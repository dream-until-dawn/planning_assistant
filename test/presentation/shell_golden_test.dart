/// 外壳整屏的视觉回归（测试策略 §7.1，快照型）。
///
/// 这是应用**第一个真正的界面**：冷启动看到的那一屏。
/// 断言在 `app_shell_test.dart`，这里只拍图。
///
/// 关于中文渲染成方框、以及这些图能证明什么不能证明什么，
/// 见 `design/task_card_golden_test.dart` 顶部那段。
@Tags(['golden'])
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/design/theme/app_theme.dart';
import 'package:planning_assistant/design/tokens/dimensions.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/views/shared/application/view_kind.dart';
import 'package:planning_assistant/features/views/task_list/presentation/task_list_page.dart';

/// M2 的真实形态：只有列表一个视图，切换器因此不出现。
Widget _current(Brightness brightness, double scale) => _wrap(
  brightness,
  scale,
  AppShell(
    currentView: ViewKind.list,
    availableViews: const [ViewKind.list],
    onViewSelected: (_) {},
    onCreateTask: () {},
    onOpenSettings: () {},
    viewBuilder: (context, kind) => TaskListPage(onCreateTask: () {}),
  ),
);

/// M3 的形态：四个视图，切换器出现。
///
/// **提前拍这一张**，是因为切换器只在多视图时才渲染 ——
/// 只拍 M2 的样子，等 M3 加视图时才会第一次看见它长什么样。
Widget _withSwitcher(Brightness brightness, double scale) => _wrap(
  brightness,
  scale,
  AppShell(
    currentView: ViewKind.list,
    availableViews: ViewKind.values,
    onViewSelected: (_) {},
    onCreateTask: () {},
    onOpenSettings: () {},
    viewBuilder: (context, kind) => TaskListPage(onCreateTask: () {}),
  ),
);

Widget _wrap(Brightness brightness, double scale, Widget child) =>
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: brightness == Brightness.light
            ? AppTheme.light()
            : AppTheme.dark(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: child,
        ),
      ),
    );

void main() {
  final cases = <String, Widget Function(Brightness, double)>{
    'shell': _current,
    'shell_switcher': _withSwitcher,
  };

  for (final entry in cases.entries) {
    for (final brightness in Brightness.values) {
      for (final scale in FontScale.goldenScales) {
        final name =
            '${entry.key}_${brightness.name}_x${scale.toStringAsFixed(1)}';

        testWidgets(name, (tester) async {
          // 整屏用真实手机比例，不像组件那样按内容放大画布 ——
          // 要看的正是「内容在一屏里放不放得下」。
          await tester.binding.setSurfaceSize(const Size(390, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(entry.value(brightness, scale));
          await tester.pumpAndSettle();

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/$name.png'),
          );
        });
      }
    }
  }
}

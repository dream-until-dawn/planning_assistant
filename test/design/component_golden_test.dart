/// 按钮与 Chip 的**视觉回归**（测试策略 §7.1，快照型）。
///
/// 只拍图，不断言约束 —— 约束在 `component_assertions_test.dart`。
/// 改间距 token 时**这里就该红**，那边不该红（§7.2 的判据）。
///
/// 关于中文渲染成方框、以及这些图能证明什么不能证明什么，
/// 见 `task_card_golden_test.dart` 顶部那段，不重复。
@Tags(['golden'])
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/design/components/app_button.dart';
import 'package:planning_assistant/design/components/app_chip.dart';
import 'package:planning_assistant/design/theme/app_theme.dart';
import 'package:planning_assistant/design/tokens/dimensions.dart';

Widget _section(String title, List<Widget> children) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(title),
    const SizedBox(height: Spacing.sm),
    Wrap(spacing: Spacing.sm, runSpacing: Spacing.sm, children: children),
    const SizedBox(height: Spacing.groupGap),
  ],
);

Widget _gallery(Brightness brightness, double scale) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.pageHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section('按钮 · 启用', [
              for (final v in AppButtonVariant.values)
                AppButton(label: '保存', variant: v, onPressed: () {}),
            ]),
            _section('按钮 · 禁用', [
              for (final v in AppButtonVariant.values)
                AppButton(label: '保存', variant: v),
            ]),
            _section('按钮 · 带图标 / 撑满', [
              AppButton(label: '新建任务', icon: Icons.add, onPressed: () {}),
              AppButton(label: '保存并关闭', onPressed: () {}, expand: true),
            ]),
            _section('分类 Chip', const [
              CategoryChip(name: '工作', color: Color(0xFFA8C8F0)),
              CategoryChip(name: '生活', color: Color(0xFF7FD1C1)),
              CategoryChip(name: '健康', color: Color(0xFFFFB7C5)),
              CategoryChip(name: '学习', color: Color(0xFFFFD79A)),
            ]),
            _section('筛选 Chip', const [
              SelectableChip(label: '今天', selected: true),
              SelectableChip(label: '本周', selected: false),
              SelectableChip(label: '已完成', selected: false),
            ]),
          ],
        ),
      ),
    ),
  ),
);

/// 缩放越大内容越高，画布跟着放大，否则底下几组会被裁掉。
Size _surfaceFor(double scale) => Size(400, 700 * scale);

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in FontScale.goldenScales) {
      final name = 'components_${brightness.name}_x${scale.toStringAsFixed(1)}';

      testWidgets(name, (tester) async {
        await tester.binding.setSurfaceSize(_surfaceFor(scale));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_gallery(brightness, scale));
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
      });
    }
  }
}

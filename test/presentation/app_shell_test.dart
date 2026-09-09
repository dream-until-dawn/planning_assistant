/// 应用根与外壳（view-specs §7）。
///
/// M0 时这里只有一条「根 Widget 不崩」的冒烟，注释里写着
/// 「M2 会在此基础上扩成真正的外壳测试」—— 就是现在。
///
/// 断的是**外壳的行为**：切换器在几个视图时出现、当前视图渲染的是谁、
/// 没有动作时按钮不画、切视图不产生路由。不拍图。
@TestOn('vm')
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/design/components/empty_state.dart';
import 'package:planning_assistant/design/theme/app_theme.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/views/calendar/presentation/calendar_page.dart';
import 'package:planning_assistant/features/views/shared/application/view_kind.dart';

import '../support/app_harness.dart';

/// **不接真库**：这些断言要的只是「外壳画对了没有」，
/// 仓库怎么过滤墓碑、怎么排序与它无关。接真库还会带来 drift
/// 取消订阅的零延时 timer，得在每个用例末尾拆树才收得干净。
///
/// 但也不能一个覆盖都不给 —— 外壳上的筛选条会读分类，
/// 裸 ProviderScope 下它直接抛，整个应用起不来，
/// 那时测的就不是「外壳对不对」了。
List<Override> _overrides() =>
    viewPipelineOverrides(today: const PlanDate(2026, 9, 8));

Future<void> _pumpApp(
  WidgetTester tester, {
  Map<String, Object?> settings = const {},
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: viewPipelineOverrides(
        today: const PlanDate(2026, 9, 8),
        settings: settings,
      ),
      child: PlanningAssistantApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// 直接搭外壳，绕开路由 —— 要验的是外壳自己的行为。
/// 直接搭外壳，绕开路由与真实依赖。
Future<void> _pumpShell(
  WidgetTester tester, {
  required List<ViewKind> available,
  ViewKind current = ViewKind.list,
  ValueChanged<ViewKind>? onViewSelected,
  void Function(BuildContext)? onCreateTask,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(),
      child: MaterialApp(
        // 必须给我们的主题：外壳从 ThemeExtension 取语义色，
        // 裸 MaterialApp 下那个扩展是 null。
        theme: AppTheme.light(),
        home: AppShell(
          currentView: current,
          availableViews: available,
          onViewSelected: onViewSelected ?? (_) {},
          onCreateTask: onCreateTask,
          viewBuilder: (context, kind) =>
              Center(child: Text('视图:${kind.name}')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('应用根', () {
    testWidgets('冷启动直达外壳，不经中转页（§6）', (tester) async {
      await _pumpApp(tester);
      expect(find.byType(AppShell), findsOneWidget);
      // 空态是规格要求的一屏（§8.2），不是加载中占位。
      expect(find.byType(EmptyState), findsOneWidget);
    });

    testAppWidgets('**冷启动进入用户设定的默认视图**（FR-CFG-04）', (tester) async {
      // 这条验收标准此前一条测试都没有 —— 组合根确实读了
      // `view.defaultView`，但没有任何东西盯着它读了以后用不用。
      // 需求编号的可追溯性守卫（`tool/check_traceability.py`）翻出来的。
      await _pumpApp(tester, settings: {'view.defaultView': 'calendar'});

      expect(
        find.byKey(CalendarPage.gridKey),
        findsOneWidget,
        reason: '设了默认视图是日历，冷启动却没进日历',
      );
    });

    testAppWidgets('配置里是个不认识的视图名时，回落而不是白屏', (tester) async {
      // 降级安装、或配置被别的版本写过 —— 那时正确的行为是
      // 给他一个能用的界面（view-specs §7.4）。
      await _pumpApp(tester, settings: {'view.defaultView': '还没做的视图'});
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('未开启 debug 横幅（发版观感）', (tester) async {
      await _pumpApp(tester);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.debugShowCheckedModeBanner, isFalse);
    });

    testWidgets('空态不出现「暂无数据」这类默认文案（§8.2 硬性）', (tester) async {
      await _pumpApp(tester);
      for (final banned in ['暂无数据', '没有数据', '空空如也', 'No data']) {
        expect(
          find.textContaining(banned),
          findsNothing,
          reason: '出现了「$banned」',
        );
      }
    });
  });

  group('视图切换器', () {
    testWidgets('只有一个视图时不画切换器，只写标题', (tester) async {
      // 一个选项的切换器是纯噪音，还会让 M2 的界面显得像坏了。
      await _pumpShell(tester, available: const [ViewKind.list]);
      expect(find.byKey(AppShell.viewTabKey(ViewKind.list)), findsNothing);
      expect(find.text(ViewKind.list.label), findsOneWidget);
    });

    testWidgets('多个视图时每个都可点', (tester) async {
      await _pumpShell(tester, available: ViewKind.values);
      for (final kind in ViewKind.values) {
        expect(
          find.byKey(AppShell.viewTabKey(kind)),
          findsOneWidget,
          reason: '缺少「${kind.label}」',
        );
      }
    });

    testWidgets('点一个未选中的标签会回传它', (tester) async {
      ViewKind? picked;
      await _pumpShell(
        tester,
        available: ViewKind.values,
        onViewSelected: (k) => picked = k,
      );
      await tester.tap(find.byKey(AppShell.viewTabKey(ViewKind.gantt)));
      expect(picked, ViewKind.gantt);
    });

    testWidgets('选中态在语义树上可读', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpShell(
        tester,
        available: ViewKind.values,
        current: ViewKind.calendar,
      );
      final node = tester.getSemantics(
        find.byKey(AppShell.viewTabKey(ViewKind.calendar)),
      );
      expect(node.flagsCollection.isSelected, Tristate.isTrue);
      handle.dispose();
    });

    testWidgets('对照组：未选中的标签在语义树上不是选中', (tester) async {
      // 否则「一律标成 selected」也能让上面那条绿。
      final handle = tester.ensureSemantics();
      await _pumpShell(
        tester,
        available: ViewKind.values,
        current: ViewKind.calendar,
      );
      final node = tester.getSemantics(
        find.byKey(AppShell.viewTabKey(ViewKind.gantt)),
      );
      expect(node.flagsCollection.isSelected, isNot(Tristate.isTrue));
      handle.dispose();
    });

    testWidgets('切换器渲染的是当前视图', (tester) async {
      await _pumpShell(
        tester,
        available: ViewKind.values,
        current: ViewKind.timeline,
      );
      expect(find.text('视图:timeline'), findsOneWidget);
      expect(find.text('视图:list'), findsNothing);
    });
  });

  group('悬浮新增按钮', () {
    testWidgets('没有新建动作时整个不画', (tester) async {
      // 一个点不动的 FAB 比没有更让人困惑。
      await _pumpShell(tester, available: const [ViewKind.list]);
      expect(find.byKey(AppShell.fabKey), findsNothing);
    });

    testWidgets('对照组：有动作时画出来且点得动', (tester) async {
      var taps = 0;
      await _pumpShell(
        tester,
        available: const [ViewKind.list],
        onCreateTask: (_) => taps++,
      );
      expect(find.byKey(AppShell.fabKey), findsOneWidget);
      await tester.tap(find.byKey(AppShell.fabKey));
      expect(taps, 1);
    });
  });

  group('ViewKind 的存储键（§7.4）', () {
    test('每个枚举值的 storageKey 互不相同', () {
      final keys = ViewKind.values.map((v) => v.storageKey).toSet();
      expect(keys.length, ViewKind.values.length);
    });

    test('存储键往返', () {
      for (final kind in ViewKind.values) {
        expect(ViewKind.fromStorageKey(kind.storageKey), kind);
      }
    });

    test('认不出的键回落到默认视图，不抛', () {
      // 用户降级安装、配置被别的版本写过时会读到这种值。
      for (final bad in [null, '', 'kanban', 'LIST', '甘特']) {
        expect(
          ViewKind.fromStorageKey(bad),
          ViewKind.fallback,
          reason: '「$bad」应当回落',
        );
      }
    });

    test('默认视图是列表（§6）', () {
      expect(ViewKind.fallback, ViewKind.list);
    });
  });
}

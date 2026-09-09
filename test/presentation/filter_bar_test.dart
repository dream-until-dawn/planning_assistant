/// 筛选条与多选弹层（view-specs §2.3、FR-VIEW-05）。
///
/// ## 这一份是重写的
///
/// 上一版顶部是一排十来个 Chip，用户的原话是「改造下顶部的筛选，
/// 改为下拉或抽屉或其他形式的多选器，按 状态/分类等等分为多个选择器」。
///
/// 这里验的是那套结构本身：**每维一个按钮**、按钮上说得出选了几项、
/// 弹层里勾了真的生效、每一维清得掉而不牵连别的维度。
/// 「筛出来的行对不对」在各视图自己的用例里（`applyFilter` 没动过）。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/design/theme/app_theme.dart';
import 'package:planning_assistant/domain/entities/category.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';
import 'package:planning_assistant/features/views/shared/application/view_shared_state.dart';
import 'package:planning_assistant/features/views/shared/presentation/filter_bar.dart';
import 'package:planning_assistant/features/views/shared/presentation/filter_sheet.dart';

import '../support/app_harness.dart';

const _today = PlanDate(2026, 9, 8);

const _categories = [
  Category(
    id: 'work',
    name: '工作',
    colorArgb: 0xFF3366CC,
    icon: 'work',
    orderIndex: 0,
  ),
  Category(
    id: 'life',
    name: '生活',
    colorArgb: 0xFF669933,
    icon: 'home',
    orderIndex: 1,
  ),
];

Future<ProviderContainer> _pump(WidgetTester tester) async {
  await setScreenSize(tester, const Size(390, 844));
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: viewPipelineOverrides(categories: _categories, today: _today),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const Scaffold(body: FilterBar());
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

FilterSpec _filterOf(ProviderContainer c) =>
    c.read(viewSharedStateProvider).filter;

void main() {
  group('每维一个按钮', () {
    testAppWidgets('三个维度都在，选项藏在弹层里', (tester) async {
      await _pump(tester);

      for (final d in FilterDimension.values) {
        expect(find.byKey(FilterBar.dimensionKey(d)), findsOneWidget);
      }
      // **没点开时选项不在树上** —— 这是这次改动的全部意义：
      // 十来个 Chip 不再挤在一行里。
      expect(find.byKey(FilterKeys.status(TaskStatus.done)), findsNothing);
      expect(find.byKey(FilterKeys.category('work')), findsNothing);
    });

    testAppWidgets('点开哪一维，弹层里就是哪一维的选项', (tester) async {
      await _pump(tester);
      await tester.tap(
        find.byKey(FilterBar.dimensionKey(FilterDimension.category)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(FilterSheet.sheetKey(FilterDimension.category)),
        findsOneWidget,
      );
      expect(find.byKey(FilterKeys.category('work')), findsOneWidget);
      expect(find.byKey(FilterKeys.category('life')), findsOneWidget);
      // 「未分类」与真分类并排 —— 它是这一维里的一个取值，不是额外开关。
      expect(find.byKey(FilterKeys.category(null)), findsOneWidget);
      // 别的维度不掺进来。
      expect(find.byKey(FilterKeys.status(TaskStatus.done)), findsNothing);
    });

    testAppWidgets('**按钮上说得出选了几项**', (tester) async {
      // 不说的话，「我到底筛了什么」得逐个点开才知道 ——
      // 而底色深浅只说得了「有没有筛」。
      final c = await _pump(tester);
      expect(find.text('状态'), findsOneWidget);

      await toggleFilter(
        tester,
        FilterDimension.status,
        FilterKeys.status(TaskStatus.done),
      );
      expect(find.text('状态 1'), findsOneWidget);

      await toggleFilter(
        tester,
        FilterDimension.status,
        FilterKeys.status(TaskStatus.skipped),
      );
      expect(find.text('状态 2'), findsOneWidget);
      expect(_filterOf(c).statuses, {TaskStatus.done, TaskStatus.skipped});
    });
  });

  group('弹层里勾了真的生效', () {
    testAppWidgets('勾一项 → 共享状态跟着变', (tester) async {
      final c = await _pump(tester);
      await toggleFilter(
        tester,
        FilterDimension.category,
        FilterKeys.category('work'),
      );

      expect(_filterOf(c).categoryIds, {'work'});
    });

    testAppWidgets('再勾一次取消 —— 不然这一维是条走进去出不来的路', (tester) async {
      final c = await _pump(tester);
      for (var i = 0; i < 2; i++) {
        await toggleFilter(
          tester,
          FilterDimension.category,
          FilterKeys.category('work'),
        );
      }
      expect(_filterOf(c).categoryIds, isEmpty);
    });

    testAppWidgets('弹层**不会点一下就关**，可以连着选几项', (tester) async {
      // 多选的意义就在这里。点一项就关的话，选三个分类要开三次。
      final c = await _pump(tester);
      await tapVisible(
        tester,
        FilterBar.dimensionKey(FilterDimension.category),
      );
      await tapVisible(tester, FilterKeys.category('work'));
      await tapVisible(tester, FilterKeys.category('life'));

      expect(
        find.byKey(FilterSheet.sheetKey(FilterDimension.category)),
        findsOneWidget,
        reason: '勾一项之后弹层就关了',
      );
      expect(_filterOf(c).categoryIds, {'work', 'life'});
    });

    testAppWidgets('勾过的项在弹层里是选中态 —— 重新打开要看得出勾过什么', (tester) async {
      await _pump(tester);
      await toggleFilter(
        tester,
        FilterDimension.category,
        FilterKeys.category('work'),
      );
      await tapVisible(
        tester,
        FilterBar.dimensionKey(FilterDimension.category),
      );

      final chip = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byKey(FilterKeys.category('work')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(chip.properties.selected, isTrue);
    });
  });

  group('清除', () {
    testAppWidgets('「清空」只清这一维，别的维度不动', (tester) async {
      final c = await _pump(tester);
      await toggleFilter(
        tester,
        FilterDimension.status,
        FilterKeys.status(TaskStatus.done),
      );
      await toggleFilter(
        tester,
        FilterDimension.category,
        FilterKeys.category('work'),
      );

      await tapVisible(
        tester,
        FilterBar.dimensionKey(FilterDimension.category),
      );
      await tester.tap(
        find.byKey(FilterSheet.clearKey(FilterDimension.category)),
      );
      await tester.pumpAndSettle();

      expect(_filterOf(c).categoryIds, isEmpty);
      expect(_filterOf(c).statuses, {TaskStatus.done}, reason: '清一维把别的维度也清了');
    });

    testAppWidgets('没选东西时不显示「清空」', (tester) async {
      await _pump(tester);
      await tapVisible(tester, FilterBar.dimensionKey(FilterDimension.status));

      expect(
        find.byKey(FilterSheet.clearKey(FilterDimension.status)),
        findsNothing,
        reason: '点了没反应的按钮比没有按钮更糟',
      );
    });

    testAppWidgets('「清除筛选」把三个维度一起清掉', (tester) async {
      final c = await _pump(tester);
      await toggleFilter(
        tester,
        FilterDimension.status,
        FilterKeys.status(TaskStatus.done),
      );
      await toggleFilter(
        tester,
        FilterDimension.category,
        FilterKeys.category('work'),
      );

      await tapVisible(tester, FilterBar.clearKey);
      expect(_filterOf(c).isEmpty, isTrue);
    });

    testAppWidgets('没筛东西时「清除筛选」不出现', (tester) async {
      await _pump(tester);
      expect(find.byKey(FilterBar.clearKey), findsNothing);
    });
  });

  group('只放设得出来的项', () {
    testAppWidgets('状态维度不出 inProgress —— 它没有任何入口', (tester) async {
      // 摆出来是个筛不出东西的按钮。
      await _pump(tester);
      await tapVisible(tester, FilterBar.dimensionKey(FilterDimension.status));

      expect(
        find.byKey(FilterKeys.status(TaskStatus.inProgress)),
        findsNothing,
      );
      for (final (s, _) in FilterSheet.exposedStatuses) {
        expect(find.byKey(FilterKeys.status(s)), findsOneWidget);
      }
    });

    testAppWidgets('**「已跳过」必须在** —— 它是跳过之后唯一的反悔入口', (tester) async {
      // 跳过的那一次「不出现在任何视图」（FR-TASK-05 验收）。
      // 拿掉这一项，跳过就成了一条走进去出不来的路。
      await _pump(tester);
      await tapVisible(tester, FilterBar.dimensionKey(FilterDimension.status));

      expect(find.byKey(FilterKeys.status(TaskStatus.skipped)), findsOneWidget);
    });

    testAppWidgets('优先级五档都在', (tester) async {
      await _pump(tester);
      await tapVisible(
        tester,
        FilterBar.dimensionKey(FilterDimension.priority),
      );

      for (final p in TaskPriority.values) {
        expect(find.byKey(FilterKeys.priority(p)), findsOneWidget);
      }
    });
  });
}

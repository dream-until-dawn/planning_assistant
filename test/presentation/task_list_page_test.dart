/// 列表视图的分组渲染与折叠（view-specs §2.1、§2.4）。
///
/// 不接库、不拍图：覆盖数据源，断言渲染出来的结构。
/// 分组规则本身在 `application/task_grouping_test.dart` 验，
/// 这里只验「界面把它画对了没有」。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/design/theme/app_theme.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/features/views/shared/application/category_providers.dart';
import 'package:planning_assistant/features/views/task_list/application/task_list_providers.dart';
import 'package:planning_assistant/features/views/task_list/presentation/task_list_page.dart';

const _today = PlanDate(2026, 9, 8);

/// 夹具里的任务标题**不能和分组标题重名**。
///
/// 初版把任务叫「今天」，而「今天」也是分组标题 —— `find.text('今天')`
/// 同时命中两个，断言当场报「too many」。撞名的话，
/// 「标题在不在」和「卡片在不在」这两件事就分不开了。
const _titlePrefix = '事项·';

Task _task(String id, {PlanDate? date}) => Task(
  id: id,
  title: id,
  kind: TaskKind.single,
  timeZoneId: 'Asia/Shanghai',
  planDate: date,
  isAllDay: true,
);

Future<void> _pump(WidgetTester tester, List<Task> tasks) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        visibleTasksProvider.overrideWith((ref) => Stream.value(tasks)),
        categoriesProvider.overrideWith((ref) => Stream.value(const [])),
        // 钉死「今天」，否则这些断言会随跑测试的日子变。
        todayProvider.overrideWithValue(_today),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: TaskListPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('分组标题', () {
    testWidgets('每组一个标题，带条数', (tester) async {
      await _pump(tester, [
        _task('$_titlePrefix今天甲', date: _today),
        _task('$_titlePrefix今天乙', date: _today),
        _task('$_titlePrefix明天', date: const PlanDate(2026, 9, 9)),
      ]);

      expect(find.byKey(TaskListPage.groupHeaderKey('today')), findsOneWidget);
      expect(
        find.byKey(TaskListPage.groupHeaderKey('tomorrow')),
        findsOneWidget,
      );
      expect(find.text('今天'), findsOneWidget, reason: '这是分组标题，不是任务标题');
      expect(find.text('2'), findsOneWidget, reason: '「今天」那组该显示 2');
    });

    testWidgets('空组不出现标题', (tester) async {
      await _pump(tester, [_task('$_titlePrefix今天', date: _today)]);
      expect(find.byKey(TaskListPage.groupHeaderKey('tomorrow')), findsNothing);
      expect(find.byKey(TaskListPage.groupHeaderKey('no-date')), findsNothing);
    });
  });

  group('折叠（§2.4）', () {
    testWidgets('逾期组默认折叠：卡片不渲染，但标题与计数在', (tester) async {
      // 折叠的意义是「我知道有这些，但先不看」——
      // 计数没了的话，折叠就等于把信息藏了。
      await _pump(tester, [
        _task('$_titlePrefix欠的', date: const PlanDate(2026, 9, 1)),
        _task('$_titlePrefix今天', date: _today),
      ]);

      expect(
        find.byKey(TaskListPage.groupHeaderKey('overdue')),
        findsOneWidget,
      );
      expect(find.text('逾期'), findsOneWidget);
      expect(find.text('$_titlePrefix欠的'), findsNothing, reason: '默认折叠时不该渲染卡片');
      expect(find.text('今天'), findsOneWidget);
    });

    testWidgets('对照组：非逾期组默认展开', (tester) async {
      // 否则「一律折叠」也能让上面那条绿，而那样打开应用是一片标题。
      await _pump(tester, [_task('$_titlePrefix今天的事', date: _today)]);
      expect(find.text('$_titlePrefix今天的事'), findsOneWidget);
    });

    testWidgets('点标题能展开逾期组', (tester) async {
      await _pump(tester, [
        _task('$_titlePrefix欠的', date: const PlanDate(2026, 9, 1)),
      ]);
      expect(find.text('$_titlePrefix欠的'), findsNothing);

      await tester.tap(find.byKey(TaskListPage.groupHeaderKey('overdue')));
      await tester.pumpAndSettle();

      expect(find.text('$_titlePrefix欠的'), findsOneWidget);
    });

    testWidgets('展开的组也能收起来', (tester) async {
      // 只验「能展开」的话，一个「点一下就永久展开」的实现也通过。
      await _pump(tester, [_task('$_titlePrefix今天的事', date: _today)]);
      expect(find.text('$_titlePrefix今天的事'), findsOneWidget);

      await tester.tap(find.byKey(TaskListPage.groupHeaderKey('today')));
      await tester.pumpAndSettle();

      expect(find.text('$_titlePrefix今天的事'), findsNothing);
    });

    testWidgets('折叠状态在语义树上可读', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, [
        _task('$_titlePrefix欠的', date: const PlanDate(2026, 9, 1)),
        _task('$_titlePrefix今天', date: _today),
      ]);

      final overdue = tester.getSemantics(
        find.byKey(TaskListPage.groupHeaderKey('overdue')),
      );
      final today = tester.getSemantics(
        find.byKey(TaskListPage.groupHeaderKey('today')),
      );
      // 读屏用户看不见「卡片没了」，只能靠这个标记知道组是收着的。
      expect(overdue.label, contains('逾期'));
      expect(overdue.label, contains('1'));
      expect(today.label, contains('今天'));

      handle.dispose();
    });
  });

  group('分组之外的东西没被弄坏', () {
    testWidgets('空列表仍然是空态，不是一堆空标题', (tester) async {
      await _pump(tester, []);
      expect(find.byKey(TaskListPage.listKey), findsNothing);
      expect(find.textContaining('今天还空着'), findsOneWidget);
    });

    testWidgets('每条任务仍然渲染成一张卡片', (tester) async {
      await _pump(tester, [
        _task('$_titlePrefix甲', date: _today),
        _task('$_titlePrefix乙', date: const PlanDate(2026, 9, 9)),
      ]);
      expect(find.byType(TaskCard), findsNWidgets(2));
    });
  });
}

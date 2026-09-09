/// 列表视图的分组渲染与折叠（view-specs §2.1、§2.4、FR-VIEW-02）。
///
/// 不接库、不拍图：覆盖数据源，断言渲染出来的结构。
/// 分组规则本身在 `application/task_grouping_test.dart` 验，
/// 这里只验「界面把它画对了没有」。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app_providers.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/core/time/time_zone_resolver.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/design/theme/app_theme.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';
import 'package:planning_assistant/features/views/shared/application/category_providers.dart';
import 'package:planning_assistant/features/views/shared/application/task_occurrence.dart';
import 'package:planning_assistant/features/views/shared/application/task_providers.dart';
import 'package:planning_assistant/features/views/shared/application/view_shared_state.dart';
import 'package:planning_assistant/features/views/shared/presentation/occurrence_card_data.dart';
import 'package:planning_assistant/features/views/task_list/presentation/task_list_page.dart';

import '../support/app_harness.dart';

const _today = PlanDate(2026, 9, 8);

/// 夹具里的任务标题**不能和分组标题重名**。
///
/// 初版把任务叫「今天」，而「今天」也是分组标题 —— `find.text('今天')`
/// 同时命中两个，断言当场报「too many」。撞名的话，
/// 「标题在不在」和「卡片在不在」这两件事就分不开了。
const _titlePrefix = '事项·';

Task _task(String id, {PlanDate? date, String? categoryId}) => Task(
  id: id,
  title: id,
  kind: TaskKind.single,
  timeZoneId: 'Asia/Shanghai',
  planDate: date,
  categoryId: categoryId,
  isAllDay: true,
);

Future<void> _pump(
  WidgetTester tester,
  List<Task> tasks, {
  FilterSpec filter = FilterSpec.none,
}) async {
  await setScreenSize(tester, const Size(390, 844));

  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        visibleTasksProvider.overrideWith((ref) => Stream.value(tasks)),
        categoriesProvider.overrideWith((ref) => Stream.value(const [])),
        // 展开需要时区换算器（重复任务要按墙钟展开）。
        // 这些用例里的任务都不重复，但展开那一步照样会读它。
        timeZoneResolverProvider.overrideWithValue(
          const TzTimeZoneResolver(fixedCurrentZoneId: 'Asia/Shanghai'),
        ),
        allOverridesProvider.overrideWith((ref) => Stream.value(const [])),
        // 钉死「今天」，否则这些断言会随跑测试的日子变。
        todayProvider.overrideWithValue(_today),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const Scaffold(body: TaskListPage());
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (!filter.isEmpty) {
    // 通过真的 notifier 设，而不是覆盖 provider —— 这样连
    // 「设筛选会触发重算」也一起验了。
    container.read(viewSharedStateProvider.notifier).setFilter(filter);
    await tester.pumpAndSettle();
  }
}

TaskOccurrence _row(PlanDate? date, {bool allDay = false, int? minute}) =>
    TaskOccurrence(
      task: Task(
        id: 't',
        title: '吃药',
        kind: TaskKind.single,
        timeZoneId: 'Asia/Shanghai',
        planDate: date,
        startMinute: minute == null ? null : MinuteOfDay(minute),
        isAllDay: allDay,
      ),
    );

void main() {
  group('FR-VIEW-02 卡片要说清「哪一天」', () {
    // 用户报的原话：「每天的任务没有标注日期啊，我不知道这个每日任务
    // 具体是哪一日的，都放在逾期里我看不出啊」。
    //
    // 一度只写 `HH:mm`，而且**全天任务直接返回 null** —— 于是一条每天
    // 重复的全天任务，卡片上关于「哪一天」一个字都没有。
    // 分组标题只说得了「逾期」这一类，说不了组里那七行各是哪天，
    // 而重复任务恰恰会在「逾期」里堆出一长串长得一模一样的卡片。

    test('不是今天的全天任务：写出日期', () {
      expect(
        timeLabelOf(
          _row(const PlanDate(2026, 9, 5), allDay: true),
          today: const PlanDate(2026, 9, 8),
        ),
        '9/5',
      );
    });

    test('不是今天的定时任务：日期 + 时刻', () {
      expect(
        timeLabelOf(
          _row(const PlanDate(2026, 9, 5), minute: 9 * 60 + 30),
          today: const PlanDate(2026, 9, 8),
        ),
        '9/5 09:30',
      );
    });

    test('**今天的不写日期** —— 分组标题已经说了', () {
      // 再写一遍是噪音。
      expect(
        timeLabelOf(
          _row(const PlanDate(2026, 9, 8), minute: 9 * 60 + 30),
          today: const PlanDate(2026, 9, 8),
        ),
        '09:30',
      );
    });

    test('今天的全天任务：什么都不写', () {
      expect(
        timeLabelOf(
          _row(const PlanDate(2026, 9, 8), allDay: true),
          today: const PlanDate(2026, 9, 8),
        ),
        isNull,
      );
    });

    test('没有日期的任务：什么都不写', () {
      // 「无日期」是合法状态（FR-TASK-01），它有自己的分组。
      expect(
        timeLabelOf(_row(null), today: const PlanDate(2026, 9, 8)),
        isNull,
      );
    });

    test('时间轴关掉时间标签 —— 它自己有一条时间栏', () {
      // 不关的话同一个时刻在一行里出现两次（左边一次、卡片上一次）。
      expect(
        occurrenceCardData(
          _row(const PlanDate(2026, 9, 5), minute: 9 * 60 + 30),
          const {},
          today: const PlanDate(2026, 9, 8),
          withTime: false,
        ).timeLabel,
        isNull,
      );
    });
  });

  group('逾期样式接到真实数据上（design-system §2.4）', () {
    // ## 这一项一度是**没人传**的
    //
    // `TaskCardData.isOverdue` 声明了、卡片也照它换左色条与时间色，
    // 断言测试与 golden 也各有一条 —— 但那些都**直接构造
    // `TaskCardData`**。从真实数据这条路上过来的卡片永远拿到默认的
    // `false`，于是逾期样式在应用里一次都没出现过。
    //
    // 组件测试全绿，因为它们绕过了整形这一步 —— 这是
    // testing-strategy §1.6「模型有旋钮、界面够不着」最难发现的那一种。
    TaskCardData dataOf(
      PlanDate? date, {
      TaskStatus status = TaskStatus.pending,
    }) => occurrenceCardData(
      TaskOccurrence(
        task: Task(
          id: 't',
          title: 't',
          kind: TaskKind.single,
          timeZoneId: 'Asia/Shanghai',
          planDate: date,
          status: status,
        ),
      ),
      const {},
      today: const PlanDate(2026, 9, 8),
    );

    test('昨天的没做完 → 逾期', () {
      expect(dataOf(const PlanDate(2026, 9, 7)).isOverdue, isTrue);
    });

    test('今天的不算逾期', () {
      expect(dataOf(const PlanDate(2026, 9, 8)).isOverdue, isFalse);
    });

    test('**做完的不算** —— 上周做完的事就是做完了', () {
      // 给它标红只会让「有几件事欠着」这个问题的答案变多。
      expect(
        dataOf(const PlanDate(2026, 9, 7), status: TaskStatus.done).isOverdue,
        isFalse,
      );
    });

    test('跳过的也不算', () {
      expect(
        dataOf(
          const PlanDate(2026, 9, 7),
          status: TaskStatus.skipped,
        ).isOverdue,
        isFalse,
      );
    });

    test('没有日期的不算 —— 它没有「过没过期」这回事', () {
      expect(dataOf(null).isOverdue, isFalse);
    });
  });

  group('FR-VIEW-02 分组标题', () {
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

  group('时间标签', () {
    testWidgets('无日期的任务不显示时刻', (tester) async {
      // 「12:32，但不知道哪天」指向不了任何东西。编辑器现在不会再产出
      // 这种数据，但库里可能已经有（早期版本存的、或导入进来的），
      // 渲染层照着不变量来。
      await _pump(tester, [
        Task(
          id: 'legacy',
          title: '$_titlePrefix旧数据',
          kind: TaskKind.single,
          timeZoneId: 'Asia/Shanghai',
          startMinute: MinuteOfDay.of(12, 32),
        ),
      ]);
      expect(find.text('12:32'), findsNothing);
      expect(find.text('$_titlePrefix旧数据'), findsOneWidget, reason: '任务本身还得在');
    });

    testWidgets('对照组：有日期就显示时刻', (tester) async {
      // 否则「一律不显示时刻」也能让上面那条绿。
      await _pump(tester, [
        Task(
          id: 'ok',
          title: '$_titlePrefix开会',
          kind: TaskKind.single,
          timeZoneId: 'Asia/Shanghai',
          planDate: _today,
          startMinute: MinuteOfDay.of(12, 32),
        ),
      ]);
      expect(find.text('12:32'), findsOneWidget);
    });
  });

  group('两种「空」要分得开（§2.3）', () {
    testWidgets('库里没有任务：引导新建', (tester) async {
      await _pump(tester, []);
      expect(find.byKey(TaskListPage.emptyKey), findsOneWidget);
      expect(find.byKey(TaskListPage.noMatchKey), findsNothing);
    });

    testWidgets('有任务但筛完没剩：引导清筛选，不是「今天还空着」', (tester) async {
      // 两种状态长得一样是最容易让人慌的 —— 用户会以为任务丢了。
      await _pump(tester, [
        _task('$_titlePrefix工作的', date: _today),
      ], filter: const FilterSpec(categoryIds: {'不存在的分类'}));

      expect(find.byKey(TaskListPage.noMatchKey), findsOneWidget);
      expect(find.byKey(TaskListPage.emptyKey), findsNothing);
      expect(
        find.textContaining('今天还空着'),
        findsNothing,
        reason: '有任务却说「还空着」，那是在骗人',
      );
      expect(find.text('清除筛选'), findsOneWidget);
    });

    testWidgets('点「清除筛选」能回到列表', (tester) async {
      // 只显示一句话而按钮没用的话，用户就卡在那一屏了。
      await _pump(tester, [
        _task('$_titlePrefix工作的', date: _today),
      ], filter: const FilterSpec(categoryIds: {'不存在的分类'}));
      expect(find.byKey(TaskListPage.noMatchKey), findsOneWidget);

      await tester.tap(find.text('清除筛选'));
      await tester.pumpAndSettle();

      expect(find.byKey(TaskListPage.listKey), findsOneWidget);
      expect(find.text('$_titlePrefix工作的'), findsOneWidget);
    });

    testWidgets('筛选生效时只留匹配的', (tester) async {
      await _pump(tester, [
        _task('$_titlePrefix工作的', date: _today, categoryId: 'c-work'),
        _task('$_titlePrefix生活的', date: _today, categoryId: 'c-life'),
      ], filter: const FilterSpec(categoryIds: {'c-work'}));
      expect(find.text('$_titlePrefix工作的'), findsOneWidget);
      expect(find.text('$_titlePrefix生活的'), findsNothing);
    });
  });
}

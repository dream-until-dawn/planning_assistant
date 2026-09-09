/// 切视图时状态保持（view-specs §5、FR-VIEW-05/06）。
///
/// §5 那句话是硬的：「**必须自动化验证** —— 手工验证这种跨视图状态
/// 最容易漏」。
///
/// ## 为什么走真外壳，不各自 pump 一个视图
///
/// 要验的正是「切过去之后一切照旧」，而这件事成立的**理由**是
/// §7.1 那个结构选择：四视图共用一个外壳、压根没发生路由切换。
/// 各自 pump 一个视图的话，共享状态是测试自己塞进去的，
/// 那时验的是「provider 读得对」，不是「切视图之后还在」。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/core/time/date_and_minute.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/domain/entities/category.dart';
import 'package:planning_assistant/domain/entities/stage.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/views/calendar/presentation/calendar_page.dart';
import 'package:planning_assistant/features/views/gantt/presentation/gantt_painter.dart';
import 'package:planning_assistant/features/views/gantt/presentation/gantt_view.dart';
import 'package:planning_assistant/features/views/shared/application/view_kind.dart';
import 'package:planning_assistant/features/views/shared/application/view_shared_state.dart';
import 'package:planning_assistant/features/views/timeline/application/timeline_providers.dart';
import 'package:planning_assistant/features/views/timeline/presentation/timeline_page.dart';

import '../support/app_harness.dart';

const _today = PlanDate(2026, 9, 8);

const _categories = [
  Category(
    id: 'work',
    name: '工作',
    colorArgb: 0xFF336699,
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

Task _task(
  String id, {
  int from = 0,
  int? to,
  int? startMinute,
  int? endMinute,
  String? categoryId,
}) => Task(
  id: id,
  title: id,
  kind: TaskKind.single,
  timeZoneId: 'Asia/Shanghai',
  planDate: _today.addDays(from),
  startMinute: startMinute == null ? null : MinuteOfDay(startMinute),
  endDate: to == null ? null : _today.addDays(to),
  endMinute: endMinute == null ? null : MinuteOfDay(endMinute),
  isAllDay: startMinute == null,
  categoryId: categoryId,
);

final _tasks = [
  _task(
    '周报',
    startMinute: 9 * 60,
    to: 0,
    endMinute: 10 * 60,
    categoryId: 'work',
  ),
  _task(
    '健身',
    startMinute: 19 * 60,
    to: 0,
    endMinute: 20 * 60,
    categoryId: 'life',
  ),
  _task('体检', from: 12, to: 12, categoryId: 'life'),
];

Future<ProviderContainer> _pumpShell(
  WidgetTester tester, {
  List<Task> tasks = const [],
  List<Stage> stages = const [],
}) async {
  await setScreenSize(tester, const Size(390, 844));
  await tester.pumpWidget(
    ProviderScope(
      overrides: viewPipelineOverrides(
        tasks: tasks.isEmpty ? _tasks : tasks,
        categories: _categories,
        stages: stages,
        today: _today,
      ),
      child: PlanningAssistantApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(AppShell)));
}

/// 用外壳自己的切换器换视图 —— 与用户做的是同一件事。
Future<void> _switchTo(WidgetTester tester, ViewKind kind) async {
  await tester.tap(find.byKey(AppShell.viewTabKey(kind)));
  await tester.pumpAndSettle();
}

void main() {
  testAppWidgets('筛选保持：列表里筛「工作」→ 切甘特，只剩工作泳道', (tester) async {
    final container = await _pumpShell(tester);

    container
        .read(viewSharedStateProvider.notifier)
        .setFilter(const FilterSpec(categoryIds: {'work'}));
    await tester.pumpAndSettle();

    await _switchTo(tester, ViewKind.gantt);
    final painter =
        tester.widget<CustomPaint>(find.byKey(GanttView.canvasKey)).painter!
            as GanttPainter;
    expect(painter.layout.lanes.map((l) => l.title), ['工作']);
  });

  testAppWidgets('聚焦日保持：日历上点 9/20 → 切时间轴，时间轴就在 9/20', (tester) async {
    // **9/20 之前先塞满两屏。**
    //
    // 只用默认那三条任务的话，9/20 那一段本来就在首屏里 —— 于是
    // 「它可见」这条断言对滚动一无所知：把定位整个删掉照样绿。
    // 变异演练里它活过一次，所以这里把它压到折线以下。
    final container = await _pumpShell(
      tester,
      tasks: [
        for (var d = 0; d < 12; d++)
          _task('第$d天', from: d, startMinute: 9 * 60, endMinute: 10 * 60),
        _task('体检', from: 12, to: 12, categoryId: 'life'),
      ],
    );

    await _switchTo(tester, ViewKind.calendar);
    // **点日期数字那一块，不是格子中心。**
    //
    // 9/20 那天有一条全天任务，它的横条正好横在格子的垂直中线上，
    // 而横条自己是可点的（点它是打开那条任务）。`tester.tap` 默认打
    // 中心，于是这一下点开了任务编辑页 —— 报出来的却是
    // 「找不到 shell-view-timeline」，因为外壳已经被路由推走了。
    final cell = tester.getRect(
      find.byKey(CalendarPage.dayKey(const PlanDate(2026, 9, 20))),
    );
    await tester.tapAt(cell.topCenter + const Offset(0, 10));
    await tester.pumpAndSettle();

    await _switchTo(tester, ViewKind.timeline);
    expect(
      container.read(timelineDateProvider),
      const PlanDate(2026, 9, 20),
      reason: '时间轴还停在旧日期 —— 两边各存了一份聚焦日',
    );

    // ## 验的是「看得见」，不是「provider 的值对」
    //
    // 时间轴改成跨天议程之后，它**不再靠聚焦日筛内容** —— 9/20 的事
    // 本来就在那一列里。只断言 provider 的值的话，这条用例对
    // 「切过去之后停在哪」一无所知：滚动条停在今天、9/20 在两屏之外，
    // 它照样绿。验收原话是「显示 9/20」，所以要量它在不在视口里。
    final section = find.byKey(
      TimelinePage.dateKey(const PlanDate(2026, 9, 20)),
    );
    expect(section, findsOneWidget, reason: '9/20 那一段没滚出来');
    final viewport = tester.getRect(find.byKey(TimelinePage.scrollKey));
    final top = tester.getRect(section).top;
    expect(
      top,
      inInclusiveRange(viewport.top, viewport.bottom),
      reason: '9/20 那一段建出来了，但不在屏幕上',
    );
  });

  testAppWidgets('日历跟的是聚焦日，不是今天', (tester) async {
    // 别处把聚焦日挪到十月之后，日历该翻到十月。
    // 日历若读的是 `todayProvider`，上面那条「点 9/20 之后时间轴跟上」
    // 照样绿 —— 九月的格子里本来就有 9/20。变异演练里它活过一次。
    final container = await _pumpShell(tester);
    container
        .read(viewSharedStateProvider.notifier)
        .focusDate(const PlanDate(2026, 10, 15));
    await tester.pumpAndSettle();

    await _switchTo(tester, ViewKind.calendar);
    expect(
      find.byKey(CalendarPage.dayKey(const PlanDate(2026, 10, 15))),
      findsOneWidget,
    );
    expect(
      find.byKey(CalendarPage.dayKey(const PlanDate(2026, 9, 8))),
      findsNothing,
      reason: '日历还停在九月 —— 它读的是「今天」，不是聚焦日',
    );
  });

  testAppWidgets('粒度保持：在甘特改档位，切走再回来还是那一档', (tester) async {
    // **这条原来验的是「切成周之后日历变一行」。**
    // 周视图按用户要求去掉了（日历恒为月），所以改成在**甘特**那侧验 ——
    // 粒度共享这件事本身没变，只是日历不再是它的显示方之一。
    final container = await _pumpShell(tester);

    await _switchTo(tester, ViewKind.gantt);
    await tapVisible(tester, GanttView.granularityKey(TimeGranularity.week));
    expect(
      container.read(viewSharedStateProvider).granularity,
      TimeGranularity.week,
    );

    // 切走再切回来，档位还在。
    await _switchTo(tester, ViewKind.calendar);
    await _switchTo(tester, ViewKind.gantt);
    expect(
      container.read(viewSharedStateProvider).granularity,
      TimeGranularity.week,
      reason: '切视图把共享的档位弄丢了',
    );
  });

  testAppWidgets('日历不跟着粒度变 —— 它恒为月视图', (tester) async {
    // 用户要求：「不需要『周』固定使用月即可」。
    final container = await _pumpShell(tester);
    container
        .read(viewSharedStateProvider.notifier)
        .setGranularity(TimeGranularity.week);
    await _switchTo(tester, ViewKind.calendar);

    expect(
      find.byWidgetPredicate(
        (w) => w.key.toString().startsWith("[<'calendar-day-"),
      ),
      findsNWidgets(42),
      reason: '共享档位是「周」时日历变成了一行 —— 它该恒为月视图',
    );
  });

  testAppWidgets('切走再切回来，筛选与聚焦日都还在', (tester) async {
    // §7.1 的说法是这在「一个外壳 + 切换器」的结构下**不需要任何机制**
    // 就成立。不需要机制的东西最容易在重构时被顺手破坏，所以要有守卫。
    final container = await _pumpShell(tester);
    final shared = container.read(viewSharedStateProvider.notifier);
    shared.setFilter(const FilterSpec(categoryIds: {'life'}));
    shared.focusDate(const PlanDate(2026, 9, 20));
    await tester.pumpAndSettle();

    for (final kind in ViewKind.values) {
      await _switchTo(tester, kind);
    }
    await _switchTo(tester, ViewKind.list);

    final state = container.read(viewSharedStateProvider);
    expect(state.filter.categoryIds, {'life'});
    expect(state.focusedDate, const PlanDate(2026, 9, 20));
  });

  testAppWidgets('J-03 的一半：末阶段超出 endDate 时，甘特与时间轴同一个跨度', (tester) async {
    // §5 最后一行。两边各自算的话，同一条任务在两个视图里一长一短。
    final staged = Task(
      id: '搬家',
      title: '搬家',
      kind: TaskKind.staged,
      timeZoneId: 'Asia/Shanghai',
      planDate: _today,
      startMinute: MinuteOfDay.of(9, 0),
      endDate: _today,
      endMinute: MinuteOfDay.of(10, 0),
      categoryId: 'work',
    );
    const stages = [
      Stage(
        id: 's1',
        taskId: '搬家',
        title: '搬运',
        orderIndex: 0,
        startOffsetMinutes: 0,
        // 9:00 + 5 小时 = 14:00，超出存储的 10:00。
        durationMinutes: 300,
      ),
    ];

    final container = await _pumpShell(tester, tasks: [staged], stages: stages);

    await _switchTo(tester, ViewKind.timeline);
    // 时间轴改成议程之后不再有「块」，跨度直接问它那一行 ——
    // 而那正是 §4.7 说的唯一来源，甘特读的也是它。
    final span = container
        .read(agendaRowsProvider)
        .singleWhere((r) => r.taskId == '搬家')
        .span!;
    final endMinute =
        span.end.date.differenceInDays(_today) * minutesPerDay +
        span.end.minute.value;
    final startMinute = span.start.minute.value;

    await _switchTo(tester, ViewKind.gantt);
    final painter =
        tester.widget<CustomPaint>(find.byKey(GanttView.canvasKey)).painter!
            as GanttPainter;
    final bar = painter.layout.lanes.single.bars.single;

    expect(endMinute, 14 * 60, reason: '时间轴没用有效跨度');
    expect(bar.lengthMinutes, endMinute - startMinute, reason: '甘特与时间轴的跨度不一样');
  });
}

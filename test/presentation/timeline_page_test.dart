/// 时间轴视图（view-specs §1、FR-VIEW-01）。
///
/// ## 这一份是重写的
///
/// 上一版验的是「一天 24 小时的刻度尺」：块的顶边落在第几像素、
/// 最小块高、重叠并排、「+N」折叠、当前时刻线在第几行。
/// 用户看过之后要的是另一种排布（见 `agenda_entries.dart` 开头那段），
/// 于是那些断言钉的全是不再存在的行为 —— **改成钉新行为，不是删掉**。
///
/// 「哪些次该出现」在 `agenda_expansion_test.dart` 里按纯函数验过了。
/// 这里验的是**它有没有被画出来**：顺序对不对、阶段有没有独立成行、
/// 时间栏什么时候留空、「现在」什么时候出现、勾完成给不给撤销。
@TestOn('vm')
library;

import 'dart:async';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app_providers.dart';
import 'package:planning_assistant/core/time/clock.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/design/components/empty_illustration.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/design/theme/app_theme.dart';
import 'package:planning_assistant/domain/commands/task_command.dart';
import 'package:planning_assistant/domain/entities/stage.dart';
import 'package:planning_assistant/domain/entities/stage_occurrence_state.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/value_objects/occurrence_key.dart';
import 'package:planning_assistant/domain/value_objects/recurrence.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';
import 'package:planning_assistant/features/views/shared/application/create_task_at.dart';
import 'package:planning_assistant/features/views/shared/application/view_shared_state.dart';
import 'package:planning_assistant/features/views/timeline/application/timeline_providers.dart';
import 'package:planning_assistant/features/views/timeline/presentation/timeline_page.dart';

import '../support/app_harness.dart';

const _today = PlanDate(2026, 9, 8);
const _yesterday = PlanDate(2026, 9, 7);
const _tomorrow = PlanDate(2026, 9, 9);

/// `appHarness()` 的时钟钉在 9/7 11:00 +08，所以真库那组的「今天」是 9/7。
const _realToday = PlanDate(2026, 9, 7);

Task _task(
  String id, {
  PlanDate? date = _today,
  int? start,
  PlanDate? endDate,
  int? end,
  bool isAllDay = false,
  String? rrule,
  TaskStatus status = TaskStatus.pending,
  TaskKind kind = TaskKind.single,
}) => Task(
  id: id,
  title: id,
  kind: kind,
  timeZoneId: 'Asia/Shanghai',
  planDate: date,
  startMinute: start == null ? null : MinuteOfDay(start),
  endDate: endDate,
  endMinute: end == null ? null : MinuteOfDay(end),
  isAllDay: isAllDay,
  status: status,
  recurrence: rrule == null ? null : Recurrence.parse(rrule),
);

Stage _stage(
  String id, {
  required String taskId,
  required int order,
  int? offset,
  int? duration,
  TaskStatus status = TaskStatus.pending,
}) => Stage(
  id: id,
  taskId: taskId,
  title: id,
  orderIndex: order,
  startOffsetMinutes: offset,
  durationMinutes: duration,
  status: status,
);

/// 装好一屏时间轴。
///
/// 时钟对到 [now]（默认 9/8 09:00 +08），**与 `todayProvider` 同一天** ——
/// 两者对不上的话「现在那条线该不该出现」验的就不是视图的逻辑，
/// 而是夹具自己前后矛盾。
Future<void> _pump(
  WidgetTester tester, {
  List<Task> tasks = const [],
  List<Stage> stages = const [],
  List<StageOccurrenceState> stageStates = const [],
  Stream<List<Task>>? tasksStream,
  PlanDate? focus,
  DateTime Function()? now,
  Stream<void>? tick,
  List<Override> extra = const [],
  CreateTaskAt? onCreateTask,
  OpenTask? onEditTask,
}) async {
  await setScreenSize(tester, const Size(390, 844));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...viewPipelineOverrides(
          tasks: tasks,
          stages: stages,
          stageStates: stageStates,
          today: _today,
          tasksStream: tasksStream,
          tick: tick ?? const Stream<void>.empty(),
        ),
        clockProvider.overrideWithValue(
          _MovingClock(now ?? () => DateTime.utc(2026, 9, 8, 1)),
        ),
        ...extra,
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TimelinePage(
            onCreateTask: onCreateTask,
            onEditTask: onEditTask,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (focus != null) {
    // 建完树**之后**再推 —— 在 build 里改 provider 会被 Riverpod 拦下。
    ProviderScope.containerOf(tester.element(find.byType(TimelinePage)))
        .read(viewSharedStateProvider.notifier)
        .focusDate(focus);
    await tester.pumpAndSettle();
  }
}

/// 屏幕上从上到下的顺序。
///
/// 量 `getRect().top` 而不是记 widget 树的次序：**用户看见的是位置**，
/// 而两者不一定一致（`Stack` 里后画的可能在上面）。
List<String> _orderOf(WidgetTester tester, List<String> ids) {
  final found = [
    for (final id in ids)
      if (tester.any(find.byKey(TimelinePage.entryKey(id))))
        (id, tester.getRect(find.byKey(TimelinePage.entryKey(id))).top),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return [for (final e in found) e.$1];
}

/// 时间栏上写着什么（null = 那一行没写）。
String? _timeOn(WidgetTester tester, String id) {
  final finder = find.byKey(TimelinePage.entryKey('time-$id'));
  if (!tester.any(finder)) return null;
  return tester.widget<Text>(finder).data;
}

void main() {
  group('FR-VIEW-01 排布：按开始时刻一路排下去', () {
    testAppWidgets('跨天连着排，不是只有今天那一天', (tester) async {
      await _pump(
        tester,
        tasks: [
          _task('明天的', date: _tomorrow, start: 8 * 60),
          _task('今天下午', start: 15 * 60),
          _task('今天上午', start: 9 * 60),
        ],
      );

      expect(_orderOf(tester, ['今天上午', '今天下午', '明天的']), [
        '今天上午',
        '今天下午',
        '明天的',
      ]);
    });

    testAppWidgets('逾期的排在最前面 —— 它是最早的那件事', (tester) async {
      await _pump(
        tester,
        tasks: [
          _task('今天的', start: 9 * 60),
          _task('昨天漏了的', date: _yesterday, start: 18 * 60),
        ],
      );

      expect(_orderOf(tester, ['昨天漏了的', '今天的']), ['昨天漏了的', '今天的']);
    });

    testAppWidgets('每天有自己的分隔，写着今天/明天', (tester) async {
      await _pump(
        tester,
        tasks: [
          _task('今天的', start: 9 * 60),
          _task('明天的', date: _tomorrow, start: 9 * 60),
        ],
      );

      expect(find.byKey(TimelinePage.dateKey(_today)), findsOneWidget);
      expect(find.byKey(TimelinePage.dateKey(_tomorrow)), findsOneWidget);
      expect(find.text('今天'), findsOneWidget);
      expect(find.text('明天'), findsOneWidget);
    });

    testAppWidgets('没有日期的不进视图', (tester) async {
      // 它没有「排在什么时候」这回事。列表另有「无日期」分组接着它。
      await _pump(
        tester,
        tasks: [
          _task('哪天做都行', date: null),
          _task('今天的', start: 9 * 60),
        ],
      );

      expect(find.byKey(TimelinePage.entryKey('哪天做都行')), findsNothing);
      expect(find.byKey(TimelinePage.entryKey('今天的')), findsOneWidget);
    });

    testAppWidgets('做完的不进视图 —— 这里回答的是「接下来是什么」', (tester) async {
      await _pump(
        tester,
        tasks: [
          _task('做完了', start: 9 * 60, status: TaskStatus.done),
          _task('还没做', start: 10 * 60),
        ],
      );

      expect(find.byKey(TimelinePage.entryKey('做完了')), findsNothing);
      expect(find.byKey(TimelinePage.entryKey('还没做')), findsOneWidget);
    });

    testAppWidgets('显式筛「已完成」时它们回来', (tester) async {
      // 折叠掉的东西必须有一条找得回来的路 —— 否则勾完就再也看不见了。
      await _pump(
        tester,
        tasks: [_task('做完了', start: 9 * 60, status: TaskStatus.done)],
      );
      expect(find.byKey(TimelinePage.entryKey('做完了')), findsNothing);

      ProviderScope.containerOf(tester.element(find.byType(TimelinePage)))
          .read(viewSharedStateProvider.notifier)
          .setFilter(const FilterSpec(statuses: {TaskStatus.done}));
      await tester.pumpAndSettle();

      expect(find.byKey(TimelinePage.entryKey('做完了')), findsOneWidget);
    });
  });

  group('时间栏', () {
    testAppWidgets('同一时刻只写一次', (tester) async {
      await _pump(
        tester,
        tasks: [
          _task('甲', start: 9 * 60),
          _task('乙', start: 9 * 60),
        ],
      );

      final labels = [_timeOn(tester, '甲'), _timeOn(tester, '乙')];
      expect(
        labels.where((l) => l != null),
        hasLength(1),
        reason: '同一时刻写了两遍 —— 时间栏该读起来像跳跃的刻度',
      );
      expect(labels.whereType<String>().single, '09:00');
    });

    testAppWidgets('时刻变了就重新写', (tester) async {
      await _pump(
        tester,
        tasks: [
          _task('甲', start: 9 * 60),
          _task('乙', start: 10 * 60),
        ],
      );

      expect(_timeOn(tester, '甲'), '09:00');
      expect(_timeOn(tester, '乙'), '10:00');
    });

    testAppWidgets('换了一天就重新写，哪怕时刻一样', (tester) async {
      // 不按天重置的话，明天 09:00 那条会因为「与上一条同一时刻」而留空，
      // 于是明天那一段头顶没有时间。
      await _pump(
        tester,
        tasks: [
          _task('今天的', start: 9 * 60),
          _task('明天的', date: _tomorrow, start: 9 * 60),
        ],
      );

      expect(_timeOn(tester, '今天的'), '09:00');
      expect(_timeOn(tester, '明天的'), '09:00');
    });

    testAppWidgets('全天写「全天」，不写它那个占位的 00:00', (tester) async {
      await _pump(tester, tasks: [_task('纪念日', isAllDay: true)]);

      expect(_timeOn(tester, '纪念日'), '全天');
    });

    testAppWidgets('卡片自己不再写时刻 —— 左边那栏已经写了', (tester) async {
      // 不关的话同一个时刻在一行里出现两次。列表那边照旧写
      // （那里没有时间栏），所以这是**时间轴独有的**一个开关。
      await _pump(
        tester,
        tasks: [_task('晨会', date: _tomorrow, start: 9 * 60)],
      );

      final card = tester.widget<TaskCard>(
        find.descendant(
          of: find.byKey(TimelinePage.entryKey('晨会')),
          matching: find.byType(TaskCard),
        ),
      );
      expect(card.data.timeLabel, isNull);
    });
  });

  group('阶段各占一行（用户第 1 条意见）', () {
    testAppWidgets('阶段按自己的时刻插进任务之间', (tester) async {
      await _pump(
        tester,
        tasks: [
          _task('搬家', start: 9 * 60),
          _task('午饭', start: 12 * 60),
        ],
        stages: [
          // 9:00 + 4 小时 = 13:00，排在午饭之后。
          _stage('装车', taskId: '搬家', order: 0, offset: 240),
        ],
      );

      expect(_orderOf(tester, ['搬家', '午饭', '搬家#装车']), ['搬家', '午饭', '搬家#装车']);
      expect(_timeOn(tester, '搬家#装车'), '13:00');
    });

    testAppWidgets('同一时刻时任务排在自己的阶段前面', (tester) async {
      await _pump(
        tester,
        tasks: [_task('搬家', start: 9 * 60)],
        stages: [_stage('第一步', taskId: '搬家', order: 0, offset: 0)],
      );

      expect(_orderOf(tester, ['搬家', '搬家#第一步']), ['搬家', '搬家#第一步']);
    });

    testAppWidgets('没排时间的阶段不成行 —— 没有时刻可排', (tester) async {
      await _pump(
        tester,
        tasks: [_task('搬家', start: 9 * 60)],
        stages: [_stage('待定', taskId: '搬家', order: 0)],
      );

      expect(find.byKey(TimelinePage.entryKey('搬家#待定')), findsNothing);
      expect(find.byKey(TimelinePage.entryKey('搬家')), findsOneWidget);
    });

    testAppWidgets('阶段行写着它属于谁', (tester) async {
      // 阶段与它的任务之间可能隔着别的任务的行，缩进说不清归属。
      await _pump(
        tester,
        tasks: [_task('搬家', start: 9 * 60)],
        stages: [_stage('装车', taskId: '搬家', order: 0, offset: 240)],
      );

      final row = find.byKey(TimelinePage.entryKey('搬家#装车'));
      expect(
        find.descendant(of: row, matching: find.text('装车')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('搬家')),
        findsOneWidget,
      );
    });

    testAppWidgets('重复任务的阶段读的是这一次的状态（FR-TASK-07）', (tester) async {
      await _pump(
        tester,
        tasks: [_task('晨跑', start: 6 * 60, rrule: 'RRULE:FREQ=DAILY')],
        stages: [_stage('热身', taskId: '晨跑', order: 0, offset: 0)],
        stageStates: [
          StageOccurrenceState(
            id: 'st1',
            taskId: '晨跑',
            stageId: '热身',
            occurrenceKey: OccurrenceKey.parse('2026-09-08T06:00'),
            status: TaskStatus.done,
          ),
        ],
      );

      // 今天那次的热身勾上了，明天那次没有 —— 两行读的是两份状态。
      final todayBox = tester.widget<DoneButton>(
        find.byKey(TimelinePage.stageDoneKey('晨跑#2026-09-08T06:00#热身')),
      );
      final tomorrowBox = tester.widget<DoneButton>(
        find.byKey(TimelinePage.stageDoneKey('晨跑#2026-09-09T06:00#热身')),
      );

      expect(todayBox.isDone, isTrue);
      expect(tomorrowBox.isDone, isFalse, reason: '明天那次读到了今天的状态');
    });
  });

  group('重复任务只出本次和下次（用户第 2 条意见）', () {
    testAppWidgets('每日规则就两行，不是十几行', (tester) async {
      await _pump(
        tester,
        tasks: [_task('吃药', start: 8 * 60, rrule: 'RRULE:FREQ=DAILY')],
      );

      expect(
        find.byWidgetPredicate((w) => w is TaskCard && w.data.title == '吃药'),
        findsNWidgets(2),
      );
    });

    testAppWidgets('逾期一堆时：逾期全留，今天起两条', (tester) async {
      // 直译成「最早的两次」的话，两条都在半个月前，**今天那次反而不见了**。
      // 所以那个「两次」只管今天起的那一侧，逾期的全留（用户的决定）。
      await _pump(
        tester,
        tasks: [
          _task(
            '吃药',
            date: const PlanDate(2026, 8, 26),
            start: 8 * 60,
            rrule: 'RRULE:FREQ=DAILY',
          ),
        ],
      );

      // 进来时定位在聚焦日（今天），逾期那一段在上面 —— **先滚上去**。
      // 不滚的话它们没被建出来，`findsNothing` 会是「懒加载」的假象，
      // 而不是「被折叠了」。
      await tester.drag(
        find.byKey(TimelinePage.scrollKey),
        const Offset(0, 4000),
      );
      await tester.pumpAndSettle();

      for (final d in [26, 27, 28]) {
        expect(
          find.byKey(TimelinePage.dateKey(PlanDate(2026, 8, d))),
          findsOneWidget,
          reason: '8/$d 那次被折叠了 —— 逾期的该全留',
        );
      }
    });

    testAppWidgets('今天起只出本次和下次，不出第三条', (tester) async {
      await _pump(
        tester,
        tasks: [_task('吃药', start: 8 * 60, rrule: 'RRULE:FREQ=DAILY')],
      );

      expect(find.byKey(TimelinePage.dateKey(_today)), findsOneWidget);
      expect(find.byKey(TimelinePage.dateKey(_tomorrow)), findsOneWidget);
      expect(
        find.byKey(TimelinePage.dateKey(_today.addDays(2))),
        findsNothing,
        reason: '今天起留的不止两条',
      );
    });
  });

  group('「现在」那条线', () {
    testAppWidgets('夹在中间时出现', (tester) async {
      await _pump(
        tester,
        tasks: [
          _task('上午', start: 8 * 60),
          _task('下午', start: 15 * 60),
        ],
        // 09:00 +08，正好夹在两条之间。
        now: () => DateTime.utc(2026, 9, 8, 1),
      );

      expect(find.byKey(TimelinePage.nowKey), findsOneWidget);
      final line = tester.getRect(find.byKey(TimelinePage.nowKey)).top;
      expect(
        line,
        greaterThan(
          tester.getRect(find.byKey(TimelinePage.entryKey('上午'))).top,
        ),
      );
      expect(
        line,
        lessThan(tester.getRect(find.byKey(TimelinePage.entryKey('下午'))).top),
      );
    });

    testAppWidgets('全在未来时不画 —— 画在最上面什么也没说明', (tester) async {
      await _pump(
        tester,
        tasks: [_task('下午', start: 15 * 60)],
        now: () => DateTime.utc(2026, 9, 8, 1),
      );

      expect(find.byKey(TimelinePage.nowKey), findsNothing);
    });

    testAppWidgets('跟着心跳走', (tester) async {
      final tick = StreamController<void>.broadcast();
      addTearDown(tick.close);
      var minute = 1; // 09:00 +08

      await _pump(
        tester,
        tasks: [
          _task('上午', start: 8 * 60),
          _task('中午', start: 11 * 60),
          _task('下午', start: 15 * 60),
        ],
        now: () => DateTime.utc(2026, 9, 8, minute),
        tick: tick.stream,
      );

      final before = tester.getRect(find.byKey(TimelinePage.nowKey)).top;
      minute = 5; // 13:00 +08，越过了「中午」
      tick.add(null);
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.byKey(TimelinePage.nowKey)).top,
        greaterThan(before),
        reason: '心跳到了但那条线没动',
      );
    });
  });

  group('空态与错误态', () {
    testAppWidgets('一件都没有时给空态', (tester) async {
      await _pump(tester, onCreateTask: ({date, minute}) {});

      expect(find.byKey(TimelinePage.emptyKey), findsOneWidget);
      expect(find.byType(EmptyIllustration), findsOneWidget);
    });

    testAppWidgets('空态的新建**不带日期** —— 议程不对着某一天', (tester) async {
      // 带上「今天」的话，「随时做」那一类任务就再也建不出来了。
      PlanDate? got;
      var called = false;
      await _pump(
        tester,
        onCreateTask: ({date, minute}) {
          called = true;
          got = date;
        },
      );

      await tester.tap(find.text('新建任务'));
      await tester.pumpAndSettle();

      expect(called, isTrue);
      expect(got, isNull);
    });

    testAppWidgets('没有新建回调时按钮不出现', (tester) async {
      await _pump(tester);
      expect(find.text('新建任务'), findsNothing);
    });

    testAppWidgets('读库失败给显式一屏，不是一片空', (tester) async {
      await _pump(
        tester,
        tasksStream: Stream<List<Task>>.error(StateError('boom')),
      );

      expect(find.byKey(TimelinePage.errorKey), findsOneWidget);
      expect(find.byKey(TimelinePage.emptyKey), findsNothing);
    });
  });

  group('交互', () {
    testAppWidgets('点任务行打开编辑页', (tester) async {
      String? opened;
      await _pump(
        tester,
        tasks: [_task('晨会', start: 9 * 60)],
        onEditTask: (id, {from}) => opened = id,
      );

      await tester.tap(find.byKey(TimelinePage.entryKey('晨会')));
      await tester.pumpAndSettle();

      expect(opened, '晨会');
    });
  });

  // 下面这一组走**真库**：勾完成、勾阶段都要落盘才算数，
  // 而假的数据源上「点了没反应」与「写成功了」长得一模一样。
  group('写路径（真库）', () {
    testAppWidgets('勾完成给撤销，而且提示会自己消失', (tester) async {
      // 议程里勾掉的行**当场消失**，没有撤销的话误触之后它去哪了都不知道。
      // 「会自己消失」是用户报的第 ② 条：带 action 的 SnackBar 默认
      // `persist: true`，`duration` 形同虚设。
      final harness = await _pumpReal(tester, [
        CreateTaskCommand(
          taskId: '晨会',
          title: '晨会',
          kind: TaskKind.single,
          timeZoneId: 'Asia/Shanghai',
          planDate: _realToday,
          startMinute: MinuteOfDay.of(9, 0),
        ),
      ]);

      await tester.tap(
        find.descendant(
          of: find.byKey(TimelinePage.entryKey('晨会')),
          matching: find.byKey(TaskCard.doneButtonKey),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('撤销'), findsOneWidget);
      expect(
        (await harness.db.select(harness.db.tasks).getSingle()).status,
        'done',
        reason: '提示弹了，但状态没落库',
      );

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('撤销'), findsNothing, reason: '提示永远不会消失');
    });

    testAppWidgets('撤销真的把它改回来', (tester) async {
      final harness = await _pumpReal(tester, [
        CreateTaskCommand(
          taskId: '晨会',
          title: '晨会',
          kind: TaskKind.single,
          timeZoneId: 'Asia/Shanghai',
          planDate: _realToday,
          startMinute: MinuteOfDay.of(9, 0),
        ),
      ]);

      await tester.tap(
        find.descendant(
          of: find.byKey(TimelinePage.entryKey('晨会')),
          matching: find.byKey(TaskCard.doneButtonKey),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('撤销'));
      await tester.pumpAndSettle();

      expect(
        (await harness.db.select(harness.db.tasks).getSingle()).status,
        'pending',
      );
      expect(find.byKey(TimelinePage.entryKey('晨会')), findsOneWidget);
    });

    testAppWidgets('不重复任务的阶段也勾得动（这条路一度是空的）', (tester) async {
      // `OccurrenceActions.setStageDone` 原本 `if (key == null) return;`
      // 就完了 —— 不重复任务的阶段只能进编辑页勾。时间轴把阶段摆成了
      // 独立的卡片，那张卡上的勾选框对一半的任务点了没反应。
      final harness = await _pumpReal(tester, [
        CreateTaskCommand(
          taskId: '搬家',
          title: '搬家',
          kind: TaskKind.staged,
          timeZoneId: 'Asia/Shanghai',
          planDate: _realToday,
          startMinute: MinuteOfDay.of(9, 0),
        ),
        const ReplaceStagesCommand(
          taskId: '搬家',
          stages: [
            StageSpec(
              id: '装车',
              title: '装车',
              orderIndex: 0,
              startOffsetMinutes: 0,
            ),
            StageSpec(
              id: '卸车',
              title: '卸车',
              orderIndex: 1,
              startOffsetMinutes: 120,
            ),
          ],
        ),
      ]);

      await tester.tap(find.byKey(TimelinePage.stageDoneKey('搬家#装车')));
      await tester.pumpAndSettle();

      final stages = await (harness.db.select(
        harness.db.stages,
      )..orderBy([(t) => OrderingTerm(expression: t.orderIndex)])).get();
      expect(stages.map((s) => s.status), [
        'done',
        'pending',
      ], reason: '要么没写进去，要么把另一个阶段也一起改了');
    });
  });
}

/// 真库版：命令先落盘，再把页面装起来。
///
/// 与 [_pump] 分开，是因为那边把 `visibleTasksProvider` 换成了一条
/// 静态流 —— 写进去的东西不会流回来，于是「勾了之后那一行消失」
/// 这类断言在假数据源上根本无从验起。
Future<Harness> _pumpReal(WidgetTester tester, List<TaskCommand> seed) async {
  await setScreenSize(tester, const Size(390, 844));
  final harness = appHarness();
  final container = ProviderContainer(
    overrides: [
      ...harness.overrides,
      // **心跳掐掉。** 真的那个每分钟响一次，用例结束时还剩着一个
      // 最多 60 秒的定时器 —— binding 判「树都拆了还有定时器在」，
      // 报的是「Pending timers」，与被测的行为毫无关系。
      // 上面那组走 `viewPipelineOverrides`，它自带这一条。
      minuteTickProvider.overrideWithValue(const Stream<void>.empty()),
    ],
  );
  addTearDown(container.dispose);
  for (final command in seed) {
    await container.read(taskCommandDispatcherProvider).dispatch(command);
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: TimelinePage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

/// 每次问都重新算的时钟。心跳到了要看见新的时刻。
final class _MovingClock implements Clock {
  const _MovingClock(this._now);

  final DateTime Function() _now;

  @override
  DateTime nowUtc() => _now();
}

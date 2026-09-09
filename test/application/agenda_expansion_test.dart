/// 议程的两级纯函数（view-specs §1）：
///
///  · `expandForAgenda` —— **哪些次该出现**（逾期一条、今天起补满两条）；
///  · `agendaEntries` —— **怎么摊成一列**（任务一行、排了时间的阶段各一行）。
///
/// 两个都不碰 provider，所以这一份不用搭树。界面把它们画出来没有
/// 在 `timeline_page_test.dart` 里另验。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/core/time/time_zone_resolver.dart';
import 'package:planning_assistant/domain/entities/occurrence.dart';
import 'package:planning_assistant/domain/entities/occurrence_override.dart';
import 'package:planning_assistant/domain/entities/stage.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/recurrence/recurrence_engine.dart';
import 'package:planning_assistant/domain/value_objects/occurrence_key.dart';
import 'package:planning_assistant/domain/value_objects/recurrence.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';
import 'package:planning_assistant/features/views/shared/application/occurrence_expansion.dart';
import 'package:planning_assistant/features/views/shared/application/task_occurrence.dart';
import 'package:planning_assistant/features/views/timeline/application/agenda_entries.dart';
import 'package:timezone/data/latest.dart' as tzdata;

const _today = PlanDate(2026, 9, 8);
const _engine = RecurrenceEngine(TzTimeZoneResolver());

Task _task(
  String id, {
  PlanDate? date = _today,
  int? start,
  PlanDate? endDate,
  int? end,
  String? rrule,
  bool isAllDay = false,
  TaskStatus status = TaskStatus.pending,
}) => Task(
  id: id,
  title: id,
  kind: TaskKind.single,
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
  int? offset,
  TaskStatus status = TaskStatus.pending,
}) => Stage(
  id: id,
  taskId: 't',
  title: id,
  orderIndex: 0,
  startOffsetMinutes: offset,
  status: status,
);

List<TaskOccurrence> _agenda(
  List<Task> tasks, {
  List<OccurrenceOverride> overrides = const [],
  bool includeSkipped = false,
  bool includeCompleted = false,
  Map<String, List<Stage>> stagesByTask = const {},
}) => expandForAgenda(
  tasks: tasks,
  overrides: overrides,
  today: _today,
  engine: _engine,
  includeSkipped: includeSkipped,
  includeCompleted: includeCompleted,
  stagesByTask: stagesByTask,
);

/// 每一行落在哪天。断言读起来像日历，不像一串 id。
List<PlanDate> _dates(List<TaskOccurrence> rows) => [
  for (final r in rows) r.planDate!,
];

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('哪些次该出现', () {
    test('没有日期的不进 —— 它不落在任何一条时间线上', () {
      expect(_agenda([_task('随时做', date: null)]), isEmpty);
    });

    test('不重复的未完成任务出一行，不看窗口', () {
      // 「明年那件事」也得看得见 —— 从议程里消失会让人以为它丢了。
      final rows = _agenda([_task('明年体检', date: const PlanDate(2027, 5, 1))]);
      expect(_dates(rows), [const PlanDate(2027, 5, 1)]);
    });

    test('做完的不进', () {
      expect(_agenda([_task('done', status: TaskStatus.done)]), isEmpty);
    });

    test('显式筛「已完成」时它回来 —— 这是它唯一的入口', () {
      expect(
        _agenda([
          _task('done', status: TaskStatus.done),
        ], includeCompleted: true),
        hasLength(1),
      );
    });
  });

  group('重复任务：本次和下次', () {
    test('一条都不逾期时，出今天和明天', () {
      final rows = _agenda([
        _task('吃药', start: 8 * 60, rrule: 'RRULE:FREQ=DAILY'),
      ]);
      expect(_dates(rows), [_today, _today.addDays(1)]);
    });

    test('逾期一堆时：逾期全留，今天起再留两条', () {
      // ## 这一条是这套规则存在的理由
      //
      // 直译成「最早的两次未完成」的话，出的是 8/26 与 8/27 ——
      // **今天那次反而看不见**，而议程要回答的正是「接下来是什么」。
      // 所以那个「两次」只管今天起的那一侧。
      //
      // 逾期的**全留**是用户的决定（中间有过一版只留最早一条）：
      // 漏了几次和漏了一次是两件事，折叠之后两者长得一样。
      final rows = _agenda([
        _task(
          '吃药',
          date: const PlanDate(2026, 8, 26),
          start: 8 * 60,
          rrule: 'RRULE:FREQ=DAILY',
        ),
      ]);

      // 8/26…9/7 共十三条逾期（窗口往回只到 8/25），加今天与明天。
      expect(_dates(rows).first, const PlanDate(2026, 8, 26));
      expect(_dates(rows).last, _today.addDays(1));
      expect(
        _dates(rows).where((d) => d.isBefore(_today)),
        hasLength(13),
        reason: '逾期的被折叠了',
      );
      expect(_dates(rows).where((d) => !d.isBefore(_today)), [
        _today,
        _today.addDays(1),
      ], reason: '今天起留的不是「本次和下次」两条');
    });

    test('**往回不是无限的** —— 逾期最多回溯 pastDays 天', () {
      // 「全留」的代价必须是有界的。规则从 2025 年就开始了，
      // 而窗口只往回看两周（`ListHorizon.pastDays`）。
      final rows = _agenda([
        _task(
          '吃药',
          date: const PlanDate(2025, 1, 1),
          start: 8 * 60,
          rrule: 'RRULE:FREQ=DAILY',
        ),
      ]);
      expect(_dates(rows).first, _today.addDays(-ListHorizon.pastDays));
    });

    test('逾期的补完之后，只剩今天起那两条', () {
      // 8/26、8/27 各写一条 done 的例外，于是最早的未完成就是今天。
      final rows = _agenda(
        [
          _task(
            '吃药',
            date: const PlanDate(2026, 8, 26),
            start: 8 * 60,
            rrule: 'RRULE:FREQ=DAILY',
          ),
        ],
        overrides: [
          for (final d in [
            const PlanDate(2026, 8, 26),
            const PlanDate(2026, 8, 27),
          ])
            OccurrenceOverride(
              taskId: '吃药',
              key: OccurrenceKey.parse('${d}T08:00'),
              action: OverrideAction.modify,
              status: OccurrenceStatus.done,
            ),
        ],
      );
      // 8/28…9/7 还是逾期的（那两天补上了，别的没有），所以第一条是 8/28。
      expect(_dates(rows).first, const PlanDate(2026, 8, 28));
      expect(
        _dates(rows).contains(const PlanDate(2026, 8, 26)),
        isFalse,
        reason: '标了完成的那次又回来了',
      );
      expect(_dates(rows).where((d) => !d.isBefore(_today)), [
        _today,
        _today.addDays(1),
      ]);
    });

    test('规则已经结束、只剩逾期的 → 那几条全在', () {
      // 漏了五次就显示五次。折叠的话，「我欠着几次」这个问题
      // 在界面上就没有答案了。
      final rows = _agenda([
        _task(
          '交房租',
          date: const PlanDate(2026, 9, 1),
          start: 9 * 60,
          rrule: 'RRULE:FREQ=DAILY;UNTIL=20260905T000000Z',
        ),
      ]);
      // 9/5 那次**不在**：`UNTIL` 是 UTC 的 9/5 00:00，而那次是
      // 本地 09:00 = UTC 01:00，越过了界。写期望时按本地日期数
      // 会多算一条 —— 这条注释就是那次算错留下的。
      expect(_dates(rows), [for (var d = 1; d <= 4; d++) PlanDate(2026, 9, d)]);
    });

    test('稀疏规则靠兜底窗口找到下一次，不整条消失', () {
      // 「每年 5 月 20 日」在九月时下一次在八个月后 ——
      // 只看常规窗口（60 天）的话它一行都没有。
      //
      // 今年那次（2026-05-20）**不出现**：逾期只回溯 14 天
      // （`ListHorizon.pastDays`），四个月前的那次不在窗口里。
      // 兜底窗口有两年，于是「本次和下次」就是明年和后年那两次。
      final rows = _agenda([
        _task(
          '纪念日',
          date: const PlanDate(2026, 5, 20),
          isAllDay: true,
          rrule: 'RRULE:FREQ=YEARLY',
        ),
      ]);
      expect(_dates(rows), [
        const PlanDate(2027, 5, 20),
        const PlanDate(2028, 5, 20),
      ]);
    });

    test('跳过的那次不出现，显式筛「已跳过」才回来（FR-TASK-05）', () {
      final skip = OccurrenceOverride.skip(
        taskId: '吃药',
        key: OccurrenceKey.parse('2026-09-08T08:00'),
      );
      final task = _task('吃药', start: 8 * 60, rrule: 'RRULE:FREQ=DAILY');

      expect(_dates(_agenda([task], overrides: [skip])), [
        _today.addDays(1),
        _today.addDays(2),
      ], reason: '跳过的那次还在');
      expect(
        _dates(_agenda([task], overrides: [skip], includeSkipped: true)).first,
        _today,
        reason: '筛了「已跳过」却找不回来',
      );
    });
  });

  group('摊成一列', () {
    test('按时刻排，跨天接着排', () {
      final rows = _agenda([
        _task('明天早上', date: _today.addDays(1), start: 8 * 60),
        _task('今天下午', start: 15 * 60),
        _task('今天上午', start: 9 * 60),
      ]);

      expect(agendaEntries(rows).map((e) => e.title), ['今天上午', '今天下午', '明天早上']);
    });

    test('阶段按自己的偏移各占一行', () {
      final rows = _agenda(
        [_task('t', start: 9 * 60)],
        stagesByTask: {
          't': [_stage('第二步', offset: 240), _stage('第一步', offset: 0)],
        },
      );

      final entries = agendaEntries(rows);
      expect(entries.map((e) => e.title), ['t', '第一步', '第二步']);
      expect(entries.map((e) => e.at.minute.value), [9 * 60, 9 * 60, 13 * 60]);
    });

    test('同一时刻时任务排在它自己的阶段前面', () {
      // 反过来的话「第一步」会出现在它所属的那条任务上面。
      final rows = _agenda(
        [_task('t', start: 9 * 60)],
        stagesByTask: {
          't': [_stage('第一步', offset: 0)],
        },
      );
      expect(agendaEntries(rows).first, isA<TaskEntry>());
    });

    test('没排时间的阶段不成行 —— 没有开始时刻可排', () {
      final rows = _agenda(
        [_task('t', start: 9 * 60)],
        stagesByTask: {
          't': [_stage('待定'), _stage('排了的', offset: 60)],
        },
      );
      expect(agendaEntries(rows).map((e) => e.title), ['t', '排了的']);
    });

    test('负偏移的阶段落到前一天，不是「当天第 -30 分」', () {
      // 整数除法在负数上截断而不是下取整，是这类换算最常见的一处错。
      final rows = _agenda(
        [_task('t', start: 30)],
        stagesByTask: {
          't': [_stage('前一晚', offset: -60)],
        },
      );

      final stage = agendaEntries(rows).whereType<StageEntry>().single;
      expect(stage.at.date, _today.addDays(-1));
      expect(stage.at.minute.value, 23 * 60 + 30);
    });

    test('全天的排在当天最前，但自称「全天」而不是 0 点', () {
      final rows = _agenda([
        _task('纪念日', isAllDay: true),
        _task('早八', start: 8 * 60),
      ]);

      final entries = agendaEntries(rows);
      expect(entries.map((e) => e.title), ['纪念日', '早八']);
      expect(entries.first.isAllDay, isTrue);
      expect(entries.first.at.minute, MinuteOfDay.midnight);
    });

    test('没有日期的行渲染不出来，直接挡掉（前置条件）', () {
      // `expandForAgenda` 已经不产出这种行，但这个函数是公开的纯函数，
      // 对任意输入都得成立 —— 它算不出「排在哪」。
      expect(
        agendaEntries([TaskOccurrence(task: _task('x', date: null))]),
        isEmpty,
      );
    });

    test('同一时刻的同类行按 id 定序 —— 每次刷新的顺序必须一致', () {
      final rows = _agenda([
        _task('乙', start: 9 * 60),
        _task('甲', start: 9 * 60),
      ]);
      final once = agendaEntries(rows).map((e) => e.id).toList();
      final twice = agendaEntries(rows.reversed.toList())
          .map((e) => e.id)
          .toList();
      expect(twice, once);
    });

    test('阶段行带着它那一次，点进去回得到（id 里三段都在）', () {
      final rows = _agenda(
        [_task('t', start: 9 * 60, rrule: 'RRULE:FREQ=DAILY')],
        stagesByTask: {
          't': [_stage('s', offset: 0)],
        },
      );

      final stage = agendaEntries(rows).whereType<StageEntry>().first;
      expect(stage.id, 't#2026-09-08T09:00#s');
      expect(stage.row.key, isNotNull);
    });
  });
}

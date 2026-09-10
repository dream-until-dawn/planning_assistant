/// 排期纯函数（notifications.md §10 的 N-01..N-13、FR-NOTI-01/02）。
///
/// ## 为什么这十三条全在这里
///
/// 设备上那三项（上限、时区变更、精确闹钟降级）**已经降级为不验收**
/// （§11，用户 2026-09-09 决定）。降级之后，M4 的正确性就全靠这一份 ——
/// 所以它不是「纯函数那一半的测试」，是**这块功能唯一的验收**。
///
/// 时区解析用真的 `TzTimeZoneResolver`（`timezone` 是纯 Dart 包），
/// 不打桩：跨时区、跨夏令时的算术正是这里最容易错的地方，
/// 打一个「加固定偏移」的桩等于把要测的东西替换掉了。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/local_wall_time.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/core/time/time_zone_resolver.dart';
import 'package:planning_assistant/domain/entities/occurrence.dart';
import 'package:planning_assistant/domain/entities/reminder.dart';
import 'package:planning_assistant/domain/services/notification_planner.dart';
import 'package:planning_assistant/domain/value_objects/occurrence_key.dart';
import 'package:planning_assistant/domain/value_objects/quiet_hours_behavior.dart';
import 'package:timezone/data/latest.dart' as tzdata;

const _zone = 'Asia/Shanghai';
const _resolver = TzTimeZoneResolver(fixedCurrentZoneId: _zone);

/// 2026-03-08 00:00 上海 = 2026-03-07 16:00 UTC。
final _now = DateTime.utc(2026, 3, 7, 16);

ReminderSettings _settings({
  bool enabled = true,
  MinuteOfDay? allDayMinute,
  bool quietHoursEnabled = false,
  int quietStart = 1320,
  int quietEnd = 420,
  QuietHoursBehavior quietBehavior = QuietHoursBehavior.postpone,
  int mergeThreshold = 3,
  int maxScheduled = 400,
}) => (
  enabled: enabled,
  defaultOffsetMinutes: -15,
  allDayMinute: allDayMinute ?? MinuteOfDay.of(9, 0),
  quietHoursEnabled: quietHoursEnabled,
  quietStart: MinuteOfDay(quietStart),
  quietEnd: MinuteOfDay(quietEnd),
  quietBehavior: quietBehavior,
  mergeThreshold: mergeThreshold,
  maxScheduled: maxScheduled,
);

/// 默认窗口：从 now 起 14 天。
ScheduleWindow _window({int days = 14}) =>
    (fromUtc: _now, toUtc: _now.add(Duration(days: days)));

LocalWallTime _wall(PlanDate d, int h, int m, {String zone = _zone}) =>
    LocalWallTime(date: d, minuteOfDay: MinuteOfDay.of(h, m), timeZoneId: zone);

Occurrence _occ({
  String taskId = 't1',
  PlanDate date = const PlanDate(2026, 3, 10),
  int hour = 9,
  int minute = 0,
  bool isAllDay = false,
  LocalWallTime? end,
  OccurrenceStatus status = OccurrenceStatus.pending,
  String? titleOverride,
  String zone = _zone,
}) {
  final start = isAllDay
      ? LocalWallTime(
          date: date,
          minuteOfDay: MinuteOfDay.midnight,
          timeZoneId: zone,
        )
      : _wall(date, hour, minute, zone: zone);
  return Occurrence(
    taskId: taskId,
    key: OccurrenceKey.fromWallTime(start, isAllDay: isAllDay),
    start: start,
    end: end,
    isAllDay: isAllDay,
    status: status,
    titleOverride: titleOverride,
  );
}

Reminder _rel(int offsetMinutes, {String id = 'r1', String taskId = 't1'}) =>
    Reminder(
      id: id,
      taskId: taskId,
      kind: ReminderKind.relativeToStart,
      offsetMinutes: offsetMinutes,
    );

List<PlannedNotification> _plan(
  List<ReminderOnOccurrence> pairs, {
  ReminderSettings? settings,
  ScheduleWindow? window,
  DateTime? now,
}) => planNotifications(
  pairs: pairs,
  settings: settings ?? _settings(),
  nowUtc: now ?? _now,
  window: window ?? _window(),
  zones: _resolver,
);

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('FR-NOTI-01 / N-01 相对提醒跟着任务时间走', () {
    test('提前 15 分钟：09:00 的任务排在 08:45', () {
      final out = _plan([
        (occurrence: _occ(), reminder: _rel(-15), title: '开会'),
      ]);

      expect(out, hasLength(1));
      expect(out.single.trigger.minuteOfDay, MinuteOfDay.of(8, 45));
      expect(out.single.trigger.date, const PlanDate(2026, 3, 10));
      expect(out.single.title, '开会');
    });

    test('任务时间改到 14:00，触发时刻跟着变', () {
      // 这条才是 N-01 说的那件事：**同一条提醒**在时间不同的两次发生上
      // 算出不同的触发时刻。只验一次的话，一个把偏移写死的实现也能过。
      final out = _plan([
        (occurrence: _occ(hour: 14), reminder: _rel(-15), title: '开会'),
      ]);
      expect(out.single.trigger.minuteOfDay, MinuteOfDay.of(13, 45));
    });

    test('偏移跨到前一天：00:10 的任务提前 30 分钟', () {
      final out = _plan([
        (
          occurrence: _occ(
            date: const PlanDate(2026, 3, 11),
            hour: 0,
            minute: 10,
          ),
          reminder: _rel(-30),
          title: '早班',
        ),
      ]);
      expect(out.single.trigger.date, const PlanDate(2026, 3, 10));
      expect(out.single.trigger.minuteOfDay, MinuteOfDay.of(23, 40));
    });

    test('这一次改过标题，通知上用那一个', () {
      final out = _plan([
        (
          occurrence: _occ(titleOverride: '临时换成评审'),
          reminder: _rel(-15),
          title: '开会',
        ),
      ]);
      expect(out.single.title, '临时换成评审');
    });
  });

  group('FR-NOTI-02 / N-02 重复任务：窗口内不多不少', () {
    test('每天一次、窗口 14 天 → 排 14 条', () {
      final pairs = [
        for (var i = 0; i < 30; i++)
          (
            occurrence: _occ(date: const PlanDate(2026, 3, 8).addDays(i)),
            reminder: _rel(0),
            title: '吃药',
          ),
      ];
      final out = _plan(pairs);

      expect(out, hasLength(14), reason: '窗口外的也排了，或者边界少算了一天');
      expect(out.first.trigger.date, const PlanDate(2026, 3, 8));
      expect(out.last.trigger.date, const PlanDate(2026, 3, 21));
    });

    test('窗口右端是开区间：正好落在 toUtc 的那条不排', () {
      // 闭区间的话，每次续排都会在窗口边界上重复排出同一条。
      //
      // **边界要真的落在 toUtc 上**：第一版这里挑了个「三天后」当右端，
      // 而那条提醒的触发时刻在它之前 —— 于是无论开区间闭区间都排得出来，
      // 这条用例验的其实是「窗口内的会排」。触发时刻 2026-03-10 00:00
      // 上海 = 2026-03-09T16:00Z，右端就取这一刻。
      const pair = (date: PlanDate(2026, 3, 10), hour: 0);
      final boundary = DateTime.utc(2026, 3, 9, 16);
      List<PlannedNotification> planTo(DateTime toUtc) => _plan(
        [
          (
            occurrence: _occ(date: pair.date, hour: pair.hour),
            reminder: _rel(0),
            title: '边界',
          ),
        ],
        window: (fromUtc: _now, toUtc: toUtc),
      );

      expect(
        planTo(boundary.add(const Duration(minutes: 1))),
        hasLength(1),
        reason: '前提：右端往后挪一分钟就该排得出来，否则这条验的不是边界',
      );
      expect(planTo(boundary), isEmpty);
    });
  });

  group('N-03 超上限：按时刻升序截断，留最近的', () {
    test('上限 5 时只留最早的 5 条', () {
      final pairs = [
        for (var i = 0; i < 12; i++)
          (
            occurrence: _occ(date: const PlanDate(2026, 3, 8).addDays(i)),
            reminder: _rel(0),
            title: '第 $i 天',
          ),
      ];
      final out = _plan(pairs, settings: _settings(maxScheduled: 5));

      expect(out, hasLength(5));
      expect(out.first.trigger.date, const PlanDate(2026, 3, 8));
      expect(
        out.last.trigger.date,
        const PlanDate(2026, 3, 12),
        reason: '丢的该是最远的那几条，不是最近的',
      );
    });

    test('没超上限时一条都不丢', () {
      final pairs = [
        for (var i = 0; i < 3; i++)
          (
            occurrence: _occ(date: const PlanDate(2026, 3, 8).addDays(i)),
            reminder: _rel(0),
            title: '第 $i 天',
          ),
      ];
      expect(_plan(pairs, settings: _settings(maxScheduled: 5)), hasLength(3));
    });
  });

  group('FR-CFG-05 / N-04/05/06 免打扰 22:00–07:00，左闭右开', () {
    ReminderSettings quiet({
      QuietHoursBehavior behavior = QuietHoursBehavior.postpone,
    }) => _settings(quietHoursEnabled: true, quietBehavior: behavior);

    List<PlannedNotification> at(int h, int m) => _plan([
      (occurrence: _occ(hour: h, minute: m), reminder: _rel(0), title: '提醒'),
    ], settings: quiet());

    test('N-04 23:30 → 顺延到**第二天** 07:00', () {
      final out = at(23, 30);
      expect(out.single.trigger.minuteOfDay, MinuteOfDay.of(7, 0));
      expect(
        out.single.trigger.date,
        const PlanDate(2026, 3, 11),
        reason: '晚上那半段的结束在第二天早上，不是当天早上',
      );
    });

    test('N-05 06:59 → 顺延到**当天** 07:00', () {
      final out = at(6, 59);
      expect(out.single.trigger.minuteOfDay, MinuteOfDay.of(7, 0));
      expect(
        out.single.trigger.date,
        const PlanDate(2026, 3, 10),
        reason: '凌晨那半段被推迟了一整天',
      );
    });

    test('N-06 07:00 整 → **不**顺延（右开）', () {
      final out = at(7, 0);
      expect(out.single.trigger.minuteOfDay, MinuteOfDay.of(7, 0));
      expect(out.single.trigger.date, const PlanDate(2026, 3, 10));
    });

    test('22:00 整 → 顺延（左闭）', () {
      final out = at(22, 0);
      expect(out.single.trigger.date, const PlanDate(2026, 3, 11));
      expect(out.single.trigger.minuteOfDay, MinuteOfDay.of(7, 0));
    });

    test('时段外的不动', () {
      final out = at(15, 0);
      expect(out.single.trigger.minuteOfDay, MinuteOfDay.of(15, 0));
    });

    test('suppress：时段内的直接丢掉', () {
      final out = _plan([
        (occurrence: _occ(hour: 23, minute: 30), reminder: _rel(0), title: 'x'),
      ], settings: quiet(behavior: QuietHoursBehavior.suppress));
      expect(out, isEmpty);
    });

    test('对照组：免打扰关着时，23:30 原样排', () {
      // 少了它，一个「永远不顺延」的实现在上面那几条里也能过 ——
      // 它们全都开着免打扰。
      final out = _plan([
        (occurrence: _occ(hour: 23, minute: 30), reminder: _rel(0), title: 'x'),
      ]);
      expect(out.single.trigger.minuteOfDay, MinuteOfDay.of(23, 30));
    });

    test('不跨零点的时段（13:00–14:00）也对', () {
      final s = _settings(
        quietHoursEnabled: true,
        quietStart: 780,
        quietEnd: 840,
      );
      final out = _plan([
        (occurrence: _occ(hour: 13, minute: 30), reminder: _rel(0), title: 'x'),
      ], settings: s);
      expect(
        out.single.trigger.date,
        const PlanDate(2026, 3, 10),
        reason: '不跨零点却顺延到了第二天',
      );
      expect(out.single.trigger.minuteOfDay, MinuteOfDay.of(14, 0));
    });
  });

  group('N-07/N-08/N-09 不该排的', () {
    test('N-07 跳过的那一次不排', () {
      expect(
        _plan([
          (
            occurrence: _occ(status: OccurrenceStatus.skipped),
            reminder: _rel(-15),
            title: 'x',
          ),
        ]),
        isEmpty,
      );
    });

    test('N-08 已完成的那一次不排', () {
      expect(
        _plan([
          (
            occurrence: _occ(status: OccurrenceStatus.done),
            reminder: _rel(-15),
            title: 'x',
          ),
        ]),
        isEmpty,
      );
    });

    test('进行中的照排 —— 只有 done/skipped 才停', () {
      expect(
        _plan([
          (
            occurrence: _occ(status: OccurrenceStatus.inProgress),
            reminder: _rel(-15),
            title: 'x',
          ),
        ]),
        hasLength(1),
      );
    });

    test('N-09 任务删了：调用方不喂这一条，结果自然是空', () {
      expect(_plan(const []), isEmpty);
    });

    test('关掉的提醒不排，但**留在库里**', () {
      const off = Reminder(
        id: 'r1',
        taskId: 't1',
        kind: ReminderKind.relativeToStart,
        offsetMinutes: -15,
        isEnabled: false,
      );
      expect(_plan([(occurrence: _occ(), reminder: off, title: 'x')]), isEmpty);
    });

    test('总开关关掉 → 一条都不排', () {
      expect(
        _plan([
          (occurrence: _occ(), reminder: _rel(-15), title: 'x'),
        ], settings: _settings(enabled: false)),
        isEmpty,
      );
    });

    test('已经过去的时刻不排 —— 系统会当场弹出来', () {
      final out = _plan(
        [
          (
            occurrence: _occ(date: const PlanDate(2026, 3, 1)),
            reminder: _rel(0),
            title: 'x',
          ),
        ],
        window: (
          fromUtc: _now.subtract(const Duration(days: 30)),
          toUtc: _now.add(const Duration(days: 14)),
        ),
      );
      expect(out, isEmpty);
    });
  });

  group('N-12 时区变了，墙钟不变', () {
    test('同一条提醒在上海与伦敦：墙钟都是 08:45，绝对时刻差 8 小时', () {
      final sh = _plan([(occurrence: _occ(), reminder: _rel(-15), title: 'x')])
          .single;

      final lon = planNotifications(
        pairs: [
          (
            occurrence: _occ(zone: 'Europe/London'),
            reminder: _rel(-15),
            title: 'x',
          ),
        ],
        settings: _settings(),
        nowUtc: _now,
        window: _window(),
        zones: const TzTimeZoneResolver(fixedCurrentZoneId: 'Europe/London'),
      ).single;

      expect(sh.trigger.minuteOfDay, lon.trigger.minuteOfDay, reason: '墙钟该一样');
      expect(
        lon.triggerUtc.difference(sh.triggerUtc),
        const Duration(hours: 8),
        reason: '3 月 10 日伦敦还没进夏令时，与上海差 8 小时',
      );
    });
  });

  group('N-13 同一刻合并成摘要', () {
    List<ReminderOnOccurrence> sameInstant(int n) => [
      for (var i = 0; i < n; i++)
        (
          occurrence: _occ(taskId: 't$i'),
          reminder: _rel(0, id: 'r$i', taskId: 't$i'),
          title: '第 $i 件',
        ),
    ];

    test('5 条、阈值 3 → 合成 1 条摘要', () {
      final out = _plan(sameInstant(5));
      expect(out, hasLength(1));
      expect(out.single.isDigest, isTrue);
      expect(out.single.taskIds, hasLength(5));
      expect(out.single.title, contains('5'));
    });

    test('**正好 3 条不合并**（阈值是「超过」不是「达到」）', () {
      final out = _plan(sameInstant(3));
      expect(out, hasLength(3));
      expect(out.every((p) => !p.isDigest), isTrue);
    });

    test('不同刻的不会被合到一起', () {
      final out = _plan([
        (
          occurrence: _occ(taskId: 'a', hour: 9),
          reminder: _rel(0, taskId: 'a'),
          title: 'a',
        ),
        (
          occurrence: _occ(taskId: 'b', hour: 10),
          reminder: _rel(0, taskId: 'b'),
          title: 'b',
        ),
        (
          occurrence: _occ(taskId: 'c', hour: 11),
          reminder: _rel(0, taskId: 'c'),
          title: 'c',
        ),
        (
          occurrence: _occ(taskId: 'd', hour: 12),
          reminder: _rel(0, taskId: 'd'),
          title: 'd',
        ),
      ], settings: _settings(mergeThreshold: 1));
      expect(out, hasLength(4));
      expect(out.every((p) => !p.isDigest), isTrue);
    });

    test('摘要的 key 由时刻派生，不由某一条任务派生', () {
      // 挂在 group.first 上的话，那条任务一改（或被删），
      // 整条摘要的身份就变了 —— 而它代表的是「这一刻的全部安排」。
      final a = _plan(sameInstant(5)).single.key;
      final b = _plan(sameInstant(5).reversed.toList()).single.key;
      expect(a, b, reason: '喂进来的顺序变了，摘要的身份就跟着变了');
    });
  });

  group('触发时刻的基准', () {
    test('全天任务用配置里的绝对时刻，偏移照加', () {
      final out = _plan([
        (occurrence: _occ(isAllDay: true), reminder: _rel(-15), title: 'x'),
      ]);
      expect(out.single.trigger.minuteOfDay, MinuteOfDay.of(8, 45));
    });

    test('全天任务的提醒时刻可配', () {
      final out = _plan([
        (occurrence: _occ(isAllDay: true), reminder: _rel(0), title: 'x'),
      ], settings: _settings(allDayMinute: MinuteOfDay.of(12, 0)));
      expect(out.single.trigger.minuteOfDay, MinuteOfDay.of(12, 0));
    });

    test('relativeToEnd 用结束时刻', () {
      final out = _plan([
        (
          occurrence: _occ(end: _wall(const PlanDate(2026, 3, 10), 17, 0)),
          reminder: const Reminder(
            id: 'r1',
            taskId: 't1',
            kind: ReminderKind.relativeToEnd,
            offsetMinutes: -60,
          ),
          title: 'x',
        ),
      ]);
      expect(out.single.trigger.minuteOfDay, MinuteOfDay.of(16, 0));
    });

    test('relativeToEnd 但没有结束 → 退回开始，不去猜', () {
      final out = _plan([
        (
          occurrence: _occ(),
          reminder: const Reminder(
            id: 'r1',
            taskId: 't1',
            kind: ReminderKind.relativeToEnd,
            offsetMinutes: -60,
          ),
          title: 'x',
        ),
      ]);
      expect(out.single.trigger.minuteOfDay, MinuteOfDay.of(8, 0));
    });

    test('absolute 与任务时间无关', () {
      final out = _plan([
        (
          occurrence: _occ(hour: 9),
          reminder: Reminder(
            id: 'r1',
            taskId: 't1',
            kind: ReminderKind.absolute,
            absoluteDate: const PlanDate(2026, 3, 12),
            absoluteMinute: MinuteOfDay.of(20, 30),
          ),
          title: 'x',
        ),
      ]);
      expect(out.single.trigger.date, const PlanDate(2026, 3, 12));
      expect(out.single.trigger.minuteOfDay, MinuteOfDay.of(20, 30));
    });
  });

  group('key 的稳定性', () {
    test('同样的输入算出同样的 key —— 续排不该全删全建', () {
      final a = _plan([(occurrence: _occ(), reminder: _rel(-15), title: 'x')])
          .single
          .key;
      final b = _plan([(occurrence: _occ(), reminder: _rel(-15), title: 'x')])
          .single
          .key;
      expect(a, b);
    });

    test('不同的发生算出不同的 key', () {
      final out = _plan([
        (
          occurrence: _occ(date: const PlanDate(2026, 3, 10)),
          reminder: _rel(0),
          title: 'x',
        ),
        (
          occurrence: _occ(date: const PlanDate(2026, 3, 11)),
          reminder: _rel(0),
          title: 'x',
        ),
      ]);
      expect(out.map((p) => p.key).toSet(), hasLength(2));
    });
  });
}

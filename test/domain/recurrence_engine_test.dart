/// 重复引擎的黄金用例表。
///
/// 对应 docs/02-domain/recurrence-engine.md §6 的 R-01..R-28。
/// **期望值来自 RFC 5545 或手算**，每条注明依据（testing-strategy §1.1）。
///
/// 用例编号与文档一一对应，改文档时这里必须同步 —— 编号本身就是可追溯性。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/local_wall_time.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/core/time/time_zone_resolver.dart';
import 'package:planning_assistant/domain/entities/occurrence.dart';
import 'package:planning_assistant/domain/entities/occurrence_override.dart';
import 'package:planning_assistant/domain/recurrence/recurrence_engine.dart';
import 'package:planning_assistant/domain/value_objects/occurrence_key.dart';
import 'package:planning_assistant/domain/value_objects/recurrence.dart';
import 'package:timezone/data/latest.dart' as tzdata;

const _engine = RecurrenceEngine(TzTimeZoneResolver());
const _zone = 'Asia/Shanghai';
const _taskId = 't1';

LocalWallTime wall(
  int y,
  int mo,
  int d, [
  int h = 9,
  int mi = 0,
  String z = _zone,
]) => LocalWallTime(
  date: PlanDate(y, mo, d),
  minuteOfDay: MinuteOfDay.of(h, mi),
  timeZoneId: z,
);

DateRange win(String from, String to) =>
    DateRange(PlanDate.parse(from), PlanDate.parse(to));

RecurrenceContext ctx(
  String rrule, {
  LocalWallTime? dtStart,
  bool isAllDay = false,
  int? durationMinutes,
}) => RecurrenceContext(
  taskId: _taskId,
  dtStart: dtStart ?? wall(2026, 9, 7),
  isAllDay: isAllDay,
  recurrence: rrule.isEmpty ? null : Recurrence.parse(rrule),
  durationMinutes: durationMinutes,
);

/// 展开并取日期串，便于与手算期望比对。
List<String> days(
  RecurrenceContext c,
  DateRange window, {
  List<OccurrenceOverride> overrides = const [],
}) => _engine
    .expand(context: c, window: window, overrides: overrides)
    .map((o) => o.start.date.toString())
    .toList();

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('6.1 基础展开', () {
    test('R-01 FREQ=DAILY 从 9/7 起，窗口 9/7–9/13 → 7 个实例', () {
      expect(
        days(ctx('RRULE:FREQ=DAILY'), win('2026-09-07', '2026-09-13')),
        hasLength(7),
      );
    });

    test('R-02 FREQ=DAILY;INTERVAL=3 → 9/7, 9/10, 9/13', () {
      expect(
        days(
          ctx('RRULE:FREQ=DAILY;INTERVAL=3'),
          win('2026-09-07', '2026-09-13'),
        ),
        ['2026-09-07', '2026-09-10', '2026-09-13'],
      );
    });

    test('R-03 FREQ=WEEKLY;BYDAY=MO,WE,FR 只落在周一三五', () {
      // 手算：2026-09-07 是周一（2026-01-01 周四 → 09-07 是第 250 天，
      // (250-1)%7=249%7=4 → 周四+4=周一）。
      final result = days(
        ctx('RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR'),
        win('2026-09-07', '2026-09-13'),
      );
      expect(result, ['2026-09-07', '2026-09-09', '2026-09-11']);
      for (final d in result) {
        expect(
          PlanDate.parse(d).weekday,
          isIn([DateTime.monday, DateTime.wednesday, DateTime.friday]),
        );
      }
    });

    test('R-04 COUNT=3 恰好 3 个，第 4 个不出现', () {
      expect(
        days(ctx('RRULE:FREQ=DAILY;COUNT=3'), win('2026-09-07', '2026-09-30')),
        ['2026-09-07', '2026-09-08', '2026-09-09'],
      );
    });

    test('R-05 UNTIL 恰为某实例时刻 → 该实例被包含（RFC 闭区间）', () {
      // RFC 5545 §3.3.10 原文（已回原始 RFC 逐字核对）：
      // "bounds the recurrence rule in an inclusive manner"
      // DTSTART 09:00 Asia/Shanghai(+8) → UNTIL 取 09-10 09:00 = 09-10T01:00Z
      expect(
        days(
          ctx('RRULE:FREQ=DAILY;UNTIL=20260910T010000Z'),
          win('2026-09-07', '2026-09-30'),
        ),
        ['2026-09-07', '2026-09-08', '2026-09-09', '2026-09-10'],
      );
    });

    test('R-06 UNTIL 早于实例 1 分钟 → 排除该实例', () {
      expect(
        days(
          ctx('RRULE:FREQ=DAILY;UNTIL=20260910T005900Z'),
          win('2026-09-07', '2026-09-30'),
        ),
        ['2026-09-07', '2026-09-08', '2026-09-09'],
      );
    });
  });

  group('6.1b UNTIL 的时区边界（§2.2 的直接验收）', () {
    // 用户意图统一是「重复到 2026-09-30 当天为止（含）」。
    // 存储的 UNTIL 由 untilForEndDate() 生成 —— 取该日**日终**再换算成真 UTC。

    ({List<String> dates, String until}) untilCase(
      String zone,
      int hour,
      int minute,
    ) {
      final base = Recurrence.parse('RRULE:FREQ=DAILY');
      final rule = _engine.withEndDate(
        base,
        PlanDate.parse('2026-09-30'),
        zone,
      );
      final c = RecurrenceContext(
        taskId: _taskId,
        dtStart: wall(2026, 9, 25, hour, minute, zone),
        isAllDay: false,
        recurrence: rule,
      );
      return (
        dates: days(c, win('2026-09-01', '2026-10-31')),
        until: rule.canonical,
      );
    }

    test('R-07 Pacific/Kiritimati (UTC+14) 每天 23:00 → 9/30 那次存在', () {
      final r = untilCase('Pacific/Kiritimati', 23, 0);
      expect(r.dates.last, '2026-09-30', reason: '东侧极端时区最容易把最后一次丢掉');
      expect(
        r.until,
        contains('UNTIL=20260930T095959Z'),
        reason: '日终 23:59:59 +14 → 同日 09:59:59 UTC',
      );
    });

    test('R-08 America/New_York (UTC-4) 每天 01:00 → 不多出 10/1', () {
      final r = untilCase('America/New_York', 1, 0);
      expect(r.dates.last, '2026-09-30', reason: '西侧时区最容易多出一次');
      expect(r.dates, isNot(contains('2026-10-01')));
    });

    test('R-09 Pacific/Niue (UTC-11) 每天 00:30 → 9/30 在、10/1 不在', () {
      final r = untilCase('Pacific/Niue', 0, 30);
      expect(r.dates, contains('2026-09-30'));
      expect(r.dates, isNot(contains('2026-10-01')));
    });

    test('R-09b Asia/Shanghai 每天 23:30 → 9/30 那次存在', () {
      expect(untilCase('Asia/Shanghai', 23, 30).dates.last, '2026-09-30');
    });

    test('R-09c 对照组：改用 COUNT 表达时四个时区结果完全一致', () {
      // COUNT 与时区无关。若 UNTIL 组分叉而 COUNT 组一致，
      // 就能直接定位到「换算」而不是「展开」出了问题。
      final counts = <String, List<String>>{};
      for (final zone in [
        'Pacific/Kiritimati',
        'America/New_York',
        'Pacific/Niue',
        'Asia/Shanghai',
      ]) {
        counts[zone] = days(
          RecurrenceContext(
            taskId: _taskId,
            dtStart: wall(2026, 9, 25, 23, 0, zone),
            isAllDay: false,
            recurrence: Recurrence.parse('RRULE:FREQ=DAILY;COUNT=6'),
          ),
          win('2026-09-01', '2026-10-31'),
        );
      }
      final first = counts.values.first;
      for (final e in counts.entries) {
        expect(e.value, first, reason: e.key);
      }
      expect(first, hasLength(6));
    });

    test('R-09f 「到 9/10 止」的早晨任务必须包含 9/10（日终语义）', () {
      // 若把结束日期当成该日 00:00，07:00 的任务会少掉 9/10 那次 ——
      // 而那是绝大多数任务的形态（recurrence-engine §6.1c）。
      final rule = _engine.withEndDate(
        Recurrence.parse('RRULE:FREQ=DAILY'),
        PlanDate.parse('2026-09-10'),
        _zone,
      );
      final c = RecurrenceContext(
        taskId: _taskId,
        dtStart: wall(2026, 9, 7, 7, 0),
        isAllDay: false,
        recurrence: rule,
      );
      expect(days(c, win('2026-09-01', '2026-09-30')), [
        '2026-09-07',
        '2026-09-08',
        '2026-09-09',
        '2026-09-10',
      ]);
    });

    test('R-09g 零点开始的任务同样包含结束日', () {
      final rule = _engine.withEndDate(
        Recurrence.parse('RRULE:FREQ=DAILY'),
        PlanDate.parse('2026-09-10'),
        _zone,
      );
      final c = RecurrenceContext(
        taskId: _taskId,
        dtStart: wall(2026, 9, 7, 0, 0),
        isAllDay: false,
        recurrence: rule,
      );
      expect(days(c, win('2026-09-01', '2026-09-30')).last, '2026-09-10');
    });

    test('R-09h UTC+14 的 23:00 任务「到 9/10 止」同样包含 9/10', () {
      final rule = _engine.withEndDate(
        Recurrence.parse('RRULE:FREQ=DAILY'),
        PlanDate.parse('2026-09-10'),
        'Pacific/Kiritimati',
      );
      final c = RecurrenceContext(
        taskId: _taskId,
        dtStart: wall(2026, 9, 7, 23, 0, 'Pacific/Kiritimati'),
        isAllDay: false,
        recurrence: rule,
      );
      expect(days(c, win('2026-09-01', '2026-09-30')).last, '2026-09-10');
    });

    test('withEndDate 会清掉 COUNT —— RFC 禁止两者共存', () {
      final r = _engine.withEndDate(
        Recurrence.parse('RRULE:FREQ=DAILY;COUNT=5'),
        PlanDate.parse('2026-09-10'),
        _zone,
      );
      expect(r.canonical, contains('UNTIL='));
      expect(r.canonical, isNot(contains('COUNT=')));
    });
  });

  group('6.2 月末与闰年', () {
    test('R-10 BYMONTHDAY=31 跳过没有 31 号的月份，不顺延', () {
      // RFC 5545 §3.3.10：落在无效日期上的实例被忽略。
      expect(
        days(
          ctx('RRULE:FREQ=MONTHLY;BYMONTHDAY=31', dtStart: wall(2026, 1, 31)),
          win('2026-01-01', '2026-12-31'),
        ),
        // 手算：2026 年有 31 天的月份是 1/3/5/7/8/10/12
        [
          '2026-01-31',
          '2026-03-31',
          '2026-05-31',
          '2026-07-31',
          '2026-08-31',
          '2026-10-31',
          '2026-12-31',
        ],
        reason: '2/4/6/9/11 月无 31 号，必须缺席而非顺延',
      );
    });

    test('R-11 BYMONTHDAY=-1 是「每月最后一天」，2 月给 28/29', () {
      expect(
        days(
          ctx('RRULE:FREQ=MONTHLY;BYMONTHDAY=-1', dtStart: wall(2026, 1, 31)),
          win('2026-01-01', '2026-04-30'),
        ),
        ['2026-01-31', '2026-02-28', '2026-03-31', '2026-04-30'],
      );
      expect(
        days(
          ctx('RRULE:FREQ=MONTHLY;BYMONTHDAY=-1', dtStart: wall(2028, 1, 31)),
          win('2028-02-01', '2028-02-29'),
        ),
        ['2028-02-29'],
        reason: '闰年',
      );
    });

    test('R-12 YEARLY 2/29 只在闰年出现', () {
      expect(
        days(
          ctx(
            'RRULE:FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=29',
            dtStart: wall(2024, 2, 29),
          ),
          win('2024-01-01', '2032-12-31'),
        ),
        ['2024-02-29', '2028-02-29', '2032-02-29'],
      );
    });

    test('R-13 BYDAY=-1FR 每月最后一个周五，跨年正确', () {
      // 手算 2026：1 月 1 日周四 → 周五为 2,9,16,23,30，末个 = 1-30
      // 2 月 1 日周日 → 6,13,20,27，末个 = 2-27；3 月同样 3-27；4 月 1 日周三 → 4-24
      expect(
        days(
          ctx('RRULE:FREQ=MONTHLY;BYDAY=-1FR', dtStart: wall(2026, 1, 30)),
          win('2026-01-01', '2026-04-30'),
        ),
        ['2026-01-30', '2026-02-27', '2026-03-27', '2026-04-24'],
      );
    });
  });

  group('6.3 例外与覆盖', () {
    OccurrenceOverride skip(String key) =>
        OccurrenceOverride.skip(taskId: _taskId, key: OccurrenceKey.parse(key));

    test('R-20 skip 掉窗口内一次 → 该次消失，其余不变', () {
      final r = days(
        ctx('RRULE:FREQ=DAILY'),
        win('2026-09-07', '2026-09-10'),
        overrides: [skip('2026-09-08T09:00')],
      );
      expect(r, ['2026-09-07', '2026-09-09', '2026-09-10']);
    });

    test('R-21 modify 改标题 → 只有该次标题变', () {
      final out = _engine.expand(
        context: ctx('RRULE:FREQ=DAILY'),
        window: win('2026-09-07', '2026-09-09'),
        overrides: [
          OccurrenceOverride(
            taskId: _taskId,
            key: OccurrenceKey.parse('2026-09-08T09:00'),
            action: OverrideAction.modify,
            titleOverride: '这一次不一样',
          ),
        ],
      );
      expect(out.map((o) => o.titleOverride), [null, '这一次不一样', null]);
    });

    test('R-22 把窗口外的一次挪进窗口 → 该次出现（最容易漏的一条）', () {
      // 10/5 那次被挪到 9/8。展开 9 月的规则不会产生 10/5，
      // 若不做第 4 步补齐，这一次会凭空消失。
      final out = _engine.expand(
        context: ctx('RRULE:FREQ=DAILY'),
        window: win('2026-09-07', '2026-09-09'),
        overrides: [
          OccurrenceOverride(
            taskId: _taskId,
            key: OccurrenceKey.parse('2026-10-05T09:00'),
            action: OverrideAction.modify,
            planDateOverride: PlanDate.parse('2026-09-08'),
          ),
        ],
      );
      final moved = out.where((o) => o.key.value == '2026-10-05T09:00');
      expect(moved, hasLength(1), reason: '被挪进窗口的那一次必须出现');
      expect(moved.single.start.date, PlanDate.parse('2026-09-08'));
      expect(moved.single.isMoved, isTrue);
      // key 保持原始时刻，否则规则再次展开时 10/5 会重影
      expect(moved.single.key.value, '2026-10-05T09:00');
    });

    test('R-23 把窗口内的一次挪出窗口 → 原位不留残影', () {
      final r = days(
        ctx('RRULE:FREQ=DAILY'),
        win('2026-09-07', '2026-09-09'),
        overrides: [
          OccurrenceOverride(
            taskId: _taskId,
            key: OccurrenceKey.parse('2026-09-08T09:00'),
            action: OverrideAction.modify,
            planDateOverride: PlanDate.parse('2026-10-20'),
          ),
        ],
      );
      expect(r, ['2026-09-07', '2026-09-09'], reason: '9/8 的位置不得留残影');
    });

    test('R-24 同一次先 modify 再 skip → 最终不出现', () {
      // 唯一索引保证一次发生最多一条例外，因此「最终态」就是那一条。
      final r = days(
        ctx('RRULE:FREQ=DAILY'),
        win('2026-09-07', '2026-09-09'),
        overrides: [skip('2026-09-08T09:00')],
      );
      expect(r, isNot(contains('2026-09-08')));
    });

    test('R-25 完成某一次只影响该次，其它次仍为 pending', () {
      final out = _engine.expand(
        context: ctx('RRULE:FREQ=DAILY'),
        window: win('2026-09-07', '2026-09-09'),
        overrides: [
          OccurrenceOverride(
            taskId: _taskId,
            key: OccurrenceKey.parse('2026-09-08T09:00'),
            action: OverrideAction.modify,
            status: OccurrenceStatus.done,
          ),
        ],
      );
      expect(out.map((o) => o.status), [
        OccurrenceStatus.pending,
        OccurrenceStatus.done,
        OccurrenceStatus.pending,
      ]);
    });

    test('脏 override（key 不是真实发生）不得凭空造出实例', () {
      // 9/8 09:30 不是 FREQ=DAILY@09:00 的发生时刻。
      final out = _engine.expand(
        context: ctx('RRULE:FREQ=DAILY'),
        window: win('2026-09-07', '2026-09-09'),
        overrides: [
          OccurrenceOverride(
            taskId: _taskId,
            key: OccurrenceKey.parse('2026-09-20T09:30'),
            action: OverrideAction.modify,
            planDateOverride: PlanDate.parse('2026-09-08'),
          ),
        ],
      );
      expect(out, hasLength(3), reason: '仍是 9/7、9/8、9/9 三次，不多一次');
    });

    test('其它任务的 override 不得影响本任务', () {
      final r = days(
        ctx('RRULE:FREQ=DAILY'),
        win('2026-09-07', '2026-09-09'),
        overrides: [
          OccurrenceOverride.skip(
            taskId: 'other-task',
            key: OccurrenceKey.parse('2026-09-08T09:00'),
          ),
        ],
      );
      expect(r, hasLength(3));
    });
  });

  group('全天任务', () {
    test('R-28 全天任务的 key 是纯日期，无 T00:00 后缀', () {
      final out = _engine.expand(
        context: ctx(
          'RRULE:FREQ=DAILY',
          dtStart: wall(2026, 9, 7, 0, 0),
          isAllDay: true,
        ),
        window: win('2026-09-07', '2026-09-08'),
      );
      expect(out.map((o) => o.key.value), ['2026-09-07', '2026-09-08']);
      expect(out.first.key.isAllDay, isTrue);
    });

    test('全天任务不因 durationMinutes 产生结束时刻', () {
      final out = _engine.expand(
        context: ctx(
          'RRULE:FREQ=DAILY',
          dtStart: wall(2026, 9, 7, 0, 0),
          isAllDay: true,
          durationMinutes: 60,
        ),
        window: win('2026-09-07', '2026-09-07'),
      );
      expect(out.single.end, isNull);
    });
  });

  group('非重复任务', () {
    test('recurrence 为 null 时只有 DTSTART 这一次', () {
      expect(days(ctx(''), win('2026-09-01', '2026-09-30')), ['2026-09-07']);
    });

    test('DTSTART 在窗口外时返回空', () {
      expect(days(ctx(''), win('2026-10-01', '2026-10-31')), isEmpty);
    });
  });

  group('时长', () {
    test('durationMinutes 推导出结束墙钟，可跨日', () {
      final out = _engine.expand(
        context: ctx(
          'RRULE:FREQ=DAILY;COUNT=1',
          dtStart: wall(2026, 9, 7, 23, 0),
          durationMinutes: 120,
        ),
        window: win('2026-09-07', '2026-09-08'),
      );
      expect(out.single.end, wall(2026, 9, 8, 1, 0));
    });
  });
}

/// 重复引擎的时区行为 —— recurrence-engine §6 的 R-40/R-41/R-42 与 R-09i。
///
/// 与 `time_zone_resolver_test.dart` 的区别：那边测的是**换算函数**，
/// 这边测的是**展开一条重复规则时**这些换算怎么体现。
/// 两层各测各的 —— 换算对了不等于展开对了，中间还隔着窗口裁剪、
/// key 计算与 override 应用。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/local_wall_time.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/core/time/time_zone_resolver.dart';
import 'package:planning_assistant/domain/entities/occurrence.dart';
import 'package:planning_assistant/domain/recurrence/recurrence_engine.dart';
import 'package:planning_assistant/domain/value_objects/recurrence.dart';
import 'package:timezone/data/latest.dart' as tzdata;

const _resolver = TzTimeZoneResolver();
const _engine = RecurrenceEngine(_resolver);

RecurrenceContext ctx({
  required String zone,
  required PlanDate from,
  required int hour,
  int minute = 0,
  String rule = 'RRULE:FREQ=DAILY',
}) => RecurrenceContext(
  taskId: 't1',
  dtStart: LocalWallTime(
    date: from,
    minuteOfDay: MinuteOfDay.of(hour, minute),
    timeZoneId: zone,
  ),
  isAllDay: false,
  recurrence: Recurrence.parse(rule),
);

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('R-40 设备换时区，墙钟不变', () {
    test('北京设的「每天 09:00」，设备切到伦敦后仍是 09:00', () {
      // **这是 ADR-0005 存在的全部理由。** 存 UTC 时间戳的话，
      // 换时区后同一条任务会显示成别的时刻 —— 用户搬个家，
      // 所有闹钟集体偏移。
      final occurrences = _engine.expand(
        context: ctx(
          zone: 'Asia/Shanghai',
          from: const PlanDate(2026, 6, 1),
          hour: 9,
        ),
        window: const DateRange(PlanDate(2026, 6, 1), PlanDate(2026, 6, 3)),
      );

      expect(occurrences.length, 3);
      for (final o in occurrences) {
        expect(o.start.minuteOfDay, MinuteOfDay.of(9, 0));
        expect(
          o.start.timeZoneId,
          'Asia/Shanghai',
          reason: '任务的时区跟着任务走，不跟着设备走',
        );
      }
    });

    test('同一条规则在两个时区展开，墙钟相同而绝对时刻不同', () {
      // 墙钟一致 = 用户看到的一致；绝对时刻不同 = 提醒该在各自的当地响。
      List<Occurrence> expandIn(String zone) => _engine.expand(
        context: ctx(zone: zone, from: const PlanDate(2026, 6, 1), hour: 9),
        window: const DateRange(PlanDate(2026, 6, 1), PlanDate(2026, 6, 1)),
      );

      final shanghai = expandIn('Asia/Shanghai').single;
      final london = expandIn('Europe/London').single;

      expect(shanghai.start.minuteOfDay, london.start.minuteOfDay);
      expect(
        _resolver.toInstant(shanghai.start),
        isNot(_resolver.toInstant(london.start)),
      );
      // 2026-06-01 伦敦是 BST(+1)，上海 +8，差 7 小时。
      expect(
        _resolver
            .toInstant(london.start)
            .difference(_resolver.toInstant(shanghai.start)),
        const Duration(hours: 7),
      );
    });
  });

  group('R-41 春季跳表日：不存在的墙钟顺延并打标记', () {
    test('America/New_York 每天 02:30，跳表日顺延到 03:00', () {
      final occurrences = _engine.expand(
        context: ctx(
          zone: 'America/New_York',
          from: const PlanDate(2026, 3, 7),
          hour: 2,
          minute: 30,
        ),
        window: const DateRange(PlanDate(2026, 3, 7), PlanDate(2026, 3, 9)),
      );

      expect(occurrences.length, 3, reason: '跳表日不该整天消失');

      final byDate = {for (final o in occurrences) o.start.date: o};
      // 前一天与后一天都正常。
      expect(
        byDate[const PlanDate(2026, 3, 7)]!.start.minuteOfDay,
        MinuteOfDay.of(2, 30),
      );
      expect(
        byDate[const PlanDate(2026, 3, 9)]!.start.minuteOfDay,
        MinuteOfDay.of(2, 30),
      );

      // 跳表日：02:30 不存在，顺延到 03:00（**不是 03:30**）。
      final jumpDay = byDate[const PlanDate(2026, 3, 8)]!;
      expect(jumpDay.start.minuteOfDay, MinuteOfDay.of(3, 0));
      expect(
        _resolver.toInstant(jumpDay.start),
        DateTime.utc(2026, 3, 8, 7),
        reason: '整个不存在的时段都映射到跳变后第一刻',
      );
    });

    test('key 用的是**原始**时刻，不是顺延后的', () {
      // key 若跟着顺延，那天的 override 就与规则对不上了 ——
      // 用户「跳过 3 月 8 日这次」会失效。
      final occurrences = _engine.expand(
        context: ctx(
          zone: 'America/New_York',
          from: const PlanDate(2026, 3, 8),
          hour: 2,
          minute: 30,
        ),
        window: const DateRange(PlanDate(2026, 3, 8), PlanDate(2026, 3, 8)),
      );
      expect(occurrences.single.key.value, '2026-03-08T02:30');
      expect(occurrences.single.start.minuteOfDay, MinuteOfDay.of(3, 0));
    });
  });

  group('R-42 秋季回拨日：重复的墙钟只出现一次', () {
    test('America/New_York 每天 01:30，回拨日只有一次且取较早的瞬时', () {
      // 01:30 在这天出现两遍（EDT 与 EST）。展开成两次的话，
      // 用户那天会收到两条同样的提醒。
      final occurrences = _engine.expand(
        context: ctx(
          zone: 'America/New_York',
          from: const PlanDate(2026, 11, 1),
          hour: 1,
          minute: 30,
        ),
        window: const DateRange(PlanDate(2026, 11, 1), PlanDate(2026, 11, 1)),
      );

      expect(occurrences.length, 1, reason: '回拨日不该出现两次');
      expect(occurrences.single.start.minuteOfDay, MinuteOfDay.of(1, 30));
      // EDT(-4) 的那个更早：01:30 - (-4) = 05:30Z。
      expect(
        _resolver.toInstant(occurrences.single.start),
        DateTime.utc(2026, 11, 1, 5, 30),
      );
    });

    test('回拨日前后各天不受影响', () {
      final occurrences = _engine.expand(
        context: ctx(
          zone: 'America/New_York',
          from: const PlanDate(2026, 10, 31),
          hour: 1,
          minute: 30,
        ),
        window: const DateRange(PlanDate(2026, 10, 31), PlanDate(2026, 11, 2)),
      );
      expect(occurrences.length, 3);
      expect(
        occurrences.every((o) => o.start.minuteOfDay == MinuteOfDay.of(1, 30)),
        isTrue,
      );
    });
  });

  group('R-09i 外部非规范序的规则入库后必须已规范化', () {
    // 这条**专门用来抓「某条写入路径漏了规范化」** ——
    // C1/C2/C3 验的是编解码器本身，它们都抓不到「某处直接存了原串」。
    const externalRules = [
      // 部件顺序与本应用规范形不同。
      'RRULE:BYMONTHDAY=-1;FREQ=MONTHLY;UNTIL=20261231T235959Z',
      'RRULE:COUNT=5;FREQ=DAILY',
      'RRULE:BYDAY=MO,WE;FREQ=WEEKLY;INTERVAL=2',
    ];

    for (final src in externalRules) {
      test('$src 经 Recurrence.parse 后满足 encode(decode(s)) == s', () {
        final stored = Recurrence.parse(src).canonical;
        // 存进库的是 canonical；再解再编必须不动。
        expect(
          encodeRrule(decodeRrule(stored)),
          stored,
          reason: '存储值不是规范形 —— 某条写入路径漏了规范化',
        );
      });
    }

    test('规范化不改变语义 —— 展开结果与原串一致', () {
      // 规范化若顺手改了语义，是比不规范严重得多的问题。
      const window = DateRange(PlanDate(2026, 1, 1), PlanDate(2026, 6, 30));
      for (final src in externalRules) {
        final canonical = Recurrence.parse(src).canonical;
        final a = _engine.expand(
          context: ctx(
            zone: 'Asia/Shanghai',
            from: const PlanDate(2026, 1, 1),
            hour: 9,
            rule: src,
          ),
          window: window,
        );
        final b = _engine.expand(
          context: ctx(
            zone: 'Asia/Shanghai',
            from: const PlanDate(2026, 1, 1),
            hour: 9,
            rule: canonical,
          ),
          window: window,
        );
        expect(
          a.map((o) => o.key.value),
          b.map((o) => o.key.value),
          reason: '$src 规范化后展开结果变了',
        );
      }
    });
  });
}

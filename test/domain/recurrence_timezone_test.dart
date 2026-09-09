/// 重复引擎的时区行为 —— recurrence-engine §6 的 R-40/R-41/R-42 与 R-09i，
/// 也是 NFR-REL-03「跨时区、跨夏令时、闰年边界行为明确」的那个专门测试集。
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

  group('NFR-REL-03 / R-40 设备换时区，墙钟不变', () {
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

  group('B1 / §4.1.1　end 也必须解析 DST，且两端各自独立', () {
    // 评审阻断项。初版只解析了 start，`01:30 + 60min` 会给出
    // `end = 02:30` —— 跳表当天不存在的墙钟。
    //
    // 后果不止显示错：`reminders.kind = relativeToEnd` 排期时会对 end
    // 做换算，得到 03:00 对应的瞬时，而 UI 显示 02:30，两边永久对不上。

    Occurrence occurrenceOf({
      required PlanDate date,
      required int hour,
      required int minute,
      required int durationMinutes,
      String zone = 'America/New_York',
    }) => _engine
        .expand(
          context: RecurrenceContext(
            taskId: 't1',
            isAllDay: false,
            durationMinutes: durationMinutes,
            dtStart: LocalWallTime(
              date: date,
              minuteOfDay: MinuteOfDay.of(hour, minute),
              timeZoneId: zone,
            ),
            recurrence: Recurrence.parse('RRULE:FREQ=DAILY'),
          ),
          window: DateRange(date, date),
        )
        .single;

    test('end 落进空隙时顺延到 03:00，并单独打 endDstAdjusted', () {
      final o = occurrenceOf(
        date: const PlanDate(2026, 3, 8),
        hour: 1,
        minute: 30,
        durationMinutes: 60,
      );

      expect(o.start.minuteOfDay, MinuteOfDay.of(1, 30), reason: 'start 本就合法');
      expect(o.dstAdjusted, isFalse, reason: '只有 end 落进空隙');
      expect(o.end!.minuteOfDay, MinuteOfDay.of(3, 0), reason: '02:30 不存在');
      expect(o.endDstAdjusted, isTrue);
    });

    test('两端的标记独立 —— 只有 start 落进空隙时 endDstAdjusted 为假', () {
      // 合成一个标记的话，UI 无从知道该解释哪一端。
      final o = occurrenceOf(
        date: const PlanDate(2026, 3, 8),
        hour: 2,
        minute: 30,
        durationMinutes: 60,
      );
      expect(o.dstAdjusted, isTrue, reason: '02:30 不存在，start 被顺延到 03:00');
      expect(o.start.minuteOfDay, MinuteOfDay.of(3, 0));
      expect(o.end!.minuteOfDay, MinuteOfDay.of(4, 0), reason: '03:00+60 合法');
      expect(o.endDstAdjusted, isFalse);
    });

    test('每一个产出的 end 墙钟都必须真实存在', () {
      // 不变式而非点断言：它不依赖「猜到问题出在哪个具体时刻」。
      final offenders = <String>[];
      for (final date in [
        const PlanDate(2026, 3, 8),
        const PlanDate(2026, 11, 1),
        const PlanDate(2026, 6, 15),
      ]) {
        for (var h = 0; h < 24; h++) {
          for (final dur in [30, 60, 90, 180]) {
            final o = occurrenceOf(
              date: date,
              hour: h,
              minute: 30,
              durationMinutes: dur,
            );
            // 断的是「最终值真实存在」，不是「曾被顺延」——
            // 顺延**之后**的 03:00 当然是合法墙钟，拿它的 dstAdjusted
            // 去比 endDstAdjusted 是两回事（第一版就这么写错了，当场变红）。
            if (_resolver.resolve(o.end!).effectiveWallTime != o.end) {
              offenders.add('  $date $h:30 +$dur → end ${o.end}');
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            '${offenders.length} 处 end 未被解析：\n'
            '${offenders.take(10).join('\n')}',
      );
    });

    test('§4.1.1 表格：跨 DST 时实际经过时长与声明值可以不同', () {
      // 这是墙钟语义的**必然结果**，不是缺陷。钉住它，
      // 免得将来有人看到「声明 180 实际 120」就去「修」。
      int elapsed(Occurrence o) => _resolver
          .toInstant(o.end!)
          .difference(_resolver.toInstant(o.start))
          .inMinutes;

      // 春季跳表当日：01:00 + 180min → 04:00，实际 120 分钟。
      expect(
        elapsed(
          occurrenceOf(
            date: const PlanDate(2026, 3, 8),
            hour: 1,
            minute: 0,
            durationMinutes: 180,
          ),
        ),
        120,
      );
      // 秋季回拨当日：同样声明 180，实际 240 分钟。
      expect(
        elapsed(
          occurrenceOf(
            date: const PlanDate(2026, 11, 1),
            hour: 1,
            minute: 0,
            durationMinutes: 180,
          ),
        ),
        240,
      );
      // 普通日对照 —— 没有这条的话，上面两条可能因为「一律算错」而假绿。
      expect(
        elapsed(
          occurrenceOf(
            date: const PlanDate(2026, 6, 15),
            hour: 1,
            minute: 0,
            durationMinutes: 180,
          ),
        ),
        180,
      );
      // 跨天且无 DST：正常。
      expect(
        elapsed(
          occurrenceOf(
            date: const PlanDate(2026, 6, 15),
            hour: 23,
            minute: 0,
            durationMinutes: 120,
          ),
        ),
        120,
      );
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

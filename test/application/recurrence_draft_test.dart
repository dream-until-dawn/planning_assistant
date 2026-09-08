/// 编辑器的重复规则（FR-TASK-03/04）。
///
/// 最要紧的不是「拼出了一个串」，而是**那个串能被引擎展开成用户想要的日子**。
/// 只验字符串的话，一个语法合法、语义错误的规则也能全绿。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/local_wall_time.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/core/time/time_zone_resolver.dart';
import 'package:planning_assistant/core/time/weekday.dart';
import 'package:planning_assistant/domain/recurrence/recurrence_engine.dart';
import 'package:planning_assistant/domain/value_objects/recurrence.dart';
import 'package:planning_assistant/features/task/application/recurrence_draft.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// 2026-09-07 是**周一**。挑周一是为了让「每周一三五」的首次就落在选中的
/// 那一天，否则首次会被 RRULE 的 DTSTART 语义挪走，验的就不是规则本身了。
const _start = PlanDate(2026, 9, 7);

const _engine = RecurrenceEngine(TzTimeZoneResolver());

/// 展开一条草稿，返回落在窗口内的日期。
List<PlanDate> _expand(RecurrenceDraft draft, {int days = 30}) {
  final raw = draft.toRrule();
  final context = RecurrenceContext(
    taskId: 't1',
    dtStart: LocalWallTime(
      date: _start,
      minuteOfDay: MinuteOfDay.of(9, 0),
      timeZoneId: 'Asia/Shanghai',
    ),
    isAllDay: false,
    recurrence: raw == null ? null : Recurrence.parse(raw),
  );
  final occurrences = _engine.expand(
    context: context,
    window: DateRange(_start, _start.addDays(days)),
  );
  return [for (final o in occurrences) o.start.date];
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('编出来的串能被解析，而且已经是规范形', () {
    // 不是规范形的话，存进库与读出来会是两个串，同步与往返都会分叉。
    final drafts = <String, RecurrenceDraft>{
      '每天': const RecurrenceDraft(enabled: true),
      '每 3 天': const RecurrenceDraft(enabled: true, interval: 3),
      '每周一三五': const RecurrenceDraft(
        enabled: true,
        frequency: RecurrenceFrequency.weekly,
        weekdays: {Weekday.monday, Weekday.wednesday, Weekday.friday},
      ),
      '每月 5 次': const RecurrenceDraft(
        enabled: true,
        frequency: RecurrenceFrequency.monthly,
        endMode: RecurrenceEndMode.count,
        count: 5,
      ),
      '每年到某日': const RecurrenceDraft(
        enabled: true,
        frequency: RecurrenceFrequency.yearly,
        endMode: RecurrenceEndMode.until,
        until: PlanDate(2027, 5, 20),
      ),
    };

    drafts.forEach((name, draft) {
      test(name, () {
        final raw = draft.toRrule()!;
        final parsed = Recurrence.parse(raw);
        expect(parsed.canonical, raw, reason: '$raw 不是规范形');
      });
    });

    test('关掉时不产出规则', () {
      expect(const RecurrenceDraft().toRrule(), isNull);
    });
  });

  group('展开成用户想要的日子（FR-TASK-03）', () {
    test('每天', () {
      final dates = _expand(const RecurrenceDraft(enabled: true), days: 3);
      expect(dates, [
        const PlanDate(2026, 9, 7),
        const PlanDate(2026, 9, 8),
        const PlanDate(2026, 9, 9),
        const PlanDate(2026, 9, 10),
      ]);
    });

    test('每 3 天', () {
      final dates = _expand(
        const RecurrenceDraft(enabled: true, interval: 3),
        days: 9,
      );
      expect(dates, [
        const PlanDate(2026, 9, 7),
        const PlanDate(2026, 9, 10),
        const PlanDate(2026, 9, 13),
        const PlanDate(2026, 9, 16),
      ]);
    });

    test('每周一、三、五', () {
      // 9/7 是周一。窗口到 9/20（周日），落在一三五上的是
      // 7(一) 9(三) 11(五) 14(一) 16(三) 18(五) —— 20 是周日，不算。
      // 我第一版把 20 也写进期望里了，是期望错不是代码错。
      final dates = _expand(
        const RecurrenceDraft(
          enabled: true,
          frequency: RecurrenceFrequency.weekly,
          weekdays: {Weekday.monday, Weekday.wednesday, Weekday.friday},
        ),
        days: 13,
      );
      expect(dates.map((d) => d.day), [7, 9, 11, 14, 16, 18]);
    });

    test('每周不选周几 = 跟开始日期同一天', () {
      // 这是 RRULE 的默认行为（不写 BYDAY 时按 DTSTART 的星期几），
      // 不是「一天都不重复」。
      final dates = _expand(
        const RecurrenceDraft(
          enabled: true,
          frequency: RecurrenceFrequency.weekly,
        ),
        days: 21,
      );
      expect(dates.map((d) => d.day), [7, 14, 21, 28]);
    });

    test('每月', () {
      final dates = _expand(
        const RecurrenceDraft(
          enabled: true,
          frequency: RecurrenceFrequency.monthly,
        ),
        days: 70,
      );
      expect(dates, [
        const PlanDate(2026, 9, 7),
        const PlanDate(2026, 10, 7),
        const PlanDate(2026, 11, 7),
      ]);
    });
  });

  group('结束条件（FR-TASK-04）', () {
    test('永不结束：窗口有多长就展开多长', () {
      final dates = _expand(const RecurrenceDraft(enabled: true), days: 100);
      expect(dates, hasLength(101));
    });

    test('重复 N 次：**含首次**', () {
      // COUNT 按 RFC 5545 是含首次的。理解成「再重复 N 次」会多出一次。
      final dates = _expand(
        const RecurrenceDraft(
          enabled: true,
          endMode: RecurrenceEndMode.count,
          count: 3,
        ),
        days: 100,
      );
      expect(dates, hasLength(3));
      expect(dates.last, const PlanDate(2026, 9, 9));
    });

    test('到某天为止：**含当天**', () {
      // UNTIL 取当天 23:59:59Z 就是为了这个 —— 用 00:00 会把当天排除掉。
      final dates = _expand(
        const RecurrenceDraft(
          enabled: true,
          endMode: RecurrenceEndMode.until,
          until: PlanDate(2026, 9, 10),
        ),
        days: 100,
      );
      expect(dates.last, const PlanDate(2026, 9, 10), reason: '结束当天应当包含在内');
    });

    test('对照组：三种结束条件展开出的次数互不相同', () {
      // 否则「结束条件根本没生效」也能让上面三条各自通过。
      final never = _expand(const RecurrenceDraft(enabled: true), days: 30);
      final counted = _expand(
        const RecurrenceDraft(
          enabled: true,
          endMode: RecurrenceEndMode.count,
          count: 3,
        ),
        days: 30,
      );
      final until = _expand(
        const RecurrenceDraft(
          enabled: true,
          endMode: RecurrenceEndMode.until,
          until: PlanDate(2026, 9, 12),
        ),
        days: 30,
      );
      expect({never.length, counted.length, until.length}, hasLength(3));
    });
  });

  group('校验', () {
    test('「到某天为止」没选日期时不给编码', () {
      // 编出去的话会得到一条永不结束的规则，而用户以为它会停。
      const draft = RecurrenceDraft(
        enabled: true,
        endMode: RecurrenceEndMode.until,
      );
      expect(draft.isValid, isFalse);
      expect(draft.toRrule(), isNull);
      expect(draft.blockedReason, isNotNull);
    });

    test('间隔小于 1 不给编码', () {
      // 0 会让规则退化成无限循环同一天。
      expect(
        const RecurrenceDraft(enabled: true, interval: 0).isValid,
        isFalse,
      );
    });

    test('次数小于 1 不给编码', () {
      expect(
        const RecurrenceDraft(
          enabled: true,
          endMode: RecurrenceEndMode.count,
          count: 0,
        ).isValid,
        isFalse,
      );
    });

    test('对照组：填全了就合法', () {
      expect(const RecurrenceDraft(enabled: true).isValid, isTrue);
    });
  });

  group('周几的顺序是稳定的', () {
    test('集合的迭代序不影响编出来的串', () {
      // 不排序的话，同一份选择可能编出两个不同的串，规范形往返会失败。
      const a = RecurrenceDraft(
        enabled: true,
        frequency: RecurrenceFrequency.weekly,
        weekdays: {Weekday.friday, Weekday.monday, Weekday.wednesday},
      );
      const b = RecurrenceDraft(
        enabled: true,
        frequency: RecurrenceFrequency.weekly,
        weekdays: {Weekday.monday, Weekday.wednesday, Weekday.friday},
      );
      expect(a.toRrule(), b.toRrule());
      expect(a.toRrule(), contains('BYDAY=MO,WE,FR'));
    });
  });

  group('说人话', () {
    test('关着时说「不重复」，不是留空', () {
      // 留空的话用户分不清「不重复」与「这个功能还没做」。
      expect(const RecurrenceDraft().describe(), '不重复');
    });

    test('带上间隔、周几与结束条件', () {
      const draft = RecurrenceDraft(
        enabled: true,
        frequency: RecurrenceFrequency.weekly,
        interval: 2,
        weekdays: {Weekday.monday, Weekday.friday},
        endMode: RecurrenceEndMode.count,
        count: 6,
      );
      final text = draft.describe();
      expect(text, contains('2'));
      expect(text, contains('周'));
      expect(text, contains('一'));
      expect(text, contains('五'));
      expect(text, contains('6'));
    });
  });
}

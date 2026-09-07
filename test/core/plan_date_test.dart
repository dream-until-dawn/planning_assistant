/// `PlanDate` 与 `MinuteOfDay` 的行为契约。
///
/// 期望值全部手算（闰年规则、各月天数、ISO 星期），不是「跑一遍看输出」。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';

void main() {
  group('PlanDate 解析与格式', () {
    test('严格往返：parse(toString(d)) == d', () {
      for (final d in [
        const PlanDate(2026, 1, 1),
        const PlanDate(2026, 12, 31),
        const PlanDate(2028, 2, 29), // 闰日
        const PlanDate(999, 9, 9),
      ]) {
        expect(PlanDate.parse(d.toString()), d, reason: '$d');
      }
    });

    test('补零到 yyyy-MM-dd', () {
      expect(const PlanDate(2026, 9, 8).toString(), '2026-09-08');
      expect(const PlanDate(999, 1, 2).toString(), '0999-01-02');
    });

    test('拒绝宽松形态 —— 存储层的值只可能来自 toString()', () {
      for (final bad in [
        '2026-9-8', // 未补零
        '2026/09/08', // 分隔符不对
        '2026-09-08T00:00', // 带时间
        '20260908', // 无分隔符
        '', // 空
        'not-a-date',
      ]) {
        expect(
          () => PlanDate.parse(bad),
          throwsFormatException,
          reason: '「$bad」应当被拒绝，而不是猜测它的含义',
        );
      }
    });

    test('拒绝该月不存在的日期', () {
      expect(
        () => PlanDate.parse('2026-02-29'),
        throwsFormatException,
        reason: '2026 非闰年',
      );
      expect(
        () => PlanDate.parse('2026-04-31'),
        throwsFormatException,
        reason: '4 月只有 30 天',
      );
      expect(() => PlanDate.parse('2026-13-01'), throwsFormatException);
      expect(() => PlanDate.parse('2026-00-01'), throwsFormatException);
      expect(() => PlanDate.parse('2026-01-00'), throwsFormatException);
      // 闰年的 2-29 必须被接受
      expect(PlanDate.parse('2028-02-29'), const PlanDate(2028, 2, 29));
    });
  });

  group('闰年与月长（重复引擎的月末用例依赖它）', () {
    test('闰年规则：能被 4 整除，但百年不闰、四百年再闰', () {
      // 手算依据格里高利历规则
      expect(PlanDate.isLeapYear(2024), isTrue);
      expect(PlanDate.isLeapYear(2026), isFalse);
      expect(PlanDate.isLeapYear(2028), isTrue);
      expect(PlanDate.isLeapYear(1900), isFalse, reason: '百年不闰');
      expect(PlanDate.isLeapYear(2000), isTrue, reason: '四百年再闰');
      expect(PlanDate.isLeapYear(2100), isFalse);
    });

    test('各月天数', () {
      const expected = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
      for (var m = 1; m <= 12; m++) {
        expect(
          PlanDate.daysInMonth(2026, m),
          expected[m - 1],
          reason: '2026-$m',
        );
      }
      expect(PlanDate.daysInMonth(2028, 2), 29, reason: '闰年二月');
    });

    test('endOfMonth', () {
      expect(
        const PlanDate(2026, 2, 1).endOfMonth,
        const PlanDate(2026, 2, 28),
      );
      expect(
        const PlanDate(2028, 2, 1).endOfMonth,
        const PlanDate(2028, 2, 29),
      );
      expect(
        const PlanDate(2026, 4, 15).endOfMonth,
        const PlanDate(2026, 4, 30),
      );
    });
  });

  group('日期运算', () {
    test('addDays 跨月、跨年、跨闰日', () {
      expect(
        const PlanDate(2026, 1, 31).addDays(1),
        const PlanDate(2026, 2, 1),
      );
      expect(
        const PlanDate(2026, 12, 31).addDays(1),
        const PlanDate(2027, 1, 1),
      );
      expect(
        const PlanDate(2028, 2, 28).addDays(1),
        const PlanDate(2028, 2, 29),
        reason: '闰年',
      );
      expect(
        const PlanDate(2026, 2, 28).addDays(1),
        const PlanDate(2026, 3, 1),
        reason: '非闰年',
      );
      expect(
        const PlanDate(2026, 1, 1).addDays(-1),
        const PlanDate(2025, 12, 31),
      );
    });

    test('differenceInDays', () {
      expect(
        const PlanDate(2026, 3, 1).differenceInDays(const PlanDate(2026, 2, 1)),
        28,
        reason: '2026 年 2 月 28 天',
      );
      expect(
        const PlanDate(2028, 3, 1).differenceInDays(const PlanDate(2028, 2, 1)),
        29,
        reason: '2028 年闰年',
      );
      expect(
        const PlanDate(2027, 1, 1).differenceInDays(const PlanDate(2026, 1, 1)),
        365,
      );
    });

    test('weekday 与 ISO-8601 一致（周一=1）', () {
      // 手算：2026-01-01 是周四。依据：2024-01-01 周一，2024 闰(366天)
      // → 2025-01-01 周三；2025 平年(365天) → 2026-01-01 周四。
      expect(const PlanDate(2026, 1, 1).weekday, DateTime.thursday);
      expect(const PlanDate(2026, 1, 2).weekday, DateTime.friday);
      expect(const PlanDate(2026, 1, 4).weekday, DateTime.sunday);
      expect(const PlanDate(2026, 1, 5).weekday, DateTime.monday);
    });

    test('比较与排序', () {
      final dates = [
        const PlanDate(2026, 12, 1),
        const PlanDate(2026, 1, 31),
        const PlanDate(2025, 12, 31),
        const PlanDate(2026, 1, 1),
      ]..sort();
      expect(dates.map((d) => d.toString()), [
        '2025-12-31',
        '2026-01-01',
        '2026-01-31',
        '2026-12-01',
      ]);
      expect(
        const PlanDate(2026, 1, 1).isBefore(const PlanDate(2026, 1, 2)),
        isTrue,
      );
      expect(
        const PlanDate(2026, 1, 2).isAfter(const PlanDate(2026, 1, 1)),
        isTrue,
      );
    });

    test('值语义：相等的日期 == 且 hashCode 相同', () {
      const a = PlanDate(2026, 9, 8);
      const b = PlanDate(2026, 9, 8);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      // 从列表构造而不是写字面量 —— 字面量里两个相等元素会被 lint 拦下，
      // 而这里要验证的正是「它们确实相等，所以会去重」。
      final asSet = <PlanDate>{}..addAll(<PlanDate>[a, b]);
      expect(asSet, hasLength(1), reason: '可安全用作 Set/Map 的键');
    });
  });

  group('MinuteOfDay', () {
    test('边界值', () {
      expect(MinuteOfDay.midnight.value, 0);
      expect(MinuteOfDay.endOfDay.value, 1439);
      expect(MinuteOfDay.endOfDay.toString(), '23:59');
      expect(MinuteOfDay.of(23, 59).value, 1439);
    });

    test('越界抛异常而不是取模', () {
      // 取模会把「加了 25 小时」这类错误静默变成合法值，
      // 让 bug 表现为「时间莫名其妙少了一天」而不是当场失败。
      expect(() => MinuteOfDay(-1), throwsRangeError);
      expect(() => MinuteOfDay(1440), throwsRangeError);
      expect(() => MinuteOfDay.of(24, 0), throwsRangeError);
      expect(() => MinuteOfDay.of(0, 60), throwsRangeError);
      expect(() => MinuteOfDay.of(-1, 0), throwsRangeError);
    });

    test('add 溢出到次日时抛异常，强制调用方显式处理跨日', () {
      expect(MinuteOfDay.of(23, 0).add(30).value, MinuteOfDay.of(23, 30).value);
      expect(
        () => MinuteOfDay.of(23, 30).add(60),
        throwsRangeError,
        reason: '若静默回绕成 00:30，日期不会跟着推进，结果差一天',
      );
    });

    test('addWithCarry 正确处理正负跨日', () {
      final plus = MinuteOfDay.of(23, 30).addWithCarry(60);
      expect(plus.minute, MinuteOfDay.of(0, 30));
      expect(plus.dayOffset, 1);

      final minus = MinuteOfDay.of(0, 30).addWithCarry(-60);
      expect(minus.minute, MinuteOfDay.of(23, 30));
      expect(minus.dayOffset, -1, reason: '负数必须向下取整，不能向零取整');

      final multi = MinuteOfDay.of(12, 0).addWithCarry(2 * 1440 + 60);
      expect(multi.minute, MinuteOfDay.of(13, 0));
      expect(multi.dayOffset, 2);

      final noCarry = MinuteOfDay.of(12, 0).addWithCarry(30);
      expect(noCarry.dayOffset, 0);
    });

    test('hour / minute 分解', () {
      final m = MinuteOfDay(9 * 60 + 5);
      expect(m.hour, 9);
      expect(m.minute, 5);
      expect(m.toString(), '09:05');
    });
  });
}

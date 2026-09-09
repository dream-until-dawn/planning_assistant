/// 月历格子（view-specs §3.1）。
///
/// 这些都是「数出来的」结论：某月第一行从几号起、2 月补几天、
/// 周日起始时整行往哪边挪。混进 widget 之后就得靠数屏幕上的方块去验，
/// 而屏幕上的方块长得都一样。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/features/views/calendar/application/month_grid.dart';

/// 这一行的日期，写成 `9-1` 这样便于一眼比对。
List<String> _days(List<MonthCell> week) => [
  for (final c in week) '${c.date.month}-${c.date.day}',
];

void main() {
  group('第一行从哪天起', () {
    test('2026-09-01 是周二，周一起始时前面补一天（8-31）', () {
      final grid = monthGrid(year: 2026, month: 9);
      expect(_days(grid.weeks.first).first, '8-31');
      expect(_days(grid.weeks.first)[1], '9-1');
    });

    test('周日起始时同一个月往后挪一格', () {
      final grid = monthGrid(
        year: 2026,
        month: 9,
        firstDayOfWeek: DateTime.sunday,
      );
      expect(_days(grid.weeks.first).first, '8-30');
      expect(_days(grid.weeks.first)[2], '9-1');
    });

    test('月初正好是周起始日时，一天都不补', () {
      // 2026-06-01 是周一。补一整周（七天）的实现在这里会露馅。
      final grid = monthGrid(year: 2026, month: 6);
      expect(_days(grid.weeks.first).first, '6-1');
    });

    test('周日起始遇上月初是周日，同样一天都不补', () {
      // (7 - 7) % 7 == 0。这条盯的是取模在「差值为 0」时不要多退一周。
      // 2026-03-01 是周日。
      final grid = monthGrid(
        year: 2026,
        month: 3,
        firstDayOfWeek: DateTime.sunday,
      );
      expect(_days(grid.weeks.first).first, '3-1');
    });

    test('周日起始遇上月初是周一，要往前退六天而不是往后一天', () {
      // `(1 - 7) % 7`：C 系语言给 -6，Dart 给 1。给 -6 的话
      // `addDays(6)` 会把第一行推到下周，整月错位一周。
      // 2026-06-01 是周一。
      final grid = monthGrid(
        year: 2026,
        month: 6,
        firstDayOfWeek: DateTime.sunday,
      );
      expect(_days(grid.weeks.first).first, '5-31');
      expect(_days(grid.weeks.first)[1], '6-1');
    });
  });

  group('形状恒定', () {
    test('永远六行七列，哪个月都一样', () {
      // 行数随月份变的话，格子高度跟着变，左右滑动切月时下半屏会跳。
      for (final (y, m) in [(2026, 2), (2026, 3), (2027, 2), (2024, 2)]) {
        final grid = monthGrid(year: y, month: m);
        expect(grid.weeks, hasLength(weeksPerMonthView), reason: '$y-$m');
        for (final w in grid.weeks) {
          expect(w, hasLength(daysPerWeek), reason: '$y-$m');
        }
      }
    });

    test('四十二格是连续的，不重不漏', () {
      final grid = monthGrid(year: 2026, month: 9);
      final all = [for (final w in grid.weeks) ...w];
      for (var i = 1; i < all.length; i++) {
        expect(
          all[i].date.differenceInDays(all[i - 1].date),
          1,
          reason: '第 $i 格与前一格不相邻',
        );
      }
      expect(grid.first, all.first.date);
      expect(grid.last, all.last.date);
    });

    test('闰年 2 月：29 号在当月，3-1 是补的', () {
      final grid = monthGrid(year: 2024, month: 2);
      final all = [for (final w in grid.weeks) ...w];
      final feb29 = all.firstWhere(
        (c) => c.date == const PlanDate(2024, 2, 29),
      );
      expect(feb29.inMonth, isTrue);
      final mar1 = all.firstWhere((c) => c.date == const PlanDate(2024, 3, 1));
      expect(mar1.inMonth, isFalse);
    });
  });

  group('当月与补进来的分得清', () {
    test('当月的日子不多不少，补进来的都标成不在当月', () {
      for (final (y, m, days) in [
        (2026, 1, 31),
        (2026, 2, 28),
        (2024, 2, 29),
        (2026, 12, 31),
      ]) {
        final all = [for (final w in monthGrid(year: y, month: m).weeks) ...w];
        expect(all.where((c) => c.inMonth), hasLength(days), reason: '$y-$m');
        for (final c in all.where((c) => !c.inMonth)) {
          expect(c.date.month, isNot(m), reason: '$y-$m 里 ${c.date} 被标错了');
        }
      }
    });

    test('一月的第一行补的是上一年的十二月', () {
      final grid = monthGrid(year: 2026, month: 1);
      expect(grid.first.year, 2025);
      expect(grid.weeks.first.first.inMonth, isFalse);
    });

    // 注：`inMonth` 里那个「年份也要相等」的判断**没有用例钉得住** ——
    // 六行窗口最多跨三个月，同一个月号出现不了两次。去掉年份比较
    // 全部用例照样绿。实现那边把这件事写明了，这里不假装测到了。
  });

  group('周视图那一行', () {
    test('包含给定日期，且从周起始日开始', () {
      // 2026-09-10 是周四。
      final week = weekOf(const PlanDate(2026, 9, 10));
      expect(_days(week), [
        '9-7',
        '9-8',
        '9-9',
        '9-10',
        '9-11',
        '9-12',
        '9-13',
      ]);
    });

    test('周起始日当天，整行就从它开始', () {
      final week = weekOf(const PlanDate(2026, 9, 7));
      expect(week.first.date, const PlanDate(2026, 9, 7));
    });

    test('周日起始时同一天落在另一行', () {
      final week = weekOf(
        const PlanDate(2026, 9, 10),
        firstDayOfWeek: DateTime.sunday,
      );
      expect(_days(week).first, '9-6');
    });
  });

  group('星期表头的顺序', () {
    test('周一起始是 1..7', () {
      expect(weekdayOrder(), [1, 2, 3, 4, 5, 6, 7]);
    });

    test('周日起始是 7,1..6 —— 周日在最前，不是最后', () {
      expect(weekdayOrder(firstDayOfWeek: DateTime.sunday), [
        7,
        1,
        2,
        3,
        4,
        5,
        6,
      ]);
    });

    test('表头顺序与格子顺序对得上', () {
      // 两处各算一遍的话，表头写着「一」而那一列其实是周日 ——
      // 这种错没人会当成 bug 报，只会觉得「这个日历怪怪的」。
      for (final start in [
        DateTime.monday,
        DateTime.sunday,
        DateTime.saturday,
      ]) {
        final grid = monthGrid(year: 2026, month: 9, firstDayOfWeek: start);
        expect(
          [for (final c in grid.weeks.first) c.date.weekday],
          weekdayOrder(firstDayOfWeek: start),
          reason: 'firstDayOfWeek=$start',
        );
      }
    });
  });
}

/// 月历的格子（view-specs §3.1）。
///
/// **纯函数**：给一个月份和「一周从周几起」，出来的格子是确定的。
/// 混进 widget 之后，「2 月是五行还是六行」「上个月的尾巴补几天」
/// 就得靠数屏幕上的方块去验了。
library;

import 'package:meta/meta.dart';

import '../../../../core/time/plan_date.dart';

/// 一周七天。
const int daysPerWeek = 7;

/// 月视图固定六行（§3.1）。
///
/// **不按当月实际需要收缩。** 2026 年 2 月正好四行，3 月要六行 ——
/// 行数随月份变的话，格子高度跟着变，左右滑动切月时整个下半屏
/// 会上下跳。固定六行的代价是偶尔多一行灰日期，比跳动小得多。
const int weeksPerMonthView = 6;

/// 格子里的一天。
@immutable
final class MonthCell {
  const MonthCell({required this.date, required this.inMonth});

  final PlanDate date;

  /// 是不是**当月**的日子。false 表示补进来的上/下月尾巴，画成灰的。
  final bool inMonth;
}

/// 一个月的格子：六行 × 七天。
@immutable
final class MonthGrid {
  const MonthGrid({
    required this.year,
    required this.month,
    required this.weeks,
  });

  final int year;
  final int month;

  /// 六行，每行七格。
  final List<List<MonthCell>> weeks;

  /// 头尾两天，供数据层一次性取一个窗口（含补进来的灰日期 ——
  /// 它们也要显示标记，否则月初那几格看起来是空的）。
  PlanDate get first => weeks.first.first.date;
  PlanDate get last => weeks.last.last.date;
}

/// 排 [year] 年 [month] 月的格子。
///
/// [firstDayOfWeek] 用 ISO 星期（周一 = 1 … 周日 = 7），
/// 与 `PlanDate.weekday` 同一套（配置项 `view.firstDayOfWeek`，默认周一）。
MonthGrid monthGrid({
  required int year,
  required int month,
  int firstDayOfWeek = DateTime.monday,
}) {
  final firstOfMonth = PlanDate(year, month, 1);

  // 这一行要从哪天开始 —— 往前退到最近的一个「周起始日」。
  //
  // `(a - b) % 7` 在 Dart 里对负数返回**非负**（与 C 系不同），
  // 所以周日起始（7）遇上周一（1）时 `(1 - 7) % 7 == 1`，退一天，是对的。
  final lead = (firstOfMonth.weekday - firstDayOfWeek) % daysPerWeek;
  final start = firstOfMonth.addDays(-lead);

  return MonthGrid(
    year: year,
    month: month,
    weeks: [
      for (var w = 0; w < weeksPerMonthView; w++)
        [
          for (var d = 0; d < daysPerWeek; d++)
            _cellAt(start.addDays(w * daysPerWeek + d), year, month),
        ],
    ],
  );
}

MonthCell _cellAt(PlanDate date, int year, int month) =>
    MonthCell(date: date, inMonth: date.year == year && date.month == month);

// 关于上面那个 `date.year == year`：**没有测试钉得住它**。
// 六行的窗口最多横跨三个日历月，同一个月号不可能出现两次，
// 所以去掉年份比较之后全部用例照样绿（变异验证过）。
//
// 留着它不是因为「必须这样写」，是因为这个函数收了 year 和 month
// 两个参数，就该两个都认。按 §7.1.1 的判据，这种没有测试撑腰的写法
// **不配写一句斩钉截铁的注释** —— 所以这里写的是它的真实状态：
// 防御性的，且不可测。哪天窗口拉长到跨年，它才会开始起作用。

/// 周视图的那一行：包含 [date] 的那一周（§3.1）。
List<MonthCell> weekOf(PlanDate date, {int firstDayOfWeek = DateTime.monday}) {
  final lead = (date.weekday - firstDayOfWeek) % daysPerWeek;
  final start = date.addDays(-lead);
  return [
    for (var d = 0; d < daysPerWeek; d++)
      // 周视图里没有「不是当月」这回事 —— 一周七天都是正主。
      MonthCell(date: start.addDays(d), inMonth: true),
  ];
}

/// 星期表头的顺序（「一 二 三 四 五 六 日」还是「日 一 …」）。
///
/// 返回 ISO 星期号，供界面去查名字 —— 名字是 l10n 的事，不在这里。
List<int> weekdayOrder({int firstDayOfWeek = DateTime.monday}) => [
  for (var i = 0; i < daysPerWeek; i++)
    (firstDayOfWeek - 1 + i) % daysPerWeek + 1,
];

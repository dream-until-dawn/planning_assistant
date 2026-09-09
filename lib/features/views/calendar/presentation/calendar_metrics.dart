/// 日历的尺寸（view-specs §3.1）。
///
/// 单独一份**常量**而不是散在 widget 里：断言型测试要能在不构建
/// widget 树的情况下直接查这些值（testing-strategy §7.1）。
library;

abstract final class CalendarMetrics {
  /// 星期表头那一条。
  static const double headerHeight = 28;

  /// 日期数字那个圆（今天描边、选中实心，§3.2）。
  ///
  /// 24 而不是 40：一行要塞下数字 + 三层横条 + 一排色点，
  /// 圆再大就把横条挤没了。触控目标由整格补足 —— 整格远大于 48。
  static const double dayCircle = 24;

  /// 一条横条的高度与间距。
  static const double bandHeight = 12;
  static const double bandGap = 2;

  /// 横条从格子顶端往下多少开始排 —— 让开日期数字。
  static const double bandsTop = dayCircle + 2;

  /// 色点。
  static const double dotSize = 6;
  static const double dotGap = 3;

  /// 拖拽把手那一条的高度（含触控留白）。
  static const double handleHeight = 20;

  /// 第 [lane] 层横条的顶边距格子顶端多远。
  static double bandTop(int lane) => bandsTop + lane * (bandHeight + bandGap);

  /// 排 [lanes] 层横条一共要多高。
  static double bandsExtent(int lanes) =>
      lanes == 0 ? 0 : bandsTop + lanes * (bandHeight + bandGap);
}

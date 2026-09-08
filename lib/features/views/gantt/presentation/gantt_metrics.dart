/// 竖向甘特的尺寸（view-specs §4）。
///
/// 单独一份**常量**：断言型测试要能在不构建 widget 树的情况下直接查
/// 这些值（testing-strategy §7.1），而画笔与命中测试用的是同一套数。
library;

abstract final class GanttMetrics {
  /// 泳道表头那一条。
  static const double headerHeight = 32;

  /// 左侧日期栏。
  static const double dateGutter = 44;

  /// 每分钟几个逻辑像素。
  ///
  /// 一天 = 48dp。一屏（约 600dp 可视）能看到十二天多 —— §4.1 说的
  /// 「一屏能看两周以上」靠滚动补足，把一天压到能一屏塞进十四天
  /// （43dp）的话，条上的文字就没地方放了。
  static const double pixelsPerMinute = 48 / 1440;

  /// 条与条之间、条与泳道边之间的留白。
  static const double barGap = 3;

  /// 阶段段落之间的缺口（§4.3「段间有 2dp 缺口」）。
  static const double segmentGap = 2;

  /// 最短的条也要看得见、点得着。
  static const double minBarLength = 6;

  /// 一天多高。
  static const double dayHeight = 1440 * pixelsPerMinute;
}

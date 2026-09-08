/// 时间轴的尺寸（view-specs §1.2）。
///
/// 单独一份**常量**而不是散在 widget 里：断言型测试要能在不构建
/// widget 树的情况下直接查这些值（testing-strategy §7.1），
/// 而「一小时有多高」这件事同时被刻度、块、当前时刻线三处用到。
library;

/// 一天有多少分钟。与 `timeline_blocks.dart` 里的同名常量是同一个数，
/// 这里再写一遍是为了让 presentation 不必为一个整数去 import application。
const int _minutesPerDay = 1440;

abstract final class TimelineMetrics {
  /// **一格的高度**，与刻度粒度无关。
  ///
  /// 于是选「15 分钟」等于把一天拉长四倍 —— 这正是那个配置项的意思
  /// （见 `timelineTickMinutes` 的注释）：只加密刻度线而不改比例的话，
  /// 15 分钟一格只有十几个逻辑像素，标签互相压着。
  static const double tickHeight = 48;

  /// 最小块高（§1.2）。短任务也不小于它，保证点得着。
  ///
  /// 触控目标 48 由内边距补足 —— 块本身不能强撑到 48，
  /// 否则 60 分钟格下一个 30 分钟的任务会比一小时的还高。
  static const double minBlockHeight = 36;

  /// 左侧时刻标签那一栏。
  static const double gutterWidth = 52;

  /// 并排的块之间留的缝。
  static const double columnGap = 3;

  /// 每分钟几个逻辑像素。
  static double pixelsPerMinute(int tickMinutes) => tickHeight / tickMinutes;

  /// 一整天有多高。
  static double dayHeight(int tickMinutes) =>
      _minutesPerDay * pixelsPerMinute(tickMinutes);

  /// 「+N」那一格的宽度。有折叠时从可用宽里**先扣掉它**，
  /// 不然它会盖在第三列的标题上 —— 而那正是「+N」本该避免的事。
  static const double pillWidth = 44;

  /// 首次进入时滚到哪里（§1.2「滚动到当前时刻前 1 小时」）。
  ///
  /// 前一小时而不是正对当前时刻：正对的话「现在」贴在屏幕顶边，
  /// 刚过去的事全在视野之外 —— 而「我刚才是不是漏了什么」
  /// 恰恰是打开时间轴最常见的问题。
  static const int leadInMinutes = 60;
}

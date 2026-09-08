/// 日历上下两半的比例（view-specs §3.1「比例可拖拽，记住用户选择」）。
///
/// **放 application 而不是 presentation**：配置注册表要用它的默认值与
/// 上下限，而注册表在 application 层，够不到 presentation（module-map §3，
/// 架构守卫盯着）。这三个数说的是「这个配置值的取值范围是什么」，
/// 本来就是配置的知识，不是像素的知识。
library;

abstract final class CalendarSplit {
  /// 上下两半的比例上下限。
  ///
  /// **两头都留住**：拖到底把某一半压成 0 的话，那一半就再也拖不回来了
  /// —— 与「到某天为止」那条死路是同一种毛病，只是发生在手势上。
  static const double min = 0.35;
  static const double max = 0.8;
  static const double byDefault = 0.58;

  /// 夹回合法区间。存进来的值可能来自手改的配置文件。
  static double clamp(double value) => value.clamp(min, max);
}

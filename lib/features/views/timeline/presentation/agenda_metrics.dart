/// 议程那条竖轴的几何（view-specs §1.2）。
///
/// **只有三个常量，但它们必须共用**：时间栏的宽度、圆点的直径、
/// 竖线的位置互相咬合 —— 各处各写一个数的话，圆点会偏出竖线，
/// 而那种偏移在一台机器上看着「还行」，换个字号就明显了。
///
/// 上一版是 `TimelineMetrics`：一天的高度、每分钟多少像素、最小块高。
/// 那套数全是「连续刻度尺」才需要的，视图改成跳跃排布之后一个都不剩。
library;

import '../../../../design/tokens/dimensions.dart';

abstract final class AgendaMetrics {
  /// 时间栏宽度。装得下「23:59」与「全天」，再宽就把卡片挤窄了。
  static const double gutterWidth = 44;

  /// 时间栏与卡片之间那条轴占的宽度。
  static const double railWidth = Spacing.xl;

  /// 竖线与圆点的中心（相对行的左边缘）。
  static const double railCenter = gutterWidth + railWidth / 2;

  /// 圆点直径。
  static const double dotSize = Spacing.sm;
}

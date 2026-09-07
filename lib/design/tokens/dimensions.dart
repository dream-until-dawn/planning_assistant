/// 尺寸类 token：字阶、圆角、间距、阴影、动效（design-system §3–§7）。
///
/// 全部是**常量**，不是 `ThemeData` 上的字段 —— 断言型测试要能在不构建
/// Widget 树的情况下直接查这些值（测试策略 §7.1）。
library;

import 'package:flutter/painting.dart';

/// 字阶（§3.3）。行高偏大（1.4–1.6）是刻意的：中文在宽松行高下更「轻松」。
abstract final class TypeScale {
  static const double displaySize = 28;
  static const double displayHeight = 1.3;
  static const FontWeight displayWeight = FontWeight.w600;

  static const double titleLgSize = 22;
  static const double titleLgHeight = 1.35;
  static const FontWeight titleLgWeight = FontWeight.w600;

  static const double titleMdSize = 18;
  static const double titleMdHeight = 1.4;
  static const FontWeight titleMdWeight = FontWeight.w600;

  static const double bodyLgSize = 16;
  static const double bodyLgHeight = 1.55;
  static const FontWeight bodyLgWeight = FontWeight.w400;

  static const double bodyMdSize = 14;
  static const double bodyMdHeight = 1.6;
  static const FontWeight bodyMdWeight = FontWeight.w400;

  static const double labelSize = 13;
  static const double labelHeight = 1.4;
  static const FontWeight labelWeight = FontWeight.w500;

  static const double captionSize = 12;
  static const double captionHeight = 1.45;
  static const FontWeight captionWeight = FontWeight.w400;

  /// 「大号文字」的门槛（WCAG）：≥18px，或 ≥14px 且加粗。
  ///
  /// 对比度守卫按它决定该用 4.5 还是 3.0 —— 写死在这里而不是各处判断，
  /// 否则「这算不算大号文字」会在每个组件里被重新回答一次。
  static bool isLargeText(double sizePx, FontWeight weight) =>
      sizePx >= 18 || (sizePx >= 14 && weight.value >= FontWeight.w700.value);
}

/// 字号缩放（§3.4）。
///
/// **两层相乘**：应用内 [appScaleMin]..[appScaleMax] × 系统缩放。
/// 用户能达到的最坏有效缩放是 [worstEffectiveScale]，
/// 而 NFR-A11Y-02 字面只写了系统的 200% —— golden 必须覆盖到前者。
abstract final class FontScale {
  static const double appScaleMin = 0.85;
  static const double appScaleDefault = 1.0;
  static const double appScaleMax = 1.4;

  /// 系统缩放上限（Android 的无障碍设置）。
  static const double systemScaleMax = 2.0;

  /// 1.4 × 2.0。**这个数没有出现在任何需求文档里**，是两处相乘得出的。
  static const double worstEffectiveScale = appScaleMax * systemScaleMax;

  /// 视觉回归必须跑满的档位（§3.4）。
  static const List<double> goldenScales = [
    1.0,
    systemScaleMax,
    worstEffectiveScale,
  ];
}

/// 圆角（§4）。
abstract final class Radii {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double full = 999;

  static const List<double> all = [xs, sm, md, lg, xl];
}

/// `theme.cornerStyle` 的三档倍率（§4，FR-CFG-02）。
enum CornerStyle {
  soft(1.25),
  standard(1.0),
  sharp(0.5);

  const CornerStyle(this.factor);

  /// 整体乘在 [Radii] 上的倍率。
  final double factor;

  /// 应用倍率。[Radii.full] 不参与缩放 —— 药丸按钮无论哪档都该是药丸。
  double apply(double radius) =>
      radius >= Radii.full ? radius : radius * factor;
}

/// 间距（§5）。4 的倍数。
abstract final class Spacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double giant = 48;

  static const List<double> all = [
    xxs,
    xs,
    sm,
    md,
    lg,
    xl,
    xxl,
    xxxl,
    huge,
    giant,
  ];

  /// 图标与文字之间。
  static const double iconToText = sm;

  /// 卡片内边距。
  static const double cardPadding = lg;

  /// 卡片之间。
  static const double cardGap = md;

  /// 分组之间。
  static const double groupGap = xxl;

  /// 页面左右边距。
  static const double pageHorizontal = lg;

  /// **触控目标最小尺寸，无障碍硬要求。**
  ///
  /// 不是「建议」——低于它的可点击区域由断言型测试直接判失败
  /// （测试策略 §7.1：查 `tester.getSize`，不拍图）。
  static const double minTouchTarget = 48;
}

/// 阴影（§6）。不用锐利深阴影。
abstract final class Shadows {
  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x0F504659),
      offset: Offset(0, 2),
      blurRadius: 12,
      spreadRadius: -2,
    ),
  ];

  static const List<BoxShadow> lifted = [
    BoxShadow(
      color: Color(0x1A504659),
      offset: Offset(0, 6),
      blurRadius: 24,
      spreadRadius: -4,
    ),
  ];

  /// 暗色主题**不用阴影**，改用表面提亮（§6）——
  /// 暗色里阴影几乎不可见，画了也白画。
  static const List<BoxShadow> none = <BoxShadow>[];
}

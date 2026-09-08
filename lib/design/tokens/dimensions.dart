/// 尺寸类 token：字阶、圆角、间距、阴影、动效（design-system §3–§7）。
///
/// 全部是**常量**，不是 `ThemeData` 上的字段 —— 断言型测试要能在不构建
/// Widget 树的情况下直接查这些值（测试策略 §7.1）。
library;

import 'package:flutter/animation.dart';
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

/// 动效（§7）。
///
/// **文档里那张表一直没有代码。** 加它是因为日历切月是第一个消费者 ——
/// 在此之前「motion.slow = 320ms」只是一行 Markdown，
/// 谁写动画都是随手填个数字，而那正是 token 要防的事。
///
/// **关动效时时长降为 0，但状态变化本身保留**（§7 的原话）——
/// 不能因为关了动效就看不出发生了什么。所以这里给的是**时长**，
/// 由调用方在 `reducedMotionOf()` 为真时换成 [Duration.zero]，
/// 而不是让调用方跳过整个切换。
abstract final class Motion {
  /// 按压反馈、涟漪。
  static const Duration fast = Duration(milliseconds: 120);

  /// 展开收起、淡入淡出。
  static const Duration base = Duration(milliseconds: 200);

  /// 页面转场。
  static const Duration slow = Duration(milliseconds: 320);

  /// **仅限**勾选完成、新增落位的回弹（§7：只用在正反馈上）。
  static const Duration bouncy = Duration(milliseconds: 280);

  static const Curve fastCurve = Curves.easeOutCubic;
  static const Curve baseCurve = Curves.easeOutCubic;
  static const Curve slowCurve = Curves.easeInOutCubic;
  static const Curve bouncyCurve = Curves.easeOutBack;

  /// 关掉动效时用它，而不是各处写 `Duration.zero`。
  static Duration of(Duration duration, {required bool reduced}) =>
      reduced ? Duration.zero : duration;
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
  /// 卡片阴影。**两层**：一层定边，一层给深度。
  ///
  /// 页面底改成纯白之后，卡片与页面同色，边界完全由这个阴影承担
  /// （§2.2、§6）。原来的单层 6% / blur 12 是配奶油底的 ——
  /// 在纯白上几乎看不见，卡片读起来像一段没有容器的文字。
  ///
  /// 分两层而不是把单层调深：
  /// - **定边那层**贴得近（y=1, blur=3），负责「这里有个边」——
  ///   它必须紧，散开就成了一团灰雾；
  /// - **深度那层**散得开（y=4, blur=16, spread=-4），负责「它浮起来」。
  ///
  /// 把单层调深到同样可见的话，会得到一圈发灰的硬边 ——
  /// 正是 §6 第一句「不用锐利深阴影」要避免的。
  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x14504659), offset: Offset(0, 1), blurRadius: 3),
    BoxShadow(
      color: Color(0x1A504659),
      offset: Offset(0, 4),
      blurRadius: 16,
      spreadRadius: -4,
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

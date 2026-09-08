/// 色彩 token（design-system §2）。
///
/// **所有颜色显式指定，不用 `ColorScheme.fromSeed`** —— 它会把低饱和色
/// 算成高饱和，破坏「可爱清新」的基调（§9）。
///
/// 每个 token 的对比度由 `test/design/contrast_test.dart` 逐对断言，
/// 而不是只写在文档里 —— 文档里的数字会随改色悄悄失效。
library;

import 'package:flutter/painting.dart';

/// 24 位 RGB 常量，配套 [toColor]。
///
/// token 用 `int` 而不是 `Color` 存：对比度守卫要枚举全空间，
/// 那条路径上不能有对象构造（见 `contrast.dart`）。
extension RgbInt on int {
  Color toColor() => Color(0xFF000000 | this);
}

/// 品牌色。
///
/// ## 为什么 primary 拆成 `.fill` 与 `.graphic`
///
/// 这不是新规矩，是 §2.4 对语义色已经做过的同一件事：一个低饱和色要
/// 同时干「装饰性填充」和「承载信息的图形」，而这两件事的门槛不同 ——
/// 填充只需保证其上文字达标，图形要自己与表面达到 3:1。
///
/// 不拆的话会撞上一个真实的矛盾：§2.1 把 primary 用于**进度条**
/// （非文字图形，§10 要求 ≥3:1），而 `#7FD1C1` 对三个亮表面只有
/// 1.72 / 1.78 / 1.58。语义色拆了，品牌色曾经没拆。
abstract final class BrandColors {
  /// 填充：按钮底、选中态背景、装饰。
  ///
  /// **不作唯一信息载体**（§2.5 的同一条原则）。其上文字一律用
  /// [TextColors.onBrand]，实测 6.62:1 ✅ —— 白字只有 1.78:1，禁止。
  static const int primaryFill = 0x7FD1C1;

  /// 图形：进度条、选中指示、承载状态的非文字图形。
  ///
  /// 与 [primaryFill] 同色相同饱和（H 168.4° / S 0.471），只压亮度。
  /// 对三个亮表面实测 3.35 / 3.46 / 3.08，全部 ≥3.0 ✅。
  ///
  /// **其上不得放文字**，**它自己也不作文字色**：`onBrand` 在其上只有
  /// 3.40、白字 3.46，而它压在亮表面上是 3.35 / 3.46 / 3.08 ——
  /// 图形够用，正文都不够。作文字请用 [primaryText]。
  ///
  /// 由 `test/design/token_usage_test.dart` 守着：那个守卫不扫源码文本，
  /// 而是渲染组件后遍历渲染树，把每段文字与它实际压着的背景配对算对比度。
  static const int primaryGraphic = 0x379986;

  /// 文字：品牌色**作文字**时用这个，不是 [primaryGraphic]。
  ///
  /// [primaryGraphic] 对三个亮表面只有 3.35 / 3.46 / 3.08 —— 图形够用，
  /// 正文不够。所以品牌色也要按 §2.4 那条规矩拆成填充 / 图形 / 文字三级，
  /// 语义色早就拆了，品牌色这里补齐。
  ///
  /// 值是**派生的不是拍的**：同色相同饱和下，用 `deriveGraphicColor`
  /// 以 ratio 4.5 对最暗亮表面（sunken）二分求解，取仍达标的**最大亮度**
  /// —— 也就是在合规前提下最接近品牌色的那一个。
  /// 实测 5.12 / 4.95 / 4.55 ✅。
  ///
  /// 暗色主题不需要这一级：[primaryDark] 对三个暗表面是 6.17–7.46，
  /// 本来就够正文用。这也是「暗色不是亮色的机械反转」的一个具体例子。
  static const int primaryText = 0x2C7A6B;

  static const int secondaryFill = 0xFFB7C5;
  static const int tertiaryFill = 0xFFD79A;

  /// 暗色主题的主色。
  ///
  /// 暗色**不需要**第二个 token：`#5FB3A3` 对三个暗表面实测
  /// 6.97 / 6.17 / 7.46，本就 ≥3.0，填充与图形可共用。
  static const int primaryDark = 0x5FB3A3;
  static const int secondaryDark = 0xD98C9C;
  static const int tertiaryDark = 0xD9AE6E;
}

/// 表面（§2.2）。
abstract final class SurfaceColors {
  static const int canvas = 0xFFFFFF;
  static const int card = 0xFFFFFF;
  static const int sunken = 0xF2F2F5;
  static const int borderSubtle = 0xE4E4EA;

  static const int canvasDark = 0x1B1A1F;
  static const int cardDark = 0x26242C;
  static const int sunkenDark = 0x141317;
  static const int borderSubtleDark = 0x35323C;

  /// 亮色三表面。**顺序无关**，但集合必须完整 ——
  /// 只算一个表面就下结论是本项目栽过的坑（评审 S-5）。
  static const List<int> lightSurfaces = [canvas, card, sunken];
  static const List<int> darkSurfaces = [canvasDark, cardDark, sunkenDark];
}

/// 文字（§2.3）。
abstract final class TextColors {
  static const int primary = 0x3A3742;
  static const int secondary = 0x6E6A78;

  /// **仅用于禁用态**，2.34:1 不承载信息。对比度守卫对它豁免。
  static const int disabled = 0xA9A5B0;

  /// 品牌色填充上的文字。
  static const int onBrand = 0x1F3D37;

  static const int primaryDark = 0xFFFFFF;
  static const int secondaryDark = 0xB8B4C0;
  static const int disabledDark = 0x6E6A78;
}

/// 语义色（§2.4）：填充与文字分开。
///
/// ⚠️ **三个 `.text` 的值比 design-system §2.4 初稿深了一点点**
/// （done/soon/overdue）。原值只在 `surface.canvas` 上算过 4.6x:1，
/// 而对最暗的 `surface.sunken` 只有 4.24 / 4.37 / 4.29 —— 不到 4.5。
///
/// 这正是「只算一个表面就下结论」那类错误，由 `contrast_test.dart`
/// 在写任何 UI 之前抓到。修正后色相完全不变，三表面最差值 4.52 / 4.51 / 4.51。
abstract final class SemanticColors {
  static const int doneFill = 0x8FD9A8;
  static const int doneText = 0x3F7A55;
  static const int soonFill = 0xFFC97A;
  static const int soonText = 0x916629;

  /// 逾期刻意不用正红：暖陶土能读清但不制造焦虑（「低压力」原则）。
  static const int overdueFill = 0xF5A38C;
  static const int overdueText = 0xA35B43;

  static const int infoFill = 0xA8C8F0;
  static const int infoText = 0x3F6FA8;
  static const int dangerFill = 0xE88B8B;
  static const int dangerText = 0xA85555;

  /// `*.fill` 全集，供 lint 断言它们不出现在文字位置。
  static const List<int> fills = [
    doneFill,
    soonFill,
    overdueFill,
    infoFill,
    dangerFill,
  ];
}

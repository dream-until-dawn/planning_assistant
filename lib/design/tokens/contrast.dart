/// WCAG 2.1 对比度计算与品牌色派生。
///
/// **纯计算，不依赖 Flutter 的 Color** —— 用 8 位通道整数进出。
/// 理由是性能：对比度守卫要枚举 24 位全空间（16,777,216 个主色），
/// 对象化 API 逐色构造会高一到两个数量级，那时全集穷举不再可行
/// （见 [probe-artifacts/contrast-space](../../../docs/05-engineering/probe-artifacts/contrast-space/README.md)）。
library;

import 'dart:math' as math;

/// sRGB 通道线性化查表。
///
/// 每通道只有 256 个取值，所以 `math.pow` 只在建表时调 256 次、
/// **不进内循环**。这是全空间穷举能在秒级完成的关键。
final List<double> _linearized = List<double>.generate(256, (i) {
  final c = i / 255.0;
  return c <= 0.04045
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}, growable: false);

/// WCAG 2.1 相对亮度。
double relativeLuminance(int r, int g, int b) =>
    0.2126 * _linearized[r] + 0.7152 * _linearized[g] + 0.0722 * _linearized[b];

/// 两个相对亮度之间的对比度。
double contrastOfLuminance(double a, double b) {
  final hi = a > b ? a : b;
  final lo = a > b ? b : a;
  return (hi + 0.05) / (lo + 0.05);
}

/// 两个颜色之间的对比度。
double contrastRatio(int rgbA, int rgbB) => contrastOfLuminance(
  relativeLuminance((rgbA >> 16) & 0xFF, (rgbA >> 8) & 0xFF, rgbA & 0xFF),
  relativeLuminance((rgbB >> 16) & 0xFF, (rgbB >> 8) & 0xFF, rgbB & 0xFF),
);

/// 与某个更亮的背景达到 [ratio] 所允许的**最大**前景亮度。
///
/// 由 `(L_bg + 0.05) / (L_fg + 0.05) >= ratio` 解出。
/// 有闭式解意味着不必对每个表面各验一遍：**取最暗的那个背景**，
/// 它过了其余必过。
double maxForegroundLuminance(double backgroundLuminance, double ratio) =>
    (backgroundLuminance + 0.05) / ratio - 0.05;

/// HSL 三元组，分量均为 0..1。
typedef Hsl = ({double h, double s, double l});

/// 24 位 RGB，各分量 0..255。
typedef Rgb = ({int r, int g, int b});

Hsl rgbToHsl(int r, int g, int b) {
  final rf = r / 255.0, gf = g / 255.0, bf = b / 255.0;
  final maxV = math.max(rf, math.max(gf, bf));
  final minV = math.min(rf, math.min(gf, bf));
  final l = (maxV + minV) / 2;
  final d = maxV - minV;
  if (d == 0) return (h: 0, s: 0, l: l);

  final s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV);
  double h;
  if (maxV == rf) {
    h = ((gf - bf) / d + (gf < bf ? 6 : 0)) / 6;
  } else if (maxV == gf) {
    h = ((bf - rf) / d + 2) / 6;
  } else {
    h = ((rf - gf) / d + 4) / 6;
  }
  return (h: h, s: s, l: l);
}

Rgb hslToRgb(double h, double s, double l) {
  if (s == 0) {
    final v = (l * 255).round().clamp(0, 255);
    return (r: v, g: v, b: v);
  }
  final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  final p = 2 * l - q;
  double channel(double t) {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  }

  return (
    r: (channel(h + 1 / 3) * 255).round().clamp(0, 255),
    g: (channel(h) * 255).round().clamp(0, 255),
    b: (channel(h - 1 / 3) * 255).round().clamp(0, 255),
  );
}

/// 派生「图形色」：与最暗亮色表面达到 [ratio]，同时**尽可能保留原色**。
///
/// ## 为什么求「仍达标的最大亮度」而不是「压到阈值以下」
///
/// 两者达标性完全一样，但前者平均只需把亮度压到原值的 **87.3%** ——
/// 大多数主色几乎不用变。一刀切压到阈值会把本来不需要变深的色也压深，
/// 视觉上明显更差。
///
/// ## 量化是这里唯一的真风险，本实现用「在量化后判定」化解
///
/// 既然求的是「仍达标的最大亮度」，解必然紧贴阈值。实测六个跨色相派生值，
/// 每通道 +1 之后 **6/6 全部**掉出 3.0：
///
/// ```
/// 薄荷 #389B88 3.0026 → 2.9652    天空 #4B8DE0 3.0156 → 2.9779
/// 樱花 #FF4166 3.0085 → 2.9954    纯黄 #909000 3.0206 → 2.9823
/// 奶油 #C87900 3.0130 → 2.9760    纯白 #8B8B8B 3.0262 → 2.9868
/// ```
///
/// 所以「在浮点上二分、最后再量化」的写法会有约一半的输出越界 ——
/// 那种写法必须朝暗取整来补救。
///
/// **本实现不走那条路**：二分的每个候选都先 [hslToRgb] 量化成 8 位色、
/// 再判定，只接受**量化后仍达标**的候选。于是 `best` 由构造就是合法值，
/// 不需要任何事后修正。
///
/// 这个区别值得写下来：初版在循环外加了一段「朝暗逐通道减 1」的兜底，
/// 变异测试显示**删掉它全空间 0 例越界** —— 它从不触发，是死代码，
/// 而且注释把它说成了保证达标的机制。真正的机制是上面那一句。
///
/// 于是全空间测试验的是「构造确实成立」，而不是
/// 「跑 1677 万次没找到反例」—— 后者永远只是没找到。
///
/// [ratio] 默认 3.0（非文字关键图形的门槛）。
Rgb deriveGraphicColor(
  int r,
  int g,
  int b, {
  required double darkestSurfaceLuminance,
  double ratio = 3.0,
}) {
  final limit = maxForegroundLuminance(darkestSurfaceLuminance, ratio);
  if (relativeLuminance(r, g, b) <= limit) {
    return (r: r, g: g, b: b); // 原色已达标，不动
  }

  final hsl = rgbToHsl(r, g, b);

  // 二分找仍达标的最大亮度。亮度降到 0 必然满足，所以一定有解 ——
  // 这个存在性是平凡的，真正要保证的是下面那一步的舍入。
  var lo = 0.0;
  var hi = hsl.l;
  var best = hslToRgb(hsl.h, hsl.s, 0);
  for (var i = 0; i < 24; i++) {
    final mid = (lo + hi) / 2;
    // **先量化再判定** —— 判的是真正会被用的那个 8 位色，
    // 而不是浮点中间值。这一步就是达标性的构造性保证。
    final candidate = hslToRgb(hsl.h, hsl.s, mid);
    if (relativeLuminance(candidate.r, candidate.g, candidate.b) <= limit) {
      best = candidate;
      lo = mid;
    } else {
      hi = mid;
    }
  }

  // 无需事后修正：上面每次接受候选前都已按**量化后**的值判过一遍。
  return best;
}

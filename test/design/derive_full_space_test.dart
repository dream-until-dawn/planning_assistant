/// 用户自定义主色的全空间验证（design-system §10.1、§10.2）。
///
/// ## 这个测试在验什么、不在验什么
///
/// 「对任意主色存在达标的图形色」是**平凡真**的 —— 亮度降到 0 必然满足。
/// 所以这里**不是在找反例**，找不到反例什么也证明不了。
///
/// 要验的是：**`deriveGraphicColor()` 的输出确实落在阈值内** ——
/// 也就是二分收敛后的浮点亮度量化到 8 bit 时，舍入没有把它顶出去。
///
/// 这个区别不是措辞：前者是「跑了 1677 万次没找到反例」，
/// 后者是「达标由构造保证，而这里验证构造成立」。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/design/tokens/colors.dart';
import 'package:planning_assistant/design/tokens/contrast.dart';

const double kGraphicRatio = 3.0;

double _lum(int rgb) =>
    relativeLuminance((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF);

String _hex(int r, int g, int b) =>
    '#${r.toRadixString(16).padLeft(2, '0')}'
            '${g.toRadixString(16).padLeft(2, '0')}'
            '${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();

void main() {
  final darkest = _lum(SurfaceColors.sunken);
  final limit = maxForegroundLuminance(darkest, kGraphicRatio);

  group('全空间：每一个主色的派生结果都落在阈值内', () {
    test('16,777,216 个主色，0 例越界', () {
      // 采样会让「范围内不允许出现不达标组合」这句话变成猜测。
      // 域是 2^24 个离散点，比 tz 数据库还小，能枚举就枚举。
      final violations = <String>[];
      var checked = 0;
      var unchanged = 0;

      for (var r = 0; r < 256; r++) {
        for (var g = 0; g < 256; g++) {
          for (var b = 0; b < 256; b++) {
            final d = deriveGraphicColor(
              r,
              g,
              b,
              darkestSurfaceLuminance: darkest,
            );
            checked++;
            if (d.r == r && d.g == g && d.b == b) unchanged++;
            if (relativeLuminance(d.r, d.g, d.b) > limit) {
              if (violations.length < 20) {
                violations.add('  ${_hex(r, g, b)} → ${_hex(d.r, d.g, d.b)}');
              }
            }
          }
        }
      }

      expect(checked, 256 * 256 * 256, reason: '必须是全集，不是采样');
      expect(
        violations,
        isEmpty,
        reason:
            '${violations.length}+ 个主色的派生结果越过阈值（舍入方向错了）：\n'
            '${violations.join('\n')}',
      );
      // 前提断言：若「原色已达标、不动」的比例是 100%，
      // 说明派生逻辑根本没被走到，上面的断言就是空对空。
      expect(unchanged, lessThan(checked), reason: '没有任何主色触发派生 —— 阈值算错了？');
      expect(unchanged, greaterThan(0), reason: '深色主色本就该原样保留');
    });

    test('派生结果保持色相与饱和度，只压亮度', () {
      // 抽查一批有代表性的色相。改了色相的话，用户会觉得进度条
      // 是另一个颜色 —— 那是功能正确但产品错误。
      const samples = [
        0x7FD1C1,
        0xFFB7C5,
        0xFFD79A,
        0xA8C8F0,
        0xFFFF00,
        0xFF0000,
        0x00FF00,
        0x0000FF,
      ];
      for (final rgb in samples) {
        final r = (rgb >> 16) & 0xFF, g = (rgb >> 8) & 0xFF, b = rgb & 0xFF;
        final src = rgbToHsl(r, g, b);
        final d = deriveGraphicColor(r, g, b, darkestSurfaceLuminance: darkest);
        final out = rgbToHsl(d.r, d.g, d.b);

        expect(out.h, closeTo(src.h, 0.01), reason: '${_hex(r, g, b)} 色相变了');
        expect(out.s, closeTo(src.s, 0.02), reason: '${_hex(r, g, b)} 饱和度变了');
        expect(out.l, lessThanOrEqualTo(src.l + 1e-9));
      }
    });

    test('保留尽量多的亮度 —— 不是一刀切压到阈值', () {
      // 「压到阈值以下」与「仍达标的最大亮度」达标性相同，视觉差别很大。
      // 若有人图省事改成前者，这条会红。
      const rgb = 0x7FD1C1;
      const r = (rgb >> 16) & 0xFF, g = (rgb >> 8) & 0xFF, b = rgb & 0xFF;
      final d = deriveGraphicColor(r, g, b, darkestSurfaceLuminance: darkest);

      // 再亮一档就该越界 —— 这证明它取的确实是「最大」。
      final brighter = (
        r: (d.r + 1).clamp(0, 255),
        g: (d.g + 1).clamp(0, 255),
        b: (d.b + 1).clamp(0, 255),
      );
      expect(
        relativeLuminance(brighter.r, brighter.g, brighter.b),
        greaterThan(limit),
        reason: '还能更亮却没取，说明不是「最大亮度」',
      );
    });
  });

  group('达标性的构造性保证：在量化后判定', () {
    test('「浮点上二分、最后才量化」的写法会有大量输出越界', () {
      // 这条是**对照组**，不测生产代码，测的是「为什么要那样写」。
      //
      // 没有它的话，`deriveGraphicColor` 里那句「先量化再判定」看起来
      // 只是一种写法偏好；有了它才知道另一种写法会坏，坏多少。
      var naiveViolations = 0;
      var sampled = 0;
      for (var r = 0; r < 256; r += 7) {
        for (var g = 0; g < 256; g += 7) {
          for (var b = 0; b < 256; b += 7) {
            final hsl = rgbToHsl(r, g, b);
            if (relativeLuminance(r, g, b) <= limit) continue;
            sampled++;

            // 朴素写法：全程在浮点亮度上二分，收敛后才转成 8 位色。
            var lo = 0.0, hi = hsl.l;
            for (var i = 0; i < 24; i++) {
              final mid = (lo + hi) / 2;
              // 关键差异：判定用的是 HSL 的 L 折算的灰阶亮度，
              // 而最终产物是 hslToRgb 出来的彩色 —— 两者之间隔着一次转换。
              if (naiveLuminanceOf(mid) <= limit) {
                lo = mid;
              } else {
                hi = mid;
              }
            }
            final out = hslToRgb(hsl.h, hsl.s, lo);
            if (relativeLuminance(out.r, out.g, out.b) > limit) {
              naiveViolations++;
            }
          }
        }
      }
      expect(sampled, greaterThan(1000), reason: '样本量不足，这条没有意义');
      // 不断言具体比例（依赖采样步长），只断言「确实会坏」。
      expect(
        naiveViolations,
        greaterThan(0),
        reason:
            '朴素写法竟然没有越界 —— 那本实现的「先量化再判定」就没有必要，'
            '说明这条对照组或生产实现有一个是错的',
      );
    });

    test('生产实现在同一批输入上 0 越界', () {
      // 与上一条同样的输入，对照才成立。
      var violations = 0;
      for (var r = 0; r < 256; r += 7) {
        for (var g = 0; g < 256; g += 7) {
          for (var b = 0; b < 256; b += 7) {
            final d = deriveGraphicColor(
              r,
              g,
              b,
              darkestSurfaceLuminance: darkest,
            );
            if (relativeLuminance(d.r, d.g, d.b) > limit) violations++;
          }
        }
      }
      expect(violations, 0);
    });
  });

  group('默认 token 与派生规则自洽', () {
    test('默认主色派生出的图形色与手写的 primaryGraphic 一致或更保守', () {
      // 手写常量与算法各来一遍。两者不一致说明常量是拍脑袋定的，
      // 或者算法改了而常量没跟上。
      const fill = BrandColors.primaryFill;
      final d = deriveGraphicColor(
        (fill >> 16) & 0xFF,
        (fill >> 8) & 0xFF,
        fill & 0xFF,
        darkestSurfaceLuminance: darkest,
      );
      final derivedLum = relativeLuminance(d.r, d.g, d.b);
      final constantLum = _lum(BrandColors.primaryGraphic);

      expect(derivedLum, lessThanOrEqualTo(limit));
      expect(constantLum, lessThanOrEqualTo(limit));
      // 常量不该比算法结果更亮 —— 更暗是可以的（更保守）。
      expect(
        constantLum,
        lessThanOrEqualTo(derivedLum + 1e-6),
        reason:
            '手写常量 ${_hex((BrandColors.primaryGraphic >> 16) & 0xFF, (BrandColors.primaryGraphic >> 8) & 0xFF, BrandColors.primaryGraphic & 0xFF)} 比算法结果 ${_hex(d.r, d.g, d.b)} 亮',
      );
    });

    test('已经足够暗的主色原样保留，不做无谓加深', () {
      const dark = 0x1F3D37; // text.onBrand，本就很暗
      final d = deriveGraphicColor(
        (dark >> 16) & 0xFF,
        (dark >> 8) & 0xFF,
        dark & 0xFF,
        darkestSurfaceLuminance: darkest,
      );
      expect(d.r, (dark >> 16) & 0xFF);
      expect(d.g, (dark >> 8) & 0xFF);
      expect(d.b, dark & 0xFF);
    });
  });
}

/// 朴素写法的判定依据：把 HSL 的 `L` 当灰阶亮度用。
///
/// 这是「浮点上二分、最后才量化」那类实现的典型形状 ——
/// **判定用的量与最终产物之间隔着一次转换**（这里既有色彩转换也有舍入）。
/// 本文件用它作对照组，证明生产实现里那句「先量化再判定」不是写法偏好。
double naiveLuminanceOf(double lightness) {
  final v = (lightness * 255).round().clamp(0, 255);
  return relativeLuminance(v, v, v);
}

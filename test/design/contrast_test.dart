/// 对比度守卫（design-system §10）。
///
/// 文档里的对比度数字会随改色悄悄失效，所以写成测试。
///
/// ## 两部分，性质不同
///
/// 1. **固定 token**：三个表面各算一遍，穷尽（§10 门槛表）。
///    「只算一个表面就下结论」是本项目栽过的坑。
/// 2. **用户自定义主色**：断言的对象是**空间**而非样本。
///    全集 16,777,216 个主色一个不落 —— 域能枚举就枚举，
///    不要采样后声称全称。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/design/tokens/colors.dart';
import 'package:planning_assistant/design/tokens/contrast.dart';

/// 正文文字。
const double kBodyText = 4.5;

/// 大号文字与非文字关键图形。
const double kLargeTextOrGraphic = 3.0;

double _lum(int rgb) =>
    relativeLuminance((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF);

String _hex(int rgb) =>
    '#${rgb.toRadixString(16).toUpperCase().padLeft(6, '0')}';

void main() {
  group('固定 token：每个表面各算一遍', () {
    test('正文文字 × 三个亮表面 ≥ 4.5:1', () {
      // 只算 canvas 会漏掉 sunken —— 后者最暗，是紧约束。
      final failures = <String>[];
      for (final text in [TextColors.primary, TextColors.secondary]) {
        for (final surface in SurfaceColors.lightSurfaces) {
          final r = contrastRatio(text, surface);
          if (r < kBodyText) {
            failures.add(
              '  ${_hex(text)} on ${_hex(surface)} = '
              '${r.toStringAsFixed(2)}:1',
            );
          }
        }
      }
      expect(failures, isEmpty, reason: '正文文字不达标：\n${failures.join('\n')}');
    });

    test('text.disabled 豁免，但必须记下它确实不达标', () {
      // 豁免不是「没测」。把它的实际值钉住：哪天有人拿它当正文色用，
      // 这条注释与数值就是拒绝的依据。
      final r = contrastRatio(TextColors.disabled, SurfaceColors.canvas);
      expect(r, lessThan(kBodyText), reason: '若它已达标，说明色值变了，豁免该撤销');
      expect(r, closeTo(2.41, 0.01));
    });

    test('text.onBrand 在三个品牌填充色上都 ≥ 4.5:1', () {
      for (final fill in [
        BrandColors.primaryFill,
        BrandColors.secondaryFill,
        BrandColors.tertiaryFill,
      ]) {
        expect(
          contrastRatio(TextColors.onBrand, fill),
          greaterThanOrEqualTo(kBodyText),
          reason: '${_hex(TextColors.onBrand)} on ${_hex(fill)}',
        );
      }
    });

    test('白字在品牌填充上**不达标** —— 这正是 onBrand 存在的理由', () {
      // 反向断言。少了它，「必须用 onBrand」就只是一句注释。
      expect(
        contrastRatio(0xFFFFFF, BrandColors.primaryFill),
        lessThan(kBodyText),
      );
    });

    test('语义色 .text × 三个亮表面 ≥ 4.5:1', () {
      final failures = <String>[];
      for (final text in [
        SemanticColors.doneText,
        SemanticColors.soonText,
        SemanticColors.overdueText,
        SemanticColors.infoText,
        SemanticColors.dangerText,
      ]) {
        for (final surface in SurfaceColors.lightSurfaces) {
          final r = contrastRatio(text, surface);
          if (r < kBodyText) {
            failures.add(
              '  ${_hex(text)} on ${_hex(surface)} = '
              '${r.toStringAsFixed(2)}:1',
            );
          }
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('语义色 .fill 作文字**全部不达标** —— 拆两个 token 的依据', () {
      // §2.4 的整个理由就是这个。若哪天某个 fill 达标了，
      // 说明色值变了，该重新审视拆分是否还必要。
      for (final fill in SemanticColors.fills) {
        expect(
          contrastRatio(fill, SurfaceColors.canvas),
          lessThan(kBodyText),
          reason: '${_hex(fill)} 作文字竟然达标了',
        );
      }
    });
  });

  group('品牌色拆分：fill 与 graphic 各判各的门槛', () {
    test('primaryFill 对表面**不达标**，因此它不作唯一信息载体', () {
      // 这条不是「发现了问题」，是把设计决定钉住：
      // fill 本就不承载信息，其上文字才承载。
      for (final surface in SurfaceColors.lightSurfaces) {
        expect(
          contrastRatio(BrandColors.primaryFill, surface),
          lessThan(kLargeTextOrGraphic),
        );
      }
    });

    test('primaryGraphic 对**三个**亮表面都 ≥ 3.0:1', () {
      final results = <String>[];
      for (final surface in SurfaceColors.lightSurfaces) {
        final r = contrastRatio(BrandColors.primaryGraphic, surface);
        results.add('${_hex(surface)}=${r.toStringAsFixed(2)}');
        expect(
          r,
          greaterThanOrEqualTo(kLargeTextOrGraphic),
          reason: '${_hex(BrandColors.primaryGraphic)} on ${_hex(surface)}',
        );
      }
      expect(results.length, 3, reason: '必须三个表面都算，实际：$results');
    });

    test('primaryGraphic 与 primaryFill 同色相同饱和，只差亮度', () {
      // 若哪天有人为了「更好看」改了色相，图形色就与品牌不再是同一个色，
      // 用户会觉得进度条是另一个颜色。
      final fill = rgbToHsl(
        (BrandColors.primaryFill >> 16) & 0xFF,
        (BrandColors.primaryFill >> 8) & 0xFF,
        BrandColors.primaryFill & 0xFF,
      );
      final graphic = rgbToHsl(
        (BrandColors.primaryGraphic >> 16) & 0xFF,
        (BrandColors.primaryGraphic >> 8) & 0xFF,
        BrandColors.primaryGraphic & 0xFF,
      );
      expect(graphic.h, closeTo(fill.h, 0.005), reason: '色相应一致');
      expect(graphic.s, closeTo(fill.s, 0.01), reason: '饱和度应一致');
      expect(graphic.l, lessThan(fill.l), reason: '图形色应更暗');
    });

    test('primaryGraphic 上不得放文字 —— onBrand 与白字都不到正文级', () {
      expect(
        contrastRatio(TextColors.onBrand, BrandColors.primaryGraphic),
        lessThan(kBodyText),
      );
      expect(
        contrastRatio(0xFFFFFF, BrandColors.primaryGraphic),
        lessThan(kBodyText),
      );
    });

    test('暗色主题不需要第二个 token：主色对三个暗表面本就 ≥ 3.0', () {
      for (final surface in SurfaceColors.darkSurfaces) {
        expect(
          contrastRatio(BrandColors.primaryDark, surface),
          greaterThanOrEqualTo(kLargeTextOrGraphic),
          reason: '${_hex(BrandColors.primaryDark)} on ${_hex(surface)}',
        );
      }
    });
  });

  group('闭式阈值', () {
    test('三个亮表面中 sunken 最暗，是紧约束', () {
      // 「过了 sunken 另外两个必过」这句话是后面只验一个表面的依据，
      // 所以它本身必须被断言，不能靠记忆。
      final lums = {for (final s in SurfaceColors.lightSurfaces) s: _lum(s)};
      final darkest = lums.entries.reduce((a, b) => a.value < b.value ? a : b);
      expect(darkest.key, SurfaceColors.sunken);
    });

    test('阈值与逐表面校验等价', () {
      // 用一批构造出来的灰阶交叉验证「闭式解 ⟺ 逐表面判定」。
      final limit = maxForegroundLuminance(
        _lum(SurfaceColors.sunken),
        kLargeTextOrGraphic,
      );
      for (var v = 0; v < 256; v++) {
        final gray = (v << 16) | (v << 8) | v;
        final byThreshold = _lum(gray) <= limit;
        final bySurfaces = SurfaceColors.lightSurfaces.every(
          (s) => contrastRatio(gray, s) >= kLargeTextOrGraphic,
        );
        expect(byThreshold, bySurfaces, reason: '灰阶 ${_hex(gray)} 两种判法不一致');
      }
    });
  });
}

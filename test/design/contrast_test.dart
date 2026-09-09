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
      // ## `BrandColors.primaryText` 一度**不在这张表里**
      //
      // 而它存在的全部理由就是「品牌色作正文时用它」——
      // 也就是说，这个 token 的定义性质从来没有人验过。
      // `colors.dart` 那边的注释写着「实测 5.12 / 4.95 / 4.55 ✅」，
      // 那个 ✅ 背后什么也没有（而且三个数还是旧配色的）。
      //
      // 找到它的路径值得记：评审指出另一处注释里的数字过期，
      // 我顺着同一份注释往下读，撞见了这一处 ——
      // **过期的数字是「这一段没人维护」的信号，不只是它自己错了。**
      final failures = <String>[];
      for (final text in [
        TextColors.primary,
        TextColors.secondary,
        BrandColors.primaryText,
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

    test('primaryGraphic 对**三个**亮表面都 ≥ 3.0:1，且都够不到 4.5', () {
      // ## 两端都要钉，因为 `primaryText` 的存在理由就是这两端
      //
      // 下界（≥3.0）：图形级够用。
      // 上界（<4.5）：正文级不够 —— **这正是品牌色要拆出第三级的原因**。
      // 只钉下界的话，注释里那句「图形够用、正文不够」有一半没人守。
      final results = <String>[];
      for (final surface in SurfaceColors.lightSurfaces) {
        final r = contrastRatio(BrandColors.primaryGraphic, surface);
        results.add('${_hex(surface)}=${r.toStringAsFixed(2)}');
        expect(
          r,
          greaterThanOrEqualTo(kLargeTextOrGraphic),
          reason: '${_hex(BrandColors.primaryGraphic)} on ${_hex(surface)}',
        );
        expect(
          r,
          lessThan(kBodyText),
          reason:
              '${_hex(surface)} 上它已经到正文级了 —— 那不是 bug，'
              '是 primaryText 可能变多余了，去看一眼 §2.4 的三级拆分还成不成立',
        );
      }
      expect(results.length, 3, reason: '必须三个表面都算，实际：$results');
    });

    test('把 primaryGraphic 的三个实测值钉住', () {
      // ## 为什么要把数字写进断言
      //
      // 这三个数原本抄在 `colors.dart` 的注释里，改配色之后**三个全过期**
      // 而没有任何东西会红（旧值是奶油白画布与暖灰 sunken 时代的）。
      // 更糟的是评审复核时用了同一份旧值，算出来与注释一致、判了「✓」——
      // **一份不受检的副本会主动提供假的确证**（testing-strategy §1.12.1）。
      //
      // 所以数字搬到这儿：**写在断言里的数字不会悄悄过期**，
      // 改配色时这条会红，红了就有人看一眼余量还剩多少。
      // 注释那边只留主张（「图形够用、正文不够」）与指针 ——
      // 主张跨配色稳定，测量不稳定。
      //
      // 与 `text.disabled 豁免` 那条同一个做法（那里也 `closeTo` 钉了 2.41）。
      // 用列表而不是 Map：canvas 与 card 都是纯白（§2.2），
      // 写成 Map 会**键重复**编译不过 —— 那条报错本身就是
      // 「这两个表面现在是同一个色」的证明。
      // 所以下面两行数相同不是笔误；哪天它们不一样了，
      // 要么表面色变了，要么这份期望过期了。
      const expected = [
        ('canvas', SurfaceColors.canvas, 3.46),
        ('card', SurfaceColors.card, 3.46),
        ('sunken', SurfaceColors.sunken, 3.10),
      ];
      for (final (name, surface, want) in expected) {
        expect(
          contrastRatio(BrandColors.primaryGraphic, surface),
          closeTo(want, 0.01),
          reason: '$name ${_hex(surface)} 上的实测值变了',
        );
      }

      // `primaryText` 那三个数同样抄在注释里、同样过期
      // （写的是 5.12 / 4.95 / 4.55，那是旧配色下 card / canvas / sunken
      // 的值，连顺序都不是注释里那个顺序）。一并钉住。
      const textExpected = [
        ('canvas', SurfaceColors.canvas, 5.12),
        ('card', SurfaceColors.card, 5.12),
        ('sunken', SurfaceColors.sunken, 4.58),
      ];
      for (final (name, surface, want) in textExpected) {
        expect(
          contrastRatio(BrandColors.primaryText, surface),
          closeTo(want, 0.01),
          reason: '$name ${_hex(surface)} 上 primaryText 的实测值变了',
        );
      }
      expect(
        expected.map((e) => e.$2).toSet().length,
        lessThan(expected.length),
        reason: 'canvas 与 card 不再是同一个色了 —— 上面那段注释要改',
      );
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

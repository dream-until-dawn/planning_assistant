/// 主题装配的契约（design-system §9）。
///
/// 这里的断言分两类，都**不产出图片**：
///  · 装配正确性：token 有没有真的接进 ThemeData；
///  · 无障碍：暗色主题的对比度声明是否属实。
///
/// 后者尤其要紧 —— `app_theme.dart` 的注释里写了「暗色下 .fill 系列
/// 实测 7.0–11.4:1，可兼作文字色」。**注释里的数字会失效**，
/// 所以这里重算，而不是相信它。
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/design/theme/app_theme.dart';
import 'package:planning_assistant/design/tokens/colors.dart';
import 'package:planning_assistant/design/tokens/contrast.dart';
import 'package:planning_assistant/design/tokens/dimensions.dart';

const double kBodyText = 4.5;
const double kLargeTextOrGraphic = 3.0;

int _rgbOf(Color c) =>
    ((c.r * 255).round() << 16) |
    ((c.g * 255).round() << 8) |
    (c.b * 255).round();

double _ratio(Color a, Color b) => contrastRatio(_rgbOf(a), _rgbOf(b));

String _hex(Color c) =>
    '#${_rgbOf(c).toRadixString(16).toUpperCase().padLeft(6, '0')}';

void main() {
  final light = AppTheme.light();
  final dark = AppTheme.dark();

  AppSemanticColors ext(ThemeData t) => t.extension<AppSemanticColors>()!;

  group('装配：token 确实接进了主题', () {
    test('语义扩展存在，两个主题都有', () {
      expect(light.extension<AppSemanticColors>(), isNotNull);
      expect(dark.extension<AppSemanticColors>(), isNotNull);
    });

    test('亮色主题的表面色与 token 一致', () {
      final c = ext(light);
      expect(_rgbOf(c.canvas), SurfaceColors.canvas);
      expect(_rgbOf(c.card), SurfaceColors.card);
      expect(_rgbOf(c.sunken), SurfaceColors.sunken);
      expect(light.scaffoldBackgroundColor, c.canvas);
    });

    test('亮色的 fill 与 graphic 是**不同**的两个值', () {
      // 若哪天有人「简化」成一个，进度条就会掉回 1.72:1。
      final c = ext(light);
      expect(_rgbOf(c.brandFill), BrandColors.primaryFill);
      expect(_rgbOf(c.brandGraphic), BrandColors.primaryGraphic);
      expect(c.brandFill, isNot(c.brandGraphic));
    });

    test('暗色的 fill 与 graphic **相同**，且这是有依据的', () {
      // 共用是因为暗色主色本就 ≥3:1，不是因为省事。
      // 依据在下面那组里重算，不靠这条注释。
      final c = ext(dark);
      expect(c.brandFill, c.brandGraphic);
      expect(_rgbOf(c.brandFill), BrandColors.primaryDark);
    });

    test('暗色主题没有阴影，亮色有', () {
      expect(ext(dark).cardShadow, isEmpty, reason: '暗色里阴影几乎不可见（§6）');
      expect(ext(light).cardShadow, isNotEmpty);
    });

    test('卡片 elevation 为 0 —— 阴影由 token 画，不用 Material 的', () {
      // 两套阴影叠加会让暗色主题出现本不该有的一层。
      expect(light.cardTheme.elevation, 0);
      expect(dark.cardTheme.elevation, 0);
    });
  });

  group('无障碍：暗色主题的声明必须重算，不能相信注释', () {
    test('暗色 .fill 系列在暗色 canvas 上确实可兼作文字色（≥4.5:1）', () {
      // app_theme.dart 里写着「暗色下 .fill 实测 7.0–11.4:1」并据此
      // 把 doneText 直接设成 doneFill。那句话若失效，暗色主题的
      // 全部状态文字都会不达标 —— 而它只是一句注释。
      final c = ext(dark);
      final pairs = {
        'done': c.doneText,
        'soon': c.soonText,
        'overdue': c.overdueText,
        'info': c.infoText,
        'danger': c.dangerText,
      };
      final failures = <String>[];
      pairs.forEach((name, color) {
        final r = _ratio(color, c.canvas);
        if (r < kBodyText) {
          failures.add(
            '  $name ${_hex(color)} on ${_hex(c.canvas)} = '
            '${r.toStringAsFixed(2)}:1',
          );
        }
      });
      expect(failures, isEmpty, reason: '暗色语义文字不达标：\n${failures.join('\n')}');
    });

    test('暗色 .fill 在**三个**暗表面上都达标，不只 canvas', () {
      // 只算 canvas 正是本项目栽过的坑。card 比 canvas 亮，是更紧的约束。
      final c = ext(dark);
      final surfaces = {'canvas': c.canvas, 'card': c.card, 'sunken': c.sunken};
      final failures = <String>[];
      for (final text in [
        c.doneText,
        c.soonText,
        c.overdueText,
        c.infoText,
        c.dangerText,
      ]) {
        surfaces.forEach((sname, s) {
          final r = _ratio(text, s);
          if (r < kBodyText) {
            failures.add(
              '  ${_hex(text)} on $sname = ${r.toStringAsFixed(2)}:1',
            );
          }
        });
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('暗色主色作图形在三个暗表面上 ≥3:1', () {
      final c = ext(dark);
      for (final s in [c.canvas, c.card, c.sunken]) {
        expect(
          _ratio(c.brandGraphic, s),
          greaterThanOrEqualTo(kLargeTextOrGraphic),
          reason: '${_hex(c.brandGraphic)} on ${_hex(s)}',
        );
      }
    });

    test('两个主题的正文文字在三个表面上都 ≥4.5:1', () {
      final failures = <String>[];
      for (final entry in {'light': light, 'dark': dark}.entries) {
        final c = ext(entry.value);
        final body = entry.value.textTheme.bodyMedium!.color!;
        for (final s in [c.canvas, c.card, c.sunken]) {
          final r = _ratio(body, s);
          if (r < kBodyText) {
            failures.add(
              '  ${entry.key}: ${_hex(body)} on ${_hex(s)} = '
              '${r.toStringAsFixed(2)}:1',
            );
          }
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('caption 用的是 secondary 色，同样要达标', () {
      // 它字号最小（12），最容易被忽略，而它承载时间与计数。
      for (final entry in {'light': light, 'dark': dark}.entries) {
        final c = ext(entry.value);
        final caption = entry.value.textTheme.bodySmall!;
        expect(
          TypeScale.isLargeText(caption.fontSize!, caption.fontWeight!),
          isFalse,
          reason: 'caption 不是大号文字，因此门槛是 4.5 而非 3.0',
        );
        expect(
          _ratio(caption.color!, c.canvas),
          greaterThanOrEqualTo(kBodyText),
          reason: '${entry.key} caption',
        );
      }
    });
  });

  group('ThemeExtension 的 copyWith / lerp', () {
    // 18 个字段。copyWith 漏一个不会报错，只会让那个颜色在切主题后
    // 悄悄停在旧值上；lerp 漏一个则是在过渡动画中途闪一下。
    // 两者都不会崩，所以只能靠测试。

    test('字段表与类定义同步 —— 否则上面几条会漏掉新字段', () {
      // 手写的 _fieldsOf 是这组测试的基础。加了字段却忘了加进去，
      // 「逐字段比对」就会安静地少比一个 —— 全绿，且没验到。
      //
      // 扫源码而不是靠自觉：Dart 没有反射可用。
      final source = File('lib/design/theme/app_theme.dart').readAsStringSync();
      final classBody = source.substring(
        source.indexOf('final class AppSemanticColors'),
        source.indexOf('AppSemanticColors copyWith'),
      );
      final declared = RegExp(
        r'^\s*final Color (\w+);',
        multiLine: true,
      ).allMatches(classBody).map((m) => m.group(1)!).toSet();

      expect(
        _fieldsOf(ext(light)).keys.toSet(),
        declared,
        reason: '字段表与 AppSemanticColors 的 Color 字段不一致',
      );
    });

    test('copyWith 不传参数时逐字段等于原值', () {
      final original = ext(light);
      final copy = original.copyWith();
      for (final entry in _fieldsOf(original).entries) {
        expect(
          _fieldsOf(copy)[entry.key],
          entry.value,
          reason: 'copyWith() 丢了字段 ${entry.key}',
        );
      }
    });

    test('copyWith 只改指定字段', () {
      final original = ext(light);
      const probe = Color(0xFF123456);
      final copy = original.copyWith(brandGraphic: probe);

      expect(copy.brandGraphic, probe);
      expect(copy.brandFill, original.brandFill);
      expect(copy.canvas, original.canvas);
      expect(copy.dangerText, original.dangerText);
    });

    test('lerp t=0 与 t=1 分别等于两端', () {
      final a = ext(light);
      final b = ext(dark);
      final at0 = a.lerp(b, 0);
      final at1 = a.lerp(b, 1);

      for (final key in _fieldsOf(a).keys) {
        expect(_fieldsOf(at0)[key], _fieldsOf(a)[key], reason: 't=0 的 $key');
        expect(_fieldsOf(at1)[key], _fieldsOf(b)[key], reason: 't=1 的 $key');
      }
    });

    test('lerp 中途每个颜色都在两端之间', () {
      // 漏插值的字段会停在起点，于是切主题时那一处「跳」一下。
      final a = ext(light);
      final b = ext(dark);
      final mid = a.lerp(b, 0.5);

      final aFields = _fieldsOf(a);
      final bFields = _fieldsOf(b);
      final midFields = _fieldsOf(mid);
      final stuck = <String>[];
      for (final key in aFields.keys) {
        if (aFields[key] == bFields[key]) continue; // 两端本就相同
        if (midFields[key] == aFields[key]) stuck.add(key);
      }
      expect(stuck, isEmpty, reason: '这些字段没参与插值：$stuck');
    });

    test('阴影不插值 —— 明暗之间是「有」与「无」', () {
      final a = ext(light);
      final b = ext(dark);
      expect(a.lerp(b, 0.4).cardShadow, a.cardShadow);
      expect(a.lerp(b, 0.6).cardShadow, b.cardShadow);
    });

    test('lerp 传入非同类扩展时返回自身，不崩', () {
      final a = ext(light);
      expect(a.lerp(null, 0.5), same(a));
    });
  });

  group('圆角配置（FR-CFG-02）', () {
    test('三档倍率各自生效', () {
      for (final style in CornerStyle.values) {
        final t = AppTheme.light(corners: style);
        final shape = t.cardTheme.shape! as RoundedRectangleBorder;
        final r = (shape.borderRadius as BorderRadius).topLeft.x;
        expect(
          r,
          closeTo(Radii.lg * style.factor, 0.01),
          reason: '${style.name} 档的卡片圆角',
        );
      }
    });

    test('三档产出三个**不同**的值 —— 否则配置项等于不存在', () {
      final radii = CornerStyle.values.map((s) => s.apply(Radii.lg)).toSet();
      expect(radii.length, 3);
    });

    test('药丸圆角不参与缩放', () {
      // sharp 档若把 999 压成 499.5，药丸按钮在小尺寸下仍是药丸，
      // 看不出区别；但在大尺寸容器上会突然变成圆角矩形。
      for (final style in CornerStyle.values) {
        expect(style.apply(Radii.full), Radii.full);
      }
    });
  });

  group('字号缩放的档位定义', () {
    test('最坏有效缩放是两层相乘，不是系统那一层', () {
      expect(FontScale.worstEffectiveScale, 2.8);
      expect(
        FontScale.worstEffectiveScale,
        greaterThan(FontScale.systemScaleMax),
        reason: 'NFR-A11Y-02 字面只写了系统 200%，实际能到 2.8',
      );
    });

    test('golden 档位包含最坏值', () {
      // 少了它，「覆盖到 200%」听着像覆盖了 NFR，实际覆盖不到。
      expect(FontScale.goldenScales, contains(FontScale.worstEffectiveScale));
      expect(FontScale.goldenScales.length, 3);
    });
  });
}

/// 把扩展的全部颜色字段摊成 map，供逐字段比对。
///
/// **手写这张表是有意的**：它与 `AppSemanticColors` 的字段列表必须一致，
/// 加了字段却忘了加进来，`copyWith 不传参数时逐字段等于原值` 那条
/// 就覆盖不到新字段 —— 于是下面那条断言拿它与源码里的字段**按名字**比集合。
/// 按名字不按个数：加一个删一个，个数不变，集合会变。
Map<String, Object?> _fieldsOf(AppSemanticColors c) => {
  'brandFill': c.brandFill,
  'brandGraphic': c.brandGraphic,
  'brandText': c.brandText,
  'onBrand': c.onBrand,
  'disabledText': c.disabledText,
  'canvas': c.canvas,
  'card': c.card,
  'sunken': c.sunken,
  'borderSubtle': c.borderSubtle,
  'doneFill': c.doneFill,
  'doneText': c.doneText,
  'soonFill': c.soonFill,
  'soonText': c.soonText,
  'overdueFill': c.overdueFill,
  'overdueText': c.overdueText,
  'infoFill': c.infoFill,
  'infoText': c.infoText,
  'dangerFill': c.dangerFill,
  'dangerText': c.dangerText,
};

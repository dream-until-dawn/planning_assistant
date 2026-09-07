/// 字体打包的守卫（design-system §3.1、§3.2）。
///
/// §3.1 的原话是「字体文件作为 `assets/fonts/` 打包进 APK，在
/// `pubspec.yaml` 声明 `fonts:`」，理由是 `google_fonts` 默认**运行时
/// 联网下载**，与 NFR-PRIV-01（V1 不联网、不采集）直接冲突。
///
/// 这条要求在文档里躺了很久，代码里一个字没落 —— pubspec 没有 `fonts:`、
/// 没有 `assets/fonts/`、主题也没设 `fontFamily`。做 M2 组件时才发现。
/// 所以补的不只是字体，还有这几条守卫：**文档写了的事，得有东西盯着**。
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/design/theme/app_theme.dart';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  group('字体必须随包，不得运行时下载（§3.1 / NFR-PRIV-01）', () {
    test('不引入 google_fonts', () {
      // 它默认联网取字体。真要用，必须配成只读本地 asset ——
      // 而那样就没有引它的理由了。
      //
      // 判据是「出现在依赖里」，不是「在文件里出现过」。初版写的是后者，
      // 当场被 pubspec 里那段解释为什么不用它的**注释**判成失败。
      // 谓词写宽了，抓到的是自己。
      final deps = pubspec
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('#'))
          .join('\n');
      expect(
        RegExp(r'^\s+google_fonts\s*:', multiLine: true).hasMatch(deps),
        isFalse,
        reason: 'google_fonts 默认运行时下载字体，与 NFR-PRIV-01 冲突',
      );
    });

    test('pubspec 声明了 fonts:，且指向真实存在的文件', () {
      final match = RegExp(
        r'^\s*-\s*asset:\s*(assets/fonts/\S+)\s*$',
        multiLine: true,
      ).allMatches(pubspec).map((m) => m.group(1)!).toList();

      expect(match, isNotEmpty, reason: 'pubspec 里没有 assets/fonts/ 下的字体声明');

      for (final path in match) {
        expect(
          File(path).existsSync(),
          isTrue,
          reason: 'pubspec 声明了 $path，但这个文件不存在',
        );
      }
    });

    test('声明的 family 与主题里用的是同一个名字', () {
      // 两边对不上时不会报错，只是**安静地退回系统字体** ——
      // 整套圆体白打包了，而界面看着「还行」。
      final family = RegExp(
        r'^\s*-\s*family:\s*(\S+)\s*$',
        multiLine: true,
      ).firstMatch(pubspec)?.group(1);

      expect(family, isNotNull, reason: 'pubspec 里没有 family:');
      expect(family, AppTheme.fontFamily);
    });

    test('字体文件是 TrueType/OpenType，不是下错的 HTML', () {
      // curl 拿到 404 页面也会得到一个「文件」。魔数不对就当场判失败，
      // 而不是等到渲染时字体静默失效。
      final head = File('assets/fonts/Quicksand[wght].ttf')
          .readAsBytesSync()
          .sublist(0, 4);
      const trueType = [0x00, 0x01, 0x00, 0x00];
      const openType = [0x4F, 0x54, 0x54, 0x4F]; // 'OTTO'
      expect(
        head.toList(),
        anyOf(equals(trueType), equals(openType)),
        reason: '文件头是 ${head.toList()}，不像字体',
      );
    });

    test('OFL 许可证随文件一起在库里', () {
      // SIL OFL 1.1 要求分发时附带许可证。
      final ofl = File('assets/fonts/OFL.txt');
      expect(ofl.existsSync(), isTrue);
      expect(ofl.readAsStringSync(), contains('SIL OPEN FONT LICENSE'));
    });
  });

  group('主题真的用上了这个字体', () {
    for (final (name, theme) in [
      ('亮色', AppTheme.light()),
      ('暗色', AppTheme.dark()),
    ]) {
      test('$name：每个字号都指定了 fontFamily', () {
        final styles = <String, TextStyle?>{
          'displaySmall': theme.textTheme.displaySmall,
          'titleLarge': theme.textTheme.titleLarge,
          'titleMedium': theme.textTheme.titleMedium,
          'bodyLarge': theme.textTheme.bodyLarge,
          'bodyMedium': theme.textTheme.bodyMedium,
          'labelLarge': theme.textTheme.labelLarge,
          'bodySmall': theme.textTheme.bodySmall,
        };
        styles.forEach((key, style) {
          expect(style, isNotNull, reason: '$key 没定义');
          expect(
            style!.fontFamily,
            AppTheme.fontFamily,
            reason: '$key 没指定字体，会退回系统默认',
          );
        });
      });

      test('$name：字重同时给了 fontVariations 的 wght 轴', () {
        // 可变字体光给 fontWeight 在部分引擎上不生效 —— 一律按默认字重
        // 渲染，「标题 600 / 正文 400」的层次没了，且不报错。
        final styles = [
          theme.textTheme.displaySmall,
          theme.textTheme.titleLarge,
          theme.textTheme.bodyLarge,
          theme.textTheme.labelLarge,
          theme.textTheme.bodySmall,
        ];
        for (final style in styles) {
          final v = style!.fontVariations;
          expect(v, isNotNull, reason: '没给 fontVariations');
          final wght = v!.firstWhere((e) => e.axis == 'wght');
          expect(
            wght.value,
            style.fontWeight!.value.toDouble(),
            reason: 'wght 轴与 fontWeight 对不上，两边会打架',
          );
        }
      });
    }

    test('字重确实分了层 —— 不是所有字号一个重量', () {
      // 否则上面那条「wght 与 fontWeight 一致」在「全都是 400」时也成立。
      final t = AppTheme.light().textTheme;
      final weights = {
        t.displaySmall!.fontWeight,
        t.bodyLarge!.fontWeight,
        t.labelLarge!.fontWeight,
      };
      expect(weights.length, greaterThan(1), reason: '字重没有层次，字阶等于白定');
    });
  });

  group('字体在测试环境里真的被加载了', () {
    testWidgets('拉丁文字的实际字宽不等于回落字体', (tester) async {
      // flutter_test_config.dart 装载失败时不会报错，只是安静地用默认字体，
      // 于是所有 golden 都在测一个线上不存在的排版。
      //
      // 判据：同一段拉丁文字，用 Quicksand 量出来的宽度，
      // 与显式指定一个不存在的字体（必然回落）量出来的宽度**不同**。
      double widthWith(String? family) {
        final painter = TextPainter(
          text: TextSpan(
            text: '2026-09-07 14:00',
            style: TextStyle(fontFamily: family, fontSize: 16),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        return painter.width;
      }

      expect(
        widthWith(AppTheme.fontFamily),
        isNot(closeTo(widthWith('__绝不存在的字体__'), 0.01)),
        reason: 'Quicksand 没装上，golden 量的是回落字体的字宽',
      );
    });
  });
}

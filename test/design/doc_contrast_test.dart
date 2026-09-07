/// 文档里的对比度数字必须是真的（design-system 附录 A）。
///
/// ## 这个测试补的是哪个洞
///
/// design-system §2 开头写着「所有对比度**均为按 WCAG 2.1 公式实算所得**」。
/// 那是一句**可机检的断言**，而此前只靠人守。
///
/// conventions §5 的文档同步检查保证「改了 token 就得改文档」，
/// 但**不保证两边说的是同一件事**。M2 里真的出现过一次「代码对、文档错」——
/// 语义色的三个 `.text` 只算了 canvas，而测试早已对三个表面都算 ——
/// 两边都没被改，同步检查无从触发。
///
/// ## 两层检查
///
/// 1. **附录表逐行重算**：写在表里的比值必须等于公式算出来的。
/// 2. **正文覆盖**：正文里出现的每一个实测数字，都要能在附录表里找到 ——
///    否则有人可以在正文写一个没人验的数。
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/design/tokens/colors.dart';
import 'package:planning_assistant/design/tokens/contrast.dart';

const String _docPath = 'docs/03-design/design-system.md';
const String _begin = '<!-- CONTRAST-TABLE-BEGIN -->';
const String _end = '<!-- CONTRAST-TABLE-END -->';

/// 附录表的一行。
typedef ContrastClaim = ({String desc, int fg, int bg, double claimed});

int _parseHex(String s) => int.parse(s.replaceAll('#', '').trim(), radix: 16);

List<ContrastClaim> _parseTable(String doc) {
  final start = doc.indexOf(_begin);
  final stop = doc.indexOf(_end);
  // 用 throw 而不是 expect：解析在 main 体里跑，那时还没有测试上下文。
  if (start < 0 || stop <= start) {
    throw StateError('附录表的标记不见了（$_begin / $_end）');
  }

  final rows = <ContrastClaim>[];
  final pattern = RegExp(
    r'^\|\s*(.+?)\s*\|\s*`(#[0-9A-Fa-f]{6})`\s*\|\s*`(#[0-9A-Fa-f]{6})`\s*\|'
    r'\s*([0-9]+\.[0-9]+):1\s*\|',
    multiLine: true,
  );
  for (final m in pattern.allMatches(doc.substring(start, stop))) {
    rows.add((
      desc: m.group(1)!,
      fg: _parseHex(m.group(2)!),
      bg: _parseHex(m.group(3)!),
      claimed: double.parse(m.group(4)!),
    ));
  }
  return rows;
}

void main() {
  final doc = File(_docPath).readAsStringSync();
  final claims = _parseTable(doc);

  group('附录表逐行重算', () {
    test('表不是空的 —— 否则下面的断言是空对空', () {
      // 解析器写错、或标记被删，都会让表变空而所有断言「通过」。
      expect(claims.length, greaterThan(25), reason: '只解析到 ${claims.length} 行');
    });

    test('每一行的比值都等于 WCAG 2.1 算出来的', () {
      final failures = <String>[];
      for (final c in claims) {
        final actual = contrastRatio(c.fg, c.bg);
        // 文档记两位小数，容差取半个末位。
        if ((actual - c.claimed).abs() > 0.005) {
          failures.add(
            '  ${c.desc}: 文档写 ${c.claimed.toStringAsFixed(2)}:1，'
            '实算 ${actual.toStringAsFixed(2)}:1',
          );
        }
      }
      expect(
        failures,
        isEmpty,
        reason:
            '${failures.length} 行对不上：\n${failures.join('\n')}\n'
            '要么色值改了没同步文档，要么文档里的数字本来就是估的。',
      );
    });

    test('没有重复行 —— 同一对颜色记两遍迟早写出两个值', () {
      final seen = <String>{};
      final dupes = <String>[];
      for (final c in claims) {
        final key = '${c.fg}-${c.bg}';
        if (!seen.add(key)) dupes.add('  ${c.desc}');
      }
      expect(dupes, isEmpty, reason: '重复的颜色对：\n${dupes.join('\n')}');
    });
  });

  group('文档里的色值必须与代码里的 token 一致', () {
    // **这一层才真正堵住「代码对、文档错」。**
    //
    // 上面两组只验「文档的算术对不对」与「正文数字有没有进表」——
    // 但如果有人改了 colors.dart 里的常量却没动文档，文档里那个旧 hex
    // 与它的比值**仍然自洽**（旧色确实是那个比值），两组都不会红。
    //
    // 实测：把 TextColors.primary 从 #3A3742 改成别的值，
    // 前两组照样全绿。所以需要这一组。

    /// 文档中的 token 名 → 代码中的常量。
    ///
    /// 手写映射，并在下面用「代码里的每个 token 都必须出现在这里」
    /// 兜住 —— 否则新增 token 时这张表会悄悄落后。
    final expected = <String, ({String constant, int value})>{
      'brand.primary.fill': (
        constant: 'primaryFill',
        value: BrandColors.primaryFill,
      ),
      'brand.primary.graphic': (
        constant: 'primaryGraphic',
        value: BrandColors.primaryGraphic,
      ),
      'brand.primary.text': (
        constant: 'primaryText',
        value: BrandColors.primaryText,
      ),
      'brand.secondary': (
        constant: 'secondaryFill',
        value: BrandColors.secondaryFill,
      ),
      'brand.tertiary': (
        constant: 'tertiaryFill',
        value: BrandColors.tertiaryFill,
      ),
      'surface.canvas': (constant: 'canvas', value: SurfaceColors.canvas),
      'surface.card': (constant: 'card', value: SurfaceColors.card),
      'surface.sunken': (constant: 'sunken', value: SurfaceColors.sunken),
      'border.subtle': (
        constant: 'borderSubtle',
        value: SurfaceColors.borderSubtle,
      ),
      'text.primary': (constant: 'primary', value: TextColors.primary),
      'text.secondary': (constant: 'secondary', value: TextColors.secondary),
      'text.disabled': (constant: 'disabled', value: TextColors.disabled),
      'text.onBrand': (constant: 'onBrand', value: TextColors.onBrand),
      'semantic.done': (constant: 'doneFill', value: SemanticColors.doneFill),
      'semantic.soon': (constant: 'soonFill', value: SemanticColors.soonFill),
      'semantic.overdue': (
        constant: 'overdueFill',
        value: SemanticColors.overdueFill,
      ),
      'semantic.info': (constant: 'infoFill', value: SemanticColors.infoFill),
      'semantic.danger': (
        constant: 'dangerFill',
        value: SemanticColors.dangerFill,
      ),
    };

    test('文档表格里每个 token 行的亮色值与代码常量相同', () {
      final failures = <String>[];
      expected.forEach((name, entry) {
        final code = entry.value;
        // 匹配形如：| `token.name` | `#RRGGBB` ...
        final row = RegExp(
          r'\|\s*`'
          '${RegExp.escape(name)}'
          r'`\s*\|\s*`(#[0-9A-Fa-f]{6})`',
        ).firstMatch(doc);
        if (row == null) return; // 缺失由下一条断言负责
        final inDoc = int.parse(row.group(1)!.substring(1), radix: 16);
        if (inDoc != code) {
          failures.add(
            '  $name: 文档 ${row.group(1)}，代码 '
            '#${code.toRadixString(16).toUpperCase().padLeft(6, '0')}',
          );
        }
      });
      expect(
        failures,
        isEmpty,
        reason:
            '文档与 token 不一致（改了代码没同步文档）：'
            '\n'
            '${failures.join('\n')}',
      );
    });

    test('每个 token 都能在文档里找到对应行', () {
      // 代码里有、文档里没有 = 那个 token 完全没被记录。
      final missing = <String>[];
      for (final name in expected.keys) {
        final row = RegExp(
          r'\|\s*`'
          '${RegExp.escape(name)}'
          r'`\s*\|\s*`#[0-9A-Fa-f]{6}`',
        ).firstMatch(doc);
        if (row == null) missing.add(name);
      }
      expect(missing, isEmpty, reason: '文档里找不到这些 token 的行：$missing');
    });

    /// 在文档里与 `.fill` **同行**、不单独占 token 行的常量。
    ///
    /// 逐个写出来，不用 `endsWith('Text')` 这类模式 —— 见下面那条测试的说明。
    const sharesRowWithFill = <String>{
      'doneText',
      'soonText',
      'overdueText',
      'infoText',
      'dangerText',
    };

    test('映射表覆盖了 colors.dart 里的全部色值常量', () {
      // 手写映射会落后于代码。扫源码，**按名字**比对，不按个数。
      //
      // 初版是按个数比的：
      //
      //     covered = expected.length + 名字以 Text 结尾的常量数
      //
      // 新增 BrandColors.primaryText 时它没红 —— 因为这个名字也以 Text
      // 结尾，于是等号两边同时加一，抵消了。计数式守卫验的是**基数**，
      // 而要验的是**同一性**：到底是哪些常量被记录了。两个错互相抵消
      // 就整不出红来。而且那个豁免谓词本身也是错的：它想说的是
      // 「语义色的 .text 与 .fill 同行」，写出来却是「任何叫 …Text 的」，
      // 而 primaryText 是品牌色，在文档里要单独占一行。
      final source = File('lib/design/tokens/colors.dart').readAsStringSync();
      final lightConstants =
          RegExp(r'static const int (\w+) = 0x[0-9A-Fa-f]{6};')
              .allMatches(source)
              .map((m) => m.group(1)!)
              .where((n) => !n.endsWith('Dark')) // 暗色值文档里单独成列
              .toSet();

      final mapped = expected.values.map((e) => e.constant).toSet();
      final unaccounted = lightConstants
          .difference(mapped)
          .difference(sharesRowWithFill);

      expect(
        unaccounted,
        isEmpty,
        reason:
            'colors.dart 里这些常量既不在映射表里、也不在「与 fill 同行」'
            '豁免名单里，等于没人验它有没有进文档：$unaccounted',
      );

      // 反向：映射表或豁免名单里写了代码里已经不存在的名字。
      final stale = mapped.union(sharesRowWithFill).difference(lightConstants);
      expect(stale, isEmpty, reason: '映射表/豁免名单里有代码里已不存在的常量：$stale');
    });
  });

  group('正文覆盖：正文里的数字必须在表里出现过', () {
    test('每个实测数字都能在附录表里找到', () {
      // 少了这条，有人可以在正文写一个没进表、因而没人验的数字。
      final claimed = claims.map((c) => c.claimed.toStringAsFixed(2)).toSet();
      // 表里的值也允许以一位小数出现（如 6.2–12.2 这种区间写法）。
      final claimedShort = claims
          .map((c) => c.claimed.toStringAsFixed(1))
          .toSet();

      final body = doc.substring(0, doc.indexOf(_begin));
      final unverified = <String>[];

      // `≥ 4.5:1` 这类是**门槛**不是实测值，跳过。
      final measured = RegExp(r'(?<!≥ )(?<!≥)([0-9]+\.[0-9]+):1');
      for (final m in measured.allMatches(body)) {
        final value = m.group(1)!;
        if (claimed.contains(value) || claimedShort.contains(value)) continue;
        unverified.add(value);
      }

      expect(
        unverified.toSet(),
        isEmpty,
        reason:
            '正文里这些数字没进附录表，因而没有被任何检查验过：\n'
            '  ${unverified.toSet().join(', ')}\n'
            '若是门槛值请写成「≥ N:1」；若是实测值请加进附录表。',
      );
    });

    test('区间写法的两个端点都在表里', () {
      // 「6.2–12.2:1」这种写法只有右端带 `:1`，左端会被上一条漏掉。
      final body = doc.substring(0, doc.indexOf(_begin));
      final ranges = RegExp(
        r'([0-9]+\.[0-9]+)\s*[–-]\s*\*{0,2}([0-9]+\.[0-9]+)\*{0,2}\s*:1',
      );
      final claimedAll = {
        for (final c in claims) c.claimed.toStringAsFixed(2),
        for (final c in claims) c.claimed.toStringAsFixed(1),
      };

      final unverified = <String>[];
      for (final m in ranges.allMatches(body)) {
        for (final v in [m.group(1)!, m.group(2)!]) {
          if (!claimedAll.contains(v)) unverified.add(v);
        }
      }
      expect(unverified.toSet(), isEmpty, reason: '区间端点未进表：$unverified');
    });
  });
}

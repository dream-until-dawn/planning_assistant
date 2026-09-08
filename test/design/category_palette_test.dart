/// 分类默认调色板（design-system §2.5）。
///
/// §2.5 里有三句话，此前**一句都没有测**：
///
///  1. 八个颜色，新建分类时按顺序取；
///  2. 对两种表面的对比度实测 1.32–1.88；
///  3. 因此它们只能做色条与色点，**绝不能承载文字**。
///
/// 第 2 句尤其危险：一个写在文档里、没人验的实测数字，
/// 会随着表面色调整而悄悄失效（M2 里把画布从奶油白改成纯白就动过分母），
/// 而它是第 3 句那条禁令的**全部依据**。依据失效了，禁令就成了迷信。
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/data/repositories/category_repository_impl.dart';
import 'package:planning_assistant/design/tokens/colors.dart';
import 'package:planning_assistant/design/tokens/contrast.dart';

/// 文档 §2.5 声称的区间。
const _claimedMin = 1.36;
const _claimedMax = 1.88;

double _round2(double v) => (v * 100).round() / 100;

void main() {
  group('调色板本身', () {
    test('正好八个，且互不重复', () {
      // 重复两个的话「同屏多分类需可辨」就落空了，而肉眼很难发现
      // 十六进制里差一位的两个近似色。
      expect(CategoryPalette.values, hasLength(8));
      expect(CategoryPalette.values.toSet(), hasLength(8));
    });

    test('取用顺序在超出八个之后回绕，不越界', () {
      expect(CategoryPalette.forIndex(0), CategoryPalette.values.first);
      expect(CategoryPalette.forIndex(7), CategoryPalette.values.last);
      expect(CategoryPalette.forIndex(8), CategoryPalette.values.first);
      expect(CategoryPalette.forIndex(19), CategoryPalette.values[3]);
    });

    test('四个默认分类的颜色都出自调色板', () {
      // data 层不能 import design 层（分层守卫），于是那四个色值是**抄**
      // 过去的。抄过去的东西会分叉，所以在这里对一次表。
      for (final spec in kDefaultCategories) {
        expect(
          CategoryPalette.values,
          contains(spec.colorArgb),
          reason: '${spec.name} 的颜色不在 §2.5 的调色板里',
        );
      }
    });
  });

  test('代码里的调色板与 §2.5 里列的那八个色号逐个对得上', () {
    // **这条 doc_contrast_test 管不到。** 那边的覆盖守卫扫的是
    // `static const int X = 0xRRGGBB;`，而调色板是个 `List<int>`、
    // 值还带 alpha（0xAARRGGBB）—— 八个新颜色就那么从它眼皮底下过去了。
    //
    // 与其去改那个正则（它扫的是「UI token 有没有进对比度附录」，
    // 是另一件事），不如在这里把文档与代码直接对上。
    final doc = File('docs/03-design/design-system.md').readAsStringSync();
    final start = doc.indexOf('### 2.5 分类默认调色板');
    expect(start, isNonNegative, reason: '§2.5 的标题变了，这条守卫要跟着改');
    final block = doc.substring(
      doc.indexOf('```', start) + 3,
      doc.indexOf('```', doc.indexOf('```', start) + 3),
    );
    final documented = RegExp('#([0-9A-Fa-f]{6})')
        .allMatches(block)
        .map((m) => int.parse(m.group(1)!, radix: 16))
        .toList();

    // 自检：扫出来得像回事，别因为正则失配变成空表而「通过」。
    expect(documented, hasLength(8));

    expect(
      [for (final c in CategoryPalette.values) c & 0xFFFFFF],
      documented,
      reason: '调色板与 §2.5 分叉了 —— 顺序也要一致（取用顺序就是它）',
    );
  });

  group('对比度：文档 §2.5 声称的区间必须是实测出来的', () {
    /// 调色板对某个表面的对比度。色值带 alpha，比对比度要去掉。
    List<double> ratiosAgainst(int surface) => [
      for (final c in CategoryPalette.values)
        contrastRatio(c & 0xFFFFFF, surface),
    ];

    test('对画布与卡片两种表面，实测落在 $_claimedMin–$_claimedMax', () {
      final all = [
        ...ratiosAgainst(SurfaceColors.canvas),
        ...ratiosAgainst(SurfaceColors.card),
      ];
      final min = _round2(all.reduce((a, b) => a < b ? a : b));
      final max = _round2(all.reduce((a, b) => a > b ? a : b));

      expect(min, _claimedMin, reason: '§2.5 写的下界与实测对不上');
      expect(max, _claimedMax, reason: '§2.5 写的上界与实测对不上');
    });

    test('全部低于 3:1 —— 这是「不得承载文字」那条禁令的依据', () {
      // 上面那条锁的是数字对不对；这条锁的是**结论还成不成立**。
      // 两条不能合并：将来若把调色板换成更深的颜色，区间会变而结论可能
      // 反转，那时该红的是上面那条，不是这条。
      for (final surface in [SurfaceColors.canvas, SurfaceColors.card]) {
        for (final c in CategoryPalette.values) {
          expect(
            contrastRatio(c & 0xFFFFFF, surface),
            lessThan(3.0),
            reason:
                '0x${c.toRadixString(16)} 对 0x${surface.toRadixString(16)} '
                '达到了 3:1 —— 那条「只能做色条、不能承载文字」的禁令要重写',
          );
        }
      }
    });

    test('对照组：主色文字色确实高于 3:1，说明这个量法本身有效', () {
      // 少了这条，一个恒返回 1.0 的 contrastRatio 能让上面全绿。
      expect(
        contrastRatio(BrandColors.primaryText, SurfaceColors.canvas),
        greaterThan(3.0),
      );
    });
  });
}

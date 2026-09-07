/// 探针：24 位色彩空间能否穷举。
///
/// 若可行，「覆盖了哪个集合」的答案就是 16,777,216 —— 全集，
/// 而不是「若干个采样点」。
@TestOn('vm')
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

/// sRGB 通道线性化查表（WCAG 2.1 相对亮度定义）。
final List<double> _linear = List.generate(256, (i) {
  final c = i / 255.0;
  return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
});

double luminance(int r, int g, int b) =>
    0.2126 * _linear[r] + 0.7152 * _linear[g] + 0.0722 * _linear[b];

double contrast(double l1, double l2) {
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('24 位全空间穷举耗时', () {
    // 三个表面 × 明暗 = 6 个背景亮度（用真实 token 的近似值占位）。
    const surfaces = <double>[0.98, 0.95, 0.90, 0.12, 0.16, 0.08];
    final surfaceLum = surfaces;

    final sw = Stopwatch()..start();
    var checked = 0;
    var failing = 0;
    for (var r = 0; r < 256; r++) {
      for (var g = 0; g < 256; g++) {
        for (var b = 0; b < 256; b++) {
          final l = luminance(r, g, b);
          for (final s in surfaceLum) {
            checked++;
            if (contrast(l, s) < 4.5) failing++;
          }
        }
      }
    }
    sw.stop();
    // ignore: avoid_print
    print('穷举 ${256 * 256 * 256} 色 × ${surfaces.length} 表面 = $checked 次对比度计算');
    // ignore: avoid_print
    print('耗时 ${sw.elapsedMilliseconds} ms，其中不达标 $failing 次');
    expect(checked, 256 * 256 * 256 * surfaces.length);
  }, timeout: const Timeout(Duration(minutes: 5)));
}

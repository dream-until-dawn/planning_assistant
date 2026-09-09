/// 六张空态插画的**视觉回归**（design-system §8.2、FR-VIEW-02 验收）。
///
/// ## 为什么这一族非拍图不可
///
/// 别的组件还能用断言型测试兜一层（触控尺寸、约束、反差）。
/// 插画不行：**它的正确性就是「看起来对不对」**，
/// 而「一个 `Path` 画出来是不是一朵云」没有任何非图像的判据。
///
/// 所以这里只拍图，红了就人去看。要它挡住的是：
///
///  · 手滑改坐标把某一笔画到画布外（那在代码里完全看不出来）；
///  · 换 token 之后色斑与线条的反差塌掉；
///  · 深色模式下线条与色斑贴到一起。
///
/// 一张图放齐六张画 × 明暗两套 —— 分开拍的话，改一个共用常数
/// （比如线宽）要看十二张才知道影响面。
@Tags(['golden'])
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/design/components/empty_illustration.dart';
import 'package:planning_assistant/design/theme/app_theme.dart';
import 'package:planning_assistant/design/tokens/colors.dart';
import 'package:planning_assistant/design/tokens/contrast.dart';
import 'package:planning_assistant/design/tokens/dimensions.dart';

Widget _gallery(Brightness brightness) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
  home: Builder(
    builder: (context) => ColoredBox(
      color: context.appColors.canvas,
      child: Center(
        child: Wrap(
          spacing: Spacing.lg,
          runSpacing: Spacing.lg,
          children: [
            // **不放名字**：测试环境里没有字体，文字会渲染成一片
            // 溢出色块，把画本身盖掉。顺序就是 `EmptyMotif.values`。
            for (final motif in EmptyMotif.values)
              EmptyIllustration(motif: motif),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  for (final brightness in Brightness.values) {
    final name = 'empty_illustration_${brightness.name}';

    testWidgets(name, (tester) async {
      await tester.binding.setSurfaceSize(const Size(440, 440));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_gallery(brightness));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/$name.png'),
      );
    });
  }

  group('线条与色斑的反差（§10.2 图形级 ≥3:1）', () {
    // ## 这一组是**两次翻车**留下的
    //
    //  1. 第一版「色斑 `brandFill`、线条 `brandGraphic`」——
    //     `AppTheme.dark()` 把这两个 token 设成了同一个值，
    //     深色下六张画全成了纯色块。**金标拍出来了，但那是人看出来的。**
    //  2. 第二版改成「同色的两个透明度」，以为反差就与 token 无关了。
    //     浅色下只有 2.85:1 —— 那一次是这几条断言拦下的，不是眼睛。
    //
    // 金标管「画得像不像」（没有非图像的判据），这里管「看不看得见」
    // （反差是个数，数就该断言）。两者缺一不可。

    for (final (name, ink, blob) in [
      ('light', BrandColors.primaryGraphic, SurfaceColors.sunken),
      ('dark', BrandColors.primaryDark, SurfaceColors.sunkenDark),
    ]) {
      test('$name：线条在色斑上看得见', () {
        expect(
          contrastRatio(ink, blob),
          greaterThanOrEqualTo(3),
          reason: '$name 下线条淹在色斑里了',
        );
      });
    }

    test('对照组：同色时这条断言会红', () {
      // 少了这条，一个恒返回 10 的 `contrastRatio` 能让上面全绿 ——
      // 而「两个 token 恰好相等」正是第一次翻车的形状。
      expect(
        contrastRatio(BrandColors.primaryDark, BrandColors.primaryDark),
        1,
      );
    });
  });

  testWidgets('画满画布，但不越界', (tester) async {
    // 这一条是**断言型**的补充：金标能看出「画歪了」，
    // 但看不出「差一点点就出界」—— 而出界在真机的某个缩放下才会露出来。
    //
    // 所有坐标都写在 120 的画布里，`EmptyIllustration` 也声明自己是
    // 120×120。两者对不上时（比如有人把 size 改小而忘了改坐标），
    // 画会被裁掉一角，而金标上那一角是白的，未必看得出来。
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Center(child: EmptyIllustration(motif: EmptyMotif.calm)),
      ),
    );

    final size = tester.getSize(find.byType(EmptyIllustration));
    expect(size, const Size(EmptyIllustration.size, EmptyIllustration.size));
  });
}

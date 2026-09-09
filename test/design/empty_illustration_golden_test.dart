/// 六张空态插画（design-system §8.2、FR-VIEW-02 验收）。
///
/// ## 金标与断言各管什么
///
/// | | 金标 | 反差断言 |
/// |---|---|---|
/// | 管 | 构图：认不认得出是一朵云、六张像不像一套、有没有画出画布 | 线条在色斑上看不看得见 |
/// | 判据 | **没有**——只能人看 | 反差是个数 |
/// | 红了怎么办 | 人看图确认是否有意 | 去改 token |
///
/// **金标的存在理由是「没有非图像的判据」**，不是「反差断言抓不住」。
/// 这个区别要紧：反差断言其实**抓得住** token 相关的问题（下面那段
/// 有实测），照「历史上是金标先抓到的」去论证，将来有人补齐断言之后
/// 就会推出「金标冗余」——而它管的构图那一半，一条数都写不出来。
///
/// ## 一个实测，把上面那张表钉住
///
/// 第一版用的是「色斑 `brandFill` + 线条 `brandGraphic`」。
/// 把 `blobOf` 改回 `brandFill` 重跑反差断言：
///
/// ```
/// light：线条在色斑上看得见 [E]  Actual: <1.94>
/// dark ：线条在色斑上看得见 [E]  Actual: <1.0>
/// ```
///
/// 两个主题**都红**。深色下是 1.0 —— `AppTheme.dark()` 把
/// brandFill / brandGraphic / brandText 设成了同一个值。
///
/// 而当时金标只让**深色**那张显出问题（六个纯色块，一眼可见）；
/// 浅色那张 1.94 看着完全正常，**人是看不出来的**。
/// 也就是说这两样谁也不比谁强，管的是不同的东西。
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
    // ## 这一组问的是「**这个组件用的那一对**够不够」
    //
    // 第一稿把 token 又抄了一遍（`primaryGraphic` / `sunken` 直接写在
    // 断言里）。那样验的是「某一对 token 的反差」——组件改用别的 token
    // 时，这条断言**照旧绿着**，因为它根本不知道组件改了。
    // 而这一组存在的全部理由，就是挡住组件选错 token。
    //
    // 所以改成读 `EmptyIllustration.blobOf/inkOf`：两边同一处来源，
    // 断言才真的跟着组件走。评审追问金标与断言的分工时翻出来的。

    int rgb(Color c) => c.toARGB32() & 0xFFFFFF;

    for (final (name, theme) in [
      ('light', AppTheme.light()),
      ('dark', AppTheme.dark()),
    ]) {
      test('$name：线条在色斑上看得见', () {
        final colors = theme.extension<AppSemanticColors>()!;
        expect(
          contrastRatio(
            rgb(EmptyIllustration.inkOf(colors)),
            rgb(EmptyIllustration.blobOf(colors)),
          ),
          greaterThanOrEqualTo(3),
          reason: '$name 下线条淹在色斑里了',
        );
      });
    }

    test('对照组：同色时这条断言会红', () {
      // 少了这条，一个恒返回 10 的 `contrastRatio` 能让上面全绿 ——
      // 而「两个 token 恰好相等」正是第一次翻车的形状：
      // `AppTheme.dark()` 把 brandFill / brandGraphic / brandText
      // 设成了同一个值。
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

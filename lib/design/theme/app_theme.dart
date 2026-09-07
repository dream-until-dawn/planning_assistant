/// 主题装配（design-system §9）。
///
/// **所有颜色显式指定，不用 `ColorScheme.fromSeed`** —— 它会把低饱和色
/// 算成高饱和，破坏「可爱清新」的基调。这条由
/// `test/design/theme_test.dart` 守着，不只是注释。
library;

import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/dimensions.dart';

/// 主题里那些 Material 没有对应字段、但组件要用的值。
///
/// 放 `ThemeExtension` 而不是全局常量，是因为它们**随主题变**
/// （图形色明暗两套、阴影暗色下为空）。组件从 context 取，
/// 于是切主题时自动跟着变，不需要每个组件自己判明暗。
@immutable
final class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.brandFill,
    required this.brandGraphic,
    required this.brandText,
    required this.onBrand,
    required this.canvas,
    required this.card,
    required this.sunken,
    required this.borderSubtle,
    required this.doneFill,
    required this.doneText,
    required this.soonFill,
    required this.soonText,
    required this.overdueFill,
    required this.overdueText,
    required this.infoFill,
    required this.infoText,
    required this.dangerFill,
    required this.dangerText,
    required this.cardShadow,
  });

  /// 填充：按钮底、选中态背景。**不作唯一信息载体。**
  final Color brandFill;

  /// 图形：进度条、选中指示。与表面 ≥3:1。**其上不得放文字。**
  final Color brandGraphic;

  /// 品牌色**作文字**。亮色下不等于 [brandGraphic]（那个只到图形级）。
  final Color brandText;

  final Color onBrand;
  final Color canvas;
  final Color card;
  final Color sunken;
  final Color borderSubtle;

  final Color doneFill;
  final Color doneText;
  final Color soonFill;
  final Color soonText;
  final Color overdueFill;
  final Color overdueText;
  final Color infoFill;
  final Color infoText;
  final Color dangerFill;
  final Color dangerText;

  /// 暗色主题下为空列表 —— 暗色里阴影几乎不可见（§6）。
  final List<BoxShadow> cardShadow;

  @override
  AppSemanticColors copyWith({
    Color? brandFill,
    Color? brandGraphic,
    Color? brandText,
    Color? onBrand,
    Color? canvas,
    Color? card,
    Color? sunken,
    Color? borderSubtle,
    Color? doneFill,
    Color? doneText,
    Color? soonFill,
    Color? soonText,
    Color? overdueFill,
    Color? overdueText,
    Color? infoFill,
    Color? infoText,
    Color? dangerFill,
    Color? dangerText,
    List<BoxShadow>? cardShadow,
  }) => AppSemanticColors(
    brandFill: brandFill ?? this.brandFill,
    brandGraphic: brandGraphic ?? this.brandGraphic,
    brandText: brandText ?? this.brandText,
    onBrand: onBrand ?? this.onBrand,
    canvas: canvas ?? this.canvas,
    card: card ?? this.card,
    sunken: sunken ?? this.sunken,
    borderSubtle: borderSubtle ?? this.borderSubtle,
    doneFill: doneFill ?? this.doneFill,
    doneText: doneText ?? this.doneText,
    soonFill: soonFill ?? this.soonFill,
    soonText: soonText ?? this.soonText,
    overdueFill: overdueFill ?? this.overdueFill,
    overdueText: overdueText ?? this.overdueText,
    infoFill: infoFill ?? this.infoFill,
    infoText: infoText ?? this.infoText,
    dangerFill: dangerFill ?? this.dangerFill,
    dangerText: dangerText ?? this.dangerText,
    cardShadow: cardShadow ?? this.cardShadow,
  );

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppSemanticColors(
      brandFill: c(brandFill, other.brandFill),
      brandGraphic: c(brandGraphic, other.brandGraphic),
      brandText: c(brandText, other.brandText),
      onBrand: c(onBrand, other.onBrand),
      canvas: c(canvas, other.canvas),
      card: c(card, other.card),
      sunken: c(sunken, other.sunken),
      borderSubtle: c(borderSubtle, other.borderSubtle),
      doneFill: c(doneFill, other.doneFill),
      doneText: c(doneText, other.doneText),
      soonFill: c(soonFill, other.soonFill),
      soonText: c(soonText, other.soonText),
      overdueFill: c(overdueFill, other.overdueFill),
      overdueText: c(overdueText, other.overdueText),
      infoFill: c(infoFill, other.infoFill),
      infoText: c(infoText, other.infoText),
      dangerFill: c(dangerFill, other.dangerFill),
      dangerText: c(dangerText, other.dangerText),
      // 阴影不插值：明暗之间是「有」与「无」，中间态没有意义。
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
    );
  }
}

/// 从 context 取语义色。
extension AppThemeContext on BuildContext {
  AppSemanticColors get appColors =>
      Theme.of(this).extension<AppSemanticColors>()!;
}

abstract final class AppTheme {
  static ThemeData light({CornerStyle corners = CornerStyle.standard}) =>
      _build(brightness: Brightness.light, corners: corners);

  static ThemeData dark({CornerStyle corners = CornerStyle.standard}) =>
      _build(brightness: Brightness.dark, corners: corners);

  static ThemeData _build({
    required Brightness brightness,
    required CornerStyle corners,
  }) {
    final isLight = brightness == Brightness.light;

    final semantic = isLight
        ? AppSemanticColors(
            brandFill: BrandColors.primaryFill.toColor(),
            brandGraphic: BrandColors.primaryGraphic.toColor(),
            brandText: BrandColors.primaryText.toColor(),
            onBrand: TextColors.onBrand.toColor(),
            canvas: SurfaceColors.canvas.toColor(),
            card: SurfaceColors.card.toColor(),
            sunken: SurfaceColors.sunken.toColor(),
            borderSubtle: SurfaceColors.borderSubtle.toColor(),
            doneFill: SemanticColors.doneFill.toColor(),
            doneText: SemanticColors.doneText.toColor(),
            soonFill: SemanticColors.soonFill.toColor(),
            soonText: SemanticColors.soonText.toColor(),
            overdueFill: SemanticColors.overdueFill.toColor(),
            overdueText: SemanticColors.overdueText.toColor(),
            infoFill: SemanticColors.infoFill.toColor(),
            infoText: SemanticColors.infoText.toColor(),
            dangerFill: SemanticColors.dangerFill.toColor(),
            dangerText: SemanticColors.dangerText.toColor(),
            cardShadow: Shadows.soft,
          )
        : AppSemanticColors(
            // 暗色主题填充与图形共用一个值：`#5FB3A3` 对三个暗表面
            // 本就 ≥3:1（6.97 / 6.17 / 7.46），不需要第二个 token。
            brandFill: BrandColors.primaryDark.toColor(),
            brandGraphic: BrandColors.primaryDark.toColor(),
            brandText: BrandColors.primaryDark.toColor(),
            onBrand: TextColors.onBrand.toColor(),
            canvas: SurfaceColors.canvasDark.toColor(),
            card: SurfaceColors.cardDark.toColor(),
            sunken: SurfaceColors.sunkenDark.toColor(),
            borderSubtle: SurfaceColors.borderSubtleDark.toColor(),
            // 暗色下 .fill 系列在深底上实测 7.0–11.4:1，可直接兼作文字色，
            // 无需第二套（§2.4）。
            doneFill: SemanticColors.doneFill.toColor(),
            doneText: SemanticColors.doneFill.toColor(),
            soonFill: SemanticColors.soonFill.toColor(),
            soonText: SemanticColors.soonFill.toColor(),
            overdueFill: SemanticColors.overdueFill.toColor(),
            overdueText: SemanticColors.overdueFill.toColor(),
            infoFill: SemanticColors.infoFill.toColor(),
            infoText: SemanticColors.infoFill.toColor(),
            dangerFill: SemanticColors.dangerFill.toColor(),
            dangerText: SemanticColors.dangerFill.toColor(),
            cardShadow: Shadows.none,
          );

    final scheme = ColorScheme(
      brightness: brightness,
      primary: semantic.brandFill,
      onPrimary: semantic.onBrand,
      secondary:
          (isLight ? BrandColors.secondaryFill : BrandColors.secondaryDark)
              .toColor(),
      onSecondary: semantic.onBrand,
      tertiary: (isLight ? BrandColors.tertiaryFill : BrandColors.tertiaryDark)
          .toColor(),
      onTertiary: semantic.onBrand,
      error: semantic.dangerText,
      onError: isLight ? semantic.card : semantic.canvas,
      surface: semantic.card,
      onSurface: (isLight ? TextColors.primary : TextColors.primaryDark)
          .toColor(),
      onSurfaceVariant:
          (isLight ? TextColors.secondary : TextColors.secondaryDark).toColor(),
      outline: semantic.borderSubtle,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: semantic.canvas,
      textTheme: _textTheme(scheme.onSurface, scheme.onSurfaceVariant),
      cardTheme: CardThemeData(
        color: semantic.card,
        elevation: 0, // 阴影由 token 画，不用 Material 的 elevation
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(corners.apply(Radii.lg)),
        ),
      ),
      extensions: [semantic],
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary) => TextTheme(
    displaySmall: TextStyle(
      fontSize: TypeScale.displaySize,
      height: TypeScale.displayHeight,
      fontWeight: TypeScale.displayWeight,
      color: primary,
    ),
    titleLarge: TextStyle(
      fontSize: TypeScale.titleLgSize,
      height: TypeScale.titleLgHeight,
      fontWeight: TypeScale.titleLgWeight,
      color: primary,
    ),
    titleMedium: TextStyle(
      fontSize: TypeScale.titleMdSize,
      height: TypeScale.titleMdHeight,
      fontWeight: TypeScale.titleMdWeight,
      color: primary,
    ),
    bodyLarge: TextStyle(
      fontSize: TypeScale.bodyLgSize,
      height: TypeScale.bodyLgHeight,
      fontWeight: TypeScale.bodyLgWeight,
      color: primary,
    ),
    bodyMedium: TextStyle(
      fontSize: TypeScale.bodyMdSize,
      height: TypeScale.bodyMdHeight,
      fontWeight: TypeScale.bodyMdWeight,
      color: primary,
    ),
    labelLarge: TextStyle(
      fontSize: TypeScale.labelSize,
      height: TypeScale.labelHeight,
      fontWeight: TypeScale.labelWeight,
      color: primary,
    ),
    bodySmall: TextStyle(
      fontSize: TypeScale.captionSize,
      height: TypeScale.captionHeight,
      fontWeight: TypeScale.captionWeight,
      color: secondary,
    ),
  );
}

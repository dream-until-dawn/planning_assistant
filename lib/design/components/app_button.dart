/// 按钮（design-system §8.5）。
///
/// 四个变体，区别不只是颜色 —— 每个变体的**对比度约束不一样**：
///
/// | 变体 | 底 | 标签 | 约束 |
/// |---|---|---|---|
/// | primary | `brand.fill` | `text.onBrand` | 6.62 ✅ |
/// | secondary | 透明 + `brand.graphic` 描边 | `brand.text` | 描边 ≥3、标签 ≥4.5 |
/// | text | 透明 | `brand.text` | ≥4.5 |
/// | danger | 透明 | `semantic.danger.text` | ≥4.5 |
///
/// **次按钮的标签不能用 `brand.graphic`**：那个色对亮表面只有
/// 3.35 / 3.46 / 3.08，够画描边不够写字。描边和标签是两个 token，
/// 这正是品牌色要拆到三级的原因（§10.2）。
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../tokens/dimensions.dart';

/// 按钮变体。
enum AppButtonVariant {
  /// 主行动。一屏之内**最多一个** —— 都是主行动等于没有主行动。
  primary,

  /// 次行动。有描边，与背景分得开。
  secondary,

  /// 弱行动。无描边，用在密集处（卡片内、列表行尾）。
  text,

  /// 破坏性行动（删除）。用语义危险色，**不做红底**（低压力原则 §1）。
  danger,
}

/// 应用按钮。
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.expand = false,
    super.key,
  });

  final String label;

  /// 为 null 即禁用态。
  final VoidCallback? onPressed;

  final AppButtonVariant variant;

  /// 可选前置图标。
  final IconData? icon;

  /// 是否撑满可用宽度（表单底部的确认按钮用）。
  final bool expand;

  /// 描边宽度。
  static const double borderWidth = 1.5;

  bool get _enabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    // 药丸形。[Radii.full] 按 [CornerStyle.apply] 的约定不参与档位缩放。
    final radius = BorderRadius.circular(context.appShape.radius(Radii.full));

    final (Color? fill, Color label_, Color? border) = switch (variant) {
      AppButtonVariant.primary => (colors.brandFill, colors.onBrand, null),
      AppButtonVariant.secondary => (
        null,
        colors.brandText,
        colors.brandGraphic,
      ),
      AppButtonVariant.text => (null, colors.brandText, null),
      AppButtonVariant.danger => (null, colors.dangerText, null),
    };

    // 禁用态：底与标签都退到中性。
    //
    // WCAG 对禁用控件不作对比度要求，§2.3 也写明 `text.disabled` 仅用于
    // 禁用态、不承载信息。但这**不是**可以随便配色的意思 ——
    // 禁用态必须与启用态一眼可分，否则用户会反复点一个点不动的按钮。
    final effectiveFill = _enabled
        ? fill
        : (fill == null ? null : colors.sunken);
    // 用我们的 token，不用 Material 的 `disabledColor` —— 后者是它自己
    // 从 ColorScheme 推的，不在 §2.3 的对比度账本里，用法级守卫也认不出
    // 它是禁用态。初版就是写的它，守卫当场判 3.62 不达标。
    final effectiveLabel = _enabled ? label_ : colors.disabledText;
    final effectiveBorder = _enabled ? border : colors.borderSubtle;

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: TypeScale.labelSize * 1.3, color: effectiveLabel),
          const SizedBox(width: Spacing.xs),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: text.labelLarge?.copyWith(color: effectiveLabel),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: effectiveFill,
            borderRadius: radius,
            border: effectiveBorder == null
                ? null
                : Border.all(color: effectiveBorder, width: borderWidth),
          ),
          child: ConstrainedBox(
            // **高度下限是触控目标，不是视觉高度。** 字号放大时内容会更高，
            // 所以是 minHeight 而不是固定 height —— 固定高度在 2.8× 下
            // 会把标签压出去。
            constraints: const BoxConstraints(
              minHeight: Spacing.minTouchTarget,
              minWidth: Spacing.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg,
                vertical: Spacing.sm,
              ),
              child: Center(widthFactor: expand ? null : 1, child: content),
            ),
          ),
        ),
      ),
    );
  }
}

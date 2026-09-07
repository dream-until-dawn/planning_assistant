/// Chip（design-system §8.4）。两种，用途不同，别混：
///
/// - [CategoryChip]：**展示**分类。圆点 + 名字，不可点。
/// - [SelectableChip]：**筛选**。可选中，进筛选栏。
///
/// 两者的共同约束：**颜色不是唯一信息载体**（§8.1 同一条原则）。
/// 分类色只是一个圆点，分类名同时以文字出现；选中态除了填充还有一个勾。
/// 色觉障碍用户和把手机调成灰度的人都要能用。
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../tokens/dimensions.dart';

/// 分类标记。**不可点**，纯展示。
class CategoryChip extends StatelessWidget {
  const CategoryChip({required this.name, required this.color, super.key});

  final String name;

  /// 分类色。只画那个圆点 —— 不作标签色。
  ///
  /// 分类色是用户可配的低饱和填充色（§2.5），拿去写字大概率不达标；
  /// 而分类名必须读得出来，否则色觉障碍用户就只剩一个圆点。
  final Color color;

  /// 圆点直径。
  static const double dotSize = 8;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.sunken,
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: Spacing.xs),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 可选中的筛选 Chip。
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    required this.label,
    required this.selected,
    this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  /// 选中时的勾。
  ///
  /// **不是装饰** —— 没有它，选中与未选中的唯一区别就是底色深浅，
  /// 灰度屏或色觉障碍下几乎分不出来。§8.1 那条原则在这里同样适用。
  static const IconData checkIcon = Icons.check;

  static const double borderWidth = 1.5;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;

    // 选中：品牌填充 + onBrand 标签（6.62 ✅）。
    // 未选中：凹陷底 + 常规标签色，描边极淡。
    final fill = selected ? colors.brandFill : colors.sunken;
    final labelColor = selected ? colors.onBrand : text.labelLarge?.color;
    final border = selected ? colors.brandGraphic : colors.borderSubtle;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onSelected == null ? null : () => onSelected!(!selected),
        borderRadius: BorderRadius.circular(Radii.full),
        child: ConstrainedBox(
          // 可点即需 48dp 触控高度。视觉药丸比这矮，靠 Center 撑开 ——
          // 与任务卡片完成钮同一个做法：视觉跟设计，触控跟手指。
          constraints: const BoxConstraints(minHeight: Spacing.minTouchTarget),
          child: Center(
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(Radii.full),
                border: Border.all(color: border, width: borderWidth),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: Spacing.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      Icon(
                        checkIcon,
                        size: TypeScale.labelSize * 1.2,
                        color: labelColor,
                      ),
                      const SizedBox(width: Spacing.xs),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelLarge?.copyWith(color: labelColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 空态（design-system §8.2）。
///
/// 规格里那句「**禁止**出现『暂无数据』这种冷冰冰的默认文案」是硬的：
/// 空态是用户见到的第一屏，也是最容易让人觉得「这 App 没做完」的一屏。
///
/// 三件套缺一不可：**插画 + 一句轻松文案 + 一个明确行动按钮**。
/// 少了按钮，用户知道空但不知道下一步；少了文案，插画就成了装饰。
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../tokens/dimensions.dart';
import 'app_button.dart';

/// 空态。
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.illustration,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// 插画。用 [Widget] 而不是资源名 —— 插画可能是 SVG、可能是
  /// `CustomPaint`、也可能是一组图标拼的，这里不替调用方决定。
  final Widget illustration;

  /// 一句话。轻松，不说教，不用感叹号堆压力（§1 低压力原则）。
  final String message;

  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        // 大字号下空态一样会超高。能滚，而不是溢出。
        padding: const EdgeInsets.all(Spacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            illustration,
            const SizedBox(height: Spacing.xl),
            Text(message, textAlign: TextAlign.center, style: text.titleMedium),
            if (actionLabel != null) ...[
              const SizedBox(height: Spacing.xxl),
              AppButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

/// 「今天还没有安排」用的插画。
///
/// **不引外部资源**：一个用 token 画的圆形底 + 图标。
/// 理由是 V1 不联网（NFR-PRIV-01），而打包位图会随着空态种类增多
/// 线性长包体积；这个形状可以按语义换图标复用。
class EmptyIllustration extends StatelessWidget {
  const EmptyIllustration({required this.icon, super.key});

  final IconData icon;

  static const double diameter = 96;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.sunken, shape: BoxShape.circle),
        child: Center(
          child: Icon(
            icon,
            size: diameter * 0.42,
            // 图标是**装饰性**的：真正的信息在下面那句文案里。
            // 所以用 graphic 级（≥3:1）而不是文字级 —— 它不承载信息，
            // 也不是状态指示，把它当文字判会平白拉高整体反差。
            color: colors.brandGraphic,
          ),
        ),
      ),
    );
  }
}

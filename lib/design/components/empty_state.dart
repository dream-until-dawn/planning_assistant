/// 空态（design-system §8.2）。
///
/// 规格里那句「**禁止**出现『暂无数据』这种冷冰冰的默认文案」是硬的：
/// 空态是用户见到的第一屏，也是最容易让人觉得「这 App 没做完」的一屏。
///
/// 三件套缺一不可：**插画 + 一句轻松文案 + 一个明确行动按钮**。
/// 少了按钮，用户知道空但不知道下一步；少了文案，插画就成了装饰。
library;

import 'package:flutter/material.dart';

import '../tokens/dimensions.dart';
import 'app_button.dart';
import 'empty_illustration.dart';

/// 空态。
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.illustration,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// 插画。用 [Widget] 而不是 [EmptyMotif] —— 空态不一定只有这一族画法，
  /// 而这一层不该替调用方决定。现成的六张在 `empty_illustration.dart`。
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

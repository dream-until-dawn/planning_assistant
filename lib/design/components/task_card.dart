/// 任务卡片（design-system §8.1）—— M2 最重要的组件。
///
/// ```
/// ┌────────────────────────────────────────────┐
/// │ ▎ ○  任务标题                        14:00 │   ▎= 分类色条(3px)
/// │ ▎    └ 副信息：分类 · 阶段 2/5              │   ○ = 完成钮(48×48 触控区)
/// └────────────────────────────────────────────┘
/// ```
///
/// 这个组件是纯展示的：不认识 `Task` 实体、不查库、不发命令。
/// 它收的是已经整形好的值，回调交给上层。
/// 理由是它要在 golden 里被反复渲染，而 golden 不该依赖数据层。
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../tokens/dimensions.dart';

/// 卡片要显示的一条任务。**不是领域实体**，是展示用的整形结果。
@immutable
final class TaskCardData {
  const TaskCardData({
    required this.title,
    required this.categoryName,
    required this.categoryColor,
    this.timeLabel,
    this.stageProgress,
    this.isDone = false,
    this.isOverdue = false,
  });

  final String title;

  /// 分类名。**必须显示** —— 左侧色条不是唯一信息载体（§8.1）。
  final String categoryName;

  final Color categoryColor;

  /// `14:00` 之类；全天任务为 null。
  final String? timeLabel;

  /// 阶段事项的 `(已完成, 总数)`；非阶段事项为 null。
  final (int done, int total)? stageProgress;

  final bool isDone;
  final bool isOverdue;
}

/// 任务卡片。
class TaskCard extends StatelessWidget {
  const TaskCard({required this.data, this.onToggleDone, super.key});

  final TaskCardData data;
  final VoidCallback? onToggleDone;

  /// 完成钮的语义标签。屏幕阅读器读它。
  static const String toggleSemanticLabel = '切换完成状态';

  /// 完成钮的 Key。
  ///
  /// 公开出来是为了让**断言型测试**能直接量它的触控尺寸 ——
  /// widget 测试默认不建语义树，`bySemanticsLabel` 找不到东西，
  /// 而为了量个尺寸就去开语义树是把两件事混在一起。
  static const Key doneButtonKey = ValueKey('task-card-done-button');

  /// 左侧分类色条宽度（§8.1）。
  static const double stripeWidth = 3;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    // 圆角走档位，不直接写 Radii —— 用户可配的三档要真的生效。
    final radius = context.appShape.radius(Radii.lg);

    // 逾期时左色条换成 overdue.fill，时间文字用 overdue.text ——
    // **不是同一个色**（§2.4）。不加感叹号、不加红底（低压力原则）。
    final stripeColor = data.isOverdue
        ? colors.overdueFill
        : data.categoryColor;
    final timeColor = data.isOverdue ? colors.overdueText : null;

    return Semantics(
      container: true,
      // **卡片感由阴影承担，不画描边。**
      //
      // 页面底改成纯白之后 canvas 与 card 同色，卡片的颜色差归零
      // （design-system §2.2）。一度试过补一圈发丝描边，但那是把
      // 「分隔」的活派给了线 —— §2.2 明写「优先用留白代替线」，
      // 而 §6 本来就有阴影 token 干这件事。改成加强 `shadow.soft`
      // （两层，见那里的注释），描边去掉。
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: colors.cardShadow,
          // 左侧分类色条用**左边框**实现，不是一个撑满高度的子组件。
          //
          // 初版用 IntrinsicHeight + Row 拉伸一个 Container，
          // 而 IntrinsicHeight 不支持内部有 LayoutBuilder
          // （「LayoutBuilder does not support returning intrinsic dimensions」）——
          // 而时间是否下沉需要量宽度。边框写法两个问题一起没了，
          // 顺带色条会跟着圆角走，比直角贴边好看。
          border: Border(
            left: BorderSide(color: stripeColor, width: TaskCard.stripeWidth),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.cardPadding),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final timeStyle = text.bodySmall?.copyWith(color: timeColor);
              // 时间要不要另起一行，**用量的**，不拍阈值。
              //
              // 大字号 + 长时间标签（「昨天 18:00」）在 400dp 宽下会把标题
              // 挤到溢出 —— 实测 2.8× 时 RenderFlex 溢出 3 像素。
              // 时间是关键信息，不能用省略号截断；所以让它下沉到副信息下方，
              // 而不是压缩标题。
              final stacked =
                  data.timeLabel != null &&
                  _timeCrowdsTitle(
                    context,
                    label: data.timeLabel!,
                    style: timeStyle,
                    contentWidth: constraints.maxWidth,
                  );

              final time = data.timeLabel == null
                  ? null
                  : Text(data.timeLabel!, style: timeStyle);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DoneButton(
                    key: TaskCard.doneButtonKey,
                    isDone: data.isDone,
                    onPressed: onToggleDone,
                  ),
                  const SizedBox(width: Spacing.iconToText),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Body(data: data),
                        if (stacked) ...[
                          const SizedBox(height: Spacing.xs),
                          time!,
                        ],
                      ],
                    ),
                  ),
                  if (time != null && !stacked) ...[
                    const SizedBox(width: Spacing.iconToText),
                    time,
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 时间标签会不会把标题挤得太窄。
///
/// 判据：时间占去可用内容宽度的 [_timeWidthBudget] 以上就算挤 ——
/// 剩下的宽度要留给标题，而标题才是「这是哪件事」的答案。
///
/// **用实测宽度而不是缩放阈值**：同一个缩放下，「14:00」与「昨天 18:00」
/// 差着一倍宽度，拍一个「scale > 2 就换行」的阈值对前者是浪费、
/// 对后者仍可能不够。
bool _timeCrowdsTitle(
  BuildContext context, {
  required String label,
  required TextStyle? style,
  required double contentWidth,
}) {
  final available =
      contentWidth - Spacing.minTouchTarget - Spacing.iconToText * 2;
  if (available <= 0) return true;

  final painter = TextPainter(
    text: TextSpan(text: label, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();

  return painter.width > available * _timeWidthBudget;
}

/// 时间最多可以占内容宽度的比例。超过就下沉到下一行。
const double _timeWidthBudget = 0.4;

class _Body extends StatelessWidget {
  const _Body({required this.data});

  final TaskCardData data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    final subtitle = <String>[
      data.categoryName,
      if (data.stageProgress != null)
        '阶段 ${data.stageProgress!.$1}/${data.stageProgress!.$2}',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          data.title,
          // **两行截断**：超长标题不能把卡片撑成一整屏，也不能只给一行 ——
          // 中文两行大约能放 30 字，够看清是哪件事。
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.bodyLarge?.copyWith(
            decoration: data.isDone ? TextDecoration.lineThrough : null,
            // 已完成用 **text.secondary**，不是 borderSubtle。
            //
            // 初版写的是 borderSubtle（#EDE7DD）—— 那是发丝分隔线的颜色，
            // 拿来当文字实测 1.23:1，等于看不见。断言型 32 条、golden 6 张
            // 全绿，我还看着图确认过，把「淡到读不出」当成了「完成态变淡」。
            // 是用法级守卫（token_usage_test）第一次跑就抓出来的。
            //
            // 完成态的信号由**划线 + 填充的勾**承载，不靠把字调没：
            // 已完成的任务标题仍然要读得出来 —— 撤销时得知道撤的是哪条。
            color: data.isDone ? text.bodySmall?.color : null,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall,
        ),
      ],
    );
  }
}

/// 完成钮。
///
/// **触控区固定 48×48**（无障碍硬要求，§5），而视觉圆钮小得多 ——
/// 两者不是一回事：视觉跟着设计走，触控区跟着手指走。
class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.isDone, this.onPressed, super.key});

  final bool isDone;
  final VoidCallback? onPressed;

  /// 视觉圆钮直径。触控区见 [Spacing.minTouchTarget]。
  static const double visualDiameter = 22;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      label: TaskCard.toggleSemanticLabel,
      checked: isDone,
      button: true,
      child: InkResponse(
        onTap: onPressed,
        radius: Spacing.minTouchTarget / 2,
        child: SizedBox(
          width: Spacing.minTouchTarget,
          height: Spacing.minTouchTarget,
          child: Center(
            child: Container(
              width: visualDiameter,
              height: visualDiameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // 未完成时是描边圈；完成后填充。
                // 用 graphic 而不是 fill —— 它是承载状态的非文字图形，
                // 需要与表面 ≥3:1（§10.2）。
                color: isDone ? colors.brandGraphic : Colors.transparent,
                border: Border.all(
                  color: isDone ? colors.brandGraphic : colors.borderSubtle,
                  width: 2,
                ),
              ),
              child: isDone
                  ? Icon(
                      Icons.check,
                      size: visualDiameter * 0.7,
                      color: colors.card,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

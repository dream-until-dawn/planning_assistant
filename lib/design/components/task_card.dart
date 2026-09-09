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

/// 卡片上的一个阶段子项。
///
/// **只带勾选要用的三样**。阶段自己还有时间段与颜色，
/// 但子项这一行不显示它们 —— 那两样是甘特与时间轴在排布时用的，
/// 摆到列表的子项上只会把「这一步做没做」这句话淹掉。
@immutable
final class TaskCardStage {
  const TaskCardStage({
    required this.id,
    required this.title,
    required this.isDone,
  });

  final String id;
  final String title;
  final bool isDone;
}

/// 卡片要显示的一条任务。**不是领域实体**，是展示用的整形结果。
@immutable
final class TaskCardData {
  const TaskCardData({
    required this.title,
    required this.categoryName,
    required this.categoryColor,
    this.timeLabel,
    this.stageProgress,
    this.stages = const [],
    this.isDone = false,
    this.isOverdue = false,
    this.isRecurring = false,
    this.priorityLabel,
  });

  final String title;

  /// 分类名。**必须显示** —— 左侧色条不是唯一信息载体（§8.1）。
  final String categoryName;

  final Color categoryColor;

  /// `14:00` 之类；全天任务为 null。
  final String? timeLabel;

  /// 阶段事项的 `(已完成, 总数)`；非阶段事项为 null。
  final (int done, int total)? stageProgress;

  /// 摊开在卡片下方的阶段子项（用户第 ② 条）。
  ///
  /// **空表 = 不摊开**，与「这条任务没有阶段」是同一种表现，也确实是
  /// 同一件事：只有列表视图传它。日历与甘特上的卡片本来就挤在格子里，
  /// 再摞几行子项会把一天的其它任务挤出可视区，而那两个视图的重点是
  /// **这一天有什么**，不是**这件事做到哪一步**。
  ///
  /// [stageProgress] 仍然照常显示 —— 两者一个是摘要一个是明细，
  /// 摊开时上面那行 `阶段 1/2` 正好是这几行的合计。
  final List<TaskCardStage> stages;

  final bool isDone;
  final bool isOverdue;

  /// 优先级。**「普通」时不显示** —— 大多数任务是普通，
  /// 每张卡片都挂一个「普通」等于什么也没说，还占掉副信息的位置。
  ///
  /// 用**文字**而不是颜色或图标：§8.1 那条「颜色/图标不单独承载信息」
  /// 在这里同样适用，而优先级恰恰是最容易被做成一个小红点的东西。
  final String? priorityLabel;

  /// 这条任务会重复（FR-TASK-03）。
  ///
  /// **必须有可见标记**：重复任务与单次任务在卡片上本来一模一样，
  /// 而它们的完成、删除、修改语义完全不同 —— 分不出来的话，
  /// 用户会以为自己删掉的是一次，实际删的是整条规则。
  final bool isRecurring;
}

/// 任务卡片。
class TaskCard extends StatelessWidget {
  const TaskCard({
    required this.data,
    this.onToggleDone,
    this.onToggleStage,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    super.key,
  });

  final TaskCardData data;
  final VoidCallback? onToggleDone;

  /// 勾/取消一个阶段子项。为 null 时子项只读（勾选框灰着）。
  ///
  /// **卡片自己不知道该往哪张表写**：不重复的任务状态在 `Stage.status`，
  /// 重复的在这一次的 `stage_occurrence_states`。那条分岔在
  /// `OccurrenceActions.setStageDone` 里，卡片只报「用户点了哪个」。
  final void Function(String stageId, bool done)? onToggleStage;

  /// 点卡片本身（view-specs §0.3：点击实例 → 打开详情）。
  ///
  /// 为 null 时整张卡片不可点 —— 一个点了没反应的卡片，
  /// 比一张明确不可点的更让人困惑。
  final VoidCallback? onTap;

  /// 长按（view-specs §2.4：进入多选模式）。
  final VoidCallback? onLongPress;

  /// 多选模式下这张卡片被选中了。
  ///
  /// **不能只靠颜色**（§8.1：颜色/图标不单独承载信息）——
  /// 低饱和的「可爱清新」配色下，一层浅色底与未选中几乎分不出来。
  /// 所以选中时另加一圈明确的边框。
  final bool selected;

  /// 完成钮的语义标签。屏幕阅读器读它。
  static const String toggleSemanticLabel = '切换完成状态';

  /// 完成钮的 Key。
  ///
  /// 公开出来是为了让**断言型测试**能直接量它的触控尺寸 ——
  /// widget 测试默认不建语义树，`bySemanticsLabel` 找不到东西，
  /// 而为了量个尺寸就去开语义树是把两件事混在一起。
  static const Key doneButtonKey = ValueKey('task-card-done-button');

  /// 一个阶段子项的勾选框。
  static Key stageKey(String stageId) => ValueKey('task-card-stage-$stageId');

  /// 重复标记的图标。
  ///
  /// 图标之外**副信息里还有文字**（「每 3 周的一、三、五」），
  /// 不靠图标单独承载（§8.1）。文字由调用方拼进 `categoryName`，
  /// 见 `task_list_page.dart` 的 `_describeRule`。
  ///
  /// 这段注释一度写着同样的话，而当时那边只输出「每周」——
  /// 举的例子是我以为的行为，不是代码的行为。举例子就要举**真跑出来的**。
  static const IconData recurringIcon = Icons.repeat;

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

    final card = Semantics(
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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DoneButton(
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
                  ),
                  // 子项**缩进到与标题对齐**：左边让出完成钮那一格。
                  // 顶格摆的话，子项和它上面那条任务看起来是平级的，
                  // 而它们恰恰不是 —— 缩进就是「这几行属于上面那条」
                  // 这句话本身。
                  for (final stage in data.stages)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: Spacing.minTouchTarget + Spacing.iconToText,
                      ),
                      child: _StageRow(
                        stage: stage,
                        onToggle: onToggleStage == null
                            ? null
                            : (v) => onToggleStage!(stage.id, v),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );

    // 选中态：**加边框，不只是换底色**（§8.1）。
    final decorated = selected
        ? DecoratedBox(
            decoration: BoxDecoration(
              // 跟卡片本身同一个圆角档位（用户可配的三档）。
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: context.appColors.brandGraphic,
                width: 2,
              ),
            ),
            child: card,
          )
        : card;

    if (onTap == null && onLongPress == null) return decorated;
    // **点击区包在外面，不换成 InkWell 当背景。**
    // 卡片的圆角、阴影、左色条都在 DecoratedBox 上；
    // 换成 Material 系的容器会把那三样重画一遍，golden 全线要重拍。
    return GestureDetector(
      // 卡片之间有间距，`opaque` 让整张卡片（含内边距）都可点，
      // 而不只是文字所在的那几个像素。
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: decorated,
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

/// 一行阶段子项：一个勾选框 + 标题。
///
/// **不用 `CheckboxListTile`**：那个组件自带 16dp 的水平内边距与
/// 最小 56dp 的行高，摞三行就把一张卡片撑到两倍高，
/// 而这里要的是「贴在任务下面的几小行」。
class _StageRow extends StatelessWidget {
  const _StageRow({required this.stage, this.onToggle});

  final TaskCardStage stage;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 勾选框的触控区靠 `Checkbox` 自己的 padded 目标撑到 48dp，
        // 不是画一个 48dp 的方框 —— 后者在视觉上会变成一个大色块。
        //
        // **不设 `visualDensity: compact`。** 一度设了，为的是让子项
        // 挨得紧一点；那一档把触控目标从 48 缩到 40，断言当场变红。
        // 子项行密不密是观感，40dp 的勾选框是**点不准**——
        // 而这几行恰恰是要一路点下去的那种东西。
        Checkbox(
          key: TaskCard.stageKey(stage.id),
          value: stage.isDone,
          onChanged: onToggle == null ? null : (v) => onToggle!(v ?? false),
        ),
        Expanded(
          child: Text(
            stage.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(
              // **只划线，不再调暗。** 子项本来就是 `bodySmall`
              // （副信息那一档的颜色），在这个基础上再压一层，
              // 走的就是标题那条注释里记下的老路 —— 淡到读不出，
              // 而断言与 golden 都不会红。
              decoration: stage.isDone ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.data});

  final TaskCardData data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    final subtitle = <String>[
      data.categoryName,
      if (data.priorityLabel != null) data.priorityLabel!,
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
        Row(
          children: [
            if (data.isRecurring) ...[
              Icon(
                TaskCard.recurringIcon,
                size: TypeScale.captionSize,
                // 与副信息同一个层级：它是补充说明，不是警示。
                color: text.bodySmall?.color,
              ),
              const SizedBox(width: Spacing.xxs),
            ],
            Flexible(
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 完成钮。
///
/// **触控区固定 48×48**（无障碍硬要求，§5），而视觉圆钮小得多 ——
/// 两者不是一回事：视觉跟着设计走，触控区跟着手指走。
///
/// ## 为什么是公开的
///
/// 时间轴把阶段摆成了独立的卡片，那张卡上也要一个「做完没有」。
/// 用 Material 的 `Checkbox` 的话，同一屏上会同时出现方框与圆钮 ——
/// 而它们表示的是同一件事。真机截图上一眼就能看出来。
class DoneButton extends StatelessWidget {
  const DoneButton({required this.isDone, this.onPressed, super.key});

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

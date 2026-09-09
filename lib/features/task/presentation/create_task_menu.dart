/// 加号弹出的那个小面板：五选一（FR-TASK-01/02/03）。
///
/// ## 为什么是「先选形态再进表单」
///
/// 上一版是一个加号直接进表单，形态靠表单里的开关来回切（阶段区、
/// 重复区都在同一页上）。用户看过之后要的是**先选**：
///
/// > 新增任务的按你调整为点击后出现悬浮小面板有 5 个选项，
/// > 分别是 单事项、阶段事项、重复单事项、重复阶段事项、临时事项
///
/// 这一步换来的是**表单只显示这一样需要的区块** —— 建一条临时事项时
/// 不必看见重复规则，建单事项时不必看见阶段列表。
/// 代价是多一次点击，而那一次点击本来也要花在表单里的开关上。
///
/// ## 为什么锚在加号上，不用底部弹层
///
/// 这个项目里底部弹层已经有两个意思了（「改哪一次」、筛选多选），
/// 都是**对着某个已有东西**的操作。新建不对着任何东西，
/// 从加号上长出来更贴近「这个按钮能做什么」。
/// 用户的原话也是「悬浮小面板」。
library;

import 'package:flutter/material.dart';

import '../../../design/theme/app_theme.dart';
import '../../../design/tokens/dimensions.dart';
import '../application/task_shape.dart';

/// 面板上每一项的 Key。
Key createShapeKey(TaskShape shape) => ValueKey('create-shape-${shape.name}');

/// 每一样配一个图标。
///
/// **图标之外一定有文字**（`TaskShape.label`）——
/// 图标不单独承载信息（NFR-A11Y-01）。这五样的区别是「有没有阶段」
/// 与「重不重复」，光靠图形分不出来。
const _icons = {
  TaskShape.single: Icons.check_circle_outline,
  TaskShape.staged: Icons.list_alt_outlined,
  TaskShape.recurringSingle: Icons.repeat,
  TaskShape.recurringStaged: Icons.repeat_on_outlined,
  TaskShape.scratch: Icons.bolt_outlined,
};

/// 一句话说清这一样是什么。
///
/// 只写**这一样特有的约束**，不写通用的东西 —— 五行副文案里
/// 三行都是「填个标题」的话，它们就等于没有。
const _hints = {
  TaskShape.single: '有明确的起止时间',
  TaskShape.staged: '分几步走，每步各有起止',
  TaskShape.recurringSingle: '按规则重复的一件事',
  TaskShape.recurringStaged: '按规则重复，每次分几步',
  TaskShape.scratch: '不排时间，哪天做都行',
};

/// 从 [anchorContext]（加号那个按钮）上弹出面板。
///
/// 返回用户选的那一样；点外面关掉时返回 null。
///
/// **位置按锚点算，不写死屏幕坐标**：加号在右下，面板从它上方长出来。
/// 写死的话，横屏、大字号、或者将来加号挪位置，面板就飘了。
Future<TaskShape?> showCreateTaskMenu(BuildContext anchorContext) {
  final anchor = anchorContext.findRenderObject()! as RenderBox;
  final overlay =
      Navigator.of(anchorContext).overlay!.context.findRenderObject()!
          as RenderBox;
  final topLeft = anchor.localToGlobal(Offset.zero, ancestor: overlay);
  final size = overlay.size;

  return showMenu<TaskShape>(
    context: anchorContext,
    // 贴着加号的**上边缘**往上长：`bottom` 用锚点顶边到屏幕底的距离，
    // 于是面板底部正好压在按钮上方。
    position: RelativeRect.fromLTRB(
      topLeft.dx,
      topLeft.dy,
      size.width - topLeft.dx - anchor.size.width,
      size.height - topLeft.dy,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(
        anchorContext.appShape.radius(Radii.lg),
      ),
    ),
    color: anchorContext.appColors.card,
    items: [
      for (final shape in TaskShape.menu)
        PopupMenuItem<TaskShape>(
          key: createShapeKey(shape),
          value: shape,
          child: _ShapeRow(shape: shape),
        ),
    ],
  );
}

class _ShapeRow extends StatelessWidget {
  const _ShapeRow({required this.shape});

  final TaskShape shape;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(_icons[shape], size: Spacing.lg, color: colors.brandGraphic),
        const SizedBox(width: Spacing.iconToText),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(shape.label, style: text.labelLarge),
            Text(_hints[shape]!, style: text.bodySmall),
          ],
        ),
      ],
    );
  }
}

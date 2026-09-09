/// 列表里的滑动手势（view-specs §2.4）。
///
/// 右滑 / 左滑各做什么由配置决定（`behavior.swipeRight` / `swipeLeft`），
/// 默认右滑完成、左滑推迟一天。
///
/// ## 为什么滑完要给撤销
///
/// 滑动是**最容易误触**的手势 —— 列表本来就要上下滚，横向多走一点就
/// 触发了。而「推迟」把这一行从今天挪走，用户下一眼就找不到它了。
/// 所以每次滑动都配一条撤销 Snackbar（view-specs §0.3 也这么要求）。
///
/// 「完成」不需要靠 Snackbar 兜底 —— 卡片留在原位只是划掉（§8.1），
/// 再点一下就撤回。但两种都给，是因为「滑完之后能不能反悔」
/// 不该取决于用户滑的是哪一边。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/theme/app_theme.dart';
import '../../../../design/tokens/dimensions.dart';
import '../../../settings/application/registry.dart';
import '../../../settings/application/settings_providers.dart';
import '../../../trash/application/trash_providers.dart';
import '../../shared/application/task_occurrence.dart';
import '../application/task_list_actions.dart';

/// 滑动背景的 Key，供测试定位。
abstract final class SwipeKeys {
  static Key row(String rowId) => ValueKey('swipe-$rowId');
  static const Key undo = ValueKey('swipe-undo');
}

/// 给一行套上滑动手势。
///
/// 两边都配成「不做事」时**不包 `Dismissible`** —— 包了的话手势照样
/// 被吃掉，横向滑动会让卡片跟着动一下再弹回来，看着像坏了。
class SwipeRow extends ConsumerWidget {
  const SwipeRow({required this.row, required this.child, super.key});

  final TaskOccurrence row;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final right = ref.setting(swipeRight);
    final left = ref.setting(swipeLeft);
    if (right == SwipeAction.none && left == SwipeAction.none) return child;

    return Dismissible(
      key: SwipeKeys.row(row.id),
      direction: _directionFor(right, left),
      background: _Background(action: right, alignment: Alignment.centerLeft),
      secondaryBackground: _Background(
        action: left,
        alignment: Alignment.centerRight,
      ),
      // **一律返回 false**：滑动是触发一个动作，不是把这一行从列表里
      // 抹掉。让 Dismissible 真的移除的话，下一帧数据流推回来又要重建，
      // 中间那一帧会闪。动作本身会让列表自然变化。
      confirmDismiss: (direction) async {
        final action = direction == DismissDirection.startToEnd ? right : left;
        await _run(context, ref, action);
        return false;
      },
      child: child,
    );
  }

  DismissDirection _directionFor(SwipeAction right, SwipeAction left) {
    if (right == SwipeAction.none) return DismissDirection.endToStart;
    if (left == SwipeAction.none) return DismissDirection.startToEnd;
    return DismissDirection.horizontal;
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    SwipeAction action,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    switch (action) {
      case SwipeAction.none:
        return;
      case SwipeAction.complete:
        // **撤销闭包由动作自己给**：它知道切换之前是什么状态。
        // 这里再调一次 `call` 的话，捕获的 `row` 还是滑动前的快照，
        // 「撤销」会把刚完成的又标成完成。
        final undoDone = await ref.read(toggleTaskDoneProvider).call(row);
        _tell(messenger, '已完成', undoDone);
      case SwipeAction.postpone:
        final undo = await ref.read(postponeRowProvider).call(row);
        if (undo == null) {
          // 没有日期的任务谈不上推迟。**说一声**，而不是滑完毫无反应 ——
          // 后者与「手势坏了」在用户看来一模一样。
          _tell(messenger, '这条没有日期，推迟不了', null);
          return;
        }
        _tell(messenger, '已推迟到明天', undo);
      case SwipeAction.delete:
        // 软删除，进回收站 —— 这个手势能存在，靠的就是这条退路
        // （见 `SwipeAction.delete` 的注释）。
        final undoDelete = await ref
            .read(trashActionsProvider)
            .delete(row.taskId);
        _tell(messenger, '已移到回收站', undoDelete);
    }
  }

  void _tell(
    ScaffoldMessengerState? messenger,
    String text,
    VoidCallback? undo,
  ) {
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 5),
          action: undo == null
              ? null
              : SnackBarAction(
                  // Key 挂在 action 上没用（它不是 widget 树里的一个节点），
                  // 所以整条 SnackBar 用 content 的文案定位，撤销按钮
                  // 由这个 label 找。
                  label: '撤销',
                  onPressed: undo,
                ),
        ),
      );
  }
}

/// 滑动时露出来的底色 + 图标 + 文字。
///
/// **图标之外还有文字**：滑到一半时用户要立刻知道松手会发生什么，
/// 而图标不单独承载信息（design-system §8.1）。
class _Background extends StatelessWidget {
  const _Background({required this.action, required this.alignment});

  final SwipeAction action;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (action == SwipeAction.none) return const SizedBox.shrink();
    final colors = context.appColors;
    final (icon, label, fill) = switch (action) {
      SwipeAction.complete => (Icons.check, '完成', colors.doneFill),
      SwipeAction.postpone => (Icons.schedule, '推迟一天', colors.soonFill),
      SwipeAction.delete => (Icons.delete_outline, '删除', colors.dangerFill),
      SwipeAction.none => (Icons.block, '', colors.sunken),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(context.appShape.radius(Radii.lg)),
      ),
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.cardPadding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: TypeScale.titleMdSize),
              const SizedBox(width: Spacing.xs),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

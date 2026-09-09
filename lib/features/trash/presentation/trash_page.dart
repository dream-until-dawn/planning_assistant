/// 回收站（FR-TASK-08）。
///
/// 删掉的任务在这里躺着，可以恢复。设置页的**二级页** ——
/// 返回手势该回到设置，不是回到列表。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../design/components/empty_illustration.dart';
import '../../../design/components/empty_state.dart';
import '../../../design/theme/app_theme.dart';
import '../../../design/tokens/dimensions.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/policies/task_lifecycle.dart';
import '../application/trash_providers.dart';

class TrashPage extends ConsumerWidget {
  const TrashPage({super.key});

  static const Key pageKey = ValueKey('trash-page');
  static const Key emptyKey = ValueKey('trash-empty');
  static const Key errorKey = ValueKey('trash-error');

  static Key itemKey(String taskId) => ValueKey('trash-item-$taskId');
  static Key restoreKey(String taskId) => ValueKey('trash-restore-$taskId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final tasks = ref.watch(trashedTasksProvider);

    return Scaffold(
      key: pageKey,
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('回收站'),
      ),
      body: switch (tasks) {
        // 与列表同一个做法：本地库首帧通常一帧内就来了，转圈只会闪一下。
        AsyncLoading() => const SizedBox.shrink(),
        AsyncError() => const EmptyState(
          key: errorKey,
          illustration: EmptyIllustration(motif: EmptyMotif.offline),
          message: '没能读出回收站。\n重开一次试试？',
        ),
        AsyncData(:final value) when value.isEmpty => const EmptyState(
          key: emptyKey,
          illustration: EmptyIllustration(motif: EmptyMotif.box),
          message: '回收站是空的。',
        ),
        AsyncData(:final value) => _TrashList(tasks: value),
      },
    );
  }
}

class _TrashList extends ConsumerWidget {
  const _TrashList({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final retention = ref.watch(trashRetentionProvider);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      itemCount: tasks.length,
      itemBuilder: (context, i) {
        final task = tasks[i];
        return ListTile(
          key: TrashPage.itemKey(task.id),
          title: Text(task.title),
          // 说清它还能待多久（FR-TASK-08：30 天内可恢复）。
          // 不说的话，用户不知道这是「暂存」还是「已经没了」。
          subtitle: Text(
            _hint(task, ref.watch(clockProvider).nowUtc(), retention),
            style: text.bodySmall,
          ),
          trailing: TextButton(
            key: TrashPage.restoreKey(task.id),
            onPressed: () => ref.read(trashActionsProvider).restore(task.id),
            child: const Text('恢复'),
          ),
        );
      },
    );
  }
}

/// 「还能待多久」。
///
/// **这句话一度只写「删除于某日」**：那时自动清理（task-lifecycle L-09）
/// 还没实现，写「还剩 12 天」是在承诺一件不会发生的事。
/// 清理接上之后这句承诺才兑得了，所以现在敢写。
///
/// 天数**不在这里算**，问 `timeUntilPurge` —— 清理判据与这句话必须同源，
/// 理由记在那个函数上。这里只负责把一个 Duration 说成人话。
String _hint(Task task, DateTime now, int retentionDays) {
  final at = task.deletedAt;
  if (at == null) return '已删除';
  final when =
      '删除于 ${at.year}-${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';

  final left = timeUntilPurge(task, now: now, retentionDays: retentionDays)!;
  // 已经到期但还没被清（清理发生在下次启动）—— 说实话，别说「还剩 0 天」。
  if (left.isNegative) return '$when · 下次启动时清理';
  // 不满一天的说「今天最后一天」。**向下取整**是刻意的：
  // 宁可让用户早一天来救，也别让他以为还有一天。
  if (left.inDays == 0) return '$when · 今天最后一天';
  return '$when · 还剩 ${left.inDays} 天';
}

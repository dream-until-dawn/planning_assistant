/// 回收站（FR-TASK-08）。
///
/// 删掉的任务在这里躺着，可以恢复。设置页的**二级页** ——
/// 返回手势该回到设置，不是回到列表。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/empty_state.dart';
import '../../../design/theme/app_theme.dart';
import '../../../design/tokens/dimensions.dart';
import '../../../domain/entities/task.dart';
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
          illustration: EmptyIllustration(icon: Icons.cloud_off_outlined),
          message: '没能读出回收站。\n重开一次试试？',
        ),
        AsyncData(:final value) when value.isEmpty => const EmptyState(
          key: emptyKey,
          illustration: EmptyIllustration(icon: Icons.delete_outline),
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
          subtitle: Text(_deletedHint(task), style: text.bodySmall),
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

/// 「什么时候删的」。
///
/// **不显示「还剩几天」** —— 自动清理（task-lifecycle L-09）还没实现，
/// 写「还剩 12 天」是在承诺一件现在不会发生的事。
String _deletedHint(Task task) {
  final at = task.deletedAt;
  if (at == null) return '已删除';
  return '删除于 ${at.year}-${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';
}

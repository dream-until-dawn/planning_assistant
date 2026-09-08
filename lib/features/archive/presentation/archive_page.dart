/// 已归档的任务（FR-TASK-08）。
///
/// 设置页的二级页，与回收站并排。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/empty_state.dart';
import '../../../design/theme/app_theme.dart';
import '../../../design/tokens/dimensions.dart';
import '../../../domain/entities/task.dart';
import '../application/archive_providers.dart';

class ArchivePage extends ConsumerWidget {
  const ArchivePage({super.key});

  static const Key pageKey = ValueKey('archive-page');
  static const Key emptyKey = ValueKey('archive-empty');
  static const Key errorKey = ValueKey('archive-error');

  static Key itemKey(String taskId) => ValueKey('archive-item-$taskId');
  static Key unarchiveKey(String taskId) =>
      ValueKey('archive-unarchive-$taskId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;

    return Scaffold(
      key: pageKey,
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('已归档'),
      ),
      body: switch (ref.watch(archivedTasksProvider)) {
        AsyncLoading() => const SizedBox.shrink(),
        AsyncError() => const EmptyState(
          key: errorKey,
          illustration: EmptyIllustration(icon: Icons.cloud_off_outlined),
          message: '没能读出归档列表。\n重开一次试试？',
        ),
        AsyncData(:final value) when value.isEmpty => const EmptyState(
          key: emptyKey,
          illustration: EmptyIllustration(icon: Icons.inventory_2_outlined),
          message: '还没有归档的任务。',
        ),
        AsyncData(:final value) => _ArchiveList(tasks: value),
      },
    );
  }
}

class _ArchiveList extends ConsumerWidget {
  const _ArchiveList({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView.builder(
    padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
    itemCount: tasks.length,
    itemBuilder: (context, i) {
      final task = tasks[i];
      return ListTile(
        key: ArchivePage.itemKey(task.id),
        title: Text(task.title),
        trailing: TextButton(
          key: ArchivePage.unarchiveKey(task.id),
          onPressed: () => ref.read(archiveActionsProvider).unarchive(task.id),
          // 「取消归档」而不是「恢复」：恢复听起来像是从删除里捞回来，
          // 而归档从来没删过任何东西。
          child: const Text('取消归档'),
        ),
      );
    },
  );
}

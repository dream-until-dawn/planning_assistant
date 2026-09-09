/// 归档（FR-TASK-08、task-lifecycle §1.1）。
///
/// **归档与删除是两件正交的事**，各用一个时间戳列表达（§1.1）：
/// 归档是「做完了/不再关心，但想留着」，删除是「不要了」。
/// 所以这里与 `features/trash/` 是并排的两个小 feature，
/// 不是一个「收纳」feature 里的两个开关 —— 后者会诱使人把
/// `archivedAt` 与 `deletedAt` 合成一个状态字段，而 §1.1 明确否掉了那条路
/// （重复任务的 status 恒为 pending，归档若是状态，重复任务就永远归不了档）。
///
/// `ArchiveTaskCommand` / `UnarchiveTaskCommand` 在领域层一直都在、也测过 ——
/// 界面上够不着，与删除此前是同一种状态。
library;

import 'package:flutter/widgets.dart' show VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../domain/commands/task_command.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/repositories/task_repository.dart';

/// 已归档的任务，持续推送。
final archivedTasksProvider = StreamProvider<List<Task>>(
  (ref) =>
      ref.watch(taskRepositoryProvider).watchTasks(scope: TaskScope.archived),
);

final archiveActionsProvider = Provider<ArchiveActions>(ArchiveActions.new);

final class ArchiveActions {
  const ArchiveActions(this._ref);

  final Ref _ref;

  /// 归档，**返回撤销闭包**。
  ///
  /// 归档会把当时的 `status` 快照进 `statusBeforeArchive`，取消归档时还原
  /// （§1.1）—— 所以撤销就是取消归档，不需要界面层记住原状态。
  Future<VoidCallback> archive(String taskId) async {
    await _ref
        .read(taskCommandDispatcherProvider)
        .dispatch(ArchiveTaskCommand(taskId));
    return () => _ref
        .read(taskCommandDispatcherProvider)
        .dispatch(UnarchiveTaskCommand(taskId));
  }

  Future<void> unarchive(String taskId) => _ref
      .read(taskCommandDispatcherProvider)
      .dispatch(UnarchiveTaskCommand(taskId));
}

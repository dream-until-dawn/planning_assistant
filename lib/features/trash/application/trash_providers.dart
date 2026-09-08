/// 回收站（FR-TASK-08、task-lifecycle §1.1）。
///
/// ## 为什么需要它
///
/// `DeleteTaskCommand` / `RestoreTaskCommand` 在领域层一直都在，也测过 ——
/// 而**界面上没有任何地方能删一条任务**，更没有地方能恢复。
/// 于是「删除进回收站，30 天内可恢复」这条需求（FR-TASK-08）
/// 一个字都没落地。又是「模型有旋钮、界面够不着」那一族。
///
/// 删除是**软删除**：写 `deletedAt` 墓碑，不物理删（§1.1）。
/// 物理清理由启动时的后台任务做（L-09），**那一步还没实现** ——
/// 所以现在的回收站是只进不出的，记在 roadmap 里。
library;

import 'package:flutter/widgets.dart' show VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../domain/commands/task_command.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/repositories/task_repository.dart';

/// 回收站里的任务，持续推送。
final trashedTasksProvider = StreamProvider<List<Task>>(
  (ref) =>
      ref.watch(taskRepositoryProvider).watchTasks(scope: TaskScope.trashed),
);

/// 删除与恢复。
final trashActionsProvider = Provider<TrashActions>(TrashActions.new);

final class TrashActions {
  const TrashActions(this._ref);

  final Ref _ref;

  /// 删除一条任务，**返回撤销闭包**。
  ///
  /// 与列表那几个动作同一个做法（§2.4）：撤销由动作本身给出，
  /// 不是界面层再算一遍。这里尤其要紧 —— 删除是最需要反悔的操作，
  /// 而「再点一次删除」不是撤销。
  Future<VoidCallback> delete(String taskId) async {
    await _ref
        .read(taskCommandDispatcherProvider)
        .dispatch(DeleteTaskCommand(taskId));
    return () => _ref
        .read(taskCommandDispatcherProvider)
        .dispatch(RestoreTaskCommand(taskId));
  }

  /// 从回收站恢复。
  Future<void> restore(String taskId) => _ref
      .read(taskCommandDispatcherProvider)
      .dispatch(RestoreTaskCommand(taskId));
}

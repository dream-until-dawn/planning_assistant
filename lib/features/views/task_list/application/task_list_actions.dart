/// 列表上的动作（view-specs §0.3：完成钮就地完成）。
///
/// 与 `task_list_providers.dart` 分开：那边是**读**，这边是**写**。
/// 写路径一律经命令（FR-AI-01），这里拿不到仓库。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app_providers.dart';
import '../../../../domain/commands/task_command.dart';
import '../../../../domain/value_objects/task_status.dart';

/// 切换一条任务的完成状态。
///
/// **取消完成回到 `pending`，不回到 `inProgress`。**
/// 「做了一半」是用户显式设的状态，不能由「取消勾选」推断出来 ——
/// 猜错的代价是把用户标注的进度悄悄改掉。
///
/// 状态机的合法性由领域层守着（`task-lifecycle.md`），
/// 这里只负责把意图翻译成一条命令。
final class ToggleTaskDone {
  const ToggleTaskDone(this._ref);

  final Ref _ref;

  Future<void> call({required String taskId, required bool isDone}) => _ref
      .read(taskCommandDispatcherProvider)
      .dispatch(
        ChangeTaskStatusCommand(
          taskId: taskId,
          status: isDone ? TaskStatus.pending : TaskStatus.done,
        ),
      );
}

final toggleTaskDoneProvider = Provider<ToggleTaskDone>(ToggleTaskDone.new);

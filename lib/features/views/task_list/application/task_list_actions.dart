/// 列表上的动作（view-specs §0.3：完成钮就地完成）。
///
/// 与 `task_list_providers.dart` 分开：那边是**读**，这边是**写**。
/// 写路径一律经命令（FR-AI-01），这里拿不到仓库。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app_providers.dart';
import '../../../../domain/commands/task_command.dart';
import '../../../../domain/entities/occurrence.dart';
import '../../../../domain/value_objects/task_status.dart';
import '../../shared/application/task_occurrence.dart';

/// 切换一行的完成状态。
///
/// **取消完成回到 `pending`，不回到 `inProgress`。**
/// 「做了一半」是用户显式设的状态，不能由「取消勾选」推断出来 ——
/// 猜错的代价是把用户标注的进度悄悄改掉。
///
/// ## 两条路，由这一行是不是「某一次」决定
///
/// 重复任务的 `tasks.status` **恒为 pending**，真实状态在
/// `occurrence_overrides`（data-model §4.3，领域不变量强制）。
/// 所以：
///
///  · 普通任务 → `ChangeTaskStatusCommand`；
///  · 某一次发生 → `SetOccurrenceStatusCommand`。
///
/// 走错的后果不是「状态没变」而是**抛异常**：拿前者去改重复任务，
/// 落库前会被不变量直接拒掉。补这条分支之前，列表里勾一条重复任务
/// 就是这个结果。
///
/// 状态机的合法性由领域层守着（`task-lifecycle.md`），
/// 这里只负责把意图翻译成一条命令。
final class ToggleTaskDone {
  const ToggleTaskDone(this._ref);

  final Ref _ref;

  Future<void> call(TaskOccurrence row) {
    final dispatcher = _ref.read(taskCommandDispatcherProvider);
    final isDone = row.status == TaskStatus.done;
    final key = row.key;

    if (key == null) {
      return dispatcher.dispatch(
        ChangeTaskStatusCommand(
          taskId: row.taskId,
          status: isDone ? TaskStatus.pending : TaskStatus.done,
        ),
      );
    }
    return dispatcher.dispatch(
      SetOccurrenceStatusCommand(
        taskId: row.taskId,
        occurrenceKey: key,
        // 取消完成时传 null = 删掉那条例外，回到跟随规则 ——
        // 而不是写一条 pending 的例外，理由见命令本身的注释。
        status: isDone ? null : OccurrenceStatus.done,
      ),
    );
  }
}

final toggleTaskDoneProvider = Provider<ToggleTaskDone>(ToggleTaskDone.new);

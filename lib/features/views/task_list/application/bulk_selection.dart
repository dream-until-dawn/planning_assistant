/// 多选与批量操作（view-specs §2.4「长按 → 进入多选模式」）。
///
/// ## 批量动作**复用**单行动作，不另写一套
///
/// 「完成一行」这件事在重复任务上不是改 `tasks.status`，而是写一条
/// 例外（`ToggleTaskDone` 里那一段）；「删一行」是软删整条任务。
/// 批量若自己再判一遍「这行是某一次还是整条」，两处迟早分叉 ——
/// 而分叉的表现是「单个勾完成好好的，批量勾完成把整条重复任务标完成了」。
///
/// 所以这里只做三件事：把选中的 id 还原成行、逐行调既有动作、
/// 把它们各自给出的撤销闭包**攒成一条**。
///
/// ## 「在不在多选模式」不另存一个开关
///
/// 模式 = 选中集合非空。多一个 `bool isSelecting` 的话，
/// 「模式开着但一个都没选」是个能表达、却没人想清楚该长什么样的状态，
/// 而它一定会出现（用户把最后一个取消掉）。
/// 取消最后一个就退出模式 —— 这也是绝大多数应用的行为。
library;

import 'package:flutter/widgets.dart' show VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../trash/application/trash_providers.dart';
import '../../shared/application/task_occurrence.dart';
import 'task_list_actions.dart';
import 'task_list_providers.dart';

/// 选中的**行 id**（不是 taskId）。
///
/// 一条重复规则展开出的几行共用一个 taskId —— 存 taskId 的话，
/// 选中「本周三」会把「下周三」也选上，而用户只点了一行。
final selectionProvider = NotifierProvider<SelectionNotifier, Set<String>>(
  SelectionNotifier.new,
);

final class SelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  bool contains(String rowId) => state.contains(rowId);

  void toggle(String rowId) {
    final next = state.toSet();
    if (!next.remove(rowId)) next.add(rowId);
    state = next;
  }

  void clear() => state = const {};
}

/// 批量动作。返回的闭包能把整批**一起**撤回。
final bulkActionsProvider = Provider<BulkActions>(BulkActions.new);

final class BulkActions {
  const BulkActions(this._ref);

  final Ref _ref;

  /// 选中的那些行，**按列表当前的顺序**。
  ///
  /// 从 id 现查而不是把行本身存进选中集合：行会随库变化重建
  /// （改个标题、勾个完成），存下来的那份一会儿就是旧的，
  /// 而批量动作用旧行算出来的撤销会撤到一个不存在的状态去。
  List<TaskOccurrence> selectedRows() {
    final ids = _ref.read(selectionProvider);
    return [
      for (final row in _ref.read(filteredTasksProvider))
        if (ids.contains(row.id)) row,
    ];
  }

  /// 批量完成 / 取消完成。
  ///
  /// 逐行调 `ToggleTaskDone` —— 它是**切换**，所以一批里既有已完成
  /// 也有未完成时，各自翻转。这与「全部标成完成」不是一回事，
  /// 而切换是单行那条路已经确立的语义，两处不该不一样。
  Future<VoidCallback> toggleDone() async {
    final toggle = _ref.read(toggleTaskDoneProvider);
    final undos = <VoidCallback>[];
    for (final row in selectedRows()) {
      undos.add(await toggle(row));
    }
    _ref.read(selectionProvider.notifier).clear();
    return () {
      for (final undo in undos) {
        undo();
      }
    };
  }

  /// 批量删除（软删，进回收站）。
  Future<VoidCallback> delete() async {
    final trash = _ref.read(trashActionsProvider);
    final undos = <VoidCallback>[];
    // **不按 taskId 去重。**
    //
    // 一条逾期的重复任务在列表上有两行（逾期的那次 + 下一次），
    // 两行都选中就会对同一条任务发两次删除。看起来该去重，
    // 而 `softDeleteTask` 里那句 `if (task.isDeleted) return` 已经挡住了 ——
    // 第二次连写都不写，同步信封的 revision 也不涨。
    //
    // 我一开始写了去重，变异演练里把它拿掉**测试全绿**（B-05）：
    // 补了「revision 只涨一格」的断言之后**还是绿**，
    // 那就说明它不是没测到，是这段代码本来就多余（§1.16）。
    for (final row in selectedRows()) {
      undos.add(await trash.delete(row.taskId));
    }
    _ref.read(selectionProvider.notifier).clear();
    return () {
      for (final undo in undos) {
        undo();
      }
    };
  }
}

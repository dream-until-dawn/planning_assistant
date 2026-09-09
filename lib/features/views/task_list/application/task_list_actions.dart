/// 列表上的动作（view-specs §0.3：完成钮就地完成）。
///
/// 与 `task_list_providers.dart` 分开：那边是**读**，这边是**写**。
/// 写路径一律经命令（FR-AI-01），这里拿不到仓库。
library;

import 'package:flutter/widgets.dart';
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

  /// 切换，并返回一个能**原样撤回**它的闭包。
  ///
  /// 撤销**不能是「再调一次 call」**：闭包捕获的 `row` 是滑动那一刻的
  /// 快照，它的状态还是切换**之前**的值 —— 再切一次等于又切回去，
  /// 于是「撤销」把刚完成的又标成完成。滑动那条用例第一次就是这么红的。
  ///
  /// 所以这里把「切换到哪个状态」和「撤回到哪个状态」两条都算清楚，
  /// 各自发一条命令。
  Future<VoidCallback> call(TaskOccurrence row) async {
    final dispatcher = _ref.read(taskCommandDispatcherProvider);
    final isDone = row.status == TaskStatus.done;
    final key = row.key;

    if (key == null) {
      final to = isDone ? TaskStatus.pending : TaskStatus.done;
      final back = isDone ? TaskStatus.done : TaskStatus.pending;
      await dispatcher.dispatch(
        ChangeTaskStatusCommand(taskId: row.taskId, status: to),
      );
      return () => dispatcher.dispatch(
        ChangeTaskStatusCommand(taskId: row.taskId, status: back),
      );
    }

    // 取消完成时传 null = 删掉那条例外，回到跟随规则 ——
    // 而不是写一条 pending 的例外，理由见命令本身的注释。
    final to = isDone ? null : OccurrenceStatus.done;
    final back = isDone ? OccurrenceStatus.done : null;
    await dispatcher.dispatch(
      SetOccurrenceStatusCommand(
        taskId: row.taskId,
        occurrenceKey: key,
        status: to,
      ),
    );
    return () => dispatcher.dispatch(
      SetOccurrenceStatusCommand(
        taskId: row.taskId,
        occurrenceKey: key,
        status: back,
      ),
    );
  }
}

final toggleTaskDoneProvider = Provider<ToggleTaskDone>(ToggleTaskDone.new);

/// 单次发生的操作（FR-TASK-05）。
final class OccurrenceActions {
  const OccurrenceActions(this._ref);

  final Ref _ref;

  /// 勾/取消一个阶段（FR-TASK-07）。
  ///
  /// ## 两条路，由这一行是不是「某一次」决定
  ///
  /// 与 [ToggleTaskDone] 同一个岔口，理由也同一条：重复任务每一次的
  /// 阶段状态在 `stage_occurrence_states`，不重复的存在 `Stage.status`
  /// 上（判据见 `stageStatusFor`）。走错不是「没反应」，是把状态写到
  /// 读的时候不看的那一半去 —— 勾了没变，再勾还是没变。
  ///
  /// ## 不重复那条路一度是空的
  ///
  /// 这里原本 `if (key == null) return;` 就完了，注释写着「不重复的
  /// 任务不走这里」。可它们的阶段也得能勾 —— 而唯一的入口是
  /// **进编辑页、勾、保存**三步。时间轴把阶段摆成了独立的卡片，
  /// 那张卡上的勾选框对一半的任务点了没反应，才把这条空路照出来。
  ///
  /// 走 [ReplaceStagesCommand] 整表替换：单个阶段的状态没有专门的
  /// 命令，而为它新加一条要连着写入侧、同步侧、导入导出一起改。
  /// 整表替换是编辑器保存时走的同一条路，已经验过了。
  Future<void> setStageDone(TaskOccurrence row, String stageId, bool done) {
    final status = done ? TaskStatus.done : TaskStatus.pending;
    final key = row.key;
    final dispatcher = _ref.read(taskCommandDispatcherProvider);

    if (key == null) {
      // 手里没有这条任务的阶段（调用方没喂）就什么也别做 ——
      // 拿一份空表去整表替换，会把它所有阶段都打上墓碑。
      if (row.stages.isEmpty) return Future<void>.value();
      return dispatcher.dispatch(
        ReplaceStagesCommand(
          taskId: row.taskId,
          stages: [
            for (final s in row.stages)
              StageSpec(
                id: s.id,
                title: s.title,
                orderIndex: s.orderIndex,
                startOffsetMinutes: s.startOffsetMinutes,
                durationMinutes: s.durationMinutes,
                colorArgb: s.colorArgb,
                // 别的阶段维持原状 —— 但**问行，不问阶段**：
                // `row.stageStatus` 才是「这一行的这一步做完没有」的
                // 唯一入口，直接读 `s.status` 有一条架构守卫盯着。
                // 走到这个分支时两者相等，而相等是 `stageStatusFor`
                // 的结论，不该在这里再假设一遍。
                status: s.id == stageId ? status : row.stageStatus(s),
              ),
          ],
        ),
      );
    }

    return dispatcher.dispatch(
      SetStageOccurrenceStatusCommand(
        taskId: row.taskId,
        stageId: stageId,
        occurrenceKey: key,
        status: status,
      ),
    );
  }

  /// 跳过这一次。**只对某一次有意义** —— 不重复的任务没有「某一次」，
  /// 调它是调用方的错，所以直接返回而不是造一条指向空 key 的例外。
  Future<void> skip(TaskOccurrence row) {
    final key = row.key;
    if (key == null) return Future<void>.value();
    return _ref
        .read(taskCommandDispatcherProvider)
        .dispatch(
          SkipOccurrenceCommand(taskId: row.taskId, occurrenceKey: key),
        );
  }

  /// 撤回跳过：把整条例外删掉，回到跟随规则。
  ///
  /// 不是「把 action 改回 modify」—— 那会留下一条什么也没改的例外，
  /// 让「这一次动过没有」多出一种说不清的中间态。
  Future<void> unskip(TaskOccurrence row) {
    final key = row.key;
    if (key == null) return Future<void>.value();
    return _ref
        .read(taskCommandDispatcherProvider)
        .dispatch(
          SetOccurrenceStatusCommand(
            taskId: row.taskId,
            occurrenceKey: key,
            status: null,
          ),
        );
  }
}

final occurrenceActionsProvider = Provider<OccurrenceActions>(
  OccurrenceActions.new,
);

/// 推迟一行（view-specs §2.4：左滑默认「推迟到明天」）。
///
/// ## 两条路，与完成钮同一个分岔
///
///  · 普通任务 → 改它自己的 `planDate`；
///  · 某一次发生 → 写一条把这次挪走的例外，**其余次不动**。
///
/// 走错的后果不是「没反应」：拿前者去改重复任务，改的是整条规则的
/// DTSTART —— 推迟一次等于把往后每一次都挪了。
final class PostponeRow {
  const PostponeRow(this._ref);

  final Ref _ref;

  /// 推迟到 [days] 天后（默认明天）。返回一个能撤回它的闭包，
  /// 给撤销 Snackbar 用。
  ///
  /// **返回撤销闭包而不是让调用方自己记**：撤销要还原到「原来那天」，
  /// 而那个值只有这里知道 —— 让界面层再算一遍，迟早算成
  /// 「今天减一天」而不是「原来那天」。
  Future<VoidCallback?> call(TaskOccurrence row, {int days = 1}) async {
    final from = row.planDate;
    if (from == null) return null; // 没日期就谈不上推迟
    final to = from.addDays(days);
    final dispatcher = _ref.read(taskCommandDispatcherProvider);
    final key = row.key;

    if (key == null) {
      await dispatcher.dispatch(
        UpdateTaskFieldsCommand(taskId: row.taskId, planDate: to),
      );
      return () => dispatcher.dispatch(
        UpdateTaskFieldsCommand(taskId: row.taskId, planDate: from),
      );
    }

    await dispatcher.dispatch(
      MoveOccurrenceCommand(
        taskId: row.taskId,
        occurrenceKey: key,
        planDate: to,
      ),
    );
    // 撤销 = 挪回原处。**不是删掉整条例外** —— 那一次可能本来就
    // 改过标题或状态，删掉会把那些一起抹了。
    return () => dispatcher.dispatch(
      MoveOccurrenceCommand(
        taskId: row.taskId,
        occurrenceKey: key,
        planDate: from,
      ),
    );
  }
}

final postponeRowProvider = Provider<PostponeRow>(PostponeRow.new);

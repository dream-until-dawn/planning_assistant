/// 单项 ⇄ 重复切换时，阶段完成状态的迁移（FR-TASK-07、data-model §3.2）。
///
/// ## 为什么这件事必须显式迁移
///
/// 阶段状态有两个存储位置（判据见 `stageStatusFor`）：
///
/// | 任务 | 状态存在哪 |
/// |---|---|
/// | 不重复 | `Stage.status` |
/// | 重复 | `stage_occurrence_states` |
///
/// 于是**改重复规则会改变「该读哪一份」**。单项 → 重复不迁的话，
/// 用户勾过的阶段进度**当场从界面上消失** —— 读路径改看那张表，
/// 而表里什么都没有；同时 `Stage.status` 变成一个没人读的死数据。
///
/// 数据一条都没丢（行还在库里），但用户看到的是「我做完的东西没了」。
/// 这一类「没丢但看不见」比真丢更难查：没有任何报错。
///
/// **反方向刻意不做**，理由在下面单独一节 —— 那不是漏了一半。
///
/// ## 这与 R-27 是同一个模式
///
/// `all_day_conversion.dart` 处理的是「`isAllDay` 变了，
/// `occurrenceKey` 的形态跟着变」。这里是「重复规则变了，
/// 阶段状态该读哪一份跟着变」。两者都是**身份改变，所以显式迁移**，
/// 而不是让读路径去猜。
///
/// ## 迁到哪一次
///
/// 迁到**第一次发生**（任务自己的开始时刻那一次）。
/// 单项任务只有一次发生，它的完成记录本来说的就是那一次 ——
/// 所以这不是「挑一个放」，是把它放回它本来的位置。
///
/// ## 反方向（重复 → 单项）不在这里做，在草稿层做
///
/// **我一度以为它不该做，那个判断有一半是错的。**
///
/// 当时给的第一个理由是「语义上没有唯一答案 —— 用户可能在五次发生上
/// 各完成了不同的阶段，挑『第一次』是替他做决定」。
/// 这条**站不住**：关掉重复之后这条任务只剩一次发生，
/// 而那一次就是它自己的开始时刻 —— 与正方向迁到「第一次」是同一个
/// 身份。不是挑一个放，是放回它本来的位置。
///
/// 第二个理由是对的，而且决定了做在哪儿：一次保存里
/// `ReplaceStagesCommand` 排在后面，会把这里写好的状态原样盖掉。
///
/// 所以反方向搬在**编辑器的草稿层**（`setRecurrence` 里）。
/// 那比命令层还好一点：勾选框当场就带着正确的状态出现，
/// 用户在保存**之前**就看见了。
library;

import '../entities/occurrence.dart';
import '../entities/occurrence_override.dart';
import '../entities/stage.dart';
import '../entities/stage_occurrence_state.dart';
import '../entities/task.dart';
import '../value_objects/occurrence_key.dart';
import '../value_objects/task_status.dart';

/// 一次切换要写回的东西。四张表都可能变，所以一起给。
typedef RecurrenceConversion = ({
  Task task,
  List<Stage> stages,
  List<StageOccurrenceState> states,
  List<OccurrenceOverride> overrides,
});

/// 算出切换后要写的阶段与状态；不需要迁移时返回 null。
///
/// [was] 是**改之前**这条任务重不重复，[updated] 是改之后的任务。
RecurrenceConversion? convertRecurrenceMode(
  Task updated, {
  required bool was,
  required List<Stage> stages,
  required List<StageOccurrenceState> states,
}) {
  final now = updated.isRecurring;
  if (was == now) return null;

  // 没有开始时刻就没有「第一次」可指。重复任务必须有日期
  // （`needsDateForRecurrence`），所以这一支实际到不了 ——
  // 但它是**导入/同步也走得到**的路径，不能靠界面的约束兜底。
  final start = updated.startWallTime;
  if (start == null) return null;
  final first = OccurrenceKey.fromWallTime(start, isAllDay: updated.isAllDay);

  if (now) {
    // 单项 → 重复：把阶段自己的状态搬到「第一次」上，阶段归零。
    //
    // **任务自己的状态也要搬**，理由一模一样：重复任务的
    // `tasks.status` 恒为 pending（data-model §4.3），真实状态落在
    // `occurrence_overrides`。不搬的话 `checkInvariants` 当场拦下 ——
    // 一条做了一半（或已完成）的任务**根本改不成重复**，
    // 而用户看到的只是「保存没反应」。
    //
    // 这条一直是漏的：以前只有显式标完成才可能让它非 pending，
    // 而那条路上没人会顺手改成重复。阶段状态开始反推父任务状态之后
    // （§4.1），勾一个阶段就够了，于是它天天都撞得上。
    //
    // **只搬非 pending 的**：给每个阶段都造一行 pending 的状态，
    // 等于把「还没动过」也落成数据 —— 那张表的约定是
    // 「只有被交互过的 (阶段, 发生) 才落行」（data-model §3.5）。
    // 任务状态那条例外同理，pending 就不落行。
    final moved = updated.status != TaskStatus.pending;
    final states = [
      for (final s in stages)
        if (s.status != TaskStatus.pending)
          StageOccurrenceState(
            id: StageOccurrenceState.idFor(s.id, first),
            taskId: updated.id,
            stageId: s.id,
            occurrenceKey: first,
            status: s.status,
            completedAt: s.completedAt,
          ),
    ];

    // 一条都没搬就当没这回事：调用方会走普通的 `saveTask`，
    // 少开一个事务，也少写一批一模一样的行。
    // **判据是「结果里有没有东西」，不是「有没有阶段」**——
    // 一条没有阶段但已完成的任务照样要搬。
    if (!moved && states.isEmpty) return null;

    return (
      task: moved
          ? updated.copyWith(status: TaskStatus.pending, completedAt: null)
          : updated,
      overrides: [
        if (moved)
          OccurrenceOverride(
            taskId: updated.id,
            key: first,
            action: OverrideAction.modify,
            status: OccurrenceStatus.fromWireName(updated.status.wireName),
          ),
      ],
      stages: [
        for (final s in stages)
          if (s.status == TaskStatus.pending)
            s
          else
            s.copyWith(status: TaskStatus.pending, completedAt: null),
      ],
      states: states,
    );
  }

  // 重复 → 单项：**不迁**，理由见文件头「反方向为什么不做」。
  return null;
}

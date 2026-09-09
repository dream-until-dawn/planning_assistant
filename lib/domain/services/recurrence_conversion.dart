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
/// ## 反方向（重复 → 单项）为什么不做
///
/// **两个理由，第二个才是主要的。**
///
/// 一、语义上没有唯一答案。用户可能在五次发生上各完成了不同的阶段，
/// 现在只剩一次 —— 挑「第一次」是**替他做决定**，
/// 与 R-27 撞车那里拒绝「留一条丢一条」是同一条理由。
/// 而「一次都不继承」是诚实的：那些行还在库里，没有被毁，
/// 只是这条任务现在不看它们了。
///
/// 二、就算想做，这个位置也做不成。一次保存里
/// `UpdateTaskFieldsCommand` 与 `ReplaceStagesCommand` **都会写阶段**，
/// 后者带着编辑器那份草稿（重复任务的草稿里阶段状态恒为 pending，
/// 因为界面上根本不给勾）。在前者里写好的状态会被后者原样盖掉。
/// 真要做，得照 R-27 的样子做成**一条显式的转换命令**、
/// 排在写阶段之后 —— 那是另一件事，记在 roadmap 里。
///
/// 写在这里是因为：一个只处理单向的函数看起来像漏了一半，
/// 而它是**想清楚之后只做一半**。
library;

import '../entities/stage.dart';
import '../entities/stage_occurrence_state.dart';
import '../entities/task.dart';
import '../value_objects/occurrence_key.dart';
import '../value_objects/task_status.dart';

/// 一次切换要写回的东西。两张表都可能变，所以一起给。
typedef RecurrenceConversion = ({
  List<Stage> stages,
  List<StageOccurrenceState> states,
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
  if (was == now || stages.isEmpty) return null;

  // 没有开始时刻就没有「第一次」可指。重复任务必须有日期
  // （`needsDateForRecurrence`），所以这一支实际到不了 ——
  // 但它是**导入/同步也走得到**的路径，不能靠界面的约束兜底。
  final start = updated.startWallTime;
  if (start == null) return null;
  final first = OccurrenceKey.fromWallTime(start, isAllDay: updated.isAllDay);

  if (now) {
    // 单项 → 重复：把阶段自己的状态搬到「第一次」上，阶段归零。
    //
    // **只搬非 pending 的**：给每个阶段都造一行 pending 的状态，
    // 等于把「还没动过」也落成数据 —— 那张表的约定是
    // 「只有被交互过的 (阶段, 发生) 才落行」（data-model §3.5）。
    return (
      stages: [
        for (final s in stages)
          if (s.status == TaskStatus.pending)
            s
          else
            s.copyWith(status: TaskStatus.pending, completedAt: null),
      ],
      states: [
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
      ],
    );
  }

  // 重复 → 单项：**不迁**，理由见文件头「反方向为什么不做」。
  return null;
}

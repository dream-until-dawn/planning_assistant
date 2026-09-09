/// 「这一次的这个阶段，到底做完没有」（FR-TASK-07）。
///
/// **纯函数**，不碰库。阶段状态有两个来源：
///
/// | 任务 | 状态存在哪 | 为什么 |
/// |---|---|---|
/// | 不重复 | `Stage.status` | 只有一次发生，另开一张表是多余的间接层 |
/// | 重复 | `StageOccurrenceState` | 每次发生各记一份（否则勾一次全部变完成） |
///
/// 这条分岔**只写一处**。视图、进度、甘特都要问同一个问题，
/// 各自写一遍 `if (task.isRecurring)` 的话，
/// 迟早出现「列表说做完了、甘特说没有」。
library;

import '../entities/stage.dart';
import '../entities/stage_occurrence_state.dart';
import '../value_objects/occurrence_key.dart';
import '../value_objects/task_status.dart';

/// 按 (stageId) 索引的、**某一次**的状态。
typedef StageStatesOfOccurrence = Map<String, StageOccurrenceState>;

/// 把一条任务的全部状态按发生分桶。
///
/// 库里是一张平表（taskId + stageId + occurrenceKey），
/// 而视图每次只关心一个 occurrenceKey。
Map<OccurrenceKey, StageStatesOfOccurrence> groupByOccurrence(
  Iterable<StageOccurrenceState> states,
) {
  final out = <OccurrenceKey, StageStatesOfOccurrence>{};
  for (final s in states) {
    if (s.deletedAt != null) continue;
    (out[s.occurrenceKey] ??= {})[s.stageId] = s;
  }
  return out;
}

/// 这一次里这个阶段的状态。
///
/// [occurrenceStates] 为 null 表示「这条任务不重复」—— 那时看阶段自己。
/// 非 null 但查不到，说明这一次还没被动过：**回落到 pending**，
/// 而**不是** `stage.status`。
///
/// 这条回落是整件事的关键。回落到 `stage.status` 的话，
/// 一条重复任务在编辑器里被标过完成的阶段，会让**每一次**都显示成已完成 ——
/// 正是要修的那个毛病换个地方又长出来。
TaskStatus stageStatusFor(
  Stage stage, {
  required StageStatesOfOccurrence? occurrenceStates,
}) {
  if (occurrenceStates == null) return stage.status;
  return occurrenceStates[stage.id]?.status ?? TaskStatus.pending;
}

/// 这一次的进度：已完成阶段数 / 总数（FR-TASK-02 的验收算式）。
///
/// 没有阶段时返回 null —— 「没有阶段」与「一个都没做」是两回事
/// （view-specs §4.3.1 那条）。
({int done, int total})? stageProgressFor(
  List<Stage> stages, {
  required StageStatesOfOccurrence? occurrenceStates,
}) {
  if (stages.isEmpty) return null;
  var done = 0;
  for (final stage in stages) {
    if (stageStatusFor(stage, occurrenceStates: occurrenceStates) ==
        TaskStatus.done) {
      done++;
    }
  }
  return (done: done, total: stages.length);
}

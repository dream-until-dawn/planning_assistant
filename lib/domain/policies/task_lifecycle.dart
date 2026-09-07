/// 任务生命周期的全部状态变更（task-lifecycle §2、§4、§5）。
///
/// **纯函数**：输入实体 + 时刻，输出新实体。不碰数据库、不读系统时钟。
/// 时刻由调用方传入 —— 用 `DateTime.now()` 的话，涉及 `completedAt` 的
/// 断言只能写成范围判断，而范围断言在「压根没设置」时照样通过。
library;

import '../entities/stage.dart';
import '../entities/task.dart';
import '../value_objects/task_status.dart';

/// 阶段推导时的行为配置（settings-spec）。
///
/// 只带这一个开关是刻意的：它只控制**「部分完成 → inProgress」这一条**
/// （task-lifecycle §4.1），其余三行推导无条件生效。
/// 初版把 §4 写成「无条件推导」而配置规格又提供了开关，两处矛盾，此处收口。
typedef StageDerivationConfig = ({bool autoStartOnFirstStage});

const StageDerivationConfig kDefaultDerivationConfig = (
  autoStartOnFirstStage: true,
);

/// 三个可见性谓词（task-lifecycle §1.1）。
///
/// **实现为一处，不各自手写** —— 视图一多，手写的过滤条件必然出现
/// 「回收站里混进归档任务」这类分叉。
abstract final class TaskVisibility {
  /// 活跃：未删除且未归档。
  static bool isActive(Task t) => !t.isDeleted && !t.isArchived;

  /// 归档列表：未删除且已归档。
  static bool isArchived(Task t) => !t.isDeleted && t.isArchived;

  /// 回收站：已删除（无论是否归档过）。
  static bool isInTrash(Task t) => t.isDeleted;

  /// 三个谓词恰好命中一个 —— 用于守卫「互斥且完备」。
  static int matchedBucketCount(Task t) =>
      (isActive(t) ? 1 : 0) + (isArchived(t) ? 1 : 0) + (isInTrash(t) ? 1 : 0);
}

/// 改变任务状态。
///
/// 会拒绝三类操作，全部**显式抛异常**：
///  · 非法迁移（§2.1 的表）；
///  · 归档态下改状态（§2.2）—— 否则 `statusBeforeArchive` 与现实脱节；
///  · 改重复任务的状态（§3）—— 它恒为 `pending`。
Task applyStatusChange(Task task, TaskStatus to, {required DateTime now}) {
  if (task.isArchived) {
    throw IllegalTransitionException(task.status, to, '任务已归档，改状态前必须先取消归档');
  }
  if (task.isRecurring) {
    throw DomainInvariantViolation(
      '重复任务 ${task.id} 的 status 恒为 pending；'
      '要改「某一次」的状态请写 occurrence_overrides（data-model §4.3）',
    );
  }
  requireTransitionAllowed(task.status, to);

  // completedAt 与 status 必须同进同退，否则 checkInvariants 会拦下。
  return task.copyWith(
    status: to,
    completedAt: to == TaskStatus.done ? (task.completedAt ?? now) : null,
  )..checkInvariants();
}

/// 归档。任何状态下都允许，包括重复任务（§2.2）。
Task archive(Task task, {required DateTime now}) {
  if (task.isArchived) return task;
  return task.copyWith(archivedAt: now, statusBeforeArchive: task.status)
    ..checkInvariants();
}

/// 取消归档：还原归档前的状态。
///
/// **不是一律回 `pending`**（用例 L-02）：归档一个进行中的任务再取消，
/// 用户期望它还是进行中。
Task unarchive(Task task) {
  if (!task.isArchived) return task;
  return task.copyWith(
    archivedAt: null,
    status: task.statusBeforeArchive ?? TaskStatus.pending,
    statusBeforeArchive: null,
  )..checkInvariants();
}

/// 由阶段状态推导父任务状态（§4）。
///
/// 无阶段时返回 null —— 由调用方决定保留原状态，而不是在这里替它决定。
TaskStatus? deriveStatusFromStages(
  List<Stage> stages, {
  StageDerivationConfig config = kDefaultDerivationConfig,
}) {
  if (stages.isEmpty) return null;

  final done = stages.where((s) => s.status == TaskStatus.done).length;
  final skipped = stages.where((s) => s.status == TaskStatus.skipped).length;
  final settled = done + skipped;

  // 顺序不能随便调：全 skipped 也满足「settled == length」，
  // 必须先分辨出「一个都没 done」这种情况。
  if (settled == stages.length) {
    return done > 0 ? TaskStatus.done : TaskStatus.skipped;
  }
  if (settled == 0) return TaskStatus.pending;

  // 唯一受配置影响的一行。关掉它父任务不自动变色，
  // 但 UI 照样显示阶段进度（2/5），所以不会丢信息。
  return config.autoStartOnFirstStage
      ? TaskStatus.inProgress
      : TaskStatus.pending;
}

/// 显式把父任务标完成：**所有未完成阶段一并标 done**（§4.2、用例 L-05）。
({Task task, List<Stage> stages}) completeTaskWithStages(
  Task task,
  List<Stage> stages, {
  required DateTime now,
}) {
  final updated = [
    for (final s in stages)
      s.status == TaskStatus.done
          ? s
          : s.copyWith(status: TaskStatus.done, completedAt: now),
  ];
  return (
    task: applyStatusChange(task, TaskStatus.done, now: now),
    stages: updated,
  );
}

/// 取消父任务完成：**阶段状态保持不变**（§4.2、用例 L-06）。
///
/// 这条不对称是刻意的 —— 破坏用户已记录的阶段进度，比留下「父任务未完成
/// 但阶段全完成」这种不一致更糟。UI 显示为「部分完成」。
///
/// 将来若有人「顺手统一一下」把它改成回滚阶段，L-06 会变红。
({Task task, List<Stage> stages}) uncompleteTaskKeepingStages(
  Task task,
  List<Stage> stages, {
  required DateTime now,
}) {
  return (
    task: applyStatusChange(task, TaskStatus.pending, now: now),
    stages: stages,
  );
}

/// 删除父任务：子实体**一并打墓碑，不物理级联删**（§6、用例 L-07）。
///
/// 物理删子实体的话，恢复时子数据就没了 —— 而回收站承诺的是「可恢复」。
({Task task, List<Stage> stages}) softDeleteTaskCascade(
  Task task,
  List<Stage> stages, {
  required DateTime now,
}) {
  return (
    task: task.copyWith(deletedAt: now),
    stages: [
      for (final s in stages)
        s.deletedAt == null ? s.copyWith(deletedAt: now) : s,
    ],
  );
}

/// 从回收站恢复：子实体一并恢复（用例 L-08）。
///
/// 只恢复**与父任务同时被删**的子实体。在删父任务之前就单独删掉的阶段，
/// 恢复父任务时不该跟着复活 —— 那是用户的另一次决定。
({Task task, List<Stage> stages}) restoreTaskCascade(
  Task task,
  List<Stage> stages,
) {
  final deletedAt = task.deletedAt;
  return (
    task: task.copyWith(deletedAt: null),
    stages: [
      for (final s in stages)
        s.deletedAt == deletedAt ? s.copyWith(deletedAt: null) : s,
    ],
  );
}

/// 是否已过回收站保留期，可以物理清理（§6、用例 L-09）。
///
/// **边界日不清**：恰好到期的那天仍然保留。用 `>` 而不是 `>=` ——
/// 差这一天的后果是用户在最后一天打开回收站发现东西已经没了。
bool isPurgeable(
  Task task, {
  required DateTime now,
  required int retentionDays,
}) {
  final deletedAt = task.deletedAt;
  if (deletedAt == null) return false;
  return now.difference(deletedAt) > Duration(days: retentionDays);
}

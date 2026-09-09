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
}) => deriveStatusFromStageStatuses([
  for (final s in stages) s.status,
], config: config);

/// 同一条推导，但只吃**一串状态**。
///
/// 拆出来是因为阶段状态有两个存储位置（判据见 `stageStatusFor`）：
/// 不重复的在 `Stage.status`，重复的在 `StageOccurrenceState`。
/// 两边都要把「阶段 → 父」这一步算一遍，而各算各的话，
/// 迟早出现「不重复的任务全勾完变已完成、重复的那次不变」。
///
/// 判据只此一份，两边各自负责把状态取出来。
TaskStatus? deriveStatusFromStageStatuses(
  List<TaskStatus> statuses, {
  StageDerivationConfig config = kDefaultDerivationConfig,
}) {
  if (statuses.isEmpty) return null;

  final done = statuses.where((s) => s == TaskStatus.done).length;
  final skipped = statuses.where((s) => s == TaskStatus.skipped).length;
  final settled = done + skipped;

  // 顺序不能随便调：全 skipped 也满足「settled == length」，
  // 必须先分辨出「一个都没 done」这种情况。
  if (settled == statuses.length) {
    return done > 0 ? TaskStatus.done : TaskStatus.skipped;
  }
  if (settled == 0) return TaskStatus.pending;

  // 唯一受配置影响的一行。关掉它父任务不自动变色，
  // 但 UI 照样显示阶段进度（2/5），所以不会丢信息。
  return config.autoStartOnFirstStage
      ? TaskStatus.inProgress
      : TaskStatus.pending;
}

/// 把阶段状态**投影**到父任务上（§4.1）。
///
/// 与 [applyStatusChange] 的区别是**不查迁移表**。迁移表约束的是
/// 「用户能直接按哪一下」—— `done → skipped` 被禁掉，是因为直接按出这一步
/// 多半是误操作。而这里的值不是用户选的，是阶段算出来的：把最后一个 done
/// 的阶段改成「跳过」之后，父任务除了 skipped 没有别的值可取。
/// 那时候抛异常，用户看到的是「这个阶段改不动」——
/// 一条给误操作用的护栏，挡住了一次完全正当的操作。
///
/// 三种情况原样返回：
///  · **没有阶段** —— 推导给不出值，父任务的状态本来就是用户自己设的；
///  · **重复任务** —— `status` 恒为 pending，真实状态按每一次存（§4.3）；
///  · **已归档** —— 归档期间状态冻结（§2.2）。这时跟着阶段改的话，
///    「取消归档还原成什么」会被悄悄改掉。
Task projectStagesOntoTask(
  Task task,
  List<Stage> stages, {
  required DateTime now,
  StageDerivationConfig config = kDefaultDerivationConfig,
}) {
  if (task.isRecurring || task.isArchived) return task;
  // 墓碑不算数：整表替换回来的列表里带着刚被删掉的阶段，
  // 把它们算进去，删掉一个未完成的阶段不会让任务变完成。
  final alive = [
    for (final s in stages)
      if (s.deletedAt == null) s,
  ];
  final derived = deriveStatusFromStages(alive, config: config);
  if (derived == null || derived == task.status) return task;
  return task.copyWith(
    status: derived,
    // **完成时刻取「最后一步做完的那一刻」，不是「算这一下的那一刻」。**
    //
    // 语义上它就是对的：整件事完成于最后一步完成的时候。
    // 而它还兼着一件事 —— [uncompleteTaskWithStages] 靠
    // 「完成时刻与任务相同」认出「让这条任务变成已完成的那一批阶段」。
    // 这里若写 `now`，那一批在钉死的时钟下与别的阶段无从分辨，
    // 在会走的时钟下又可能差几毫秒而一个都认不出来。取 max 之后，
    // 「最后那一批」在两种时钟下都是确定的。
    completedAt: derived == TaskStatus.done
        ? (_latestCompletion(alive) ?? now)
        : null,
  )..checkInvariants();
}

/// 一组阶段里最晚的完成时刻；一个都没完成时 null。
DateTime? _latestCompletion(List<Stage> stages) {
  DateTime? latest;
  for (final s in stages) {
    final at = s.completedAt;
    if (at == null) continue;
    if (latest == null || at.isAfter(latest)) latest = at;
  }
  return latest;
}

/// 显式把父任务标完成：**所有待办阶段一并标 done**（§4.2、用例 L-05）。
///
/// **`skipped` 的阶段不动。** 「跳过」是用户对那一步的明确判断
/// （这一步不做了），把它盖成 done 是在替他改结论。
/// 全 settled 且有 done 的组合推导出来照样是 done（[deriveStatusFromStages]），
/// 所以放着不动不会让父子状态对不上。
({Task task, List<Stage> stages}) completeTaskWithStages(
  Task task,
  List<Stage> stages, {
  required DateTime now,
}) {
  final updated = [
    for (final s in stages)
      s.status == TaskStatus.done || s.status == TaskStatus.skipped
          ? s
          : s.copyWith(status: TaskStatus.done, completedAt: now),
  ];
  return (
    task: applyStatusChange(task, TaskStatus.done, now: now),
    stages: updated,
  );
}

/// 取消父任务完成：**只收回「让它变成已完成的那一批」阶段**（§4.2、L-06）。
///
/// 判据是**完成时刻等于任务的完成时刻**。这不是靠时间戳猜，是同一次操作
/// 的两半：[completeTaskWithStages] 用同一个 `now` 写任务与它补上的阶段；
/// 逐个勾满时任务的完成时刻取自最后那一步（[projectStagesOntoTask]）。
/// 于是「最后那一批」在两种情形下都认得出来：
///
///  · 显式标完成 → 级联补上的全部；
///  · 逐个勾满 → 最后勾的那一个。
///
/// **之前就勾好的、跳过的，一律留着。** 任务的状态随后由剩下的阶段推出来
/// （所以取消一条 1/2 的任务会落在 `inProgress`，不是 `pending` ——
/// 那正是它当时的样子）。
///
/// ## 这条规则被推翻过两次，记下来省得再绕
///
/// **初版**：取消时不回滚任何阶段，理由「破坏用户已记录的阶段进度比留下
/// 不一致更糟」。它在「阶段全勾完推出 done」那种来法下会留下
/// 「存的是 pending、推出来是 done」的自相矛盾。
///
/// **第二版（我改的）**：回滚**所有** done 的阶段，论证是「那份进度在标完成
/// 的那一下就已经被盖掉了」。**对已经 done 的阶段这句是假的** ——
/// [completeTaskWithStages] 刻意跳过它们，一次都没碰过。于是
/// 「用户自己勾的第一步」被取消完成抹掉，正是初版那句话说的情形。
/// 而且它和同一个改动里对 `skipped` 的处理自相矛盾：
/// 「这一步跳过」保得住，「这一步做完了」保不住，两者都是用户亲手记的。
/// 评审跑出了那个序列。
///
/// 教训：发现旧规则的一个反例，不等于可以换上另一个有反例的规则。
({Task task, List<Stage> stages}) uncompleteTaskWithStages(
  Task task,
  List<Stage> stages, {
  required DateTime now,
  StageDerivationConfig config = kDefaultDerivationConfig,
}) {
  final at = task.completedAt;
  final updated = [
    for (final s in stages)
      s.status == TaskStatus.done && (at == null || s.completedAt == at)
          // 完成时刻缺失（不变量本不允许）时全收回：宁可多收，
          // 也不要留下一条「取消了却还是完成」的任务。
          ? s.copyWith(status: TaskStatus.pending, completedAt: null)
          : s,
  ];
  return (
    // 先落到 pending，再让推导按剩下的阶段说话。**不走
    // `applyStatusChange`**：推导出的值不查迁移表（见
    // [projectStagesOntoTask]），而这里正是一次推导。
    task: projectStagesOntoTask(
      task.copyWith(status: TaskStatus.pending, completedAt: null),
      updated,
      now: now,
      config: config,
    ),
    stages: updated,
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

/// 距离「可以被清掉」还有多久（§6、用例 L-09）。未删除的返回 null。
///
/// 已经过期的返回**负值** —— 清理发生在下次启动，所以「早就该清了」
/// 是一个真实存在的状态，不该压成 0。
///
/// ## 为什么这条要单独暴露出去
///
/// 回收站界面要写「还剩几天」。那句话若自己拿 `inDays` 算一遍，
/// 就与下面这条判据分了叉：删除 29 天 20 小时时它算出「还剩 1 天」，
/// 而清理判的是「差值 > 30 天」—— 今晚一过就真清了，
/// 用户看到的却是还有一天。差半天不算大事，但它是**同一个问题的
/// 两套答案**，而两套答案里迟早有一套会被改坏。
Duration? timeUntilPurge(
  Task task, {
  required DateTime now,
  required int retentionDays,
}) {
  final deletedAt = task.deletedAt;
  if (deletedAt == null) return null;
  return deletedAt.add(Duration(days: retentionDays)).difference(now);
}

/// 是否已过回收站保留期，可以物理清理（§6、用例 L-09）。
///
/// **边界日不清**：恰好到期的那一刻仍然保留 —— 剩余为 0 时 `isNegative`
/// 是 false。差这一天的后果是用户在最后一天打开回收站发现东西已经没了。
bool isPurgeable(
  Task task, {
  required DateTime now,
  required int retentionDays,
}) =>
    timeUntilPurge(task, now: now, retentionDays: retentionDays)?.isNegative ??
    false;

/// 命令分发器 —— 写路径上唯一执行变更的地方（overview §4）。
///
/// 只依赖 `TaskRepository` 抽象与领域策略纯函数，**不认识 Drift**。
/// 因此它既能跑在 App 里，也能被纯 Dart 测试直接驱动，
/// 将来 V3 云端下发的变更、V4 Agent 产出的命令走的都是这同一条路径。
library;

import '../../core/patch/unset.dart';
import '../../core/time/clock.dart';
import '../entities/stage.dart';
import '../entities/task.dart';
import '../policies/task_lifecycle.dart';
import '../repositories/task_repository.dart';
import '../value_objects/recurrence.dart';
import '../value_objects/task_status.dart';
import 'task_command.dart';

/// 命令引用了不存在的实体。
///
/// 与「未知命令类型」分开：那是协议问题，这是数据问题，
/// 上层对两者的处置完全不同（前者要升级客户端，后者要重新同步）。
final class EntityNotFoundException implements Exception {
  const EntityNotFoundException(this.entityType, this.id);
  final String entityType;
  final String id;

  @override
  String toString() => 'EntityNotFoundException: 找不到 $entityType「$id」';
}

/// 执行 [TaskCommand]。
final class CommandDispatcher {
  const CommandDispatcher(this._repo, this._clock);

  final TaskRepository _repo;

  /// 注入时钟。**不读系统时钟** —— 否则命令的效果不可复现，
  /// 回放一致性测试也就无从谈起。
  final Clock _clock;

  DateTime _now() => _clock.nowUtc();

  /// 分发一条命令。
  ///
  /// `switch` 对 sealed 类型穷尽检查：新增命令时这里会编译报错，
  /// 而不是运行时悄悄走进 default 分支什么也不做。
  Future<void> dispatch(TaskCommand command) async {
    switch (command) {
      case CreateTaskCommand():
        await _create(command);
      case UpdateTaskFieldsCommand():
        await _updateFields(command);
      case ChangeTaskStatusCommand():
        await _changeStatus(command);
      case ArchiveTaskCommand():
        await _repo.saveTask(
          archive(await _require(command.taskId), now: _now()),
        );
      case UnarchiveTaskCommand():
        await _repo.saveTask(unarchive(await _require(command.taskId)));
      case DeleteTaskCommand():
        await _repo.softDeleteTask(command.taskId);
      case RestoreTaskCommand():
        await _repo.restoreTask(command.taskId);
      case ReplaceStagesCommand():
        await _replaceStages(command);
      case CompleteTaskWithStagesCommand():
        await _completeWithStages(command);
    }
  }

  /// 按顺序执行一串命令。
  ///
  /// **不包在一个大事务里**：每条命令各自原子即可。整串原子会让
  /// 「导入 500 条任务，第 499 条有问题」变成全军覆没，
  /// 而用户更想要的是「其余都进来了，告诉我哪条不行」。
  Future<void> dispatchAll(Iterable<TaskCommand> commands) async {
    for (final c in commands) {
      await dispatch(c);
    }
  }

  Future<Task> _require(String id) async {
    final task = await _repo.findTaskById(id, scope: TaskScope.all);
    if (task == null) throw EntityNotFoundException('task', id);
    return task;
  }

  Future<void> _create(CreateTaskCommand c) async {
    final task = Task(
      id: c.taskId,
      title: c.title,
      kind: c.kind,
      timeZoneId: c.timeZoneId,
      note: c.note,
      categoryId: c.categoryId,
      priority: c.priority,
      isAllDay: c.isAllDay,
      planDate: c.planDate,
      startMinute: c.startMinute,
      endDate: c.endDate,
      endMinute: c.endMinute,
      // **在这里统一规范化**，不依赖各调用方自觉（recurrence-engine §7）。
      // 直接存外部原串的话，同一条规则会有多种写法进库，
      // 之后每处比较都要先归一。
      recurrence: c.recurrenceRule == null
          ? null
          : Recurrence.parse(c.recurrenceRule!),
      colorArgb: c.colorArgb,
      icon: c.icon,
      sortOrder: c.sortOrder,
    );
    await _repo.saveTask(task);
  }

  Future<void> _updateFields(UpdateTaskFieldsCommand c) async {
    final task = await _require(c.taskId);
    // 命令里的哨兵语义（不传 = 不改，显式 null = 清空）直接传给 copyWith，
    // 两边用的是同一套约定。
    await _repo.saveTask(
      task.copyWith(
        title: c.title,
        note: c.note,
        categoryId: c.categoryId,
        priority: c.priority,
        planDate: c.planDate,
        startMinute: c.startMinute,
        endDate: c.endDate,
        endMinute: c.endMinute,
        // 规则串在这里规范化。哨兵原样透传 —— 命令与实体共用同一个 [unset]，
        // 所以「不改」不需要在中间翻译一道。
        recurrence: identical(c.recurrenceRule, unset)
            ? unset
            : (c.recurrenceRule == null
                  ? null
                  : Recurrence.parse(c.recurrenceRule! as String)),
        colorArgb: c.colorArgb,
        icon: c.icon,
        sortOrder: c.sortOrder,
      ),
    );
  }

  Future<void> _changeStatus(ChangeTaskStatusCommand c) async {
    final task = await _require(c.taskId);
    final updated = applyStatusChange(task, c.status, now: _now());

    // 阶段任务标完成时必须连阶段一起处理，否则父子状态不一致。
    // 这里只处理「非完成」的迁移；完成走 CompleteTaskWithStagesCommand。
    await _repo.saveTask(updated);
  }

  Future<void> _replaceStages(ReplaceStagesCommand c) async {
    _requireStageCount(c.stages);
    _requireContiguousOrder(c.stages);

    final task = await _require(c.taskId);
    final existing = await _repo.findStagesOfTask(
      c.taskId,
      scope: TaskScope.all,
    );
    final incoming = {for (final s in c.stages) s.id};

    final stages = <Stage>[
      for (final s in c.stages)
        Stage(
          id: s.id,
          taskId: c.taskId,
          title: s.title,
          orderIndex: s.orderIndex,
          startOffsetMinutes: s.startOffsetMinutes,
          durationMinutes: s.durationMinutes,
          colorArgb: s.colorArgb,
          status: s.status,
          completedAt: s.status == TaskStatus.done ? _now() : null,
        ),
      // 不在新列表里的旧阶段**打墓碑而不是物理删**：
      // 物理删的话，V3 对端只会看到「这条还在」。
      for (final old in existing)
        if (!incoming.contains(old.id) && old.deletedAt == null)
          old.copyWith(deletedAt: _now()),
    ];

    await _repo.saveTaskWithStages(task, stages);
  }

  /// 阶段数只能是 **0 或 ≥2**（FR-TASK-02：「包含 2..N 个有序阶段」）。
  ///
  /// 0 是合法的 —— 那是「把阶段事项改回单项」。
  /// **1 个不合法**：一个只有一个阶段的阶段事项，进度永远是 0/1 或 1/1，
  /// 与单项任务没有任何区别，却多担一套阶段的读写路径。
  ///
  /// 之所以在这里挡而不是只在界面挡：界面是**当前唯一**的入口，
  /// 而 V4 的语音/Agent 会构造同一批命令（FR-AI-01）。
  void _requireStageCount(List<StageSpec> stages) {
    if (stages.length == 1) {
      throw const DomainInvariantViolation('阶段事项至少要两个阶段，或者一个都没有（改回单项）');
    }
  }

  /// `orderIndex` 必须从 0 起连续（data-model §3.2）。
  ///
  /// 不连续时甘特图与列表的排序会出现空档，且「上移/下移」的实现会踩空。
  /// 显式抛出，不用 assert。
  void _requireContiguousOrder(List<StageSpec> stages) {
    final indices = [for (final s in stages) s.orderIndex]..sort();
    for (var i = 0; i < indices.length; i++) {
      if (indices[i] != i) {
        throw DomainInvariantViolation('阶段的 orderIndex 必须从 0 起连续，实际为 $indices');
      }
    }
  }

  Future<void> _completeWithStages(CompleteTaskWithStagesCommand c) async {
    final task = await _require(c.taskId);
    final stages = await _repo.findStagesOfTask(c.taskId);
    final result = completeTaskWithStages(task, stages, now: _now());
    await _repo.saveTaskWithStages(result.task, result.stages);
  }
}

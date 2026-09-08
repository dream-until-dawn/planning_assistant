/// 命令分发器 —— 写路径上唯一执行变更的地方（overview §4）。
///
/// 只依赖 `TaskRepository` 抽象与领域策略纯函数，**不认识 Drift**。
/// 因此它既能跑在 App 里，也能被纯 Dart 测试直接驱动，
/// 将来 V3 云端下发的变更、V4 Agent 产出的命令走的都是这同一条路径。
library;

import '../../core/patch/unset.dart';
import '../../core/time/clock.dart';
import '../../core/time/time_zone_resolver.dart';
import '../entities/occurrence.dart';
import '../entities/occurrence_override.dart';
import '../entities/stage.dart';
import '../entities/stage_occurrence_state.dart';
import '../entities/task.dart';
import '../policies/task_lifecycle.dart';
import '../recurrence/recurrence_engine.dart';
import '../repositories/task_repository.dart';
import '../value_objects/occurrence_key.dart';
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
  /// [engine] 只为「本次及以后」用：截断原规则要算 `UNTIL`，
  /// 而那要经时区换算（`withEndDate`）。自己拼 UNTIL 串是
  /// recurrence-engine §2.3 明确禁止的 —— 少个 `Z` 就静默错一次。
  ///
  /// 默认给一个用系统时区库的引擎，于是绝大多数调用方不必关心它。
  const CommandDispatcher(
    this._repo,
    this._clock, {
    this._engine = const RecurrenceEngine(TzTimeZoneResolver()),
  });

  final TaskRepository _repo;

  /// 注入时钟。**不读系统时钟** —— 否则命令的效果不可复现，
  /// 回放一致性测试也就无从谈起。
  final Clock _clock;
  final RecurrenceEngine _engine;

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
      case SetOccurrenceStatusCommand():
        await _setOccurrenceStatus(command);
      case SplitRecurringTaskCommand():
        await _split(command);
      case MoveOccurrenceCommand():
        await _moveOccurrence(command);
      case SkipOccurrenceCommand():
        await _repo.saveOverride(
          OccurrenceOverride.skip(
            taskId: command.taskId,
            key: command.occurrenceKey,
          ),
        );
      case CompleteTaskWithStagesCommand():
        await _completeWithStages(command);
      case SetStageOccurrenceStatusCommand():
        await _setStageOccurrenceStatus(command);
    }
  }

  /// 「本次及以后」：把原规则在分割点截断，再建一条从分割点起的新任务
  /// （FR-TASK-06、data-model §4.4）。
  ///
  /// **不改历史** —— 分割点之前的发生与它们的完成记录原样留在原任务上。
  Future<void> _split(SplitRecurringTaskCommand c) async {
    final original = await _require(c.taskId);
    final recurrence = original.recurrence;
    if (recurrence == null) {
      throw StateError('任务 ${c.taskId} 不重复，谈不上「本次及以后」');
    }

    // 分割点正好是第一次 → 截断出来的原任务一次都不发生，留下一条死任务。
    // 这时「本次及以后」与「改整条」是同一件事，直接改整条。
    final firstKey = OccurrenceKey.fromWallTime(
      original.startWallTime!,
      isAllDay: original.isAllDay,
    );
    if (c.splitAt == firstKey) {
      await _create(c.newTask.copyWithId(c.taskId));
      await _writeStages(c.taskId, c.stages);
      return;
    }

    // 原规则截到**分割点前一天**为止 —— 分割点那一次归新任务。
    // 截到分割点当天的话，那一次会同时出现在两条任务上。
    await _repo.saveTask(
      original.copyWith(
        recurrence: _engine.withEndDate(
          recurrence,
          c.splitAt.date.addDays(-1),
          original.timeZoneId,
        ),
      ),
    );
    await _create(c.newTask);
    await _writeStages(c.newTask.taskId, c.stages);
  }

  /// 整表写回阶段。空表也要写 —— 那表示「这条任务没有阶段」。
  Future<void> _writeStages(String taskId, List<StageSpec> specs) =>
      _replaceStages(ReplaceStagesCommand(taskId: taskId, stages: specs));

  /// 把某一次挪到别的日期（FR-TASK-05）。
  ///
  /// **在已有例外之上叠加**，不是覆盖：那一次可能已经被改过标题、
  /// 或者标成了进行中。整条替换掉的话，左滑推迟一下就把用户之前
  /// 改的东西抹了。
  Future<void> _moveOccurrence(MoveOccurrenceCommand c) async {
    final existing = await _repo.findOverridesOfTask(c.taskId);
    final prior = existing.where((o) => o.key == c.occurrenceKey).firstOrNull;

    await _repo.saveOverride(
      OccurrenceOverride(
        taskId: c.taskId,
        key: c.occurrenceKey,
        action: OverrideAction.modify,
        status: prior?.status,
        titleOverride: prior?.titleOverride,
        noteOverride: prior?.noteOverride,
        planDateOverride: c.planDate,
        startMinuteOverride: c.startMinute ?? prior?.startMinuteOverride,
        endDateOverride: prior?.endDateOverride,
        endMinuteOverride: prior?.endMinuteOverride,
      ),
    );
  }

  /// 改某一次发生的状态（FR-TASK-05）。
  ///
  /// `status == null` 表示回到跟随规则 —— **删掉那条例外**，
  /// 而不是写一条 `pending` 的例外，理由见命令本身的注释。
  ///
  /// `completedAt` 与任务侧同一套语义：转 done 时记下**实际点完成的
  /// 那一刻**（不是计划时间，data-model §5），转别的状态时清掉。
  /// 少了这一步，「今天完成的」这类查询会把历史上完成过的也算进来。
  /// 某一次里某个阶段的状态（FR-TASK-07）。
  ///
  /// 行 id 由 (stageId, occurrenceKey) 派生，所以这是一次**覆盖写** ——
  /// 连点两下不会攒出两行互相矛盾的状态。
  Future<void> _setStageOccurrenceStatus(
    SetStageOccurrenceStatusCommand c,
  ) async {
    await _repo.saveStageState(
      StageOccurrenceState(
        id: StageOccurrenceState.idFor(c.stageId, c.occurrenceKey),
        taskId: c.taskId,
        stageId: c.stageId,
        occurrenceKey: c.occurrenceKey,
        status: c.status,
        // 与 `applyStatusChange` 同一条不变量：completedAt 与 status
        // 同进同退。取消完成时必须清掉，否则下次它会显示成
        // 「未完成，但完成于上周三」。
        completedAt: c.status == TaskStatus.done ? _clock.nowUtc() : null,
      ),
    );
  }

  Future<void> _setOccurrenceStatus(SetOccurrenceStatusCommand c) async {
    final status = c.status;
    if (status == null) {
      await _repo.removeOverride(c.taskId, c.occurrenceKey);
      return;
    }
    await _repo.saveOverride(
      OccurrenceOverride(
        taskId: c.taskId,
        key: c.occurrenceKey,
        action: OverrideAction.modify,
        status: status,
      ),
      completedAt: status == OccurrenceStatus.done ? _now() : null,
    );
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
      splitFromTaskId: c.splitFromTaskId,
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
    final before = {for (final s in existing) s.id: s};

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
          // **本来就完成着的，保留原来的完成时刻。**
          //
          // 一律盖成 `_now()` 的话，用户改一下任务标题，所有已完成阶段的
          // 完成时间都变成「刚刚」—— 而这条整表写回是每次保存都跑的。
          // 表现是「上周做完的事显示成刚做完」，没人会去查这个字段，
          // 但它是导出与将来同步时的真实数据。
          completedAt: s.status == TaskStatus.done
              ? (before[s.id]?.status == TaskStatus.done
                    ? before[s.id]!.completedAt
                    : _now())
              : null,
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

/// 命令分发器 —— 写路径上唯一执行变更的地方（overview §4）。
///
/// 只依赖 `TaskRepository` 抽象与领域策略纯函数，**不认识 Drift**。
/// 因此它既能跑在 App 里，也能被纯 Dart 测试直接驱动，
/// 将来 V3 云端下发的变更、V4 Agent 产出的命令走的都是这同一条路径。
library;

import '../../core/patch/unset.dart';
import '../../core/time/clock.dart';
import '../../core/time/minute_of_day.dart';
import '../../core/time/time_zone_resolver.dart';
import '../entities/checklist_item.dart';
import '../entities/occurrence.dart';
import '../entities/occurrence_override.dart';
import '../entities/reminder.dart';
import '../entities/stage.dart';
import '../entities/stage_occurrence_state.dart';
import '../entities/task.dart';
import '../policies/task_lifecycle.dart';
import '../recurrence/recurrence_engine.dart';
import '../repositories/task_repository.dart';
import '../services/all_day_conversion.dart';
import '../services/recurrence_conversion.dart';
import '../services/stage_occurrence_status.dart';
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
      case ReplaceChecklistCommand():
        await _replaceChecklist(command);
      case ReplaceRemindersCommand():
        await _replaceReminders(command);
      case ConvertTaskAllDayModeCommand():
        await _convertAllDayMode(command);
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
        completedAt: prior?.completedAt,
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
    // **整条命令只读一次钟。** 阶段的完成时刻要与这一次的完成时刻对得上 ——
    // 「取消完成时收回哪一批阶段」正是靠两者相等认出来的。
    // 各读各的话，两次读之间差一毫秒，那一批就一个都认不出来。
    final now = _now();

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
        completedAt: c.status == TaskStatus.done ? now : null,
      ),
    );

    // 勾满这一次的全部阶段，这一次就算完成（§4.2 的另一半）。
    // 推导出 pending 时写 null = 删掉状态那一格，而不是留一条
    // 「等于没改」的例外 —— 与取消完成走的是同一个写法。
    final states = await _statesOfOccurrence(c.taskId, c.occurrenceKey);
    final derived = deriveOccurrenceStatusFor(
      await _repo.findStagesOfTask(c.taskId),
      occurrenceStates: states,
    );
    await _writeOccurrenceStatus(
      c.taskId,
      c.occurrenceKey,
      derived == OccurrenceStatus.pending ? null : derived,
      // 与任务侧同一条：完成时刻取**最后一步做完的那一刻**，
      // 不是「算这一下的那一刻」（见 `projectStagesOntoTask`）。
      completedAt: _latestStateCompletion(states) ?? now,
    );
  }

  Future<StageStatesOfOccurrence> _statesOfOccurrence(
    String taskId,
    OccurrenceKey key,
  ) async =>
      groupByOccurrence(await _repo.findStageStatesOfTask(taskId))[key] ??
      const {};

  /// 这一次里最晚的阶段完成时刻；一个都没完成时 null。
  DateTime? _latestStateCompletion(StageStatesOfOccurrence states) {
    DateTime? latest;
    for (final st in states.values) {
      if (st.status != TaskStatus.done) continue;
      final at = st.completedAt;
      if (at == null) continue;
      if (latest == null || at.isAfter(latest)) latest = at;
    }
    return latest;
  }

  /// 只改某一次的**状态那一格**，行上其余字段原样留着。
  ///
  /// 直接 `saveOverride(OccurrenceOverride(status: ...))` 是**整行覆盖**
  /// —— 行 id 由 `taskId#key` 派生，而映射器每一列都写 `Value(...)`。
  /// 于是把一条推迟过的重复任务标完成，推迟就没了。
  /// `_moveOccurrence` 早就是「在已有例外之上叠加」，这里补上同一条。
  ///
  /// 清空状态时：行上还有别的改动就只清状态，什么都不剩才删整行。
  /// 「回到跟随规则」说的是状态那一格，不是把用户挪过的日期一起撤掉。
  Future<void> _writeOccurrenceStatus(
    String taskId,
    OccurrenceKey key,
    OccurrenceStatus? status, {
    required DateTime completedAt,
  }) async {
    final existing = await _repo.findOverridesOfTask(taskId);
    final prior = existing.where((o) => o.key == key).firstOrNull;

    if (status == null && (prior == null || !prior.hasEditsBesidesStatus)) {
      await _repo.removeOverride(taskId, key);
      return;
    }
    await _repo.saveOverride(
      OccurrenceOverride(
        taskId: taskId,
        key: key,
        action: OverrideAction.modify,
        status: status,
        completedAt: status == OccurrenceStatus.done ? completedAt : null,
        titleOverride: prior?.titleOverride,
        noteOverride: prior?.noteOverride,
        planDateOverride: prior?.planDateOverride,
        startMinuteOverride: prior?.startMinuteOverride,
        endDateOverride: prior?.endDateOverride,
        endMinuteOverride: prior?.endMinuteOverride,
      ),
    );
  }

  Future<void> _setOccurrenceStatus(SetOccurrenceStatusCommand c) async {
    final now = _now();
    final prior = (await _repo.findOverridesOfTask(c.taskId))
        .where((o) => o.key == c.occurrenceKey)
        .firstOrNull;

    // 标完成要级联；**清空只在这一次本来是完成的时候**才级联。
    //
    // 同一个 null 还表示「撤回跳过」（`OccurrenceActions.unskip`）。
    // 一条被跳过的发生，它的阶段没被这条命令动过 ——
    // 撤回跳过时顺手清掉，等于把用户在那一次上勾过的进度抹了。
    if (c.status == OccurrenceStatus.done ||
        (c.status == null && prior?.status == OccurrenceStatus.done)) {
      await _cascadeStagesOfOccurrence(
        c.taskId,
        c.occurrenceKey,
        c.status,
        now: now,
        // 收回时只认「让这一次变成已完成的那一批」，判据同任务侧。
        writtenAt: prior?.completedAt,
      );
    }
    await _writeOccurrenceStatus(
      c.taskId,
      c.occurrenceKey,
      c.status,
      completedAt: now,
    );
  }

  /// 把「这一次完成 / 取消完成」推到它的每个阶段上（§4.2）。
  ///
  /// 与不重复那条路同一套规则，只是状态落在
  /// `stage_occurrence_states` 而不是 `Stage.status`：
  /// 待办阶段跟着 done，已完成阶段跟着回 pending，**跳过的不动**。
  ///
  /// **该不该级联由调用方决定**，这里只管照做：判断要看这一次原来的
  /// 状态，而那个值调用方已经读出来了 —— 在这里再读一遍，两处的判据
  /// 迟早对不上。
  Future<void> _cascadeStagesOfOccurrence(
    String taskId,
    OccurrenceKey key,
    OccurrenceStatus? status, {
    required DateTime now,
    DateTime? writtenAt,
  }) async {
    final stages = await _repo.findStagesOfTask(taskId);
    if (stages.isEmpty) return;

    final states = await _statesOfOccurrence(taskId, key);
    final to = status == null ? TaskStatus.pending : TaskStatus.done;

    for (final stage in stages) {
      final was = stageStatusFor(stage, occurrenceStates: states);
      if (was == TaskStatus.skipped || was == to) continue;
      // **收回时只动「让这一次变成已完成的那一批」**（任务侧同一条判据，
      // 见 `uncompleteTaskWithStages`）：用户在那之前自己勾好的留着。
      // `writtenAt` 取不到时全收回 —— 宁可多收，也不要留下
      // 「取消了却还是完成」的一次。
      if (to == TaskStatus.pending &&
          writtenAt != null &&
          states[stage.id]?.completedAt != writtenAt) {
        continue;
      }
      await _repo.saveStageState(
        StageOccurrenceState(
          id: StageOccurrenceState.idFor(stage.id, key),
          taskId: taskId,
          stageId: stage.id,
          occurrenceKey: key,
          status: to,
          completedAt: to == TaskStatus.done ? now : null,
        ),
      );
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
      splitFromTaskId: c.splitFromTaskId,
    );
    await _repo.saveTask(task);
  }

  Future<void> _updateFields(UpdateTaskFieldsCommand c) async {
    final task = await _require(c.taskId);
    // 命令里的哨兵语义（不传 = 不改，显式 null = 清空）直接传给 copyWith，
    // 两边用的是同一套约定。
    final updated = task.copyWith(
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
    );

    // **改重复规则会改变「阶段状态该读哪一份」**（FR-TASK-07）。
    //
    // 不重复看 `Stage.status`，重复看 `stage_occurrence_states` ——
    // 于是 null ⇄ 非 null 那一刻，用户勾过的进度会**当场从界面上消失**
    // （数据没丢，只是读路径改看另一张空表了）。
    //
    // 与 R-27 同一个模式：身份变了就显式迁移，不让读路径去猜。
    final migration = convertRecurrenceMode(
      updated,
      was: task.isRecurring,
      stages: await _repo.findStagesOfTask(c.taskId),
      states: await _repo.findStageStatesOfTask(c.taskId),
    );
    if (migration == null) {
      await _repo.saveTask(updated);
      return;
    }
    // 一个事务：任务改了而阶段没迁的话，那段时间里读到的是空进度。
    await _repo.applyRecurrenceConversion(migration);
  }

  /// 改任务状态。阶段任务的 done 与它的阶段**绑死**（§4.2）。
  ///
  /// 标完成 → 待办阶段全 done；取消完成 → 已完成阶段全回 pending。
  /// **两个方向都在这里**，而不是把「完成」那一半分给
  /// `CompleteTaskWithStagesCommand`：那条命令是给显式表达意图的调用方
  /// （导入、Agent）留的，界面上勾一下发的是这一条。
  /// 级联各写一遍的话，迟早只有一条记得取消时也要回滚。
  Future<void> _changeStatus(ChangeTaskStatusCommand c) async {
    final task = await _require(c.taskId);
    final now = _now();

    // 「取消完成」专指 done → pending。`inProgress → pending`
    // （用户把「进行中」点掉）不该回滚阶段 —— 那会把已经勾好的步骤清空，
    // 而用户只是想撤掉一个标记。
    //
    // 重复任务在这里会被 `applyStatusChange` 直接拒掉（status 恒 pending），
    // 所以先排除掉，否则白读一次阶段表。
    if (!task.isRecurring &&
        (c.status == TaskStatus.done ||
            (c.status == TaskStatus.pending &&
                task.status == TaskStatus.done))) {
      final stages = await _repo.findStagesOfTask(c.taskId);
      if (stages.isNotEmpty) {
        final r = c.status == TaskStatus.done
            ? completeTaskWithStages(task, stages, now: now)
            : uncompleteTaskWithStages(task, stages, now: now);
        await _repo.saveTaskWithStages(r.task, r.stages);
        return;
      }
    }

    await _repo.saveTask(applyStatusChange(task, c.status, now: now));
  }

  /// 全天 ⇄ 定时切换（R-27）。
  ///
  /// 判断与迁移全在纯函数 `convertAllDayMode` 里，这里只负责取数与落盘。
  /// **已经是那个形态时直接返回** —— 不是「无害地再写一遍」：
  /// 再写一遍会把所有例外原地删了重建，白白产生一批墓碑与新行，
  /// 而 V3 对端要为这些什么也没变的行做一轮合并。
  Future<void> _convertAllDayMode(ConvertTaskAllDayModeCommand c) async {
    final task = await _require(c.taskId);
    if (task.isAllDay == c.toAllDay) return;

    await _repo.applyAllDayConversion(
      convertAllDayMode(
        task,
        toAllDay: c.toAllDay,
        // **回落 00:00 的规则只有一处**：`Task.wallStart` 里那句
        // `startMinute ?? MinuteOfDay.midnight`。定时任务不填时刻时，
        // 引擎展开出来的 key 就是 `T00:00` —— 这里算迁移后的 key 时
        // 必须用同一条，否则迁完的例外挂在一个不存在的时刻上。
        startMinute: c.toAllDay
            ? null
            : (c.startMinute ?? MinuteOfDay.midnight),
        overrides: await _repo.findOverridesOfTask(c.taskId),
        stageStates: await _repo.findStageStatesOfTask(c.taskId),
      ),
    );
  }

  /// 整表替换清单项（FR-TASK-09）。
  ///
  /// 与 `_replaceStages` 同一个形状，**少一条约束**：清单没有
  /// 「至少两项」的要求 —— 一项是完全正常的（「记得带伞」）。
  /// 顺序仍然要求连续从 0 开始：断号的话「上移一位」这类操作
  /// 会跳格，而那是界面看不出来的错。
  Future<void> _replaceChecklist(ReplaceChecklistCommand c) async {
    _requireContiguousChecklistOrder(c.items);
    await _require(c.taskId);

    final existing = await _repo.findChecklistOfTask(
      c.taskId,
      scope: TaskScope.all,
    );
    final incoming = {for (final i in c.items) i.id};

    await _repo.saveChecklist(c.taskId, [
      for (final i in c.items)
        ChecklistItem(
          id: i.id,
          taskId: c.taskId,
          title: i.title,
          orderIndex: i.orderIndex,
          isDone: i.isDone,
        ),
      // 不在新列表里的旧项打墓碑，不物理删（同阶段）。
      for (final old in existing)
        if (!incoming.contains(old.id) && old.deletedAt == null)
          old.copyWith(deletedAt: _now()),
    ]);
  }

  Future<void> _replaceReminders(ReplaceRemindersCommand c) async {
    await _require(c.taskId);

    final existing = await _repo.findRemindersOfTask(
      c.taskId,
      scope: TaskScope.all,
    );
    final incoming = {for (final r in c.reminders) r.id};

    await _repo.saveReminders(c.taskId, [
      for (final r in c.reminders)
        Reminder(
          id: r.id,
          taskId: c.taskId,
          kind: r.kind,
          offsetMinutes: r.offsetMinutes,
          absoluteDate: r.absoluteDate,
          absoluteMinute: r.absoluteMinute,
          isEnabled: r.isEnabled,
          // **字段搭配当场校验**：相对提醒缺偏移、绝对提醒缺时刻这类
          // 坏数据一旦落盘，排期时才发现就只剩「那条提醒不响」这一个症状。
        )..checkInvariants(),
      // 不在新列表里的旧提醒打墓碑，不物理删（同阶段与清单）。
      for (final old in existing)
        if (!incoming.contains(old.id) && old.deletedAt == null)
          old.copyWith(deletedAt: _now()),
    ]);
  }

  void _requireContiguousChecklistOrder(List<ChecklistItemSpec> items) {
    final order = [for (final i in items) i.orderIndex]..sort();
    for (var i = 0; i < order.length; i++) {
      if (order[i] != i) {
        throw DomainInvariantViolation(
          '清单项的 orderIndex 必须是连续的 0..${items.length - 1}，实得 $order',
        );
      }
    }
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

    // **重复任务的 `Stage.status` 恒为 pending。**
    //
    // 那一列对重复任务没人读（状态按每一次存，判据见 `stageStatusFor`）。
    // 让它带着 done 落库，就是留下一个能被写、写了没人看的字段 ——
    // 而这种字段下一个人一定会去写它。
    //
    // **归一化而不是抛异常**：编辑器把一条已完成的单项任务改成重复时，
    // 它手上那份草稿还带着 done（草稿是任务还不重复时读的），
    // 抛的话这条最普通的编辑就存不下去。
    // 那份 done **不会丢** —— `_updateFields` 里的
    // `convertRecurrenceMode` 已经先把它搬到第一次发生上了，
    // 而那条命令排在这一条之前。
    TaskStatus statusOf(StageSpec s) =>
        task.isRecurring ? TaskStatus.pending : s.status;

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
          status: statusOf(s),
          // **本来就完成着的，保留原来的完成时刻。**
          //
          // 一律盖成 `_now()` 的话，用户改一下任务标题，所有已完成阶段的
          // 完成时间都变成「刚刚」—— 而这条整表写回是每次保存都跑的。
          // 表现是「上周做完的事显示成刚做完」，没人会去查这个字段，
          // 但它是导出与将来同步时的真实数据。
          completedAt: statusOf(s) == TaskStatus.done
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

    // 阶段是父任务状态的**来源**，不是它的附属（§4.1）：
    // 勾满就完成、取消一个就不再完成，全靠这一步把新的阶段状态投影回去。
    //
    // 放在整表替换里而不是只放在「勾一个阶段」那条路上，是因为
    // 不重复任务的勾选**走的就是整表替换**（没有单阶段命令，
    // 见 `OccurrenceActions.setStageDone`）。挑一条路写的话，
    // 编辑页里勾完保存和列表里勾一下会得出两种父任务状态。
    await _repo.saveTaskWithStages(
      projectStagesOntoTask(task, stages, now: _now()),
      stages,
    );
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

  /// 与 `ChangeTaskStatusCommand(done)` **是同一件事**，转给它。
  ///
  /// 命令留着是因为它在协议里（`TaskCommand.allTypes`，导入与 Agent
  /// 都会构造），删掉是破坏性变更；但实现只能有一份 ——
  /// 两份的话，级联规则改一次就得记得改两处。
  Future<void> _completeWithStages(CompleteTaskWithStagesCommand c) =>
      _changeStatus(
        ChangeTaskStatusCommand(taskId: c.taskId, status: TaskStatus.done),
      );
}

/// [TaskRepository] 的 Drift 实现。
///
/// 职责边界：
///  · 可见性谓词 → SQL 条件的翻译（**一处**，见 [_scopeFilter]）；
///  · 事务边界（跨表写必须原子）；
///  · 写入前校验领域不变量。
///
/// 不做的事：状态机、推导、级联规则 —— 那些都在
/// `domain/policies/task_lifecycle.dart` 的纯函数里，数据层只负责落盘。
library;

import 'package:drift/drift.dart';

import '../../core/time/clock.dart';
import '../../domain/entities/checklist_item.dart';
import '../../domain/entities/occurrence_override.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/stage.dart';
import '../../domain/entities/stage_occurrence_state.dart';
import '../../domain/entities/task.dart';
import '../../domain/policies/task_lifecycle.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/services/all_day_conversion.dart';
import '../../domain/services/recurrence_conversion.dart';
import '../../domain/value_objects/occurrence_key.dart';
import '../database/app_database.dart';
import '../database/dao/synced_dao.dart';
import '../database/dao/table_daos.dart';
import '../mappers/checklist_item_mapper.dart';
import '../mappers/occurrence_override_mapper.dart';
import '../mappers/reminder_mapper.dart';
import '../mappers/stage_occurrence_state_mapper.dart';
import '../mappers/task_mapper.dart';

final class DriftTaskRepository implements TaskRepository {
  DriftTaskRepository(this._db, WriterIdentity writer, Clock clock)
    : _tasks = TaskDao(_db, writer, clock),
      _stages = StageDao(_db, writer, clock),
      _overrides = OccurrenceOverrideDao(_db, writer, clock),
      _stageStates = StageOccurrenceStateDao(_db, writer, clock),
      _checklist = ChecklistItemDao(_db, writer, clock),
      _reminders = ReminderDao(_db, writer, clock),
      _clock = clock;

  final AppDatabase _db;
  final TaskDao _tasks;
  final StageDao _stages;
  final OccurrenceOverrideDao _overrides;
  final StageOccurrenceStateDao _stageStates;
  final ChecklistItemDao _checklist;
  final ReminderDao _reminders;
  final Clock _clock;

  /// 三个可见性谓词翻译成 SQL 的**唯一出处**。
  ///
  /// 每个查询各写各的过滤条件，最先出现的分叉就是「已删的归档任务同时
  /// 出现在回收站和归档列表里」。领域侧的对应实现是 `TaskVisibility`，
  /// 两边由 `task_repository_test.dart` 交叉验证一致。
  String _scopeFilter(TaskScope scope) => switch (scope) {
    TaskScope.active => 'deleted_at IS NULL AND archived_at IS NULL',
    TaskScope.archived => 'deleted_at IS NULL AND archived_at IS NOT NULL',
    TaskScope.trashed => 'deleted_at IS NOT NULL',
    TaskScope.all => '1 = 1',
  };

  @override
  Future<List<Task>> findTasks({TaskScope scope = TaskScope.active}) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM tasks WHERE ${_scopeFilter(scope)} '
          'ORDER BY sort_order, id',
          readsFrom: {_db.tasks},
        )
        .get();
    return [for (final r in rows) _db.tasks.map(r.data).toEntity()];
  }

  @override
  Future<Task?> findTaskById(
    String id, {
    TaskScope scope = TaskScope.active,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM tasks WHERE id = ? AND ${_scopeFilter(scope)}',
          variables: [Variable<String>(id)],
          readsFrom: {_db.tasks},
        )
        .get();
    if (rows.isEmpty) return null;
    return _db.tasks.map(rows.first.data).toEntity();
  }

  @override
  Stream<List<Stage>> watchAllStages() =>
      _stages.watchAll().map((rows) => [for (final r in rows) r.toEntity()]);

  @override
  Future<List<Stage>> findStagesOfTask(
    String taskId, {
    TaskScope scope = TaskScope.active,
  }) async {
    // 阶段没有 archived_at —— 归档是任务级的概念。
    // 所以这里只翻译墓碑那一维，archived 与 active 对阶段是同义的。
    final tombstone = scope == TaskScope.trashed
        ? 'deleted_at IS NOT NULL'
        : scope == TaskScope.all
        ? '1 = 1'
        : 'deleted_at IS NULL';
    final rows = await _db
        .customSelect(
          'SELECT * FROM stages WHERE task_id = ? AND $tombstone '
          'ORDER BY order_index',
          variables: [Variable<String>(taskId)],
          readsFrom: {_db.stages},
        )
        .get();
    return [for (final r in rows) _db.stages.map(r.data).toEntity()];
  }

  @override
  Stream<List<Task>> watchTasks({TaskScope scope = TaskScope.active}) {
    return _db
        .customSelect(
          'SELECT * FROM tasks WHERE ${_scopeFilter(scope)} '
          'ORDER BY sort_order, id',
          readsFrom: {_db.tasks},
        )
        .watch()
        .map(
          (rows) => [for (final r in rows) _db.tasks.map(r.data).toEntity()],
        );
  }

  @override
  Future<List<Reminder>> findRemindersOfTask(
    String taskId, {
    TaskScope scope = TaskScope.active,
  }) async {
    final q = _db.select(_db.reminders)..where((t) => t.taskId.equals(taskId));
    if (scope != TaskScope.all) {
      q.where((t) => t.deletedAt.isNull());
    }
    return (await q.get()).map(reminderFromRow).toList();
  }

  @override
  Future<void> saveReminders(String taskId, List<Reminder> reminders) async {
    await _db.transaction(() async {
      for (final r in reminders) {
        await _reminders.upsert(reminderToCompanion(r));
      }
    });
  }

  @override
  Stream<List<Reminder>> watchAllReminders() => _reminders.watchAll().map(
    (rows) => [for (final r in rows) reminderFromRow(r)],
  );

  @override
  Stream<List<OccurrenceOverride>> watchAllOverrides() => _overrides
      .watchAll()
      .map((rows) => [for (final r in rows) occurrenceOverrideFromRow(r)]);

  @override
  Future<List<OccurrenceOverride>> findOverridesOfTask(String taskId) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM occurrence_overrides '
          'WHERE task_id = ? AND deleted_at IS NULL',
          variables: [Variable<String>(taskId)],
          readsFrom: {_db.occurrenceOverrides},
        )
        .get();
    return [
      for (final r in rows)
        occurrenceOverrideFromRow(_db.occurrenceOverrides.map(r.data)),
    ];
  }

  @override
  Future<void> saveOverride(OccurrenceOverride override) =>
      _overrides.upsert(occurrenceOverrideToCompanion(override));

  @override
  Future<void> removeOverride(String taskId, OccurrenceKey key) =>
      _overrides.softDelete(overrideRowId(taskId, key));

  @override
  Stream<List<StageOccurrenceState>> watchAllStageStates() =>
      (_db.select(_db.stageOccurrenceStates)
            ..where((t) => t.deletedAt.isNull()))
          .watch()
          .map((rows) => rows.map(stageStateFromRow).toList());

  @override
  Future<void> saveStageState(StageOccurrenceState state) =>
      _stageStates.upsert(stageStateToCompanion(state));

  @override
  Stream<List<ChecklistItem>> watchAllChecklistItems() =>
      (_db.select(_db.checklistItems)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
          .watch()
          .map((rows) => rows.map(checklistItemFromRow).toList());

  @override
  Future<List<ChecklistItem>> findChecklistOfTask(
    String taskId, {
    TaskScope scope = TaskScope.active,
  }) async {
    final q = _db.select(_db.checklistItems)
      ..where((t) => t.taskId.equals(taskId))
      ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]);
    if (scope != TaskScope.all) {
      q.where((t) => t.deletedAt.isNull());
    }
    return (await q.get()).map(checklistItemFromRow).toList();
  }

  @override
  Future<List<StageOccurrenceState>> findStageStatesOfTask(
    String taskId,
  ) async {
    final rows = await (_db.select(
      _db.stageOccurrenceStates,
    )..where((t) => t.taskId.equals(taskId) & t.deletedAt.isNull())).get();
    return rows.map(stageStateFromRow).toList();
  }

  @override
  Future<void> applyRecurrenceConversion(RecurrenceConversion c) async {
    c.task.checkInvariants();
    await _db.transaction(() async {
      await _tasks.upsert(c.task.toCompanion());
      for (final s in c.stages) {
        await _stages.upsert(s.toCompanion());
      }
      for (final s in c.states) {
        await _stageStates.upsert(stageStateToCompanion(s));
      }
      for (final o in c.overrides) {
        await _overrides.upsert(occurrenceOverrideToCompanion(o));
      }
    });
  }

  @override
  Future<void> applyAllDayConversion(AllDayConversion conversion) async {
    // **一个事务**：任务改了而例外的 key 没迁，那些例外就永久失联 ——
    // 库里还在、界面上再也挂不上任何一次发生，而且没有任何报错。
    await _db.transaction(() async {
      await _tasks.upsert(conversion.task.toCompanion());
      for (final moved in conversion.movedOverrides) {
        // 顺序要紧：**先写新行再删旧行**。反过来的话，中途失败会留下
        // 「旧的没了、新的还没写」—— 而事务回滚救得了，
        // 唯独救不了「两边都指着同一条例外」那一瞬的唯一索引冲突。
        // 这里两个 id 必然不同（key 变了才会进这张表），所以不冲突。
        await _overrides.upsert(occurrenceOverrideToCompanion(moved.to));
        await _overrides.softDelete(overrideRowId(moved.to.taskId, moved.from));
      }
      for (final moved in conversion.movedStageStates) {
        await _stageStates.upsert(stageStateToCompanion(moved.to));
        await _stageStates.softDelete(
          StageOccurrenceState.idFor(moved.to.stageId, moved.from),
        );
      }
    });
  }

  @override
  Future<void> saveChecklist(String taskId, List<ChecklistItem> items) async {
    // 整表写回必须原子：写到一半的话，界面上会短暂出现
    // 「删掉的那条还在、新加的那条没有」这种谁也解释不了的中间态。
    await _db.transaction(() async {
      for (final i in items) {
        await _checklist.upsert(checklistItemToCompanion(i));
      }
    });
  }

  @override
  Future<void> saveTask(Task task) async {
    // **写库前校验**：坏数据一旦落盘，后面每一次读取都要带着它，
    // 而修复要写迁移。在这里拦下的代价只是一次异常。
    task.checkInvariants();
    await _tasks.upsert(task.toCompanion());
  }

  @override
  Future<void> saveTaskWithStages(Task task, List<Stage> stages) async {
    task.checkInvariants();
    // 跨表写必须原子：半截状态会让「阶段推导父任务状态」永久不一致。
    await _db.transaction(() async {
      await _tasks.upsert(task.toCompanion());
      for (final s in stages) {
        await _stages.upsert(s.toCompanion());
      }
    });
  }

  @override
  Future<void> softDeleteTask(String id) async {
    await _db.transaction(() async {
      final task = await findTaskById(id, scope: TaskScope.all);
      if (task == null || task.isDeleted) return;
      final stages = await findStagesOfTask(id, scope: TaskScope.all);

      // 级联规则在领域层，这里只负责把结果落盘。
      final result = softDeleteTaskCascade(task, stages, now: _clock.nowUtc());
      await _tasks.upsert(result.task.toCompanion());
      for (final s in result.stages) {
        await _stages.upsert(s.toCompanion());
      }
    });
  }

  @override
  Future<int> purgeDeleted(Iterable<String> taskIds) async {
    var purged = 0;
    await _db.transaction(() async {
      for (final id in taskIds) {
        // 子实体交给外键的 `ON DELETE CASCADE`（`app_database.dart` 里
        // 开了 `PRAGMA foreign_keys`）。
        //
        // 这里**只删墓碑**（`purgeTombstone` 那句 WHERE），所以级联删掉的
        // 也一定是墓碑的子行 —— 软删除本来就是级联打墓碑的
        // （`softDeleteTaskCascade`），父是墓碑时子不可能还活着。
        purged += await _tasks.purgeTombstone(id);
      }
    });
    return purged;
  }

  @override
  Future<void> restoreTask(String id) async {
    await _db.transaction(() async {
      final task = await findTaskById(id, scope: TaskScope.all);
      if (task == null || !task.isDeleted) return;
      final stages = await findStagesOfTask(id, scope: TaskScope.all);

      final result = restoreTaskCascade(task, stages);
      await _tasks.upsert(result.task.toCompanion());
      for (final s in result.stages) {
        await _stages.upsert(s.toCompanion());
      }
    });
  }
}

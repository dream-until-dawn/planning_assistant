/// 各可同步表的 DAO。
///
/// 每个都只声明**三件表特有的事**：表本身、outbox 里的实体类型名、
/// 主键怎么取。其余（墓碑过滤、信封盖章、outbox 写入）全在 [SyncedDao] 里。
///
/// 这么切分是有意的：DAO 里能写的每一行，都是将来可能写错的一行。
/// 表越多，共用逻辑下沉的收益越大 —— 十张表意味着十次忘记加
/// `deletedAt IS NULL` 的机会。
library;

import 'package:drift/drift.dart';

import '../app_database.dart';
import 'synced_dao.dart';

/// `entityType` 取值的**唯一出处**。
///
/// outbox 的 `entityType` 同时是导出格式 `data` 下的键名（data-model §6），
/// 两处写死两遍迟早对不上，所以集中在这里。
abstract final class EntityTypes {
  static const task = 'task';
  static const stage = 'stage';
  static const checklistItem = 'checklistItem';
  static const occurrenceOverride = 'occurrenceOverride';
  static const stageOccurrenceState = 'stageOccurrenceState';
  static const reminder = 'reminder';
  static const category = 'category';
  static const tag = 'tag';
  static const taskTag = 'taskTag';
  static const setting = 'setting';

  /// 全集，供守卫测试逐一核对。
  static const all = <String>[
    task,
    stage,
    checklistItem,
    occurrenceOverride,
    stageOccurrenceState,
    reminder,
    category,
    tag,
    taskTag,
    setting,
  ];
}

class TaskDao extends SyncedDao<$TasksTable, TaskRow> {
  TaskDao(super.db, super.writer, super.clock);

  @override
  TableInfo<$TasksTable, TaskRow> get table => attachedDatabase.tasks;

  @override
  String get entityType => EntityTypes.task;

  @override
  String primaryKeyOf(TaskRow row) => row.id;

  @override
  Map<String, Object?> toJson(TaskRow row) => row.toJson();
}

class StageDao extends SyncedDao<$StagesTable, StageRow> {
  StageDao(super.db, super.writer, super.clock);

  @override
  TableInfo<$StagesTable, StageRow> get table => attachedDatabase.stages;

  @override
  String get entityType => EntityTypes.stage;

  @override
  String primaryKeyOf(StageRow row) => row.id;

  @override
  Map<String, Object?> toJson(StageRow row) => row.toJson();
}

class ChecklistItemDao
    extends SyncedDao<$ChecklistItemsTable, ChecklistItemRow> {
  ChecklistItemDao(super.db, super.writer, super.clock);

  @override
  TableInfo<$ChecklistItemsTable, ChecklistItemRow> get table =>
      attachedDatabase.checklistItems;

  @override
  String get entityType => EntityTypes.checklistItem;

  @override
  String primaryKeyOf(ChecklistItemRow row) => row.id;

  @override
  Map<String, Object?> toJson(ChecklistItemRow row) => row.toJson();
}

class OccurrenceOverrideDao
    extends SyncedDao<$OccurrenceOverridesTable, OccurrenceOverrideRow> {
  OccurrenceOverrideDao(super.db, super.writer, super.clock);

  @override
  TableInfo<$OccurrenceOverridesTable, OccurrenceOverrideRow> get table =>
      attachedDatabase.occurrenceOverrides;

  @override
  String get entityType => EntityTypes.occurrenceOverride;

  @override
  String primaryKeyOf(OccurrenceOverrideRow row) => row.id;

  @override
  Map<String, Object?> toJson(OccurrenceOverrideRow row) => row.toJson();
}

class StageOccurrenceStateDao
    extends SyncedDao<$StageOccurrenceStatesTable, StageOccurrenceStateRow> {
  StageOccurrenceStateDao(super.db, super.writer, super.clock);

  @override
  TableInfo<$StageOccurrenceStatesTable, StageOccurrenceStateRow> get table =>
      attachedDatabase.stageOccurrenceStates;

  @override
  String get entityType => EntityTypes.stageOccurrenceState;

  @override
  String primaryKeyOf(StageOccurrenceStateRow row) => row.id;

  @override
  Map<String, Object?> toJson(StageOccurrenceStateRow row) => row.toJson();
}

class ReminderDao extends SyncedDao<$RemindersTable, ReminderRow> {
  ReminderDao(super.db, super.writer, super.clock);

  @override
  TableInfo<$RemindersTable, ReminderRow> get table =>
      attachedDatabase.reminders;

  @override
  String get entityType => EntityTypes.reminder;

  @override
  String primaryKeyOf(ReminderRow row) => row.id;

  @override
  Map<String, Object?> toJson(ReminderRow row) => row.toJson();
}

class CategoryDao extends SyncedDao<$CategoriesTable, CategoryRow> {
  CategoryDao(super.db, super.writer, super.clock);

  @override
  TableInfo<$CategoriesTable, CategoryRow> get table =>
      attachedDatabase.categories;

  @override
  String get entityType => EntityTypes.category;

  @override
  String primaryKeyOf(CategoryRow row) => row.id;

  @override
  Map<String, Object?> toJson(CategoryRow row) => row.toJson();
}

class TagDao extends SyncedDao<$TagsTable, TagRow> {
  TagDao(super.db, super.writer, super.clock);

  @override
  TableInfo<$TagsTable, TagRow> get table => attachedDatabase.tags;

  @override
  String get entityType => EntityTypes.tag;

  @override
  String primaryKeyOf(TagRow row) => row.id;

  @override
  Map<String, Object?> toJson(TagRow row) => row.toJson();
}

/// 配置项。主键是 `key` 而不是 `id`。
class SettingDao extends SyncedDao<$SettingsTable, SettingRow> {
  SettingDao(super.db, super.writer, super.clock);

  @override
  TableInfo<$SettingsTable, SettingRow> get table => attachedDatabase.settings;

  @override
  String get entityType => EntityTypes.setting;

  @override
  String primaryKeyOf(SettingRow row) => row.key;

  @override
  Map<String, Object?> toJson(SettingRow row) => row.toJson();

  /// 只取参与同步的行（data-model §5：`scope='device'` 的不同步）。
  Future<List<SettingRow>> getGlobalScoped() =>
      (select(table)
            ..where((_) => notDeleted)
            ..where(
              (_) => table.columnsByName['scope']!.equalsExp(
                const Variable<String>('global'),
              ),
            ))
          .get();
}

/// 任务 ⇄ 标签联结表。**联合主键**，因此 [softDelete] 不适用。
class TaskTagDao extends SyncedDao<$TaskTagsTable, TaskTagRow> {
  TaskTagDao(super.db, super.writer, super.clock);

  @override
  TableInfo<$TaskTagsTable, TaskTagRow> get table => attachedDatabase.taskTags;

  @override
  String get entityType => EntityTypes.taskTag;

  /// 复合键拼成 `taskId:tagId`（分隔符见 [kCompositeKeySeparator]）。
  ///
  /// 两段都过 [requireSeparatorFree]：拼得回去的前提是各段不含分隔符，
  /// 而这条假设此前只存在于注释里。放在写入路径上拦，
  /// 是因为回放可能发生在几个月后、甚至另一台设备上。
  @override
  String primaryKeyOf(TaskTagRow row) =>
      '${requireSeparatorFree(row.taskId, 'taskId')}'
      '$kCompositeKeySeparator'
      '${requireSeparatorFree(row.tagId, 'tagId')}';

  @override
  Map<String, Object?> toJson(TaskTagRow row) => row.toJson();
}

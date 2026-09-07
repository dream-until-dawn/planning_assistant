/// Drift 数据库定义与迁移。
///
/// 表定义在 `tables/` 下按领域分文件（data-model §3）；这里只做装配、
/// 索引声明与迁移编排。
library;

import 'package:drift/drift.dart';

import 'tables/system_tables.dart';
import 'tables/task_tables.dart';
import 'tables/taxonomy_tables.dart';

part 'app_database.g.dart';

/// 索引（data-model §3 各表末尾的「索引」条目）。
///
/// 为什么显式声明而不是「等慢了再加」：这些索引对应的是**默认查询路径**
/// （三个可见性谓词 + 按日期取任务），一旦漏掉，问题要到数据量上来才暴露，
/// 那时已经在用户设备上了。
@DriftDatabase(
  tables: [
    Tasks,
    Stages,
    ChecklistItems,
    OccurrenceOverrides,
    StageOccurrenceStates,
    Reminders,
    Categories,
    Tags,
    TaskTags,
    Settings,
    ScheduledNotifications,
    ChangeLog,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// **只增不改**（data-model §7）。每次升版必须：
  /// 写迁移步骤 + `drift_dev schema dump` 固化旧版快照 + 写迁移测试。
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndexes(m);
    },
    beforeOpen: (details) async {
      // **外键约束默认是关的**。SQLite 每个连接都要单独打开，
      // 忘了这一步的话 `ON DELETE CASCADE` 完全不生效 —— 删任务留下
      // 一堆孤儿阶段行，且不报任何错。这正是需要一条测试盯着的那类静默失效。
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createIndexes(Migrator m) async {
    for (final stmt in kIndexStatements) {
      await customStatement(stmt);
    }
  }
}

/// 索引建表语句。
///
/// 单独提出来是为了让测试能逐条断言「该建的都建了」——
/// 索引漏建不会让任何功能测试变红，只有专门的测试能抓到。
const List<String> kIndexStatements = [
  // tasks：三个可见性谓词 + 按日期取任务的主路径。
  'CREATE INDEX IF NOT EXISTS idx_tasks_visible_date '
      'ON tasks (deleted_at, archived_at, plan_date)',
  'CREATE INDEX IF NOT EXISTS idx_tasks_category ON tasks (category_id)',
  // 部分索引：重复任务是少数，但每次展开都要全量捞出来。
  'CREATE INDEX IF NOT EXISTS idx_tasks_recurring ON tasks (recurrence_rule) '
      'WHERE recurrence_rule IS NOT NULL',
  'CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks (status, deleted_at)',

  'CREATE INDEX IF NOT EXISTS idx_stages_task_order '
      'ON stages (task_id, order_index)',

  // 一次发生最多一条例外 —— 唯一索引，靠库保证而不是靠应用层自觉。
  'CREATE UNIQUE INDEX IF NOT EXISTS idx_overrides_task_key '
      'ON occurrence_overrides (task_id, occurrence_key)',
  'CREATE UNIQUE INDEX IF NOT EXISTS idx_stage_occ_stage_key '
      'ON stage_occurrence_states (stage_id, occurrence_key)',

  // change_log：找待推送 + 按实体溯源。
  'CREATE INDEX IF NOT EXISTS idx_changelog_unsynced ON change_log (synced_at)',
  'CREATE INDEX IF NOT EXISTS idx_changelog_entity '
      'ON change_log (entity_type, entity_id)',
];

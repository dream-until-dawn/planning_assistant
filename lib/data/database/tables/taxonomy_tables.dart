/// 分类与标签（data-model §3.6、§3.7）。
library;

import 'package:drift/drift.dart';

import 'sync_envelope.dart';
import 'task_tables.dart';

/// 分类（§3.6）。一个任务至多一个分类；删分类不删任务。
@DataClassName('CategoryRow')
class Categories extends Table with SyncEnvelope {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get colorArgb => integer()();

  /// 图标**标识串**，不存二进制 —— 图标资源应随版本走，
  /// 存进库会让换图标变成一次数据迁移。
  TextColumn get icon => text()();

  IntColumn get orderIndex => integer()();

  /// 「未分类」这条不可删（settings-spec §4）。
  BoolColumn get isSystemDefault =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 标签（§3.7）。一个任务可有多个标签。
@DataClassName('TagRow')
class Tags extends Table with SyncEnvelope {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get colorArgb => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 任务 ⇄ 标签联结表（§3.7）。
///
/// **联结表也带同步信封** —— 否则云端无法表达「解除了一个标签关联」：
/// 物理删行在对端看来与「从未关联过」无法区分。
@DataClassName('TaskTagRow')
class TaskTags extends Table with SyncEnvelope {
  TextColumn get taskId =>
      text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {taskId, tagId};
}

/// 数据库骨架的行为契约（含 FR-DATA-02：每条记录携带同步信封）。
///
/// 这里测的全是**静默失效**的东西：外键没打开、索引没建、信封漏列。
/// 它们都不会让功能测试变红 —— 功能照跑，只是数据在悄悄烂掉。
@TestOn('vm')
library;

// 只需 native.dart：它同时带来 NativeDatabase 与 SqliteException。
// 不导入 drift.dart —— 它导出的 isNull（SQL 的 IS NULL 构造）
// 会与 matcher 的同名匹配器冲突。
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/data/database/app_database.dart';

/// 可同步的表 —— 必须带完整同步信封（data-model §5）。
const _syncableTables = <String>[
  'tasks',
  'stages',
  'checklist_items',
  'occurrence_overrides',
  'stage_occurrence_states',
  'reminders',
  'categories',
  'tags',
  'task_tags',
  'settings',
];

/// 明确**不**带信封的表，各有理由（§5）。
const _nonSyncableTables = <String, String>{
  'scheduled_notifications': '本地排期簿记，系统通知 ID 是设备本地的',
  'change_log': '信封的来源本身',
};

const _envelopeColumns = <String>[
  'created_at',
  'updated_at',
  'deleted_at',
  'revision',
  'last_writer_id',
  'remote_version',
];

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<String>> columnsOf(String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return rows.map((r) => r.read<String>('name')).toList();
  }

  group('schema 基线', () {
    test('schemaVersion 为 1', () {
      // 只增不改（§7）。改这个数字必须同时补迁移步骤、schema 快照与迁移测试。
      expect(db.schemaVersion, 1);
    });

    test('12 张表全部建出', () async {
      final rows = await db.customSelect('''
        SELECT name FROM sqlite_master
        WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
      ''').get();
      final names = rows.map((r) => r.read<String>('name')).toSet();
      expect(
        names,
        containsAll([..._syncableTables, ..._nonSyncableTables.keys]),
      );
      expect(names.length, 12, reason: '实际建出：${names.toList()..sort()}');
    });
  });

  group('同步信封（§5）', () {
    test('每张可同步表都带全部 6 个信封列', () async {
      // 漏一列的后果不是报错，是**该表在 V3 无法参与同步**，
      // 且要到那时才发现 —— 而那时表里已经有用户数据。
      final missing = <String>[];
      for (final table in _syncableTables) {
        final cols = await columnsOf(table);
        for (final c in _envelopeColumns) {
          if (!cols.contains(c)) missing.add('$table.$c');
        }
      }
      expect(missing, isEmpty, reason: '缺失的信封列：$missing');
    });

    test('不同步的表确实没有信封列', () async {
      // 反向也要断：给 change_log 加信封等于给日志本身记日志。
      for (final entry in _nonSyncableTables.entries) {
        final cols = await columnsOf(entry.key);
        expect(
          cols.where(_envelopeColumns.contains),
          isEmpty,
          reason: '${entry.key} 不该带信封（${entry.value}）',
        );
      }
    });

    test('deletedAt 可空、revision 默认 1、createdAt/updatedAt 非空', () async {
      final info = await db.customSelect('PRAGMA table_info(tasks)').get();
      final byName = {for (final r in info) r.read<String>('name'): r};
      expect(byName['deleted_at']!.read<int>('notnull'), 0);
      expect(byName['revision']!.read<String?>('dflt_value'), '1');
      // 墓碑要靠这两列判新旧，可空的话 LWW 无从比较。
      expect(byName['created_at']!.read<int>('notnull'), 1);
      expect(byName['updated_at']!.read<int>('notnull'), 1);
    });
  });

  group('外键级联', () {
    test('PRAGMA foreign_keys 在打开的连接上是 ON', () async {
      // **SQLite 的外键默认是关的，且每个连接都要单独打开。**
      // 忘了这一步不会报任何错，只是 ON DELETE CASCADE 完全不生效。
      final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(row.data.values.first, 1);
    });

    test('删任务级联删掉阶段与清单项', () async {
      await _seedTask(db, 't1');
      await db.customStatement('''
        INSERT INTO stages (id, task_id, title, order_index, status,
                            created_at, updated_at, revision, last_writer_id)
        VALUES ('s1', 't1', '阶段一', 0, 'pending', 1, 1, 1, 'dev')
      ''');
      await db.customStatement('''
        INSERT INTO checklist_items (id, task_id, title, is_done, order_index,
                                     created_at, updated_at, revision,
                                     last_writer_id)
        VALUES ('c1', 't1', '子项', 0, 0, 1, 1, 1, 'dev')
      ''');

      await db.customStatement("DELETE FROM tasks WHERE id = 't1'");

      expect(await _count(db, 'stages'), 0, reason: '阶段应被级联删除');
      expect(await _count(db, 'checklist_items'), 0);
    });

    test('删分类不删任务，只把 categoryId 置空（FR-CFG-03）', () async {
      // 与上一条相反 —— 同一个机制、两种策略，都得断。
      await db.customStatement('''
        INSERT INTO categories (id, name, color_argb, icon, order_index,
                                is_system_default, created_at, updated_at,
                                revision, last_writer_id)
        VALUES ('cat1', '工作', 1, 'work', 0, 0, 1, 1, 1, 'dev')
      ''');
      await _seedTask(db, 't1', categoryId: 'cat1');

      await db.customStatement("DELETE FROM categories WHERE id = 'cat1'");

      expect(await _count(db, 'tasks'), 1, reason: '任务不该被删');
      final row = await db
          .customSelect("SELECT category_id FROM tasks WHERE id = 't1'")
          .getSingle();
      expect(row.read<String?>('category_id'), isNull);
    });

    test('插入指向不存在任务的阶段被拒绝', () async {
      // 证明外键真的在生效，而不只是 PRAGMA 报了个 1。
      expect(
        db.customStatement('''
          INSERT INTO stages (id, task_id, title, order_index, status,
                              created_at, updated_at, revision, last_writer_id)
          VALUES ('s1', '不存在', 'x', 0, 'pending', 1, 1, 1, 'dev')
        '''),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('索引', () {
    test('声明的索引全部建出', () async {
      // 索引漏建不会让任何功能测试变红，只有专门断言能抓到。
      final rows = await db.customSelect('''
        SELECT name FROM sqlite_master
        WHERE type = 'index' AND name LIKE 'idx_%'
      ''').get();
      final built = rows.map((r) => r.read<String>('name')).toSet();
      expect(
        built.length,
        kIndexStatements.length,
        reason: '已建：${built.toList()..sort()}',
      );
      expect(
        built,
        containsAll([
          'idx_tasks_visible_date',
          'idx_tasks_category',
          'idx_tasks_recurring',
          'idx_tasks_status',
          'idx_stages_task_order',
          'idx_overrides_task_key',
          'idx_stage_occ_stage_key',
          'idx_changelog_unsynced',
          'idx_changelog_entity',
        ]),
      );
    });

    test('一次发生最多一条例外 —— 靠唯一索引保证，不靠应用层自觉', () async {
      await _seedTask(db, 't1');
      Future<void> insertOverride(String id) => db.customStatement('''
        INSERT INTO occurrence_overrides (id, task_id, occurrence_key, action,
                                          created_at, updated_at, revision,
                                          last_writer_id)
        VALUES ('$id', 't1', '2026-03-08T09:00', 'skip', 1, 1, 1, 'dev')
      ''');

      await insertOverride('o1');
      expect(insertOverride('o2'), throwsA(isA<SqliteException>()));
    });

    test('部分索引带 WHERE 子句（只索引重复任务）', () async {
      // 全表索引与部分索引同名，只有看 SQL 才能区分。
      final row = await db
          .customSelect(
            "SELECT sql FROM sqlite_master WHERE name = 'idx_tasks_recurring'",
          )
          .getSingle();
      expect(row.read<String>('sql'), contains('WHERE'));
    });
  });

  group('change_log（outbox）', () {
    test('seq 自增且单调 —— 回放顺序依赖它', () async {
      for (var i = 0; i < 3; i++) {
        await db.customStatement('''
          INSERT INTO change_log (entity_type, entity_id, op, occurred_at,
                                  device_id)
          VALUES ('task', 't$i', 'upsert', $i, 'dev')
        ''');
      }
      final rows = await db
          .customSelect('SELECT seq FROM change_log ORDER BY seq')
          .get();
      expect(rows.map((r) => r.read<int>('seq')).toList(), [1, 2, 3]);
    });

    test('syncedAt 在 V1 恒为 NULL（可空且无默认值）', () async {
      final info = await db.customSelect('PRAGMA table_info(change_log)').get();
      final synced = info.firstWhere(
        (r) => r.read<String>('name') == 'synced_at',
      );
      expect(synced.read<int>('notnull'), 0);
      expect(synced.read<String?>('dflt_value'), isNull);
    });
  });
}

Future<int> _count(AppDatabase db, String table) async {
  final row = await db
      .customSelect('SELECT COUNT(*) AS c FROM $table')
      .getSingle();
  return row.read<int>('c');
}

Future<void> _seedTask(AppDatabase db, String id, {String? categoryId}) {
  final cat = categoryId == null ? 'NULL' : "'$categoryId'";
  return db.customStatement('''
    INSERT INTO tasks (id, title, kind, category_id, priority, status,
                       is_all_day, time_zone_id, sort_order,
                       created_at, updated_at, revision, last_writer_id)
    VALUES ('$id', '任务', 'single', $cat, 2, 'pending',
            0, 'Asia/Shanghai', 0, 1, 1, 1, 'dev')
  ''');
}

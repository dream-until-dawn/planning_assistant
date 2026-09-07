/// 变更日志回放（module-map `data/outbox/`）。
///
/// **这是 overview §6 里 V3 那一格的验收工具**，但它在 V1 内部就有价值：
/// 「清库 → 按 seq 回放 → 状态等价」是发现**写操作绕过命令管道**
/// 最有效的手段 —— 绕过的写不会留下 change_log 行，回放后状态就对不上。
/// 靠 code review 找这种绕过，是找不干净的。
///
/// ## 回放**不**走 `SyncedDao`
///
/// 走 DAO 会重新盖信封、并再写一遍 change_log —— 那是「又操作了一次」，
/// 不是「还原到当时」。回放是恢复，不是重演：直接按载荷原样写行，
/// 信封字段一并照抄，于是回放结果与原状态可以逐列相等，
/// 而不是「大致一样」。
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/dao/table_daos.dart';

/// 回放结果，用于诊断。
typedef ReplayReport = ({int applied, int skipped});

/// 按 `change_log.seq` 顺序重建业务表。
final class ChangeLogReplayer {
  const ChangeLogReplayer(this._db);

  final AppDatabase _db;

  /// 回放全部变更日志。
  ///
  /// [wipeFirst] 为真时先清空业务表（不清 `change_log` 自身）。
  /// 这正是验收要做的事：清库后只凭日志能否还原。
  Future<ReplayReport> replayAll({bool wipeFirst = true}) async {
    return _db.transaction(() async {
      if (wipeFirst) await _wipeBusinessTables();

      final rows = await _db
          .customSelect(
            'SELECT entity_type, entity_id, op, payload_json, occurred_at, '
            'device_id FROM change_log ORDER BY seq',
          )
          .get();

      var applied = 0;
      var skipped = 0;
      for (final row in rows) {
        final entityType = row.read<String>('entity_type');
        final op = row.read<String>('op');
        final payload = row.read<String?>('payload_json');

        final table = _tableFor(entityType);
        if (table == null) {
          // 认不出的实体类型**不静默丢弃**：跳过意味着回放结果缺一块，
          // 而调用方会以为回放成功了。计数上报，由调用方决定是否接受。
          skipped++;
          continue;
        }

        switch (op) {
          case 'upsert':
            if (payload == null) {
              skipped++;
              continue;
            }
            await _applyUpsert(table, payload);
            applied++;
          case 'delete':
            await _applyDelete(
              table,
              row.read<String>('entity_id'),
              row.read<int>('occurred_at'),
              row.read<String>('device_id'),
            );
            applied++;
          default:
            skipped++;
        }
      }
      return (applied: applied, skipped: skipped);
    });
  }

  /// 按载荷原样写行，信封一并照抄。
  ///
  /// 用裸 SQL 而不是 drift 的 `into(table).insert(...)`：后者要求
  /// `Insertable<Row>`，而这里的表是运行时按 `entityType` 选出来的，
  /// 静态行类型只能是 `dynamic`，泛型对不上。
  /// 回放本就是「把当时那一行原样放回去」，裸 SQL 更贴近这个语义。
  Future<void> _applyUpsert(TableInfo<Table, dynamic> table, String payload) {
    final json = jsonDecode(payload) as Map<String, Object?>;

    final names = <String>[];
    final values = <Object?>[];
    for (final col in table.$columns) {
      final key = _jsonKeyOf(col.name);
      if (!json.containsKey(key)) continue;
      names.add(col.name);
      values.add(_sqlValue(col, json[key]));
    }
    if (names.isEmpty) return Future<void>.value();

    // **绝不能用 `INSERT OR REPLACE`。**
    //
    // 它的语义是「先 DELETE 掉冲突行，再 INSERT」，于是会触发
    // `ON DELETE CASCADE` —— 回放一条任务的 upsert 会把它名下所有阶段、
    // 清单项、提醒、例外**全部连带删掉**，而且后续日志再也补不回来
    // （那些子行的日志在更早的 seq 上，已经放过了）。
    //
    // 这不是理论风险：写这个文件时第一版就是 `INSERT OR REPLACE`，
    // 回放一致性测试当场把它抓了出来 —— 13 条日志全部 applied、
    // 报告显示 skipped=0，而阶段表回放后是空的。
    //
    // `ON CONFLICT DO UPDATE` 是原地更新，不删行，因此不触发级联；
    // 顺带也保住了 rowid，快照比对不会因为行序变化而假红。
    final pk = [for (final c in table.$primaryKey) c.name];
    final placeholders = List.filled(names.length, '?').join(', ');
    final assignments = [
      for (final n in names)
        if (!pk.contains(n)) '$n = excluded.$n',
    ].join(', ');

    return _db.customStatement(
      'INSERT INTO ${table.actualTableName} (${names.join(', ')}) '
      'VALUES ($placeholders) '
      'ON CONFLICT(${pk.join(', ')}) DO UPDATE SET $assignments',
      values,
    );
  }

  /// 回放一条删除：把墓碑打回去。
  ///
  /// 载荷是空的（删除不需要整行），所以时刻取自日志行的 `occurredAt` ——
  /// 不能用「现在」，否则回放出来的墓碑时间与当时不同，
  /// 逐列比对会红，而 V3 的 LWW 也会拿到错的时间戳。
  Future<void> _applyDelete(
    TableInfo<Table, dynamic> table,
    String entityId,
    int occurredAt,
    String deviceId,
  ) {
    // 主键可能是复合的（`task_tags` 是 `(taskId, tagId)`），此时 outbox 的
    // `entityId` 是 `SyncedDao.primaryKeyOf()` 拼出的 `taskId:tagId`。
    //
    // 初版这里写的是 `$primaryKey.single`，靠 `_tableFor` 对 taskTag 返回 null
    // 兜住 —— 而那个 null 判断在 `switch (op)` **之前**，于是连 upsert 一起
    // 被跳过：taskTag 写得进库、回放不回来、`skipped` 计数没人看。
    // 三层同时失明。修的时候两处必须一起改。
    final pk = [for (final c in table.$primaryKey) c.name];
    final values = _splitCompositeKey(entityId, pk.length, table);

    final where = pk.map((c) => '$c = ?').join(' AND ');
    return _db.customStatement(
      'UPDATE ${table.actualTableName} SET deleted_at = ?, updated_at = ?, '
      'revision = revision + 1, last_writer_id = ? WHERE $where',
      [occurredAt, occurredAt, deviceId, ...values],
    );
  }

  /// 把 outbox 的 `entityId` 拆回主键各列的值。
  ///
  /// 分隔符与 `SyncedDao.primaryKeyOf()` 约定一致，用 `:` 而不是 `-`
  /// —— 两侧都是 UUID v7，本身含 `-`。
  List<String> _splitCompositeKey(
    String entityId,
    int columnCount,
    TableInfo<Table, dynamic> table,
  ) {
    if (columnCount == 1) return [entityId];
    final parts = entityId.split(':');
    if (parts.length != columnCount) {
      // 拆不开就**抛**，不猜。猜错会更新到别的行上去，
      // 而那种损坏在回放报告里看不出来。
      throw StateError(
        '${table.actualTableName} 的复合主键有 $columnCount 列，'
        '但 entityId「$entityId」拆出 ${parts.length} 段',
      );
    }
    return parts;
  }

  /// drift 的 `toJson()` 用 Dart 字段名（lowerCamelCase），列名是 snake_case。
  static String _jsonKeyOf(String columnName) {
    final parts = columnName.split('_');
    return parts.first +
        parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
  }

  /// JSON 值 → SQLite 能直接绑定的值。
  ///
  /// 只有 bool 需要特殊处理：SQLite 没有布尔类型，drift 存的是 0/1，
  /// 而 `toJson()` 给出的是真正的 `true`/`false`。直接绑 bool 会写进
  /// 一个 SQLite 认不出的值。
  static Object? _sqlValue(GeneratedColumn<Object> col, Object? v) {
    if (v == null) return null;
    return switch (col.type) {
      DriftSqlType.bool => (v is bool ? v : (v as int) != 0) ? 1 : 0,
      DriftSqlType.double => (v as num).toDouble(),
      DriftSqlType.int => v as int,
      _ => v,
    };
  }

  TableInfo<Table, dynamic>? _tableFor(String entityType) =>
      switch (entityType) {
        EntityTypes.task => _db.tasks,
        EntityTypes.stage => _db.stages,
        EntityTypes.checklistItem => _db.checklistItems,
        EntityTypes.occurrenceOverride => _db.occurrenceOverrides,
        EntityTypes.stageOccurrenceState => _db.stageOccurrenceStates,
        EntityTypes.reminder => _db.reminders,
        EntityTypes.category => _db.categories,
        EntityTypes.tag => _db.tags,
        EntityTypes.setting => _db.settings,
        EntityTypes.taskTag => _db.taskTags,
        _ => null,
      };

  /// 清空业务表，保留 `change_log`。
  ///
  /// 顺序按外键依赖倒着来 —— 先删子后删父，否则外键会拦下。
  Future<void> _wipeBusinessTables() async {
    const order = [
      'stage_occurrence_states',
      'occurrence_overrides',
      'reminders',
      'checklist_items',
      'task_tags',
      'stages',
      'tasks',
      'tags',
      'categories',
      'settings',
    ];
    for (final t in order) {
      await _db.customStatement('DELETE FROM $t');
    }
  }
}

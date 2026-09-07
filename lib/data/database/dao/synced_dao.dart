/// 可同步表的 DAO 基类。
///
/// 它存在的理由只有一条：**把三件容易忘、忘了又不报错的事变成不可能忘**。
///
///  1. 查询漏掉 `deletedAt IS NULL` → 已删除的任务重新出现在列表里；
///  2. 写入漏掉信封维护（`updatedAt` / `revision` / `lastWriterId`）
///     → V3 同步时无法判断新旧，冲突解析全错；
///  3. 写入漏掉 outbox 行 → 该次变更永远不会被推送，且回放一致性测试
///     会在很久以后才发现「有写操作绕过了管道」。
///
/// 这三件都属于**静默失效**：功能照跑，数据在悄悄烂掉。所以不靠自觉，
/// 靠基类统一做掉，再用 `test/data/synced_dao_test.dart` 对**每一张表**
/// 逐条验证 —— 新加表时漏接基类会直接变红。
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';

/// outbox 的操作类型（data-model §3.11）。
enum ChangeOp {
  upsert,
  delete;

  String get wireName => name;
}

/// 写入方标识。
///
/// 抽成接口是因为 V3 的冲突解析完全依赖它 —— 设备 ID 若在测试里是随机的，
/// 相关断言就写不成确定值。
abstract interface class WriterIdentity {
  String get deviceId;
}

/// 固定设备 ID。
final class FixedWriterIdentity implements WriterIdentity {
  const FixedWriterIdentity(this.deviceId);

  @override
  final String deviceId;
}

/// 所有**可同步**表的 DAO 都必须继承它。
///
/// 泛型参数 [Tbl] 是 drift 生成的表类（如 `$TasksTable`），[Row] 是行数据类。
abstract class SyncedDao<Tbl extends Table, Row extends DataClass>
    extends DatabaseAccessor<AppDatabase> {
  SyncedDao(super.attachedDatabase, this._writer, this._now);

  final WriterIdentity _writer;

  /// 注入时钟：`DateTime.now()` 会让所有涉及 `updatedAt` 的断言变成
  /// 「跑得快就过、跑得慢就挂」。见 `core/time/clock.dart`。
  final DateTime Function() _now;

  /// 具体表。
  TableInfo<Tbl, Row> get table;

  /// outbox 里的实体类型名，如 `task`。**同时是导出格式的键名**，
  /// 改它等于改导出契约。
  String get entityType;

  /// 取某行的主键值，用于 outbox 的 `entityId`。
  String primaryKeyOf(Row row);

  /// 该行的完整 JSON，写进 outbox 的 `payloadJson`。
  Map<String, Object?> toJson(Row row);

  /// 墓碑列。
  ///
  /// 经 `columnsByName` 取而不是让子类各写一遍 —— 子类能写的地方就是子类
  /// 能写错的地方。表没带信封时这里会直接抛，而不是悄悄退化成不过滤。
  GeneratedColumn<int> get _deletedAt {
    final col = table.columnsByName['deleted_at'];
    if (col == null) {
      throw StateError(
        '${table.actualTableName} 没有 deleted_at 列 —— '
        'SyncedDao 只能用于带同步信封的表（data-model §5）',
      );
    }
    return col as GeneratedColumn<int>;
  }

  /// 「未删除」谓词。**所有读取都必须经过它。**
  Expression<bool> get notDeleted => _deletedAt.isNull();

  /// 全部存活行。
  Future<List<Row>> getAll() => (select(table)..where((_) => notDeleted)).get();

  /// 全部存活行的流。
  Stream<List<Row>> watchAll() =>
      (select(table)..where((_) => notDeleted)).watch();

  /// 含墓碑的全部行。**仅供导出与同步使用**（墓碑必须导出，
  /// 否则导入方无法知道某条被删了 —— data-model §6）。
  Future<List<Row>> getAllIncludingDeleted() => select(table).get();

  /// 写入一行：**盖信封 + 写 outbox**，两件事都由这里做掉。
  ///
  /// 调用方给的 Companion 里的信封字段会被**无条件覆盖** ——
  /// 让「忘了填」与「填错了」归到同一条路径上，只有一处需要正确。
  ///
  ///  · 新行：`createdAt = now`、`revision = 1`
  ///  · 已存在：保留原 `createdAt`，`revision + 1`
  ///  · 两种情况都刷新 `updatedAt` 与 `lastWriterId`
  ///
  /// 数据写入与 outbox 追加在**同一个事务**里。分开写的话中途失败会留下
  /// 「数据变了但 outbox 没记」的状态 —— 回放一致性测试正是为抓它而存在，
  /// 但那时已经晚了，所以在这里用事务从根上排除。
  Future<void> upsert(Insertable<Row> entry) async {
    await transaction(() async {
      final columns = Map<String, Expression<Object>>.from(
        entry.toColumns(false),
      );
      final pkName = _primaryKeyColumn();
      final id = _stringValueOf(columns[pkName], pkName);

      final nowMs = _now().millisecondsSinceEpoch;
      final prior = await _envelopeOf(id);

      // 已存在时保留原 createdAt —— 覆盖它会让「这条何时建的」永久丢失，
      // 且 V3 的冲突解析拿它做兜底比较。
      columns['created_at'] = Variable<int>(prior?.createdAt ?? nowMs);
      columns['updated_at'] = Variable<int>(nowMs);
      columns['revision'] = Variable<int>((prior?.revision ?? 0) + 1);
      columns['last_writer_id'] = Variable<String>(_writer.deviceId);

      await into(table)
          .insertOnConflictUpdate(RawValuesInsertable<Row>(columns));

      final row = await _requireRow(id);
      await _appendChangeLog(ChangeOp.upsert, primaryKeyOf(row), toJson(row));
    });
  }

  /// 现有行的信封快照；行不存在时为 null。
  Future<({int createdAt, int revision})?> _envelopeOf(String id) async {
    final rows = await customSelect(
      'SELECT created_at, revision FROM ${table.actualTableName} '
      'WHERE ${_primaryKeyColumn()} = ?',
      variables: [Variable<String>(id)],
      readsFrom: {table},
    ).get();
    if (rows.isEmpty) return null;
    return (
      createdAt: rows.first.read<int>('created_at'),
      revision: rows.first.read<int>('revision'),
    );
  }

  String _stringValueOf(Expression<Object>? expr, String columnName) {
    if (expr is! Variable) {
      throw StateError('无法从写入内容中取出主键 $columnName');
    }
    final value = expr.value;
    if (value is! String) {
      throw StateError('主键 $columnName 不是字符串：$value');
    }
    return value;
  }

  /// 软删除：打墓碑，**不物理删行**。
  ///
  /// 物理删除会让「删除」这件事无法同步 —— 对端只会看到「这条还在」。
  ///
  /// 返回是否确实删到了行。
  Future<bool> softDelete(String id) async {
    return transaction(() async {
      final nowMs = _now().millisecondsSinceEpoch;
      final affected = await customUpdate(
        'UPDATE ${table.actualTableName} SET deleted_at = ?, updated_at = ?, '
        'revision = revision + 1, last_writer_id = ? '
        'WHERE ${_primaryKeyColumn()} = ? AND deleted_at IS NULL',
        variables: [
          Variable<int>(nowMs),
          Variable<int>(nowMs),
          Variable<String>(_writer.deviceId),
          Variable<String>(id),
        ],
        updates: {table},
      );
      if (affected == 0) return false;
      await _appendChangeLog(ChangeOp.delete, id, null);
      return true;
    });
  }

  /// 主键列名。联合主键的表（`task_tags`）不能用 [softDelete]，
  /// 由子类覆写自己的删除方法。
  String _primaryKeyColumn() {
    final pk = table.$primaryKey;
    if (pk.length != 1) {
      throw StateError(
        '${table.actualTableName} 是联合主键，'
        'softDelete(String id) 不适用，子类需自行实现',
      );
    }
    return pk.first.name;
  }

  Future<Row> _requireRow(String id) async {
    final pkName = _primaryKeyColumn();
    final rows =
        await (select(table)..where(
              (_) =>
                  table.columnsByName[pkName]!.equalsExp(Variable<String>(id)),
            ))
            .get();
    if (rows.isEmpty) {
      throw StateError('刚写入的行不见了：${table.actualTableName} $pkName=$id');
    }
    return rows.first;
  }

  /// 追加 outbox 行。**每一次写入都必须有对应的一行**，
  /// 否则回放会漏掉这次变更。
  Future<void> _appendChangeLog(
    ChangeOp op,
    String entityId,
    Map<String, Object?>? payload,
  ) {
    return into(attachedDatabase.changeLog).insert(
      ChangeLogCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        op: op.wireName,
        payloadJson: Value(payload == null ? null : jsonEncode(payload)),
        occurredAt: _now().millisecondsSinceEpoch,
        deviceId: _writer.deviceId,
      ),
    );
  }
}

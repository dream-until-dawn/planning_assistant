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

import '../../../core/time/clock.dart';
import '../app_database.dart';

/// 复合主键在 outbox `entityId` 里的分隔符。
///
/// **这是一条承重假设**：`entityId` 是单列 TEXT，联结表只能把两个键拼成一串，
/// 回放时再拆开。拼得回去的前提是**各段本身不含分隔符**。
///
/// 选 `:` 而不是 `-`：两侧都是 UUID v7，本身含 `-`。
/// 当下满足假设（UUID v7 只有十六进制与 `-`），但「当下满足」不等于
/// 「以后也满足」—— 所以由 [requireSeparatorFree] 在**写入时**拦住，
/// 而不是等到回放时才拆不开。评审把它列为观察项，这里升格成可执行的检查。
const String kCompositeKeySeparator = ':';

/// 校验一个键段不含分隔符，否则拼出的 `entityId` 无法还原。
///
/// 在写入路径上抛，不在回放路径上抛：回放可能发生在几个月后、
/// 甚至另一台设备上，那时已经查不出是哪次写入种下的。
String requireSeparatorFree(String value, String columnName) {
  if (value.contains(kCompositeKeySeparator)) {
    throw ArgumentError.value(
      value,
      columnName,
      '不得包含复合主键分隔符「$kCompositeKeySeparator」—— '
      '它会让 outbox 的 entityId 无法被回放拆回原键',
    );
  }
  return value;
}

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
  SyncedDao(super.attachedDatabase, this._writer, this._clock);

  final WriterIdentity _writer;

  /// 注入时钟。用具名的 [Clock] 而不是裸 `DateTime Function()`：
  /// 后者在生产代码里传一个 `DateTime.now` 就绕过了 cross-cutting §1
  /// 的禁令，且架构守卫扫不出来。
  final Clock _clock;

  DateTime _now() => _clock.nowUtc();

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
      // 主键可能是复合的（task_tags 是 (taskId, tagId)），所以按**列集合**
      // 定位，而不是假设只有一列。假设单列的话联结表的 upsert 直接抛，
      // 而联结表恰恰是最不起眼、最容易漏测的那张。
      final keyValues = _primaryKeyValuesOf(columns);

      final nowMs = _now().millisecondsSinceEpoch;
      final prior = await _envelopeOf(keyValues);

      // **没显式给 deletedAt 的 upsert = 断言这一行活着。**
      //
      // 不补这一句的话，`insertOnConflictUpdate` 只更新companion 里带的
      // 那几列，墓碑那一列原样留着 —— 于是「写进去了，但读不出来」。
      //
      // 这在**主键是派生的**那几张表上是常规路径，不是边角情况：
      // 例外的行 id 是 `taskId#occurrenceKey`，所以
      // 「完成 → 取消完成 → 再完成」写的是同一行。用户报的就是它：
      // 取消完成之后再点完成，库里 `status=done` 而 `deletedAt` 还在，
      // 每一次读取都把它过滤掉，界面上那一下**看起来毫无反应**。
      //
      // 显式给了的照旧（`_replaceStages` 就是靠传 deletedAt 打墓碑的）——
      // 一律清空会把那条路径的墓碑全复活。
      if (!columns.containsKey('deleted_at')) {
        columns['deleted_at'] = const Variable<int>(null);
      }

      // 已存在时保留原 createdAt —— 覆盖它会让「这条何时建的」永久丢失，
      // 且 V3 的冲突解析拿它做兜底比较。
      columns['created_at'] = Variable<int>(prior?.createdAt ?? nowMs);
      columns['updated_at'] = Variable<int>(nowMs);
      columns['revision'] = Variable<int>((prior?.revision ?? 0) + 1);
      columns['last_writer_id'] = Variable<String>(_writer.deviceId);

      await into(table)
          .insertOnConflictUpdate(RawValuesInsertable<Row>(columns));

      final row = await _requireRow(keyValues);
      await _appendChangeLog(ChangeOp.upsert, primaryKeyOf(row), toJson(row));
    });
  }

  /// 从待写入的列里取出主键各列的值。
  Map<String, String> _primaryKeyValuesOf(
    Map<String, Expression<Object>> columns,
  ) {
    final result = <String, String>{};
    for (final col in table.$primaryKey) {
      final expr = columns[col.name];
      if (expr is! Variable) {
        throw StateError('无法从写入内容中取出主键 ${col.name}');
      }
      final value = expr.value;
      if (value is! String) {
        throw StateError('主键 ${col.name} 不是字符串：$value');
      }
      result[col.name] = value;
    }
    return result;
  }

  /// `WHERE k1 = ? AND k2 = ?` 及其绑定值。
  (String, List<Variable<Object>>) _whereByKey(Map<String, String> keyValues) =>
      (
        keyValues.keys.map((k) => '$k = ?').join(' AND '),
        [for (final v in keyValues.values) Variable<String>(v)],
      );

  /// 现有行的信封快照；行不存在时为 null。
  Future<({int createdAt, int revision})?> _envelopeOf(
    Map<String, String> keyValues,
  ) async {
    final (where, vars) = _whereByKey(keyValues);
    final rows = await customSelect(
      'SELECT created_at, revision FROM ${table.actualTableName} WHERE $where',
      variables: vars,
      readsFrom: {table},
    ).get();
    if (rows.isEmpty) return null;
    return (
      createdAt: rows.first.read<int>('created_at'),
      revision: rows.first.read<int>('revision'),
    );
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

  /// **物理删除**一行（task-lifecycle §6、用例 L-09）。
  ///
  /// ## 为什么这个方法可以存在，而 [softDelete] 之外的路径不行
  ///
  /// 上面那句「物理删除会让『删除』这件事无法同步」说的是**用户按下删除**
  /// 那一刻：那时对端还不知道这条被删了，行没了就没法告诉它。
  ///
  /// 超期清理是另一回事：墓碑已经存在、已经进过 outbox（V1 里
  /// 「已同步」恒为真），对端早就知道了。这时留着行只是占地方。
  ///
  /// **只删已经打了墓碑的行**（`deleted_at IS NOT NULL`）——
  /// 少了这个条件，一次调用错就把活着的数据抹了，而且没有退路。
  ///
  /// **不写 change_log**：这一步不是一次新的用户操作，
  /// 而是把一条早已同步过的删除落到本地存储上。
  Future<int> purgeTombstone(String id) async {
    return customUpdate(
      'DELETE FROM ${table.actualTableName} '
      'WHERE ${_primaryKeyColumn()} = ? AND deleted_at IS NOT NULL',
      variables: [Variable<String>(id)],
      updates: {table},
    );
  }

  /// 单列主键的列名。
  ///
  /// **只有 [softDelete] 与 [purgeTombstone] 用它** —— 两者的签名都是
  /// 单个 `String id`，
  /// 复合主键无从表达。其余路径都按主键**列集合**处理，
  /// 见 [_primaryKeyValuesOf]。
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

  Future<Row> _requireRow(Map<String, String> keyValues) async {
    var query = select(table);
    for (final entry in keyValues.entries) {
      query = query
        ..where(
          (_) => table.columnsByName[entry.key]!.equalsExp(
            Variable<String>(entry.value),
          ),
        );
    }
    final rows = await query.get();
    if (rows.isEmpty) {
      throw StateError('刚写入的行不见了：${table.actualTableName} $keyValues');
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

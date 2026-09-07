/// 导入导出的载荷（data-model §6、FR-DATA-04）。
///
/// **这份格式同时是 V3 的服务端契约**：服务端要在没有任何客户端代码的
/// 情况下解析它，据此发提醒邮件。所以两条硬约束：
///
///  1. 字段名 = 列名（lowerCamelCase），逐字段对应，**不做嵌套加工**；
///  2. 二次编码的 JSON 列必须在 JSON Schema 里显式标注
///     （`tasks.recurrenceExDates`、`settings.valueJson`）——
///     不标的话服务端不知道要再 `JSON.parse` 一次，
///     「无需客户端逻辑即可解析」这句话对这两列就不成立。
///
/// 墓碑行**照常导出**：不导的话导入方无从知道某条被删了，
/// 恢复备份会让已删的任务集体复活。
library;

import 'dart:convert';

import '../database/app_database.dart';
import '../database/dao/table_daos.dart';

/// 导出格式版本。**与 DB `schemaVersion` 解耦** ——
/// 表结构变了未必影响导出格式，反之亦然；绑在一起会让两边都不敢动。
const int kExportFormatVersion = 1;

/// `data` 下的键名与表的对应。
///
/// 键名取自 [EntityTypes] 的复数形式，集中在这里而不是散在各处 ——
/// 导出、导入、JSON Schema 三处必须用同一套名字。
const Map<String, String> kExportSections = {
  'categories': 'categories',
  'tags': 'tags',
  'taskTags': 'task_tags',
  'tasks': 'tasks',
  'stages': 'stages',
  'checklistItems': 'checklist_items',
  'occurrenceOverrides': 'occurrence_overrides',
  'stageOccurrenceStates': 'stage_occurrence_states',
  'reminders': 'reminders',
  'settings': 'settings',
};

/// 二次编码的 JSON 列：库里是 TEXT，内容本身是 JSON 串。
///
/// 服务端解析时要对这些再做一次 `JSON.parse`。JSON Schema 里用
/// `contentMediaType: "application/json"` 标注。
const Map<String, List<String>> kDoubleEncodedJsonColumns = {
  'tasks': ['recurrenceExDates'],
  'settings': ['valueJson'],
};

/// 导出/导入失败。
final class ExportFormatException implements Exception {
  const ExportFormatException(this.message);
  final String message;

  @override
  String toString() => 'ExportFormatException: $message';
}

/// 读写导出包。
final class ExportService {
  const ExportService(this._db);

  final AppDatabase _db;

  /// 导出整库。
  ///
  /// [appVersion] 与 [deviceId] 由调用方注入 —— 让它们在这里现取的话，
  /// 导出结果就不可复现，往返测试也无从断言。
  Future<Map<String, Object?>> export({
    required String appVersion,
    required String deviceId,
    required DateTime exportedAt,
  }) async {
    final data = <String, List<Map<String, Object?>>>{};
    final counts = <String, int>{};

    for (final entry in kExportSections.entries) {
      final rows = await _readSection(entry.key, entry.value);
      data[entry.key] = rows;
      counts[entry.key] = rows.length;
    }

    return {
      'formatVersion': kExportFormatVersion,
      'schemaVersion': _db.schemaVersion,
      'appVersion': appVersion,
      'exportedAt': exportedAt.millisecondsSinceEpoch,
      'deviceId': deviceId,
      'counts': counts,
      'data': data,
    };
  }

  Future<List<Map<String, Object?>>> _readSection(
    String section,
    String table,
  ) async {
    // settings 只导 scope='global'（data-model §5：device 域不同步）。
    final where = section == 'settings' ? "WHERE scope = 'global'" : '';
    final rows = await _db
        .customSelect('SELECT * FROM $table $where ORDER BY rowid')
        .get();

    // 值原样输出：SQLite 里 bool 已经是 0/1，与列类型一致，
    // 服务端不必猜「这个 1 是数字还是真」。
    return [
      for (final r in rows)
        {for (final e in r.data.entries) _camelCase(e.key): e.value},
    ];
  }

  /// 导入一个包，**先清库再写入**。
  ///
  /// 不做增量合并：合并需要冲突策略，而 V1 没有。假装能合并的话，
  /// 用户会得到一个「有些新有些旧」的库，且说不清哪些是哪些。
  Future<void> import(Map<String, Object?> bundle) async {
    _validate(bundle);
    final data = bundle['data']! as Map<String, Object?>;

    await _db.transaction(() async {
      // 顺序按外键依赖：先删子后删父，写入时反过来。
      for (final table in _wipeOrder) {
        await _db.customStatement('DELETE FROM $table');
      }
      // 写入顺序必须满足外键：父在前、子在后。
      // **不能直接用 kExportSections 的顺序** —— 那个顺序照抄文档的示例，
      // 里面 taskTags 排在 tasks 前面，直接照写会撞外键。
      for (final section in kInsertOrder) {
        final rows = (data[section] as List?) ?? const [];
        for (final row in rows) {
          await _insertRow(
            kExportSections[section]!,
            row as Map<String, Object?>,
          );
        }
      }
    });
  }

  /// 写入顺序：父表在前。
  ///
  /// 与 [kExportSections] 分开维护，因为后者是**输出的键序**（照文档），
  /// 这里是**写入的依赖序**。两者恰好不同（taskTags 依赖 tasks），
  /// 合成一个会让其中一个必然是错的。
  static const kInsertOrder = [
    'categories',
    'tags',
    'settings',
    'tasks',
    'taskTags',
    'stages',
    'checklistItems',
    'occurrenceOverrides',
    'stageOccurrenceStates',
    'reminders',
  ];

  static const _wipeOrder = [
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

  Future<void> _insertRow(String table, Map<String, Object?> row) {
    final names = <String>[];
    final values = <Object?>[];
    row.forEach((key, value) {
      names.add(_snakeCase(key));
      values.add(_denormalizeFromJson(value));
    });
    final placeholders = List.filled(names.length, '?').join(', ');
    return _db.customStatement(
      'INSERT INTO $table (${names.join(', ')}) VALUES ($placeholders)',
      values,
    );
  }

  /// 校验包的形状。
  ///
  /// **在写库之前全部校验完**：一半写进去再报错，用户的库就成了半截状态，
  /// 而他刚刚才把它清空。
  void _validate(Map<String, Object?> bundle) {
    final version = bundle['formatVersion'];
    if (version != kExportFormatVersion) {
      throw ExportFormatException(
        '导出格式版本不匹配：包是 $version，本端支持 $kExportFormatVersion',
      );
    }
    if (bundle['data'] is! Map) {
      throw const ExportFormatException('缺少 data 段');
    }
    final data = bundle['data']! as Map<String, Object?>;

    for (final section in kExportSections.keys) {
      final rows = data[section];
      if (rows != null && rows is! List) {
        throw ExportFormatException('data.$section 不是数组');
      }
    }

    // counts 是**校验用**的，不是装饰。对不上说明包被截断或改过。
    final counts = bundle['counts'];
    if (counts is Map) {
      counts.forEach((key, expected) {
        final actual = (data[key] as List?)?.length ?? 0;
        if (expected is int && expected != actual) {
          throw ExportFormatException(
            'counts.$key 声称 $expected 条，实际 $actual 条 —— 包可能被截断',
          );
        }
      });
    }
  }

  /// 容忍导入方给的是 `true`/`false`（别的实现可能这么写）。
  Object? _denormalizeFromJson(Object? value) =>
      value is bool ? (value ? 1 : 0) : value;

  static String _camelCase(String snake) {
    final parts = snake.split('_');
    return parts.first +
        parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
  }

  static String _snakeCase(String camel) =>
      camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
}

/// 把包编码成可落盘的字符串。
///
/// 用带缩进的编码：备份文件是用户可能会打开看的东西，
/// 也是出问题时最先被贴进 issue 的东西。
String encodeExportBundle(Map<String, Object?> bundle) =>
    const JsonEncoder.withIndent('  ').convert(bundle);

Map<String, Object?> decodeExportBundle(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, Object?>) {
    throw const ExportFormatException('导出文件的顶层不是 JSON 对象');
  }
  return decoded;
}

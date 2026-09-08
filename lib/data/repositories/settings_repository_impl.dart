/// 配置存取的 Drift 实现。
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/time/clock.dart';
import '../../domain/repositories/settings_repository.dart';
import '../database/app_database.dart';
import '../database/dao/synced_dao.dart';
import '../database/dao/table_daos.dart';

final class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(AppDatabase db, WriterIdentity writer, Clock clock)
    : _dao = SettingDao(db, writer, clock);

  final SettingDao _dao;

  /// 值以 **JSON 文本**存，不是裸字符串。
  ///
  /// 裸存的话 `bool`、`int`、`enum` 都得各自约定一套编码，而 `"true"`
  /// 与 `true` 分不开。JSON 让类型自带，解码由各 `SettingSpec` 负责。
  Map<String, Object?> _decode(List<SettingRow> rows) => {
    for (final row in rows) row.key: _decodeOne(row),
  };

  Object? _decodeOne(SettingRow row) {
    try {
      return jsonDecode(row.valueJson);
    } on FormatException {
      // 存进去的不是合法 JSON —— 只可能是被别的东西写过。
      // **当成没设过**（返回 null，读取层用默认值），而不是让整个
      // 配置加载失败：一条坏值不该让所有设置都读不出来。
      return null;
    }
  }

  @override
  Future<Map<String, Object?>> loadAll() async => _decode(await _dao.getAll());

  @override
  Stream<Map<String, Object?>> watchAll() => _dao.watchAll().map(_decode);

  @override
  Future<void> put(String key, Object? value, {required String scope}) =>
      _dao.upsert(
        SettingsCompanion(
          key: Value(key),
          valueJson: Value(jsonEncode(value)),
          scope: Value(scope),
        ),
      );

  @override
  Future<void> remove(String key) => _dao.softDelete(key);
}

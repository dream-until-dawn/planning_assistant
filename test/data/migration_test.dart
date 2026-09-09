/// 迁移基线（data-model §7、FR-DATA-05）。
///
/// **v1 还没有可迁移的上一版**，所以这里现在只做两件事，且两件都不白做：
///
///  1. 断言 v1 的快照与**当前表定义**逐列一致 —— 改了表却忘了重新 dump，
///     在这里变红，而不是等到写 v2 迁移时才发现基线本身是错的。
///  2. 把迁移测试的脚手架先跑通。v2 到来时补的是一次 `migrateAndValidate`，
///     而不是从零搭一套。
///
/// 快照更新命令（改表定义后必须跑）：
/// ```
/// dart run drift_dev schema dump lib/data/database/app_database.dart drift_schemas/
/// dart run drift_dev schema generate drift_schemas/ test/data/generated_migrations/
/// ```
///
/// ---
/// **一条踩过的坑，留给将来写 v2 的人。**
///
/// 这个文件第一版用的是 drift 文档里的标准写法：
/// ```dart
/// final connection = await verifier.startAt(1);
/// await verifier.migrateAndValidate(AppDatabase(connection), 1);
/// ```
/// 它**永远绿**。`startAt(1)` 建的库已经是 v1，再迁到 v1 不跑任何迁移，
/// 校验的是「快照 vs 由快照建出的库」—— 自己跟自己比，
/// **当前表定义根本没参与**。给 Categories 加一列再跑，照样通过。
///
/// 所以下面改成显式比对两个来源：
/// 「当前表定义建出的库」 vs 「快照建出的库」。
@TestOn('vm')
library;

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/data/database/app_database.dart';

import 'generated_migrations/schema.dart';

/// 一张表的形状：列名 → `类型|是否非空|默认值`。
typedef TableShape = Map<String, String>;

/// 读出整库的形状，用于两个来源之间比对。
Future<Map<String, TableShape>> _shapeOf(GeneratedDatabase db) async {
  final tables = await db.customSelect('''
    SELECT name FROM sqlite_master
    WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
    ORDER BY name
  ''').get();

  final result = <String, TableShape>{};
  for (final t in tables) {
    final name = t.read<String>('name');
    final cols = await db.customSelect('PRAGMA table_info($name)').get();
    result[name] = {
      for (final c in cols)
        c.read<String>('name'):
            '${c.read<String>('type')}|'
            '${c.read<int>('notnull')}|'
            '${c.read<String?>('dflt_value') ?? '-'}',
    };
  }
  return result;
}

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
    // 本文件的核心就是**同时开两个库来比对**，drift 的「重复实例化」
    // 调试告警在这里是误报。只关这一处，不全局关。
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  test('FR-DATA-05 当前表定义与 v1 快照逐列一致', () async {
    final fromCode = AppDatabase(NativeDatabase.memory());
    final fromSnapshot = AppDatabase(await verifier.startAt(1));
    addTearDown(fromCode.close);
    addTearDown(fromSnapshot.close);

    final codeShape = await _shapeOf(fromCode);
    final snapshotShape = await _shapeOf(fromSnapshot);

    // 先比表集合 —— 少一张表时逐列比对的报错会很难读。
    expect(
      codeShape.keys.toSet(),
      snapshotShape.keys.toSet(),
      reason: '表集合不一致：快照需要重新 dump',
    );

    final diffs = <String>[];
    for (final table in codeShape.keys) {
      final a = codeShape[table]!;
      final b = snapshotShape[table]!;
      for (final col in {...a.keys, ...b.keys}) {
        if (a[col] != b[col]) {
          diffs.add(
            '  $table.$col  代码=${a[col] ?? '(无)'}  快照=${b[col] ?? '(无)'}',
          );
        }
      }
    }
    expect(
      diffs,
      isEmpty,
      reason: '表定义与 v1 快照不一致，需重新 dump：\n${diffs.join('\n')}',
    );
  });

  test('v1 快照覆盖全部 12 张表', () async {
    // SchemaVerifier 比对的是两边，dump 时整张表漏掉的话两边会一起漏。
    // 所以独立数一次。
    final db = AppDatabase(await verifier.startAt(1));
    addTearDown(db.close);
    final shape = await _shapeOf(db);
    expect(shape.length, 12, reason: '快照里的表：${shape.keys.toList()..sort()}');
  });

  test('建库后 user_version 落为 1', () async {
    // user_version 是 SQLite 记 schema 版本的地方，drift 靠它决定跑哪些迁移。
    // 与代码里的 schemaVersion 不一致时，迁移会被跳过或重复执行。
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    expect(row.data.values.first, 1);
    expect(db.schemaVersion, 1);
  });
}

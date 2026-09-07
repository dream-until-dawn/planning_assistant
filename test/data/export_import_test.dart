/// 导入导出往返（FR-CFG-06、FR-DATA-04）。
///
/// 「导出 → 清库 → 导入 → **逐表逐字段**比对」。逐字段是要紧的：
/// 只比条数的话，字段搬错、类型变了、墓碑丢了，全都测不出来。
///
/// 另外这个文件会把一份**真实导出样例**写到
/// `build/export-sample.json`，交给 `tool/validate_export.py` 校验。
/// 那一步才是「服务端无需客户端逻辑即可解析」的真正证据 ——
/// Dart 侧自己读自己写的东西，证明不了任何事。
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/data/database/app_database.dart';
import 'package:planning_assistant/data/database/dao/synced_dao.dart';
import 'package:planning_assistant/data/database/dao/table_daos.dart';
import 'package:planning_assistant/data/dto/export_bundle.dart';
import 'package:planning_assistant/data/repositories/task_repository_impl.dart';
import 'package:planning_assistant/domain/commands/command_dispatcher.dart';
import 'package:planning_assistant/domain/commands/task_command.dart';
import 'package:planning_assistant/domain/entities/task.dart';

const _writer = FixedWriterIdentity('device-A');
final _exportedAt = DateTime.utc(2026, 3, 8, 12);

class _Clock {
  DateTime value = DateTime.utc(2026, 3, 8, 9);
  DateTime call() {
    value = value.add(const Duration(minutes: 1));
    return value;
  }
}

const _tables = [
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

Future<Map<String, List<Map<String, Object?>>>> snapshot(AppDatabase db) async {
  final result = <String, List<Map<String, Object?>>>{};
  for (final t in _tables) {
    final rows = await db.customSelect('SELECT * FROM $t ORDER BY rowid').get();
    result[t] = [for (final r in rows) Map<String, Object?>.from(r.data)];
  }
  return result;
}

void main() {
  late AppDatabase db;
  late _Clock clock;
  late ExportService service;
  late CommandDispatcher dispatcher;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = _Clock();
    service = ExportService(db);
    dispatcher = CommandDispatcher(
      DriftTaskRepository(db, _writer, clock.call),
      clock.call,
    );
  });
  tearDown(() => db.close());

  /// 一份**覆盖面尽量宽**的数据：满字段任务、重复任务、墓碑、归档、
  /// 阶段、标签关联、两种 scope 的配置。
  ///
  /// 只放一条最简任务的话，往返测试会漏掉所有可空字段与二次编码列。
  Future<void> seed() async {
    final cat = CategoryDao(db, _writer, clock.call);
    final tag = TagDao(db, _writer, clock.call);
    final taskTag = TaskTagDao(db, _writer, clock.call);
    final setting = SettingDao(db, _writer, clock.call);

    await cat.upsert(
      CategoriesCompanion.insert(
        id: 'cat-1',
        name: '工作',
        colorArgb: 0xFF2196F3,
        icon: 'work',
        orderIndex: 0,
      ),
    );
    await tag.upsert(
      TagsCompanion.insert(id: 'tag-1', name: '重要', colorArgb: 0xFFF44336),
    );

    await dispatcher.dispatchAll([
      CreateTaskCommand(
        taskId: 'task-full',
        title: '字段填满的任务',
        kind: TaskKind.staged,
        timeZoneId: 'America/New_York',
        note: '带备注',
        categoryId: 'cat-1',
        priority: TaskPriority.urgent,
        planDate: const PlanDate(2026, 3, 10),
        startMinute: MinuteOfDay.of(9, 30),
        endDate: const PlanDate(2026, 3, 12),
        endMinute: MinuteOfDay.of(17, 0),
        colorArgb: 0xFF4CAF50,
        icon: 'star',
        sortOrder: 1.5,
      ),
      const CreateTaskCommand(
        taskId: 'task-recurring',
        title: '每周重复',
        kind: TaskKind.single,
        timeZoneId: 'Asia/Shanghai',
        recurrenceRule: 'RRULE:FREQ=WEEKLY;BYDAY=MO,WE',
      ),
      const CreateTaskCommand(
        taskId: 'task-deleted',
        title: '已删除的',
        kind: TaskKind.single,
        timeZoneId: 'Etc/UTC',
      ),
      const ReplaceStagesCommand(
        taskId: 'task-full',
        stages: [
          StageSpec(
            id: 'stage-0',
            title: '第一步',
            orderIndex: 0,
            startOffsetMinutes: 0,
            durationMinutes: 90,
            colorArgb: 0xFF9C27B0,
          ),
          StageSpec(id: 'stage-1', title: '第二步', orderIndex: 1),
        ],
      ),
      const ArchiveTaskCommand('task-recurring'),
      // 墓碑必须能被导出，否则导入方无从知道它被删了。
      const DeleteTaskCommand('task-deleted'),
    ]);

    await taskTag.upsert(
      TaskTagsCompanion.insert(taskId: 'task-full', tagId: 'tag-1'),
    );

    await setting.upsert(
      SettingsCompanion.insert(
        key: 'behavior.autoStartOnFirstStage',
        valueJson: 'true',
        scope: 'global',
      ),
    );
    // device 域**不该被导出** —— 设备本地的东西同步到别的设备没有意义。
    await setting.upsert(
      SettingsCompanion.insert(
        key: 'device.lastOpenedView',
        valueJson: '"timeline"',
        scope: 'device',
      ),
    );

    // 二次编码列：直接写库，因为 V1 的命令不产出它（只有导入 .ics 会）。
    await db.customStatement(
      'UPDATE tasks SET recurrence_ex_dates = ? WHERE id = ?',
      ['["2026-03-16","2026-03-23"]', 'task-recurring'],
    );
  }

  Future<Map<String, Object?>> exportNow() => service.export(
    appVersion: '1.0.0',
    deviceId: 'device-A',
    exportedAt: _exportedAt,
  );

  group('导出的形状', () {
    test('顶层字段齐全，counts 与实际条数一致', () async {
      await seed();
      final bundle = await exportNow();

      expect(bundle['formatVersion'], kExportFormatVersion);
      expect(bundle['schemaVersion'], db.schemaVersion);
      expect(bundle['appVersion'], '1.0.0');
      expect(bundle['exportedAt'], _exportedAt.millisecondsSinceEpoch);
      expect(bundle['deviceId'], 'device-A');

      final data = bundle['data']! as Map<String, Object?>;
      final counts = bundle['counts']! as Map<String, Object?>;
      for (final section in kExportSections.keys) {
        expect(data.containsKey(section), isTrue, reason: '缺少 data.$section');
        expect(
          counts[section],
          (data[section]! as List).length,
          reason: 'counts.$section 与实际不符',
        );
      }
    });

    test('墓碑行照常导出', () async {
      // 不导的话，恢复备份会让已删的任务集体复活。
      await seed();
      final data = (await exportNow())['data']! as Map<String, Object?>;
      final tasks = (data['tasks']! as List).cast<Map<String, Object?>>();

      final deleted = tasks.where((t) => t['deletedAt'] != null).toList();
      expect(deleted.length, 1);
      expect(deleted.single['id'], 'task-deleted');
    });

    test('settings 只导 global，device 域不出现', () async {
      await seed();
      final data = (await exportNow())['data']! as Map<String, Object?>;
      final settings = (data['settings']! as List).cast<Map<String, Object?>>();

      expect(settings.map((s) => s['key']), ['behavior.autoStartOnFirstStage']);
      expect(settings.every((s) => s['scope'] == 'global'), isTrue);
    });

    test('字段名是 lowerCamelCase，与列名逐字段对应', () async {
      // 服务端按 schema 解析，键名对不上就全盘失败。
      await seed();
      final data = (await exportNow())['data']! as Map<String, Object?>;
      final task = (data['tasks']! as List).first as Map<String, Object?>;

      expect(task.containsKey('timeZoneId'), isTrue);
      expect(task.containsKey('time_zone_id'), isFalse);
      expect(task.containsKey('recurrenceExDates'), isTrue);
      expect(task.containsKey('statusBeforeArchive'), isTrue);
      // 信封也照常导出 —— V3 的冲突解析要用。
      expect(task.containsKey('lastWriterId'), isTrue);
      expect(task.containsKey('revision'), isTrue);
    });

    test('二次编码列在导出里仍是字符串，不是数组', () async {
      // 这一列的约定是「TEXT 里放 JSON 串」。若导出时顺手解开成数组，
      // schema 上的 contentMediaType 标注就与实际不符，服务端会解析失败。
      await seed();
      final data = (await exportNow())['data']! as Map<String, Object?>;
      final tasks = (data['tasks']! as List).cast<Map<String, Object?>>();
      final recurring = tasks.firstWhere((t) => t['id'] == 'task-recurring');

      expect(recurring['recurrenceExDates'], isA<String>());
      expect(jsonDecode(recurring['recurrenceExDates']! as String), [
        '2026-03-16',
        '2026-03-23',
      ]);
    });
  });

  group('往返：导出 → 清库 → 导入 → 逐表逐字段比对', () {
    test('全部业务表逐行逐列相等', () async {
      await seed();
      final before = await snapshot(db);
      final bundle = await exportNow();

      // 走真正的文本编解码，而不是把 Map 直接传回去 ——
      // 后者测不出「值不是合法 JSON 类型」这类问题。
      final restored = decodeExportBundle(encodeExportBundle(bundle));
      await service.import(restored);

      final after = await snapshot(db);
      for (final table in _tables) {
        if (table == 'settings') continue; // device 域不导出，单独断言
        expect(after[table], before[table], reason: '$table 往返后不一致');
      }
    });

    test('device 域配置在往返后**丢失** —— 这是设计如此，不是缺陷', () async {
      // 记下来，免得将来有人把它当 bug「修」掉：
      // 设备本地的配置（上次打开哪个视图之类）跟着备份走没有意义，
      // 换台设备恢复反而会覆盖掉那台设备自己的偏好。
      await seed();
      final bundle = await exportNow();
      await service.import(bundle);

      final rows = await db
          .customSelect('SELECT key, scope FROM settings ORDER BY key')
          .get();
      expect(rows.map((r) => r.read<String>('key')), [
        'behavior.autoStartOnFirstStage',
      ]);
    });

    test('往返两次结果稳定（幂等）', () async {
      await seed();
      final first = await exportNow();
      await service.import(first);
      final second = await exportNow();
      expect(
        encodeExportBundle(second),
        encodeExportBundle(first),
        reason: '导入再导出应得到同一份包',
      );
    });
  });

  group('坏包不写进库', () {
    test('格式版本不匹配时拒绝，且库没被清空', () async {
      // **校验必须在清库之前**：一半写进去再报错，用户的库就成了半截状态，
      // 而他刚刚才被清空。
      await seed();
      final before = await snapshot(db);
      final bad = Map<String, Object?>.from(await exportNow())
        ..['formatVersion'] = 999;

      await expectLater(
        service.import(bad),
        throwsA(isA<ExportFormatException>()),
      );
      expect(await snapshot(db), before, reason: '拒绝的包不该动到库');
    });

    test('counts 与实际条数对不上时拒绝（包被截断）', () async {
      await seed();
      final bundle = await exportNow();
      final counts = Map<String, Object?>.from(bundle['counts']! as Map)
        ..['tasks'] = 999;
      final bad = Map<String, Object?>.from(bundle)..['counts'] = counts;

      await expectLater(
        service.import(bad),
        throwsA(isA<ExportFormatException>()),
      );
    });

    test('缺少 data 段时拒绝', () async {
      await expectLater(
        service.import({'formatVersion': 1}),
        throwsA(isA<ExportFormatException>()),
      );
    });

    test('顶层不是 JSON 对象时拒绝', () {
      expect(
        () => decodeExportBundle('[1,2,3]'),
        throwsA(isA<ExportFormatException>()),
      );
    });
  });

  group('产出供独立脚本校验的样例', () {
    test('写出 build/export-sample.json', () async {
      // 这份文件由 tool/validate_export.py（Python + 标准 jsonschema）校验。
      // **那一步才是「服务端可独立解析」的证据** ——
      // Dart 侧自己读自己写的东西证明不了任何事。
      await seed();
      final bundle = await exportNow();

      final out = File('build/export-sample.json');
      await out.parent.create(recursive: true);
      await out.writeAsString(encodeExportBundle(bundle));

      expect(out.existsSync(), isTrue);
      // 前提断言：样例得有内容，否则 schema 校验是空对空。
      final data = bundle['data']! as Map<String, Object?>;
      expect((data['tasks']! as List).length, 3);
      expect((data['stages']! as List).length, 2);
      expect((data['taskTags']! as List).length, 1);
    });
  });
}

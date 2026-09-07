/// Drift 行 ⇄ 领域实体的转换契约。
///
/// **这个文件刻意不以往返测试为主。**
///
/// 往返测试（`entity → row → entity` 相等）在 mapper 上有个致命盲区：
/// 把两个同类型字段搬反了 —— 比如 `note` 写进 `icon` 列、`icon` 读回 `note` ——
/// **往返照样通过**，因为两个方向反得一致。数据库里的列是错的，
/// 而这件事只有在导出、同步或服务端解析时才暴露。
///
/// 所以主力是**逐列断言**：每个字段给一个独一无二的哨兵值，
/// 写进库后逐列核对。往返只作为补充。
@TestOn('vm')
library;

import 'dart:convert';

// drift 的 isNull / isNotNull（SQL 构造）与 matcher 的同名匹配器冲突。
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/data/database/app_database.dart';
import 'package:planning_assistant/data/database/dao/synced_dao.dart';
import 'package:planning_assistant/data/database/dao/table_daos.dart';
import 'package:planning_assistant/data/mappers/task_mapper.dart';
import 'package:planning_assistant/domain/entities/stage.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/value_objects/recurrence.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';

const _writer = FixedWriterIdentity('device-A');
final _now = DateTime.utc(2026, 3, 8, 12);
DateTime _clock() => _now;

/// 每个字段一个**互不相同**的值。
///
/// 全用同一个值（比如所有字符串都填 'x'）的话，字段搬反了照样对得上 ——
/// 那种夹具能让最严的逐列断言也变成摆设。
final _fullTask = Task(
  id: 'task-id-1',
  title: '标题值',
  note: '备注值',
  kind: TaskKind.staged,
  categoryId: 'category-id-1',
  priority: TaskPriority.urgent,
  status: TaskStatus.inProgress,
  statusBeforeArchive: null,
  isAllDay: false,
  planDate: const PlanDate(2026, 3, 8),
  startMinute: MinuteOfDay.of(9, 30),
  endDate: const PlanDate(2026, 3, 10),
  endMinute: MinuteOfDay.of(17, 45),
  timeZoneId: 'America/New_York',
  recurrence: null,
  recurrenceExDates: const ['2026-03-15', '2026-03-22'],
  splitFromTaskId: 'split-from-id-1',
  colorArgb: 0xFF112233,
  icon: '图标值',
  sortOrder: 12.5,
  completedAt: null,
  archivedAt: DateTime.utc(2026, 3, 9, 8),
  deletedAt: DateTime.utc(2026, 3, 9, 9),
);

void main() {
  late AppDatabase db;
  late TaskDao taskDao;
  late StageDao stageDao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    taskDao = TaskDao(db, _writer, _clock);
    stageDao = StageDao(db, _writer, _clock);
    // 外键是真开着的，夹具引用的分类必须先存在。
    await CategoryDao(db, _writer, _clock).upsert(
      CategoriesCompanion.insert(
        id: 'category-id-1',
        name: '分类',
        colorArgb: 1,
        icon: 'work',
        orderIndex: 0,
      ),
    );
  });
  tearDown(() => db.close());

  Future<Map<String, Object?>> rawRow(
    String table,
    String pk,
    String id,
  ) async {
    final row = await db
        .customSelect(
          'SELECT * FROM $table WHERE $pk = ?',
          variables: [Variable<String>(id)],
        )
        .getSingle();
    return row.data;
  }

  group('逐列断言：每个字段落到正确的列上', () {
    test('tasks 的每一列都是预期值', () async {
      // 这是本文件的主力用例。任意两个同类型字段搬反，这里必红。
      final archived = _fullTask.copyWith(
        statusBeforeArchive: TaskStatus.inProgress,
      );
      await taskDao.upsert(archived.toCompanion());
      final raw = await rawRow('tasks', 'id', 'task-id-1');

      expect(raw['id'], 'task-id-1');
      expect(raw['title'], '标题值');
      expect(raw['note'], '备注值');
      expect(raw['kind'], 'staged');
      expect(raw['category_id'], 'category-id-1');
      expect(raw['priority'], 4, reason: 'urgent = 4');
      expect(raw['status'], 'inProgress');
      expect(raw['status_before_archive'], 'inProgress');
      expect(raw['is_all_day'], 0);
      expect(raw['plan_date'], '2026-03-08');
      expect(raw['start_minute'], 9 * 60 + 30);
      expect(raw['end_date'], '2026-03-10');
      expect(raw['end_minute'], 17 * 60 + 45);
      expect(raw['time_zone_id'], 'America/New_York');
      expect(raw['recurrence_rule'], isNull);
      expect(raw['recurrence_ex_dates'], '["2026-03-15","2026-03-22"]');
      expect(raw['split_from_task_id'], 'split-from-id-1');
      expect(raw['color_argb'], 0xFF112233);
      expect(raw['icon'], '图标值');
      expect(raw['sort_order'], 12.5);
      expect(raw['completed_at'], isNull);
      expect(
        raw['archived_at'],
        DateTime.utc(2026, 3, 9, 8).millisecondsSinceEpoch,
      );
      expect(
        raw['deleted_at'],
        DateTime.utc(2026, 3, 9, 9).millisecondsSinceEpoch,
      );
    });

    test('stages 的每一列都是预期值', () async {
      await taskDao.upsert(
        const Task(
          id: 'parent',
          title: '母任务',
          kind: TaskKind.staged,
          timeZoneId: 'Asia/Shanghai',
        ).toCompanion(),
      );
      final s = Stage(
        id: 'stage-id-1',
        taskId: 'parent',
        title: '阶段标题',
        orderIndex: 3,
        startOffsetMinutes: 120,
        durationMinutes: 45,
        colorArgb: 0xFF445566,
        status: TaskStatus.skipped,
        completedAt: null,
        deletedAt: DateTime.utc(2026, 3, 9),
      );
      await stageDao.upsert(s.toCompanion());
      final raw = await rawRow('stages', 'id', 'stage-id-1');

      expect(raw['task_id'], 'parent');
      expect(raw['title'], '阶段标题');
      expect(raw['order_index'], 3);
      expect(raw['start_offset_minutes'], 120);
      expect(raw['duration_minutes'], 45, reason: '与 start_offset 不能搞反');
      expect(raw['color_argb'], 0xFF445566);
      expect(raw['status'], 'skipped');
      expect(raw['completed_at'], isNull);
      expect(
        raw['deleted_at'],
        DateTime.utc(2026, 3, 9).millisecondsSinceEpoch,
      );
    });
  });

  group('覆盖完整性', () {
    test('mapper 搬运了 tasks 表除信封外的每一列', () async {
      // 表加了列却忘了在 mapper 里搬 → 该列永远是默认值，
      // 功能上表现为「这个字段存不进去」，但不报任何错。
      await taskDao.upsert(_fullTask.toCompanion());
      final companionColumns = _fullTask
          .toCompanion()
          .toColumns(false)
          .keys
          .toSet();

      final info = await db.customSelect('PRAGMA table_info(tasks)').get();
      final tableColumns = info.map((r) => r.read<String>('name')).toSet();

      final missed = tableColumns
          .difference(companionColumns)
          .difference(kEnvelopeOnlyColumns);
      expect(
        missed,
        isEmpty,
        reason:
            'mapper 漏搬了这些列：$missed\n'
            '若是有意不搬（如新增的簿记列），请加进 kEnvelopeOnlyColumns',
      );
    });

    test('mapper 没有写入信封列（那是 DAO 的职责）', () async {
      // 两边都写会互相覆盖，且哪边赢取决于调用顺序 —— 最难查的一类缺陷。
      final companionColumns = _fullTask
          .toCompanion()
          .toColumns(false)
          .keys
          .toSet();
      expect(
        companionColumns.intersection(kEnvelopeOnlyColumns),
        isEmpty,
        reason: '信封列由 SyncedDao.upsert() 盖章，mapper 不该碰',
      );
    });

    test('stages 同样无遗漏', () async {
      const s = Stage(id: 's', taskId: 't', title: 'x', orderIndex: 0);
      final companionColumns = s.toCompanion().toColumns(false).keys.toSet();
      final info = await db.customSelect('PRAGMA table_info(stages)').get();
      final tableColumns = info.map((r) => r.read<String>('name')).toSet();

      expect(
        tableColumns
            .difference(companionColumns)
            .difference(kEnvelopeOnlyColumns),
        isEmpty,
      );
    });
  });

  group('往返（作为补充，不作主力）', () {
    test('完整任务往返后各字段相等', () async {
      await taskDao.upsert(_fullTask.toCompanion());
      final back = (await taskDao.getAllIncludingDeleted()).single.toEntity();

      expect(back.id, _fullTask.id);
      expect(back.title, _fullTask.title);
      expect(back.note, _fullTask.note);
      expect(back.kind, _fullTask.kind);
      expect(back.categoryId, _fullTask.categoryId);
      expect(back.priority, _fullTask.priority);
      expect(back.status, _fullTask.status);
      expect(back.isAllDay, _fullTask.isAllDay);
      expect(back.planDate, _fullTask.planDate);
      expect(back.startMinute, _fullTask.startMinute);
      expect(back.endDate, _fullTask.endDate);
      expect(back.endMinute, _fullTask.endMinute);
      expect(back.timeZoneId, _fullTask.timeZoneId);
      expect(back.recurrenceExDates, _fullTask.recurrenceExDates);
      expect(back.splitFromTaskId, _fullTask.splitFromTaskId);
      expect(back.colorArgb, _fullTask.colorArgb);
      expect(back.icon, _fullTask.icon);
      expect(back.sortOrder, _fullTask.sortOrder);
      expect(back.archivedAt, _fullTask.archivedAt);
      expect(back.deletedAt, _fullTask.deletedAt);
    });

    test('全空可选字段的任务往返后仍全空', () async {
      // 空值路径与满值路径走的是不同分支，必须各测一遍。
      const minimal = Task(
        id: 'minimal',
        title: '最简',
        kind: TaskKind.single,
        timeZoneId: 'Etc/UTC',
      );
      await taskDao.upsert(minimal.toCompanion());
      final back = (await taskDao.getAll()).single.toEntity();

      expect(back.note, isNull);
      expect(back.categoryId, isNull);
      expect(back.planDate, isNull);
      expect(back.startMinute, isNull);
      expect(back.recurrence, isNull);
      expect(back.recurrenceExDates, isEmpty);
      expect(back.completedAt, isNull);
      expect(back.archivedAt, isNull);
      expect(back.deletedAt, isNull);
      expect(back.priority, TaskPriority.normal, reason: '默认值');
      expect(back.status, TaskStatus.pending);
    });

    test('重复规则往返后是规范形', () async {
      final t = Task(
        id: 'recurring',
        title: '每天',
        kind: TaskKind.single,
        timeZoneId: 'Asia/Shanghai',
        recurrence: Recurrence.parse('RRULE:FREQ=DAILY;COUNT=5'),
      );
      await taskDao.upsert(t.toCompanion());
      final raw = await rawRow('tasks', 'id', 'recurring');

      // 库里存的必须是 encodeRrule() 的规范形，不是外部原串
      // （recurrence-engine §2.3）。
      expect(raw['recurrence_rule'], t.recurrence!.canonical);
      final back = (await taskDao.getAll()).single.toEntity();
      expect(back.recurrence!.canonical, t.recurrence!.canonical);
    });
  });

  group('坏数据不静默吞掉', () {
    test('未知的 status 串抛异常，而不是回落成 pending', () async {
      // 静默回落会把「数据坏了」变成「用户的任务莫名变回待办」，
      // 且再也查不出何时坏的。
      await taskDao.upsert(_fullTask.toCompanion());
      await db.customStatement(
        "UPDATE tasks SET status = 'somethingElse' WHERE id = 'task-id-1'",
      );
      final row = (await taskDao.getAllIncludingDeleted()).single;
      expect(row.toEntity, throwsA(isA<FormatException>()));
    });

    test('未知的 kind / priority 同样抛异常', () async {
      await taskDao.upsert(_fullTask.toCompanion());
      await db.customStatement(
        "UPDATE tasks SET kind = 'weird' WHERE id = 'task-id-1'",
      );
      expect(
        (await taskDao.getAllIncludingDeleted()).single.toEntity,
        throwsA(isA<FormatException>()),
      );

      await db.customStatement(
        "UPDATE tasks SET kind = 'single', priority = 99 WHERE id = 'task-id-1'",
      );
      expect(
        (await taskDao.getAllIncludingDeleted()).single.toEntity,
        throwsA(isA<FormatException>()),
      );
    });

    test('recurrenceExDates 不是 JSON 数组时抛 FormatException', () async {
      await taskDao.upsert(_fullTask.toCompanion());
      await db.customStatement(
        'UPDATE tasks SET recurrence_ex_dates = \'{"a":1}\' '
        "WHERE id = 'task-id-1'",
      );
      expect(
        (await taskDao.getAllIncludingDeleted()).single.toEntity,
        throwsA(isA<FormatException>()),
      );
    });

    test('recurrenceExDates 是二次编码的 JSON —— 列里存的是字符串', () async {
      // data-model §6 对这一列有专门标注：服务端解析时需要再 JSON.parse 一次。
      // 这条把那个约定钉住。
      await taskDao.upsert(_fullTask.toCompanion());
      final raw = await rawRow('tasks', 'id', 'task-id-1');
      final stored = raw['recurrence_ex_dates']! as String;
      expect(jsonDecode(stored), ['2026-03-15', '2026-03-22']);
    });
  });
}

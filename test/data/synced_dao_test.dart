/// `SyncedDao` 的契约 —— **对每一张可同步表逐条验证**。
///
/// 这个文件的形状是刻意的：不是「给 TaskDao 写几个用例」，而是把 10 张表
/// 全列进一张表格，每条契约对全部 10 张跑一遍。理由很直接 ——
/// 漏掉墓碑过滤、漏盖信封、漏写 outbox 这三件事都**不报错**，
/// 而它们是按表出现的：抽查一张表通过，说明不了另外九张。
///
/// 新增可同步表时若忘了接 `SyncedDao`，`entityType 全集与 DAO 一一对应`
/// 这条会立刻变红。
@TestOn('vm')
library;

// drift 也导出 isNull / isNotNull（SQL 构造），与 matcher 的同名匹配器冲突。
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/clock.dart';
import 'package:planning_assistant/data/database/app_database.dart';
import 'package:planning_assistant/data/database/dao/synced_dao.dart';
import 'package:planning_assistant/data/database/dao/table_daos.dart';

/// 固定时钟。
///
/// 用 `DateTime.now()` 的话，`updatedAt` 的断言只能写成「大于某个值」，
/// 那种断言在 `updatedAt` 完全没被更新时**照样通过**（旧值也大于起始值）。
class _FakeClock implements Clock {
  DateTime value = DateTime.utc(2026, 3, 8, 12);

  @override
  DateTime nowUtc() => value;

  int get ms => value.millisecondsSinceEpoch;
  void advance(Duration d) => value = value.add(d);
}

/// 一张表的测试装配：怎么建 DAO、怎么造一行、主键是什么。
typedef DaoCase = ({
  String label,
  SyncedDao<Table, DataClass> Function() dao,
  Insertable<DataClass> Function(String id) makeRow,
  String entityType,
});

void main() {
  late AppDatabase db;
  late _FakeClock clock;
  const writer = FixedWriterIdentity('device-A');

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = _FakeClock();
  });
  tearDown(() => db.close());

  test('对照组：显式带 deletedAt 的 upsert 仍然打墓碑（tasks）', () async {
    // 少了它，一个「upsert 一律清空 deletedAt」的实现能让上面那组
    // 「墓碑复活」全绿 —— 而那会把 `_replaceStages` 打的墓碑全复活，
    // 用户删掉的阶段会集体诈尸。
    //
    // 只验一张表：那条规则住在共用的 `SyncedDao.upsert` 里，
    // 一张表验得到就够；上面那组「复活」才需要逐表跑
    // （因为每张表的 companion 带不带 deletedAt 各不相同）。
    final dao = TaskDao(db, writer, clock);
    await dao.upsert(
      TasksCompanion.insert(
        id: 'buried-1',
        title: '要埋掉的',
        kind: 'single',
        timeZoneId: 'Asia/Shanghai',
      ),
    );
    await dao.softDelete('buried-1');

    await dao.upsert(
      TasksCompanion.insert(
        id: 'buried-1',
        title: '要埋掉的',
        kind: 'single',
        timeZoneId: 'Asia/Shanghai',
        deletedAt: Value(DateTime.utc(2026).millisecondsSinceEpoch),
      ),
    );

    expect(
      (await dao.getAll()).map(dao.primaryKeyOf),
      isNot(contains('buried-1')),
      reason: '显式传的墓碑被 upsert 清掉了',
    );
  });

  // 每张可同步表一条。**加表必须加这里**，否则下面的一一对应断言会红。
  List<DaoCase> cases() => [
    (
      label: 'tasks',
      dao: () => TaskDao(db, writer, clock),
      makeRow: (id) => TasksCompanion.insert(
        id: id,
        title: '任务 $id',
        kind: 'single',
        timeZoneId: 'Asia/Shanghai',
      ),
      entityType: EntityTypes.task,
    ),
    (
      label: 'categories',
      dao: () => CategoryDao(db, writer, clock),
      makeRow: (id) => CategoriesCompanion.insert(
        id: id,
        name: '分类 $id',
        colorArgb: 1,
        icon: 'work',
        orderIndex: 0,
      ),
      entityType: EntityTypes.category,
    ),
    (
      label: 'tags',
      dao: () => TagDao(db, writer, clock),
      makeRow: (id) =>
          TagsCompanion.insert(id: id, name: '标签 $id', colorArgb: 2),
      entityType: EntityTypes.tag,
    ),
    (
      label: 'settings',
      dao: () => SettingDao(db, writer, clock),
      makeRow: (id) => SettingsCompanion.insert(
        key: id,
        valueJson: '{"v":1}',
        scope: 'global',
      ),
      entityType: EntityTypes.setting,
    ),
    (
      label: 'stages',
      dao: () => StageDao(db, writer, clock),
      makeRow: (id) => StagesCompanion.insert(
        id: id,
        taskId: _seedTaskId,
        title: '阶段 $id',
        orderIndex: 0,
      ),
      entityType: EntityTypes.stage,
    ),
    (
      label: 'checklist_items',
      dao: () => ChecklistItemDao(db, writer, clock),
      makeRow: (id) => ChecklistItemsCompanion.insert(
        id: id,
        taskId: _seedTaskId,
        title: '子项 $id',
        orderIndex: 0,
      ),
      entityType: EntityTypes.checklistItem,
    ),
    (
      label: 'occurrence_overrides',
      dao: () => OccurrenceOverrideDao(db, writer, clock),
      makeRow: (id) => OccurrenceOverridesCompanion.insert(
        id: id,
        taskId: _seedTaskId,
        occurrenceKey: '2026-03-08T09:00-$id',
        action: 'skip',
      ),
      entityType: EntityTypes.occurrenceOverride,
    ),
    (
      label: 'stage_occurrence_states',
      dao: () => StageOccurrenceStateDao(db, writer, clock),
      makeRow: (id) => StageOccurrenceStatesCompanion.insert(
        id: id,
        taskId: _seedTaskId,
        stageId: _seedStageId,
        occurrenceKey: '2026-03-08T09:00-$id',
        status: 'pending',
      ),
      entityType: EntityTypes.stageOccurrenceState,
    ),
    (
      label: 'reminders',
      dao: () => ReminderDao(db, writer, clock),
      makeRow: (id) => RemindersCompanion.insert(
        id: id,
        taskId: _seedTaskId,
        kind: 'relativeToStart',
        offsetMinutes: const Value(-15),
      ),
      entityType: EntityTypes.reminder,
    ),
  ];

  /// 依赖任务/阶段存在的表需要先铺底 —— 外键是真开着的。
  Future<void> seedParents() async {
    await TaskDao(db, writer, clock).upsert(
      TasksCompanion.insert(
        id: _seedTaskId,
        title: '母任务',
        kind: 'staged',
        timeZoneId: 'Asia/Shanghai',
      ),
    );
    await StageDao(db, writer, clock).upsert(
      StagesCompanion.insert(
        id: _seedStageId,
        taskId: _seedTaskId,
        title: '母阶段',
        orderIndex: 0,
      ),
    );
    // 铺底也走 DAO，于是也写了 outbox。后面的断言要减掉这两条。
  }

  Future<int> changeLogCount() async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS c FROM change_log')
        .getSingle();
    return row.read<int>('c');
  }

  group('墓碑过滤（data-model §5）', () {
    for (final c in cases()) {
      test('${c.label}：软删除后不再出现在 getAll()', () async {
        await seedParents();
        final dao = c.dao();
        await dao.upsert(c.makeRow('live-1'));
        await dao.upsert(c.makeRow('dead-1'));

        expect((await dao.getAll()).length, greaterThanOrEqualTo(2));

        expect(await dao.softDelete('dead-1'), isTrue);

        final ids = (await dao.getAll()).map(dao.primaryKeyOf).toSet();
        expect(ids, contains('live-1'));
        expect(
          ids,
          isNot(contains('dead-1')),
          reason: '${c.label} 的读取漏了 deletedAt IS NULL',
        );
      });

      test('${c.label}：**再次 upsert 会把墓碑复活**', () async {
        // ## 这条是真缺陷补出来的
        //
        // `upsert` 原来只更新 companion 里带的那几列，
        // 而多数 companion 不带 `deletedAt` —— 于是软删过的行再写一次，
        // 数据写进去了、墓碑还在，**每一次读取都把它过滤掉**。
        //
        // 在**主键是派生的**那几张表上这是常规路径，不是边角情况：
        // 例外的行 id 是 `taskId#occurrenceKey`，
        // 「完成 → 取消完成 → 再完成」写的就是同一行。
        // 用户报的就是它：取消完成之后再点完成，界面上毫无反应。
        await seedParents();
        final dao = c.dao();
        await dao.upsert(c.makeRow('zombie-1'));
        await dao.softDelete('zombie-1');
        expect(
          (await dao.getAll()).map(dao.primaryKeyOf),
          isNot(contains('zombie-1')),
          reason: '前提：它现在是墓碑',
        );

        await dao.upsert(c.makeRow('zombie-1'));

        expect(
          (await dao.getAll()).map(dao.primaryKeyOf),
          contains('zombie-1'),
          reason: '${c.label} 再写一次之后仍然读不出来 —— 墓碑没被复活',
        );
      });

      test('${c.label}：软删除不物理删行，导出仍能看到墓碑', () async {
        // 物理删除会让「删除」这件事无法同步 —— 对端只看到「这条还在」。
        await seedParents();
        final dao = c.dao();
        await dao.upsert(c.makeRow('x-1'));
        await dao.softDelete('x-1');

        final all = await dao.getAllIncludingDeleted();
        expect(
          all.map(dao.primaryKeyOf),
          contains('x-1'),
          reason: '${c.label} 的墓碑被物理删掉了',
        );
      });
    }
  });

  group('信封盖章', () {
    for (final c in cases()) {
      test('${c.label}：新行 revision=1，createdAt/updatedAt/writer 均落值', () async {
        await seedParents();
        final dao = c.dao();
        await dao.upsert(c.makeRow('e-1'));

        final env = await _envelope(db, dao, 'e-1');
        expect(env.revision, 1);
        expect(env.createdAt, clock.ms);
        expect(env.updatedAt, clock.ms);
        expect(env.lastWriterId, 'device-A');
      });

      test('${c.label}：再次写入 revision 递增、createdAt 不变、updatedAt 刷新', () async {
        // createdAt 被覆盖的话，「这条何时建的」永久丢失，且 V3 的冲突
        // 解析拿它做兜底比较。
        await seedParents();
        final dao = c.dao();
        await dao.upsert(c.makeRow('e-2'));
        final first = await _envelope(db, dao, 'e-2');

        clock.advance(const Duration(hours: 3));
        await dao.upsert(c.makeRow('e-2'));
        final second = await _envelope(db, dao, 'e-2');

        expect(second.revision, 2);
        expect(second.createdAt, first.createdAt, reason: 'createdAt 不该被覆盖');
        expect(second.updatedAt, clock.ms);
        expect(second.updatedAt, greaterThan(first.updatedAt));
      });

      test('${c.label}：软删除也递增 revision 并刷新 updatedAt', () async {
        // 删除同样是一次写入。不递增的话对端无法判断「删除」与「旧状态」谁新。
        await seedParents();
        final dao = c.dao();
        await dao.upsert(c.makeRow('e-3'));

        clock.advance(const Duration(minutes: 5));
        await dao.softDelete('e-3');

        final env = await _envelope(db, dao, 'e-3');
        expect(env.revision, 2);
        expect(env.updatedAt, clock.ms);
        expect(env.deletedAt, clock.ms);
      });
    }
  });

  group('outbox 写入（data-model §3.11）', () {
    for (final c in cases()) {
      test('${c.label}：每次写入恰好追加一行 change_log', () async {
        await seedParents();
        final before = await changeLogCount();
        final dao = c.dao();

        await dao.upsert(c.makeRow('o-1'));
        expect(await changeLogCount(), before + 1);

        await dao.upsert(c.makeRow('o-1'));
        expect(await changeLogCount(), before + 2, reason: '更新也要记');

        await dao.softDelete('o-1');
        expect(await changeLogCount(), before + 3, reason: '删除也要记');
      });

      test('${c.label}：outbox 行的 entityType / op / payload 正确', () async {
        await seedParents();
        final dao = c.dao();
        await dao.upsert(c.makeRow('o-2'));
        await dao.softDelete('o-2');

        final rows = await db.customSelect('''
          SELECT entity_type, entity_id, op, payload_json, occurred_at, device_id
          FROM change_log WHERE entity_id = 'o-2' ORDER BY seq
        ''').get();

        expect(rows.length, 2);
        expect(rows[0].read<String>('entity_type'), c.entityType);
        expect(rows[0].read<String>('op'), 'upsert');
        expect(
          rows[0].read<String?>('payload_json'),
          isNotNull,
          reason: 'upsert 必须带整行 JSON，否则回放无从还原',
        );
        expect(rows[0].read<String>('device_id'), 'device-A');

        expect(rows[1].read<String>('op'), 'delete');
        expect(
          rows[1].read<String?>('payload_json'),
          isNull,
          reason: 'delete 不需要载荷，墓碑信息在行里',
        );
      });
    }
  });

  group('事务性', () {
    test('outbox 写入失败时，数据写入一并回滚', () async {
      // 分开写的话中途失败会留下「数据变了但 outbox 没记」——
      // 那条变更永远不会被推送，且回放一致性测试要很久以后才发现。
      final dao = TaskDao(db, writer, clock);
      await dao.upsert(
        TasksCompanion.insert(
          id: 't-ok',
          title: '正常',
          kind: 'single',
          timeZoneId: 'Asia/Shanghai',
        ),
      );

      // 让 change_log 的插入必然失败：device_id 是 NOT NULL，
      // 用一个空 deviceId 不会失败，所以改用触发器制造失败。
      await db.customStatement('''
        CREATE TRIGGER fail_changelog BEFORE INSERT ON change_log
        BEGIN SELECT RAISE(ABORT, 'boom'); END
      ''');

      await expectLater(
        dao.upsert(
          TasksCompanion.insert(
            id: 't-rollback',
            title: '应回滚',
            kind: 'single',
            timeZoneId: 'Asia/Shanghai',
          ),
        ),
        throwsA(anything),
      );

      await db.customStatement('DROP TRIGGER fail_changelog');
      final ids = (await dao.getAll()).map((r) => r.id).toSet();
      expect(ids, contains('t-ok'));
      expect(
        ids,
        isNot(contains('t-rollback')),
        reason: 'outbox 失败了，数据写入必须一起回滚',
      );
    });
  });

  group('结构守卫', () {
    test('EntityTypes 全集与实际 DAO 一一对应', () async {
      // 加了表却忘了接 SyncedDao / 忘了登记 entityType，在这里变红。
      // 联结表 task_tags 的主键是复合的，不进上面的参数化用例，单独核对。
      final covered = {
        ...cases().map((c) => c.entityType),
        EntityTypes.taskTag,
      };
      expect(
        covered,
        EntityTypes.all.toSet(),
        reason: 'EntityTypes.all 与实际 DAO 不一致',
      );
      expect(EntityTypes.all.length, 10);
      expect(
        EntityTypes.all.toSet().length,
        EntityTypes.all.length,
        reason: 'entityType 有重复 —— 导出格式的键会互相覆盖',
      );
    });

    test('联合主键的表调用 softDelete 会明确报错，而不是悄悄失败', () async {
      // task_tags 的主键是 (taskId, tagId)，单串 id 无从定位。
      // 这里必须抛，否则「删了个标签关联」会静默无效。
      await seedParents();
      final tagDao = TagDao(db, writer, clock);
      await tagDao.upsert(
        TagsCompanion.insert(id: 'tag-1', name: '标签', colorArgb: 1),
      );
      final dao = TaskTagDao(db, writer, clock);

      expect(
        () => dao.softDelete('$_seedTaskId:tag-1'),
        throwsA(isA<StateError>()),
      );
    });

    test('联合主键的表 upsert 可用（曾经不可用）', () async {
      // **这条是补漏。** 上面的参数化用例声称「覆盖每一张可同步表」，
      // 但 task_tags 因为主键是复合的，不符合 `makeRow(String id)` 的形状，
      // 被排除在外 —— 而缺陷恰恰就在那里：`upsert` 内部也走了
      // `_primaryKeyColumn()`（只支持单列），于是 TaskTagDao.upsert
      // **完全不可用**，一调就抛 StateError。
      //
      // 是导出往返测试先撞上的，不是这个文件。参数化用例的覆盖声明
      // 与实际覆盖范围之间的缺口，就是缺陷藏身的地方。
      await seedParents();
      await TagDao(
        db,
        writer,
        clock,
      ).upsert(TagsCompanion.insert(id: 'tag-1', name: '标签', colorArgb: 1));
      final dao = TaskTagDao(db, writer, clock);

      final before = await changeLogCount();
      await dao.upsert(
        TaskTagsCompanion.insert(taskId: _seedTaskId, tagId: 'tag-1'),
      );

      expect((await dao.getAll()).length, 1);
      expect(await changeLogCount(), before + 1, reason: '联结表也要写 outbox');

      // 复合键在 outbox 里拼成 `taskId:tagId`。
      final log = await db.customSelect('''
        SELECT entity_id FROM change_log
        WHERE entity_type = 'taskTag' ORDER BY seq DESC LIMIT 1
      ''').getSingle();
      expect(log.read<String>('entity_id'), '$_seedTaskId:tag-1');
    });

    test('联合主键的表重复 upsert 递增 revision 且不重复建行', () async {
      await seedParents();
      await TagDao(
        db,
        writer,
        clock,
      ).upsert(TagsCompanion.insert(id: 'tag-1', name: '标签', colorArgb: 1));
      final dao = TaskTagDao(db, writer, clock);
      final row = TaskTagsCompanion.insert(taskId: _seedTaskId, tagId: 'tag-1');

      await dao.upsert(row);
      clock.advance(const Duration(minutes: 1));
      await dao.upsert(row);

      expect((await dao.getAll()).length, 1, reason: '主键相同不该建出第二行');
      final env = await db
          .customSelect(
            '''
        SELECT revision, updated_at FROM task_tags
        WHERE task_id = ? AND tag_id = 'tag-1'
      ''',
            variables: [const Variable<String>(_seedTaskId)],
          )
          .getSingle();
      expect(env.read<int>('revision'), 2);
      expect(env.read<int>('updated_at'), clock.ms);
    });

    test('复合主键的各段不得含分隔符 —— 在写入时就拦住', () async {
      // 评审的观察项。`entityId` 是单列 TEXT，联结表把两个键拼成一串，
      // 回放时再按分隔符拆开 —— 拼得回去的前提是各段本身不含分隔符。
      //
      // 这条假设此前只活在注释里。UUID v7 确实不含 `:`，但「当下满足」
      // 不等于「以后也满足」（换 id 方案、导入外部数据都可能破坏它）。
      //
      // 拦在**写入**路径而不是回放路径：回放可能发生在几个月后、
      // 甚至另一台设备上，那时已经查不出是哪次写入种下的。
      await seedParents();
      await TagDao(db, writer, clock).upsert(
        TagsCompanion.insert(id: 'tag:with:colon', name: '坏 id', colorArgb: 1),
      );
      final dao = TaskTagDao(db, writer, clock);

      await expectLater(
        dao.upsert(
          TaskTagsCompanion.insert(
            taskId: _seedTaskId,
            tagId: 'tag:with:colon',
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('正常 id 不受影响（否则上面那条可能因「一律拒绝」而假绿）', () async {
      await seedParents();
      await TagDao(
        db,
        writer,
        clock,
      ).upsert(TagsCompanion.insert(id: 'tag-ok', name: '正常', colorArgb: 1));
      final dao = TaskTagDao(db, writer, clock);
      await dao.upsert(
        TaskTagsCompanion.insert(taskId: _seedTaskId, tagId: 'tag-ok'),
      );
      expect((await dao.getAll()).length, 1);
    });

    test('SyncedDao 用在无信封的表上会直接抛，而不是不过滤', () async {
      // 退化成「不过滤」比报错危险得多：查询照跑，只是墓碑全漏出来。
      final dao = _BadDao(db, writer, clock);
      expect(() => dao.getAll(), throwsA(isA<StateError>()));
    });
  });
}

const _seedTaskId = 'seed-task';
const _seedStageId = 'seed-stage';

typedef _Envelope = ({
  int createdAt,
  int updatedAt,
  int? deletedAt,
  int revision,
  String lastWriterId,
});

Future<_Envelope> _envelope(
  AppDatabase db,
  SyncedDao<Table, DataClass> dao,
  String id,
) async {
  final pk = dao.table.$primaryKey.first.name;
  final row = await db
      .customSelect(
        'SELECT created_at, updated_at, deleted_at, revision, last_writer_id '
        'FROM ${dao.table.actualTableName} WHERE $pk = ?',
        variables: [Variable<String>(id)],
      )
      .getSingle();
  return (
    createdAt: row.read<int>('created_at'),
    updatedAt: row.read<int>('updated_at'),
    deletedAt: row.read<int?>('deleted_at'),
    revision: row.read<int>('revision'),
    lastWriterId: row.read<String>('last_writer_id'),
  );
}

/// 故意接到一张没有信封的表上，用于验证基类会报错而不是退化。
class _BadDao
    extends SyncedDao<$ScheduledNotificationsTable, ScheduledNotificationRow> {
  _BadDao(super.db, super.writer, super.now);

  @override
  TableInfo<$ScheduledNotificationsTable, ScheduledNotificationRow> get table =>
      attachedDatabase.scheduledNotifications;

  @override
  String get entityType => 'scheduledNotification';

  @override
  String primaryKeyOf(ScheduledNotificationRow row) =>
      row.osNotificationId.toString();

  @override
  Map<String, Object?> toJson(ScheduledNotificationRow row) => row.toJson();
}

/// 回放一致性 —— **overview §6 里 V3 那一格的验收项**。
///
/// 「清库 → 按 seq 回放 outbox → 状态等价」。
///
/// 它验的不只是「回放能用」，更重要的是**没有写操作绕过命令管道**：
/// 绕过的写不留 change_log 行，回放后那部分数据就不见了。
/// 靠 code review 找绕过找不干净，靠这条能。
///
/// 「等价」在这里取最严的定义：**逐表逐列字节相等**。放宽成「大致一样」
/// 的话，信封没被正确记录这类问题会整个漏掉。
@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/data/database/app_database.dart';
import 'package:planning_assistant/data/database/dao/synced_dao.dart';
import 'package:planning_assistant/data/database/dao/table_daos.dart';
import 'package:planning_assistant/data/outbox/change_log_replayer.dart';
import 'package:planning_assistant/data/repositories/task_repository_impl.dart';
import 'package:planning_assistant/domain/commands/command_dispatcher.dart';
import 'package:planning_assistant/domain/commands/task_command.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';

const _writer = FixedWriterIdentity('device-A');

/// 可推进的时钟：每条命令的效果都带时刻，固定不动的话
/// 「updatedAt 有没有被正确记录」就无从分辨。
class _Clock {
  DateTime value = DateTime.utc(2026, 3, 8, 9);
  DateTime call() {
    value = value.add(const Duration(minutes: 1));
    return value;
  }
}

/// 参与比对的业务表。**change_log 自身不在内** —— 回放不重写日志。
const _businessTables = [
  'tasks',
  'stages',
  'checklist_items',
  'occurrence_overrides',
  'stage_occurrence_states',
  'reminders',
  'categories',
  'tags',
  'settings',
];

/// 整库快照：表名 → 逐行逐列的值。
Future<Map<String, List<Map<String, Object?>>>> snapshot(AppDatabase db) async {
  final result = <String, List<Map<String, Object?>>>{};
  for (final t in _businessTables) {
    final rows = await db.customSelect('SELECT * FROM $t ORDER BY rowid').get();
    result[t] = [for (final r in rows) Map<String, Object?>.from(r.data)];
  }
  return result;
}

void main() {
  late AppDatabase db;
  late _Clock clock;
  late CommandDispatcher dispatcher;
  late ChangeLogReplayer replayer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = _Clock();
    dispatcher = CommandDispatcher(
      DriftTaskRepository(db, _writer, clock.call),
      clock.call,
    );
    replayer = ChangeLogReplayer(db);
  });
  tearDown(() => db.close());

  /// 一段有代表性的命令序列：建、改、加阶段、完成、归档、删、恢复。
  ///
  /// 全是 create 的话，覆盖不到「同一行被改多次」这条最容易在回放里
  /// 出问题的路径（顺序错了就还原成中间某个版本）。
  Future<void> runScript() async {
    await CategoryDao(db, _writer, clock.call).upsert(
      CategoriesCompanion.insert(
        id: 'cat-1',
        name: '工作',
        colorArgb: 1,
        icon: 'work',
        orderIndex: 0,
      ),
    );

    await dispatcher.dispatchAll([
      const CreateTaskCommand(
        taskId: 't1',
        title: '写文档',
        kind: TaskKind.staged,
        timeZoneId: 'Asia/Shanghai',
        categoryId: 'cat-1',
        planDate: PlanDate(2026, 3, 10),
        startMinute: MinuteOfDay.midnight,
      ),
      const CreateTaskCommand(
        taskId: 't2',
        title: '每天跑步',
        kind: TaskKind.single,
        timeZoneId: 'Asia/Shanghai',
        recurrenceRule: 'RRULE:FREQ=DAILY',
      ),
      const CreateTaskCommand(
        taskId: 't3',
        title: '要删掉的',
        kind: TaskKind.single,
        timeZoneId: 'Etc/UTC',
      ),
      // 同一行改多次 —— 回放顺序错了就会还原成中间版本。
      const UpdateTaskFieldsCommand(taskId: 't1', title: '写设计文档'),
      const UpdateTaskFieldsCommand(taskId: 't1', note: '先列大纲'),
      const UpdateTaskFieldsCommand(taskId: 't1', note: null),
      const ReplaceStagesCommand(
        taskId: 't1',
        stages: [
          StageSpec(id: 's0', title: '列大纲', orderIndex: 0),
          StageSpec(id: 's1', title: '写正文', orderIndex: 1),
          StageSpec(id: 's2', title: '校对', orderIndex: 2),
        ],
      ),
      // 阶段从 3 个减到 2 个：被移除的那个应打墓碑，不是消失。
      const ReplaceStagesCommand(
        taskId: 't1',
        stages: [
          StageSpec(id: 's0', title: '列大纲', orderIndex: 0),
          StageSpec(id: 's1', title: '写正文', orderIndex: 1),
        ],
      ),
      const CompleteTaskWithStagesCommand('t1'),
      const ArchiveTaskCommand('t1'),
      const DeleteTaskCommand('t3'),
      const RestoreTaskCommand('t3'),
      const ChangeTaskStatusCommand(taskId: 't3', status: TaskStatus.skipped),
    ]);
  }

  group('回放一致性（V3 验收项）', () {
    test('清库后按 seq 回放 → 逐表逐列与原状态字节相等', () async {
      await runScript();
      final before = await snapshot(db);

      // 前提断言：脚本确实写出了东西，否则「相等」是空对空。
      expect(before['tasks']!.length, 3);
      expect(before['stages']!.length, 3);
      expect(before['categories']!.length, 1);

      final report = await replayer.replayAll();
      expect(report.skipped, 0, reason: '有变更没被回放：$report');
      expect(report.applied, greaterThan(10));

      final after = await snapshot(db);
      for (final table in _businessTables) {
        expect(after[table], before[table], reason: '$table 回放后与原状态不一致');
      }
    });

    test('墓碑在回放后仍是墓碑 —— 删除这件事本身也要能还原', () async {
      // 若回放漏掉删除，被删的数据会在下次同步/恢复时「复活」。
      await runScript();
      await dispatcher.dispatch(const DeleteTaskCommand('t2'));
      final before = await snapshot(db);
      final deletedBefore = before['tasks']!
          .where((r) => r['deleted_at'] != null)
          .map((r) => r['id'])
          .toSet();
      expect(deletedBefore, {'t2'}, reason: '前提：确有一条墓碑');

      await replayer.replayAll();

      final after = await snapshot(db);
      final deletedAfter = after['tasks']!
          .where((r) => r['deleted_at'] != null)
          .map((r) => r['id'])
          .toSet();
      expect(deletedAfter, deletedBefore);
    });

    test('回放是幂等的：连回放两次结果不变', () async {
      // 不幂等的话，V3 的重试会把状态越推越偏。
      await runScript();
      await replayer.replayAll();
      final once = await snapshot(db);
      await replayer.replayAll();
      expect(await snapshot(db), once);
    });

    test('回放不产生新的 change_log 行 —— 回放是恢复，不是重演', () async {
      // 走 DAO 回放会再写一遍日志，日志就会无限自我膨胀。
      await runScript();
      final logsBefore = await _changeLogCount(db);
      await replayer.replayAll();
      expect(await _changeLogCount(db), logsBefore);
    });
  });

  group('这条测试确实能抓到「绕过命令管道」', () {
    test('直接写库（不经 DAO）的数据在回放后消失', () async {
      // **本文件的存在理由。** 绕过管道的写不留 change_log 行，
      // 回放后那条数据就没了 —— 这正是我们要它变红的场景。
      await runScript();
      await db.customStatement('''
        INSERT INTO tasks (id, title, kind, priority, status, is_all_day,
                           time_zone_id, sort_order, created_at, updated_at,
                           revision, last_writer_id)
        VALUES ('sneaky', '绕过管道写进来的', 'single', 2, 'pending', 0,
                'Etc/UTC', 0, 1, 1, 1, 'device-A')
      ''');

      final before = await snapshot(db);
      expect(
        before['tasks']!.map((r) => r['id']),
        contains('sneaky'),
        reason: '前提：绕过的写确实进了库',
      );

      await replayer.replayAll();
      final after = await snapshot(db);

      expect(
        after['tasks']!.map((r) => r['id']),
        isNot(contains('sneaky')),
        reason: '绕过管道的写没有日志，回放后必然缺失 —— 这就是本测试的检出机制',
      );
      expect(after['tasks'], isNot(before['tasks']), reason: '若这里相等，说明检出机制失效了');
    });

    test('经 DAO 但绕过 dispatcher 的写仍能回放 —— 边界要说清', () async {
      // DAO 才是写 outbox 的地方，dispatcher 只是它上面的一层编排。
      // 所以这条测试**不**声称「绕过 dispatcher 会被抓到」——
      // 它抓的是绕过 DAO 的裸 SQL。把这个边界写下来，
      // 免得将来有人以为它的保护范围更大。
      await CategoryDao(db, _writer, clock.call).upsert(
        CategoriesCompanion.insert(
          id: 'direct',
          name: '直接经 DAO 写的',
          colorArgb: 2,
          icon: 'x',
          orderIndex: 1,
        ),
      );
      final before = await snapshot(db);
      await replayer.replayAll();
      expect((await snapshot(db))['categories'], before['categories']);
    });
  });

  group('回放顺序', () {
    test('同一行的多次修改按 seq 还原成最后一版，不是中间版', () async {
      await runScript();
      final finalTitle =
          (await db
                  .customSelect("SELECT title FROM tasks WHERE id = 't1'")
                  .getSingle())
              .read<String>('title');
      expect(finalTitle, '写设计文档', reason: '前提：脚本里改过标题');

      await replayer.replayAll();

      final afterTitle =
          (await db
                  .customSelect("SELECT title FROM tasks WHERE id = 't1'")
                  .getSingle())
              .read<String>('title');
      expect(afterTitle, '写设计文档');
    });

    test('被清空的字段回放后仍是空（不是还原成清空前的值）', () async {
      // 脚本里 note 被设过值又被显式清空。回放若把「清空」当成「不改」，
      // 这里会还原出 '先列大纲'。
      await runScript();
      await replayer.replayAll();
      final note =
          (await db
                  .customSelect("SELECT note FROM tasks WHERE id = 't1'")
                  .getSingle())
              .read<String?>('note');
      expect(note, isNull);
    });

    test('被移除的阶段回放后仍是墓碑', () async {
      await runScript();
      await replayer.replayAll();
      final rows = await db
          .customSelect(
            "SELECT id, deleted_at FROM stages WHERE task_id = 't1'",
          )
          .get();
      final tombstoned = rows
          .where((r) => r.read<int?>('deleted_at') != null)
          .map((r) => r.read<String>('id'))
          .toSet();
      expect(tombstoned, {'s2'}, reason: '第二次 ReplaceStages 移除了 s2');
    });
  });
}

Future<int> _changeLogCount(AppDatabase db) async {
  final row = await db
      .customSelect('SELECT COUNT(*) AS c FROM change_log')
      .getSingle();
  return row.read<int>('c');
}

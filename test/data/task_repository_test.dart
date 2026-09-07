/// `TaskRepository` 的行为契约。
///
/// 重点在两处**跨层一致性**：
///  · 可见性谓词在领域层（`TaskVisibility`）与数据层（SQL）有两套实现，
///    必须交叉验证一致 —— 两处定义同一件事，迟早分叉；
///  · 级联删除/恢复的规则在领域层纯函数里，数据层只负责落盘，
///    必须验证落盘结果与纯函数一致。
@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/clock.dart';
import 'package:planning_assistant/data/database/app_database.dart';
import 'package:planning_assistant/data/database/dao/synced_dao.dart';
import 'package:planning_assistant/data/repositories/task_repository_impl.dart';
import 'package:planning_assistant/domain/entities/stage.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/policies/task_lifecycle.dart';
import 'package:planning_assistant/domain/repositories/task_repository.dart';
import 'package:planning_assistant/domain/value_objects/recurrence.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';

const _writer = FixedWriterIdentity('device-A');
final _now = DateTime.utc(2026, 3, 8, 12);
final _clock = FixedClock(_now);

Task makeTask(
  String id, {
  TaskStatus status = TaskStatus.pending,
  DateTime? archivedAt,
  DateTime? deletedAt,
  TaskStatus? statusBeforeArchive,
  double sortOrder = 0,
}) => Task(
  id: id,
  title: '任务 $id',
  kind: TaskKind.single,
  timeZoneId: 'Asia/Shanghai',
  status: status,
  completedAt: status == TaskStatus.done ? _now : null,
  archivedAt: archivedAt,
  statusBeforeArchive: statusBeforeArchive,
  deletedAt: deletedAt,
  sortOrder: sortOrder,
);

void main() {
  late AppDatabase db;
  late DriftTaskRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftTaskRepository(db, _writer, _clock);
  });
  tearDown(() => db.close());

  group('可见性范围：数据层 SQL 与领域层谓词必须一致', () {
    /// 覆盖 (deleted, archived) 四种组合。
    Future<void> seedAll() async {
      await repo.saveTask(makeTask('active'));
      await repo.saveTask(
        makeTask(
          'archived',
          archivedAt: _now,
          statusBeforeArchive: TaskStatus.pending,
        ),
      );
      await repo.saveTask(makeTask('trashed', deletedAt: _now));
      await repo.saveTask(
        makeTask(
          'trashed-and-archived',
          archivedAt: _now,
          deletedAt: _now,
          statusBeforeArchive: TaskStatus.pending,
        ),
      );
    }

    test('三个范围的结果与 TaskVisibility 逐条一致', () async {
      // **这条是本文件的核心。** 同一个判定有两套实现（Dart 谓词 + SQL 条件），
      // 只测其中一套等于没测跨层一致性 —— 分叉恰恰发生在两者之间。
      await seedAll();
      final all = await repo.findTasks(scope: TaskScope.all);
      expect(all.length, 4, reason: '前提：四种组合都在库里');

      final expectations = <TaskScope, bool Function(Task)>{
        TaskScope.active: TaskVisibility.isActive,
        TaskScope.archived: TaskVisibility.isArchived,
        TaskScope.trashed: TaskVisibility.isInTrash,
      };

      for (final entry in expectations.entries) {
        final fromSql = (await repo.findTasks(scope: entry.key))
            .map((t) => t.id)
            .toSet();
        final fromDomain = all.where(entry.value).map((t) => t.id).toSet();
        expect(
          fromSql,
          fromDomain,
          reason:
              '${entry.key.name}：SQL 与领域谓词分叉了\n'
              'SQL=$fromSql  领域=$fromDomain',
        );
      }
    });

    test('已删的归档任务只出现在回收站', () async {
      // 最容易写错的一格：归档列表若只判 archived_at，它会同时出现在两处。
      await seedAll();
      final archived = (await repo.findTasks(scope: TaskScope.archived))
          .map((t) => t.id);
      final trashed = (await repo.findTasks(scope: TaskScope.trashed))
          .map((t) => t.id);

      expect(archived, ['archived']);
      expect(trashed, containsAll(['trashed', 'trashed-and-archived']));
      expect(archived, isNot(contains('trashed-and-archived')));
    });

    test('三个范围两两不相交，且并集等于全部', () async {
      await seedAll();
      final active = (await repo.findTasks(scope: TaskScope.active))
          .map((t) => t.id)
          .toSet();
      final archived = (await repo.findTasks(scope: TaskScope.archived))
          .map((t) => t.id)
          .toSet();
      final trashed = (await repo.findTasks(scope: TaskScope.trashed))
          .map((t) => t.id)
          .toSet();

      expect(active.intersection(archived), isEmpty);
      expect(active.intersection(trashed), isEmpty);
      expect(archived.intersection(trashed), isEmpty);
      expect({...active, ...archived, ...trashed}.length, 4, reason: '并集必须完备');
    });

    test('findTaskById 同样受范围约束', () async {
      await seedAll();
      expect(await repo.findTaskById('trashed'), isNull, reason: '默认 active');
      expect(
        (await repo.findTaskById('trashed', scope: TaskScope.trashed))?.id,
        'trashed',
      );
    });
  });

  group('写入前校验不变量', () {
    test('重复任务带非 pending 状态时拒绝写入，且库里没留下痕迹', () async {
      // 坏数据一旦落盘，之后每次读取都要带着它，修复要写迁移。
      final bad = Task(
        id: 'bad',
        title: '坏数据',
        kind: TaskKind.single,
        timeZoneId: 'Asia/Shanghai',
        status: TaskStatus.done,
        completedAt: _now,
        recurrence: Recurrence.parse('RRULE:FREQ=DAILY'),
      );
      await expectLater(
        repo.saveTask(bad),
        throwsA(isA<DomainInvariantViolation>()),
      );
      expect(await repo.findTasks(scope: TaskScope.all), isEmpty);
    });

    test('合法任务正常写入（否则上面那条可能因「全拒绝」而假绿）', () async {
      await repo.saveTask(makeTask('ok'));
      expect((await repo.findTasks()).single.id, 'ok');
    });
  });

  group('级联删除与恢复（L-07 / L-08 的落盘验证）', () {
    Future<void> seedTaskWithStages() async {
      await repo.saveTaskWithStages(makeTask('t1'), [
        const Stage(id: 's1', taskId: 't1', title: '阶段一', orderIndex: 0),
        Stage(
          id: 's2',
          taskId: 't1',
          title: '阶段二',
          orderIndex: 1,
          status: TaskStatus.done,
          completedAt: _now,
        ),
      ]);
    }

    test('删除任务 → 阶段一并打墓碑，无一物理删除', () async {
      await seedTaskWithStages();
      await repo.softDeleteTask('t1');

      expect(await repo.findTaskById('t1'), isNull);
      expect(
        (await repo.findTaskById('t1', scope: TaskScope.trashed))?.id,
        't1',
      );

      // 物理删的话恢复时子数据就没了 —— 而回收站承诺可恢复。
      final all = await repo.findStagesOfTask('t1', scope: TaskScope.all);
      expect(all.length, 2, reason: '阶段不能被物理删除');
      expect(all.every((s) => s.deletedAt == _now), isTrue);
      expect(await repo.findStagesOfTask('t1'), isEmpty, reason: '默认范围看不到');
    });

    test('恢复任务 → 阶段一并恢复，状态不变', () async {
      await seedTaskWithStages();
      await repo.softDeleteTask('t1');
      await repo.restoreTask('t1');

      expect((await repo.findTaskById('t1'))?.id, 't1');
      final stages = await repo.findStagesOfTask('t1');
      expect(stages.length, 2);
      expect(stages.every((s) => s.deletedAt == null), isTrue);
      // 删除/恢复不该动状态。
      expect(stages[1].status, TaskStatus.done);
    });

    test('重复删除是幂等的，不会重复写 outbox', () async {
      await seedTaskWithStages();
      await repo.softDeleteTask('t1');
      final countAfterFirst = await _changeLogCount(db);
      await repo.softDeleteTask('t1');
      expect(
        await _changeLogCount(db),
        countAfterFirst,
        reason: '已是墓碑就该直接返回，否则回放时会多出无意义的变更',
      );
    });

    test('恢复未删除的任务是空操作', () async {
      await seedTaskWithStages();
      final before = await _changeLogCount(db);
      await repo.restoreTask('t1');
      expect(await _changeLogCount(db), before);
    });
  });

  group('事务边界', () {
    test('saveTaskWithStages 中途失败时任务与阶段一起回滚', () async {
      // 半截状态会让「阶段推导父任务状态」永久不一致。
      await repo.saveTask(makeTask('existing'));
      final before = (await repo.findTasks(scope: TaskScope.all)).length;

      await expectLater(
        repo.saveTaskWithStages(makeTask('t2'), [
          const Stage(id: 'sx', taskId: '不存在的任务', title: '孤儿', orderIndex: 0),
        ]),
        throwsA(anything),
      );

      final after = await repo.findTasks(scope: TaskScope.all);
      expect(after.length, before, reason: '任务写入必须随阶段失败一起回滚');
      expect(after.map((t) => t.id), isNot(contains('t2')));
    });
  });

  group('查询顺序与流', () {
    test('按 sortOrder 升序，相同则按 id —— 顺序必须确定', () async {
      // 不定顺序会让 UI 每次刷新都跳一下，且测试变成偶发失败。
      await repo.saveTask(makeTask('c', sortOrder: 2));
      await repo.saveTask(makeTask('a', sortOrder: 1));
      await repo.saveTask(makeTask('b', sortOrder: 1));

      expect((await repo.findTasks()).map((t) => t.id), ['a', 'b', 'c']);
    });

    test('阶段按 orderIndex 升序', () async {
      await repo.saveTaskWithStages(makeTask('t1'), [
        const Stage(id: 's2', taskId: 't1', title: '二', orderIndex: 1),
        const Stage(id: 's0', taskId: 't1', title: '零', orderIndex: 0),
      ]);
      expect((await repo.findStagesOfTask('t1')).map((s) => s.orderIndex), [
        0,
        1,
      ]);
    });

    test('watchTasks 在写入后推出新结果', () async {
      // 先等首帧到达再写入。不等的话首帧与写入后的帧可能被合并成一次推送，
      // 用例就变成「有时收到 2 帧、有时 1 帧」的偶发失败 ——
      // 那种测试比没有更糟，它会训练人忽略红灯。
      final emitted = <List<String>>[];
      final sub = repo.watchTasks().listen(
        (rows) => emitted.add([for (final t in rows) t.id]),
      );
      addTearDown(sub.cancel);

      await _waitUntil(() => emitted.isNotEmpty);
      expect(emitted.first, isEmpty, reason: '首帧是空库');

      await repo.saveTask(makeTask('t1'));
      await _waitUntil(() => emitted.length >= 2);
      expect(emitted.last, ['t1']);

      await repo.softDeleteTask('t1');
      await _waitUntil(() => emitted.last.isEmpty);
      expect(emitted.last, isEmpty, reason: '打墓碑后应从 active 流里消失');
    });
  });
}

Future<int> _changeLogCount(AppDatabase db) async {
  final row = await db
      .customSelect('SELECT COUNT(*) AS c FROM change_log')
      .getSingle();
  return row.read<int>('c');
}

/// 等待条件成立，超时即失败。
///
/// 用轮询而不是固定 `Future.delayed`：固定延时在慢机器上偶发失败、
/// 在快机器上白等 —— 两头不讨好。
///
/// 计时用 `Stopwatch` 而不是 `DateTime.now()`。架构守卫「测试不得使用真实时钟」
/// 先拦下了这里，而它拦得对：`DateTime.now()` 相减测的是**墙钟差**，
/// 系统对时或 DST 跳变时会给出荒谬的结果；测「过了多久」本就该用单调时钟。
/// 这不是绕开守卫，是守卫指出了更合适的 API。
Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final elapsed = Stopwatch()..start();
  while (!condition()) {
    if (elapsed.elapsed > timeout) {
      fail('等待条件超时（${timeout.inSeconds}s）');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

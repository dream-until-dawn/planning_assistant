/// `CommandDispatcher` 的行为契约。
///
/// 用真库跑（内存 SQLite），不打桩 Repository —— 打桩的话验的是
/// 「dispatcher 调了哪些方法」，而不是「命令执行后数据对不对」，
/// 前者会在重构时无谓地红，后者才是我们要保的。
@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/data/database/app_database.dart';
import 'package:planning_assistant/data/database/dao/synced_dao.dart';
import 'package:planning_assistant/data/repositories/task_repository_impl.dart';
import 'package:planning_assistant/domain/commands/command_dispatcher.dart';
import 'package:planning_assistant/domain/commands/task_command.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/repositories/task_repository.dart';
import 'package:planning_assistant/domain/value_objects/recurrence.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';

const _writer = FixedWriterIdentity('device-A');
final _now = DateTime.utc(2026, 3, 8, 12);
DateTime _clock() => _now;

const _create = CreateTaskCommand(
  taskId: 't1',
  title: '任务',
  kind: TaskKind.single,
  timeZoneId: 'Asia/Shanghai',
);

void main() {
  late AppDatabase db;
  late DriftTaskRepository repo;
  late CommandDispatcher dispatcher;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftTaskRepository(db, _writer, _clock);
    dispatcher = CommandDispatcher(repo, _clock);
  });
  tearDown(() => db.close());

  group('建任务', () {
    test('ID 来自命令，不由 dispatcher 现场生成', () async {
      // 现场生成的话，同一条命令重放两次会建出两条任务 ——
      // 而 V3 的重试与 outbox 回放都会重放命令。
      await dispatcher.dispatch(_create);
      await dispatcher.dispatch(_create);

      final tasks = await repo.findTasks();
      expect(tasks.length, 1, reason: '重放同一条 create 应是幂等的');
      expect(tasks.single.id, 't1');
    });

    test('重复规则在写库前被规范化，不存外部原串', () async {
      // recurrence-engine §7：统一在管道里规范化，不依赖各调用方自觉。
      // 存原串的话同一条规则会有多种写法进库，之后每处比较都要先归一。
      await dispatcher.dispatch(
        const CreateTaskCommand(
          taskId: 'r1',
          title: '每天',
          kind: TaskKind.single,
          timeZoneId: 'Asia/Shanghai',
          recurrenceRule: 'RRULE:FREQ=DAILY;COUNT=3',
        ),
      );
      final stored = (await repo.findTaskById('r1'))!.recurrence!;
      expect(
        stored.canonical,
        Recurrence.parse('RRULE:FREQ=DAILY;COUNT=3').canonical,
      );
    });

    test('非法的重复规则串被拒绝，任务不落库', () async {
      await expectLater(
        dispatcher.dispatch(
          const CreateTaskCommand(
            taskId: 'bad',
            title: 'x',
            kind: TaskKind.single,
            timeZoneId: 'Etc/UTC',
            recurrenceRule: '这不是 RRULE',
          ),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(await repo.findTasks(scope: TaskScope.all), isEmpty);
    });
  });

  group('改字段：不改 / 清空 必须可区分', () {
    setUp(() => dispatcher.dispatch(_create));

    test('只改标题时备注不动', () async {
      await dispatcher.dispatch(
        const UpdateTaskFieldsCommand(taskId: 't1', note: '原备注'),
      );
      await dispatcher.dispatch(
        const UpdateTaskFieldsCommand(taskId: 't1', title: '新标题'),
      );

      final t = (await repo.findTaskById('t1'))!;
      expect(t.title, '新标题');
      expect(t.note, '原备注', reason: '没传 note 就不该动它');
    });

    test('显式传 null 时备注被清空', () async {
      await dispatcher.dispatch(
        const UpdateTaskFieldsCommand(taskId: 't1', note: '原备注'),
      );
      await dispatcher.dispatch(
        const UpdateTaskFieldsCommand(taskId: 't1', note: null),
      );
      expect((await repo.findTaskById('t1'))!.note, isNull);
    });

    test('清空日期与时间', () async {
      await dispatcher.dispatch(
        UpdateTaskFieldsCommand(
          taskId: 't1',
          planDate: const PlanDate(2026, 5, 1),
          startMinute: MinuteOfDay.of(9, 0),
        ),
      );
      expect(
        (await repo.findTaskById('t1'))!.planDate,
        const PlanDate(2026, 5, 1),
      );

      await dispatcher.dispatch(
        const UpdateTaskFieldsCommand(
          taskId: 't1',
          planDate: null,
          startMinute: null,
        ),
      );
      final t = (await repo.findTaskById('t1'))!;
      expect(t.planDate, isNull);
      expect(t.startMinute, isNull);
    });

    test('清空重复规则 → 任务变成不重复', () async {
      await dispatcher.dispatch(
        const UpdateTaskFieldsCommand(
          taskId: 't1',
          recurrenceRule: 'RRULE:FREQ=WEEKLY',
        ),
      );
      expect((await repo.findTaskById('t1'))!.isRecurring, isTrue);

      await dispatcher.dispatch(
        const UpdateTaskFieldsCommand(taskId: 't1', recurrenceRule: null),
      );
      expect((await repo.findTaskById('t1'))!.isRecurring, isFalse);
    });
  });

  group('状态与归档', () {
    setUp(() => dispatcher.dispatch(_create));

    test('合法迁移生效并记 completedAt', () async {
      await dispatcher.dispatch(
        const ChangeTaskStatusCommand(taskId: 't1', status: TaskStatus.done),
      );
      final t = (await repo.findTaskById('t1'))!;
      expect(t.status, TaskStatus.done);
      expect(t.completedAt, _now);
    });

    test('非法迁移被拒绝，库里状态不变', () async {
      await dispatcher.dispatch(
        const ChangeTaskStatusCommand(taskId: 't1', status: TaskStatus.skipped),
      );
      await expectLater(
        dispatcher.dispatch(
          const ChangeTaskStatusCommand(taskId: 't1', status: TaskStatus.done),
        ),
        throwsA(isA<Object>()),
      );
      expect((await repo.findTaskById('t1'))!.status, TaskStatus.skipped);
    });

    test('归档 → 取消归档，状态还原', () async {
      await dispatcher.dispatch(
        const ChangeTaskStatusCommand(
          taskId: 't1',
          status: TaskStatus.inProgress,
        ),
      );
      await dispatcher.dispatch(const ArchiveTaskCommand('t1'));

      expect(await repo.findTaskById('t1'), isNull, reason: '归档后不在 active');
      final archived = (await repo.findTaskById(
        't1',
        scope: TaskScope.archived,
      ))!;
      expect(archived.statusBeforeArchive, TaskStatus.inProgress);

      await dispatcher.dispatch(const UnarchiveTaskCommand('t1'));
      final back = (await repo.findTaskById('t1'))!;
      expect(back.status, TaskStatus.inProgress);
      expect(back.statusBeforeArchive, isNull);
    });

    test('删除 → 恢复', () async {
      await dispatcher.dispatch(const DeleteTaskCommand('t1'));
      expect(await repo.findTaskById('t1'), isNull);

      await dispatcher.dispatch(const RestoreTaskCommand('t1'));
      expect((await repo.findTaskById('t1'))?.id, 't1');
    });
  });

  group('阶段的整体替换', () {
    setUp(
      () => dispatcher.dispatch(
        const CreateTaskCommand(
          taskId: 't1',
          title: '阶段任务',
          kind: TaskKind.staged,
          timeZoneId: 'Asia/Shanghai',
        ),
      ),
    );

    test('首次写入 3 个阶段', () async {
      await dispatcher.dispatch(
        const ReplaceStagesCommand(
          taskId: 't1',
          stages: [
            StageSpec(id: 's0', title: '一', orderIndex: 0),
            StageSpec(id: 's1', title: '二', orderIndex: 1),
            StageSpec(id: 's2', title: '三', orderIndex: 2),
          ],
        ),
      );
      expect((await repo.findStagesOfTask('t1')).map((s) => s.id), [
        's0',
        's1',
        's2',
      ]);
    });

    test('移除的阶段打墓碑，不物理删', () async {
      // 物理删的话，V3 对端只会看到「这条还在」。
      await dispatcher.dispatch(
        const ReplaceStagesCommand(
          taskId: 't1',
          stages: [
            StageSpec(id: 's0', title: '一', orderIndex: 0),
            StageSpec(id: 's1', title: '二', orderIndex: 1),
          ],
        ),
      );
      await dispatcher.dispatch(
        const ReplaceStagesCommand(
          taskId: 't1',
          stages: [StageSpec(id: 's0', title: '一', orderIndex: 0)],
        ),
      );

      expect((await repo.findStagesOfTask('t1')).map((s) => s.id), ['s0']);
      final all = await repo.findStagesOfTask('t1', scope: TaskScope.all);
      expect(all.length, 2, reason: 's1 应该还在，只是打了墓碑');
      expect(all.firstWhere((s) => s.id == 's1').deletedAt, _now);
    });

    test('orderIndex 不连续时拒绝，且什么都不写', () async {
      // 不连续会让甘特图与列表排序出现空档，「上移/下移」的实现踩空。
      await expectLater(
        dispatcher.dispatch(
          const ReplaceStagesCommand(
            taskId: 't1',
            stages: [
              StageSpec(id: 's0', title: '一', orderIndex: 0),
              StageSpec(id: 's5', title: '五', orderIndex: 5),
            ],
          ),
        ),
        throwsA(isA<Object>()),
      );
      expect(await repo.findStagesOfTask('t1', scope: TaskScope.all), isEmpty);
    });

    test('从 0 开始也是必须的（1..n 同样拒绝）', () async {
      await expectLater(
        dispatcher.dispatch(
          const ReplaceStagesCommand(
            taskId: 't1',
            stages: [StageSpec(id: 's1', title: '一', orderIndex: 1)],
          ),
        ),
        throwsA(isA<Object>()),
      );
    });

    test('标完成时所有阶段一并完成', () async {
      await dispatcher.dispatch(
        const ReplaceStagesCommand(
          taskId: 't1',
          stages: [
            StageSpec(id: 's0', title: '一', orderIndex: 0),
            StageSpec(id: 's1', title: '二', orderIndex: 1),
          ],
        ),
      );
      await dispatcher.dispatch(const CompleteTaskWithStagesCommand('t1'));

      expect((await repo.findTaskById('t1'))!.status, TaskStatus.done);
      final stages = await repo.findStagesOfTask('t1');
      expect(stages.every((s) => s.status == TaskStatus.done), isTrue);
      expect(stages.every((s) => s.completedAt == _now), isTrue);
    });
  });

  group('引用不存在的实体', () {
    test('改不存在的任务抛 EntityNotFoundException', () async {
      // 与「未知命令类型」分开：那是协议问题，这是数据问题，
      // 上层处置完全不同（前者要升级客户端，后者要重新同步）。
      await expectLater(
        dispatcher.dispatch(
          const UpdateTaskFieldsCommand(taskId: '不存在', title: 'x'),
        ),
        throwsA(isA<EntityNotFoundException>()),
      );
    });

    test('删不存在的任务是空操作，不抛', () async {
      // 删除天然幂等：对端重放一条删除时不该炸。
      await dispatcher.dispatch(const DeleteTaskCommand('不存在'));
      expect(await repo.findTasks(scope: TaskScope.all), isEmpty);
    });
  });

  group('dispatchAll 的失败语义', () {
    test('中途失败时，之前成功的命令**保留**', () async {
      // 整串包在一个事务里的话，「导入 500 条，第 499 条有问题」会全军覆没。
      // 用户更想要的是「其余都进来了，告诉我哪条不行」。
      await expectLater(
        dispatcher.dispatchAll([
          _create,
          const CreateTaskCommand(
            taskId: 't2',
            title: '好的',
            kind: TaskKind.single,
            timeZoneId: 'Etc/UTC',
          ),
          const UpdateTaskFieldsCommand(taskId: '不存在', title: 'x'),
          const CreateTaskCommand(
            taskId: 't3',
            title: '不会执行到',
            kind: TaskKind.single,
            timeZoneId: 'Etc/UTC',
          ),
        ]),
        throwsA(isA<EntityNotFoundException>()),
      );

      final ids = (await repo.findTasks()).map((t) => t.id).toSet();
      expect(ids, {'t1', 't2'}, reason: '失败前的应保留，失败后的不该执行');
    });
  });
}

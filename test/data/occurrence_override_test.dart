/// 单次例外的落盘与读回（data-model §3.4、§4.3.1，FR-TASK-05）。
///
/// 这条路此前**完全没有实现**：领域层的引擎、实体、表都齐备，
/// 只差持久化与命令 —— 于是在列表里勾一条重复任务会抛
/// `DomainInvariantViolation`（`tasks.status` 恒为 pending 那条不变量
/// 拦住了，但界面没有别的路可走）。
@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/clock.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/data/database/app_database.dart';
import 'package:planning_assistant/data/database/dao/synced_dao.dart';
import 'package:planning_assistant/data/mappers/occurrence_override_mapper.dart';
import 'package:planning_assistant/data/repositories/task_repository_impl.dart';
import 'package:planning_assistant/domain/commands/command_dispatcher.dart';
import 'package:planning_assistant/domain/commands/task_command.dart';
import 'package:planning_assistant/domain/entities/occurrence.dart';
import 'package:planning_assistant/domain/entities/occurrence_override.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/value_objects/occurrence_key.dart';

final _now = DateTime.utc(2026, 9, 8, 2);

void main() {
  late AppDatabase db;
  late DriftTaskRepository repo;
  late CommandDispatcher dispatcher;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftTaskRepository(
      db,
      const FixedWriterIdentity('test'),
      FixedClock(_now),
    );
    dispatcher = CommandDispatcher(repo, FixedClock(_now));
  });
  tearDown(() => db.close());

  Future<void> seedRecurring() => repo.saveTask(
    Task(
      id: 't1',
      title: '晨会',
      kind: TaskKind.single,
      timeZoneId: 'Asia/Shanghai',
      planDate: const PlanDate(2026, 9, 8),
      startMinute: MinuteOfDay.of(9, 0),
      recurrence: null,
    ),
  );

  OccurrenceKey keyOf(int day) =>
      OccurrenceKey.timed(PlanDate(2026, 9, day), MinuteOfDay.of(9, 0));

  group('主键由 (taskId, key) 派生（§4.3.1）', () {
    test('同一次写两遍只有一行', () async {
      // 随机 UUID 的话「勾完成 → 取消 → 再勾」会插三行，
      // 而读取时哪一行说了算没有定义 —— 完成状态会随机跳。
      await seedRecurring();
      for (final s in [
        OccurrenceStatus.done,
        OccurrenceStatus.inProgress,
        OccurrenceStatus.done,
      ]) {
        await repo.saveOverride(
          OccurrenceOverride(
            taskId: 't1',
            key: keyOf(8),
            action: OverrideAction.modify,
            status: s,
          ),
        );
      }

      final rows = await db.select(db.occurrenceOverrides).get();
      expect(rows, hasLength(1));
      expect(rows.single.status, 'done');
    });

    test('不同的发生各自一行', () async {
      // 对照：「永远覆盖同一行」也能让上面那条绿。
      await seedRecurring();
      for (final day in [8, 9]) {
        await repo.saveOverride(
          OccurrenceOverride(
            taskId: 't1',
            key: keyOf(day),
            action: OverrideAction.modify,
            status: OccurrenceStatus.done,
          ),
        );
      }
      expect(await db.select(db.occurrenceOverrides).get(), hasLength(2));
    });

    test('派生式就是 taskId#key', () {
      expect(overrideRowId('t1', keyOf(8)), 't1#2026-09-08T09:00');
    });
  });

  group('映射：逐列断言，不只验往返', () {
    test('每一列都落在自己的位置上', () async {
      // 往返对「两个同类型字段搬反了」是瞎的。这里有两对陷阱：
      // titleOverride/noteOverride 都是 String?，
      // planDateOverride/endDateOverride 都是 PlanDate?，
      // startMinuteOverride/endMinuteOverride 都是 MinuteOfDay?。
      await seedRecurring();
      await repo.saveOverride(
        OccurrenceOverride(
          taskId: 't1',
          key: keyOf(8),
          action: OverrideAction.modify,
          status: OccurrenceStatus.inProgress,
          titleOverride: '临时改的标题',
          noteOverride: '临时改的备注',
          planDateOverride: const PlanDate(2026, 9, 10),
          startMinuteOverride: MinuteOfDay.of(14, 30),
          endDateOverride: const PlanDate(2026, 9, 11),
          endMinuteOverride: MinuteOfDay.of(16, 45),
        ),
      );

      final row = (await db.select(db.occurrenceOverrides).get()).single;
      expect(row.taskId, 't1');
      expect(row.occurrenceKey, '2026-09-08T09:00');
      expect(row.action, 'modify');
      expect(row.status, 'inProgress');
      expect(row.titleOverride, '临时改的标题');
      expect(row.noteOverride, '临时改的备注');
      expect(row.planDateOverride, '2026-09-10');
      expect(row.startMinuteOverride, 14 * 60 + 30);
      expect(row.endDateOverride, '2026-09-11');
      expect(row.endMinuteOverride, 16 * 60 + 45);

      final back = occurrenceOverrideFromRow(row);
      expect(back.titleOverride, '临时改的标题');
      expect(back.planDateOverride, const PlanDate(2026, 9, 10));
      expect(back.startMinuteOverride, MinuteOfDay.of(14, 30));
      expect(back.endDateOverride, const PlanDate(2026, 9, 11));
      expect(back.endMinuteOverride, MinuteOfDay.of(16, 45));
    });
  });

  group('命令管道（FR-AI-01：写只有一条路）', () {
    test('标为完成 → 落一条例外，并记下完成的那一刻', () async {
      await seedRecurring();
      await dispatcher.dispatch(
        SetOccurrenceStatusCommand(
          taskId: 't1',
          occurrenceKey: keyOf(8),
          status: OccurrenceStatus.done,
        ),
      );

      final row = (await db.select(db.occurrenceOverrides).get()).single;
      expect(row.status, 'done');
      expect(
        row.completedAt,
        _now.millisecondsSinceEpoch,
        reason: 'completedAt 是**实际点完成的那一刻**，不是计划时间（§5）',
      );
    });

    test('转成非 done 时清掉 completedAt', () async {
      // 留着的话，「今天完成了几件」会把历史上完成过、后来又撤销的
      // 也算进去。
      await seedRecurring();
      await dispatcher.dispatch(
        SetOccurrenceStatusCommand(
          taskId: 't1',
          occurrenceKey: keyOf(8),
          status: OccurrenceStatus.done,
        ),
      );
      await dispatcher.dispatch(
        SetOccurrenceStatusCommand(
          taskId: 't1',
          occurrenceKey: keyOf(8),
          status: OccurrenceStatus.skipped,
        ),
      );

      final row = (await db.select(db.occurrenceOverrides).get()).single;
      expect(row.status, 'skipped');
      expect(row.completedAt, isNull);
    });

    test('status 传 null = 回到跟随规则，例外被删掉', () async {
      // **不是写一条 pending 的例外**：那会让「从没动过」与
      // 「动过又撤回」在库里长得不一样，而它们对用户是同一件事。
      await seedRecurring();
      await dispatcher.dispatch(
        SetOccurrenceStatusCommand(
          taskId: 't1',
          occurrenceKey: keyOf(8),
          status: OccurrenceStatus.done,
        ),
      );
      await dispatcher.dispatch(
        SetOccurrenceStatusCommand(
          taskId: 't1',
          occurrenceKey: keyOf(8),
          status: null,
        ),
      );

      expect(await repo.findOverridesOfTask('t1'), isEmpty);
    });

    test('命令能序列化并原样解回来（可重放）', () async {
      // 命令要能进 outbox 再回放（FR-AI-01、V3 同步）。
      // 少了往返，加一个字段却忘了写进 toJson，回放出来就少那一维。
      final command = SetOccurrenceStatusCommand(
        taskId: 't1',
        occurrenceKey: keyOf(8),
        status: OccurrenceStatus.done,
      );
      final back = TaskCommand.fromJson(command.toJson());
      expect(back, isA<SetOccurrenceStatusCommand>());
      final typed = back as SetOccurrenceStatusCommand;
      expect(typed.taskId, 't1');
      expect(typed.occurrenceKey, keyOf(8));
      expect(typed.status, OccurrenceStatus.done);
    });

    test('status 为 null 也能往返', () {
      final command = SetOccurrenceStatusCommand(
        taskId: 't1',
        occurrenceKey: keyOf(8),
        status: null,
      );
      final back =
          TaskCommand.fromJson(command.toJson()) as SetOccurrenceStatusCommand;
      expect(back.status, isNull);
    });
  });

  group('读回', () {
    test('watchAllOverrides 推的是全部任务的例外', () async {
      // 列表要一次展开几十条重复任务，逐条查库就是 N+1。
      await seedRecurring();
      await repo.saveTask(
        const Task(
          id: 't2',
          title: '周会',
          kind: TaskKind.single,
          timeZoneId: 'Asia/Shanghai',
          planDate: PlanDate(2026, 9, 8),
        ),
      );
      for (final id in ['t1', 't2']) {
        await repo.saveOverride(
          OccurrenceOverride(
            taskId: id,
            key: keyOf(8),
            action: OverrideAction.modify,
            status: OccurrenceStatus.done,
          ),
        );
      }

      final seen = await repo.watchAllOverrides().first;
      expect(seen.map((o) => o.taskId).toSet(), {'t1', 't2'});
    });

    test('删掉的例外不再读出来', () async {
      await seedRecurring();
      await repo.saveOverride(
        OccurrenceOverride(
          taskId: 't1',
          key: keyOf(8),
          action: OverrideAction.modify,
          status: OccurrenceStatus.done,
        ),
      );
      await repo.removeOverride('t1', keyOf(8));

      expect(await repo.findOverridesOfTask('t1'), isEmpty);
      expect(await repo.watchAllOverrides().first, isEmpty);
    });
  });
}

/// 全天 ⇄ 定时切换的落盘（R-27）。
///
/// 纯函数那一侧在 `test/domain/all_day_conversion_test.dart`。
/// 这里走真库，验三件它验不了的事：
///
///  1. 迁移之后例外**真的还挂得上**（不是「新行写出来了」而已）——
///     这是 R-27 验收原话里的「例外不失联」；
///  2. 旧行打的是墓碑，不是物理删（V3 对端要靠它知道那行没了）；
///  3. 整件事是**一个事务**。
@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/clock.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/data/database/app_database.dart';
import 'package:planning_assistant/data/database/dao/synced_dao.dart';
import 'package:planning_assistant/data/repositories/task_repository_impl.dart';
import 'package:planning_assistant/domain/commands/command_dispatcher.dart';
import 'package:planning_assistant/domain/commands/task_command.dart';
import 'package:planning_assistant/domain/entities/occurrence_override.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/repositories/task_repository.dart';
import 'package:planning_assistant/domain/value_objects/occurrence_key.dart';
import 'package:planning_assistant/domain/value_objects/recurrence.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';

final _now = DateTime.utc(2026, 9, 8, 1);
const _writer = FixedWriterIdentity('test-device');

({AppDatabase db, TaskRepository repo, CommandDispatcher bus}) _setUp() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final clock = FixedClock(_now);
  final repo = DriftTaskRepository(db, _writer, clock);
  return (db: db, repo: repo, bus: CommandDispatcher(repo, clock));
}

/// 一条每天重复的**全天**任务，外加 9/8 那一次的跳过例外。
Future<void> _seedAllDay(TaskRepository repo) async {
  await repo.saveTask(
    Task(
      id: 't1',
      title: '晨会',
      kind: TaskKind.single,
      timeZoneId: 'Asia/Shanghai',
      planDate: const PlanDate(2026, 9, 8),
      isAllDay: true,
      recurrence: Recurrence.parse('RRULE:FREQ=DAILY'),
    ),
  );
  await repo.saveOverride(
    OccurrenceOverride.skip(
      taskId: 't1',
      key: OccurrenceKey.allDay(const PlanDate(2026, 9, 8)),
    ),
  );
}

void main() {
  test('R-27 迁移之后，例外仍然挂在同一次发生上', () async {
    // **这条才是验收原话。** 只验「新行写出来了」的话，一个把 key 写成
    // 任意串的实现也能绿 —— 而那时例外挂不上任何一次发生。
    final env = _setUp();
    await _seedAllDay(env.repo);

    await env.bus.dispatch(
      ConvertTaskAllDayModeCommand(
        taskId: 't1',
        toAllDay: false,
        startMinute: MinuteOfDay.of(9, 0),
      ),
    );

    final task = (await env.repo.findTaskById('t1'))!;
    final overrides = await env.repo.findOverridesOfTask('t1');

    // 任务现在是定时的，那么这一次发生的 key 该是什么？
    // **问 OccurrenceKey 自己**，不手写字符串 —— 手写的话，
    // 这条断言与被测代码就没有共同的判据了（§1.10 的反面：
    // 这里要的正是「与引擎用同一条规则」）。
    final expected = OccurrenceKey.fromWallTime(
      task.startWallTime!,
      isAllDay: task.isAllDay,
    );
    expect(
      overrides.single.key.value,
      expected.value,
      reason: '例外的 key 与任务现在会展开出的 key 对不上 —— 它失联了',
    );
  });

  test('旧行打墓碑，不是物理删', () async {
    final env = _setUp();
    await _seedAllDay(env.repo);

    await env.bus.dispatch(
      ConvertTaskAllDayModeCommand(
        taskId: 't1',
        toAllDay: false,
        startMinute: MinuteOfDay.of(9, 0),
      ),
    );

    final rows = await env.db.select(env.db.occurrenceOverrides).get();
    expect(rows, hasLength(2), reason: '旧行被物理删了 —— V3 对端只会看到「这条还在」');
    final old = rows.firstWhere((r) => r.occurrenceKey == '2026-09-08');
    expect(old.deletedAt, isNotNull);
    final fresh = rows.firstWhere((r) => r.occurrenceKey == '2026-09-08T09:00');
    expect(fresh.deletedAt, isNull);
  });

  test('已经是那个形态时什么都不做', () async {
    // 「无害地再写一遍」并不无害：会把所有例外原地删了重建，
    // 白白造一批墓碑，而 V3 对端要为这些什么也没变的行做一轮合并。
    final env = _setUp();
    await _seedAllDay(env.repo);

    final before = (await env.db.select(env.db.tasks).get()).single;

    await env.bus.dispatch(
      const ConvertTaskAllDayModeCommand(taskId: 't1', toAllDay: true),
    );

    final rows = await env.db.select(env.db.occurrenceOverrides).get();
    expect(rows, hasLength(1));
    expect(rows.single.deletedAt, isNull);

    // **连任务自己都不该被写一遍。**
    //
    // 只验「例外没动」的话，一个「照常把任务 upsert 一次」的实现照样绿 ——
    // 而那一次写会把同步信封的 version +1、updatedAt 刷新，
    // V3 对端得为一条什么也没变的记录做一轮合并。
    // 变异演练里 R-05 就是从这儿漏过去的。
    final after = (await env.db.select(env.db.tasks).get()).single;
    expect(after.revision, before.revision, reason: '什么都没变，修订号却涨了');
    expect(after.updatedAt, before.updatedAt);
  });

  test('撞车时整件事回滚 —— 不留半截状态', () async {
    // 定时 → 全天，9:00 与 14:00 会压成同一个 key。
    // 纯函数会抛，而这里要的是**任务也没被改**：
    // 任务改了而例外没迁，例外就永久失联了。
    final env = _setUp();
    await env.repo.saveTask(
      Task(
        id: 't1',
        title: '晨会',
        kind: TaskKind.single,
        timeZoneId: 'Asia/Shanghai',
        planDate: const PlanDate(2026, 9, 8),
        startMinute: MinuteOfDay.of(9, 0),
        isAllDay: false,
        recurrence: Recurrence.parse('RRULE:FREQ=DAILY'),
      ),
    );
    for (final m in [MinuteOfDay.of(9, 0), MinuteOfDay.of(14, 0)]) {
      await env.repo.saveOverride(
        OccurrenceOverride.skip(
          taskId: 't1',
          key: OccurrenceKey.timed(const PlanDate(2026, 9, 8), m),
        ),
      );
    }

    await expectLater(
      env.bus.dispatch(
        const ConvertTaskAllDayModeCommand(taskId: 't1', toAllDay: true),
      ),
      throwsA(isA<DomainInvariantViolation>()),
    );

    final task = (await env.repo.findTaskById('t1'))!;
    expect(task.isAllDay, isFalse, reason: '拦住了，但任务已经被改了 —— 那两条例外现在失联着');
  });
}

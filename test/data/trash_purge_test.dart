/// 超期清理（task-lifecycle §6、用例 L-09）。
///
/// `isPurgeable` 那条策略早就写好也测过了（边界日不清）。这里验的是
/// **它真的被接上了**：启动时跑一遍、只清超期的、清掉的连子实体一起没。
///
/// 在这之前回收站是「只进不出」的 —— 策略在、仓库不会物理删、
/// 没有任何东西调用它。又是一条从领域层断在半路上的链路。
@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app_providers.dart';
import 'package:planning_assistant/core/id/id_generator.dart';
import 'package:planning_assistant/core/time/clock.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/data/database/app_database.dart';
import 'package:planning_assistant/data/database/dao/synced_dao.dart';
import 'package:planning_assistant/data/repositories/settings_repository_impl.dart';
import 'package:planning_assistant/data/repositories/task_repository_impl.dart';
import 'package:planning_assistant/domain/entities/stage.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/repositories/task_repository.dart';
import 'package:planning_assistant/features/settings/application/settings_providers.dart';
import 'package:planning_assistant/features/trash/application/trash_purge.dart';

/// 「现在」。删除时刻按它往前推。
final _now = DateTime.utc(2026, 9, 8, 12);

const _writer = FixedWriterIdentity('test-device');

/// 一条建好、带一个阶段、然后在 [deletedDaysAgo] 天前被删掉的任务。
Future<void> _seedDeleted(
  TaskRepository repo,
  String id, {
  required int deletedDaysAgo,
}) async {
  await repo.saveTaskWithStages(
    Task(
      id: id,
      title: id,
      kind: TaskKind.staged,
      timeZoneId: 'Asia/Shanghai',
      planDate: const PlanDate(2026, 1, 1),
      isAllDay: true,
    ),
    [Stage(id: '$id-s1', taskId: id, title: '一步', orderIndex: 0)],
  );
  // 软删除走真的那条路（级联打墓碑），再把删除时刻改到过去 ——
  // 直接构造一条「已删」的任务会绕过级联，子实体不会打墓碑，
  // 那时验「子实体一起没」就成了自证。
  await repo.softDeleteTask(id);
  final deletedAt = _now.subtract(Duration(days: deletedDaysAgo));
  final task = (await repo.findTaskById(id, scope: TaskScope.all))!;
  await repo.saveTask(task.copyWith(deletedAt: deletedAt));
}

({ProviderContainer container, AppDatabase db, TaskRepository repo}) _setUp() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final clock = FixedClock(_now);
  final repo = DriftTaskRepository(db, _writer, clock);

  final container = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(clock),
      idGeneratorProvider.overrideWithValue(
        SequentialIdGenerator(prefix: 'task'),
      ),
      taskRepositoryProvider.overrideWithValue(repo),
      settingsRepositoryProvider.overrideWithValue(
        DriftSettingsRepository(db, _writer, clock),
      ),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, db: db, repo: repo);
}

void main() {
  test('L-09：只清超过保留期的，边界日不清', () async {
    final env = _setUp();
    await _seedDeleted(env.repo, '很久以前', deletedDaysAgo: 31);
    await _seedDeleted(env.repo, '正好三十天', deletedDaysAgo: 30);
    await _seedDeleted(env.repo, '昨天', deletedDaysAgo: 1);

    final purged = await env.container.read(trashPurgeProvider)();

    expect(purged, 1, reason: '边界日被清掉了 —— 判据与领域层那条不一致');
    final left = await env.repo.findTasks(scope: TaskScope.trashed);
    expect(left.map((t) => t.id).toSet(), {'正好三十天', '昨天'}, reason: '清错了对象');
  });

  test('清掉的连子实体一起没 —— 不留孤儿行', () async {
    // 外键的 ON DELETE CASCADE 管这一步。它没生效的话，
    // 库里会攒下一堆指向不存在任务的阶段，而且谁也不会去查。
    final env = _setUp();
    await _seedDeleted(env.repo, '很久以前', deletedDaysAgo: 60);

    expect(await env.db.select(env.db.stages).get(), hasLength(1));
    await env.container.read(trashPurgeProvider)();

    expect(await env.db.select(env.db.tasks).get(), isEmpty);
    expect(
      await env.db.select(env.db.stages).get(),
      isEmpty,
      reason: '任务清了、阶段还在 —— 外键级联没生效',
    );
  });

  test('**活着的任务一条都不动**', () async {
    // 这是这条链路最危险的一步：清理是物理删除，没有退路。
    final env = _setUp();
    await env.repo.saveTask(
      const Task(
        id: '活着的',
        title: '活着的',
        kind: TaskKind.single,
        timeZoneId: 'Asia/Shanghai',
      ),
    );
    await _seedDeleted(env.repo, '该清的', deletedDaysAgo: 60);

    await env.container.read(trashPurgeProvider)();

    final alive = await env.repo.findTasks();
    expect(alive.map((t) => t.id), ['活着的']);
  });

  test('保留期跟着配置走', () async {
    // 配置改成 7 天之后，十天前删的那条就该清了 ——
    // 写死 30 的实现在这里会露馅。
    final env = _setUp();
    await env.container
        .read(settingsRepositoryProvider)
        .put('data.trashRetentionDays', 7, scope: 'global');
    await _seedDeleted(env.repo, '十天前', deletedDaysAgo: 10);

    // **必须等配置流吐出值**。同步读的话拿到的是 loading 的回落 ——
    // 而配置的回落是「默认值」，看起来完全正常：断言会失败在
    // 「一条都没清」上，而真实原因是那一帧还没读到 7。
    // 与 `settleViewPipeline` 里记的是同一个坑。
    env.container.listen(rawSettingsProvider, (_, _) {});
    await pumpEventQueue();

    expect(await env.container.read(trashPurgeProvider)(), 1);
  });

  test('没有超期的就什么都不做', () async {
    final env = _setUp();
    await _seedDeleted(env.repo, '昨天', deletedDaysAgo: 1);
    expect(await env.container.read(trashPurgeProvider)(), 0);
    expect(await env.repo.findTasks(scope: TaskScope.trashed), hasLength(1));
  });

  test('仓库这一侧只删墓碑 —— 传进来一条活着的 id 也删不掉', () async {
    // 判「该不该清」是领域策略的事，而仓库这一侧守着最后一道：
    // 调用方算错了，最坏也只是清早了，不会把活数据抹掉。
    final env = _setUp();
    await env.repo.saveTask(
      const Task(
        id: '活着的',
        title: '活着的',
        kind: TaskKind.single,
        timeZoneId: 'Asia/Shanghai',
      ),
    );

    expect(await env.repo.purgeDeleted(['活着的']), 0);
    expect(await env.repo.findTasks(), hasLength(1));
  });
}

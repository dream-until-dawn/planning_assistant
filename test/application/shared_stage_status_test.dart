/// 阶段完成状态在四个视图里是同一个答案（FR-TASK-07）。
///
/// ## 它防的和 `shared_span_test` 是同一件事
///
/// §4.7 那条「不得各自计算」防的是**算得不一样**。阶段状态有同样的风险，
/// 而且已经真的发生过一次：
///
/// 补 FR-TASK-07 时，卡片进度与单次弹层都改走了 `stageStatusFor`，
/// **甘特没改** —— 它自己 `stage.status == done` 算分段着色与进度条。
/// 于是一条重复的阶段事项，这周勾掉一步之后：
///
/// | 视图 | 显示 |
/// |---|---|
/// | 列表 / 日历 / 时间轴的卡片 | 阶段 1/2 |
/// | 甘特 | 0/2 |
///
/// 两个视图对同一条任务说了两句话，而且都不报错 ——
/// 没人会把它当 bug 报，只会觉得「甘特好像不太准」。
/// 当时全套测试是绿的：卡片那条走新路径、甘特那条用的是不重复的夹具。
///
/// 所以判据收到 `TaskOccurrence.stageStatus` 一处，
/// 并有一条 lint 盯着 `stage.status` 不许在别处出现。这里验的是结果。
@TestOn('vm')
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/domain/entities/stage.dart';
import 'package:planning_assistant/domain/entities/stage_occurrence_state.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/value_objects/occurrence_key.dart';
import 'package:planning_assistant/domain/value_objects/recurrence.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';
import 'package:planning_assistant/features/views/gantt/application/gantt_providers.dart';
import 'package:planning_assistant/features/views/task_list/application/task_list_providers.dart';
import 'package:planning_assistant/features/views/timeline/application/timeline_providers.dart';

import '../support/app_harness.dart';

const _today = PlanDate(2026, 9, 8);

/// 一条每天 9:00、拆成两步的重复任务。
final _task = Task(
  id: '健身',
  title: '健身',
  kind: TaskKind.staged,
  timeZoneId: 'Asia/Shanghai',
  planDate: _today,
  startMinute: MinuteOfDay.of(9, 0),
  isAllDay: false,
  recurrence: Recurrence.parse('RRULE:FREQ=DAILY'),
);

final _stages = [
  const Stage(
    id: 's1',
    taskId: '健身',
    title: '热身',
    orderIndex: 0,
    startOffsetMinutes: 0,
    durationMinutes: 30,
  ),
  const Stage(
    id: 's2',
    taskId: '健身',
    title: '主训',
    orderIndex: 1,
    startOffsetMinutes: 30,
    durationMinutes: 30,
  ),
];

/// 今天这一次的 key。
final _todayKey = OccurrenceKey.timed(_today, MinuteOfDay.of(9, 0));

/// 今天这一次，第一步做完了。
final _states = [
  StageOccurrenceState(
    id: StageOccurrenceState.idFor('s1', _todayKey),
    taskId: '健身',
    stageId: 's1',
    occurrenceKey: _todayKey,
    status: TaskStatus.done,
    completedAt: DateTime.utc(2026, 9, 8, 2),
  ),
];

Future<ProviderContainer> _container() async {
  final c = ProviderContainer(
    overrides: viewPipelineOverrides(
      tasks: [_task],
      stages: _stages,
      stageStates: _states,
      today: _today,
    ),
  );
  addTearDown(c.dispose);
  await settleViewPipeline(c);
  return c;
}

void main() {
  test('**四个视图对今天这一次说同一个进度**', () async {
    final c = await _container();

    final timeline = c.read(timelineOccurrencesProvider).single;
    final list = c.read(filteredTasksProvider).single;
    // 甘特是排布好的条 —— 它的进度是 double。
    final lanes = c.read(ganttLayoutProvider).lanes;
    final todayBar = [
      for (final lane in lanes)
        for (final bar in lane.bars)
          if (bar.row.planDate == _today) bar,
    ].single;

    for (final (name, row) in [('时间轴', timeline), ('列表', list)]) {
      expect(row.stageProgress, (done: 1, total: 2), reason: '$name 的阶段进度不一样');
    }
    expect(
      todayBar.progress,
      0.5,
      reason: '甘特自己读了 stage.status —— 它看到的是整条任务共用的那一份',
    );
  });

  test('甘特的分段着色也按这一次算', () async {
    // 进度对了而分段没对的话，条上那两段的深浅仍然是整条任务的状态。
    final c = await _container();
    final lanes = c.read(ganttLayoutProvider).lanes;
    final todayBar = [
      for (final lane in lanes)
        for (final bar in lane.bars)
          if (bar.row.planDate == _today) bar,
    ].single;

    expect(todayBar.segments, hasLength(2));
    expect(
      [for (final s in todayBar.segments) s.done],
      [true, false],
      reason: '分段的完成着色没按这一次算',
    );
  });

  test('对照组：另一次一步都没做，四个视图也一致', () async {
    // 少了这条，一个「一律返回 1/2」的实现能让上面绿。
    final c = await _container();

    final tomorrow = _today.addDays(1);
    final list = c.read(filteredTasksProvider);
    final lanes = c.read(ganttLayoutProvider).lanes;
    final tomorrowBar = [
      for (final lane in lanes)
        for (final bar in lane.bars)
          if (bar.row.planDate == tomorrow) bar,
    ];

    // 列表对重复任务只展开「逾期的 + 下一次」，所以明天那一次不一定在
    // 列表里 —— 甘特窗口里一定在。
    expect(tomorrowBar.single.progress, 0.0, reason: '另一次跟着变完成了');
    expect(list.single.stageProgress, (done: 1, total: 2));
  });
}

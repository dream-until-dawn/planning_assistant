/// 有效跨度在四个视图里是同一个答案（data-model §4.7、甘特 G-05）。
///
/// §4.7 那条规则的原话是「所有视图、甘特布局、冲突检测一律用
/// `effectiveEnd`，**不得各自计算**」。它防的不是算错，是**算得不一样**：
/// 甘特自行扩展到末阶段、时间轴按 endDate 画，同一条任务在两个视图里
/// 一长一短 —— 而没人会把它当 bug 报，只会觉得「甘特好像不太准」。
///
/// 所以这里不验「某个视图算得对」，验的是**三个视图给出同一个跨度**。
@TestOn('vm')
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/domain/entities/stage.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/features/views/calendar/application/calendar_providers.dart';
import 'package:planning_assistant/features/views/calendar/application/day_bands.dart';
import 'package:planning_assistant/features/views/shared/application/view_shared_state.dart';
import 'package:planning_assistant/features/views/task_list/application/task_list_providers.dart';
import 'package:planning_assistant/features/views/timeline/application/timeline_providers.dart';

import '../support/app_harness.dart';

const _today = PlanDate(2026, 9, 8);

/// 一条 9:00 开始、**存储的结束是当天 10:00**、但末阶段排到第二天 14:00
/// 的阶段事项。跨度该是「到第二天 14:00」，不是「到当天 10:00」。
final _staged = Task(
  id: '搬家',
  title: '搬家',
  kind: TaskKind.staged,
  timeZoneId: 'Asia/Shanghai',
  planDate: _today,
  startMinute: MinuteOfDay.of(9, 0),
  endDate: _today,
  endMinute: MinuteOfDay.of(10, 0),
);

final _stages = [
  const Stage(
    id: 's1',
    taskId: '搬家',
    title: '打包',
    orderIndex: 0,
    startOffsetMinutes: 0,
    durationMinutes: 60,
  ),
  const Stage(
    id: 's2',
    taskId: '搬家',
    title: '搬运',
    orderIndex: 1,
    // 9:00 + 1740 分 = 第二天 14:00，**超出存储的结束**。
    startOffsetMinutes: 60,
    durationMinutes: 1680,
  ),
];

Future<ProviderContainer> _container() async {
  final c = ProviderContainer(
    overrides: viewPipelineOverrides(
      tasks: [_staged],
      stages: _stages,
      today: _today,
    ),
  );
  addTearDown(c.dispose);
  await settleViewPipeline(c);
  return c;
}

void main() {
  test('三个视图对同一条任务给出同一个结束', () async {
    final c = await _container();

    final fromTimeline = c.read(agendaRowsProvider).single;
    final fromCalendar = c.read(calendarOccurrencesProvider).single;
    final fromList = c.read(filteredTasksProvider).single;

    const expected = PlanDate(2026, 9, 9);
    for (final (name, row) in [
      ('时间轴', fromTimeline),
      ('日历', fromCalendar),
      ('列表', fromList),
    ]) {
      expect(row.effectiveEndDate, expected, reason: '$name 的跨度不一样');
      expect(row.effectiveEndMinute?.value, 14 * 60, reason: '$name 的跨度不一样');
    }
  });

  test('存储的结束仍然读得到 —— 有效跨度不改写它', () async {
    // `effectiveEnd` 是**派生值，不落库**（§4.7）。存储那一份要原样在，
    // 否则「阶段超出了任务结束时间」这个提示就无从判断。
    final c = await _container();
    final row = c.read(agendaRowsProvider).single;
    expect(row.endDate, _today);
    expect(row.endMinute?.value, 10 * 60);
  });

  test('阶段撑开之后，日历上它变成跨天的横条', () async {
    // 跨度只在数据里对还不够 —— 要能看出它改变了视图的判断。
    // 不撑开的话这条任务只占 9/8 一天，走色点。
    final c = await _container();
    c
        .read(viewSharedStateProvider.notifier)
        .setGranularity(TimeGranularity.month);

    final row = c.read(calendarOccurrencesProvider).single;
    expect(showsAsBand(row), isTrue, reason: '没被撑开，它还是「只占一天」');

    final layout = c.read(calendarLayoutProvider);
    final bands = [for (final w in layout.bands) ...w.bands];
    expect(bands, hasLength(1));
    expect(bands.single.spanDays, 2);
  });

  test('对照组：没有阶段时，跨度就是存储的那一段', () async {
    // 少了这条，一个「一律扩展到第二天」的实现也能让上面绿。
    final c = ProviderContainer(
      overrides: viewPipelineOverrides(tasks: [_staged], today: _today),
    );
    addTearDown(c.dispose);
    await settleViewPipeline(c);

    final row = c.read(agendaRowsProvider).single;
    expect(row.effectiveEndDate, _today);
    expect(row.effectiveEndMinute?.value, 10 * 60);
  });
}

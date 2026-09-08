/// 竖向甘特的数据源（view-specs §4）。
///
/// **视图不自己查库**（§0.2）—— 与另外三个视图走同一条流。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app_providers.dart';
import '../../../../core/time/plan_date.dart';
import '../../../../domain/recurrence/recurrence_engine.dart';
import '../../../../domain/value_objects/task_status.dart';
import '../../../settings/application/registry.dart';
import '../../../settings/application/settings_providers.dart';
import '../../shared/application/category_providers.dart';
import '../../shared/application/occurrence_expansion.dart';
import '../../shared/application/task_filter.dart';
import '../../shared/application/task_occurrence.dart';
import '../../shared/application/task_providers.dart';
import '../../shared/application/view_shared_state.dart';
import 'gantt_layout.dart';

/// 甘特一屏看多久。
///
/// 随共享的 `granularity` 变（§0.1「日/周/月，甘特与日历共用」）——
/// 甘特自己存一份的话，从日历切过来时两边对不上。
///
/// 三档给的是**窗口跨度**，不是刻度密度：竖向甘特的价值在于「一屏能看
/// 两周以上」（§4.1），所以「日」这一档也不该只看一天。
int ganttWindowDays(TimeGranularity granularity) => switch (granularity) {
  TimeGranularity.day => 14,
  TimeGranularity.week => 35,
  TimeGranularity.month => 90,
};

/// 这一屏的时间窗，从聚焦日**往前留三天**开始。
///
/// 不从聚焦日当天开始：那样「刚过去的事」全在屏幕上方之外，
/// 而甘特最常见的用法就是回头看一眼进度。
final ganttWindowProvider = Provider<({PlanDate start, PlanDate end})>((ref) {
  final shared = ref.watch(viewSharedStateProvider);
  final start = shared.focusedDate.addDays(-3);
  return (
    start: start,
    end: start.addDays(ganttWindowDays(shared.granularity) - 1),
  );
});

/// 这一屏窗口里的发生，已筛选。
final ganttOccurrencesProvider = Provider<List<TaskOccurrence>>((ref) {
  final window = ref.watch(ganttWindowProvider);
  final filter = ref.watch(viewSharedStateProvider).filter;

  return switch (ref.watch(visibleTasksProvider)) {
    AsyncData(:final value) => applyFilter(
      expandInWindow(
        tasks: value,
        overrides: switch (ref.watch(allOverridesProvider)) {
          AsyncData(:final value) => value,
          _ => const [],
        },
        window: DateRange(window.start, window.end),
        engine: RecurrenceEngine(ref.watch(timeZoneResolverProvider)),
        // 阶段进来算有效跨度（§4.7）—— 甘特的条长必须与时间轴一致。
        stagesByTask: ref.watch(stagesByTaskProvider),
        includeSkipped: filter.statuses.contains(TaskStatus.skipped),
      ),
      filter,
    ),
    _ => const [],
  };
});

/// 排好的一屏甘特。
final ganttLayoutProvider = Provider<GanttLayout>((ref) {
  final window = ref.watch(ganttWindowProvider);
  return ganttLayout(
    rows: ref.watch(ganttOccurrencesProvider),
    windowStart: window.start,
    windowEnd: window.end,
    laneBy: settingOf(ref, ganttLaneBy),
    categories: ref.watch(categoryListProvider),
  );
});

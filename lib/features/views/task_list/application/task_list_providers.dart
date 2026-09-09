/// 列表视图的数据源（view-specs §2）。
///
/// **视图不自己查库**（view-specs §0.2）—— 经仓库的 `watchTasks` 流，
/// 于是新建任务落库后列表自动刷新，不需要任何手工「刷新」调用。
/// 这条在 J-01「建任务 → 列表可见」里是关键：如果靠手工刷新，
/// 那条集成测试会因为时序偶尔变绿，而那比红更糟。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app_providers.dart';
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
import 'task_grouping.dart';

/// 展开成「一行一次发生」（view-specs §0.2）。
///
/// 重复任务在这里变成多行；不重复与无日期的仍是一行。
/// 展开窗口见 [ListHorizon]。
final visibleOccurrencesProvider = Provider<List<TaskOccurrence>>((ref) {
  final tasks = ref.watch(visibleTasksProvider);
  final overrides = ref.watch(allOverridesProvider);
  return switch (tasks) {
    AsyncData(:final value) => expandForList(
      tasks: value,
      // 例外还没读出来时先按「没有例外」展开 —— 下一帧到了自动重算。
      // 抛或者卡住的话，首帧会是一屏错误，而它其实只是还没读完。
      overrides: switch (overrides) {
        AsyncData(:final value) => value,
        _ => const [],
      },
      today: ref.watch(todayProvider),
      // 阶段进来算有效跨度（§4.7）—— 四视图共用同一个答案。
      stagesByTask: ref.watch(stagesByTaskProvider),
      stageStatesByTask: ref.watch(stageStatesByTaskProvider),
      engine: RecurrenceEngine(ref.watch(timeZoneResolverProvider)),
      // 被跳过的那一次默认不出现（FR-TASK-05 验收）。
      // **只有用户显式筛「已跳过」时才让它现身** —— 不留这条路的话，
      // 跳错了就再也找不回来，与「到某天为止」那条死路是同一种毛病。
      // 被折叠掉的那些次（已跳过 / 已完成的历史）**只有显式筛选才现身**。
      // 不留这条路的话，跳过或做完的那些就再也找不回来了 ——
      // 与「到某天为止」那条死路是同一种毛病。
      includeSkipped: ref
          .watch(viewSharedStateProvider)
          .filter
          .statuses
          .contains(TaskStatus.skipped),
      includeCompleted: ref
          .watch(viewSharedStateProvider)
          .filter
          .statuses
          .contains(TaskStatus.done),
    ),
    _ => const [],
  };
});

/// 筛选后的行（view-specs §2.3）。
///
/// 筛选状态来自 `viewSharedStateProvider` —— 四个视图共用同一份
/// （FR-VIEW-05），所以它不属于列表这个 feature。
final filteredTasksProvider = Provider<List<TaskOccurrence>>((ref) {
  final filter = ref.watch(viewSharedStateProvider).filter;
  return applyFilter(ref.watch(visibleOccurrencesProvider), filter);
});

/// 分好组、排好序的列表。
///
/// 三个输入（任务、分类、偏好）任一变化都会重算 —— 勾完成之后
/// 任务会自动挪到「已完成」组，不需要谁去手动通知。
final groupedTasksProvider = Provider<List<TaskGroup>>((ref) {
  // 分组与排序**直接读配置**（settings-spec §1.1）。
  //
  // 一度在这两者之间放过一个自带默认值的 `ListPreferences` Notifier。
  // 那份默认值与注册表里的 `defaultValue` 是**两处同一个事实**，
  // 迟早分叉 —— 表现会是「设置页显示按日期，列表却按分类排」。
  // 去掉那一层，只留注册表这一处定义。
  return groupTasks(
    ref.watch(filteredTasksProvider),
    groupBy: settingOf(ref, listGroupBy),
    sortBy: settingOf(ref, listSortBy),
    today: ref.watch(todayProvider),
    categories: ref.watch(categoryListProvider),
  );
});

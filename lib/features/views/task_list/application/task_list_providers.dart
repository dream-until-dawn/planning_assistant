/// 列表视图的数据源（view-specs §2）。
///
/// **视图不自己查库**（view-specs §0.2）—— 经仓库的 `watchTasks` 流，
/// 于是新建任务落库后列表自动刷新，不需要任何手工「刷新」调用。
/// 这条在 J-01「建任务 → 列表可见」里是关键：如果靠手工刷新，
/// 那条集成测试会因为时序偶尔变绿，而那比红更糟。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app_providers.dart';
import '../../../../domain/entities/occurrence_override.dart';
import '../../../../domain/entities/stage.dart';
import '../../../../domain/entities/task.dart';
import '../../../../domain/recurrence/recurrence_engine.dart';
import '../../../settings/application/registry.dart';
import '../../../settings/application/settings_providers.dart';
import '../../shared/application/category_providers.dart';
import '../../shared/application/occurrence_expansion.dart';
import '../../shared/application/task_filter.dart';
import '../../shared/application/task_occurrence.dart';
import '../../shared/application/view_shared_state.dart';
import 'task_grouping.dart';

/// 库里的活动任务，**未经筛选**。
///
/// 拆成两个 provider 是有意的：这一个是数据源，
/// [filteredTasksProvider] 才是列表看到的东西。合成一个的话，
/// 「空态」就分不清是「一条任务都没有」还是「筛完之后没有」——
/// 而这两种的正确文案完全不同。
final visibleTasksProvider = StreamProvider<List<Task>>(
  (ref) => ref.watch(taskRepositoryProvider).watchTasks(),
);

/// 全部单次例外的流（FR-TASK-05）。
///
/// **必须是顶层 provider**，与 [allStagesProvider] 同一条理由：
/// 在别的 provider 体内内联构造 `StreamProvider` 会每次重建出一个新对象，
/// `watch` 于是不停重新订阅 —— 测试表现为「did not complete」，
/// 看不出是死循环。
final allOverridesProvider = StreamProvider<List<OccurrenceOverride>>(
  (ref) => ref.watch(taskRepositoryProvider).watchAllOverrides(),
);

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
      engine: RecurrenceEngine(ref.watch(timeZoneResolverProvider)),
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

/// 按 taskId 索引的阶段（FR-TASK-02：父任务进度 = 已完成阶段数 / 总数）。
///
/// 一次取全再索引，不按 taskId 分别订阅 —— 理由见
/// `TaskRepository.watchAllStages` 的注释。
/// 全部阶段的流。
///
/// **必须是顶层 provider。** 一度写成在 [stagesByTaskProvider] 体内
/// 内联 `ref.watch(StreamProvider(...))` —— 那样每次重建都构造一个
/// **新的 provider 对象**，`watch` 于是不停重新订阅，测试直接挂死
/// （表现是「did not complete」，看不出是死循环）。
final allStagesProvider = StreamProvider<List<Stage>>(
  (ref) => ref.watch(taskRepositoryProvider).watchAllStages(),
);

final stagesByTaskProvider = Provider<Map<String, List<Stage>>>((ref) {
  final stages = ref.watch(allStagesProvider);
  return switch (stages) {
    AsyncData(:final value) => _indexByTask(value),
    _ => const {},
  };
});

Map<String, List<Stage>> _indexByTask(List<Stage> stages) {
  final map = <String, List<Stage>>{};
  for (final s in stages) {
    (map[s.taskId] ??= []).add(s);
  }
  // 组内按 orderIndex 排 —— 进度只数个数，但详情页要按顺序显示，
  // 索引在这里排好，省得每个消费者各排一遍。
  for (final list in map.values) {
    list.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }
  return map;
}

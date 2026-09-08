/// 四视图共享的数据源（view-specs §0.2）。
///
/// **禁止任何视图自己查库**（§0.2 原话）。这几个 provider 原本长在
/// `task_list/application/` 里 —— 那时只有列表一个消费者。
/// 编辑器要按 id 取一条任务时才暴露出问题：那样一来 `task` feature
/// 得 import `views/task_list` 的内部，方向反了。搬到 shared 层。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app_providers.dart';
import '../../../../domain/entities/occurrence_override.dart';
import '../../../../domain/entities/stage.dart';
import '../../../../domain/entities/task.dart';

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

/// 按 id 取一条任务。**同步**，从已经在内存里的那份列表里找。
///
/// 编辑器要用它：打开编辑页时得当场拿到那条任务。再去查一次库的话，
/// 表单会先空一帧再被填上 —— 而那一帧里用户可能已经开始打字了。
///
/// 找不到就是 null（任务被删了、或者流还没到）。调用方要显式处理，
/// **不给一张空表单** —— 空表单看起来像「这条任务的内容全没了」。
final taskByIdProvider = Provider.family<Task?, String>((ref, id) {
  final tasks = switch (ref.watch(visibleTasksProvider)) {
    AsyncData(:final value) => value,
    _ => const <Task>[],
  };
  for (final t in tasks) {
    if (t.id == id) return t;
  }
  return null;
});

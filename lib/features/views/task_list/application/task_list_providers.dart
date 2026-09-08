/// 列表视图的数据源（view-specs §2）。
///
/// **视图不自己查库**（view-specs §0.2）—— 经仓库的 `watchTasks` 流，
/// 于是新建任务落库后列表自动刷新，不需要任何手工「刷新」调用。
/// 这条在 J-01「建任务 → 列表可见」里是关键：如果靠手工刷新，
/// 那条集成测试会因为时序偶尔变绿，而那比红更糟。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../../../app_providers.dart';
import '../../../../core/time/plan_date.dart';
import '../../../../domain/entities/task.dart';
import '../../shared/application/category_providers.dart';
import 'task_grouping.dart';

/// 当前可见的任务。
///
/// M2 只做「未完成的活动任务」这一档。筛选（§2.3）还没做 ——
/// **这里不预先塞一个假的筛选**：假筛选会让后面真正实现 §2.3 时
/// 分不清「改对了」还是「本来就那样」。
final visibleTasksProvider = StreamProvider<List<Task>>(
  (ref) => ref.watch(taskRepositoryProvider).watchTasks(),
);

/// 列表的分组与排序偏好（配置项 `view.listGroupBy` / `view.listSortBy`）。
@immutable
final class ListPreferences {
  const ListPreferences({
    this.groupBy = ListGroupBy.fallback,
    this.sortBy = ListSortBy.fallback,
  });

  final ListGroupBy groupBy;
  final ListSortBy sortBy;

  ListPreferences copyWith({ListGroupBy? groupBy, ListSortBy? sortBy}) =>
      ListPreferences(
        groupBy: groupBy ?? this.groupBy,
        sortBy: sortBy ?? this.sortBy,
      );

  @override
  bool operator ==(Object other) =>
      other is ListPreferences &&
      groupBy == other.groupBy &&
      sortBy == other.sortBy;

  @override
  int get hashCode => Object.hash(groupBy, sortBy);
}

/// 偏好的持有者。
///
/// TODO(M2-设置): 初值改读配置项，改动写回配置。
///   两个枚举的 `fromStorageKey` 已经把「认不出的值」处理成回落。
final class ListPreferencesNotifier extends Notifier<ListPreferences> {
  @override
  ListPreferences build() => const ListPreferences();

  void setGroupBy(ListGroupBy value) => state = state.copyWith(groupBy: value);

  void setSortBy(ListSortBy value) => state = state.copyWith(sortBy: value);
}

final listPreferencesProvider =
    NotifierProvider<ListPreferencesNotifier, ListPreferences>(
      ListPreferencesNotifier.new,
    );

/// 「今天」——**本地墙钟的今天**，不是 UTC 的（ADR-0005）。
///
/// 分组要靠它区分逾期/今天/明天，而东八区早上八点前 UTC 还停在昨天：
/// 直接截 `nowUtc` 的话，用户一早打开应用，今天的事全被算成「明天」。
final todayProvider = Provider<PlanDate>((ref) {
  final resolver = ref.watch(timeZoneResolverProvider);
  return resolver
      .toWallTime(ref.watch(clockProvider).nowUtc(), resolver.currentZoneId())
      .date;
});

/// 分好组、排好序的列表。
///
/// 三个输入（任务、分类、偏好）任一变化都会重算 —— 勾完成之后
/// 任务会自动挪到「已完成」组，不需要谁去手动通知。
final groupedTasksProvider = Provider<List<TaskGroup>>((ref) {
  final tasks = ref.watch(visibleTasksProvider);
  final prefs = ref.watch(listPreferencesProvider);

  return switch (tasks) {
    AsyncData(:final value) => groupTasks(
      value,
      groupBy: prefs.groupBy,
      sortBy: prefs.sortBy,
      today: ref.watch(todayProvider),
      categories: ref.watch(categoryListProvider),
    ),
    // 还没读出来、或读失败，都交给页面去表达 ——
    // 这里返回空组，页面靠 `visibleTasksProvider` 自己的状态区分
    // 「空」与「出错」。**不能在这里把出错也当成空**，
    // 那会让用户以为任务全没了。
    _ => const [],
  };
});

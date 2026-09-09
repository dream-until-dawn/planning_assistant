/// 四视图共享的状态（view-specs §0.1、FR-VIEW-05/06）。
///
/// **这份状态活在外壳上，不属于任何一个视图。** 切视图不换路由，
/// 于是「在列表设的筛选切到甘特仍生效」不需要任何恢复机制 ——
/// 状态压根没被销毁过（view-specs §7.1）。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app_providers.dart';
import '../../../../core/patch/unset.dart';
import '../../../../core/time/plan_date.dart';
import '../../../../domain/entities/task.dart';
import '../../../../domain/value_objects/task_status.dart';

/// 时间粒度。甘特与日历共用（view-specs §0.1）。
enum TimeGranularity { day, week, month }

/// 筛选条件（view-specs §2.3）。
///
/// **空筛选 ≠ null**：`FilterSpec.none` 是一个真实的值，表示「不筛」。
/// 用 null 表示不筛的话，「清空筛选」与「还没加载」会长得一样，
/// 而这两件事的正确行为不同。
///
/// ## 每个维度里，空集合 = 不筛这个维度
///
/// **不是「一个都不匹配」。** 这条不是口味问题：用户把最后一个分类
/// 取消勾选时，期待的是「回到全部」，不是「列表空掉」。
/// 反过来实现的话，取消最后一项会让人以为任务丢了。
///
/// ## 维度之间取交集，维度之内取并集
///
/// 「分类=工作 且 状态∈{待办,进行中}」——这是 §2.3 说的「条件可叠加」。
@immutable
final class FilterSpec {
  const FilterSpec({
    this.categoryIds = const {},
    this.priorities = const {},
    this.statuses = const {},
    this.keyword,
    this.dateFrom,
    this.dateTo,
  });

  /// 不筛任何东西。
  static const FilterSpec none = FilterSpec();

  /// 分类。**元素可以是 `null`，那表示「未分类」**
  /// —— 未分类就是 `categoryId IS NULL`，不是某一行（settings-spec §3.0）。
  /// 用一个单独的 bool 来表达它的话，这个维度就有了两套开关。
  final Set<String?> categoryIds;

  final Set<TaskPriority> priorities;
  final Set<TaskStatus> statuses;

  /// 关键词。匹配标题与备注，大小写不敏感。
  final String? keyword;

  /// 日期范围，两端都可选（只给一端就是开区间）。
  final PlanDate? dateFrom;
  final PlanDate? dateTo;

  bool get isEmpty =>
      categoryIds.isEmpty &&
      priorities.isEmpty &&
      statuses.isEmpty &&
      (keyword == null || keyword!.trim().isEmpty) &&
      dateFrom == null &&
      dateTo == null;

  FilterSpec copyWith({
    Set<String?>? categoryIds,
    Set<TaskPriority>? priorities,
    Set<TaskStatus>? statuses,
    Object? keyword = unset,
    Object? dateFrom = unset,
    Object? dateTo = unset,
  }) => FilterSpec(
    categoryIds: categoryIds ?? this.categoryIds,
    priorities: priorities ?? this.priorities,
    statuses: statuses ?? this.statuses,
    // 这三个都要能被**清空**，所以用 core/patch 的哨兵，
    // 不用 `?? this.x` —— 后者把 null 解释成「不改」，清不掉。
    keyword: patch(keyword, this.keyword),
    dateFrom: patch(dateFrom, this.dateFrom),
    dateTo: patch(dateTo, this.dateTo),
  );

  /// 切换某个分类的勾选。`null` 即「未分类」那一项。
  FilterSpec toggleCategory(String? id) => copyWith(
    categoryIds: categoryIds.contains(id)
        ? (categoryIds.toSet()..remove(id))
        : (categoryIds.toSet()..add(id)),
  );

  /// 切换某个状态的勾选。
  /// 切换某个优先级的勾选。
  FilterSpec togglePriority(TaskPriority priority) => copyWith(
    priorities: priorities.contains(priority)
        ? (priorities.toSet()..remove(priority))
        : (priorities.toSet()..add(priority)),
  );

  FilterSpec toggleStatus(TaskStatus status) => copyWith(
    statuses: statuses.contains(status)
        ? (statuses.toSet()..remove(status))
        : (statuses.toSet()..add(status)),
  );

  @override
  bool operator ==(Object other) =>
      other is FilterSpec &&
      setEquals(categoryIds, other.categoryIds) &&
      setEquals(priorities, other.priorities) &&
      setEquals(statuses, other.statuses) &&
      keyword == other.keyword &&
      dateFrom == other.dateFrom &&
      dateTo == other.dateTo;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(categoryIds),
    Object.hashAllUnordered(priorities),
    Object.hashAllUnordered(statuses),
    keyword,
    dateFrom,
    dateTo,
  );
}

/// 视图共享状态。
@immutable
final class ViewSharedState {
  const ViewSharedState({
    required this.focusedDate,
    this.filter = FilterSpec.none,
    this.selectedOccurrenceId,
    this.granularity = TimeGranularity.day,
  });

  /// 当前聚焦日期。
  ///
  /// 类型是 [PlanDate] 而不是 `DateTime`，因为它表达的是**纯日期**
  /// —— cross-cutting §1.1 要求三种时间绝不混用，而 `DateTime`
  /// 同时能表示绝对时刻与墙钟，正是那条规矩要避免的东西。
  /// 用了 [PlanDate]，「切视图后还在 9/20」这件事的相等判断就不可能
  /// 因为多带了个时分秒而失败。
  final PlanDate focusedDate;

  final FilterSpec filter;
  final String? selectedOccurrenceId;
  final TimeGranularity granularity;

  ViewSharedState copyWith({
    PlanDate? focusedDate,
    FilterSpec? filter,
    Object? selectedOccurrenceId = unset,
    TimeGranularity? granularity,
  }) => ViewSharedState(
    focusedDate: focusedDate ?? this.focusedDate,
    filter: filter ?? this.filter,
    // 选中态要能被**清掉**（点空白处取消选中），同 FilterSpec.keyword。
    selectedOccurrenceId: patch(
      selectedOccurrenceId,
      this.selectedOccurrenceId,
    ),
    granularity: granularity ?? this.granularity,
  );

  @override
  bool operator ==(Object other) =>
      other is ViewSharedState &&
      focusedDate == other.focusedDate &&
      filter == other.filter &&
      selectedOccurrenceId == other.selectedOccurrenceId &&
      granularity == other.granularity;

  @override
  int get hashCode =>
      Object.hash(focusedDate, filter, selectedOccurrenceId, granularity);
}

/// 共享状态的持有者。
final class ViewSharedStateNotifier extends Notifier<ViewSharedState> {
  @override
  ViewSharedState build() => ViewSharedState(focusedDate: _today());

  /// 「今天」由 [todayProvider] 统一给出 —— 全应用只有那一处定义。
  PlanDate _today() => ref.watch(todayProvider);

  /// 聚焦到某一天。
  void focusDate(PlanDate date) => state = state.copyWith(focusedDate: date);

  /// 回到今天。
  void focusToday() => focusDate(_today());

  void setFilter(FilterSpec filter) => state = state.copyWith(filter: filter);

  void clearFilter() => state = state.copyWith(filter: FilterSpec.none);

  void select(String? occurrenceId) =>
      state = state.copyWith(selectedOccurrenceId: occurrenceId);

  void setGranularity(TimeGranularity g) =>
      state = state.copyWith(granularity: g);
}

final viewSharedStateProvider =
    NotifierProvider<ViewSharedStateNotifier, ViewSharedState>(
      ViewSharedStateNotifier.new,
    );

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

/// 时间粒度。甘特与日历共用（view-specs §0.1）。
enum TimeGranularity { day, week, month }

/// 筛选条件。
///
/// **空筛选 ≠ null**：`FilterSpec.none` 是一个真实的值，
/// 表示「不筛」。用 null 表示不筛的话，「清空筛选」与「还没加载」
/// 会长得一样，而这两件事的正确行为不同。
@immutable
final class FilterSpec {
  const FilterSpec({
    this.categoryIds = const {},
    this.tagIds = const {},
    this.keyword,
    this.includeCompleted = false,
  });

  /// 不筛任何东西。
  static const FilterSpec none = FilterSpec();

  final Set<String> categoryIds;
  final Set<String> tagIds;
  final String? keyword;

  /// 是否把已完成的也显示出来。默认不显示。
  final bool includeCompleted;

  bool get isEmpty =>
      categoryIds.isEmpty &&
      tagIds.isEmpty &&
      (keyword == null || keyword!.isEmpty) &&
      !includeCompleted;

  FilterSpec copyWith({
    Set<String>? categoryIds,
    Set<String>? tagIds,
    Object? keyword = unset,
    bool? includeCompleted,
  }) => FilterSpec(
    categoryIds: categoryIds ?? this.categoryIds,
    tagIds: tagIds ?? this.tagIds,
    // 关键词要能被**清空**，所以不能用 `keyword ?? this.keyword` ——
    // 那样传 null 表示「不改」，就永远清不掉了。
    //
    // 哨兵用 core/patch 里那个专门的 [unset]，**不自己写
    // `const Object()`** —— Dart 会把 const Object() 规范化成同一个实例，
    // 两处各写一个会意外互通，而那种「碰巧能用」比不能用更危险。
    // 那个文件就是为这件事存在的。
    keyword: patch(keyword, this.keyword),
    includeCompleted: includeCompleted ?? this.includeCompleted,
  );

  @override
  bool operator ==(Object other) =>
      other is FilterSpec &&
      setEquals(categoryIds, other.categoryIds) &&
      setEquals(tagIds, other.tagIds) &&
      keyword == other.keyword &&
      includeCompleted == other.includeCompleted;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(categoryIds),
    Object.hashAllUnordered(tagIds),
    keyword,
    includeCompleted,
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

  /// 「今天」是**本地墙钟的今天**，不是 UTC 的今天。
  ///
  /// 直接把 `clock.nowUtc()` 截成日期，对 UTC 以东以西的用户在午夜
  /// 前后会差一天 —— 东八区 08:00 之前，UTC 还停在昨天。
  /// 所以必须经时区换算器（ADR-0005）。
  PlanDate _today() {
    final resolver = ref.watch(timeZoneResolverProvider);
    return resolver
        .toWallTime(ref.watch(clockProvider).nowUtc(), resolver.currentZoneId())
        .date;
  }

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

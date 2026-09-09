/// 筛选的多选弹层（view-specs §2.3）。
///
/// ## 为什么从「一排 Chip」改成这个
///
/// 上一版顶部是一条横向滚动的 Chip 条：清除 + 三个状态 + 五个优先级 +
/// 分类若干，**十来个** Chip 排成一行。用户看过之后的原话：
///
/// > 还要改造下顶部的筛选，改为下拉或抽屉或其他形式的多选器，
/// > 按 状态/分类等等分为多个选择器。
///
/// 那条 Chip 条有两个问题，都不是审美问题：
///
///  · **看不出维度。** 「已完成」和「紧急」和「工作」排在一起，
///    读起来像一串平级开关，而它们之间是**交集**、维度内部是并集
///    （[FilterSpec] 的注释里写着这条规则，界面上一个字都没有）。
///  · **够不着。** 分类多一点，后面几个要横向滚两三屏才看得到，
///    而横向滚动条上没有任何「后面还有」的提示。
///
/// 现在顶部只有**每个维度一个按钮**（带上选了几项），点开是这一维的
/// 多选弹层。维度之间的关系由此变成可见的：三个按钮并排 = 三个条件叠加。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/app_chip.dart';
import '../../../../design/tokens/dimensions.dart';
import '../../../../domain/entities/task.dart';
import '../../../../domain/value_objects/task_status.dart';
import '../application/category_providers.dart';
import '../application/view_shared_state.dart';

/// 筛选的一个维度 —— **界面上开得出来的那几个**。
///
/// [FilterSpec] 还支持关键词与日期范围，但那两个不是「多选一组取值」
/// 的形状（一个要搜索框，一个要区间选择器），塞进这套弹层里会变成
/// 两个格格不入的特例。它们跟着各自的入口一起做。
enum FilterDimension {
  status('状态'),
  priority('优先级'),
  category('分类');

  const FilterDimension(this.label);

  final String label;
}

/// 打开某一维的多选弹层。
Future<void> showFilterSheet(BuildContext context, FilterDimension dimension) =>
    showModalBottomSheet<void>(
      context: context,
      // 分类可以有很多个，弹层要能长高、也要能滚。
      isScrollControlled: true,
      builder: (_) => FilterSheet(dimension: dimension),
    );

class FilterSheet extends ConsumerWidget {
  const FilterSheet({required this.dimension, super.key});

  final FilterDimension dimension;

  static Key sheetKey(FilterDimension d) => ValueKey('filter-sheet-${d.name}');

  /// 「这一维清空」。
  static Key clearKey(FilterDimension d) =>
      ValueKey('filter-sheet-clear-${d.name}');

  /// 收起弹层。
  static Key doneKey(FilterDimension d) =>
      ValueKey('filter-sheet-done-${d.name}');

  /// 状态维度暴露哪几项。**只放设得出来的**。
  ///
  /// `inProgress` 仍然没有入口（编辑器只建 pending，勾完成只在
  /// pending/done 之间切），摆出来是个筛不出东西的按钮。
  ///
  /// `skipped` 是**后来加上的**，而且它不只是个筛选条件：跳过的那一次
  /// 「不出现在任何视图」（FR-TASK-05 验收），勾上这个才让它们现身
  /// （`expandForList` 的 `includeSkipped`）。**这是跳过之后唯一的
  /// 反悔入口** —— 拿掉它，跳过就成了一条走进去出不来的路。
  static const List<(TaskStatus, String)> exposedStatuses = [
    (TaskStatus.pending, '待办'),
    (TaskStatus.done, '已完成'),
    (TaskStatus.skipped, '已跳过'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final filter = ref.watch(viewSharedStateProvider).filter;
    final notifier = ref.read(viewSharedStateProvider.notifier);
    final chosen = _countOf(filter, dimension);

    return SafeArea(
      key: sheetKey(dimension),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.pageHorizontal,
          Spacing.lg,
          Spacing.pageHorizontal,
          Spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(dimension.label, style: text.titleMedium),
                const SizedBox(width: Spacing.sm),
                // **一句话说清维度之间是什么关系。** 三个条件叠加是
                // 「且」，同一维里勾两项是「或」—— 不写出来的话，
                // 「勾了工作和生活为什么两类都在」会变成一道谜题。
                Expanded(
                  child: Text(
                    chosen == 0 ? '不筛这一项' : '选中的任意一项',
                    style: text.bodySmall,
                  ),
                ),
                if (chosen > 0)
                  TextButton(
                    key: clearKey(dimension),
                    onPressed: () =>
                        notifier.setFilter(_clear(filter, dimension)),
                    child: const Text('清空'),
                  ),
                TextButton(
                  key: doneKey(dimension),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('完成'),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            // 分类多的时候弹层不该顶到屏幕外，所以这一段自己能滚。
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.sm,
                  children: [
                    for (final option in _optionsOf(ref, dimension))
                      SelectableChip(
                        key: option.key,
                        label: option.label,
                        selected: option.selected,
                        onSelected: (_) => notifier.setFilter(option.next),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 弹层里的一项。
typedef _Option = ({Key key, String label, bool selected, FilterSpec next});

List<_Option> _optionsOf(WidgetRef ref, FilterDimension dimension) {
  final filter = ref.watch(viewSharedStateProvider).filter;

  return switch (dimension) {
    FilterDimension.status => [
      for (final (status, label) in FilterSheet.exposedStatuses)
        (
          key: FilterKeys.status(status),
          label: label,
          selected: filter.statuses.contains(status),
          next: filter.toggleStatus(status),
        ),
    ],
    // 按 `byImportance`（紧急 → … → 无），与列表的「按优先级」分组、
    // 编辑器里的选择区**同一份顺序**。三处各写一遍的话迟早对不上。
    FilterDimension.priority => [
      for (final p in TaskPriority.byImportance)
        (
          key: FilterKeys.priority(p),
          label: p.label,
          selected: filter.priorities.contains(p),
          next: filter.togglePriority(p),
        ),
    ],
    FilterDimension.category => [
      // 「未分类」和真分类并排，不单列 —— 它是这个维度里的一个取值
      // （settings-spec §3.0），不是一个额外开关。
      (
        key: FilterKeys.category(null),
        label: Uncategorized.name,
        selected: filter.categoryIds.contains(null),
        next: filter.toggleCategory(null),
      ),
      for (final c in ref.watch(categoryListProvider))
        (
          key: FilterKeys.category(c.id),
          label: c.name,
          selected: filter.categoryIds.contains(c.id),
          next: filter.toggleCategory(c.id),
        ),
    ],
  };
}

/// 这一维选了几项。顶部按钮上的那个数字就是它。
int _countOf(FilterSpec filter, FilterDimension dimension) =>
    switch (dimension) {
      FilterDimension.status => filter.statuses.length,
      FilterDimension.priority => filter.priorities.length,
      FilterDimension.category => filter.categoryIds.length,
    };

/// 只清这一维，别的维度不动。
FilterSpec _clear(FilterSpec filter, FilterDimension dimension) =>
    switch (dimension) {
      FilterDimension.status => filter.copyWith(statuses: const {}),
      FilterDimension.priority => filter.copyWith(priorities: const {}),
      FilterDimension.category => filter.copyWith(categoryIds: const {}),
    };

/// 每一项的 Key，以及顶部按钮要的那个计数。
///
/// **单独拿出来**：弹层与筛选条各要用一份，而测试要靠它们定位。
/// 放在其中一个组件的静态成员上的话，另一个就得反向 import。
abstract final class FilterKeys {
  static Key status(TaskStatus s) => ValueKey('filter-status-${s.name}');
  static Key priority(TaskPriority p) => ValueKey('filter-priority-${p.name}');

  /// `null` 是「未分类」那一项。
  static Key category(String? id) =>
      ValueKey('filter-category-${id ?? 'none'}');

  static int countOf(FilterSpec filter, FilterDimension d) =>
      _countOf(filter, d);
}

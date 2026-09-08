/// 筛选条（view-specs §2.3、§0.3「顶部筛选条：同一个组件，同一份状态」）。
///
/// 放 `views/shared/presentation/` 是因为四个视图共用它 ——
/// 同一个组件、同一份状态，切视图时筛选照旧（FR-VIEW-05）。
///
/// ## 控件本身就是「已生效条件」的展示
///
/// §2.3 要求「顶部以 Chip 形式展示已生效条件，可单个清除」。
/// 这里没有再单做一条「已生效条件」栏 —— 选中的 Chip 就是那个展示，
/// 点一下就是那个「单个清除」。两处各画一遍的话，它们迟早不同步，
/// 而用户会相信离他更近的那一处。
///
/// ## 现在只有分类与状态
///
/// [FilterSpec] 支持优先级、关键词、日期范围，但那三个还没有入口：
/// 优先级在编辑器里还设不了（设不了就筛不出东西）、关键词要一个搜索框、
/// 日期范围要一个区间选择器。**不放点了没反应的控件** ——
/// 逻辑先备好，入口跟着各自的来源一起做。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/app_chip.dart';
import '../../../../design/tokens/dimensions.dart';
import '../../../../domain/value_objects/task_status.dart';
import '../application/category_providers.dart';
import '../application/view_shared_state.dart';

class FilterBar extends ConsumerWidget {
  const FilterBar({super.key});

  static const Key barKey = ValueKey('filter-bar');
  static const Key clearKey = ValueKey('filter-clear');

  /// 分类筛选项的 Key。`null` 是「未分类」那一项。
  static Key categoryKey(String? id) =>
      ValueKey('filter-category-${id ?? 'none'}');

  static Key statusKey(TaskStatus status) =>
      ValueKey('filter-status-${status.name}');

  /// 状态维度只暴露这两项。
  ///
  /// `inProgress` 与 `skipped` 现在没有任何入口能设出来（编辑器只建
  /// pending，勾完成只在 pending/done 之间切），摆出来是四个筛不出东西的
  /// 按钮。等状态机接上入口再加。
  static const List<(TaskStatus, String)> exposedStatuses = [
    (TaskStatus.pending, '待办'),
    (TaskStatus.done, '已完成'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryListProvider);
    final filter = ref.watch(viewSharedStateProvider).filter;
    final notifier = ref.read(viewSharedStateProvider.notifier);

    return SizedBox(
      key: barKey,
      height: Spacing.minTouchTarget + Spacing.sm,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.pageHorizontal),
        children: [
          // 「清除」放在**最前面**：筛完之后想回到全部是最急的操作，
          // 而横向滚动条上「最前面」是唯一不用滚就够得到的位置。
          if (!filter.isEmpty) ...[
            SelectableChip(
              key: clearKey,
              label: '清除筛选',
              selected: false,
              onSelected: (_) => notifier.clearFilter(),
            ),
            const SizedBox(width: Spacing.sm),
          ],
          for (final (status, label) in exposedStatuses) ...[
            SelectableChip(
              key: statusKey(status),
              label: label,
              selected: filter.statuses.contains(status),
              onSelected: (_) =>
                  notifier.setFilter(filter.toggleStatus(status)),
            ),
            const SizedBox(width: Spacing.sm),
          ],
          // 「未分类」和真分类并排，不单列 —— 它是这个维度里的一个取值
          // （settings-spec §3.0），不是一个额外开关。
          SelectableChip(
            key: categoryKey(null),
            label: Uncategorized.name,
            selected: filter.categoryIds.contains(null),
            onSelected: (_) => notifier.setFilter(filter.toggleCategory(null)),
          ),
          const SizedBox(width: Spacing.sm),
          for (final c in categories) ...[
            SelectableChip(
              key: categoryKey(c.id),
              label: c.name,
              selected: filter.categoryIds.contains(c.id),
              onSelected: (_) =>
                  notifier.setFilter(filter.toggleCategory(c.id)),
            ),
            const SizedBox(width: Spacing.sm),
          ],
        ],
      ),
    );
  }
}

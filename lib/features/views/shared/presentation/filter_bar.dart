/// 筛选条（view-specs §2.3、§0.3「顶部筛选条：同一个组件，同一份状态」）。
///
/// 放 `views/shared/presentation/` 是因为四个视图共用它 ——
/// 同一个组件、同一份状态，切视图时筛选照旧（FR-VIEW-05）。
///
/// ## 一个维度一个按钮
///
/// 上一版是一排十来个 Chip（清除 + 三个状态 + 五个优先级 + 分类若干）。
/// 改成现在这样的理由写在 `filter_sheet.dart` 开头 —— 一句话：
/// 那一排读起来像平级开关，而维度之间是交集、维度内部是并集。
///
/// 按钮上带着**选了几项**：不带的话，筛选生效与否只能靠底色深浅判断，
/// 而「我到底筛了什么」得逐个点开才知道。
///
/// ## 控件本身就是「已生效条件」的展示
///
/// §2.3 要求「顶部以 Chip 形式展示已生效条件，可单个清除」。
/// 这里没有再单做一条「已生效条件」栏 —— 按钮上的计数就是那个展示，
/// 点开逐项取消、或按「清空」就是那个「单个清除」。
/// 两处各画一遍的话它们迟早不同步，而用户会相信离他更近的那一处。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/app_chip.dart';
import '../../../../design/tokens/dimensions.dart';
import '../application/view_shared_state.dart';
import 'filter_sheet.dart';

class FilterBar extends ConsumerWidget {
  const FilterBar({super.key});

  static const Key barKey = ValueKey('filter-bar');

  /// 「全部清除」。只在筛了东西时出现。
  static const Key clearKey = ValueKey('filter-clear');

  /// 某一维那个按钮。点开是它的多选弹层。
  static Key dimensionKey(FilterDimension d) =>
      ValueKey('filter-dimension-${d.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(viewSharedStateProvider).filter;
    final notifier = ref.read(viewSharedStateProvider.notifier);

    return SizedBox(
      key: barKey,
      height: Spacing.minTouchTarget + Spacing.sm,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.pageHorizontal),
        children: [
          for (final dimension in FilterDimension.values) ...[
            _DimensionButton(dimension: dimension, filter: filter),
            const SizedBox(width: Spacing.sm),
          ],
          // 「全部清除」放在维度按钮**之后**：三个按钮固定宽度，
          // 一屏放得下，它跟在后面照样够得着；而放在最前面的话，
          // 它一出现就把三个维度整体往右推，按钮位置会跳。
          if (!filter.isEmpty)
            SelectableChip(
              key: clearKey,
              label: '清除筛选',
              selected: false,
              onSelected: (_) => notifier.clearFilter(),
            ),
        ],
      ),
    );
  }
}

/// 一个维度的入口。
class _DimensionButton extends StatelessWidget {
  const _DimensionButton({required this.dimension, required this.filter});

  final FilterDimension dimension;
  final FilterSpec filter;

  @override
  Widget build(BuildContext context) {
    final count = FilterKeys.countOf(filter, dimension);

    return SelectableChip(
      key: FilterBar.dimensionKey(dimension),
      // 计数写进标签里，不做成角标：角标是纯图形，
      // 屏幕阅读器读不出「状态筛了两项」（NFR-A11Y-01）。
      label: count == 0 ? dimension.label : '${dimension.label} $count',
      selected: count > 0,
      onSelected: (_) => showFilterSheet(context, dimension),
    );
  }
}

/// 列表视图（view-specs §2、FR-VIEW-02）。
///
/// **当前只实现了空态。** 分组、排序、筛选、滑动手势按 §2.1–§2.4 还没做，
/// 那是这个 feature 接下来的工作 —— 这里不放假数据占位，
/// 空态本身是规格里要求的一屏（§8.2），不是占位符。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/empty_state.dart';

class TaskListPage extends ConsumerWidget {
  const TaskListPage({this.onCreateTask, super.key});

  /// 空态里那个行动按钮。为 null 时按钮不出现 ——
  /// §8.2 要求「一个明确行动按钮」，而一个点不动的按钮比没有更糟。
  final VoidCallback? onCreateTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EmptyState(
      illustration: const EmptyIllustration(icon: Icons.wb_sunny_outlined),
      message: '今天还空着，\n要不要添一件想做的事？',
      actionLabel: onCreateTask == null ? null : '新建任务',
      onAction: onCreateTask,
    );
  }
}

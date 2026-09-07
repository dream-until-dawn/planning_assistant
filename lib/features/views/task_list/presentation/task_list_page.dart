/// 列表视图（view-specs §2、FR-VIEW-02）。
///
/// **当前只做到「看得见」**：分组、排序、筛选、滑动手势按 §2.1–§2.4
/// 还没做，是这个 feature 接下来的工作。空态不是占位符，
/// 它是规格里要求的一屏（§8.2）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/empty_state.dart';
import '../../../../design/components/task_card.dart';
import '../../../../design/theme/app_theme.dart';
import '../../../../design/tokens/dimensions.dart';
import '../../../../domain/entities/task.dart';
import '../../../../domain/value_objects/task_status.dart';
import '../application/task_list_actions.dart';
import '../application/task_list_providers.dart';

class TaskListPage extends ConsumerWidget {
  const TaskListPage({this.onCreateTask, super.key});

  /// 空态里那个行动按钮。为 null 时按钮不出现 ——
  /// §8.2 要求「一个明确行动按钮」，而一个点不动的按钮比没有更糟。
  final VoidCallback? onCreateTask;

  static const Key listKey = ValueKey('task-list');
  static const Key errorKey = ValueKey('task-list-error');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(visibleTasksProvider);

    return tasks.when(
      // 加载中**不画转圈**：本地 SQLite 的首帧通常在一帧内就来了，
      // 转圈只会闪一下，比直接等更吵。真慢的话是另一个问题，
      // 该去查那个，而不是拿转圈盖住。
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const _LoadFailed(key: errorKey),
      data: (list) => list.isEmpty
          ? EmptyState(
              illustration: const EmptyIllustration(
                icon: Icons.wb_sunny_outlined,
              ),
              message: '今天还空着，\n要不要添一件想做的事？',
              actionLabel: onCreateTask == null ? null : '新建任务',
              onAction: onCreateTask,
            )
          : ListView.separated(
              key: listKey,
              padding: const EdgeInsets.all(Spacing.pageHorizontal),
              itemCount: list.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: Spacing.cardGap),
              itemBuilder: (context, i) {
                final task = list[i];
                final isDone = task.status == TaskStatus.done;
                return TaskCard(
                  data: _toCardData(context, task),
                  // 就地完成（view-specs §0.3）。
                  //
                  // 完成后**不立即消失**（design-system §8.1）——
                  // 卡片留在原位只是划掉，给撤销留时间。
                  // 「完成即消失」在误触时最伤：那条任务去哪了、
                  // 怎么找回来，用户完全没有线索。
                  onToggleDone: () => ref
                      .read(toggleTaskDoneProvider)
                      .call(taskId: task.id, isDone: isDone),
                );
              },
            ),
    );
  }
}

/// 领域实体 → 卡片展示数据。
///
/// 卡片是纯展示的，不认识 [Task]（design-system §8.1 的分工），
/// 所以整形放在这里。
TaskCardData _toCardData(BuildContext context, Task task) {
  final colors = context.appColors;
  return TaskCardData(
    title: task.title,
    // 分类还没实现（Categories 表在，领域实体与仓库查询都还没有）。
    // **不假装有分类**：统一「未分类」+ 中性色条，
    // 等分类做出来再接。编造一个分类名会让 §8.1 那条
    // 「分类名必须以文字出现」看起来已经满足，其实没有。
    categoryName: '未分类',
    categoryColor: colors.borderSubtle,
    timeLabel: _timeLabelOf(task),
    isDone: task.status == TaskStatus.done,
  );
}

/// 卡片右侧那个时间标签。
///
/// 全天任务不显示时刻（design-system §8.1）—— `isAllDay` 与
/// `startMinute` 是两个独立字段，全天时那个 00:00 只是占位，
/// **不表示「零点」这个时刻**（见 `LocalWallTime.allDay` 的注释）。
String? _timeLabelOf(Task task) {
  if (task.isAllDay) return null;
  final m = task.startMinute;
  if (m == null) return null;
  return '${m.hour.toString().padLeft(2, '0')}:'
      '${m.minute.toString().padLeft(2, '0')}';
}

/// 读库失败。
///
/// **显式一屏，不是空列表** —— 出错时显示空列表会让用户以为
/// 「我的任务全没了」，那是最吓人的误解，而且它与真的没有任务
/// 长得一模一样。
class _LoadFailed extends StatelessWidget {
  const _LoadFailed({super.key});

  @override
  Widget build(BuildContext context) => const EmptyState(
    illustration: EmptyIllustration(icon: Icons.cloud_off_outlined),
    message: '没能读出任务列表。\n重开一次试试？',
  );
}

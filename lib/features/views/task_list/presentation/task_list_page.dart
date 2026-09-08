/// 列表视图（view-specs §2、FR-VIEW-02）。
///
/// 分组与组内排序按 §2.1/§2.2 做好了。**筛选（§2.3）与滑动手势（§2.4）
/// 还没做**，是这个 feature 接下来的工作。
/// 空态不是占位符，它是规格里要求的一屏（§8.2）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/app_chip.dart';
import '../../../../design/components/empty_state.dart';
import '../../../../design/components/task_card.dart';
import '../../../../design/tokens/dimensions.dart';
import '../../../../domain/entities/category.dart';
import '../../../../domain/entities/task.dart';
import '../../../../domain/value_objects/task_status.dart';
import '../../shared/application/category_providers.dart';
import '../application/task_grouping.dart';
import '../application/task_list_actions.dart';
import '../application/task_list_providers.dart';

class TaskListPage extends ConsumerStatefulWidget {
  const TaskListPage({this.onCreateTask, super.key});

  /// 空态里那个行动按钮。为 null 时按钮不出现 ——
  /// §8.2 要求「一个明确行动按钮」，而一个点不动的按钮比没有更糟。
  final VoidCallback? onCreateTask;

  static const Key listKey = ValueKey('task-list');
  static const Key errorKey = ValueKey('task-list-error');

  /// 某个分组标题的 Key。
  static Key groupHeaderKey(String groupKey) =>
      ValueKey('task-group-$groupKey');

  @override
  ConsumerState<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends ConsumerState<TaskListPage> {
  /// 用户手动改过折叠状态的组。
  ///
  /// **只记「改过的」，不记全部** —— 默认折不折叠由分组规则决定
  /// （§2.4：逾期组默认折叠）。若在这里存下全部组的布尔值，
  /// 规则改了之后旧状态会盖住新默认，而用户从没表达过那个意见。
  final _collapseOverrides = <String, bool>{};

  bool _isCollapsed(TaskGroup group) =>
      _collapseOverrides[group.key] ?? group.collapsedByDefault;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(visibleTasksProvider);
    final categories = ref.watch(categoryByIdProvider);
    final groups = ref.watch(groupedTasksProvider);

    return tasks.when(
      // 加载中**不画转圈**：本地 SQLite 的首帧通常在一帧内就来了，
      // 转圈只会闪一下，比直接等更吵。真慢的话是另一个问题，
      // 该去查那个，而不是拿转圈盖住。
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const _LoadFailed(key: TaskListPage.errorKey),
      data: (list) => list.isEmpty
          ? EmptyState(
              illustration: const EmptyIllustration(
                icon: Icons.wb_sunny_outlined,
              ),
              message: '今天还空着，\n要不要添一件想做的事？',
              actionLabel: widget.onCreateTask == null ? null : '新建任务',
              onAction: widget.onCreateTask,
            )
          : ListView(
              key: TaskListPage.listKey,
              padding: const EdgeInsets.all(Spacing.pageHorizontal),
              children: [
                for (final group in groups) ...[
                  _GroupHeader(
                    key: TaskListPage.groupHeaderKey(group.key),
                    group: group,
                    collapsed: _isCollapsed(group),
                    onToggle: () => setState(() {
                      _collapseOverrides[group.key] = !_isCollapsed(group);
                    }),
                  ),
                  if (!_isCollapsed(group))
                    for (final task in group.tasks) ...[
                      TaskCard(
                        data: _toCardData(task, categories),
                        // 就地完成（view-specs §0.3）。
                        //
                        // 完成后**不立即消失**（design-system §8.1）——
                        // 卡片留在原位只是划掉，给撤销留时间。
                        // 「完成即消失」在误触时最伤：那条任务去哪了、
                        // 怎么找回来，用户完全没有线索。
                        onToggleDone: () => ref
                            .read(toggleTaskDoneProvider)
                            .call(
                              taskId: task.id,
                              isDone: task.status == TaskStatus.done,
                            ),
                      ),
                      const SizedBox(height: Spacing.cardGap),
                    ],
                  const SizedBox(height: Spacing.sm),
                ],
              ],
            ),
    );
  }
}

/// 分组标题。
///
/// **带计数，而且折叠时也带** —— 折叠的意义是「我知道有这些，但先不看」；
/// 没有计数的话折叠就等于把信息藏了。§2.4 让逾期组默认折叠，
/// 正是靠这个计数让用户知道欠了多少。
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.group,
    required this.collapsed,
    required this.onToggle,
    super.key,
  });

  final TaskGroup group;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      expanded: !collapsed,
      label: '${group.title}，${group.tasks.length} 条',
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: ConstrainedBox(
          // 可点即需 48dp（§5）。
          constraints: const BoxConstraints(minHeight: Spacing.minTouchTarget),
          child: Row(
            children: [
              // 折叠状态**不只靠这个图标**：折叠时整组卡片消失，
              // 那本身就是最强的指示，图标只是辅助。
              Icon(
                collapsed ? Icons.chevron_right : Icons.expand_more,
                size: TypeScale.titleMdSize,
              ),
              const SizedBox(width: Spacing.xs),
              Text(group.title, style: text.titleMedium),
              const SizedBox(width: Spacing.sm),
              Text('${group.tasks.length}', style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// 领域实体 → 卡片展示数据。
///
/// 卡片是纯展示的，不认识 [Task]（design-system §8.1 的分工），
/// 所以整形放在这里。
TaskCardData _toCardData(Task task, Map<String, Category> categories) {
  // `categoryId == null` 就是未分类（settings-spec §3.0）——
  // 查不到也当未分类：那说明分类被删了，而删分类不该让任务消失。
  final category = task.categoryId == null ? null : categories[task.categoryId];

  return TaskCardData(
    title: task.title,
    categoryName: category?.name ?? Uncategorized.name,
    categoryColor: category == null
        ? Uncategorized.color
        : Color(category.colorArgb),
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

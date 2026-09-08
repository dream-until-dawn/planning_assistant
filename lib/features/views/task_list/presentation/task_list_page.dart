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
import '../../../../domain/entities/stage.dart';
import '../../../../domain/entities/task.dart';
import '../../../../domain/value_objects/task_status.dart';
import '../../../task/application/recurrence_draft.dart';
import '../../shared/application/category_providers.dart';
import '../../shared/application/task_occurrence.dart';
import '../../shared/application/task_providers.dart';
import '../../shared/application/view_shared_state.dart';
import '../application/task_grouping.dart';
import '../application/task_list_actions.dart';
import '../application/task_list_providers.dart';
import 'occurrence_actions_sheet.dart';

class TaskListPage extends ConsumerStatefulWidget {
  const TaskListPage({this.onCreateTask, this.onEditTask, super.key});

  /// 打开某条任务的编辑页。**由组合根接上路由**（同外壳的
  /// `onOpenSettings`）—— 视图自己不认识路由表。
  final void Function(String taskId)? onEditTask;

  /// 空态里那个行动按钮。为 null 时按钮不出现 ——
  /// §8.2 要求「一个明确行动按钮」，而一个点不动的按钮比没有更糟。
  final VoidCallback? onCreateTask;

  static const Key listKey = ValueKey('task-list');
  static const Key errorKey = ValueKey('task-list-error');

  /// 库里一条任务都没有。
  static const Key emptyKey = ValueKey('task-list-empty');

  /// 有任务，但筛完没剩。**与 [emptyKey] 是两回事**，
  /// 文案与行动按钮都不同。
  static const Key noMatchKey = ValueKey('task-list-no-match');

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
    final stages = ref.watch(stagesByTaskProvider);

    return tasks.when(
      // 加载中**不画转圈**：本地 SQLite 的首帧通常在一帧内就来了，
      // 转圈只会闪一下，比直接等更吵。真慢的话是另一个问题，
      // 该去查那个，而不是拿转圈盖住。
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const _LoadFailed(key: TaskListPage.errorKey),
      // **两种「空」要分开说。**
      //
      // 库里一条都没有 → 引导他新建。
      // 有任务但筛完没剩 → 引导他清筛选；这时候说「今天还空着」是错的，
      // 而且会让人以为任务丢了。两种状态长得一样是最容易让人慌的。
      data: (list) => list.isEmpty
          ? EmptyState(
              key: TaskListPage.emptyKey,
              illustration: const EmptyIllustration(
                icon: Icons.wb_sunny_outlined,
              ),
              message: '今天还空着，\n要不要添一件想做的事？',
              actionLabel: widget.onCreateTask == null ? null : '新建任务',
              onAction: widget.onCreateTask,
            )
          : groups.isEmpty
          ? EmptyState(
              key: TaskListPage.noMatchKey,
              illustration: const EmptyIllustration(icon: Icons.filter_alt_off),
              message: '这个筛选下没有任务。\n换个条件看看？',
              actionLabel: '清除筛选',
              onAction: () =>
                  ref.read(viewSharedStateProvider.notifier).clearFilter(),
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
                        // **key 用行的 id，不是 taskId** —— 同一条规则
                        // 展开出的几十行会共用一个 taskId，
                        // 列表复用时会认错行：勾一行动的是另一行。
                        key: ValueKey(task.id),
                        data: _toCardData(
                          task,
                          categories,
                          stages[task.taskId],
                        ),
                        // 就地完成（view-specs §0.3）。
                        //
                        // 完成后**不立即消失**（design-system §8.1）——
                        // 卡片留在原位只是划掉，给撤销留时间。
                        // 「完成即消失」在误触时最伤：那条任务去哪了、
                        // 怎么找回来，用户完全没有线索。
                        onToggleDone: () =>
                            ref.read(toggleTaskDoneProvider).call(task),
                        // 点卡片（view-specs §0.3）。
                        //
                        // 不重复的任务只有一条路，直接开编辑；
                        // 重复的先弹动作 —— 那里要先问「改哪一次」。
                        onTap: () => task.isOccurrence
                            ? showOccurrenceActions(
                                context,
                                task,
                                onEditSeries: widget.onEditTask,
                              )
                            : widget.onEditTask?.call(task.taskId),
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
TaskCardData _toCardData(
  TaskOccurrence row,
  Map<String, Category> categories,
  List<Stage>? stages,
) {
  final task = row.task;
  // `categoryId == null` 就是未分类（settings-spec §3.0）——
  // 查不到也当未分类：那说明分类被删了，而删分类不该让任务消失。
  final category = task.categoryId == null ? null : categories[task.categoryId];

  return TaskCardData(
    // 标题走**行**的：例外可以只改某一次的标题（FR-TASK-05）。
    title: row.title,
    // 重复任务的副信息里带上规则本身 —— 图标是辅助，
    // 文字才是「颜色/图标不单独承载信息」那条要求的落点（§8.1）。
    categoryName: task.isRecurring
        ? '${category?.name ?? Uncategorized.name} · ${_describeRule(task)}'
        : (category?.name ?? Uncategorized.name),
    categoryColor: category == null
        ? Uncategorized.color
        : Color(category.colorArgb),
    timeLabel: _timeLabelOf(row),
    stageProgress: _progressOf(stages),
    isRecurring: task.isRecurring,
    // 状态也走**行**的 —— 重复任务的 tasks.status 恒为 pending，
    // 看它的话每一次都显示成未完成（data-model §4.3）。
    isDone: row.status == TaskStatus.done,
  );
}

/// 把 RRULE 说成人话。
///
/// **只认界面自己造得出来的那几种**（`RecurrenceDraft` 覆盖的范围）。
/// 认不出来时退回一句「重复」——库里可能有导入进来的、更复杂的规则，
/// 那时说「重复」是对的，而硬猜一个描述会说错。
///
/// 一度是在这里 `rule.contains('FREQ=WEEKLY')` 挑关键字拼句子，于是
/// `INTERVAL=3` 的规则在卡片上显示成**「每周」**—— 挑着认的部件拼出来的
/// 句子，缺的那部分不是「没说」，是「说错了」。现在整条交给
/// [RecurrenceDraft.fromRrule]：它认不全就返回 null，一个字都不猜。
///
/// 结束条件不上卡片（`withEnd: false`）：副信息只有一行且会截断，
/// 而「重复什么」比「什么时候停」更要紧。
String _describeRule(Task task) {
  final recurrence = task.recurrence;
  if (recurrence == null) return '重复';
  return RecurrenceDraft.fromRrule(recurrence)?.describe(withEnd: false) ??
      '重复';
}

/// 阶段进度 = 已完成阶段数 / 总数（FR-TASK-02）。
///
/// **没有阶段就是 null**，不是 `(0, 0)` —— 后者会让卡片显示「阶段 0/0」，
/// 而单项任务压根没有阶段这个概念。
(int, int)? _progressOf(List<Stage>? stages) {
  if (stages == null || stages.isEmpty) return null;
  final done = stages.where((s) => s.status == TaskStatus.done).length;
  return (done, stages.length);
}

/// 卡片右侧那个时间标签。
///
/// 全天任务不显示时刻（design-system §8.1）—— `isAllDay` 与
/// `startMinute` 是两个独立字段，全天时那个 00:00 只是占位，
/// **不表示「零点」这个时刻**（见 `LocalWallTime.allDay` 的注释）。
///
/// **没有日期也不显示时刻。** 「12:32，但不知道哪天」指向不了任何东西，
/// 摆在卡片上只会让人以为它有安排。编辑器现在不会再产出这种数据
/// （关掉全天会自动补今天），但**库里可能已经有** —— 早期版本存下的、
/// 或将来导入进来的。渲染层照着不变量来，比相信数据一定干净稳妥。
String? _timeLabelOf(TaskOccurrence row) {
  // 走**行**的字段：被例外挪到别的时刻的那一次，卡片上要显示挪之后的。
  if (row.isAllDay) return null;
  if (row.planDate == null) return null;
  final m = row.startMinute;
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

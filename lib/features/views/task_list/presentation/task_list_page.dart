/// 列表视图（view-specs §2、FR-VIEW-02）。
///
/// 分组与组内排序按 §2.1/§2.2 做好了。**筛选（§2.3）与滑动手势（§2.4）
/// 还没做**，是这个 feature 接下来的工作。
/// 空态不是占位符，它是规格里要求的一屏（§8.2）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/empty_state.dart';
import '../../../../design/components/task_card.dart';
import '../../../../design/theme/app_theme.dart';
import '../../../../design/tokens/dimensions.dart';
import '../../shared/application/create_task_at.dart';
import '../../shared/application/task_providers.dart';
import '../../shared/application/view_shared_state.dart';
import '../../shared/presentation/occurrence_card_data.dart';
import '../application/bulk_selection.dart';
import '../application/task_grouping.dart';
import '../application/task_list_actions.dart';
import '../application/task_list_providers.dart';
import 'occurrence_actions_sheet.dart';
import 'swipe_row.dart';

class TaskListPage extends ConsumerStatefulWidget {
  const TaskListPage({this.onCreateTask, this.onEditTask, super.key});

  /// 打开某条任务的编辑页。**由组合根接上路由**（同外壳的
  /// `onOpenSettings`）—— 视图自己不认识路由表。
  ///
  /// [from] 非空表示「本次及以后」的分割点（FR-TASK-06）。
  final void Function(String taskId, {String? from})? onEditTask;

  /// 空态里那个行动按钮。为 null 时按钮不出现 ——
  /// §8.2 要求「一个明确行动按钮」，而一个点不动的按钮比没有更糟。
  final CreateTaskAt? onCreateTask;

  static const Key listKey = ValueKey('task-list');
  static const Key errorKey = ValueKey('task-list-error');

  /// 库里一条任务都没有。
  static const Key emptyKey = ValueKey('task-list-empty');

  /// 有任务，但筛完没剩。**与 [emptyKey] 是两回事**，
  /// 文案与行动按钮都不同。
  static const Key noMatchKey = ValueKey('task-list-no-match');

  /// 某个分组标题的 Key。
  /// 多选（view-specs §2.4「长按 → 进入多选模式」）。
  static const Key selectionBarKey = ValueKey('task-list-selection-bar');
  static const Key selectionCountKey = ValueKey('task-list-selection-count');
  static const Key selectionDoneKey = ValueKey('task-list-selection-done');
  static const Key selectionDeleteKey = ValueKey('task-list-selection-delete');
  static const Key selectionCancelKey = ValueKey('task-list-selection-cancel');

  static Key selectionCheckKey(String rowId) =>
      ValueKey('task-list-select-$rowId');

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
    final groups = ref.watch(groupedTasksProvider);

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
          : Column(
              children: [
                if (ref.watch(selectionProvider).isNotEmpty)
                  const _SelectionBar(key: TaskListPage.selectionBarKey),
                Expanded(child: _buildList(groups)),
              ],
            ),
    );
  }

  Widget _buildList(List<TaskGroup> groups) {
    final selection = ref.watch(selectionProvider);
    return ListView(
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
              SwipeRow(
                row: task,
                // **key 用行的 id，不是 taskId** —— 同一条规则
                // 展开出的几行会共用一个 taskId，
                // 列表复用时会认错行：勾一行动的是另一行。
                key: ValueKey(task.id),
                child: TaskCard(
                  data: cardDataOf(ref, task),
                  // 就地完成（view-specs §0.3）。
                  //
                  // 完成后**不立即消失**（design-system §8.1）——
                  // 卡片留在原位只是划掉，给撤销留时间。
                  // 「完成即消失」在误触时最伤：那条任务去哪了、
                  // 怎么找回来，用户完全没有线索。
                  // **多选模式下勾选框让位给「选中」** ——
                  // 一个框在两种模式里表示两件事，是最容易点错的
                  // 那种设计。模式开着时它整个不响应。
                  onToggleDone: selection.isEmpty
                      ? () => ref.read(toggleTaskDoneProvider).call(task)
                      : null,
                  selected: selection.contains(task.id),
                  // 长按进多选（view-specs §2.4）。
                  //
                  // 长按在时间轴上是「在这儿新建」（FR-VIEW-07），
                  // 两处不冲突：那边按的是空白画布，这边按的是
                  // 一张卡片。同一个手势在不同对象上是不同动作，
                  // 这在列表类界面里是常见约定。
                  onLongPress: () =>
                      ref.read(selectionProvider.notifier).toggle(task.id),
                  // 点卡片（view-specs §0.3）。
                  //
                  // 不重复的任务只有一条路，直接开编辑；
                  // 重复的先弹动作 —— 那里要先问「改哪一次」。
                  // 多选模式下点击 = 选中/取消，不是打开。
                  onTap: () {
                    if (selection.isNotEmpty) {
                      ref.read(selectionProvider.notifier).toggle(task.id);
                      return;
                    }
                    task.isOccurrence
                        ? showOccurrenceActions(
                            context,
                            task,
                            onEditSeries: widget.onEditTask,
                          )
                        : widget.onEditTask?.call(task.taskId);
                  },
                ),
              ),
              const SizedBox(height: Spacing.cardGap),
            ],
          const SizedBox(height: Spacing.sm),
        ],
      ],
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

/// 多选模式下顶上那条（view-specs §2.4）。
///
/// **停在列表上方而不是浮在底部**：底部是加号的地盘，
/// 一个盖住加号的条会让「退出多选」变成必须先找按钮。
class _SelectionBar extends ConsumerWidget {
  const _SelectionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(selectionProvider).length;
    final colors = context.appColors;
    final bulk = ref.read(bulkActionsProvider);

    return Material(
      color: colors.sunken,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.pageHorizontal,
          vertical: Spacing.xs,
        ),
        child: Row(
          children: [
            IconButton(
              key: TaskListPage.selectionCancelKey,
              icon: const Icon(Icons.close),
              tooltip: '退出多选',
              onPressed: ref.read(selectionProvider.notifier).clear,
            ),
            Expanded(
              child: Text(
                '已选 $count 项',
                key: TaskListPage.selectionCountKey,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            IconButton(
              key: TaskListPage.selectionDoneKey,
              icon: const Icon(Icons.check_circle_outline),
              tooltip: '完成 / 取消完成',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final undo = await bulk.toggleDone();
                _offerUndo(messenger, '已更新 $count 项', undo);
              },
            ),
            IconButton(
              key: TaskListPage.selectionDeleteKey,
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final undo = await bulk.delete();
                _offerUndo(messenger, '已删除 $count 项', undo);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 批量操作**一定要给撤销**。
  ///
  /// 单行滑动都配了撤销（§2.4），而批量一次动的是十几条 ——
  /// 误触的代价按条数放大，撤销的必要性只会更高。
  void _offerUndo(
    ScaffoldMessengerState messenger,
    String message,
    VoidCallback undo,
  ) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(label: '撤销', onPressed: undo),
        ),
      );
  }
}

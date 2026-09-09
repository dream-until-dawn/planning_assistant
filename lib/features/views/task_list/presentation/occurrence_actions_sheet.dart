/// 点一行之后的动作（view-specs §0.3「点击实例 → 打开详情底部弹层」）。
///
/// 现在只放**重复任务的单次操作**（FR-TASK-05）。完整的详情弹层
/// （改标题、改时间、看阶段、删除）是 M3 的事 —— 先做这一部分，
/// 是因为跳过与撤回**没有别的入口**：数据层支持了，界面上够不着。
///
/// ## 跳过之后怎么找回来
///
/// 跳过的那一次「不出现在任何视图」（FR-TASK-05 验收），于是也就没有
/// 一行可以让用户反悔 —— 那是一条走进去出不来的路，M2 里已经栽过一次
/// （「到某天为止」选了却没地方选日期）。
///
/// 所以：筛选条里勾上「已跳过」时，那些次会以灰掉的样子回到列表
/// （`RecurrenceEngine.expand` 的 `includeSkipped`），从那里可以撤回。
/// 弹层里也直说了这句话 —— 不说的话，用户点下「跳过」时不知道
/// 自己还能不能反悔。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/tokens/dimensions.dart';
import '../../../../domain/value_objects/task_status.dart';
import '../../shared/application/task_occurrence.dart';
import '../../shared/application/task_providers.dart';
import '../../shared/presentation/toggle_done_action.dart';
import '../../shared/presentation/toggle_stage_action.dart';
import '../application/task_list_actions.dart';

/// 弹层里各行的 Key。
abstract final class OccurrenceSheetKeys {
  static const Key sheet = ValueKey('occurrence-sheet');
  static const Key skip = ValueKey('occurrence-skip');
  static const Key unskip = ValueKey('occurrence-unskip');
  static const Key hint = ValueKey('occurrence-skip-hint');
  static const Key editSeries = ValueKey('occurrence-edit-series');

  /// 不重复的任务那两条（用户第①条：两种任务同一套动作）。
  static const Key toggleDone = ValueKey('occurrence-toggle-done');
  static const Key edit = ValueKey('occurrence-edit');
  static const Key editFromHere = ValueKey('occurrence-edit-from-here');

  /// 这一次的阶段勾选（FR-TASK-07）。
  static Key stage(String stageId) => ValueKey('occurrence-stage-$stageId');
  static const Key stageSection = ValueKey('occurrence-stages');
}

/// 打开某一行的动作弹层。
///
/// ## 不重复的任务也弹（用户 2026-09-09 定的）
///
/// 一度只对重复任务弹，不重复的点一下直接推编辑页 —— 理由写的是
/// 「不重复的没有可放的动作，弹一个空壳比不弹更让人以为坏了」。
/// 用户的原话：
///
/// > 统一任务点击，无论是否重复任务都出现抽屉选项
/// > （非重复的任务的选项可以是 完成 和 编辑）
///
/// 那个「空壳」的前提不成立了：完成与编辑本来就是两个动作，
/// 而先前把「编辑」做成了点一下的默认结果、把「完成」赶到卡片左边那个
/// 小圆钮上 —— **同一行上两个动作，一个要点卡片、一个要点钮**，
/// 而重复任务那边两个都在弹层里。统一之后哪一种任务都是同一套。
Future<void> showOccurrenceActions(
  BuildContext context,
  TaskOccurrence row, {
  void Function(String taskId, {String? from})? onEditSeries,
}) => showModalBottomSheet<void>(
  context: context,
  builder: (context) =>
      _OccurrenceActionsSheet(row: row, onEditSeries: onEditSeries),
);

class _OccurrenceActionsSheet extends ConsumerWidget {
  const _OccurrenceActionsSheet({required this.row, this.onEditSeries});

  final TaskOccurrence row;
  final void Function(String taskId, {String? from})? onEditSeries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final actions = ref.read(occurrenceActionsProvider);
    final isSkipped = row.status == TaskStatus.skipped;
    final isDone = row.status == TaskStatus.done;

    return SafeArea(
      key: OccurrenceSheetKeys.sheet,
      // **要能滚。** 加上阶段清单之后，一条五六步的任务已经撑破
      // 弹层的自然高度 —— `Column(mainAxisSize: min)` 不滚，
      // 溢出的部分不是被裁掉就是报 RenderFlex overflow，
      // 而那几行恰好是最下面的「跳过这一次」。
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.pageHorizontal,
                Spacing.lg,
                Spacing.pageHorizontal,
                Spacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.title, style: text.titleMedium),
                  // **说清动作作用在哪一次上。** 不写日期的话，
                  // 「跳过」看着像是要停掉整条规则。
                  //
                  // 不重复的任务没有「这一次」这回事 —— 写上去反而
                  // 让人以为它也是重复的。
                  Text(
                    row.isOccurrence
                        ? '${row.planDate}这一次'
                        : (row.planDate == null ? '没有日期' : '${row.planDate}'),
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            if (row.stages.isNotEmpty) _StageChecklist(row: row),
            // ## 完成：两种任务都有，写法不同
            //
            // 不重复的改 `tasks.status`，某一次的写例外
            // （`ToggleTaskDone` 里那个岔口）。这里只表达意图，
            // 分流在那边。
            ListTile(
              key: OccurrenceSheetKeys.toggleDone,
              leading: Icon(
                isDone ? Icons.remove_done : Icons.check_circle_outline,
              ),
              title: Text(isDone ? '标为未完成' : '完成'),
              onTap: () {
                Navigator.of(context).pop();
                unawaited(toggleDoneWithUndo(context, ref, row));
              },
            ),
            // 不重复的任务：直接编辑它本身。重复的那两条在下面 ——
            // 它们要先说清「改的是整条还是从这次起」。
            if (!row.isOccurrence && onEditSeries != null)
              ListTile(
                key: OccurrenceSheetKeys.edit,
                leading: const Icon(Icons.edit_outlined),
                title: const Text('编辑'),
                onTap: () {
                  Navigator.of(context).pop();
                  onEditSeries!(row.taskId);
                },
              ),
            if (row.isOccurrence && onEditSeries != null)
              ListTile(
                key: OccurrenceSheetKeys.editSeries,
                leading: const Icon(Icons.edit_outlined),
                title: const Text('编辑整条重复任务'),
                // 说清作用范围。不说的话，用户会以为这是「只改这一次」——
                // 改完发现每一次都变了，那是最伤的一种误解。
                subtitle: const Text('改的是规则本身，每一次都会变'),
                onTap: () {
                  Navigator.of(context).pop();
                  onEditSeries!(row.taskId);
                },
              ),
            if (row.isOccurrence && onEditSeries != null && !isSkipped)
              ListTile(
                key: OccurrenceSheetKeys.editFromHere,
                leading: const Icon(Icons.call_split),
                title: const Text('本次及以后'),
                // 说清它做了什么：**不改历史**。不说的话，用户会担心
                // 之前做过的记录被一起改掉 —— 而那正是这个做法要保住的东西。
                subtitle: const Text('这一次之前的不受影响'),
                onTap: () {
                  Navigator.of(context).pop();
                  onEditSeries!(row.taskId, from: row.key!.value);
                },
              ),
            if (!row.isOccurrence)
              const SizedBox.shrink()
            else if (isSkipped)
              ListTile(
                key: OccurrenceSheetKeys.unskip,
                leading: const Icon(Icons.undo),
                title: const Text('恢复这一次'),
                onTap: () {
                  actions.unskip(row);
                  Navigator.of(context).pop();
                },
              )
            else ...[
              ListTile(
                key: OccurrenceSheetKeys.skip,
                leading: const Icon(Icons.event_busy_outlined),
                title: const Text('跳过这一次'),
                subtitle: const Text('只影响这一次，规则本身不变'),
                onTap: () {
                  actions.skip(row);
                  Navigator.of(context).pop();
                },
              ),
              Padding(
                key: OccurrenceSheetKeys.hint,
                padding: const EdgeInsets.fromLTRB(
                  Spacing.pageHorizontal,
                  0,
                  Spacing.pageHorizontal,
                  Spacing.lg,
                ),
                // 先告诉他反悔的路在哪，再让他点那个按钮。
                child: Text(
                  '跳过之后它不再出现在列表里。想找回来，'
                  '在顶部筛选里勾上「已跳过」。',
                  style: text.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 这一次的阶段清单（FR-TASK-07、view-specs §4.3「可就地标完成」）。
///
/// ## 为什么勾在这里，而不是在编辑器里
///
/// 编辑器编的是**整条任务**。在那儿勾一个阶段，改的是
/// `Stage.status` —— 于是「每周三·健身」的热身勾掉一次，
/// **每一周**的热身都成了已完成。
///
/// 「就地标完成」里的「就地」永远发生在**某一次**上，
/// 所以它属于这个弹层：弹层的标题那一行已经写明了是哪一次。
class _StageChecklist extends ConsumerWidget {
  const _StageChecklist({required this.row});

  final TaskOccurrence row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    // **弹层拿到的 `row` 是打开那一刻的快照**，勾一下之后它不会自己变新。
    //
    // 重复那一半原本靠现读 `stageStatesByTaskProvider` 绕开了这件事；
    // 不重复的任务状态在 `Stage.status` 上，那条路上什么都没读 ——
    // 于是它的勾选框**打开是空的、勾完还是空的**。
    // （更准的说法：那里把 `occurrenceStates` 传成了空表而不是 null，
    // 而空表的意思是「这一次一步都没做」。）
    //
    // 两半一起解决：拿新的阶段与新的状态**重建这一行**，再问
    // `row.stageStatus` —— 「状态该读哪一份」的分流仍然只有那一处。
    final live = TaskOccurrence(
      task: row.task,
      occurrence: row.occurrence,
      stages: ref.watch(stagesByTaskProvider)[row.taskId] ?? row.stages,
      stageStates:
          ref.watch(stageStatesByTaskProvider)[row.taskId]?[row.key] ??
          const {},
    );

    return Column(
      key: OccurrenceSheetKeys.stageSection,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.pageHorizontal,
            0,
            Spacing.pageHorizontal,
            Spacing.xs,
          ),
          child: Text('这一次的进度', style: text.bodySmall),
        ),
        for (final stage in live.stages)
          CheckboxListTile(
            key: OccurrenceSheetKeys.stage(stage.id),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: live.stageStatus(stage) == TaskStatus.done,
            title: Text(stage.title),
            // **喂 `live` 不是 `row`**：不重复那条路要拿这一行的全部阶段
            // 去整表替换，用快照的话，勾第二步会把第一步写回未完成。
            onChanged: (v) => unawaited(
              toggleStageDone(context, ref, live, stage.id, done: v ?? false),
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}

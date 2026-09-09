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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/tokens/dimensions.dart';
import '../../../../domain/services/stage_occurrence_status.dart';
import '../../../../domain/value_objects/task_status.dart';
import '../../shared/application/task_occurrence.dart';
import '../../shared/application/task_providers.dart';
import '../application/task_list_actions.dart';

/// 弹层里各行的 Key。
abstract final class OccurrenceSheetKeys {
  static const Key sheet = ValueKey('occurrence-sheet');
  static const Key skip = ValueKey('occurrence-skip');
  static const Key unskip = ValueKey('occurrence-unskip');
  static const Key hint = ValueKey('occurrence-skip-hint');
  static const Key editSeries = ValueKey('occurrence-edit-series');
  static const Key editFromHere = ValueKey('occurrence-edit-from-here');

  /// 这一次的阶段勾选（FR-TASK-07）。
  static Key stage(String stageId) => ValueKey('occurrence-stage-$stageId');
  static const Key stageSection = ValueKey('occurrence-stages');
}

/// 打开某一行的动作弹层。
///
/// 不重复的任务暂时没有可放的动作，所以**不弹** —— 弹一个空壳
/// 比不弹更让人以为坏了。
Future<void> showOccurrenceActions(
  BuildContext context,
  TaskOccurrence row, {
  void Function(String taskId, {String? from})? onEditSeries,
}) {
  if (!row.isOccurrence) return Future<void>.value();
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) =>
        _OccurrenceActionsSheet(row: row, onEditSeries: onEditSeries),
  );
}

class _OccurrenceActionsSheet extends ConsumerWidget {
  const _OccurrenceActionsSheet({required this.row, this.onEditSeries});

  final TaskOccurrence row;
  final void Function(String taskId, {String? from})? onEditSeries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final actions = ref.read(occurrenceActionsProvider);
    final isSkipped = row.status == TaskStatus.skipped;

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
                  Text('${row.planDate}这一次', style: text.bodySmall),
                ],
              ),
            ),
            if (row.stages.isNotEmpty) _StageChecklist(row: row),
            if (onEditSeries != null)
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
            if (onEditSeries != null && !isSkipped)
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
            if (isSkipped)
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
    final actions = ref.read(occurrenceActionsProvider);
    final states =
        ref.watch(stageStatesByTaskProvider)[row.taskId]?[row.key] ?? const {};

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
        for (final stage in row.stages)
          CheckboxListTile(
            key: OccurrenceSheetKeys.stage(stage.id),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value:
                stageStatusFor(stage, occurrenceStates: states) ==
                TaskStatus.done,
            title: Text(stage.title),
            onChanged: (v) => actions.setStageDone(row, stage.id, v ?? false),
          ),
        const Divider(height: 1),
      ],
    );
  }
}

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
import '../../../../domain/value_objects/task_status.dart';
import '../../shared/application/task_occurrence.dart';
import '../application/task_list_actions.dart';

/// 弹层里各行的 Key。
abstract final class OccurrenceSheetKeys {
  static const Key sheet = ValueKey('occurrence-sheet');
  static const Key skip = ValueKey('occurrence-skip');
  static const Key unskip = ValueKey('occurrence-unskip');
  static const Key hint = ValueKey('occurrence-skip-hint');
}

/// 打开某一行的动作弹层。
///
/// 不重复的任务暂时没有可放的动作，所以**不弹** —— 弹一个空壳
/// 比不弹更让人以为坏了。
Future<void> showOccurrenceActions(BuildContext context, TaskOccurrence row) {
  if (!row.isOccurrence) return Future<void>.value();
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) => _OccurrenceActionsSheet(row: row),
  );
}

class _OccurrenceActionsSheet extends ConsumerWidget {
  const _OccurrenceActionsSheet({required this.row});

  final TaskOccurrence row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final actions = ref.read(occurrenceActionsProvider);
    final isSkipped = row.status == TaskStatus.skipped;

    return SafeArea(
      key: OccurrenceSheetKeys.sheet,
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
    );
  }
}

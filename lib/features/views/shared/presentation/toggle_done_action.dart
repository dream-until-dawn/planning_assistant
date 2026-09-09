/// 完成钮：就地完成 + 撤销（view-specs §0.3）。
///
/// ## 为什么要收成一个函数
///
/// 规格里那一行写的是「**所有视图一致**」，而实现是四个视图各写一遍
/// `onToggleDone: () => ref.read(toggleTaskDoneProvider)(row)` ——
/// 返回的撤销闭包被直接丢掉。于是：
///
/// | | 滑动完成 | 完成钮 |
/// |---|---|---|
/// | 列表 | 有撤销 | **没有** |
/// | 日历 | — | **没有** |
/// | 时间轴 | — | 有（这一版新写的） |
///
/// 同一件事在同一个视图里有两条路，一条给撤销一条不给 —— 而用户不会
/// 知道自己走的是哪条。时间轴上更要命：勾掉的行**当场消失**
/// （那个视图只装未完成的），没有撤销的话误触之后它去哪了都不知道。
///
/// 所以入口收成一个。四个视图的完成钮都接它，撤销就不再是「谁记得写谁有」。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/undo_snackbar.dart';
import '../../../../domain/value_objects/task_status.dart';
import '../../task_list/application/task_list_actions.dart';
import '../application/task_occurrence.dart';

/// 勾/取消这一行，并弹一条带撤销的提示。
///
/// [messenger] 在 await **之前**取好 —— 异步之后 context 可能已经不在
/// 树上了（勾完成会让这一行从时间轴上消失，那正是它被拆掉的时刻）。
Future<void> toggleDoneWithUndo(
  BuildContext context,
  WidgetRef ref,
  TaskOccurrence row,
) async {
  final messenger = ScaffoldMessenger.of(context);
  // **先读状态再动手** —— 动完之后 row 是旧快照，读出来的还是旧值，
  // 但文案说的是「刚才发生了什么」，靠的正是这个旧值。
  final wasDone = row.status == TaskStatus.done;
  final undo = await ref.read(toggleTaskDoneProvider)(row);

  showUndoSnackBar(
    messenger,
    wasDone ? '已标为未完成：${row.title}' : '已完成：${row.title}',
    onUndo: undo,
  );
}

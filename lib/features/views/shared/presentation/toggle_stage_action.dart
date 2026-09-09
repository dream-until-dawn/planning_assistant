/// 勾/取消一个阶段，并把可能已经过期的撤销提示撤下。
///
/// ## 为什么要收成一个函数
///
/// 与 `toggle_done_action.dart` 同一个理由，只是问题反过来：那边是
/// 「四个视图各写一遍，有的忘了给撤销」，这边是**撤销给多了** ——
/// 一条已经不该再点的撤销还挂在屏幕上。
///
/// [ToggleTaskDone] 的撤销闭包捕获的是**点完成那一刻**的阶段快照
/// （它必须捕获：反向的状态命令走同一套级联，会把本来就勾着的那一步
/// 一起清掉）。提示还挂着的那几秒里，用户可以在别处改某一步 ——
/// 那份快照当场过期，再点撤销就会把这次改动盖掉。
///
/// 与其让一个会盖掉新改动的撤销挂在那儿，不如把它撤下来：
/// **能撤销的窗口短一点，好过撤销做错事。**
///
/// 收成一个函数是因为勾阶段有两个入口（列表卡片上的子项、单次动作弹层），
/// 各写一遍的话迟早只有一个记得撤提示 —— 而那正是这个仓库反复踩的形状。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../task_list/application/task_list_actions.dart';
import '../application/task_occurrence.dart';

Future<void> toggleStageDone(
  BuildContext context,
  WidgetRef ref,
  TaskOccurrence row,
  String stageId, {
  required bool done,
}) async {
  // messenger 在 await 之前取好，同 `toggleDoneWithUndo` 那条注释。
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  await ref.read(occurrenceActionsProvider).setStageDone(row, stageId, done);
}

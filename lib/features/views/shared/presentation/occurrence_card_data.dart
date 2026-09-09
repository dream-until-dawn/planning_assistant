/// 把一行发生整形成卡片要显示的东西（design-system §8.1）。
///
/// **四个视图共用。** 一度只有列表用得上，就放在 `task_list_page.dart`
/// 里当私有函数；时间轴的「随时」区要显示同样的卡片时，
/// 摆在眼前的两条路都是错的：复制一份（同一条规矩两处维护，
/// 迟早一处显示「每周」一处显示「每 3 周」），或者让时间轴去 import
/// 列表那个页面（视图之间横向依赖，module-map §3 不允许）。
///
/// 所以挪到共享层。这里只做**整形**，不查库、不认识 provider。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/app_chip.dart';
import '../../../../design/components/task_card.dart';
import '../../../../domain/entities/category.dart';
import '../../../../domain/entities/task.dart';
import '../../../../domain/value_objects/task_status.dart';
import '../../../task/application/recurrence_draft.dart';
import '../application/category_providers.dart';
import '../application/task_occurrence.dart';

/// 一行卡片要的全部展示数据 —— **视图统一走这个入口**。
///
/// 三个视图此前各写一遍 `occurrenceCardData(row, categories,
/// stages[row.taskId])`。加「这一次的阶段状态」时要改三处，
/// 而漏掉任何一处的表现是：那个视图的进度永远显示整条任务的，
/// 与另外两个说的不一样 —— 还不会报错。
///
/// 所以把「要喂哪些东西」收在这里，视图只给一行。
/// 纯函数版 [occurrenceCardData] 留着给测试直接构造用。
TaskCardData cardDataOf(WidgetRef ref, TaskOccurrence row) =>
    occurrenceCardData(row, ref.watch(categoryByIdProvider));

/// 领域实体 → 卡片展示数据。
///
/// 卡片是纯展示的，不认识 [Task]（design-system §8.1 的分工），
/// 所以整形放在这里。
TaskCardData occurrenceCardData(
  TaskOccurrence row,
  Map<String, Category> categories,
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
        ? '${category?.name ?? Uncategorized.name} · ${describeRule(task)}'
        : (category?.name ?? Uncategorized.name),
    categoryColor: category == null
        ? Uncategorized.color
        : Color(category.colorArgb),
    timeLabel: timeLabelOf(row),
    // **进度问行自己**（`TaskOccurrence.stageProgress`）——
    // 那里面才知道这一行是不是「某一次」，以及该看哪一份状态。
    stageProgress: switch (row.stageProgress) {
      null => null,
      final p => (p.done, p.total),
    },
    isRecurring: task.isRecurring,
    // 「普通」不显示（见 `TaskCardData.priorityLabel`）。
    priorityLabel: task.priority == TaskPriority.normal
        ? null
        : task.priority.label,
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
String describeRule(Task task) {
  final recurrence = task.recurrence;
  if (recurrence == null) return '重复';
  return RecurrenceDraft.fromRrule(recurrence)?.describe(withEnd: false) ??
      '重复';
}

/// 阶段进度 = 已完成阶段数 / 总数（FR-TASK-02）。
///
/// **没有阶段就是 null**，不是 `(0, 0)` —— 后者会让卡片显示「阶段 0/0」，
/// 而单项任务压根没有阶段这个概念。

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
String? timeLabelOf(TaskOccurrence row) {
  // 走**行**的字段：被例外挪到别的时刻的那一次，卡片上要显示挪之后的。
  if (row.isAllDay) return null;
  if (row.planDate == null) return null;
  final m = row.startMinute;
  if (m == null) return null;
  return '${m.hour.toString().padLeft(2, '0')}:'
      '${m.minute.toString().padLeft(2, '0')}';
}

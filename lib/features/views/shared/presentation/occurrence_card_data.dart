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

import '../../../../app_providers.dart';
import '../../../../core/time/plan_date.dart';
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
TaskCardData cardDataOf(
  WidgetRef ref,
  TaskOccurrence row, {
  bool withTime = true,
  bool withStages = false,
}) => occurrenceCardData(
  row,
  ref.watch(categoryByIdProvider),
  today: ref.watch(todayProvider),
  withTime: withTime,
  withStages: withStages,
);

/// 领域实体 → 卡片展示数据。
///
/// 卡片是纯展示的，不认识 [Task]（design-system §8.1 的分工），
/// 所以整形放在这里。
TaskCardData occurrenceCardData(
  TaskOccurrence row,
  Map<String, Category> categories, {
  required PlanDate today,

  /// 时间轴自己有一条时间栏，卡片再写一遍就是同一个时刻在一行里
  /// 出现两次。只有那一个视图关这个开关。
  bool withTime = true,

  /// 把阶段摊成子项（用户第 ② 条）。**只有列表开**。
  ///
  /// 日历与甘特的卡片挤在格子里，多摞几行会把同一天的其它任务顶出
  /// 可视区 —— 那两个视图回答的是「这一天有什么」。时间轴另有安排：
  /// 它把阶段摆成了独立的卡片（上一批做的），再摊一次就是同一件事
  /// 在一屏里出现两遍。
  bool withStages = false,
}) {
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
    timeLabel: withTime ? timeLabelOf(row, today: today) : null,
    // **进度问行自己**（`TaskOccurrence.stageProgress`）——
    // 那里面才知道这一行是不是「某一次」，以及该看哪一份状态。
    stageProgress: switch (row.stageProgress) {
      null => null,
      final p => (p.done, p.total),
    },
    // 子项的勾选状态**问行不问阶段**（同 `stageProgress` 那条）：
    // 重复任务的 `Stage.status` 没人读，这一次的状态在另一张表。
    stages: !withStages
        ? const []
        : [
            for (final stage in row.stages)
              TaskCardStage(
                id: stage.id,
                title: stage.title,
                isDone: row.stageStatus(stage) == TaskStatus.done,
              ),
          ],
    isRecurring: task.isRecurring,
    // 「普通」不显示（见 `TaskCardData.priorityLabel`）。
    priorityLabel: task.priority == TaskPriority.normal
        ? null
        : task.priority.label,
    // 状态也走**行**的 —— 重复任务的 tasks.status 恒为 pending，
    // 看它的话每一次都显示成未完成（data-model §4.3）。
    isDone: row.status == TaskStatus.done,
    // ## 这一项一度是**没人传**的
    //
    // `TaskCardData.isOverdue` 声明了、卡片也照它换左色条与时间色
    // （design-system §2.4），断言测试与 golden 也各有一条 ——
    // 但那些都是**直接构造 `TaskCardData`** 的。从真实数据这条路上
    // 过来的卡片永远拿到默认的 `false`，于是逾期样式在应用里
    // 一次都没出现过。
    //
    // 又是「模型有旋钮、界面够不着」的一例（testing-strategy §1.6），
    // 而且是最难发现的那一种：组件测试全绿，因为它们绕过了这里。
    isOverdue: _isOverdue(row, today),
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
/// 卡片副信息里的「什么时候」。
///
/// ## 不是今天的，就把日期写出来
///
/// 一度只写 `HH:mm`，而且**全天任务直接返回 null** —— 于是一条每天重复
/// 的全天任务，卡片上关于「哪一天」一个字都没有。
/// 用户报的原话：「每天的任务没有标注日期啊，我不知道这个每日任务
/// 具体是哪一日的，都放在逾期里我看不出啊」。
///
/// 分组标题只说得了「逾期」这一类，说不了组里那七行各是哪天 ——
/// 而重复任务恰恰会在「逾期」里堆出一长串长得一模一样的卡片。
///
/// **今天的不写日期**：那一行的分组标题已经写着「今天」了，
/// 再写一遍是噪音。其余一律写，包括明天 ——
/// 「明天」那一组只有一天，但写出日期不碍事，而少写会让规则变成
/// 「有时写有时不写」，用户得先弄懂规则才能读卡片。
String? timeLabelOf(TaskOccurrence row, {required PlanDate today}) {
  // 走**行**的字段：被例外挪到别的时刻的那一次，卡片上要显示挪之后的。
  final date = row.planDate;
  if (date == null) return null;

  final datePart = date == today ? null : '${date.month}/${date.day}';
  final m = row.isAllDay ? null : row.startMinute;
  final timePart = m == null
      ? null
      : '${m.hour.toString().padLeft(2, '0')}:'
            '${m.minute.toString().padLeft(2, '0')}';

  return switch ((datePart, timePart)) {
    (null, null) => null,
    (final d?, null) => d,
    (null, final t?) => t,
    (final d?, final t?) => '$d $t',
  };
}

/// 这一行逾期了没有。
///
/// **做完的不算逾期。** 上周做完的事就是做完了，给它标红只会让
/// 「有几件事欠着」这个问题的答案变多。跳过的同理。
bool _isOverdue(TaskOccurrence row, PlanDate today) {
  final date = row.planDate;
  if (date == null) return false;
  if (row.status == TaskStatus.done || row.status == TaskStatus.skipped) {
    return false;
  }
  return date.isBefore(today);
}

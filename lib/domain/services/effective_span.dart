/// 任务的**有效跨度**（data-model §4.7）。
///
/// ## 为什么这不是甘特图的私事
///
/// 阶段用相对偏移表达（§4.1），所以**末阶段的结束可能超出 `endDate`**。
/// 甘特图如果自行「扩展到末阶段结束」，而时间轴按 `endDate` 画，
/// 同一条任务在两个视图里跨度不同 —— 而「四视图共享同一份数据源」
/// 正是 FR-VIEW-05/06 的前提。
///
/// 所以这条规则放在领域层，四视图共用，**不得各自计算**。
///
/// > 它在文档里躺了很久没有实现：§4.7 写着「所有视图一律用
/// > `effectiveEnd`」，而在甘特之前没有任何视图读得到阶段，
/// > 于是那句话没有落点。又是一次「文档有、代码没有」。
library;

import '../../core/time/date_and_minute.dart';
import '../../core/time/minute_of_day.dart';
import '../../core/time/plan_date.dart';
import '../entities/stage.dart';

/// 一段有效跨度，两端都是墙钟。
typedef EffectiveSpan = ({DateAndMinute start, DateAndMinute end});

/// 把「结束日期 + 结束时刻」读成一个墙钟。
///
/// **「有结束日期、没有结束时刻」= 那天的 23:59**，与
/// `Task._endsBeforeItStarts`、`occurrence_expansion._durationOf`、
/// `timeline_blocks._endOffset` 同一个读法（data-model §3.1.1）。
/// 这几处必须是同一句话，所以规则写在这里一次。
DateAndMinute? storedEnd({
  required PlanDate? endDate,
  required MinuteOfDay? endMinute,
}) {
  if (endDate == null) return null;
  return DateAndMinute(endDate, endMinute ?? MinuteOfDay(minutesPerDay - 1));
}

/// 算一次发生的有效跨度。
///
/// [start] 是**这一次**的开始（重复任务每次不同）。
/// [end] 是存储侧读出来的结束（见 [storedEnd]）—— **由调用方给**，
/// 因为「存储侧」对重复任务来说是那一次的 override，不是任务本身。
/// 一度直接在这里读 `task.endDate`，于是重复任务的每一次都拿任务的
/// 结束当自己的：一条「每天 9:00–10:00」的规则，第二次发生会被算成
/// 「9 月 8 日 10:00 结束」，跨度是负的。时间轴那条用例当场变红。
///
/// 结束 = `max(存储的结束, 每个阶段的结束)`：
///
/// - 存储的结束可能为 null（没写结束）→ 那一侧不参与取最大；
/// - 阶段可能没有 `startOffsetMinutes`（还没排时间）→ 那一段不参与；
/// - 两边都没有 → 结束**与开始同一刻**（零长），不替用户假设时长；
/// - 结束**永远不早于开始**：库里可能有脏数据，倒挂的区间会让甘特
///   画出负高度然后抛。
EffectiveSpan effectiveSpan({
  required DateAndMinute start,
  DateAndMinute? end,
  Iterable<Stage> stages = const [],
}) {
  var latest = start;
  if (end != null && end.isAfter(latest)) latest = end;

  for (final stage in stages) {
    // `endOffsetMinutes` 为 null = 这个阶段还没排时间。
    //
    // **这个 continue 没有测试钉得住**：换成 `?? 0` 的话结果一模一样
    // —— `shiftFrom(start, 0)` 就是 start，而 latest 从 start 起只增不减，
    // 所以那一支永远赢不了。变异验证过。
    //
    // 留着是因为它说的是「没排时间的不参与」这件事本身。按 §7.1.1 的
    // 判据，没有测试撑腰的写法不配写一句斩钉截铁的注释，
    // 所以这里写的是它的真实状态：表意的，不可测。
    final offset = stage.endOffsetMinutes;
    if (offset == null) continue;
    final stageEnd = shiftFrom(start, offset);
    if (stageEnd.isAfter(latest)) latest = stageEnd;
  }

  return (start: start, end: latest);
}

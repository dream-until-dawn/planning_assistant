/// 阶段事项的起止**由阶段推出**（用户 2026-09-10 定）。
///
/// ## 方向反过来了
///
/// 在这之前，任务是锚：用户选任务的起止，阶段挂在上面，
/// `Stage.startOffsetMinutes` 是**相对任务开始**的偏移（data-model §4.1）。
///
/// 用户要的是反过来 —— **阶段时间必填，任务的起止取阶段里最早的开始与
/// 最晚的结束**。于是「任务开始」不再是一个用户填的字段，
/// 而是一个**推导结果**。
///
/// ## 存储不变，只是谁决定谁变了
///
/// 偏移这套存法**保留**，理由没变：一条每周重复的阶段事项，它的阶段
/// 写不出绝对日期（该写哪一周？），而偏移对每一次发生都成立。
///
/// 变的是：推导之后要把偏移**重新表达成「相对最早那个阶段」** ——
/// 于是最早那个阶段的偏移恒为 0，而任务开始就是它的绝对时刻。
/// 两件事必须一起做，否则任务挪了、阶段没跟着，或者反过来。
///
/// ## 为什么是纯函数
///
/// 它是这条改动里**唯一有判断的一段**（取最早、取最晚、重新表达偏移、
/// 以及「一个阶段都没填时间时什么也别推」）。放在这儿，它不用起一棵
/// widget 树就测得了，而编辑器那边只剩「显示/隐藏哪几个区」。
library;

import '../../../core/time/date_and_minute.dart';

/// 推导的结果：任务的起止，加上**重新表达过偏移**的阶段。
typedef DerivedSpan = ({
  DateAndMinute start,
  DateAndMinute end,
  List<({int? startOffsetMinutes, int? durationMinutes})> stages,
});

/// 一个阶段在推导里用得上的两样。
typedef StageTiming = ({int? startOffsetMinutes, int? durationMinutes});

/// 由阶段推出任务的起止，并把偏移改成相对新的开始。
///
/// [anchor] 是**当前**的任务开始 —— 传进来的偏移是相对它算的。
///
/// 返回 `null` 表示**推不出来**：一个带时间的阶段都没有。
/// 那时调用方该保持原样，而不是把任务的起止清掉 ——
/// 「推不出来」与「推出来是空的」是两回事。
///
/// 没填时间的阶段（`startOffsetMinutes == null`）**不参与推导**，
/// 但会原样留在结果里：它们由 `blockedReason` 那一侧去催填，
/// 而不是在这里被悄悄丢掉。
DerivedSpan? deriveSpanFromStages(
  DateAndMinute anchor,
  List<StageTiming> stages,
) {
  final timed = [
    for (final s in stages)
      if (s.startOffsetMinutes case final o?)
        (start: o, end: o + (s.durationMinutes ?? 0)),
  ];
  if (timed.isEmpty) return null;

  var earliest = timed.first.start;
  var latest = timed.first.end;
  for (final t in timed) {
    if (t.start < earliest) earliest = t.start;
    // **取最晚的结束，不是「最后一个阶段的结束」。** 阶段可以交叠，
    // 也可以乱序 —— 排在后面的那个不一定结束得最晚。
    if (t.end > latest) latest = t.end;
  }

  return (
    start: shiftFrom(anchor, earliest),
    end: shiftFrom(anchor, latest),
    // 偏移整体前移 `earliest`：最早那个阶段从此是 0，
    // 而任务开始就是它。没填时间的原样留着（仍然是 null）。
    stages: [
      for (final s in stages)
        (
          startOffsetMinutes: s.startOffsetMinutes == null
              ? null
              : s.startOffsetMinutes! - earliest,
          durationMinutes: s.durationMinutes,
        ),
    ],
  );
}

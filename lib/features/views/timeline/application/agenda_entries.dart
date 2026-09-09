/// 时间轴上的一行（FR-VIEW-01）。
///
/// ## 这个视图重做过一次
///
/// 第一版是「一天 24 小时的刻度尺 + 按时刻定位的块」。用户看过之后
/// 要的是另一样东西：
///
/// > 时间轴应该是按任务/阶段的开始时间卡片排列下来（无日期的不进视图）。
/// > 类似左侧是竖向时间轴右侧是任务/阶段卡片，**时间是跳跃的**。
///
/// 差别不是样式，是**排布的依据**：
///
/// | | 第一版 | 现在 |
/// |---|---|---|
/// | 纵轴 | 连续的一天，空白时段照样占高度 | 只在**有东西**的时刻打点 |
/// | 范围 | 单日 | 所有未完成的，按时间顺序一路往下 |
/// | 阶段 | 并进任务那一块里 | **各占一行**，按自己的开始时刻排 |
/// | 没有时刻的 | 顶部「随时」区 | 不进视图（无日期），全天的排在当天最前 |
///
/// 空白时段不占高度这一条是它与日历/甘特的分工所在：那两个视图回答
/// 「这段时间有多满」，时间轴回答「**接下来依次是什么**」。
/// 一天里只有两件事时，前者该画出大片空白，后者不该。
library;

import 'package:meta/meta.dart';

import '../../../../core/time/date_and_minute.dart';
import '../../../../core/time/minute_of_day.dart';
import '../../../../domain/entities/stage.dart';
import '../../../../domain/value_objects/task_status.dart';
import '../../shared/application/task_occurrence.dart';

/// 时间轴上的一行：一条任务，或者它的一个阶段。
@immutable
sealed class AgendaEntry {
  const AgendaEntry({required this.row, required this.at});

  /// 这一行属于哪一次发生。阶段行也带着它 —— 点进去要能回到那一次。
  final TaskOccurrence row;

  /// 排在什么时刻。**全天的按当天 00:00 排**，但显示成「全天」
  /// （见 [isAllDay]）—— 排序需要一个具体时刻，而界面不该把它说成 0 点。
  final DateAndMinute at;

  /// 这一行在库里的唯一标识。列表复用要用它。
  String get id;

  /// 给人看的标题。
  String get title;

  /// 这一行有没有具体时刻。
  bool get isAllDay;
}

/// 一条任务（的某一次发生）。
final class TaskEntry extends AgendaEntry {
  const TaskEntry({required super.row, required super.at});

  @override
  String get id => row.id;

  @override
  String get title => row.title;

  @override
  bool get isAllDay => row.isAllDay;
}

/// 一个阶段。**独占一行，按自己的开始时刻排。**
///
/// 阶段的时间存的是相对任务开始的偏移（data-model §4.1），
/// 所以这里的 [at] 是现算的绝对时刻。
final class StageEntry extends AgendaEntry {
  const StageEntry({
    required super.row,
    required super.at,
    required this.stage,
    required this.status,
  });

  final Stage stage;

  /// 这一次里这个阶段的状态（FR-TASK-07）——
  /// 走 `TaskOccurrence.stageStatus`，不看 `Stage.status`。
  final TaskStatus status;

  @override
  String get id => '${row.id}#${stage.id}';

  @override
  String get title => stage.title;

  /// 阶段一定有时刻 —— 没排时间的阶段压根不进时间轴（见 [agendaEntries]）。
  @override
  bool get isAllDay => false;
}

/// 把展开好的行拍平成时间轴上的**一列**。
///
/// 纯函数：给一批行，出来的顺序是确定的，不需要搭一棵树就能验。
///
/// ## 它做什么，不做什么
///
/// **做**：任务出一行；它每个**排了时间**的阶段各出一行；按时刻排序。
///
/// **不做**筛选 —— 「哪些次该出现」在 `expandForAgenda` 里（逾期一条、
/// 今天起两条、做完的不出）。两处都写一遍的话，改了一处就是两个视图
/// 各说各话；而这里只挡一件事：**没有日期的行渲染不出来**，
/// 因为它连排在哪都算不出。那是前置条件，不是策略。
///
/// ## 阶段为什么要单独成行
///
/// 用户看过第一版之后说的第一条就是「阶段是独立的卡片」。并进任务那张卡
/// 的话，一条「上午写方案、下午评审」的任务在时间轴上只有一个落点，
/// 而下午那个落点才是你四点钟要看的东西。
///
/// 只有**排了时间**的阶段进来：没排时间的阶段没有开始时刻，
/// 硬给一个就是编造（甘特那边不把它们切成段，是同一条理由）。
List<AgendaEntry> agendaEntries(List<TaskOccurrence> rows) {
  final entries = <AgendaEntry>[];

  for (final row in rows) {
    final date = row.planDate;
    if (date == null) continue;

    final start = DateAndMinute(date, row.startMinute ?? MinuteOfDay.midnight);
    entries.add(TaskEntry(row: row, at: start));

    for (final stage in row.stages) {
      final offset = stage.startOffsetMinutes;
      if (offset == null) continue;
      entries.add(
        StageEntry(
          row: row,
          at: shiftFrom(start, offset),
          stage: stage,
          status: row.stageStatus(stage),
        ),
      );
    }
  }

  entries.sort((a, b) {
    final byTime = a.at.compareTo(b.at);
    if (byTime != 0) return byTime;
    // 同一时刻时任务排在它自己的阶段前面 —— 阶段是任务的细分，
    // 反过来的话「第一步」会出现在它所属的那条任务上面。
    final aTask = a is TaskEntry ? 0 : 1;
    final bTask = b is TaskEntry ? 0 : 1;
    if (aTask != bTask) return aTask - bTask;
    // 最后按 id，只为**排序稳定**：同一批数据每次刷新的顺序必须一致，
    // 否则列表会在两个等价顺序之间跳。
    return a.id.compareTo(b.id);
  });

  return entries;
}

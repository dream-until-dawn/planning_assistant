/// 把任务展开成「一行一次发生」（view-specs §0.2、FR-TASK-05）。
///
/// **纯函数**，不碰 provider —— 展开的规则要能单独测：给一批任务和一批
/// 例外，出来的行是确定的。混进 provider 之后，验它就得先搭一整棵树。
library;

import '../../../../core/time/local_wall_time.dart';
import '../../../../core/time/minute_of_day.dart';
import '../../../../core/time/plan_date.dart';
import '../../../../domain/entities/occurrence.dart';
import '../../../../domain/entities/occurrence_override.dart';
import '../../../../domain/entities/stage.dart';
import '../../../../domain/entities/task.dart';
import '../../../../domain/recurrence/recurrence_engine.dart';
import 'task_occurrence.dart';

/// 列表的展开窗口，相对「今天」。
///
/// ## 为什么必须有窗口
///
/// 「每天」这类规则是**无限**的 —— 没有窗口就展不完。
///
/// ## 为什么这几个数
///
/// [pastDays]：逾期组要看得见漏掉的那几次。取得太长的话，一条搁置了
/// 三个月的每日任务会在逾期组里堆出九十行 —— 那不是提醒，是噪声。
/// 两周够覆盖「上周忘了做」这类真实情形。
///
/// [futureDays]：未来方向只展开**一条**（见 [expandForList]），
/// 所以这个数不再决定行数，只决定「往前找多远算便宜的一次」。
///
/// [lookaheadDays]：稀疏规则的兜底。「每年 5 月 20 日」在九月时，
/// 下一次在八个月之后 —— 只看 [futureDays] 的话它**一行都没有**，
/// 整条任务从列表里消失。所以找不到时再往前看这么远。
/// 比它还稀疏的规则（每三年）不会显示「下一次」，只显示逾期的那些。
abstract final class ListHorizon {
  static const int pastDays = 14;
  static const int futureDays = 60;
  static const int lookaheadDays = 366 * 2;

  static DateRange around(PlanDate today) =>
      DateRange(today.addDays(-pastDays), today.addDays(futureDays));

  /// 兜底窗口：常规窗口的右端到 [lookaheadDays]。
  static DateRange lookahead(PlanDate today) =>
      DateRange(today.addDays(futureDays + 1), today.addDays(lookaheadDays));
}

/// 把任务与例外展开成列表的行。
///
/// ## 重复任务只展开「逾期的 + 下一次」
///
/// 全展开的话，一条「每天」在列表里就是六十行，逾期组还会堆 ——
/// 那不是一份计划，是一份日历的转录。规则：
///
/// | 那一次 | 显示吗 |
/// |---|---|
/// | 没做完，且日期在今天之前 | **留着**（逾期组）—— 漏交一次房租不该无声消失 |
/// | 没做完，日期今天或以后 | **只留最早的一条**，就是「下一次」 |
/// | 已完成，日期今天或以后 | 留着 —— 刚勾掉的那张卡不能立刻消失（§8.1），要给撤销留时间 |
/// | 已完成，且已经是过去 | 不留（除非 [includeCompleted]） |
/// | 已跳过 | 不留（除非 [includeSkipped]） |
///
/// 于是勾掉今天那次之后，明天那次**当场出现** —— 而今天那张划掉的
/// 卡片还在原位，可以撤销。
///
/// [overrides] 是**全部任务**的例外，按 taskId 索引在这里做 ——
/// 调用方逐条查库就是 N+1（`watchAllOverrides` 的注释里有同一条理由）。
///
/// [includeSkipped] / [includeCompleted]：用户显式筛「已跳过」「已完成」
/// 时打开，把被折叠掉的那些放回来。**这是它们唯一的入口** ——
/// 没有的话，跳过或做完的那些次就再也找不回来了。
List<TaskOccurrence> expandForList({
  required List<Task> tasks,
  required List<OccurrenceOverride> overrides,
  required PlanDate today,
  required RecurrenceEngine engine,
  bool includeSkipped = false,
  bool includeCompleted = false,

  /// 每条任务的阶段，用来算**有效跨度**（data-model §4.7）——
  /// 末阶段可能排到 `endDate` 之后，那时跨度以阶段为准。
  /// 不传就是「没有阶段」，跨度退回存储的那一段。
  Map<String, List<Stage>> stagesByTask = const {},
}) {
  final byTask = _indexOverrides(overrides);
  final out = <TaskOccurrence>[];

  for (final task in tasks) {
    final date = task.planDate;

    // 没有日期 → 一行，就是任务本身。「无日期」是合法且常见的状态
    // （FR-TASK-01：仅填标题即可保存），不能从列表里消失。
    if (date == null) {
      out.add(
        TaskOccurrence(task: task, stages: stagesByTask[task.id] ?? const []),
      );
      continue;
    }

    // 不重复 → 一行。**不看窗口**：它只有一次，不存在展不完的问题，
    // 而「明年的事」从列表里消失会让人以为它丢了。
    if (!task.isRecurring) {
      out.add(
        TaskOccurrence(task: task, stages: stagesByTask[task.id] ?? const []),
      );
      continue;
    }

    final context = _contextOf(task, date);
    final taskOverrides = byTask[task.id] ?? const <OccurrenceOverride>[];

    final occurrences = engine.expand(
      context: context,
      window: ListHorizon.around(today),
      overrides: taskOverrides,
      includeSkipped: includeSkipped,
    );

    var hasNext = false;
    for (final o in occurrences) {
      final isPast = o.start.date.isBefore(today);
      switch (o.status) {
        case OccurrenceStatus.skipped:
          // 走到这里说明 includeSkipped 开着（否则引擎就不产出了）。
          out.add(
            TaskOccurrence(
              task: task,
              occurrence: o,
              stages: stagesByTask[task.id] ?? const [],
            ),
          );
        case OccurrenceStatus.done:
          if (includeCompleted || !isPast) {
            out.add(
              TaskOccurrence(
                task: task,
                occurrence: o,
                stages: stagesByTask[task.id] ?? const [],
              ),
            );
          }
        case OccurrenceStatus.pending:
        case OccurrenceStatus.inProgress:
          if (isPast) {
            out.add(
              TaskOccurrence(
                task: task,
                occurrence: o,
                stages: stagesByTask[task.id] ?? const [],
              ),
            );
          } else if (!hasNext) {
            hasNext = true;
            out.add(
              TaskOccurrence(
                task: task,
                occurrence: o,
                stages: stagesByTask[task.id] ?? const [],
              ),
            );
          }
      }
    }

    // 常规窗口里一条未来的都没有 → 往更远处找一条「下一次」。
    // 不找的话，「每年 5 月 20 日」这种稀疏规则会整条从列表里消失。
    if (!hasNext) {
      final far = engine.expand(
        context: context,
        window: ListHorizon.lookahead(today),
        overrides: taskOverrides,
      );
      for (final o in far) {
        if (o.status == OccurrenceStatus.done ||
            o.status == OccurrenceStatus.skipped) {
          continue;
        }
        out.add(
          TaskOccurrence(
            task: task,
            occurrence: o,
            stages: stagesByTask[task.id] ?? const [],
          ),
        );
        break;
      }
    }
  }

  return out;
}

/// **窗口内的全部发生**，一次不落，不做任何折叠。
///
/// 时间轴与日历用这个：它们问的是「这段时间里都发生什么」，
/// 答案由日期决定，不掺任何取舍。
///
/// 列表用的是 [expandForList] —— 那里面是一套 **UX 策略**
/// （逾期全留、未来只留下一次，§0.2.2）。两者刻意分开：
/// 合成一个带开关的函数的话，「日历为什么少了几天」会变成一道
/// 要读策略分支才答得上的题。
///
/// **没有日期的任务不进来** —— 它不落在任何一天上。
/// 列表另有「无日期」分组管它（§2.1）。
///
/// ## 按覆盖区间收，不按开始日期
///
/// 「9/1 到 9/30 的项目」在 9/15 那天的时间轴上必须在。按开始日期筛的话
/// 它只在 9/1 出现一次，中间那二十九天空空如也 —— 而那看起来像
/// 「这个任务不见了」，不像「窗口没框住它」。
List<TaskOccurrence> expandInWindow({
  required List<Task> tasks,
  required List<OccurrenceOverride> overrides,
  required DateRange window,
  required RecurrenceEngine engine,
  bool includeSkipped = false,

  /// 每条任务的阶段，用来算**有效跨度**（data-model §4.7）——
  /// 末阶段可能排到 `endDate` 之后，那时跨度以阶段为准。
  /// 不传就是「没有阶段」，跨度退回存储的那一段。
  Map<String, List<Stage>> stagesByTask = const {},
}) {
  final byTask = _indexOverrides(overrides);
  final out = <TaskOccurrence>[];

  for (final task in tasks) {
    final date = task.planDate;
    if (date == null) continue;

    if (!task.isRecurring) {
      // 不重复：只有一次，区间碰到窗口就算。
      if (_intersects(date, task.endDate ?? date, window)) {
        out.add(
          TaskOccurrence(task: task, stages: stagesByTask[task.id] ?? const []),
        );
      }
      continue;
    }

    // 重复的跨天任务：某一次的**开始**可能在窗口之前，而引擎是按开始
    // 日期筛的（`window.contains(occ.start.date)`）。所以往前多展开
    // 「它自己那么长」，再按覆盖区间收。
    //
    // 多展开的天数由**任务自己的时长**决定，不是一个拍脑袋的常量 ——
    // 一小时的晨会多展开一天，三天的排班多展开三天，各不相欠。
    final back = _spanDays(task, date);
    for (final o in engine.expand(
      context: _contextOf(task, date),
      window: back == 0
          ? window
          : DateRange(window.start.addDays(-back), window.end),
      overrides: byTask[task.id] ?? const [],
      includeSkipped: includeSkipped,
    )) {
      final row = TaskOccurrence(
        task: task,
        occurrence: o,
        stages: stagesByTask[task.id] ?? const [],
      );
      final start = row.planDate;
      if (start == null) continue;
      if (_intersects(start, row.effectiveEndDate ?? start, window)) {
        out.add(row);
      }
    }
  }

  return out;
}

/// 闭区间 `[start, end]` 与 [window] 有没有交集。
bool _intersects(PlanDate start, PlanDate end, DateRange window) =>
    !start.isAfter(window.end) && !end.isBefore(window.start);

/// 这条规则的每一次横跨几天（向上取整）。
///
/// [_maxSpanDays] 是**刻意的上界**，同 `ListHorizon.lookaheadDays` 的性质：
/// 跨度超过它的重复任务，中间那些天不会出现在窗口里。
/// 一条「每周一次、每次持续三个月」的规则在现实里是排班表画错了，
/// 而为它把每条规则的展开范围放大三个月，代价落在所有人身上。
int _spanDays(Task task, PlanDate start) {
  final minutes = _durationOf(task, start);
  if (minutes == null || minutes <= 0) return 0;
  final days = (minutes + _minutesPerDay - 1) ~/ _minutesPerDay;
  return days > _maxSpanDays ? _maxSpanDays : days;
}

/// 一天有多少分钟。
const int _minutesPerDay = 1440;

/// 重复任务往前多展开的天数上限，见 [_spanDays]。
const int _maxSpanDays = 62;

Map<String, List<OccurrenceOverride>> _indexOverrides(
  List<OccurrenceOverride> overrides,
) {
  final byTask = <String, List<OccurrenceOverride>>{};
  for (final o in overrides) {
    (byTask[o.taskId] ??= []).add(o);
  }
  return byTask;
}

RecurrenceContext _contextOf(Task task, PlanDate date) => RecurrenceContext(
  taskId: task.id,
  dtStart: LocalWallTime(
    date: date,
    minuteOfDay: task.startMinute ?? MinuteOfDay.midnight,
    timeZoneId: task.timeZoneId,
  ),
  isAllDay: task.isAllDay,
  recurrence: task.recurrence,
  durationMinutes: _durationOf(task, date),
);

/// 一条规则的每一次持续多久（墙钟分钟，recurrence-engine §5）。
///
/// ## 这里一度是空的
///
/// `RecurrenceContext.durationMinutes` 声明了、引擎也读它，但**没有
/// 任何地方写它** —— 于是每一次发生的 `end` 恒为 null。
/// 列表只显示开始时刻，所以整个 M2 都看不出来；时间轴是第一个
/// 要用结束时刻的视图，一接上就是「每条重复任务都是零长块」。
///
/// 又是一次「模型有字段、写入侧没有生产者」（testing-strategy §1.6）。
/// 引擎里那段两端各自解析 DST 的代码（§4.1.1）也因此从未在
/// 规则推导出的 end 上跑过。
int? _durationOf(Task task, PlanDate start) {
  final endDate = task.endDate;
  if (endDate == null) return null;

  final days = endDate.differenceInDays(task.planDate ?? start);
  if (task.isAllDay) return days * _minutesPerDay;

  final startMinute = task.startMinute?.value ?? 0;
  // 有结束日期却没有结束时刻 = **到那天结束**。与 `Task` 自己
  // 判先后时的读法一致（`_endsBeforeItStarts` 把空的结束时刻当 1439），
  // 也与时间轴的 `_endOffset` 一致 —— 同一份数据在三处必须是同一个意思。
  final endMinute = task.endMinute?.value ?? (_minutesPerDay - 1);
  return days * _minutesPerDay + (endMinute - startMinute);
}

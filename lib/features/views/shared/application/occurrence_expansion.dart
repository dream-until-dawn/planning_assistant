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
}) {
  final byTask = <String, List<OccurrenceOverride>>{};
  for (final o in overrides) {
    (byTask[o.taskId] ??= []).add(o);
  }

  final out = <TaskOccurrence>[];

  for (final task in tasks) {
    final date = task.planDate;

    // 没有日期 → 一行，就是任务本身。「无日期」是合法且常见的状态
    // （FR-TASK-01：仅填标题即可保存），不能从列表里消失。
    if (date == null) {
      out.add(TaskOccurrence(task: task));
      continue;
    }

    // 不重复 → 一行。**不看窗口**：它只有一次，不存在展不完的问题，
    // 而「明年的事」从列表里消失会让人以为它丢了。
    if (!task.isRecurring) {
      out.add(TaskOccurrence(task: task));
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
          out.add(TaskOccurrence(task: task, occurrence: o));
        case OccurrenceStatus.done:
          if (includeCompleted || !isPast) {
            out.add(TaskOccurrence(task: task, occurrence: o));
          }
        case OccurrenceStatus.pending:
        case OccurrenceStatus.inProgress:
          if (isPast) {
            out.add(TaskOccurrence(task: task, occurrence: o));
          } else if (!hasNext) {
            hasNext = true;
            out.add(TaskOccurrence(task: task, occurrence: o));
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
        out.add(TaskOccurrence(task: task, occurrence: o));
        break;
      }
    }
  }

  return out;
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
);

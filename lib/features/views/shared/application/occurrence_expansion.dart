/// 把任务展开成「一行一次发生」（view-specs §0.2、FR-TASK-05）。
///
/// **纯函数**，不碰 provider —— 展开的规则要能单独测：给一批任务和一批
/// 例外，出来的行是确定的。混进 provider 之后，验它就得先搭一整棵树。
library;

import '../../../../core/time/local_wall_time.dart';
import '../../../../core/time/minute_of_day.dart';
import '../../../../core/time/plan_date.dart';
import '../../../../domain/entities/occurrence_override.dart';
import '../../../../domain/entities/task.dart';
import '../../../../domain/recurrence/recurrence_engine.dart';
import 'task_occurrence.dart';

/// 列表的展开窗口，相对「今天」。
///
/// ## 为什么必须有窗口
///
/// 「每天」这类规则是**无限**的 —— 没有窗口就展不完。
/// 而列表的分组里有「更远」这一档（§2.1），字面上没有尽头。
/// 两者不可兼得，只能选一个有限的地平线。
///
/// ## 为什么是这两个数
///
/// 往前 [pastDays]：逾期组要看得见漏掉的那几次。取得太长的话，
/// 一条搁置了三个月的每日任务会在逾期组里堆出九十行 ——
/// 那不是提醒，是噪声。两周够覆盖「上周忘了做」这类真实情形。
///
/// 往后 [futureDays]：日历与时间轴各有自己的窗口，列表只负责
/// 「近期要做什么」。两个月能装下「下个月那次月度复盘」。
///
/// **窗口只作用于重复任务。** 不重复的任务无论多远都照常显示 ——
/// 它只有一次，不存在展不完的问题，而「明年的事」从列表里消失
/// 会让人以为它丢了。
abstract final class ListHorizon {
  static const int pastDays = 14;
  static const int futureDays = 60;

  static DateRange around(PlanDate today) =>
      DateRange(today.addDays(-pastDays), today.addDays(futureDays));
}

/// 把任务与例外展开成列表的行。
///
/// [overrides] 是**全部任务**的例外，按 taskId 索引在这里做 ——
/// 调用方逐条查库就是 N+1（`watchAllOverrides` 的注释里有同一条理由）。
List<TaskOccurrence> expandForList({
  required List<Task> tasks,
  required List<OccurrenceOverride> overrides,
  required PlanDate today,
  required RecurrenceEngine engine,
}) {
  final byTask = <String, List<OccurrenceOverride>>{};
  for (final o in overrides) {
    (byTask[o.taskId] ??= []).add(o);
  }

  final window = ListHorizon.around(today);
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

    final occurrences = engine.expand(
      context: RecurrenceContext(
        taskId: task.id,
        dtStart: LocalWallTime(
          date: date,
          minuteOfDay: task.startMinute ?? MinuteOfDay.midnight,
          timeZoneId: task.timeZoneId,
        ),
        isAllDay: task.isAllDay,
        recurrence: task.recurrence,
      ),
      window: window,
      overrides: byTask[task.id] ?? const [],
    );

    for (final o in occurrences) {
      out.add(TaskOccurrence(task: task, occurrence: o));
    }
  }

  return out;
}

/// 把视图那套「行」配成排期要的 `(某一次, 一条提醒, 标题)`。
///
/// ## 为什么这一步在 feature 层
///
/// `planNotifications` 收的是领域的 `Occurrence`，而展开出来的是
/// `TaskOccurrence`（视图行：`(任务, 可选的某一次)`）。让纯函数去认识
/// 视图类型是把依赖倒过来了；让展开去产出领域类型又会丢掉
/// 「无日期任务」「有效跨度」那些视图才需要的东西。
///
/// 所以中间这一步单独放在这儿 —— 它两边都认识，而两边都不认识对方。
///
/// ## 不重复的行要**现造一个 `Occurrence`**
///
/// `TaskOccurrence.occurrence` 只有重复任务的行才有；不重复的那一行
/// 它是 null（那一行就是任务本身）。但排期两边都要 ——
/// 通知的稳定标识里带着 `occurrenceKey`。
///
/// 造出来的那一个与 `convertRecurrenceMode` 迁移到「第一次」时用的是
/// **同一个身份**：任务自己的开始时刻那一次。不重复的任务只有一次发生，
/// 这不是「挑一个」，是放回它本来的位置。
library;

import '../../../core/time/local_wall_time.dart';
import '../../../core/time/minute_of_day.dart';
import '../../../domain/entities/occurrence.dart';
import '../../../domain/entities/reminder.dart';
import '../../../domain/services/notification_planner.dart';
import '../../../domain/value_objects/occurrence_key.dart';
import '../../../domain/value_objects/task_status.dart';
import '../../views/shared/application/task_occurrence.dart';

/// 把展开出来的行与提醒配起来。
///
/// [remindersByTask] 里没有这条任务时，它一条通知都不产出 ——
/// 没设提醒的任务本来就不该响。
List<ReminderOnOccurrence> reminderPairsOf({
  required List<TaskOccurrence> rows,
  required Map<String, List<Reminder>> remindersByTask,
}) {
  final pairs = <ReminderOnOccurrence>[];

  for (final row in rows) {
    final reminders = remindersByTask[row.task.id];
    if (reminders == null || reminders.isEmpty) continue;

    final occurrence = _occurrenceOf(row);
    // 没有日期就没有「哪一次」可指 —— 相对提醒无从算起。
    // 「随时做」那一档（FR-VIEW-01）落在这里，它本来就不该有到点提醒。
    if (occurrence == null) continue;

    for (final reminder in reminders) {
      pairs.add((occurrence: occurrence, reminder: reminder, title: row.title));
    }
  }

  return pairs;
}

/// 这一行对应的领域 `Occurrence`；没有日期时 null。
Occurrence? _occurrenceOf(TaskOccurrence row) {
  final existing = row.occurrence;
  if (existing != null) return existing;

  final date = row.planDate;
  if (date == null) return null;

  final isAllDay = row.task.isAllDay;
  final start = LocalWallTime(
    date: date,
    // **全天的开始按午夜算**，与 `Task.wallStart` 里那句
    // `startMinute ?? MinuteOfDay.midnight` 是同一条 —— 两处不一致的话，
    // 算出来的 `OccurrenceKey` 会挂在一个不存在的时刻上。
    minuteOfDay: isAllDay
        ? MinuteOfDay.midnight
        : (row.startMinute ?? MinuteOfDay.midnight),
    timeZoneId: row.task.timeZoneId,
  );

  final endDate = row.endDate;
  final endMinute = row.endMinute;

  return Occurrence(
    taskId: row.task.id,
    key: OccurrenceKey.fromWallTime(start, isAllDay: isAllDay),
    start: start,
    end: endDate == null
        ? null
        : LocalWallTime(
            date: endDate,
            minuteOfDay: endMinute ?? MinuteOfDay.midnight,
            timeZoneId: row.task.timeZoneId,
          ),
    isAllDay: isAllDay,
    // **状态走行的**：不重复任务的状态在 `tasks.status` 上，
    // 而 `row.status` 已经把「看任务还是看这一次」那条岔口处理掉了。
    status: _asOccurrenceStatus(row.status),
  );
}

OccurrenceStatus _asOccurrenceStatus(TaskStatus status) =>
    // 两个枚举取值一一对应，`wireName` 就是那份对应表 ——
    // 手写 switch 的话，谁给其中一边加一个值，另一边会静悄悄落到 default。
    OccurrenceStatus.fromWireName(status.wireName);

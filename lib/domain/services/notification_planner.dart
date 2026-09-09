/// 「窗口内该排哪些通知」——**纯函数**（notifications.md §2、FR-NOTI-01/02）。
///
/// 几乎全部业务逻辑都在这里：相对/绝对触发、全天任务的基准时刻、免打扰顺延、
/// 合并、去重、按上限截断。真正碰系统 API 的那层薄到只剩「照计划调
/// schedule / cancel」。这样分是为了让 N-01..N-13 全部能在纯 Dart 层测完
/// （notifications.md §10），不需要设备 —— 而设备上那三项已经降级（§11），
/// 更没有理由把判断逻辑留在够不着的地方。
///
/// 不碰系统时钟、不碰库：`nowUtc` 与时区解析器都由调用方传入。
library;

import 'package:meta/meta.dart';

import '../../core/time/date_and_minute.dart';
import '../../core/time/local_wall_time.dart';
import '../../core/time/minute_of_day.dart';
import '../../core/time/time_zone_resolver.dart';
import '../entities/occurrence.dart';
import '../entities/reminder.dart';
import '../value_objects/occurrence_key.dart';
import '../value_objects/quiet_hours_behavior.dart';

/// 排期要用到的配置（settings-spec §2.3 里那几条的**取值**，不是规格本身）。
///
/// 用记录而不是让纯函数去读配置仓库：读配置是副作用，而这一层要能被
/// 十三条用例直接构造出来喂进去。
typedef ReminderSettings = ({
  bool enabled,
  int defaultOffsetMinutes,
  MinuteOfDay allDayMinute,
  bool quietHoursEnabled,
  MinuteOfDay quietStart,
  MinuteOfDay quietEnd,
  QuietHoursBehavior quietBehavior,
  int mergeThreshold,
  int maxScheduled,
});

/// 排期窗口：`[from, to)`，两端都是绝对时刻。
typedef ScheduleWindow = ({DateTime fromUtc, DateTime toUtc});

/// 排好期的一条通知。
@immutable
final class PlannedNotification {
  const PlannedNotification({
    required this.key,
    required this.trigger,
    required this.triggerUtc,
    required this.taskIds,
    required this.title,
    this.body,
  });

  /// **稳定标识**，对账（N-10/N-11）与去重都靠它。
  ///
  /// 由 `taskId#reminderId#occurrenceKey` 派生，所以同一条提醒在两次排期里
  /// 算出来的 key 一样 —— 否则每次续排都会「全删全建」，
  /// 而那既浪费系统配额，又会让已经排好的闹钟白白重置一次。
  final String key;

  /// 给 `zonedSchedule` 用的墙钟 + 时区。
  ///
  /// **存墙钟而不是只存绝对时刻**：时区变了要按墙钟重算（§6），
  /// 只留绝对时刻的话「早上 9 点」会跟着飞到别的钟点上。
  final LocalWallTime trigger;

  /// [trigger] 解析出来的绝对时刻。排序、截断、与 `now` 比较都用它。
  final DateTime triggerUtc;

  /// 这条通知涉及的任务。合并摘要时不止一个（N-13）。
  final List<String> taskIds;

  final String title;
  final String? body;

  bool get isDigest => taskIds.length > 1;

  @override
  String toString() =>
      'PlannedNotification($key @ $triggerUtc'
      '${isDigest ? ', 合并 ${taskIds.length} 条' : ''})';
}

/// 一条提醒挂在哪一次发生上。调用方按任务把三样配好再传进来。
///
/// **标题单独传**：`Occurrence` 只带 `titleOverride`（某一次改过的标题），
/// 任务本身的标题不在它身上。让这个函数去认识 `Task` 是把领域实体的
/// 依赖倒过来了 —— 它只需要「这条通知上写什么」这一个串。
typedef ReminderOnOccurrence = ({
  Occurrence occurrence,
  Reminder reminder,
  String title,
});

/// 算出窗口内应该排的全部通知，**按触发时刻升序**。
///
/// [pairs] 是「(某一次发生, 挂在它上面的一条提醒)」的全部组合 ——
/// 由调用方按 taskId 配好。这里不做那一步是刻意的：配对要读任务与提醒两张表，
/// 而这个函数不该知道有表这回事。
List<PlannedNotification> planNotifications({
  required List<ReminderOnOccurrence> pairs,
  required ReminderSettings settings,
  required DateTime nowUtc,
  required ScheduleWindow window,
  required TimeZoneResolver zones,
}) {
  // 总开关关掉就是**一条都不排**，不是排了不响（见 `reminderEnabled` 的注释）。
  if (!settings.enabled) return const [];

  final planned = <PlannedNotification>[];

  for (final (:occurrence, :reminder, :title) in pairs) {
    if (!reminder.isEnabled || reminder.deletedAt != null) continue;

    // 已完成/已跳过的那一次不再提醒（N-07、N-08）。
    // **判据是这一次的状态，不是任务的** —— 重复任务的 `tasks.status`
    // 恒为 pending，看它的话每一次都会被当成待办。
    if (occurrence.status == OccurrenceStatus.done ||
        occurrence.status == OccurrenceStatus.skipped) {
      continue;
    }

    final base = _baseFor(occurrence, reminder, settings);
    if (base == null) continue;

    final shifted = reminder.isRelative
        ? shiftFrom(base, reminder.offsetMinutes ?? 0)
        : base;

    final adjusted = _applyQuietHours(shifted, settings);
    if (adjusted == null) continue; // suppress

    final wall = LocalWallTime(
      date: adjusted.date,
      minuteOfDay: adjusted.minute,
      timeZoneId: occurrence.start.timeZoneId,
    );
    final instant = zones.toInstant(wall);

    // 过去的排不了 —— 系统会当场把它弹出来。窗口右开，见 [ScheduleWindow]。
    if (!instant.isAfter(nowUtc)) continue;
    if (instant.isBefore(window.fromUtc)) continue;
    if (!instant.isBefore(window.toUtc)) continue;

    planned.add(
      PlannedNotification(
        key: notificationKeyOf(
          taskId: occurrence.taskId,
          reminderId: reminder.id,
          occurrenceKey: occurrence.key,
        ),
        trigger: wall,
        triggerUtc: instant,
        taskIds: [occurrence.taskId],
        // 这一次改过标题就用那一个（FR-TASK-05）。
        title: occurrence.titleOverride ?? title,
        body: null,
      ),
    );
  }

  final merged = _mergeSameInstant(planned, settings.mergeThreshold);

  // **按时刻升序截断，丢最远的**（N-03）：近的更可能真的被用到，
  // 远的会在下次续排时补上（notifications.md §3）。
  merged.sort((a, b) => a.triggerUtc.compareTo(b.triggerUtc));
  if (merged.length > settings.maxScheduled) {
    return merged.sublist(0, settings.maxScheduled);
  }
  return merged;
}

/// 一条通知的稳定标识。**只此一处**拼这个串 —— 排期侧与对账侧各拼一遍的话，
/// 两边算出来的 key 迟早差一个分隔符，而表现是「每次续排都全删全建」。
String notificationKeyOf({
  required String taskId,
  required String reminderId,
  required OccurrenceKey occurrenceKey,
}) => '$taskId#$reminderId#${occurrenceKey.value}';

/// 这条提醒从哪一刻起算。
DateAndMinute? _baseFor(
  Occurrence occurrence,
  Reminder reminder,
  ReminderSettings settings,
) {
  switch (reminder.kind) {
    case ReminderKind.absolute:
      final d = reminder.absoluteDate;
      final m = reminder.absoluteMinute;
      if (d == null || m == null) return null;
      return DateAndMinute(d, m);

    case ReminderKind.relativeToStart:
      return _startBase(occurrence, settings);

    case ReminderKind.relativeToEnd:
      // 没有结束就退回开始：一条「截止前一小时」挂在没有结束时刻的任务上，
      // 不提醒比在一个猜出来的时刻提醒好不了多少 —— 但退回开始至少是
      // 用户填过的那个时刻，而猜一个「开始 + 默认时长」是替他编数据。
      final end = occurrence.end;
      if (end == null || occurrence.isAllDay) {
        return _startBase(occurrence, settings);
      }
      return DateAndMinute(end.date, end.minuteOfDay);
  }
}

/// 相对提醒的开始基准。
///
/// **全天任务用配置里的那个绝对时刻**（`reminder.allDayReminderMinute`）：
/// 全天没有开始时刻，「提前 15 分钟」从哪一刻算起问不出来。
/// 偏移仍然照加 —— 于是「全天 + 提前 15 分」= 当天 08:45，
/// 这比无视用户设的偏移更接近他的意思。
DateAndMinute _startBase(Occurrence occurrence, ReminderSettings settings) {
  final start = occurrence.start;
  if (occurrence.isAllDay) {
    return DateAndMinute(start.date, settings.allDayMinute);
  }
  return DateAndMinute(start.date, start.minuteOfDay);
}

/// 免打扰。返回 null 表示这一条被丢弃（`suppress`）。
///
/// 时段是**左闭右开** `[start, end)`：结束那一刻本身不算免打扰
/// （N-06 钉住这条边界）。闭区间的话「顺延到 07:00」会顺延到一个
/// 仍然在时段内的时刻，然后要么再顺延一次、要么就地违反自己的规则。
DateAndMinute? _applyQuietHours(DateAndMinute at, ReminderSettings s) {
  if (!s.quietHoursEnabled) return at;
  if (!_inQuietHours(at.minute, s.quietStart, s.quietEnd)) return at;

  if (s.quietBehavior == QuietHoursBehavior.suppress) return null;

  // 顺延到时段结束。**跨零点时要分清自己在前半段还是后半段**：
  // 22:00–07:00 里，23:30 的结束在**第二天** 07:00，而 06:59 的结束
  // 就是**当天** 07:00。不分的话，凌晨那批会被推迟整整一天。
  final crossesMidnight = s.quietStart.value > s.quietEnd.value;
  final inEveningHalf =
      crossesMidnight && at.minute.value >= s.quietStart.value;
  final date = inEveningHalf ? at.date.addDays(1) : at.date;
  return DateAndMinute(date, s.quietEnd);
}

/// [m] 是否落在 `[start, end)` 内。跨零点的时段（22:00–07:00）是正常情况。
bool _inQuietHours(MinuteOfDay m, MinuteOfDay start, MinuteOfDay end) {
  if (start.value == end.value) return false; // 零长时段 = 没设
  if (start.value < end.value) {
    return m.value >= start.value && m.value < end.value;
  }
  return m.value >= start.value || m.value < end.value;
}

/// 同一刻的多条合并成一条摘要（N-13）。
///
/// **阈值是「超过」不是「达到」**：`mergeThreshold` 默认 3 时，
/// 正好 3 条仍然各发各的 —— 三条通知还看得清是哪三件事，
/// 合成「有 3 项安排」反而丢了信息。
List<PlannedNotification> _mergeSameInstant(
  List<PlannedNotification> planned,
  int threshold,
) {
  final byInstant = <int, List<PlannedNotification>>{};
  for (final p in planned) {
    (byInstant[p.triggerUtc.millisecondsSinceEpoch] ??= []).add(p);
  }

  final out = <PlannedNotification>[];
  for (final group in byInstant.values) {
    if (group.length <= threshold) {
      out.addAll(group);
      continue;
    }
    final first = group.first;
    out.add(
      PlannedNotification(
        // 摘要的 key 由**时刻**派生，不由某一条提醒派生 ——
        // 挂在 group.first 上的话，那条任务一改，整条摘要的身份就变了，
        // 而它代表的是「这一刻的全部安排」。
        key: 'digest#${first.triggerUtc.millisecondsSinceEpoch}',
        trigger: first.trigger,
        triggerUtc: first.triggerUtc,
        taskIds: [for (final p in group) ...p.taskIds],
        title: '${group.length} 项安排',
        body: null,
      ),
    );
  }
  return out;
}

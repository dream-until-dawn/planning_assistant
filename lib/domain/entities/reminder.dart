/// 提醒实体（data-model §3.8、FR-NOTI-01）。
///
/// ## 三种，因为「提前多久」对某些任务问不出来
///
/// | kind | 触发时刻 | 什么时候只能用它 |
/// |---|---|---|
/// | `relativeToStart` | 这一次的开始 + [offsetMinutes] | 常规 |
/// | `relativeToEnd` | 这一次的结束 + [offsetMinutes] | 「截止前一小时」 |
/// | `absolute` | [absoluteDate] + [absoluteMinute] | 与任务时间无关的一次性提醒 |
///
/// **全天任务不在这张表里选**：它没有开始时刻，「提前 15 分钟」从哪一刻算起
/// 问不出来。那种情况用配置项 `reminder.allDayReminderMinute` 给的绝对时刻
/// （notifications.md §7），而不是在这里多加一个 kind ——
/// 多加一个 kind 的话，用户能给一条定时任务选上「全天提醒时刻」，
/// 而那对它没有意义。
///
/// ## 偏移是**负数表示提前**
///
/// 与 `Stage.startOffsetMinutes` 的正负约定一致（都是「相对基准点的偏移」）。
/// 写成正数表示提前的话，两处相邻的字段含义相反，迟早有人算错符号。
library;

import 'package:meta/meta.dart';

import '../../core/patch/unset.dart';
import '../../core/time/minute_of_day.dart';
import '../../core/time/plan_date.dart';

/// 提醒相对什么算。
enum ReminderKind {
  relativeToStart('relativeToStart'),
  relativeToEnd('relativeToEnd'),
  absolute('absolute');

  const ReminderKind(this.wireName);

  /// 落库与导出用的串。
  final String wireName;

  /// 未知值抛异常，不回落 —— 同 `TaskStatus.fromWireName` 的理由：
  /// 悄悄当成某一种，用户看到的是提醒在莫名其妙的时刻响。
  static ReminderKind fromWireName(String value) {
    for (final k in ReminderKind.values) {
      if (k.wireName == value) return k;
    }
    throw FormatException('未知的提醒类型', value);
  }
}

@immutable
final class Reminder {
  const Reminder({
    required this.id,
    required this.taskId,
    required this.kind,
    this.offsetMinutes,
    this.absoluteDate,
    this.absoluteMinute,
    this.isEnabled = true,
    this.deletedAt,
  });

  final String id;
  final String taskId;
  final ReminderKind kind;

  /// 相对基准点的分钟偏移，**负数 = 提前**。[kind] 为相对时必填。
  final int? offsetMinutes;

  /// [kind] 为 `absolute` 时的墙钟。
  final PlanDate? absoluteDate;
  final MinuteOfDay? absoluteMinute;

  /// 关掉的提醒**留在库里**，不排期。
  ///
  /// 删掉与关掉是两件事：用户关掉一条「提前一天」是想以后再打开，
  /// 而那条提醒的偏移量是他调过的。
  final bool isEnabled;

  final DateTime? deletedAt;

  bool get isRelative => kind != ReminderKind.absolute;

  /// 这条提醒的字段搭配是否自洽。
  ///
  /// **显式抛而不是 assert**（cross-cutting §3.1）：assert 在 release 下
  /// 整条被移除，那时坏数据会一路写进库。
  void checkInvariants() {
    switch (kind) {
      case ReminderKind.relativeToStart:
      case ReminderKind.relativeToEnd:
        if (offsetMinutes == null) {
          throw FormatException('相对提醒必须有 offsetMinutes', id);
        }
        if (absoluteDate != null || absoluteMinute != null) {
          throw FormatException('相对提醒不该带绝对时刻', id);
        }
      case ReminderKind.absolute:
        if (absoluteDate == null || absoluteMinute == null) {
          throw FormatException('绝对提醒必须有日期与时刻', id);
        }
        if (offsetMinutes != null) {
          throw FormatException('绝对提醒不该带偏移', id);
        }
    }
  }

  Reminder copyWith({
    ReminderKind? kind,
    Object? offsetMinutes = unset,
    Object? absoluteDate = unset,
    Object? absoluteMinute = unset,
    bool? isEnabled,
    Object? deletedAt = unset,
  }) => Reminder(
    id: id,
    taskId: taskId,
    kind: kind ?? this.kind,
    offsetMinutes: patch<int>(offsetMinutes, this.offsetMinutes),
    absoluteDate: patch<PlanDate>(absoluteDate, this.absoluteDate),
    absoluteMinute: patch<MinuteOfDay>(absoluteMinute, this.absoluteMinute),
    isEnabled: isEnabled ?? this.isEnabled,
    deletedAt: patch<DateTime>(deletedAt, this.deletedAt),
  );

  @override
  String toString() =>
      'Reminder($id, ${kind.wireName}, '
      '${isRelative ? '$offsetMinutes 分' : '$absoluteDate $absoluteMinute'}'
      '${isEnabled ? '' : ', 已关'})';
}

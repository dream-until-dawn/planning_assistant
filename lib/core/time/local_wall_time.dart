/// 用户心智中的计划时间：「9 月 8 日 09:00，在 `Asia/Shanghai`」。
///
/// 这是本项目**唯一**用来表达计划时间的类型（ADR-0005）。
/// 它刻意不是绝对时刻 —— 用户设了「每天 07:00 起床」，飞到伦敦后仍应是当地 07:00。
///
/// 换算成绝对时刻必须经 `TimeZoneResolver`，本类自己不做任何时区计算：
/// 时区规则会随 tz 数据库更新而变，把它留在一个可注入的接口后面，
/// 测试才能固定住 DST 边界这类行为。
library;

import 'package:meta/meta.dart';

import 'minute_of_day.dart';
import 'plan_date.dart';

@immutable
final class LocalWallTime {
  const LocalWallTime({
    required this.date,
    required this.minuteOfDay,
    required this.timeZoneId,
  });

  /// 全天任务：只有日期，没有时刻。
  ///
  /// [minuteOfDay] 取 00:00 只是占位，**不表示「零点」这个时刻** ——
  /// 是否全天由 `tasks.isAllDay` 决定，两者不可互相推断。
  const LocalWallTime.allDay({required this.date, required this.timeZoneId})
    : minuteOfDay = MinuteOfDay.midnight;

  final PlanDate date;
  final MinuteOfDay minuteOfDay;

  /// IANA 时区标识，如 `Asia/Shanghai`。
  final String timeZoneId;

  /// 墙钟域的假 UTC 表示，供 rrule 这类时区无关的库使用。
  ///
  /// 它的 `isUtc` 为 true 但**不代表 UTC 时刻**（recurrence-engine §4）。
  /// 时区信息在这一步被丢弃，因此结果只能喂回同一时区的换算器。
  DateTime toFakeUtc() => date.toFakeUtc(minuteOfDay.value);

  /// 从墙钟域的假 UTC 值还原。
  static LocalWallTime fromFakeUtc(DateTime fakeUtc, String timeZoneId) =>
      LocalWallTime(
        date: PlanDate.fromUtcDateTime(fakeUtc),
        minuteOfDay: MinuteOfDay.of(fakeUtc.hour, fakeUtc.minute),
        timeZoneId: timeZoneId,
      );

  /// 推进 [minutes] 分钟，日期随之跨日。
  LocalWallTime addMinutes(int minutes) {
    final carried = minuteOfDay.addWithCarry(minutes);
    return LocalWallTime(
      date: date.addDays(carried.dayOffset),
      minuteOfDay: carried.minute,
      timeZoneId: timeZoneId,
    );
  }

  LocalWallTime withTimeZone(String newZoneId) => LocalWallTime(
    date: date,
    minuteOfDay: minuteOfDay,
    timeZoneId: newZoneId,
  );

  /// 同一时区内比较。
  ///
  /// **跨时区比较会抛异常**：两个不同时区的墙钟值没有可比性，
  /// 要比较必须先各自换算成 `Instant`。默默按字面量比大小是错的
  /// —— 那正是 ADR-0005 想消灭的那类 bug。
  int compareToSameZone(LocalWallTime other) {
    if (other.timeZoneId != timeZoneId) {
      throw ArgumentError(
        '不能直接比较不同时区的墙钟值（$timeZoneId vs ${other.timeZoneId}）；'
        '请先经 TimeZoneResolver.toInstant() 换算',
      );
    }
    final byDate = date.compareTo(other.date);
    return byDate != 0 ? byDate : minuteOfDay.compareTo(other.minuteOfDay);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalWallTime &&
      other.date == date &&
      other.minuteOfDay == minuteOfDay &&
      other.timeZoneId == timeZoneId;

  @override
  int get hashCode => Object.hash(date, minuteOfDay, timeZoneId);

  @override
  String toString() => '$date $minuteOfDay[$timeZoneId]';
}

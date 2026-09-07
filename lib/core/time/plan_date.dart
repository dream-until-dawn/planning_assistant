/// 纯日期，无时间部分、无时区。
///
/// 对应 docs/00-product/glossary.md §2 的 `PlanDate`，存储形态 `yyyy-MM-dd`。
///
/// **为什么不直接用 `DateTime`**：`DateTime` 同时能表示「绝对时刻」与「墙钟」，
/// 把两者混在一个类型里正是本项目要避免的（cross-cutting §1.1 的三种时间绝不混用）。
/// 一个独立类型让「日期 + 时刻 = 墙钟」这类换算在编译期就无法写错。
///
/// **为什么手写 `==`/`hashCode` 而不用 freezed**：这个类型会在重复展开的热循环里
/// 被大量创建与比较（NFR-PERF-04 要求 1 年 ≤ 50ms），保持零依赖、零代码生成。
library;

import 'package:meta/meta.dart';

@immutable
final class PlanDate implements Comparable<PlanDate> {
  const PlanDate(this.year, this.month, this.day);

  /// 从 `yyyy-MM-dd` 解析。格式或取值非法时抛 [FormatException]。
  ///
  /// 刻意**不接受**宽松形态（`2026-9-8`、`2026/09/08`、带时间后缀）：
  /// 存储层的值只可能来自本类的 [toString]，任何其它形态都说明数据被别处写过，
  /// 那种情况应当立刻失败而不是猜测。
  factory PlanDate.parse(String value) {
    final m = _pattern.firstMatch(value);
    if (m == null) {
      throw FormatException('PlanDate 必须是 yyyy-MM-dd', value);
    }
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12) {
      throw FormatException('月份超出 1..12', value);
    }
    if (d < 1 || d > daysInMonth(y, mo)) {
      throw FormatException('该月没有第 $d 天', value);
    }
    return PlanDate(y, mo, d);
  }

  /// 取 [instant] 在 UTC 下的日期部分。
  ///
  /// **不要用它把「绝对时刻」当成用户的计划日期** —— 那需要经
  /// `TimeZoneResolver.toWallTime()` 换算到任务时区。此工厂只用于
  /// 已经在墙钟域里的假 UTC 值（如 rrule 的展开结果）。
  factory PlanDate.fromUtcDateTime(DateTime dt) =>
      PlanDate(dt.year, dt.month, dt.day);

  static final RegExp _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  final int year;
  final int month;
  final int day;

  static bool isLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  static const List<int> _daysInMonth = [
    31,
    28,
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31,
  ];

  static int daysInMonth(int year, int month) =>
      month == 2 && isLeapYear(year) ? 29 : _daysInMonth[month - 1];

  /// 该日在**墙钟域**的假 UTC 表示，供 rrule 之类时区无关的库使用。
  ///
  /// 命名里带 `fake` 是刻意的：它的 `isUtc` 为 true 但**不代表 UTC 时刻**，
  /// 只是一个携带墙钟值的容器（recurrence-engine §4）。
  DateTime toFakeUtc([int minuteOfDay = 0]) =>
      DateTime.utc(year, month, day, minuteOfDay ~/ 60, minuteOfDay % 60);

  PlanDate addDays(int days) {
    final dt = DateTime.utc(year, month, day).add(Duration(days: days));
    return PlanDate(dt.year, dt.month, dt.day);
  }

  /// 与 [other] 相差的天数（本对象减去 [other]）。
  int differenceInDays(PlanDate other) => DateTime.utc(
    year,
    month,
    day,
  ).difference(DateTime.utc(other.year, other.month, other.day)).inDays;

  /// ISO-8601 星期：周一 = 1 … 周日 = 7，与 `DateTime.weekday` 一致。
  int get weekday => DateTime.utc(year, month, day).weekday;

  /// 该月最后一天。
  PlanDate get endOfMonth => PlanDate(year, month, daysInMonth(year, month));

  bool isBefore(PlanDate other) => compareTo(other) < 0;
  bool isAfter(PlanDate other) => compareTo(other) > 0;

  @override
  int compareTo(PlanDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is PlanDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  /// 存储形态。**必须与 [PlanDate.parse] 严格互逆**。
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

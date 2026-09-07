/// 从当日 00:00 起的分钟数，取值 0..1439。
///
/// 对应 glossary §2 的 `MinuteOfDay`，存储形态是 INT。
///
/// **为什么不用 `Duration` 或 `TimeOfDay`**：
///  · `Duration` 不带「必须落在一天之内」这个约束，越界值会静默传播；
///  · `TimeOfDay` 来自 Flutter，而 core 层必须零 Flutter 依赖（NFR-MAINT-02）。
library;

import 'package:meta/meta.dart';

@immutable
final class MinuteOfDay implements Comparable<MinuteOfDay> {
  /// 越界时抛 [RangeError]，**不做取模**。
  ///
  /// 取模会把「加了 25 小时」这类算错的结果悄悄变成合法值，
  /// 让 bug 表现为「时间莫名其妙少了一天」而不是当场失败。
  factory MinuteOfDay(int value) {
    if (value < 0 || value > maxValue) {
      throw RangeError.range(value, 0, maxValue, 'minuteOfDay');
    }
    return MinuteOfDay._(value);
  }

  const MinuteOfDay._(this.value);

  factory MinuteOfDay.of(int hour, int minute) {
    if (hour < 0 || hour > 23) {
      throw RangeError.range(hour, 0, 23, 'hour');
    }
    if (minute < 0 || minute > 59) {
      throw RangeError.range(minute, 0, 59, 'minute');
    }
    return MinuteOfDay._(hour * 60 + minute);
  }

  /// 1439 = 23:59。一天的分钟数是 1440，最大下标是 1439。
  static const int maxValue = 1439;

  static const MinuteOfDay midnight = MinuteOfDay._(0);

  /// 当日最后一个整分钟（23:59）。
  ///
  /// 「到某日止」的日终语义用它，见 recurrence-engine §6.1c ——
  /// 若把结束日当成该日 00:00，所有非零点开始的任务都会少一次。
  static const MinuteOfDay endOfDay = MinuteOfDay._(maxValue);

  final int value;

  int get hour => value ~/ 60;
  int get minute => value % 60;

  /// 加 [minutes] 分钟，**溢出到次日/前日时抛异常**。
  ///
  /// 跨日必须由调用方显式处理（同时推进 [PlanDate]），
  /// 否则「23:30 + 60 分钟」会得到 00:30 而日期没动。
  MinuteOfDay add(int minutes) => MinuteOfDay(value + minutes);

  /// 加 [minutes] 分钟并返回跨越的天数。用于需要跨日推进的场景。
  ({MinuteOfDay minute, int dayOffset}) addWithCarry(int minutes) {
    final total = value + minutes;
    // Dart 的 ~/ 与 % 对负数向零取整，这里需要向下取整
    final dayOffset = (total / 1440).floor();
    final within = total - dayOffset * 1440;
    return (minute: MinuteOfDay._(within), dayOffset: dayOffset);
  }

  @override
  int compareTo(MinuteOfDay other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      other is MinuteOfDay && other.value == value;

  @override
  int get hashCode => value.hashCode;

  /// 仅用于日志与调试。**面向用户的时间格式必须走 `intl`**
  /// （cross-cutting §5：日期/数字格式一律不手拼字符串）。
  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

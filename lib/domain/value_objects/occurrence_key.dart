/// 一次「发生」的身份标识。
///
/// **它是原始发生时刻，不是生效时刻**（data-model §4.2）：
/// 把 9/8 那次挪到 9/10 之后，它的 key 仍是 `2026-09-08T09:00`。
/// 否则规则再次展开时会在 9/8 又生成一个未被覆盖的实例 —— 出现重影。
/// 这与 iCalendar `RECURRENCE-ID` 的语义一致。
///
/// 形态按 data-model §4.6 区分全天与定时：
///  · 定时 `yyyy-MM-ddTHH:mm`
///  · 全天 `yyyy-MM-dd`（**不补 `T00:00`**）
///
/// 不补齐的理由：若全天写成 `T00:00`，用户把全天任务改成定时任务时，
/// 同一次发生的 key 会静默改变，已有的例外会全部失联。
library;

import 'package:meta/meta.dart';

import '../../core/time/local_wall_time.dart';
import '../../core/time/minute_of_day.dart';
import '../../core/time/plan_date.dart';

@immutable
final class OccurrenceKey implements Comparable<OccurrenceKey> {
  const OccurrenceKey._(this.value, this.date, this.minuteOfDay);

  /// 定时任务的 key。
  factory OccurrenceKey.timed(PlanDate date, MinuteOfDay minute) =>
      OccurrenceKey._('$date T$minute'.replaceAll(' ', ''), date, minute);

  /// 全天任务的 key。
  factory OccurrenceKey.allDay(PlanDate date) =>
      OccurrenceKey._(date.toString(), date, null);

  /// 从墙钟构造。[isAllDay] 决定形态，**不可从 minuteOfDay==0 反推**。
  factory OccurrenceKey.fromWallTime(
    LocalWallTime wall, {
    required bool isAllDay,
  }) => isAllDay
      ? OccurrenceKey.allDay(wall.date)
      : OccurrenceKey.timed(wall.date, wall.minuteOfDay);

  /// 解析存储中的 key。形态非法时抛 [FormatException]。
  factory OccurrenceKey.parse(String value) {
    final tIndex = value.indexOf('T');
    if (tIndex < 0) {
      return OccurrenceKey.allDay(PlanDate.parse(value));
    }
    final datePart = value.substring(0, tIndex);
    final timePart = value.substring(tIndex + 1);
    final m = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(timePart);
    if (m == null) {
      throw FormatException('occurrenceKey 的时间部分必须是 HH:mm', value);
    }
    return OccurrenceKey.timed(
      PlanDate.parse(datePart),
      MinuteOfDay.of(int.parse(m.group(1)!), int.parse(m.group(2)!)),
    );
  }

  /// 存储形态，与 [parse] 严格互逆。
  final String value;

  final PlanDate date;

  /// 全天任务为 null —— 这是区分两种形态的**唯一**依据。
  final MinuteOfDay? minuteOfDay;

  bool get isAllDay => minuteOfDay == null;

  @override
  int compareTo(OccurrenceKey other) {
    final byDate = date.compareTo(other.date);
    if (byDate != 0) return byDate;
    final a = minuteOfDay?.value ?? -1;
    final b = other.minuteOfDay?.value ?? -1;
    return a.compareTo(b);
  }

  @override
  bool operator ==(Object other) =>
      other is OccurrenceKey && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

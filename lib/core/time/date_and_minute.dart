/// 「哪天几点」以及它上面的偏移运算。
///
/// **放 core**：领域层要用它算任务的有效跨度（data-model §4.7），
/// 编辑器要用它把用户输入的绝对时刻折算成阶段偏移（§4.1）。
/// 留在某个 feature 里的话，`domain/` 够不到它（domain 不得依赖 features），
/// 于是同一套 `floorDiv` 会被抄第二遍 —— 而抄错的那一遍只在负偏移上错。
library;

import 'package:meta/meta.dart';

import 'minute_of_day.dart';
import 'plan_date.dart';

/// 一个墙钟上的「哪天几点」。
///
/// 不用 `LocalWallTime`：那个带时区，而这里的换算全在同一个时区内完成，
/// 带上时区只会让「换算错」与「时区错」混成一类问题。
@immutable
final class DateAndMinute implements Comparable<DateAndMinute> {
  const DateAndMinute(this.date, this.minute);

  final PlanDate date;
  final MinuteOfDay minute;

  @override
  int compareTo(DateAndMinute other) {
    final byDate = date.compareTo(other.date);
    return byDate != 0 ? byDate : minute.value.compareTo(other.minute.value);
  }

  bool isAfter(DateAndMinute other) => compareTo(other) > 0;
  bool isBefore(DateAndMinute other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) =>
      other is DateAndMinute && other.date == date && other.minute == minute;

  @override
  int get hashCode => Object.hash(date, minute);

  @override
  String toString() => '$date ${minute.value}';
}

const int minutesPerDay = 1440;

/// 从 [anchor] 起偏移 [offsetMinutes] 分钟之后落在哪天几点。
///
/// [offsetMinutes] 允许为负（虽然界面不产出负值）——
/// 用 `floorDiv` 而不是 `~/`：`-30 ~/ 1440 == 0`，会把「前一天 23:30」
/// 算成「当天 -30 分」。整数除法在负数上截断而不是下取整，
/// 是这类换算最常见的一处错，而正数样例一条都测不出来。
DateAndMinute shiftFrom(DateAndMinute anchor, int offsetMinutes) {
  final total = anchor.minute.value + offsetMinutes;
  final days = _floorDiv(total, minutesPerDay);
  final rest = total - days * minutesPerDay;
  return DateAndMinute(anchor.date.addDays(days), MinuteOfDay(rest));
}

/// [target] 相对 [anchor] 的偏移分钟数。[shiftFrom] 的逆。
int offsetFrom(DateAndMinute anchor, DateAndMinute target) =>
    target.date.differenceInDays(anchor.date) * minutesPerDay +
    (target.minute.value - anchor.minute.value);

/// 向下取整的整除。见 [shiftFrom] 里那段。
int _floorDiv(int a, int b) {
  final q = a ~/ b;
  return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q;
}

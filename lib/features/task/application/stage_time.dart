/// 阶段时间的两种表示之间的换算（data-model §4.1）。
///
/// **存的是相对偏移，看的是绝对时刻。**
///
/// 存偏移的理由是重复：一条每周发生的阶段事项，它的阶段该写哪一周的日期？
/// 写不出来。偏移则对每一次发生都成立，而且整体挪动任务时阶段自动跟随。
///
/// 但偏移不能拿给人看 ——「+1440 分钟」谁也读不出是哪天。所以界面上
/// 一律显示绝对时刻，编辑时换算回偏移（§4.1 最后一段），换算就在这里。
///
/// 放 application 而不是 domain：它是**编辑器**把用户的输入折算成存储形式
/// 的规则，不是领域不变量。领域侧只认偏移。
library;

import 'package:meta/meta.dart';

import '../../../core/time/minute_of_day.dart';
import '../../../core/time/plan_date.dart';

/// 一个墙钟上的「哪天几点」。
///
/// 不用 `LocalWallTime`：那个带时区，而编辑器里这几个换算全在同一个
/// 时区内完成，带上时区只会让「换算错」与「时区错」混成一类问题。
@immutable
final class DateAndMinute {
  const DateAndMinute(this.date, this.minute);

  final PlanDate date;
  final MinuteOfDay minute;

  @override
  bool operator ==(Object other) =>
      other is DateAndMinute && other.date == date && other.minute == minute;

  @override
  int get hashCode => Object.hash(date, minute);

  @override
  String toString() => '$date ${minute.value}';
}

const int _minutesPerDay = 1440;

/// 从 [anchor] 起偏移 [offsetMinutes] 分钟之后落在哪天几点。
///
/// [offsetMinutes] 允许为负（虽然界面不产出负值）——
/// 用 `floorDiv` 而不是 `~/`：`-30 ~/ 1440 == 0`，会把「前一天 23:30」
/// 算成「当天 -30 分」。整数除法在负数上截断而不是下取整，
/// 是这类换算最常见的一处错，而正数样例一条都测不出来。
DateAndMinute shiftFrom(DateAndMinute anchor, int offsetMinutes) {
  final total = anchor.minute.value + offsetMinutes;
  final days = _floorDiv(total, _minutesPerDay);
  final rest = total - days * _minutesPerDay;
  return DateAndMinute(anchor.date.addDays(days), MinuteOfDay(rest));
}

/// [target] 相对 [anchor] 的偏移分钟数。[shiftFrom] 的逆。
int offsetFrom(DateAndMinute anchor, DateAndMinute target) =>
    target.date.differenceInDays(anchor.date) * _minutesPerDay +
    (target.minute.value - anchor.minute.value);

/// 向下取整的整除。见 [shiftFrom] 里那段。
int _floorDiv(int a, int b) {
  final q = a ~/ b;
  return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q;
}

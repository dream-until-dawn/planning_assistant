/// 对某一次发生的单独处理，相当于 iCalendar 的 `RECURRENCE-ID` + 修改。
///
/// 对应 data-model §3.4。唯一索引是 `(taskId, occurrenceKey)` ——
/// 一次发生最多一条例外。
library;

import 'package:meta/meta.dart';

import '../../core/time/minute_of_day.dart';
import '../../core/time/plan_date.dart';
import '../value_objects/occurrence_key.dart';
import 'occurrence.dart';

enum OverrideAction {
  skip,
  modify;

  /// 存进数据库与导出格式的串。**不存枚举序号** ——
  /// 序号随枚举重排而变，会静默改写全部历史数据（同 `TaskStatus`）。
  String get wireName => name;

  /// 未知值**抛异常而不是回落** —— 静默回落会把「数据坏了」
  /// 变成「用户跳过的那一次自己回来了」。
  static OverrideAction fromWireName(String value) {
    for (final a in OverrideAction.values) {
      if (a.name == value) return a;
    }
    throw FormatException('未知的例外动作', value);
  }
}

@immutable
final class OccurrenceOverride {
  const OccurrenceOverride({
    required this.taskId,
    required this.key,
    required this.action,
    this.status,
    this.titleOverride,
    this.noteOverride,
    this.planDateOverride,
    this.startMinuteOverride,
    this.endDateOverride,
    this.endMinuteOverride,
  });

  /// 跳过某一次。
  const OccurrenceOverride.skip({required this.taskId, required this.key})
    : action = OverrideAction.skip,
      status = null,
      titleOverride = null,
      noteOverride = null,
      planDateOverride = null,
      startMinuteOverride = null,
      endDateOverride = null,
      endMinuteOverride = null;

  final String taskId;

  /// 被覆盖的那一次的**原始**标识。
  final OccurrenceKey key;

  final OverrideAction action;

  /// 该次的状态；null 表示不改变状态。
  final OccurrenceStatus? status;

  final String? titleOverride;
  final String? noteOverride;

  /// 把这一次挪到别的日期/时刻；null 表示不挪。
  final PlanDate? planDateOverride;
  final MinuteOfDay? startMinuteOverride;
  final PlanDate? endDateOverride;
  final MinuteOfDay? endMinuteOverride;

  /// 换一个 key，其余原样（R-27）。
  ///
  /// **这不是「改一行」，是「另起一行」**：行 id 由
  /// `taskId#occurrenceKey` 派生，key 变了身份就变了。
  /// 旧的那行要打墓碑，见 `all_day_conversion.dart` 开头那段。
  OccurrenceOverride withKey(OccurrenceKey newKey) => OccurrenceOverride(
    taskId: taskId,
    key: newKey,
    action: action,
    status: status,
    titleOverride: titleOverride,
    noteOverride: noteOverride,
    planDateOverride: planDateOverride,
    startMinuteOverride: startMinuteOverride,
    endDateOverride: endDateOverride,
    endMinuteOverride: endMinuteOverride,
  );

  bool get isSkip => action == OverrideAction.skip;

  /// 是否改变了发生的时间位置。
  bool get movesOccurrence =>
      planDateOverride != null || startMinuteOverride != null;

  @override
  String toString() =>
      'OccurrenceOverride($taskId, $key, ${action.name}'
      '${movesOccurrence ? ', 已挪动' : ''})';
}

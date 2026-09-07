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

enum OverrideAction { skip, modify }

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

  bool get isSkip => action == OverrideAction.skip;

  /// 是否改变了发生的时间位置。
  bool get movesOccurrence =>
      planDateOverride != null || startMinuteOverride != null;

  @override
  String toString() =>
      'OccurrenceOverride($taskId, $key, ${action.name}'
      '${movesOccurrence ? ', 已挪动' : ''})';
}

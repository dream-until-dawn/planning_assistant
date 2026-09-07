/// 阶段实体（data-model §3.2）。
///
/// 时间用**相对偏移**而非绝对日期（§4.1）：任务整体被挪动时，
/// 阶段跟着走，不需要逐个重算；重复任务的每次发生也共用同一套偏移。
library;

import 'package:meta/meta.dart';

import '../value_objects/task_status.dart';

@immutable
final class Stage {
  const Stage({
    required this.id,
    required this.taskId,
    required this.title,
    required this.orderIndex,
    this.startOffsetMinutes,
    this.durationMinutes,
    this.colorArgb,
    this.status = TaskStatus.pending,
    this.completedAt,
    this.deletedAt,
  });

  final String id;
  final String taskId;
  final String title;

  /// 从 0 起连续。
  final int orderIndex;

  /// 相对任务（或该次发生）开始的分钟偏移。
  final int? startOffsetMinutes;
  final int? durationMinutes;

  /// 甘特图分段色。
  final int? colorArgb;

  /// **仅非重复任务使用**；重复任务每次发生的阶段状态在
  /// `stage_occurrence_states`（data-model §3.5）。
  final TaskStatus status;

  final DateTime? completedAt;
  final DateTime? deletedAt;

  /// 相对任务开始的结束偏移。缺时长时与开始重合（零长）。
  int? get endOffsetMinutes {
    final start = startOffsetMinutes;
    if (start == null) return null;
    return start + (durationMinutes ?? 0);
  }

  static const Object _unset = Object();

  Stage copyWith({
    String? title,
    int? orderIndex,
    Object? startOffsetMinutes = _unset,
    Object? durationMinutes = _unset,
    Object? colorArgb = _unset,
    TaskStatus? status,
    Object? completedAt = _unset,
    Object? deletedAt = _unset,
  }) {
    return Stage(
      id: id,
      taskId: taskId,
      title: title ?? this.title,
      orderIndex: orderIndex ?? this.orderIndex,
      startOffsetMinutes: startOffsetMinutes == _unset
          ? this.startOffsetMinutes
          : startOffsetMinutes as int?,
      durationMinutes: durationMinutes == _unset
          ? this.durationMinutes
          : durationMinutes as int?,
      colorArgb: colorArgb == _unset ? this.colorArgb : colorArgb as int?,
      status: status ?? this.status,
      completedAt: completedAt == _unset
          ? this.completedAt
          : completedAt as DateTime?,
      deletedAt: deletedAt == _unset ? this.deletedAt : deletedAt as DateTime?,
    );
  }

  @override
  String toString() => 'Stage($id, "$title", #$orderIndex, ${status.name})';
}

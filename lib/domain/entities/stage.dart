/// 阶段实体（data-model §3.2）。
///
/// 时间用**相对偏移**而非绝对日期（§4.1）：任务整体被挪动时，
/// 阶段跟着走，不需要逐个重算；重复任务的每次发生也共用同一套偏移。
library;

import 'package:meta/meta.dart';

import '../../core/patch/unset.dart';
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

  Stage copyWith({
    String? title,
    int? orderIndex,
    Object? startOffsetMinutes = unset,
    Object? durationMinutes = unset,
    Object? colorArgb = unset,
    TaskStatus? status,
    Object? completedAt = unset,
    Object? deletedAt = unset,
  }) {
    return Stage(
      id: id,
      taskId: taskId,
      title: title ?? this.title,
      orderIndex: orderIndex ?? this.orderIndex,
      startOffsetMinutes: patch<int>(
        startOffsetMinutes,
        this.startOffsetMinutes,
      ),
      durationMinutes: patch<int>(durationMinutes, this.durationMinutes),
      colorArgb: patch<int>(colorArgb, this.colorArgb),
      status: status ?? this.status,
      completedAt: patch<DateTime>(completedAt, this.completedAt),
      deletedAt: patch<DateTime>(deletedAt, this.deletedAt),
    );
  }

  @override
  String toString() => 'Stage($id, "$title", #$orderIndex, ${status.name})';
}

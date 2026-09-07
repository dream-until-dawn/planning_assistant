/// 重复规则在某一具体时刻的一次发生。
///
/// **不预存在数据库里**（ADR-0004）：库里只有规则与例外，实例按可见窗口现场展开。
library;

import 'package:meta/meta.dart';

import '../../core/time/local_wall_time.dart';
import '../value_objects/occurrence_key.dart';

/// 一次发生的状态。
///
/// 注意与 `TaskStatus` 的区别：重复任务的 `tasks.status` **恒为 pending**，
/// 真实状态落在这里（data-model §4.3）。
enum OccurrenceStatus { pending, inProgress, done, skipped }

@immutable
final class Occurrence {
  const Occurrence({
    required this.taskId,
    required this.key,
    required this.start,
    required this.isAllDay,
    this.end,
    this.status = OccurrenceStatus.pending,
    this.titleOverride,
    this.noteOverride,
    this.isModified = false,
  });

  final String taskId;

  /// **原始**发生时刻的标识，即使这一次被挪到了别处也不变。
  final OccurrenceKey key;

  /// **生效**的开始墙钟。被 override 挪动过时与 [key] 不一致。
  final LocalWallTime start;

  /// 生效的结束墙钟。无明确时长时为 null。
  final LocalWallTime? end;

  final bool isAllDay;
  final OccurrenceStatus status;

  /// 本次专属的标题；null 表示继承任务。
  final String? titleOverride;
  final String? noteOverride;

  /// 这一次是否被 override 修改过（时间、标题、状态任一）。
  final bool isModified;

  /// 生效开始时刻是否已偏离 key 所指的原始时刻。
  bool get isMoved =>
      OccurrenceKey.fromWallTime(start, isAllDay: isAllDay) != key;

  Occurrence copyWith({
    LocalWallTime? start,
    LocalWallTime? end,
    OccurrenceStatus? status,
    String? titleOverride,
    String? noteOverride,
    bool? isModified,
  }) => Occurrence(
    taskId: taskId,
    key: key,
    start: start ?? this.start,
    end: end ?? this.end,
    isAllDay: isAllDay,
    status: status ?? this.status,
    titleOverride: titleOverride ?? this.titleOverride,
    noteOverride: noteOverride ?? this.noteOverride,
    isModified: isModified ?? this.isModified,
  );

  @override
  bool operator ==(Object other) =>
      other is Occurrence &&
      other.taskId == taskId &&
      other.key == key &&
      other.start == start &&
      other.end == end &&
      other.isAllDay == isAllDay &&
      other.status == status &&
      other.titleOverride == titleOverride &&
      other.noteOverride == noteOverride &&
      other.isModified == isModified;

  @override
  int get hashCode => Object.hash(
    taskId,
    key,
    start,
    end,
    isAllDay,
    status,
    titleOverride,
    noteOverride,
    isModified,
  );

  @override
  String toString() =>
      'Occurrence($taskId, key=$key, start=$start'
      '${isMoved ? ' [已挪动]' : ''}, status=${status.name})';
}

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
enum OccurrenceStatus {
  pending,
  inProgress,
  done,
  skipped;

  /// 存进数据库与导出格式的串，取值与 `TaskStatus.wireName` 一致 ——
  /// 同一件事在两处用同一套词，导出格式里也就只有一套状态词。
  String get wireName => name;

  /// 未知值抛异常，不回落（同 `TaskStatus.fromWireName` 的理由）。
  static OccurrenceStatus fromWireName(String value) {
    for (final s in OccurrenceStatus.values) {
      if (s.name == value) return s;
    }
    throw FormatException('未知的发生状态', value);
  }
}

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
    this.dstAdjusted = false,
    this.endDstAdjusted = false,
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

  /// [start] 的墙钟在该时区当天**不存在**（春季跳表），已顺延到该时段后
  /// 第一个合法时刻（recurrence-engine §4.1）。
  ///
  /// 暴露出来是为了让 UI 能解释「为什么今天这条是 03:00 而不是 02:30」——
  /// 静默改掉时刻而不告诉用户，是日历应用最招人恨的行为之一。
  final bool dstAdjusted;

  /// [end] 被同样顺延过。
  ///
  /// **与 [dstAdjusted] 分开**：两端各自独立解析（§4.1.1），
  /// 完全可能只有一端落进空隙 —— 合成一个标记的话，UI 无从知道该解释哪一端。
  final bool endDstAdjusted;

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
    bool? dstAdjusted,
    bool? endDstAdjusted,
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
    dstAdjusted: dstAdjusted ?? this.dstAdjusted,
    endDstAdjusted: endDstAdjusted ?? this.endDstAdjusted,
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
      other.isModified == isModified &&
      other.dstAdjusted == dstAdjusted &&
      other.endDstAdjusted == endDstAdjusted;

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

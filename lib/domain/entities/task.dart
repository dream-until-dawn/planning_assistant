/// 任务实体（data-model §3.1）。
///
/// 纯值对象：没有任何持久化、Flutter 或平台依赖。所有状态变更经
/// `domain/policies/task_lifecycle.dart` 的纯函数完成，实体本身只提供
/// [copyWith] 与不变量校验。
library;

import 'package:meta/meta.dart';

import '../../core/time/local_wall_time.dart';
import '../../core/time/minute_of_day.dart';
import '../../core/time/plan_date.dart';
import '../value_objects/recurrence.dart';
import '../value_objects/task_status.dart';

/// 任务形态（data-model §3.1 的 `kind` 列）。
enum TaskKind {
  /// 单个待办。
  single,

  /// 一件事，多个阶段。
  staged;

  String get wireName => name;

  static TaskKind fromWireName(String value) {
    for (final k in TaskKind.values) {
      if (k.name == value) return k;
    }
    throw FormatException('未知的任务形态', value);
  }
}

/// 优先级。存 INT，但取值受控。
enum TaskPriority {
  none(0),
  low(1),
  normal(2),
  high(3),
  urgent(4);

  const TaskPriority(this.value);
  final int value;

  static TaskPriority fromValue(int value) {
    for (final p in TaskPriority.values) {
      if (p.value == value) return p;
    }
    throw FormatException('未知的优先级', '$value');
  }
}

@immutable
final class Task {
  const Task({
    required this.id,
    required this.title,
    required this.kind,
    required this.timeZoneId,
    this.note,
    this.categoryId,
    this.priority = TaskPriority.normal,
    this.status = TaskStatus.pending,
    this.statusBeforeArchive,
    this.isAllDay = false,
    this.planDate,
    this.startMinute,
    this.endDate,
    this.endMinute,
    this.recurrence,
    this.recurrenceExDates = const [],
    this.splitFromTaskId,
    this.colorArgb,
    this.icon,
    this.sortOrder = 0,
    this.completedAt,
    this.archivedAt,
    this.deletedAt,
  });

  final String id;
  final String title;
  final String? note;
  final TaskKind kind;
  final String? categoryId;
  final TaskPriority priority;

  /// **重复任务此列恒为 `pending`**，真实状态在 `occurrence_overrides`。
  /// 由 [checkInvariants] 强制。
  final TaskStatus status;

  /// 归档时快照的 [status]；非归档态恒为 null。
  final TaskStatus? statusBeforeArchive;

  final bool isAllDay;

  /// 重复任务时即 DTSTART 的日期。
  final PlanDate? planDate;
  final MinuteOfDay? startMinute;
  final PlanDate? endDate;
  final MinuteOfDay? endMinute;

  /// 创建时的 IANA 时区。存墙钟 + 时区而非 UTC 时间戳（ADR-0005）。
  final String timeZoneId;

  /// null = 不重复。
  final Recurrence? recurrence;

  /// **V1 不参与展开**，仅作导入 `.ics` 的原始留档（data-model §4.5）。
  final List<String> recurrenceExDates;

  /// 「本次及以后」分裂的溯源。
  final String? splitFromTaskId;

  final int? colorArgb;
  final String? icon;
  final double sortOrder;

  /// 实际点击完成的瞬时（UTC ms），**不是计划时间**（§5）。
  final DateTime? completedAt;

  /// 非空即已归档。归档不是 `status` 的取值（§1.1）。
  final DateTime? archivedAt;

  /// 非空即墓碑。
  final DateTime? deletedAt;

  bool get isRecurring => recurrence != null;
  bool get isArchived => archivedAt != null;
  bool get isDeleted => deletedAt != null;

  /// 开始墙钟。无日期时为 null。
  LocalWallTime? get startWallTime {
    final date = planDate;
    if (date == null) return null;
    return LocalWallTime(
      date: date,
      minuteOfDay: startMinute ?? MinuteOfDay.midnight,
      timeZoneId: timeZoneId,
    );
  }

  /// 校验领域不变量。**显式抛出，不用 `assert`**（task-lifecycle §3.1）——
  /// `assert` 在 AOT release 构建里整条消失，正式包零保护。
  ///
  /// 每次构造后并不自动调用：实体是纯值对象，校验的时机由用例决定
  /// （例如命令管道在写库前统一调）。但**任何写入路径都必须调**。
  void checkInvariants() {
    if (isRecurring && status != TaskStatus.pending) {
      throw DomainInvariantViolation(
        '重复任务 $id 的 status 必须恒为 pending（当前 ${status.name}）；'
        '每次发生的状态应落在 occurrence_overrides（data-model §4.3）',
      );
    }
    if (isArchived && statusBeforeArchive == null) {
      throw DomainInvariantViolation(
        '任务 $id 已归档但缺少 statusBeforeArchive —— 取消归档时无从还原',
      );
    }
    if (!isArchived && statusBeforeArchive != null) {
      throw DomainInvariantViolation(
        '任务 $id 未归档却留着 statusBeforeArchive=${statusBeforeArchive!.name}，'
        '取消归档时未清理',
      );
    }
    if (isAllDay && startMinute != null) {
      throw DomainInvariantViolation(
        '任务 $id 是全天任务却带 startMinute=${startMinute!.value}',
      );
    }
    if (status == TaskStatus.done && completedAt == null) {
      throw DomainInvariantViolation('任务 $id 状态为 done 但没有 completedAt');
    }
    if (status != TaskStatus.done && completedAt != null) {
      throw DomainInvariantViolation(
        '任务 $id 状态为 ${status.name} 却留着 completedAt —— 取消完成时未清理',
      );
    }
  }

  /// `null` 与「不改」在 [copyWith] 里无法区分，因此可空字段用哨兵。
  ///
  /// 不用哨兵的话，「清空备注」和「不动备注」会写成同一个调用 ——
  /// 这类 copyWith 缺陷在测试里极难看出来，因为两者中的一个总是碰巧对的。
  static const Object _unset = Object();

  Task copyWith({
    String? title,
    Object? note = _unset,
    TaskKind? kind,
    Object? categoryId = _unset,
    TaskPriority? priority,
    TaskStatus? status,
    Object? statusBeforeArchive = _unset,
    bool? isAllDay,
    Object? planDate = _unset,
    Object? startMinute = _unset,
    Object? endDate = _unset,
    Object? endMinute = _unset,
    String? timeZoneId,
    Object? recurrence = _unset,
    List<String>? recurrenceExDates,
    Object? splitFromTaskId = _unset,
    Object? colorArgb = _unset,
    Object? icon = _unset,
    double? sortOrder,
    Object? completedAt = _unset,
    Object? archivedAt = _unset,
    Object? deletedAt = _unset,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      note: note == _unset ? this.note : note as String?,
      kind: kind ?? this.kind,
      categoryId: categoryId == _unset
          ? this.categoryId
          : categoryId as String?,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      statusBeforeArchive: statusBeforeArchive == _unset
          ? this.statusBeforeArchive
          : statusBeforeArchive as TaskStatus?,
      isAllDay: isAllDay ?? this.isAllDay,
      planDate: planDate == _unset ? this.planDate : planDate as PlanDate?,
      startMinute: startMinute == _unset
          ? this.startMinute
          : startMinute as MinuteOfDay?,
      endDate: endDate == _unset ? this.endDate : endDate as PlanDate?,
      endMinute: endMinute == _unset
          ? this.endMinute
          : endMinute as MinuteOfDay?,
      timeZoneId: timeZoneId ?? this.timeZoneId,
      recurrence: recurrence == _unset
          ? this.recurrence
          : recurrence as Recurrence?,
      recurrenceExDates: recurrenceExDates ?? this.recurrenceExDates,
      splitFromTaskId: splitFromTaskId == _unset
          ? this.splitFromTaskId
          : splitFromTaskId as String?,
      colorArgb: colorArgb == _unset ? this.colorArgb : colorArgb as int?,
      icon: icon == _unset ? this.icon : icon as String?,
      sortOrder: sortOrder ?? this.sortOrder,
      completedAt: completedAt == _unset
          ? this.completedAt
          : completedAt as DateTime?,
      archivedAt: archivedAt == _unset
          ? this.archivedAt
          : archivedAt as DateTime?,
      deletedAt: deletedAt == _unset ? this.deletedAt : deletedAt as DateTime?,
    );
  }

  @override
  String toString() =>
      'Task($id, "$title", ${kind.name}, ${status.name}'
      '${isRecurring ? ', recurring' : ''}'
      '${isArchived ? ', archived' : ''}'
      '${isDeleted ? ', deleted' : ''})';
}

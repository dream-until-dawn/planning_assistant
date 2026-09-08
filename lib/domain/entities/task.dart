/// 任务实体（data-model §3.1）。
///
/// 纯值对象：没有任何持久化、Flutter 或平台依赖。所有状态变更经
/// `domain/policies/task_lifecycle.dart` 的纯函数完成，实体本身只提供
/// [copyWith] 与不变量校验。
library;

import 'package:meta/meta.dart';

import '../../core/patch/unset.dart';
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
  none(0, '无'),
  low(1, '低'),
  normal(2, '普通'),
  high(3, '高'),
  urgent(4, '紧急');

  const TaskPriority(this.value, this.label);

  /// 存进库里的数值（data-model §3.1）。**枚举顺序不是它** ——
  /// 改枚举顺序不该改写用户的数据。
  final int value;

  /// 给人看的名字。
  // TODO(M4): 走 l10n 资源（NFR-A11Y-04）
  final String label;

  /// 从高到低。列表的「按优先级」分组与筛选条都按这个顺序摆
  /// （view-specs §2.1「紧急 → 高 → 普通 → 低 → 无」）——
  /// 两处各写一遍的话，筛选条与分组的次序会对不上。
  static const List<TaskPriority> byImportance = [
    TaskPriority.urgent,
    TaskPriority.high,
    TaskPriority.normal,
    TaskPriority.low,
    TaskPriority.none,
  ];

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

  /// 结束早于开始。
  ///
  /// 先比日期，同一天才比分钟。**缺失的结束时刻按当天最后一分钟算**，
  /// 不按 00:00 —— 「9/8 九点开始，9/8 结束」说的是「那天结束前」，
  /// 按 00:00 理解会把一条完全正常的任务判成违规。
  bool get _endsBeforeItStarts {
    final start = planDate;
    final end = endDate;
    if (start == null || end == null) return false;
    if (end.isBefore(start)) return true;
    if (end != start) return false;
    return (endMinute?.value ?? 1439) < (startMinute?.value ?? 0);
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
    // 结束侧与开始侧对称。**这四条是补上的** —— 一开始只写了开始侧，
    // 而那时编辑器还写不出结束时间，于是「没有测试会红」与
    // 「不会出问题」看起来是一回事。写得出来的那天，坏数据就落库了。
    if (isAllDay && endMinute != null) {
      throw DomainInvariantViolation(
        '任务 $id 是全天任务却带 endMinute=${endMinute!.value}',
      );
    }
    if (endMinute != null && endDate == null) {
      throw DomainInvariantViolation('任务 $id 有结束时刻却没有结束日期 —— 「几点」落不到哪一天上');
    }
    if (endDate != null && planDate == null) {
      throw DomainInvariantViolation('任务 $id 有结束日期却没有开始日期');
    }
    if (_endsBeforeItStarts) {
      throw DomainInvariantViolation(
        '任务 $id 的结束（$endDate ${endMinute?.value}）早于开始'
        '（$planDate ${startMinute?.value}）',
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

  /// 可空字段用 [unset] 哨兵区分「不改」与「显式清空」，理由见该文件。
  Task copyWith({
    String? title,
    Object? note = unset,
    TaskKind? kind,
    Object? categoryId = unset,
    TaskPriority? priority,
    TaskStatus? status,
    Object? statusBeforeArchive = unset,
    bool? isAllDay,
    Object? planDate = unset,
    Object? startMinute = unset,
    Object? endDate = unset,
    Object? endMinute = unset,
    String? timeZoneId,
    Object? recurrence = unset,
    List<String>? recurrenceExDates,
    Object? splitFromTaskId = unset,
    Object? colorArgb = unset,
    Object? icon = unset,
    double? sortOrder,
    Object? completedAt = unset,
    Object? archivedAt = unset,
    Object? deletedAt = unset,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      note: patch<String>(note, this.note),
      kind: kind ?? this.kind,
      categoryId: patch<String>(categoryId, this.categoryId),
      priority: priority ?? this.priority,
      status: status ?? this.status,
      statusBeforeArchive: patch<TaskStatus>(
        statusBeforeArchive,
        this.statusBeforeArchive,
      ),
      isAllDay: isAllDay ?? this.isAllDay,
      planDate: patch<PlanDate>(planDate, this.planDate),
      startMinute: patch<MinuteOfDay>(startMinute, this.startMinute),
      endDate: patch<PlanDate>(endDate, this.endDate),
      endMinute: patch<MinuteOfDay>(endMinute, this.endMinute),
      timeZoneId: timeZoneId ?? this.timeZoneId,
      recurrence: patch<Recurrence>(recurrence, this.recurrence),
      recurrenceExDates: recurrenceExDates ?? this.recurrenceExDates,
      splitFromTaskId: patch<String>(splitFromTaskId, this.splitFromTaskId),
      colorArgb: patch<int>(colorArgb, this.colorArgb),
      icon: patch<String>(icon, this.icon),
      sortOrder: sortOrder ?? this.sortOrder,
      completedAt: patch<DateTime>(completedAt, this.completedAt),
      archivedAt: patch<DateTime>(archivedAt, this.archivedAt),
      deletedAt: patch<DateTime>(deletedAt, this.deletedAt),
    );
  }

  @override
  String toString() =>
      'Task($id, "$title", ${kind.name}, ${status.name}'
      '${isRecurring ? ', recurring' : ''}'
      '${isArchived ? ', archived' : ''}'
      '${isDeleted ? ', deleted' : ''})';
}

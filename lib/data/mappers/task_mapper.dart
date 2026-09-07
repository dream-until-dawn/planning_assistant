/// Drift 行 ⇄ 领域实体的转换（module-map `data/mappers/`）。
///
/// **这一层没有业务逻辑，只有逐字段搬运** —— 也正因为如此，它是最容易
/// 出现「两个同类型字段搬反了」的地方：搬反了编译通过、往返测试也通过
/// （两个方向反得一致），只有逐列断言才能抓到。见 `test/data/task_mapper_test.dart`。
///
/// 信封字段（`createdAt` / `updatedAt` / `revision` / `lastWriterId` /
/// `remoteVersion`）**不进领域实体**：它们是持久化与同步的簿记，
/// 由 `SyncedDao` 维护，领域层不该知道。唯一的例外是 `deletedAt` ——
/// 回收站是产品功能，不是簿记。
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/time/minute_of_day.dart';
import '../../core/time/plan_date.dart';
import '../../domain/entities/stage.dart';
import '../../domain/entities/task.dart';
import '../../domain/value_objects/recurrence.dart';
import '../../domain/value_objects/task_status.dart';
import '../database/app_database.dart';

/// Instant ms ⇄ UTC DateTime。
DateTime? _instantFromMs(int? ms) =>
    ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

int? _msFromInstant(DateTime? instant) => instant?.millisecondsSinceEpoch;

/// `recurrenceExDates` 是**二次编码的 JSON 列**（data-model §6）：
/// 库里是 TEXT，内容本身是 JSON 数组。导出契约对这一列有专门标注。
List<String> _decodeExDates(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    throw FormatException('recurrenceExDates 不是 JSON 数组', raw);
  }
  return decoded.cast<String>();
}

String? _encodeExDates(List<String> dates) =>
    dates.isEmpty ? null : jsonEncode(dates);

extension TaskRowMapper on TaskRow {
  /// 行 → 实体。
  ///
  /// 未知的枚举串**抛异常而不是回落到默认值**：静默回落会把「数据坏了」
  /// 变成「用户的任务莫名变回待办」，且再也查不出何时坏的。
  Task toEntity() => Task(
    id: id,
    title: title,
    note: note,
    kind: TaskKind.fromWireName(kind),
    categoryId: categoryId,
    priority: TaskPriority.fromValue(priority),
    status: TaskStatus.fromWireName(status),
    statusBeforeArchive: statusBeforeArchive == null
        ? null
        : TaskStatus.fromWireName(statusBeforeArchive!),
    isAllDay: isAllDay,
    planDate: planDate == null ? null : PlanDate.parse(planDate!),
    startMinute: startMinute == null ? null : MinuteOfDay(startMinute!),
    endDate: endDate == null ? null : PlanDate.parse(endDate!),
    endMinute: endMinute == null ? null : MinuteOfDay(endMinute!),
    timeZoneId: timeZoneId,
    recurrence: recurrenceRule == null
        ? null
        : Recurrence.parse(recurrenceRule!),
    recurrenceExDates: _decodeExDates(recurrenceExDates),
    splitFromTaskId: splitFromTaskId,
    colorArgb: colorArgb,
    icon: icon,
    sortOrder: sortOrder,
    completedAt: _instantFromMs(completedAt),
    archivedAt: _instantFromMs(archivedAt),
    deletedAt: _instantFromMs(deletedAt),
  );
}

extension TaskEntityMapper on Task {
  /// 实体 → 可写入的 Companion。
  ///
  /// **不含信封字段**：它们由 `SyncedDao.upsert()` 盖章。这里若一并写出，
  /// 就会与 DAO 的盖章互相覆盖，且哪边赢取决于调用顺序。
  TasksCompanion toCompanion() => TasksCompanion.insert(
    id: id,
    title: title,
    note: Value(note),
    kind: kind.wireName,
    categoryId: Value(categoryId),
    priority: Value(priority.value),
    status: Value(status.wireName),
    statusBeforeArchive: Value(statusBeforeArchive?.wireName),
    isAllDay: Value(isAllDay),
    planDate: Value(planDate?.toString()),
    startMinute: Value(startMinute?.value),
    endDate: Value(endDate?.toString()),
    endMinute: Value(endMinute?.value),
    timeZoneId: timeZoneId,
    recurrenceRule: Value(recurrence?.canonical),
    recurrenceExDates: Value(_encodeExDates(recurrenceExDates)),
    splitFromTaskId: Value(splitFromTaskId),
    colorArgb: Value(colorArgb),
    icon: Value(icon),
    sortOrder: Value(sortOrder),
    completedAt: Value(_msFromInstant(completedAt)),
    archivedAt: Value(_msFromInstant(archivedAt)),
    deletedAt: Value(_msFromInstant(deletedAt)),
  );
}

extension StageRowMapper on StageRow {
  Stage toEntity() => Stage(
    id: id,
    taskId: taskId,
    title: title,
    orderIndex: orderIndex,
    startOffsetMinutes: startOffsetMinutes,
    durationMinutes: durationMinutes,
    colorArgb: colorArgb,
    status: TaskStatus.fromWireName(status),
    completedAt: _instantFromMs(completedAt),
    deletedAt: _instantFromMs(deletedAt),
  );
}

extension StageEntityMapper on Stage {
  StagesCompanion toCompanion() => StagesCompanion.insert(
    id: id,
    taskId: taskId,
    title: title,
    orderIndex: orderIndex,
    startOffsetMinutes: Value(startOffsetMinutes),
    durationMinutes: Value(durationMinutes),
    colorArgb: Value(colorArgb),
    status: Value(status.wireName),
    completedAt: Value(_msFromInstant(completedAt)),
    deletedAt: Value(_msFromInstant(deletedAt)),
  );
}

/// 领域实体**不覆盖**的列。
///
/// 提出来给守卫测试用：`tasks` 表新增一列时，若忘了在 mapper 里搬运，
/// 「mapper 覆盖了全部非信封列」那条会红。信封列在这里列出即视为「有意不搬」。
const Set<String> kEnvelopeOnlyColumns = {
  'created_at',
  'updated_at',
  'revision',
  'last_writer_id',
  'remote_version',
};

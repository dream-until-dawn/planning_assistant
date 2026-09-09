/// Drift 行 ⇄ 单次例外实体（module-map `data/mappers/`）。
///
/// ## 这一层要多做一件事：造主键
///
/// 领域实体 `OccurrenceOverride` **没有 id 字段** —— 一次发生的身份就是
/// `(taskId, occurrenceKey)`，相等性也由这两者决定。而表需要一个主键。
///
/// 主键**由这两者派生**，不是随机 UUID（data-model §4.3.1）：
///
///  · 随机的话「勾完成 → 取消 → 再勾」会插三行例外，而读取时
///    「哪一行说了算」没有定义 —— 表现为完成状态随机跳；
///  · V3 同步时，两台设备各自标记同一次，会带着两个不同的 id 上去，
///    合并后那一天出现两个「已完成」的同一件事。
library;

import 'package:drift/drift.dart';

import '../../core/time/minute_of_day.dart';
import '../../core/time/plan_date.dart';
import '../../domain/entities/occurrence.dart';
import '../../domain/entities/occurrence_override.dart';
import '../../domain/value_objects/occurrence_key.dart';
import '../database/app_database.dart';

/// 例外行的主键。
///
/// `occurrenceKey` 的形态是 `yyyy-MM-dd` 或 `yyyy-MM-ddTHH:mm`（§4.6），
/// 都不含 `#`，所以拼接无歧义。
String overrideRowId(String taskId, OccurrenceKey key) =>
    '$taskId#${key.value}';

OccurrenceOverride occurrenceOverrideFromRow(OccurrenceOverrideRow row) =>
    OccurrenceOverride(
      taskId: row.taskId,
      key: OccurrenceKey.parse(row.occurrenceKey),
      action: OverrideAction.fromWireName(row.action),
      status: row.status == null
          ? null
          : OccurrenceStatus.fromWireName(row.status!),
      completedAt: row.completedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.completedAt!, isUtc: true),
      titleOverride: row.titleOverride,
      noteOverride: row.noteOverride,
      planDateOverride: row.planDateOverride == null
          ? null
          : PlanDate.parse(row.planDateOverride!),
      startMinuteOverride: row.startMinuteOverride == null
          ? null
          : MinuteOfDay(row.startMinuteOverride!),
      endDateOverride: row.endDateOverride == null
          ? null
          : PlanDate.parse(row.endDateOverride!),
      endMinuteOverride: row.endMinuteOverride == null
          ? null
          : MinuteOfDay(row.endMinuteOverride!),
    );

OccurrenceOverridesCompanion occurrenceOverrideToCompanion(
  OccurrenceOverride o,
) => OccurrenceOverridesCompanion(
  id: Value(overrideRowId(o.taskId, o.key)),
  taskId: Value(o.taskId),
  occurrenceKey: Value(o.key.value),
  action: Value(o.action.wireName),
  status: Value(o.status?.wireName),
  completedAt: Value(o.completedAt?.millisecondsSinceEpoch),
  titleOverride: Value(o.titleOverride),
  noteOverride: Value(o.noteOverride),
  planDateOverride: Value(o.planDateOverride?.toString()),
  startMinuteOverride: Value(o.startMinuteOverride?.value),
  endDateOverride: Value(o.endDateOverride?.toString()),
  endMinuteOverride: Value(o.endMinuteOverride?.value),
);

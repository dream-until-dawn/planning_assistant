/// `ReminderRow` ⇄ [Reminder]（data-model §3.8）。
library;

import 'package:drift/drift.dart';

import '../../core/time/minute_of_day.dart';
import '../../core/time/plan_date.dart';
import '../../domain/entities/reminder.dart';
import '../database/app_database.dart';

Reminder reminderFromRow(ReminderRow row) => Reminder(
  id: row.id,
  taskId: row.taskId,
  kind: ReminderKind.fromWireName(row.kind),
  offsetMinutes: row.offsetMinutes,
  absoluteDate: row.absoluteDate == null
      ? null
      : PlanDate.parse(row.absoluteDate!),
  absoluteMinute: row.absoluteMinute == null
      ? null
      : MinuteOfDay(row.absoluteMinute!),
  isEnabled: row.isEnabled,
  deletedAt: row.deletedAt == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(row.deletedAt!, isUtc: true),
);

RemindersCompanion reminderToCompanion(Reminder r) => RemindersCompanion(
  id: Value(r.id),
  taskId: Value(r.taskId),
  kind: Value(r.kind.wireName),
  offsetMinutes: Value(r.offsetMinutes),
  absoluteDate: Value(r.absoluteDate?.toString()),
  absoluteMinute: Value(r.absoluteMinute?.value),
  isEnabled: Value(r.isEnabled),
  deletedAt: Value(r.deletedAt?.millisecondsSinceEpoch),
);

/// `StageOccurrenceStateRow` ⇄ [StageOccurrenceState]（data-model §3.6）。
library;

import 'package:drift/drift.dart';

import '../../domain/entities/stage_occurrence_state.dart';
import '../../domain/value_objects/occurrence_key.dart';
import '../../domain/value_objects/task_status.dart';
import '../database/app_database.dart';

StageOccurrenceState stageStateFromRow(StageOccurrenceStateRow row) =>
    StageOccurrenceState(
      id: row.id,
      taskId: row.taskId,
      stageId: row.stageId,
      occurrenceKey: OccurrenceKey.parse(row.occurrenceKey),
      status: TaskStatus.fromWireName(row.status),
      completedAt: row.completedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.completedAt!, isUtc: true),
      deletedAt: row.deletedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.deletedAt!, isUtc: true),
    );

StageOccurrenceStatesCompanion stageStateToCompanion(StageOccurrenceState s) =>
    StageOccurrenceStatesCompanion(
      id: Value(s.id),
      taskId: Value(s.taskId),
      stageId: Value(s.stageId),
      occurrenceKey: Value(s.occurrenceKey.value),
      status: Value(s.status.wireName),
      completedAt: Value(s.completedAt?.millisecondsSinceEpoch),
    );

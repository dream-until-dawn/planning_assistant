/// `ChecklistItemRow` ⇄ [ChecklistItem]（data-model §3.3）。
library;

import 'package:drift/drift.dart';

import '../../domain/entities/checklist_item.dart';
import '../database/app_database.dart';

ChecklistItem checklistItemFromRow(ChecklistItemRow row) => ChecklistItem(
  id: row.id,
  taskId: row.taskId,
  title: row.title,
  orderIndex: row.orderIndex,
  isDone: row.isDone,
  deletedAt: row.deletedAt == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(row.deletedAt!, isUtc: true),
);

ChecklistItemsCompanion checklistItemToCompanion(ChecklistItem i) =>
    ChecklistItemsCompanion(
      id: Value(i.id),
      taskId: Value(i.taskId),
      title: Value(i.title),
      isDone: Value(i.isDone),
      orderIndex: Value(i.orderIndex),
      deletedAt: Value(i.deletedAt?.millisecondsSinceEpoch),
    );

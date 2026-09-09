/// 归档（FR-TASK-08 的另一半、task-lifecycle §1.1）。
///
/// `ArchiveTaskCommand` / `UnarchiveTaskCommand` 在领域层一直都在、也测过，
/// 界面上够不着 —— 与删除此前是同一种状态。
///
/// ## 归档不是「另一种删除」
///
/// §1.1 把两者做成**两个正交的时间戳列**，理由是重复任务的 `status`
/// 恒为 `pending`：归档若是一个状态值，重复任务就永远归不了档。
/// 所以这里也验一条「重复任务归得了档」——
/// 那正是当初否掉「归档是状态」那条路的原因。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/features/archive/presentation/archive_page.dart';
import 'package:planning_assistant/features/settings/presentation/settings_page.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/task/application/recurrence_draft.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';
import 'package:planning_assistant/features/views/task_list/presentation/occurrence_actions_sheet.dart';

import '../support/app_harness.dart';

Future<Harness> _pumpApp(WidgetTester tester) async {
  await setScreenSize(tester, const Size(390, 844));
  final harness = appHarness();
  await tester.pumpWidget(
    ProviderScope(overrides: harness.overrides, child: PlanningAssistantApp()),
  );
  await tester.pumpAndSettle();
  return harness;
}

Future<void> _createTask(
  WidgetTester tester,
  String title, {
  bool recurring = false,
}) async {
  await tester.tap(find.byKey(AppShell.fabKey));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), title);
  await tester.pump();
  if (recurring) {
    await tapVisible(tester, TaskEditorPage.recurrenceSwitchKey);
    await tapVisible(
      tester,
      TaskEditorPage.frequencyKey(RecurrenceFrequency.weekly),
    );
  }
  await tapVisible(tester, TaskEditorPage.saveButtonKey);
}

Future<void> _archiveFromEditor(WidgetTester tester) async {
  await tester.tap(find.byType(TaskCard).first);
  await tester.pumpAndSettle();
  // 重复任务点卡片先弹「改哪一次」——归档改的是**整条任务**，
  // 所以走「编辑整条重复任务」那条。不重复的直接就是编辑页。
  if (find.byKey(OccurrenceSheetKeys.editSeries).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(OccurrenceSheetKeys.editSeries));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(TaskEditorPage.archiveButtonKey));
  await tester.pumpAndSettle();
}

Future<void> _openArchive(WidgetTester tester) async {
  await tester.tap(find.byKey(AppShell.settingsKey));
  await tester.pumpAndSettle();
  await tapVisible(tester, SettingsPage.archiveEntryKey);
}

void main() {
  testAppWidgets('归档之后从列表里消失，但没被删', (tester) async {
    final harness = await _pumpApp(tester);
    await _createTask(tester, '去年的项目');
    await _archiveFromEditor(tester);

    expect(find.byType(TaskCard), findsNothing);

    final row = (await harness.db.select(harness.db.tasks).get()).single;
    expect(row.archivedAt, isNotNull);
    expect(row.deletedAt, isNull, reason: '归档把它删了 —— 那是另一件事');
  });

  testAppWidgets('归档会记下归档前的状态，取消归档时还原', (tester) async {
    // §1.1：归档时把当时的 status 快照到 statusBeforeArchive。
    // 不记的话，一条已完成的任务取消归档之后会变回待办。
    final harness = await _pumpApp(tester);
    await _createTask(tester, '写总结');
    await tester.tap(find.byKey(TaskCard.doneButtonKey));
    await tester.pumpAndSettle();

    await _archiveFromEditor(tester);
    final archived = (await harness.db.select(harness.db.tasks).get()).single;
    expect(archived.statusBeforeArchive, 'done');

    await _openArchive(tester);
    await tester.tap(find.text('取消归档'));
    await tester.pumpAndSettle();

    final back = (await harness.db.select(harness.db.tasks).get()).single;
    expect(back.archivedAt, isNull);
    expect(back.statusBeforeArchive, isNull, reason: '取消归档后该清掉快照');
    expect(back.status, 'done', reason: '取消归档把「已完成」弄丢了');
  });

  testAppWidgets('重复任务也归得了档 —— 这正是「归档不是状态」的理由', (tester) async {
    // 重复任务的 status 恒为 pending（data-model §4.3）。
    // 归档若是一个 status 值，这条任务就永远归不了档。
    final harness = await _pumpApp(tester);
    await _createTask(tester, '周报', recurring: true);
    await _archiveFromEditor(tester);

    final row = (await harness.db.select(harness.db.tasks).get()).single;
    expect(row.archivedAt, isNotNull);
    expect(row.status, 'pending', reason: '重复任务的 status 必须恒为 pending');
    expect(find.byType(TaskCard), findsNothing);
  });

  testAppWidgets('归档给一条撤销', (tester) async {
    final harness = await _pumpApp(tester);
    await _createTask(tester, '去年的项目');
    await _archiveFromEditor(tester);

    expect(find.text('撤销'), findsOneWidget);
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();

    expect(
      (await harness.db.select(harness.db.tasks).get()).single.archivedAt,
      isNull,
    );
    expect(find.byType(TaskCard), findsOneWidget);
  });

  testAppWidgets('归档列表：没有时是空态；归档的在里面，回收站里没有', (tester) async {
    // 两个列表**不能互相串**：回收站里混进归档任务是 §1.1 那三条
    // 可见性谓词要防的第一件事。
    await _pumpApp(tester);
    await _openArchive(tester);
    expect(find.byKey(ArchivePage.emptyKey), findsOneWidget);

    Navigator.of(tester.element(find.byType(ArchivePage))).pop();
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(SettingsPage))).pop();
    await tester.pumpAndSettle();

    await _createTask(tester, '去年的项目');
    await _archiveFromEditor(tester);

    await _openArchive(tester);
    expect(find.text('去年的项目'), findsOneWidget);

    // 回收站里不该有它。
    Navigator.of(tester.element(find.byType(ArchivePage))).pop();
    await tester.pumpAndSettle();
    await tapVisible(tester, SettingsPage.trashEntryKey);
    expect(find.text('去年的项目'), findsNothing);
  });

  testAppWidgets('新建页上没有归档入口', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(AppShell.fabKey));
    await tester.pumpAndSettle();
    expect(find.byKey(TaskEditorPage.archiveButtonKey), findsNothing);
  });
}

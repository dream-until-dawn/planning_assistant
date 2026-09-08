/// 「本次及以后」（FR-TASK-06）。
///
/// 验收原话：**原规则在分割点截断，新规则从分割点起生效，
/// 历史记录保持不变**。第三句是这套做法（data-model §4.4「不改历史，
/// 而是分裂」）唯一的理由 —— 若历史会被改掉，那还不如直接改整条。
/// 所以这里每一条都盯着它。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';
import 'package:planning_assistant/features/views/task_list/presentation/occurrence_actions_sheet.dart';
import 'package:planning_assistant/features/views/task_list/presentation/task_list_page.dart';

import '../support/app_harness.dart';

Future<Harness> _pumpDaily(WidgetTester tester) async {
  await setScreenSize(tester, const Size(390, 844));
  final harness = appHarness();
  await tester.pumpWidget(
    ProviderScope(overrides: harness.overrides, child: PlanningAssistantApp()),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(AppShell.fabKey));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '晨会');
  await tester.pump();
  await tapVisible(tester, TaskEditorPage.recurrenceSwitchKey);
  await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
  await tester.pumpAndSettle();
  return harness;
}

/// 打开「明天」那一行的动作弹层 —— 分割点故意**不选第一次**，
/// 否则走的是「等同于改整条」那条特殊分支，验不到分裂。
Future<void> _openTomorrowSheet(WidgetTester tester) async {
  final header = find.byKey(TaskListPage.groupHeaderKey('tomorrow'));
  await tester.ensureVisible(header);
  await tester.pumpAndSettle();
  // 「明天」组里就一张卡片，取标题在 header 之下的第一张。
  final headerY = tester.getCenter(header).dy;
  final cards = find.byType(TaskCard);
  for (var i = 0; i < cards.evaluate().length; i++) {
    if (tester.getCenter(cards.at(i)).dy > headerY) {
      await tester.tap(cards.at(i));
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('「明天」组下面没有卡片');
}

void main() {
  testAppWidgets('弹层里有「本次及以后」，且说明不改历史', (tester) async {
    // 不说的话，用户会担心之前做过的记录被一起改掉 ——
    // 而那正是这套做法要保住的东西。
    await _pumpDaily(tester);
    await _openTomorrowSheet(tester);

    expect(find.byKey(OccurrenceSheetKeys.editFromHere), findsOneWidget);
    expect(find.textContaining('之前的不受影响'), findsOneWidget);
  });

  testAppWidgets('改标题 → 原任务截断，新任务从分割点起', (tester) async {
    final harness = await _pumpDaily(tester);
    final original = (await harness.db.select(harness.db.tasks).get()).single;

    await _openTomorrowSheet(tester);
    await tester.tap(find.byKey(OccurrenceSheetKeys.editFromHere));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '站会');
    await tester.pump();
    await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
    await tester.pumpAndSettle();

    final rows = await harness.db.select(harness.db.tasks).get();
    expect(rows, hasLength(2), reason: '分裂应当产出两条任务');

    final old = rows.firstWhere((t) => t.id == original.id);
    final fresh = rows.firstWhere((t) => t.id != original.id);

    // 1) 原规则截断了。
    expect(old.title, '晨会', reason: '历史那一半的标题不该被改');
    expect(old.recurrenceRule, contains('UNTIL='), reason: '原规则要在分割点之前截断');

    // 2) 新任务从分割点起，带着新内容与溯源。
    expect(fresh.title, '站会');
    expect(fresh.planDate, isNotNull);
    expect(fresh.splitFromTaskId, original.id, reason: '溯源要记下来，将来「合并回去」与同步都靠它');
    expect(fresh.recurrenceRule, isNot(contains('UNTIL=')));
  });

  testAppWidgets('**历史记录保持不变**：分割点之前勾过的那次还在', (tester) async {
    // 这是验收里的第三句，也是「分裂而不是就地改」的唯一理由。
    final harness = await _pumpDaily(tester);

    // 先把「今天」那一次勾完成 —— 它在分割点之前。
    await tester.tap(find.byKey(TaskCard.doneButtonKey).first);
    await tester.pumpAndSettle();
    final before = await harness.db
        .select(harness.db.occurrenceOverrides)
        .get();
    expect(before, hasLength(1), reason: '前提：今天那次已标记完成');

    await _openTomorrowSheet(tester);
    await tester.tap(find.byKey(OccurrenceSheetKeys.editFromHere));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '站会');
    await tester.pump();
    await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
    await tester.pumpAndSettle();

    final after = await harness.db.select(harness.db.occurrenceOverrides).get();
    expect(
      after.map((o) => (o.taskId, o.occurrenceKey, o.status)),
      before.map((o) => (o.taskId, o.occurrenceKey, o.status)),
      reason: '分裂不该动到分割点之前的完成记录',
    );
  });

  testAppWidgets('分割点那一次归新任务，不会两边各出现一次', (tester) async {
    // 原规则若截到分割点当天，那一次会同时属于两条任务 ——
    // 列表里同一天出现两行一模一样的东西。
    final harness = await _pumpDaily(tester);

    await _openTomorrowSheet(tester);
    await tester.tap(find.byKey(OccurrenceSheetKeys.editFromHere));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '站会');
    await tester.pump();
    await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
    await tester.pumpAndSettle();

    // 「明天」组里应当只有一行，而且是新标题。
    final header = find.byKey(TaskListPage.groupHeaderKey('tomorrow'));
    await tester.ensureVisible(header);
    await tester.pumpAndSettle();
    final count = int.parse(
      (tester.widget(
        find.descendant(of: header, matching: find.byType(Text)).last,
      ) as Text).data!,
    );
    expect(count, 1, reason: '分割点那一天只该有一行');

    expect(await harness.db.select(harness.db.tasks).get(), hasLength(2));
  });

  testAppWidgets('分割点正好是第一次 → 不分裂，直接改整条', (tester) async {
    // 那样截断出来的原任务一次都不发生，会留下一条死任务。
    final harness = await _pumpDaily(tester);

    // 「今天」就是第一次。
    await tester.tap(find.byType(TaskCard).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(OccurrenceSheetKeys.editFromHere));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '站会');
    await tester.pump();
    await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
    await tester.pumpAndSettle();

    final rows = await harness.db.select(harness.db.tasks).get();
    expect(rows, hasLength(1), reason: '不该多出一条一次都不发生的死任务');
    expect(rows.single.title, '站会');
    expect(rows.single.recurrenceRule, isNot(contains('UNTIL=')));
  });

  testAppWidgets('对照组：不重复的任务没有「本次及以后」', (tester) async {
    // 它只有一次，「本次及以后」与「改整条」是同一件事，
    // 摆出来是个多余的选择题。
    await setScreenSize(tester, const Size(390, 844));
    final harness = appHarness();
    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides,
        child: PlanningAssistantApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppShell.fabKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '买菜');
    await tester.pump();
    await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TaskCard).first);
    await tester.pumpAndSettle();
    // 直接进的是编辑页，根本没有弹层。
    expect(find.byKey(OccurrenceSheetKeys.editFromHere), findsNothing);
    expect(find.text('编辑任务'), findsOneWidget);
  });
}

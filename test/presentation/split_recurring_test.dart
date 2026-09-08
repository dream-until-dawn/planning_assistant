/// 「本次及以后」（FR-TASK-06）。
///
/// 验收原话：**原规则在分割点截断，新规则从分割点起生效，
/// 历史记录保持不变**。第三句是这套做法（data-model §4.4「不改历史，
/// 而是分裂」）唯一的理由 —— 若历史会被改掉，那还不如直接改整条。
/// 所以这里每一条都盯着它。
@TestOn('vm')
library;

import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/data/database/app_database.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';
import 'package:planning_assistant/features/views/task_list/presentation/occurrence_actions_sheet.dart';
import 'package:planning_assistant/features/views/task_list/presentation/task_list_page.dart';

import '../support/app_harness.dart';

/// 装的时钟是 2026-09-07 11:00（上海），所以「今天」是 9/7。
const _todayDate = PlanDate(2026, 9, 7);
const _start = PlanDate(2026, 8, 28);

/// 建一条**从十天前开始**的每日任务。
///
/// 起点故意放在过去。放今天的话，列表里唯一那一行就是规则的
/// **第一次** —— 而分割点是第一次时走的是「等同于改整条」那条特殊分支
/// （见 dispatcher），根本验不到分裂。
///
/// 现实里也正是这样：会想「从现在起改成……」的，都是已经跑了一阵子的
/// 任务；刚建好就要改的，直接改整条就是了。
Future<Harness> _pumpEstablishedDaily(WidgetTester tester) async {
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

  // 把起点挪到十天前，并把那十天都标成已完成 —— 否则它们会以逾期的
  // 身份堆在列表最上面，遮住要点的那一行。
  final id = (await harness.db.select(harness.db.tasks).get()).single.id;
  await harness.db.customUpdate(
    'UPDATE tasks SET plan_date = ? WHERE id = ?',
    variables: [Variable<String>('$_start'), Variable<String>(id)],
    updates: {harness.db.tasks},
  );
  for (var i = 1; i <= 10; i++) {
    final day = _todayDate.addDays(-i);
    await harness.db
        .into(harness.db.occurrenceOverrides)
        .insert(
          OccurrenceOverridesCompanion.insert(
            id: '$id#$day',
            taskId: id,
            occurrenceKey: '$day',
            action: 'modify',
            status: const Value('done'),
            updatedAt: const Value(0),
            lastWriterId: const Value('test'),
          ),
        );
  }
  await tester.pumpAndSettle();
  return harness;
}

/// 打开列表里那唯一一行（= 今天这一次）的动作弹层。
Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byType(TaskCard).first);
  await tester.pumpAndSettle();
}

void main() {
  testAppWidgets('弹层里有「本次及以后」，且说明不改历史', (tester) async {
    // 不说的话，用户会担心之前做过的记录被一起改掉 ——
    // 而那正是这套做法要保住的东西。
    await _pumpEstablishedDaily(tester);
    await _openSheet(tester);

    expect(find.byKey(OccurrenceSheetKeys.editFromHere), findsOneWidget);
    expect(find.textContaining('之前的不受影响'), findsOneWidget);
  });

  testAppWidgets('改标题 → 原任务截断，新任务从分割点起', (tester) async {
    final harness = await _pumpEstablishedDaily(tester);
    final original = (await harness.db.select(harness.db.tasks).get()).single;

    await _openSheet(tester);
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
    final harness = await _pumpEstablishedDaily(tester);

    // 夹具里过去十天都已标记完成 —— 它们全在分割点之前。
    final before = await harness.db
        .select(harness.db.occurrenceOverrides)
        .get();
    expect(before, hasLength(10), reason: '前提：分割点之前有十条完成记录');

    await _openSheet(tester);
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
    final harness = await _pumpEstablishedDaily(tester);

    await _openSheet(tester);
    await tester.tap(find.byKey(OccurrenceSheetKeys.editFromHere));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '站会');
    await tester.pump();
    await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
    await tester.pumpAndSettle();

    // 分割点那一天（今天）只该有一行。
    final header = find.byKey(TaskListPage.groupHeaderKey('today'));
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
    //
    // **这条要用刚建好的任务**：起点就是今天，于是列表里唯一那一行
    // 正是规则的第一次。上面几条用的是「已经跑了十天」的夹具，
    // 那里今天不是第一次，走的是真分裂。
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
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '晨会');
    await tester.pump();
    await tapVisible(tester, TaskEditorPage.recurrenceSwitchKey);
    await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
    await tester.pumpAndSettle();

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

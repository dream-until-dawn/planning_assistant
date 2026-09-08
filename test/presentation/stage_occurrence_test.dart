/// 重复的阶段事项：每一次各记各的进度（FR-TASK-07）。
///
/// ## 用户会怎么撞见它
///
/// 「每周三·健身」拆成热身 / 主训 / 拉伸。这周三做完热身，勾掉它 ——
/// 在这个提交之前，**下周三打开也是「1/3」**，因为阶段状态只有
/// `Stage.status` 一份，整条任务共用。
///
/// 表 `stage_occurrence_states` 从 M1 就在库里，导出也带着它，
/// 而领域层以上一片空白。又是「模型有旋钮、界面够不着」——
/// 这次连领域层都没接。
///
/// 这里走真库、真路由，从建任务一路验到卡片上的数字。
/// 纯函数那一侧在 `test/domain/stage_occurrence_state_test.dart`。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/task/application/recurrence_draft.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';
import 'package:planning_assistant/features/views/calendar/presentation/calendar_page.dart';
import 'package:planning_assistant/features/views/shared/application/view_kind.dart';
import 'package:planning_assistant/features/views/shared/application/view_shared_state.dart';
import 'package:planning_assistant/features/views/task_list/presentation/occurrence_actions_sheet.dart';

import '../support/app_harness.dart';

/// 夹具的今天与明天。
const _today = PlanDate(2026, 9, 7);
const _tomorrow = PlanDate(2026, 9, 8);

Future<Harness> _pumpApp(WidgetTester tester) async {
  await setScreenSize(tester, const Size(390, 844));
  final harness = appHarness();
  await tester.pumpWidget(
    ProviderScope(overrides: harness.overrides, child: PlanningAssistantApp()),
  );
  await tester.pumpAndSettle();
  return harness;
}

/// 建一条每天重复、带三个阶段的任务。
///
/// **用「每天」而不是「每周」**：要连着两天各看一次，
/// 而每周的下一次在七天后。
Future<void> _createRecurringStaged(WidgetTester tester) async {
  await tester.tap(find.byKey(AppShell.fabKey));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '健身');
  await tester.pump();

  for (final name in ['热身', '主训', '拉伸']) {
    await tapVisible(tester, TaskEditorPage.addStageKey);
    final fields = find.descendant(
      of: find.byKey(TaskEditorPage.stageSectionKey),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.last, name);
    await tester.pump();
  }

  await tapVisible(tester, TaskEditorPage.recurrenceSwitchKey);
  await tapVisible(
    tester,
    TaskEditorPage.frequencyKey(RecurrenceFrequency.daily),
  );
  await tapVisible(tester, TaskEditorPage.saveButtonKey);
}

/// 切到日历，并把聚焦日挪到 [date]。
///
/// **不能靠列表看两次发生**：列表对重复任务只展开「逾期的 + 下一次」
/// （`expandForList` 的注释写着理由），一条每天重复的任务在那儿
/// 永远只有一行。要连着看两天，得用对着某一天的视图。
Future<void> _goToDay(WidgetTester tester, PlanDate date) async {
  if (find.byKey(CalendarPage.gridKey).evaluate().isEmpty) {
    await tapVisible(tester, AppShell.viewTabKey(ViewKind.calendar));
  }
  ProviderScope.containerOf(tester.element(find.byType(AppShell)))
      .read(viewSharedStateProvider.notifier)
      .focusDate(date);
  await tester.pumpAndSettle();
}

/// 打开当天那一行的动作弹层。
Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byType(TaskCard).first);
  await tester.pumpAndSettle();
  expect(find.byKey(OccurrenceSheetKeys.sheet), findsOneWidget);
}

Future<void> _closeSheet(WidgetTester tester) async {
  Navigator.of(tester.element(find.byKey(OccurrenceSheetKeys.sheet))).pop();
  await tester.pumpAndSettle();
}

/// 弹层里勾掉某一步。
Future<void> _tick(WidgetTester tester, String stageId) async {
  await tapVisible(tester, OccurrenceSheetKeys.stage(stageId));
  await tester.pumpAndSettle();
}

/// 库里那三个阶段，按顺序。
Future<List<String>> _stageIds(Harness harness) async {
  final rows = await harness.db.select(harness.db.stages).get();
  rows.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  return rows.map((r) => r.id).toList();
}

void main() {
  testAppWidgets('**这一次勾了，另一次还是没勾**（R-50/R-51）', (tester) async {
    final harness = await _pumpApp(tester);
    await _createRecurringStaged(tester);
    final stages = await _stageIds(harness);

    await _goToDay(tester, _today);
    await _openSheet(tester);
    await _tick(tester, stages[1]); // 主训
    await _closeSheet(tester);

    // 今天这一次：主训已勾。
    await _openSheet(tester);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(OccurrenceSheetKeys.stage(stages[1])),
          )
          .value,
      isTrue,
    );
    await _closeSheet(tester);

    // 明天那一次：一步都没做。
    await _goToDay(tester, _tomorrow);
    await _openSheet(tester);
    for (final id in stages) {
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(OccurrenceSheetKeys.stage(id)))
            .value,
        isFalse,
        reason: '另一次跟着变完成了 —— 阶段状态还是整条任务共用的那一份',
      );
    }
    await _closeSheet(tester);
  });

  testAppWidgets('卡片上的进度也按这一次算', (tester) async {
    // 弹层对了而卡片没对的话，用户看到的是「列表说 0/3，点进去说 1/3」。
    final harness = await _pumpApp(tester);
    await _createRecurringStaged(tester);
    final stages = await _stageIds(harness);

    await _goToDay(tester, _today);
    expect(find.textContaining('0/3'), findsOneWidget);

    await _openSheet(tester);
    await _tick(tester, stages[0]);
    await _closeSheet(tester);

    expect(find.textContaining('1/3'), findsOneWidget, reason: '今天这一次该是 1/3');

    await _goToDay(tester, _tomorrow);
    expect(find.textContaining('0/3'), findsOneWidget, reason: '明天那一次仍是 0/3');
  });

  testAppWidgets('落库的是「这一步·这一次」，不是阶段本身', (tester) async {
    // 写进 `stages.status` 的实现在这里露馅：那一份是整条任务共用的。
    final harness = await _pumpApp(tester);
    await _createRecurringStaged(tester);
    final stages = await _stageIds(harness);

    await _openSheet(tester);
    await _tick(tester, stages[2]);
    await _closeSheet(tester);

    final states = await harness.db
        .select(harness.db.stageOccurrenceStates)
        .get();
    expect(states, hasLength(1));
    expect(states.single.stageId, stages[2]);
    expect(states.single.status, 'done');
    expect(states.single.completedAt, isNotNull, reason: '标了完成却没有完成时刻');

    final stageRows = await harness.db.select(harness.db.stages).get();
    expect(
      stageRows.where((s) => s.status == 'done'),
      isEmpty,
      reason: '写到 stages.status 上了 —— 那一份是每一次共用的',
    );
  });

  testAppWidgets('再点一下取消，完成时刻一并清掉', (tester) async {
    // 与 `applyStatusChange` 同一条不变量：completedAt 与 status 同进同退。
    // 不清的话，下次它显示成「未完成，但完成于上周三」。
    final harness = await _pumpApp(tester);
    await _createRecurringStaged(tester);
    final stages = await _stageIds(harness);

    await _openSheet(tester);
    await _tick(tester, stages[0]);
    await _tick(tester, stages[0]);
    await _closeSheet(tester);

    final states = await harness.db
        .select(harness.db.stageOccurrenceStates)
        .get();
    expect(states, hasLength(1), reason: '连点两下攒出了两行互相矛盾的状态');
    expect(states.single.status, 'pending');
    expect(states.single.completedAt, isNull);
  });

  testAppWidgets('对照组：不重复的阶段任务不弹这个弹层', (tester) async {
    // 它没有「某一次」，阶段状态就在阶段自己身上 ——
    // 勾选仍在编辑器里（`stage_done_test.dart` 验那条路）。
    await _pumpApp(tester);
    await tester.tap(find.byKey(AppShell.fabKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '搬家');
    await tester.pump();
    await tapVisible(tester, TaskEditorPage.addStageKey);
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    await tester.tap(find.byType(TaskCard));
    await tester.pumpAndSettle();
    expect(find.byKey(OccurrenceSheetKeys.sheet), findsNothing);
    expect(find.byKey(TaskEditorPage.titleFieldKey), findsOneWidget);
  });
}

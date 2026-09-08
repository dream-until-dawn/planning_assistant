/// 跳过某一次，以及**怎么反悔**（FR-TASK-05）。
///
/// 验收原话是「跳过的次数不出现在任何视图」—— 于是也就没有一行可以让
/// 用户撤回。M2 里已经栽过一次同样的形状（「到某天为止」选了却没地方
/// 选日期，保存永久灰着），所以这里把**反悔的路**当成功能的一部分来验：
/// 筛选条勾上「已跳过」→ 那些次现身 → 从弹层里恢复。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';
import 'package:planning_assistant/features/views/shared/presentation/filter_bar.dart';
import 'package:planning_assistant/features/views/task_list/presentation/occurrence_actions_sheet.dart';
import 'package:planning_assistant/features/views/task_list/presentation/task_list_page.dart';

import '../support/app_harness.dart';

Future<Harness> _pumpWithDaily(WidgetTester tester) async {
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

/// **数「今天」那一组在不在**，不数渲染出来的卡片。
///
/// `ListView` 是惰性的：屏幕上永远只有七八张卡片，删掉一行会有下一行
/// 补上来，数量一点不变 —— 用卡片数当判据，跳过成功与完全没生效
/// 看起来一模一样。第一版就是这么写的，三条用例齐刷刷报
/// 「Expected 6, Actual 7」。
bool _hasTodayGroup(WidgetTester tester) =>
    find.byKey(TaskListPage.groupHeaderKey('today')).evaluate().isNotEmpty;

/// 「今天」组里的行数。组不在时返回 0。
int _todayCount(WidgetTester tester) {
  if (!_hasTodayGroup(tester)) return 0;
  final header = find.descendant(
    of: find.byKey(TaskListPage.groupHeaderKey('today')),
    matching: find.byType(Text),
  );
  // 标题一个 Text，条数一个 Text。
  return int.parse((tester.widget(header.last) as Text).data!);
}

/// 打开第一行的动作弹层。
Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byType(TaskCard).first);
  await tester.pumpAndSettle();
  expect(find.byKey(OccurrenceSheetKeys.sheet), findsOneWidget);
}

void main() {
  testAppWidgets('点一行能打开弹层，而且说清是哪一次', (tester) async {
    // 不写日期的话，「跳过」看着像是要停掉整条规则。
    await _pumpWithDaily(tester);
    await _openSheet(tester);

    expect(find.text('晨会'), findsWidgets);
    expect(find.textContaining('这一次'), findsWidgets);
  });

  testAppWidgets('跳过之后那一行消失，落的是 action=skip', (tester) async {
    final harness = await _pumpWithDaily(tester);
    expect(_todayCount(tester), 1, reason: '前提：今天有一次');

    await _openSheet(tester);
    await tester.tap(find.byKey(OccurrenceSheetKeys.skip));
    await tester.pumpAndSettle();

    expect(
      _hasTodayGroup(tester),
      isFalse,
      reason: '跳过的那一次不该出现在列表里（FR-TASK-05 验收）',
    );

    final row =
        (await harness.db.select(harness.db.occurrenceOverrides).get()).single;
    expect(
      row.action,
      'skip',
      reason: '跳过是 action，不是 status —— 写成 status=skipped 的话那一行还在',
    );
  });

  testAppWidgets('**跳过之后找得回来**：勾「已跳过」→ 它现身 → 恢复', (tester) async {
    // 这条是整个功能的一半。没有它，跳过就是一条走进去出不来的路。
    final harness = await _pumpWithDaily(tester);

    await _openSheet(tester);
    await tester.tap(find.byKey(OccurrenceSheetKeys.skip));
    await tester.pumpAndSettle();
    expect(_hasTodayGroup(tester), isFalse);

    // 顶部筛选条勾上「已跳过」。
    await tapVisible(tester, FilterBar.statusKey(TaskStatus.skipped));
    expect(find.byType(TaskCard), findsOneWidget, reason: '筛「已跳过」时只该剩被跳过的那一次');

    // 从弹层里恢复。
    await _openSheet(tester);
    expect(
      find.byKey(OccurrenceSheetKeys.unskip),
      findsOneWidget,
      reason: '已跳过的那一次，弹层里给的是「恢复」而不是「跳过」',
    );
    await tester.tap(find.byKey(OccurrenceSheetKeys.unskip));
    await tester.pumpAndSettle();

    // 例外被整条删掉 —— 不是把 action 改回 modify 留一条空壳。
    final live = (await harness.db.select(harness.db.occurrenceOverrides).get())
        .where((o) => o.deletedAt == null);
    expect(live, isEmpty);

    // 取消筛选，那一次回到列表里。
    await tapVisible(tester, FilterBar.statusKey(TaskStatus.skipped));
    expect(_todayCount(tester), 1, reason: '恢复之后「今天」那一次该回来');
  });

  testAppWidgets('跳过只影响那一次', (tester) async {
    // 影响全部的话，「跳过今天」等于把整条规则停了。
    await _pumpWithDaily(tester);
    // 前提：这条规则本来就展开成很多行。
    expect(find.byKey(TaskListPage.groupHeaderKey('tomorrow')), findsOneWidget);

    await _openSheet(tester);
    await tester.tap(find.byKey(OccurrenceSheetKeys.skip));
    await tester.pumpAndSettle();

    expect(_hasTodayGroup(tester), isFalse);
    expect(
      find.byKey(TaskListPage.groupHeaderKey('tomorrow')),
      findsOneWidget,
      reason: '只该少掉被跳过的那一次 —— 明天那次还得在',
    );
  });

  testAppWidgets('弹层里先说清怎么反悔，再让他点跳过', (tester) async {
    // 「点下去之后还能不能回来」是决定要不要点的关键信息，
    // 事后再告诉他就晚了。
    await _pumpWithDaily(tester);
    await _openSheet(tester);
    expect(find.byKey(OccurrenceSheetKeys.hint), findsOneWidget);
    expect(find.textContaining('已跳过'), findsWidgets);
  });

  testAppWidgets('对照组：不重复的任务点了不弹', (tester) async {
    // 弹一个只有标题、没有任何动作的空壳，比不弹更让人以为坏了。
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
    expect(find.byKey(OccurrenceSheetKeys.sheet), findsNothing);
  });
}

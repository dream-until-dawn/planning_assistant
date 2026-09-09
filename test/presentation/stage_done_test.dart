/// 阶段的完成状态：勾得上、存得住、不会被下一次保存清掉。
///
/// ## 这一族债的第六次
///
/// `Stage.status` 与 `StageSpec.status` 一直都在，甘特图还按它画进度 ——
/// 而**界面上没有任何地方能勾**，`StageDraft` 里甚至没有这个字段。
///
/// 后果比「够不着」还重一层：编辑一条有已完成阶段的任务、什么都不改
/// 直接保存，`ReplaceStagesCommand` 会把整表换成默认的 `pending`，
/// **用户的进度被静默清空**。而界面上看不出任何异常 —— 保存成功、
/// 回到列表，卡片上的「阶段 1/3」变成「阶段 0/3」。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';

import '../support/app_harness.dart';

Future<Harness> _pumpApp(WidgetTester tester, {bool advancing = false}) async {
  await setScreenSize(tester, const Size(390, 844));
  // 「完成时刻会不会漂移」那条要**时间真的往前走** —— 钉死的时钟下，
  // 「保留原值」与「一律盖成现在」给出同一个值，测试永远绿。
  final harness = appHarness(advancingClock: advancing);
  await tester.pumpWidget(
    ProviderScope(overrides: harness.overrides, child: PlanningAssistantApp()),
  );
  await tester.pumpAndSettle();
  return harness;
}

/// 建一条带 [count] 个阶段的任务，回到列表。
Future<void> _createStaged(WidgetTester tester, int count) async {
  await tester.tap(find.byKey(AppShell.fabKey));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '搬家');
  await tester.pump();
  for (var i = 0; i < count; i++) {
    await tapVisible(tester, TaskEditorPage.addStageKey);
    final fields = find.descendant(
      of: find.byKey(TaskEditorPage.stageSectionKey),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.last, '第 ${i + 1} 步');
    await tester.pump();
  }
  await tapVisible(tester, TaskEditorPage.saveButtonKey);
}

/// 重新打开那条任务。
Future<void> _reopen(WidgetTester tester) async {
  await tester.tap(find.byType(TaskCard));
  await tester.pumpAndSettle();
}

void main() {
  testAppWidgets('重新打开时，阶段标题要显示出来（不是空白行）', (tester) async {
    // **这是个真发生过的缺陷。** 阶段那一行的 `TextField` 没有
    // controller —— 页面开头那段注释早就写明「编辑模式必须有」
    // （标题与备注因此各有一个），阶段漏了。
    // 于是打开一条已有的阶段事项，几行阶段全是空的，像内容丢了。
    //
    // 一直没被发现，是因为勾选/排序/时间那几条用例都只按 Key 找控件，
    // **没有一条看过里面的字**。
    await _pumpApp(tester);
    await _createStaged(tester, 2);
    await _reopen(tester);

    await tester.scrollUntilVisible(
      find.byKey(TaskEditorPage.stageSectionKey),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('第 1 步'), findsOneWidget);
    expect(find.text('第 2 步'), findsOneWidget);
  });

  testAppWidgets('勾一个阶段 → 落库 → 卡片上的进度跟着变', (tester) async {
    final harness = await _pumpApp(tester);
    await _createStaged(tester, 3);
    expect(find.textContaining('0/3'), findsOneWidget);

    await _reopen(tester);
    final stages = await harness.db.select(harness.db.stages).get();
    final second = stages.firstWhere((s) => s.orderIndex == 1);
    await tapVisible(tester, TaskEditorPage.stageDoneKey(second.id));
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    final after = await harness.db.select(harness.db.stages).get();
    expect(after.where((s) => s.status == 'done'), hasLength(1));
    expect(
      after.firstWhere((s) => s.id == second.id).completedAt,
      isNotNull,
      reason: '标了完成却没有完成时刻',
    );
    expect(find.textContaining('1/3'), findsOneWidget);
  });

  testAppWidgets('再存一次不会把已完成的阶段清回未完成', (tester) async {
    // 这是这条链路**最要紧**的一条。草稿不带 status 的话，
    // 「打开任务、什么都不改、保存」就会把进度清空 ——
    // 而界面上看不出任何异常。
    final harness = await _pumpApp(tester);
    await _createStaged(tester, 3);

    await _reopen(tester);
    final stages = await harness.db.select(harness.db.stages).get();
    await tapVisible(
      tester,
      TaskEditorPage.stageDoneKey(
        stages.firstWhere((s) => s.orderIndex == 0).id,
      ),
    );
    await tapVisible(tester, TaskEditorPage.saveButtonKey);
    expect(find.textContaining('1/3'), findsOneWidget);

    // 什么都不改，再存一次。
    await _reopen(tester);
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    final after = await harness.db.select(harness.db.stages).get();
    expect(
      after.where((s) => s.status == 'done'),
      hasLength(1),
      reason: '再存一次把完成状态清掉了 —— 用户的进度被静默清空',
    );
    expect(find.textContaining('1/3'), findsOneWidget);
  });

  testAppWidgets('已完成阶段的完成时刻不随每次保存漂移', (tester) async {
    // 一律盖成「现在」的话，改一下标题，上周做完的事就显示成刚做完。
    // 没人会去查这个字段，但它是导出与将来同步时的真实数据。
    final harness = await _pumpApp(tester, advancing: true);
    await _createStaged(tester, 2);

    await _reopen(tester);
    final stages = await harness.db.select(harness.db.stages).get();
    final first = stages.firstWhere((s) => s.orderIndex == 0);
    await tapVisible(tester, TaskEditorPage.stageDoneKey(first.id));
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    final stamped = (await harness.db.select(harness.db.stages).get())
        .firstWhere((s) => s.id == first.id)
        .completedAt;

    // 改个标题再存 —— 完成时刻应当原封不动。
    await _reopen(tester);
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '搬家（改）');
    await tester.pump();
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    expect(
      (await harness.db.select(harness.db.stages).get())
          .firstWhere((s) => s.id == first.id)
          .completedAt,
      stamped,
      reason: '完成时刻被这次保存盖掉了',
    );
  });

  testAppWidgets('取消勾选之后完成时刻也要清掉', (tester) async {
    // 留着的话就是「未完成但有完成时间」，与领域里
    // 「status != done 却留着 completedAt」是同一类自相矛盾。
    final harness = await _pumpApp(tester);
    await _createStaged(tester, 2);

    await _reopen(tester);
    final id = (await harness.db.select(harness.db.stages).get())
        .firstWhere((s) => s.orderIndex == 0)
        .id;
    await tapVisible(tester, TaskEditorPage.stageDoneKey(id));
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    await _reopen(tester);
    await tapVisible(tester, TaskEditorPage.stageDoneKey(id));
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    final row = (await harness.db.select(harness.db.stages).get()).firstWhere(
      (s) => s.id == id,
    );
    expect(row.status, 'pending');
    expect(row.completedAt, isNull);
  });
}

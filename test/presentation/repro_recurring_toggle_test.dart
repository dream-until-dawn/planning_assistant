/// 复现用户报的那条：**重复任务取消完成之后再也标不了完成**。
///
/// 原话：
///
/// > 有个每 2 日重复的任务。我完成今天 → 出现后天的（对）；
/// > 我再完成后天 → 出现大大后天的（对）。
/// > 但我取消完成大大后天和后天的后，今天的取消完成后就**无法再次标注
/// > 完成**（点击无效果了）。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/features/task/application/recurrence_draft.dart';
import 'package:planning_assistant/features/task/application/task_shape.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';

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

/// 每 2 天重复，从今天起。
Future<void> _createEvery2Days(WidgetTester tester) async {
  await tapCreate(tester, TaskShape.recurringSingle);
  // **拨成全天。** 这一份的断言里写着 `2026-09-07=done` 这样的
  // 发生标识；定时任务的标识带时刻（`2026-09-07T12:00`），
  // 而那个时刻来自「下一个整点」—— 跟着跑测试的钟点走，不该进断言。
  // 全天让标识退回纯日期，与这一份要验的「取消完成之后还能再标完成」
  // 无关的变量就少一个。
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '吃药');
  await tester.pump();
  await tapVisible(tester, TaskEditorPage.allDaySwitchKey);
  await tapVisible(
    tester,
    TaskEditorPage.frequencyKey(RecurrenceFrequency.daily),
  );
  await tapVisible(
    tester,
    TaskEditorPage.stepperIncKey(TaskEditorPage.intervalStepper),
  );
  await tapVisible(tester, TaskEditorPage.saveButtonKey);
}

/// 勾第 [i] 张卡片的完成钮。
Future<void> _toggle(WidgetTester tester, int i) async {
  await tester.tap(find.byKey(TaskCard.doneButtonKey).at(i));
  await tester.pumpAndSettle();
}

/// 库里那条任务的例外，按 key 排序。
Future<List<String>> _overrides(Harness harness) async {
  final rows = await harness.db.select(harness.db.occurrenceOverrides).get()
    ..sort((a, b) => a.occurrenceKey.compareTo(b.occurrenceKey));
  return [
    for (final r in rows)
      if (r.deletedAt == null) '${r.occurrenceKey}=${r.status}',
  ];
}

void main() {
  testAppWidgets('取消完成之后还能再标完成', (tester) async {
    final harness = await _pumpApp(tester);
    await _createEvery2Days(tester);

    // 今天 9/7，每 2 天 → 9/7、9/9、9/11…
    expect(find.byType(TaskCard), findsWidgets);

    // ① 完成今天的。
    await _toggle(tester, 0);
    expect(await _overrides(harness), ['2026-09-07=done']);

    // ② 完成下一次。
    await _toggle(tester, 1);
    expect(await _overrides(harness), ['2026-09-07=done', '2026-09-09=done']);

    // ③ 倒着取消。
    await _toggle(tester, 1);
    expect(await _overrides(harness), ['2026-09-07=done']);
    await _toggle(tester, 0);
    expect(await _overrides(harness), isEmpty, reason: '取消完成该把例外删掉');

    // ④ **再标一次完成** —— 用户说这里点了没反应。
    await _toggle(tester, 0);
    expect(await _overrides(harness), [
      '2026-09-07=done',
    ], reason: '取消完成之后再点完成，没反应');
  });
}

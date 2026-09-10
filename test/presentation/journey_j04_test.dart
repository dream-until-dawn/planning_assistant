/// **J-04**（testing-strategy §8、roadmap M4 验收）。
///
/// | # | 旅程 |
/// |---|---|
/// | J-04 | 设提醒 → 改任务时间 → 提醒时刻跟着变 |
///
/// 与 J-01..J-03 一样走**真的链路**：真路由、真编辑器、真命令、真仓库、
/// 真 SQLite（内存）。唯一的替身是通知平台 —— 它是这一层的**出口**，
/// 记下「排了什么」正是这条旅程要看的东西。
///
/// ## 与 `reminder_editor_test` 里那条不是一回事
///
/// 那边改的是**提前量**（同一次发生，触发时刻前移）。这一条改的是
/// **任务时间**，于是「哪一次发生」本身变了 —— 通知的稳定标识里带着
/// `occurrenceKey`，key 变了就是另一条通知：旧的要取消、新的要排。
/// 走的是对账那条路，不是「同 key 改时刻」那条。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/features/task/application/task_shape.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';

import '../support/app_harness.dart';

/// 夹具时钟钉在 2026-09-07 03:00 UTC（上海 11:00）。
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

/// 续排是 fire-and-forget 的，`pumpAndSettle` 收不完。
Future<void> _settleSync(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

/// 左滑推迟一天（`behavior.swipeLeft` 的默认动作）。
Future<void> _postpone(WidgetTester tester) async {
  await tester.drag(find.byType(TaskCard).first, const Offset(-400, 0));
  await tester.pumpAndSettle();
}

void main() {
  testAppWidgets('J-04 设提醒 → 改任务时间 → 提醒时刻跟着变', (tester) async {
    final harness = await _pumpApp(tester);

    // ① 建一条今天的**定时**单事项，带一条提醒。
    //
    // **必须拨掉全天**（2026-09-10 起全天是默认）：全天任务的提醒基准是
    // 配置里那个绝对时刻（默认 09:00），而夹具的钟停在 11:00 ——
    // 今天那一条已经过去，`scheduled` 是空的，②③④ 全无从谈起。
    await tapCreate(tester, TaskShape.single);
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '开会');
    await tester.pump();
    await tapVisible(tester, TaskEditorPage.allDaySwitchKey);
    await tapVisible(tester, TaskEditorPage.addReminderKey);
    await tapVisible(tester, TaskEditorPage.saveButtonKey);
    await _settleSync(tester);

    final first = harness.notifications.scheduled.last;
    expect(first.trigger.date, _today, reason: '前提：先排在今天');

    // ② 把任务推迟一天 —— 这是「改任务时间」的一次真实手势。
    await _postpone(tester);
    await _settleSync(tester);

    final task = (await harness.db.select(harness.db.tasks).get()).single;
    expect(task.planDate, _tomorrow.toString(), reason: '前提：任务真的挪了');

    // ③ 提醒跟着挪到明天，**而且时刻不变**：提前量没动过。
    final latest = harness.notifications.scheduled.last;
    expect(latest.trigger.date, _tomorrow, reason: '任务挪了，提醒还留在今天');
    expect(
      latest.trigger.minuteOfDay,
      first.trigger.minuteOfDay,
      reason: '只挪了日期，钟点不该变 —— 提前量是同一个',
    );

    // ④ 旧的那条要取消掉。**这一步最容易漏**：只排新的不取消旧的，
    // 用户会在原来那个时刻先被提醒一次，而那件事已经不在那天了。
    expect(
      harness.notifications.cancelled,
      isNotEmpty,
      reason: '旧时刻那条没取消 —— 它照样会响',
    );
    expect(
      latest.key,
      isNot(first.key),
      reason: '发生变了，通知的身份也该变（key 里带着 occurrenceKey）',
    );
  });

  testAppWidgets('J-04 对照组：没设提醒的任务，推迟不产生任何排期', (tester) async {
    // 少了它，一个「凡是任务变动就排一条」的实现在上面那条里也能过。
    final harness = await _pumpApp(tester);

    await tapCreate(tester, TaskShape.single);
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '开会');
    await tester.pump();
    await tapVisible(tester, TaskEditorPage.saveButtonKey);
    await _settleSync(tester);

    await _postpone(tester);
    await _settleSync(tester);

    expect(harness.notifications.scheduled, isEmpty);
  });
}

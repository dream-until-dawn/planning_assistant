/// 提醒的状态卡片（FR-NOTI-04 的「UI 状态可查」那一半）。
///
/// ## 这一份守的是「不假装一切正常」
///
/// 两种降级都是**静默**的：没权限就一条不排，精确闹钟拿不到就降一档
/// 继续排。应用两种情况下看起来都正常，而用户只会觉得「这个应用的提醒
/// 不准」。notifications.md §4.4 写的是「明确告知」——
/// 没有这一份，那句话是纸上的。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/features/reminder/presentation/reminder_status_card.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';

import '../support/app_harness.dart';

Future<Harness> _pumpSettings(
  WidgetTester tester, {
  bool canNotify = true,
  bool canScheduleExact = true,
}) async {
  await setScreenSize(tester, const Size(390, 844));
  final harness = appHarness();
  harness.notifications
    ..canNotify = canNotify
    ..canScheduleExact = canScheduleExact;

  await tester.pumpWidget(
    ProviderScope(overrides: harness.overrides, child: PlanningAssistantApp()),
  );
  await tester.pumpAndSettle();
  // 冷启动那一轮续排要跑完，卡片才有东西可读。
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(AppShell.settingsKey));
  await tester.pumpAndSettle();
  return harness;
}

Future<void> _scrollToCard(WidgetTester tester) async {
  final finder = find.byKey(ReminderStatusCard.cardKey);
  if (finder.evaluate().isNotEmpty) return;
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  testAppWidgets('FR-NOTI-04 **没有权限 → 明说提醒不会响，并给一个去开权限的入口**', (tester) async {
    final harness = await _pumpSettings(tester, canNotify: false);
    await _scrollToCard(tester);

    expect(find.byKey(ReminderStatusCard.cardKey), findsOneWidget);
    expect(find.textContaining('不会响'), findsOneWidget);
    expect(find.byKey(ReminderStatusCard.grantKey), findsOneWidget);

    // 点它要真的去申请权限，不是画一个按钮摆着。
    // **走 `tapVisible`**：卡片在设置页很靠下，直接 `tap` 时它的中心点
    // 落在视口外，Flutter 只会警告一句、然后什么也没点到 ——
    // 而断言会红在「按钮点了没去申请权限」上，指向一个完全无关的方向。
    await tapVisible(tester, ReminderStatusCard.grantKey);
    expect(
      harness.notifications.permissionRequests,
      greaterThan(0),
      reason: '按钮点了没去申请权限',
    );
  });

  testAppWidgets('**精确闹钟不可用 → 明说可能晚几分钟**', (tester) async {
    final harness = await _pumpSettings(tester, canScheduleExact: false);
    await _scrollToCard(tester);

    expect(find.byKey(ReminderStatusCard.cardKey), findsOneWidget);
    expect(find.textContaining('晚几分钟'), findsOneWidget);

    await tapVisible(tester, ReminderStatusCard.exactKey);
    expect(
      harness.notifications.exactSettingsOpened,
      greaterThan(0),
      reason: '按钮点了没跳系统设置',
    );
  });

  testAppWidgets('**一切正常时不显示** —— 不说用户没问的事', (tester) async {
    // 对照组。少了它，一个「永远显示一张卡片」的实现在上面两条里都能过。
    await _pumpSettings(tester);
    expect(find.byKey(ReminderStatusCard.cardKey), findsNothing);
    expect(find.byKey(ReminderStatusCard.grantKey), findsNothing);
  });

  testAppWidgets('两种状态同时成立时，先说权限那条', (tester) async {
    // 没权限时**一条都没排**，「可能晚几分钟」在那种情况下是句废话 ——
    // 而且两张卡片摞在一起，用户不知道该先处理哪个。
    await _pumpSettings(tester, canNotify: false, canScheduleExact: false);
    await _scrollToCard(tester);

    expect(find.textContaining('不会响'), findsOneWidget);
    expect(find.textContaining('晚几分钟'), findsNothing);
  });

  testAppWidgets('给完权限后立刻补排，不用等下次进前台', (tester) async {
    final harness = await _pumpSettings(tester, canNotify: false);
    await _scrollToCard(tester);

    final before = harness.notifications.capabilityChecks;
    harness.notifications.canNotify = true;
    // **走 `tapVisible`**：卡片在设置页很靠下，直接 `tap` 时它的中心点
    // 落在视口外，Flutter 只会警告一句、然后什么也没点到 ——
    // 而断言会红在「按钮点了没去申请权限」上，指向一个完全无关的方向。
    await tapVisible(tester, ReminderStatusCard.grantKey);

    expect(
      harness.notifications.capabilityChecks,
      greaterThan(before),
      reason: '点完之后没有重新续排 —— 用户会以为刚才那一下没起作用',
    );
  });
}

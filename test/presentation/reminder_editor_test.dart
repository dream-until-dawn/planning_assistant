/// 编辑器里的提醒（FR-NOTI-01）。
///
/// ## 这一份把最后一段路补上
///
/// `reminder_sync_test` 证明了「库里有提醒 → 真的排出去」，但那份是
/// **直接往库里写**的 —— 界面上够不着的话，用户仍然设不了提醒。
/// 所以这里从**点「加个提醒」**开始，一路验到假通知平台收到那一条。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/features/task/application/task_shape.dart';
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

/// 同 `reminder_sync_test`：续排是 fire-and-forget 的，`pumpAndSettle` 不够。
///
/// **这里一度是三轮循环**，理由写的是「保存一次连发四条命令，一轮收不完」。
/// 那是假的 —— 三是试出来的，而真正没收敛的原因是续排在监听回调里同步读
/// 派生 provider（评审 M4-B1）。那个修好之后一轮就够，三轮删掉了。
///
/// 教训：**「多等几轮」凑出来的数，多半是在补偿别处一个真的缺陷。**
/// 收敛轮数取决于传播链有多长，链一变数就得重试 —— 一个要重试的常数
/// 本身就是信号。
Future<void> _settleSync(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

/// 建一条**定时**单事项，并在编辑器里加提醒。
///
/// **必须拨掉全天**（2026-09-10 起全天是默认）。全天任务的提醒基准是配置里
/// 那个绝对时刻（`reminder.allDayReminderMinute`，默认 09:00），而夹具的钟
/// 停在 09-07 11:00 —— **今天那一条已经过去了，排不出任何东西**，
/// 于是这一族用例全会报「一条都没排」，而原因跟提醒本身毫无关系。
Future<void> _createWithReminder(
  WidgetTester tester, {
  int? offsetMinutes,
}) async {
  await tapCreate(tester, TaskShape.single);
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '开会');
  await tester.pump();
  await tapVisible(tester, TaskEditorPage.allDaySwitchKey);

  await tapVisible(tester, TaskEditorPage.addReminderKey);
  await tester.pumpAndSettle();

  if (offsetMinutes != null) {
    await tapVisible(tester, TaskEditorPage.addReminderKey);
  }
  await tapVisible(tester, TaskEditorPage.saveButtonKey);
}

/// 库里那条任务的提醒行。
Future<List<({int? offset, bool enabled})>> _reminderRows(
  Harness harness,
) async {
  final rows = await harness.db.select(harness.db.reminders).get();
  return [
    for (final r in rows)
      if (r.deletedAt == null) (offset: r.offsetMinutes, enabled: r.isEnabled),
  ];
}

Future<void> _reopenEditor(WidgetTester tester) async {
  await openEditorFromCard(tester);
  if (find.byKey(OccurrenceSheetKeys.editSeries).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(OccurrenceSheetKeys.editSeries));
    await tester.pumpAndSettle();
  }
}

void main() {
  testAppWidgets('FR-NOTI-01 **加一条提醒，保存，它真的排出去了**', (tester) async {
    final harness = await _pumpApp(tester);
    await _createWithReminder(tester);
    await _settleSync(tester);

    expect(await _reminderRows(harness), [
      (offset: -15, enabled: true),
    ], reason: '默认提前量该取配置项 reminder.defaultOffsetMinutes');
    expect(
      harness.notifications.scheduled,
      isNotEmpty,
      reason: '界面上设得了，但没走到排期 —— 中间那根线又断了',
    );
    expect(harness.notifications.scheduled.last.title, '开会');
  });

  testAppWidgets('对照组：不加提醒就一条都不排', (tester) async {
    final harness = await _pumpApp(tester);
    await tapCreate(tester, TaskShape.single);
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '开会');
    await tester.pump();
    await tapVisible(tester, TaskEditorPage.saveButtonKey);
    await _settleSync(tester);

    expect(await _reminderRows(harness), isEmpty);
    expect(harness.notifications.scheduled, isEmpty);
  });

  testAppWidgets('重新打开编辑器，那条提醒还在', (tester) async {
    // 读不回来的话，用户每次编辑任务都会把已有的提醒**顺手删掉** ——
    // 保存时整表替换，草稿里没有它就等于删了。
    final harness = await _pumpApp(tester);
    await _createWithReminder(tester);
    await _settleSync(tester);

    final rows = await _reminderRows(harness);
    expect(rows, hasLength(1), reason: '前提：库里有一条');
    final id = (await harness.db.select(harness.db.reminders).get()).single.id;

    await _reopenEditor(tester);
    // **滚过去再找**：表单是懒建的 `ListView`，离屏的那几段压根没建出来，
    // `find.byKey` 直接找会是 0 个 —— 而那与「草稿里有没有读回这条提醒」
    // 毫无关系。`tapVisible` 里那段注释说的是同一件事。
    await tester.scrollUntilVisible(
      find.byKey(TaskEditorPage.reminderOffsetKey(id)),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(TaskEditorPage.reminderOffsetKey(id)), findsOneWidget);

    // 直接保存，不动任何东西 —— 那条提醒必须原样还在。
    await tapVisible(tester, TaskEditorPage.saveButtonKey);
    await _settleSync(tester);
    expect(await _reminderRows(harness), rows, reason: '打开又保存把提醒弄没了');
  });

  testAppWidgets('删掉提醒 → 库里打墓碑，也不再排', (tester) async {
    final harness = await _pumpApp(tester);
    await _createWithReminder(tester);
    await _settleSync(tester);
    final id = (await harness.db.select(harness.db.reminders).get()).single.id;
    expect(harness.notifications.scheduled, isNotEmpty, reason: '前提：本来排着');

    await _reopenEditor(tester);
    await tapVisible(tester, TaskEditorPage.reminderRemoveKey(id));
    await tapVisible(tester, TaskEditorPage.saveButtonKey);
    await _settleSync(tester);

    expect(await _reminderRows(harness), isEmpty);
    expect(
      harness.notifications.cancelled,
      isNotEmpty,
      reason: '删了提醒，已经排出去的那条得取消 —— 否则它照样会响',
    );
  });

  testAppWidgets('关掉某条提醒 → 留在库里，但不排', (tester) async {
    // 「这阵子别吵我」与「以后都不要」是两件事：关掉要保住用户调过的提前量。
    final harness = await _pumpApp(tester);
    await _createWithReminder(tester);
    await _settleSync(tester);
    final id = (await harness.db.select(harness.db.reminders).get()).single.id;

    await _reopenEditor(tester);
    await tapVisible(tester, TaskEditorPage.reminderEnabledKey(id));
    await tapVisible(tester, TaskEditorPage.saveButtonKey);
    await _settleSync(tester);

    expect(await _reminderRows(harness), [
      (offset: -15, enabled: false),
    ], reason: '关掉不该把它删了，提前量也得留着');
    expect(harness.notifications.cancelled, isNotEmpty, reason: '关了还排着');
  });

  testAppWidgets('改提前量 → 触发时刻跟着变', (tester) async {
    final harness = await _pumpApp(tester);
    await _createWithReminder(tester);
    await _settleSync(tester);

    final first = harness.notifications.scheduled.last.trigger.minuteOfDay;
    final id = (await harness.db.select(harness.db.reminders).get()).single.id;

    await _reopenEditor(tester);
    await tapVisible(tester, TaskEditorPage.reminderOffsetKey(id));
    await tester.pumpAndSettle();
    // **不选「提前 1 小时」**：默认单事项从下一个整点起（夹具时钟 11:00
    // → 任务 12:00），提前一小时正好落在 11:00 —— 也就是 `now` 本身。
    // 而排期会（正确地）丢掉不晚于当下的时刻，于是这条用例会红在
    // 一个与「改提前量生不生效」毫无关系的地方。
    await tester.tap(find.text('提前 30 分钟').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, TaskEditorPage.saveButtonKey);
    await _settleSync(tester);

    expect(await _reminderRows(harness), [(offset: -30, enabled: true)]);
    expect(
      harness.notifications.scheduled.last.trigger.minuteOfDay,
      isNot(first),
      reason: '库里改了，排出去的还是旧时刻',
    );
    expect(
      MinuteOfDay(
        harness.notifications.scheduled.last.trigger.minuteOfDay.value,
      ).value,
      first.value - 15,
      reason: '从提前 15 分改成提前 30 分，该早 15 分钟',
    );
  });
}

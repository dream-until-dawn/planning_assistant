/// 续排真的会被触发（notifications.md §3 的「续排触发点」）。
///
/// ## 这一份是这块功能的**接通证明**
///
/// 纯函数、平台接口、编排、落库四层各自都有测试，全绿。但它们连起来
/// 之前，用户设了提醒什么也不会发生 —— 这个仓库反复撞的就是这一种
/// （`isOverdue`、非重复的 `setStageDone`、`deriveStatusFromStages`…
/// 共同点是两侧都测过、中间那根线没人接）。
///
/// 所以这里从**真的应用树**装起，只在最外层换掉通知平台，
/// 断言的是「假平台上真的收到了一条排期」。
@TestOn('vm')
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/core/time/clock.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/data/database/app_database.dart';
import 'package:planning_assistant/data/database/dao/synced_dao.dart';
import 'package:planning_assistant/data/database/dao/table_daos.dart';
import 'package:planning_assistant/data/mappers/reminder_mapper.dart';
import 'package:planning_assistant/domain/entities/reminder.dart';
import 'package:planning_assistant/features/settings/application/registry.dart';
import 'package:planning_assistant/features/task/application/task_shape.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';
import 'package:planning_assistant/platform/notification/notification_platform.dart';

import '../support/app_harness.dart';

/// 夹具时钟钉在 2026-09-07 03:00 UTC = 上海 11:00，所以「今天」是 9/7。
const _today = PlanDate(2026, 9, 7);

Future<Harness> _pumpApp(
  WidgetTester tester, {
  bool canNotify = true,
  bool canScheduleExact = true,
}) async {
  await setScreenSize(tester, const Size(390, 844));
  final harness = appHarness();
  // **在装树之前设好。** 冷启动那一轮续排在 `pumpWidget` 里就跑了，
  // 装完再改的话，那一轮用的还是默认能力 —— 于是「没权限时连渠道都不该建」
  // 会被第一轮建的渠道弄红，而红的原因与它要验的东西无关。
  harness.notifications
    ..canNotify = canNotify
    ..canScheduleExact = canScheduleExact;
  await tester.pumpWidget(
    ProviderScope(overrides: harness.overrides, child: PlanningAssistantApp()),
  );
  await tester.pumpAndSettle();
  return harness;
}

/// 等一轮续排真的跑完。
///
/// **`pumpAndSettle` 不够**：续排是 fire-and-forget 的，中间还要读几次
/// 内存库，而那些查询落在 `pumpAndSettle` 认为「没有帧要画了」之后。
///
/// 一度以为「改完没有重排」是这个原因，于是把这里加长到八轮 ——
/// 没用。真正的原因是续排读了一个没人 watch 的派生 provider，
/// 拿回来的是旧值（见 `remindersByTaskProvider` 的注释）。
/// **等得更久治不了读到旧值**，那次差点就把加长当成修好了。
Future<void> _settleSync(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

/// 建一条今天 15:00 的任务，返回它的 id。
Future<String> _createTask(WidgetTester tester, Harness harness) async {
  await tapCreate(tester, TaskShape.scratch);
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '开会');
  await tester.pump();
  await tapVisible(tester, TaskEditorPage.saveButtonKey);

  final row = (await harness.db.select(harness.db.tasks).get()).single;
  await (harness.db.update(
    harness.db.tasks,
  )..where((t) => t.id.equals(row.id))).write(
    TasksCompanion(
      planDate: Value(_today.toString()),
      startMinute: Value(MinuteOfDay.of(15, 0).value),
      // **`isAllDay` 也要落回 false。** 临时事项存下来是全天的，
      // 只补 `startMinute` 会留下一行自相矛盾的数据 ——
      // 而排期会（正确地）按全天走 `reminder.allDayReminderMinute`，
      // 于是这份夹具验的东西和它以为在验的完全不是一回事。
      isAllDay: const Value(false),
    ),
  );
  return row.id;
}

/// 直接往库里放一条提醒。
///
/// **编辑器里还没有提醒这一栏**（那是下一步）。在它到位之前，
/// 这一份验的是「有提醒的数据能不能一路走到排期」——
/// 少了这条路，界面做出来也只是接到一段死路上。
Future<void> _seedReminder(
  Harness harness,
  String taskId, {
  int offsetMinutes = -15,
}) async {
  await ReminderDao(
    harness.db,
    const FixedWriterIdentity('test-device'),
    FixedClock(DateTime.utc(2026, 9, 7, 3)),
  ).upsert(
    reminderToCompanion(
      Reminder(
        id: 'rem-1',
        taskId: taskId,
        kind: ReminderKind.relativeToStart,
        offsetMinutes: offsetMinutes,
      ),
    ),
  );
}

void main() {
  testAppWidgets('**设了提醒的任务，真的排出去了**', (tester) async {
    final harness = await _pumpApp(tester);
    final taskId = await _createTask(tester, harness);
    await _seedReminder(harness, taskId);
    await _settleSync(tester);

    final platform = harness.notifications;
    expect(
      platform.scheduled,
      isNotEmpty,
      reason: '四层都绿，但没接上 —— 用户设了提醒什么也不会发生',
    );
    expect(platform.readyCount, greaterThan(0), reason: '渠道都没建');

    final planned = platform.scheduled.last;
    expect(planned.title, '开会');
    expect(
      planned.trigger.minuteOfDay,
      MinuteOfDay.of(14, 45),
      reason: '15:00 提前 15 分钟',
    );
    expect(planned.trigger.date, _today);
  });

  testAppWidgets('对照组：没设提醒的任务，一条都不排', (tester) async {
    // 少了它，一个「凡是任务都排一条」的实现在上面那条里也能过。
    final harness = await _pumpApp(tester);
    await _createTask(tester, harness);
    await _settleSync(tester);

    expect(harness.notifications.scheduled, isEmpty);
  });

  testAppWidgets('FR-NOTI-01 改「滚动排期窗口」→ 当场按新窗口重排', (tester) async {
    // ## 这条补的是一个**只有守卫覆盖、没有行为用例**的缺口
    //
    // `resync_trigger_test` 证明的是 `ref.listen(reminderWindowDaysProvider, …)`
    // 那一行**在**。它证明不了改设置之后真的重排了 ——
    // 而 M4-B1 那次断的恰恰不是接线，是**读的时刻**，结构守卫对时刻是瞎的。
    //
    // 所以这一条从**平台侧收到了什么**上验：窗口外的那条本来排不出来，
    // 把窗口调宽之后，**不做任何别的操作**，它应该自己排出来。
    final harness = await _pumpApp(tester);
    final taskId = await _createTask(tester, harness);

    // 把它挪到默认窗口（14 天）**之外**。
    await (harness.db.update(harness.db.tasks)
          ..where((t) => t.id.equals(taskId)))
        .write(TasksCompanion(planDate: Value(_today.addDays(20).toString())));
    await _seedReminder(harness, taskId);
    await _settleSync(tester);
    expect(
      harness.notifications.scheduled,
      isEmpty,
      reason: '前提：20 天后的那条在 14 天窗口里排不出来',
    );

    // **只改这一个设置，别的什么都不动。**
    await seedSetting(tester, reminderWindowDays, 30);
    await _settleSync(tester);

    expect(
      harness.notifications.scheduled,
      isNotEmpty,
      reason: '改了窗口却没有重排 —— 那个设置不在触发集里',
    );
  });

  testAppWidgets('关掉总开关 → 不排', (tester) async {
    final harness = await _pumpApp(tester);
    final taskId = await _createTask(tester, harness);
    await _seedReminder(harness, taskId);
    await _settleSync(tester);
    expect(harness.notifications.scheduled, isNotEmpty, reason: '前提：本来排得出来');

    harness.notifications.scheduled.clear();
    await seedSetting(tester, reminderEnabled, false);
    await _settleSync(tester);

    expect(harness.notifications.scheduled, isEmpty);
  });

  testAppWidgets('通知权限没给 → 一条都不排', (tester) async {
    final harness = await _pumpApp(tester, canNotify: false);

    final taskId = await _createTask(tester, harness);
    await _seedReminder(harness, taskId);
    await _settleSync(tester);

    expect(harness.notifications.scheduled, isEmpty);
    expect(harness.notifications.readyCount, 0, reason: '没权限时连渠道都不该建');
  });

  testAppWidgets('精确闹钟不可用 → 降级排，不是不排', (tester) async {
    final harness = await _pumpApp(tester, canScheduleExact: false);

    final taskId = await _createTask(tester, harness);
    await _seedReminder(harness, taskId);
    await _settleSync(tester);

    expect(harness.notifications.scheduled, isNotEmpty);
    expect(harness.notifications.lastMode, ReminderScheduleMode.inexact);
  });

  testAppWidgets('**改了提醒就重排** —— 不用切出去再切回来', (tester) async {
    // 只挂「进前台」的话，刚改完要切后台再回来才生效。
    final harness = await _pumpApp(tester);
    final taskId = await _createTask(tester, harness);
    await _seedReminder(harness, taskId);
    await _settleSync(tester);

    harness.notifications.scheduled.clear();
    await _seedReminder(harness, taskId, offsetMinutes: -60);
    await _settleSync(tester);
    expect(harness.notifications.scheduled, isNotEmpty, reason: '改完没有重排');
    expect(
      harness.notifications.scheduled.last.trigger.minuteOfDay,
      MinuteOfDay.of(14, 0),
      reason: '重排了，但用的还是旧的偏移',
    );
  });
}

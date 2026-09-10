/// 改阶段也要触发续排（评审 M4-B2）。
///
/// ## 这条缺陷不是「算错了」，是「该算的时候没算」
///
/// `resyncNow` 读 `stagesByTaskProvider` 与 `stageStatesByTaskProvider`，
/// 而监听集里一度**一个都没有**。于是：
///
/// ```
/// 改一个阶段的时间
///   → 有效结束变（data-model §4.7：末阶段可能排到 endDate 之后）
///   → 这一次的结束时刻变
///   → relativeToEnd 的提醒本该跟着挪
///   → 没有任何监听被触发，续排不跑
/// ```
///
/// 影响有界 —— 进前台会整窗口重排。但提醒恰恰是**在后台等着响**的东西，
/// 那个窗口正是它最该准的时候。
///
/// ## 它照出了「全靠纯 Dart 那一侧」这个前提的洞
///
/// 那一侧（35 条 + 变异验证）覆盖的是 `planNotifications` **算得对不对**。
/// 这条不在它的射程里：接线正确性（谁监听谁）既不在领域用例里，
/// 也不在真机验证里（已降级）。**算法有纯 Dart 兜着，接线得单独兜。**
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
import 'package:planning_assistant/features/task/application/task_shape.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';

import '../support/app_harness.dart';

const _today = PlanDate(2026, 9, 7);
final _clock = FixedClock(DateTime.utc(2026, 9, 7, 3));

Future<Harness> _pumpApp(WidgetTester tester) async {
  await setScreenSize(tester, const Size(390, 844));
  final harness = appHarness();
  await tester.pumpWidget(
    ProviderScope(overrides: harness.overrides, child: PlanningAssistantApp()),
  );
  await tester.pumpAndSettle();
  return harness;
}

Future<void> _settleSync(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

/// 建一条今天的两阶段任务，起止钉死，返回 taskId。
Future<String> _createStaged(WidgetTester tester, Harness harness) async {
  await tapCreate(tester, TaskShape.staged);
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '搬家');
  await tester.pump();
  for (final name in ['打包', '搬运']) {
    await addStage(tester, name);
  }
  await tapVisible(tester, TaskEditorPage.saveButtonKey);

  final row = (await harness.db.select(harness.db.tasks).get()).single;
  await (harness.db.update(
    harness.db.tasks,
  )..where((t) => t.id.equals(row.id))).write(
    TasksCompanion(
      planDate: Value(_today.toString()),
      startMinute: Value(MinuteOfDay.of(13, 0).value),
      endDate: Value(_today.toString()),
      endMinute: Value(MinuteOfDay.of(14, 0).value),
      isAllDay: const Value(false),
    ),
  );
  return row.id;
}

/// 一条「结束前 15 分钟」的提醒。
///
/// **界面上给不了这一档**（编辑器只做相对开始，requirements §4.1），
/// 但领域层与排期都支持，导入与 Agent 构造得出来 —— 而这条缺陷正是
/// 挂在它身上的。
Future<void> _seedEndReminder(Harness harness, String taskId) async {
  await ReminderDao(
    harness.db,
    const FixedWriterIdentity('test-device'),
    _clock,
  ).upsert(
    reminderToCompanion(
      Reminder(
        id: 'rem-end',
        taskId: taskId,
        kind: ReminderKind.relativeToEnd,
        offsetMinutes: -15,
      ),
    ),
  );
}

/// 把最后一个阶段挪到任务结束之后 —— 有效结束跟着变（§4.7）。
Future<void> _pushLastStageBeyondEnd(Harness harness) async {
  final stages = await harness.db.select(harness.db.stages).get();
  stages.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  await (harness.db.update(
    harness.db.stages,
  )..where((t) => t.id.equals(stages.last.id))).write(
    // 从任务开始起偏移 180 分钟、时长 60 → 末阶段结束在 17:00，
    // 而任务自己的结束是 14:00。有效结束取两者的晚者。
    const StagesCompanion(
      startOffsetMinutes: Value(180),
      durationMinutes: Value(60),
    ),
  );
}

void main() {
  testAppWidgets('**改一个阶段的时间 → 续排真的跑了，结束前的提醒跟着挪**', (tester) async {
    final harness = await _pumpApp(tester);
    final taskId = await _createStaged(tester, harness);
    await _seedEndReminder(harness, taskId);
    await _settleSync(tester);

    final before = harness.notifications.scheduled.last;
    expect(
      before.trigger.minuteOfDay,
      MinuteOfDay.of(13, 45),
      reason: '前提：任务 13:00–14:00，结束前 15 分钟 = 13:45',
    );

    // 只动阶段，别的什么都不碰。
    await _pushLastStageBeyondEnd(harness);
    await _settleSync(tester);

    final after = harness.notifications.scheduled.last;
    expect(
      after.trigger.minuteOfDay,
      MinuteOfDay.of(16, 45),
      reason:
          '末阶段排到 17:00，有效结束跟着变，提醒该挪到 16:45 —— '
          '没挪就是阶段那两条流不在监听集里',
    );
  });

  testAppWidgets('对照组：改阶段不该把相对开始的提醒也挪了', (tester) async {
    // 少了它，一个「阶段一变就把所有提醒重算成别的时刻」的实现
    // 在上面那条里也能过。相对开始的基准是开始时刻，与阶段无关。
    final harness = await _pumpApp(tester);
    final taskId = await _createStaged(tester, harness);
    await ReminderDao(
      harness.db,
      const FixedWriterIdentity('test-device'),
      _clock,
    ).upsert(
      reminderToCompanion(
        Reminder(
          id: 'rem-start',
          taskId: taskId,
          kind: ReminderKind.relativeToStart,
          offsetMinutes: -15,
        ),
      ),
    );
    await _settleSync(tester);
    expect(
      harness.notifications.scheduled.last.trigger.minuteOfDay,
      MinuteOfDay.of(12, 45),
      reason: '前提：13:00 提前 15 分钟',
    );

    await _pushLastStageBeyondEnd(harness);
    await _settleSync(tester);

    expect(
      harness.notifications.scheduled.last.trigger.minuteOfDay,
      MinuteOfDay.of(12, 45),
      reason: '相对开始的提醒被阶段改动带跑了',
    );
  });
}

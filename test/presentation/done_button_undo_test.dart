/// 完成钮：**所有视图一致**地给撤销（view-specs §0.3）。
///
/// ## 这一条是补出来的，而且是我自己漏的
///
/// 规格那一行写的是「就地完成 + 撤销 Snackbar」，主语是「所有视图」。
/// 实现却是每个视图各写一遍：
///
/// ```dart
/// onToggleDone: () => ref.read(toggleTaskDoneProvider)(row),
/// ```
///
/// —— 返回的**撤销闭包被直接丢掉**。于是同一个视图里滑动完成有撤销、
/// 按完成钮没有，而用户不会知道自己走的是哪条路。
///
/// 1471 个用例对此**一条都没说话**：视图各自的用例用的是替身数据源
/// （没有 dispatcher，勾不动），而走真库的旅程用例只验落库，
/// 没人问过「提示弹了没有」。
///
/// 所以这一份**跨视图**验：一条规格说「所有视图一致」，那就该有一条
/// 用例遍历所有视图 —— 挨个视图各写一条的话，新加视图的人不会知道
/// 有这条规矩（testing-strategy §1.15：守卫的宇宙要跟着规格划）。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/app_providers.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/domain/commands/task_command.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/views/shared/application/view_kind.dart';

import '../support/app_harness.dart';

/// `appHarness()` 的时钟钉在 9/7 11:00 +08。
const _today = PlanDate(2026, 9, 7);

/// 完成钮在哪几个视图上摆着。
///
/// 甘特没有 —— 它画的是条，不是卡片（§4.2）。**列在这里而不是
/// 默默跳过**：将来甘特要是加了卡片，这张表是提醒。
const _viewsWithCards = [ViewKind.list, ViewKind.timeline, ViewKind.calendar];

Future<Harness> _pump(WidgetTester tester) async {
  await setScreenSize(tester, const Size(390, 844));
  final harness = appHarness();
  await tester.pumpWidget(
    ProviderScope(overrides: harness.overrides, child: PlanningAssistantApp()),
  );
  await tester.pumpAndSettle();

  // 一条今天上午的任务，三个视图都看得见它。
  await ProviderScope.containerOf(tester.element(find.byType(AppShell)))
      .read(taskCommandDispatcherProvider)
      .dispatch(
        CreateTaskCommand(
          taskId: '晨会',
          title: '晨会',
          kind: TaskKind.single,
          timeZoneId: 'Asia/Shanghai',
          planDate: _today,
          startMinute: MinuteOfDay.of(9, 0),
        ),
      );
  await tester.pumpAndSettle();
  return harness;
}

Future<void> _switchTo(WidgetTester tester, ViewKind kind) async {
  await tester.tap(find.byKey(AppShell.viewTabKey(kind)));
  await tester.pumpAndSettle();
}

/// 按下这一屏上的完成钮。
Future<void> _tapDone(WidgetTester tester) async {
  await tapVisible(tester, TaskCard.doneButtonKey);
}

Future<String?> _statusOf(Harness harness) async =>
    (await harness.db.select(harness.db.tasks).getSingle()).status;

void main() {
  for (final view in _viewsWithCards) {
    group('${view.label}视图的完成钮', () {
      testAppWidgets('勾完成弹提示，而且带「撤销」', (tester) async {
        final harness = await _pump(tester);
        await _switchTo(tester, view);

        await _tapDone(tester);

        expect(await _statusOf(harness), 'done', reason: '钮点了但没落库');
        expect(
          find.text('撤销'),
          findsOneWidget,
          reason: '${view.label}的完成钮把撤销闭包丢了 —— 滑动有、按钮没有',
        );
      });

      testAppWidgets('**撤销真的改回来**', (tester) async {
        // 只弹一个按钮而点了没用，比没有这个按钮更糟。
        final harness = await _pump(tester);
        await _switchTo(tester, view);

        await _tapDone(tester);
        await tester.tap(find.text('撤销'));
        await tester.pumpAndSettle();

        expect(await _statusOf(harness), 'pending');
      });

      testAppWidgets('提示会自己消失', (tester) async {
        // 带 action 的 SnackBar 默认 `persist: true`，`duration` 形同虚设 ——
        // 用户报过一次（「下方的轻提示永远不会消失」）。
        await _pump(tester);
        await _switchTo(tester, view);

        await _tapDone(tester);
        expect(find.text('撤销'), findsOneWidget);

        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(find.text('撤销'), findsNothing);
      });
    });
  }

  testAppWidgets('对照组：甘特上没有完成钮，不该硬凑一个', (tester) async {
    // 少了这条，把 `_viewsWithCards` 写成 `ViewKind.values` 会得到
    // 一条「甘特的完成钮也给撤销」的假绿 —— 找不到钮时
    // `tapVisible` 会抛，但抛出来的话没人读得懂那是「本来就没有」。
    await _pump(tester);
    await _switchTo(tester, ViewKind.gantt);

    expect(find.byKey(TaskCard.doneButtonKey), findsNothing);
  });
}

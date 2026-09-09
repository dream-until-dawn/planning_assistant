/// 撤销提示会自己消失（用户报的第 2 条：「下方的轻提示永远不会消失」）。
///
/// 撤销 Snackbar 是这个应用里最常出现的一块界面 —— 每次滑动、每次批量
/// 操作都弹一条。它不消失的话，屏幕底部会被一条陈旧的提示长期占住，
/// 而那条提示上的「撤销」按钮**还连着一个早就过期的闭包**。
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

Future<Harness> _pumpApp(WidgetTester tester) async {
  await setScreenSize(tester, const Size(390, 844));
  final harness = appHarness();
  await tester.pumpWidget(
    ProviderScope(overrides: harness.overrides, child: PlanningAssistantApp()),
  );
  await tester.pumpAndSettle();
  return harness;
}

Future<void> _create(WidgetTester tester, String title) async {
  await tester.tap(find.byKey(AppShell.fabKey));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), title);
  await tester.pump();
  await tapVisible(tester, TaskEditorPage.saveButtonKey);
}

void main() {
  testAppWidgets('滑动弹的撤销提示，几秒后自己消失', (tester) async {
    // ## 根因值得记
    //
    // Flutter 的 `SnackBar` 里有一行：
    //
    //     persist = persist ?? action != null;
    //
    // **带 action 的提示默认永不自动消失**，等用户去点。
    // 而我们每一条提示都带「撤销」—— 于是全都是永久的。
    // `duration` 照样设了、计时器也照样起，但回调第一句是
    // `if (snackBar.persist) return;`。
    //
    // 用户报的原话：「下方的轻提示永远不会消失」。
    // 后果不止是碍眼：那条提示上的「撤销」还连着一个早就过期的闭包，
    // 而后面每一条新提示都排在它后面出不来
    // —— 排查时我在同一棵树里弹了一条对照提示，它压根没出现。
    await _pumpApp(tester);
    await _create(tester, '买菜');

    await tester.drag(find.byType(TaskCard), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(find.text('撤销'), findsOneWidget, reason: '前提：提示弹出来了');

    // **不能只 pump 一帧就断言。** 超时触发的是一段退场动画，
    // 一帧之内它还在树上 —— 我第一版探针就是这么把「已经修好的」
    // 读成「还没修」的，白查了两轮。
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(
      find.text('撤销'),
      findsNothing,
      reason: '提示不会自己消失 —— 多半是 SnackBar 少写了 persist: false',
    );
  });

  testAppWidgets('提示消失之后，下一条弹得出来', (tester) async {
    // 卡住的那条会把后面所有提示堵在队列里。
    // 只验「第一条会消失」的话，一个「一律不弹」的实现也能绿。
    await _pumpApp(tester);
    await _create(tester, '买菜');

    await tester.drag(find.byType(TaskCard), const Offset(400, 0));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(TaskCard), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(find.text('撤销'), findsOneWidget, reason: '第二条提示被堵在队列里了');
  });
}

/// R-52 任务整体挪动时，阶段跟着走（data-model §4.1）。
///
/// ## 这条用例欠了两个里程碑
///
/// M1 的遗留清单里记着它，到期写的是「M3 阶段编辑」。R-27 补完之后
/// 它是那张清单上**最后一条**。
///
/// ## 它验的其实是「什么都没发生」
///
/// §4.1 选了相对偏移而不是绝对日期，好处之一就是「整体挪任务时阶段
/// 自动跟随」—— 那不需要任何代码去实现，只需要**没有人去动那个偏移**。
///
/// 所以这条用例的形状是反的：它盯的是编辑器改开始时刻时
/// **不去重算阶段偏移**。哪天有人「顺手」在 `setStartMinute` 里
/// 把阶段的绝对时刻保持住（听起来很贴心），这条会红 ——
/// 而那正是 §4.1 权衡掉的那一半。
///
/// 同一段还写了另一半：**改结束日期时阶段不自动缩放**，
/// 而且那是刻意的（「静默改变用户排好的阶段时长比不改更糟」）。
/// 下面有一条对照组钉着它。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
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

/// 建一条两阶段的任务，并给第二个阶段定上「任务开始起、一小时」。
Future<List<String>> _createStaged(WidgetTester tester) async {
  await tapCreate(tester, TaskShape.staged);
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '搬家');
  await tester.pump();
  final ids = <String>[];
  for (final name in ['打包', '搬运']) {
    await tapVisible(tester, TaskEditorPage.addStageKey);
    final field = find
        .descendant(
          of: find.byKey(TaskEditorPage.stageSectionKey),
          matching: find.byType(TextField),
        )
        .last;
    await tester.enterText(field, name);
    await tester.pumpAndSettle();
    ids.add(
      ((tester.widget(field) as TextField).key! as ValueKey<String>).value
          .replaceFirst('editor-stage-', ''),
    );
  }

  await tapVisible(tester, TaskEditorPage.stageTimeKey(ids[1]));
  await tester.tap(find.byKey(TaskEditorPage.stageTimeConfirmKey));
  await tester.pumpAndSettle();
  await tapVisible(tester, TaskEditorPage.saveButtonKey);
  return ids;
}

Future<void> _reopen(WidgetTester tester) async {
  await openEditorFromCard(tester);
}

/// 把任务从「全天」改成「有具体时刻」。
///
/// **这就是一次「任务整体挪动」**：锚点从「这一天」变成「这一天 09:00」，
/// 所有阶段的绝对时刻跟着后移。
/// 不用时间选择器再拨一次是因为那个对话框在测试里只接受默认值 ——
/// 而验 R-52 需要的只是**锚点真的动了**，不是动到几点。

void main() {
  testAppWidgets('R-52 阶段之间的相对关系，不因为任务起止变了而被重算', (tester) async {
    // ## 这一条被改写过（用户 2026-09-10 定：阶段事项的起止由阶段推出）
    //
    // 原来的形态是「把任务整体挪动（关掉全天、给它一个时刻），
    // 断言阶段偏移原样不动」。**那条路没有了** —— 阶段事项的起止不再由
    // 用户直接填，日期/全天/时刻那几个控件已经不出现在表单上。
    //
    // **不是删掉，是换观察点。** R-52 守的性质还在，只是现在只能从
    // 「改阶段」那一侧看：改了一个阶段的时间之后，任务的起止跟着走，
    // 而**另一个阶段与它的相对距离不变**。
    // 若哪天有人在推导里顺手「保持每个阶段的绝对时刻」（听起来很贴心），
    // 这条会红 —— 而那正是 §4.1 权衡掉的那一半。
    final harness = await _pumpApp(tester);
    final ids = await _createStaged(tester);

    final before = await harness.db.select(harness.db.stages).get();
    expect(
      before.firstWhere((s) => s.id == ids[1]).startOffsetMinutes,
      0,
      reason: '前提：第二个阶段从任务开始那一刻起',
    );

    // 给**第一个**阶段也定上时间（对话框默认「任务开始起、一小时」）。
    await _reopen(tester);
    await tapVisible(tester, TaskEditorPage.stageTimeKey(ids[0]));
    await tester.tap(find.byKey(TaskEditorPage.stageTimeConfirmKey));
    await tester.pumpAndSettle();
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    final after = await harness.db.select(harness.db.stages).get();
    final a = after.firstWhere((s) => s.id == ids[0]);
    final b = after.firstWhere((s) => s.id == ids[1]);

    // 两个阶段现在从同一刻起 —— 相对距离是 0，而且**两边都是 0**：
    // 谁也没有被推导挪走。
    expect(a.startOffsetMinutes, 0);
    expect(b.startOffsetMinutes, 0);
    expect(
      b.durationMinutes,
      before.firstWhere((s) => s.id == ids[1]).durationMinutes,
      reason: '别人的时长被动了 —— 推导只该改偏移的基准，不该碰时长',
    );
  });

  testAppWidgets('**推导是幂等的**：什么都不改地重开再保存，一个字都不动', (tester) async {
    // 这一条是整条改动的回归闸。推导每次改阶段时间都会跑一遍，
    // 不幂等的话，什么都不改地保存两次，任务会一次次往前挪 ——
    // 而用户看到的是「我什么都没干，它自己动了」。
    //
    // `derived_span_test` 在纯函数那一层验过同一件事；这一条验的是
    // **接线**：编辑器真的按那个函数走，而不是另算了一遍。
    final harness = await _pumpApp(tester);
    await _createStaged(tester);

    final task0 = (await harness.db.select(harness.db.tasks).get()).single;
    final stages0 = await harness.db.select(harness.db.stages).get();

    await _reopen(tester);
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    final task1 = (await harness.db.select(harness.db.tasks).get()).single;
    final stages1 = await harness.db.select(harness.db.stages).get();

    expect(task1.planDate, task0.planDate);
    expect(task1.startMinute, task0.startMinute);
    expect(task1.endDate, task0.endDate);
    expect(task1.endMinute, task0.endMinute);
    expect(
      stages1.map((s) => s.startOffsetMinutes),
      stages0.map((s) => s.startOffsetMinutes),
    );
  });

  testAppWidgets('对照组：任务的结束由**最晚那个阶段**决定，不缩放任何阶段时长', (tester) async {
    // ## 也被改写过，理由同上一条
    //
    // 原来验的是「改任务的结束日期不缩放阶段时长」，而任务的结束现在
    // 不是用户填的了。换成从阶段那一侧看同一件事：
    // 任务的结束跟着最晚那个阶段走，而**没有任何阶段的时长被动过**。
    //
    // 「不自动缩放」是写进文档的取舍（§4.1）：静默改变用户排好的阶段
    // 时长比不改更糟。少了这条，一个「整体等比缩放」的实现能让上一条绿。
    final harness = await _pumpApp(tester);
    final ids = await _createStaged(tester);

    final task = (await harness.db.select(harness.db.tasks).get()).single;
    final timed = (await harness.db.select(harness.db.stages).get()).firstWhere(
      (s) => s.id == ids[1],
    );

    expect(timed.durationMinutes, 60, reason: '前提：那个阶段是一小时');
    // 那个阶段从任务开始起、一小时 —— 于是任务的结束就该是它的结束。
    expect(timed.startOffsetMinutes, 0);
    expect(
      task.endMinute! - task.startMinute!,
      60,
      reason: '任务的跨度不等于最晚那个阶段的结束 —— 推导取错了边界',
    );
    expect(
      (await harness.db.select(harness.db.stages).get()).map(
        (s) => s.durationMinutes,
      ),
      [null, 60],
      reason: '有阶段的时长被推导动过了',
    );
  });
}

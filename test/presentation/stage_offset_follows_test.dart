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
import 'package:planning_assistant/design/components/task_card.dart';
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
  // **拨成全天**：这一份验的是「任务整体挪动时阶段偏移不动」，
  // 而它下面有一条前提断言「这条任务还是全天的」。
  // 新建默认是定时的（起止必填那条改动之后），所以要拨回来 ——
  // 全天与偏移无关，换成定时只会给这份夹具多两个变量。
  await tapVisible(tester, TaskEditorPage.allDaySwitchKey);

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
  await tester.tap(find.byType(TaskCard).first);
  await tester.pumpAndSettle();
}

/// 把任务从「全天」改成「有具体时刻」。
///
/// **这就是一次「任务整体挪动」**：锚点从「这一天」变成「这一天 09:00」，
/// 所有阶段的绝对时刻跟着后移。
/// 不用时间选择器再拨一次是因为那个对话框在测试里只接受默认值 ——
/// 而验 R-52 需要的只是**锚点真的动了**，不是动到几点。
Future<void> _makeTimed(WidgetTester tester) async {
  await tapVisible(tester, TaskEditorPage.allDaySwitchKey);
  await tapVisible(tester, TaskEditorPage.timeFieldKey);
  await tester.tap(find.text('确定'));
  await tester.pumpAndSettle();
}

void main() {
  testAppWidgets('R-52 任务整体挪动之后，阶段的偏移**原样不动**', (tester) async {
    // 「跟随后移」不是靠算出来的，是靠**没人去动那个偏移**。
    // 编辑器若在改开始时刻时顺手保持阶段的绝对时刻（听起来很贴心），
    // 这条会红 —— 而那正是 §4.1 权衡掉的那一半。
    final harness = await _pumpApp(tester);
    final ids = await _createStaged(tester);

    final before = (await harness.db.select(harness.db.stages).get())
        .firstWhere((s) => s.id == ids[1]);
    expect(before.startOffsetMinutes, 0);
    expect(before.durationMinutes, 60);
    expect(
      (await harness.db.select(harness.db.tasks).get()).single.startMinute,
      isNull,
      reason: '前提：这条任务还是全天的',
    );

    await _reopen(tester);
    await _makeTimed(tester);
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    final task = (await harness.db.select(harness.db.tasks).get()).single;
    expect(task.startMinute, isNotNull, reason: '锚点没动，这条用例就什么也没验');
    expect(task.isAllDay, isFalse);

    final after = (await harness.db.select(harness.db.stages).get()).firstWhere(
      (s) => s.id == ids[1],
    );
    expect(
      after.startOffsetMinutes,
      before.startOffsetMinutes,
      reason: '阶段的偏移被重算了 —— 那样阶段就不会跟着任务走',
    );
    expect(after.durationMinutes, before.durationMinutes);
  });

  testAppWidgets('R-52 顺带钉住：关掉「全天」再保存不会崩', (tester) async {
    // **这是写上面那条时撞出来的真缺陷。**
    // R-27 把形态切换做成了一条单独的命令，而它在保存流程里排在
    // `UpdateTaskFieldsCommand` **之后** —— 那条命令带着 startMinute，
    // 而库里那条还是全天，于是 `checkInvariants` 当场抛
    // 「是全天任务却带 startMinute」。
    //
    // 也就是说：**关掉「全天」、选个时刻、保存** —— 这条最普通不过的
    // 编辑会直接崩。R-27 自己那批测试没覆盖它：要么只验开关能拨
    // （没保存），要么直接发命令（没走编辑器这条「改形态 + 改字段」
    // 同时发生的路）。
    final harness = await _pumpApp(tester);
    // 这一条与阶段无关，用临时事项起手 —— 它默认就是全天、没日期，
    // 正好是「关掉全天」这个动作的起点。
    await tapCreate(tester, TaskShape.scratch);
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '开会');
    await tester.pump();
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    await _reopen(tester);
    await _makeTimed(tester);
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    final task = (await harness.db.select(harness.db.tasks).get()).single;
    expect(task.isAllDay, isFalse);
    expect(task.startMinute, isNotNull);
    // 回到列表 = 真的存下去了（崩的话会停在编辑页上）。
    expect(find.byType(TaskCard), findsOneWidget);
  });

  testAppWidgets('对照组：改结束日期不缩放阶段时长（§4.1 刻意如此）', (tester) async {
    // 「不自动缩放」是写进文档的取舍：静默改变用户排好的阶段时长
    // 比不改更糟。少了这条，一个「整体等比缩放」的实现能让上面那条绿。
    final harness = await _pumpApp(tester);
    final ids = await _createStaged(tester);

    await _reopen(tester);
    await tapVisible(tester, TaskEditorPage.endSwitchKey);
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    final after = (await harness.db.select(harness.db.stages).get()).firstWhere(
      (s) => s.id == ids[1],
    );
    expect(after.durationMinutes, 60, reason: '阶段时长被跟着缩放了');
  });
}

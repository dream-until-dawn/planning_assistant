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
import 'package:planning_assistant/data/database/app_database.dart';
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

/// 把某个阶段挪到「9 月 [startDay] 号 → 9 月 [endDay] 号」。
///
/// **先挪结束、再挪开始。** 反过来的话中间会经过「开始晚于结束」那个
/// 状态，对话框的「确定」当场就灰了 —— 而那道拦截是对的，
/// 夹具该绕开它，不该去改它。
Future<void> _setStageDays(
  WidgetTester tester,
  String id, {
  required int startDay,
  required int endDay,
}) async {
  Future<void> pick(Key field, int day) async {
    await tester.tap(find.byKey(field));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('$day'),
      ),
    );
    await tester.pumpAndSettle();
    // **必须限定在日期选择器里找「确定」**：它底下压着阶段时间对话框，
    // 那个也有一颗「确定」。`find.text('确定')` 会找到两个，
    // 报的是「too many elements」—— 与「日期没选上」差得很远。
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('确定'),
      ),
    );
    await tester.pumpAndSettle();
  }

  await tapVisible(tester, TaskEditorPage.stageTimeKey(id));
  await pick(TaskEditorPage.stageTimeEndDateKey, endDay);
  await pick(TaskEditorPage.stageTimeStartDateKey, startDay);
  await tester.tap(find.byKey(TaskEditorPage.stageTimeConfirmKey));
  await tester.pumpAndSettle();
}

/// 建一条**三阶段**的任务，三个阶段各占一天：9/7、9/8、9/9。
///
/// ## 为什么是三个，为什么每个都有时间
///
/// 每个都有时间：用户 2026-09-10「加强必填项校验」之后，
/// 阶段事项的**每个**阶段都必须有时间，一个没填就存不下去。
///
/// 三个而不是两个：R-52 说的是「改一个阶段，**其余阶段之间**的相对关系
/// 不变」。只有两个的时候「其余」只剩一个，那句话退化成「被改的那个
/// 变了」—— 什么也没守住。
Future<List<String>> _createStaged(WidgetTester tester) async {
  await tapCreate(tester, TaskShape.staged);
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '搬家');
  await tester.pump();
  final ids = <String>[];
  for (final name in ['打包', '搬运', '收拾']) {
    await addStage(tester, name);
    final field = find
        .descendant(
          of: find.byKey(TaskEditorPage.stageSectionKey),
          matching: find.byType(TextField),
        )
        .last;
    ids.add(
      ((tester.widget(field) as TextField).key! as ValueKey<String>).value
          .replaceFirst('editor-stage-', ''),
    );
  }

  // 夹具的今天是 2026-09-07，`addStage` 给的默认是「任务开始起、一小时」。
  // 把后两个各往后挪一天，于是三个阶段的偏移是 0 / 1440 / 2880。
  await _setStageDays(tester, ids[1], startDay: 8, endDay: 8);
  await _setStageDays(tester, ids[2], startDay: 9, endDay: 9);
  await tapVisible(tester, TaskEditorPage.saveButtonKey);
  return ids;
}

Future<void> _reopen(WidgetTester tester) async {
  await openEditorFromCard(tester);
}

void main() {
  testAppWidgets('R-52 阶段之间的相对关系，不因为任务起止变了而被重算', (tester) async {
    // ## 这一条被改写过（用户 2026-09-10 定：阶段事项的起止由阶段推出）
    //
    // 原来的形态是「把任务整体挪动（关掉全天、给它一个时刻），
    // 断言阶段偏移原样不动」。**那条路没有了** —— 阶段事项的起止不再由
    // 用户直接填，全天与起止那几个控件已经不出现在表单上。
    //
    // **不是删掉，是换观察点。** R-52 守的性质还在，只是现在只能从
    // 「改阶段」那一侧看：改一个阶段的时间会让任务的起止跟着走
    // （推导会把偏移的**基准**换成新的最早那个），而
    // **其余阶段彼此之间的距离与各自的时长一个都不许动**。
    //
    // 若哪天有人在推导里顺手「保持每个阶段的绝对时刻」（听起来很贴心），
    // 这条会红 —— 而那正是 §4.1 权衡掉的那一半。
    final harness = await _pumpApp(tester);
    final ids = await _createStaged(tester);

    Map<String, ({int? offset, int? duration})> read(List<StageRow> rows) => {
      for (final r in rows)
        r.id: (offset: r.startOffsetMinutes, duration: r.durationMinutes),
    };

    final before = read(await harness.db.select(harness.db.stages).get());
    expect(
      [before[ids[0]]!.offset, before[ids[1]]!.offset, before[ids[2]]!.offset],
      [0, 1440, 2880],
      reason: '前提：三个阶段各占一天',
    );

    // 把**第一个**阶段挪到 9/10 —— 于是最早的那个变成了「搬运」，
    // 推导要把所有偏移重新表达成相对它。
    await _reopen(tester);
    await _setStageDays(tester, ids[0], startDay: 10, endDay: 10);
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    final after = read(await harness.db.select(harness.db.stages).get());

    // 最早那个的偏移恒为 0（`derived_span.dart` 的不变量）。
    expect(after[ids[1]]!.offset, 0);
    // **其余两个彼此的距离没变**：搬运 9/8、收拾 9/9，仍然差一天。
    expect(
      after[ids[2]]!.offset! - after[ids[1]]!.offset!,
      before[ids[2]]!.offset! - before[ids[1]]!.offset!,
      reason: '没被改的两个阶段之间的距离被推导动了',
    );
    // 时长一个都不许动。
    for (final id in ids) {
      expect(
        after[id]!.duration,
        before[id]!.duration,
        reason: '推导只该改偏移的基准，不该碰时长',
      );
    }
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
    await _createStaged(tester);

    final task = (await harness.db.select(harness.db.tasks).get()).single;
    final stages = await harness.db.select(harness.db.stages).get();

    expect(task.planDate, '2026-09-07', reason: '任务的开始不等于最早那个阶段的开始 —— 推导取错了边界');
    expect(task.endDate, '2026-09-09', reason: '任务的结束不等于最晚那个阶段的结束 —— 推导取错了边界');
    expect(
      stages.map((s) => s.durationMinutes),
      everyElement(60),
      reason: '有阶段的时长被推导动过了',
    );
  });
}

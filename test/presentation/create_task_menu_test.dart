/// 加号弹出的五选一面板（FR-TASK-01/02/03）。
///
/// 用户 2026-09-09 定的：「点击后出现悬浮小面板有 5 个选项，
/// 分别是 单事项、阶段事项、重复单事项、重复阶段事项、临时事项」。
///
/// 这一份验**选了之后表单变成什么样**——五样各自要求什么、
/// 默认值从哪来。表单内部那些控件本身在 `edit_task_test` 里另验。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/data/database/app_database.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/task/application/task_shape.dart';
import 'package:planning_assistant/features/task/presentation/create_task_menu.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';

import '../support/app_harness.dart';

Future<Harness> _pump(WidgetTester tester) async {
  await setScreenSize(tester, const Size(390, 844));
  final harness = appHarness();
  await tester.pumpWidget(
    ProviderScope(overrides: harness.overrides, child: PlanningAssistantApp()),
  );
  await tester.pumpAndSettle();
  return harness;
}

Future<TaskRow> _saveAs(
  WidgetTester tester,
  Harness harness,
  String title,
) async {
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), title);
  await tester.pump();
  await tapVisible(tester, TaskEditorPage.saveButtonKey);
  return (await harness.db.select(harness.db.tasks).get()).single;
}

void main() {
  group('面板本身', () {
    testAppWidgets('点加号弹出五个选项，一个不少', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(AppShell.fabKey));
      await tester.pumpAndSettle();

      for (final shape in TaskShape.values) {
        expect(
          find.byKey(createShapeKey(shape)),
          findsOneWidget,
          reason: '面板上没有「${shape.label}」',
        );
      }
    });

    testAppWidgets('每一项都有文字，不只是图标（NFR-A11Y-01）', (tester) async {
      // 这五样的区别是「有没有阶段」与「重不重复」，光靠图形分不出来。
      await _pump(tester);
      await tester.tap(find.byKey(AppShell.fabKey));
      await tester.pumpAndSettle();

      for (final shape in TaskShape.values) {
        expect(find.text(shape.label), findsOneWidget);
      }
    });

    testAppWidgets('点外面关掉 —— 什么也不建', (tester) async {
      final harness = await _pump(tester);
      await tester.tap(find.byKey(AppShell.fabKey));
      await tester.pumpAndSettle();

      // 点面板之外的地方。
      await tester.tapAt(const Offset(20, 120));
      await tester.pumpAndSettle();

      expect(find.byType(TaskEditorPage), findsNothing);
      expect(await harness.db.select(harness.db.tasks).get(), isEmpty);
    });

    testAppWidgets('**存一条仍然只要三次点击**（vision §成功标准）', (tester) async {
      // 「从点开 App 到任务落库 ≤ 3 次点击」。面板多了一步，
      // 所以这条要重新数一遍：加号、选一样、保存 —— 打字不算点击。
      //
      // 数出来是 3，正好卡在线上。**再加一步就破了**，
      // 所以这条用例是那个上限的守卫，不是记账。
      final harness = await _pump(tester);
      var taps = 0;

      await tester.tap(find.byKey(AppShell.fabKey));
      taps++;
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(createShapeKey(TaskShape.scratch)));
      taps++;
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '买菜');
      await tester.pump();

      await tapVisible(tester, TaskEditorPage.saveButtonKey);
      taps++;

      expect(taps, lessThanOrEqualTo(3));
      expect(
        (await harness.db.select(harness.db.tasks).get()).single.title,
        '买菜',
      );
    });
  });

  group('选了之后表单要求什么', () {
    testAppWidgets('临时事项：只填标题就能存，而且没有日期', (tester) async {
      // 「仅填标题即可保存」现在是这一档的性质（FR-TASK-01 的验收
      // 2026-09-09 改成这样）。
      final harness = await _pump(tester);
      await tapCreate(tester, TaskShape.scratch);
      final row = await _saveAs(tester, harness, '想想去哪玩');

      expect(row.planDate, isNull);
      expect(row.kind, 'single');
      expect(row.recurrenceRule, isNull);
    });

    testAppWidgets('单事项：默认是**全天 + 今天**，直接就能存', (tester) async {
      // ## 这一条 2026-09-10 换了默认值
      //
      // 原来是「今天 + 下一个整点 + 默认时长」。用户改成了
      // 「进来默认就是启用全天、日期今天」—— 两条入口（面板、日历翻到
      // 某天）说的其实是同一件事：**没人说几点，就别替他挑一个几点。**
      //
      // 必填不等于要用户从零填 —— 默认值仍然是**当场就能存**的。
      final harness = await _pump(tester);
      await tapCreate(tester, TaskShape.single);
      final row = await _saveAs(tester, harness, '写周报');

      expect(row.isAllDay, isTrue);
      expect(row.planDate, '2026-09-07');
      expect(row.endDate, '2026-09-07', reason: '全天就是一天');
      expect(row.startMinute, isNull);
      expect(row.endMinute, isNull);
    });

    testAppWidgets('关掉全天：结束是开始 +24 小时（配置项的默认档）', (tester) async {
      // `behavior.defaultDuration` 默认 24 小时 —— 于是拨成定时之后的
      // 默认任务**跨午夜**。这一条把那个后果钉住：它是用户选的默认，
      // 不是谁手滑写的。
      //
      // 这一栏 2026-09-10 起**只管定时任务**：全天没有「多长」可言。
      final harness = await _pump(tester);
      await tapCreate(tester, TaskShape.single);
      await tapVisible(tester, TaskEditorPage.allDaySwitchKey);
      final row = await _saveAs(tester, harness, '写周报');

      expect(row.startMinute, 12 * 60, reason: '默认开始不是下一个整点');
      expect(row.endDate, '2026-09-08', reason: '+24 小时该落到第二天');
      expect(row.endMinute, 12 * 60);
    });

    testAppWidgets('重复单事项：建出来带着重复规则', (tester) async {
      final harness = await _pump(tester);
      await tapCreate(tester, TaskShape.recurringSingle);
      final row = await _saveAs(tester, harness, '吃药');

      expect(row.recurrenceRule, isNotNull, reason: '选了重复却没有规则');
      expect(row.kind, 'single');
    });

    testAppWidgets('阶段事项：建出来是 staged', (tester) async {
      final harness = await _pump(tester);
      await tapCreate(tester, TaskShape.staged);
      // 阶段事项要 ≥2 个阶段才存得下去（填阶段在 `stage_*` 那几份里验），
      // 这里验的是**形态传到了表单上**：阶段区出现了。
      // 表单是个懒建的 `ListView`，阶段区在下面 —— 先滚过去。
      // 表单里不止一个 `Scrollable`（阶段列表自己也是），
      // 所以要指明滚哪一个 —— 同 `tapVisible` 里那段。
      await tester.scrollUntilVisible(
        find.byKey(TaskEditorPage.stageSectionKey),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(TaskEditorPage.stageSectionKey), findsOneWidget);
      expect(
        await harness.db.select(harness.db.tasks).get(),
        isEmpty,
        reason: '还没保存就落库了',
      );
    });
  });
}

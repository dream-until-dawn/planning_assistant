/// 子任务清单（FR-TASK-09）。
///
/// ## 又一条只有表的链路
///
/// `checklist_items` 表、它的 DAO、导出里的那一段，从 M1 就在 ——
/// 而领域层以上一片空白：没有实体、没有仓库方法、没有命令、没有界面。
/// 需求可追溯性门禁（`tool/check_traceability.py`）把它和 FR-TASK-07
/// 一起翻了出来，那时它是仅剩的两条「一个字都没落地」的 V1 需求之一。
///
/// ## 验收原话
///
/// > checklist 项**不参与甘特/时间轴排布**，只在详情页显示
///
/// 所以这里除了「建得出来、存得住」，还专门验**它不上视图** ——
/// 那是它与阶段的分界线。阶段撑长任务跨度、在甘特上分段；
/// 清单一样都不该有。哪天有人给清单项加上时间偏移，
/// 「不参与排布」那条会先红。
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

/// 在打开的编辑器里加一项清单，并填上标题。
Future<void> _addItem(WidgetTester tester, String title) async {
  await tapVisible(tester, TaskEditorPage.addChecklistKey);
  final fields = find.descendant(
    of: find.byKey(TaskEditorPage.checklistSectionKey),
    matching: find.byType(TextField),
  );
  await tester.enterText(fields.last, title);
  await tester.pump();
}

/// 建一条带清单的任务。
Future<void> _createWithChecklist(
  WidgetTester tester,
  String title,
  List<String> items,
) async {
  await tapCreate(tester);
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), title);
  await tester.pump();
  for (final i in items) {
    await _addItem(tester, i);
  }
  await tapVisible(tester, TaskEditorPage.saveButtonKey);
}

Future<void> _reopen(WidgetTester tester) async {
  await openEditorFromCard(tester);
}

/// 把清单区滚进视野。
///
/// **不滚就断言等于没断言**：清单区在表单最下面，`ListView` 的
/// cacheExtent 之外压根没建 —— 那时 `findsNothing` 恒真，
/// 而「找不到」正是这一族用例最想抓的失效。
Future<void> _scrollToChecklist(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(TaskEditorPage.checklistSectionKey),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testAppWidgets('加几项、保存、再打开还在', (tester) async {
    final harness = await _pumpApp(tester);
    await _createWithChecklist(tester, '出门', ['带伞', '买菜']);

    final rows = await harness.db.select(harness.db.checklistItems).get()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    expect(rows.map((r) => r.title), ['带伞', '买菜']);
    expect(rows.map((r) => r.orderIndex), [0, 1], reason: 'orderIndex 必须连续从 0');

    await _reopen(tester);
    await _scrollToChecklist(tester);
    expect(find.text('带伞'), findsOneWidget);
    expect(find.text('买菜'), findsOneWidget);
  });

  testAppWidgets('勾上之后存得住 —— 不会被下一次保存清掉', (tester) async {
    // 阶段就栽过这一次：`ReplaceStagesCommand` 整表写回时把状态
    // 换成了默认的 pending，用户的进度被静默清空。
    // 清单走同一个形状的命令，所以同一个坑要先钉住。
    final harness = await _pumpApp(tester);
    await _createWithChecklist(tester, '出门', ['带伞', '买菜']);

    await _reopen(tester);
    final first = (await harness.db.select(harness.db.checklistItems).get())
        .firstWhere((r) => r.orderIndex == 0);
    await tapVisible(tester, TaskEditorPage.checklistDoneKey(first.id));
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    expect(
      (await harness.db.select(harness.db.checklistItems).get())
          .firstWhere((r) => r.id == first.id)
          .isDone,
      isTrue,
    );

    // 再存一次，什么都不改。
    await _reopen(tester);
    await tapVisible(tester, TaskEditorPage.saveButtonKey);
    expect(
      (await harness.db.select(harness.db.checklistItems).get())
          .firstWhere((r) => r.id == first.id)
          .isDone,
      isTrue,
      reason: '什么都没改，一次保存就把勾掉的清空了',
    );
  });

  testAppWidgets('删掉一项：界面上没了，库里是墓碑', (tester) async {
    final harness = await _pumpApp(tester);
    await _createWithChecklist(tester, '出门', ['带伞', '买菜']);

    await _reopen(tester);
    final gone = (await harness.db.select(harness.db.checklistItems).get())
        .firstWhere((r) => r.title == '带伞');
    await tapVisible(tester, TaskEditorPage.checklistRemoveKey(gone.id));
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    final rows = await harness.db.select(harness.db.checklistItems).get();
    expect(rows, hasLength(2), reason: '物理删了 —— V3 对端只会看到「这条还在」');
    expect(rows.firstWhere((r) => r.id == gone.id).deletedAt, isNotNull);

    await _reopen(tester);
    await _scrollToChecklist(tester);
    // **两条一起看**：只验「带伞没了」的话，清单区没建出来时它也绿。
    expect(find.text('买菜'), findsOneWidget, reason: '清单区根本没渲染，下面那条就是自证');
    expect(find.text('带伞'), findsNothing);
  });

  testAppWidgets('空行不落库 —— 点了「加一项」没打字不算一项', (tester) async {
    final harness = await _pumpApp(tester);
    await tapCreate(tester);
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '出门');
    await tester.pump();
    await tapVisible(tester, TaskEditorPage.addChecklistKey);
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    expect(await harness.db.select(harness.db.checklistItems).get(), isEmpty);
  });

  group('**不参与时间排布**（FR-TASK-09 的验收原话）', () {
    testAppWidgets('清单不撑长任务跨度，也不在甘特上分段', (tester) async {
      // 这是清单与阶段的分界线。阶段会把跨度撑到最后一个阶段的结束
      // （data-model §4.7），并在甘特上分成几段。
      // 清单一样都不该有 —— 有的话它就是第二种阶段了。
      final harness = await _pumpApp(tester);
      await _createWithChecklist(tester, '出门', ['带伞', '买菜', '取快递']);

      final task = (await harness.db.select(harness.db.tasks).get()).single;
      expect(task.endDate, isNull, reason: '清单把任务的结束日期改了');
      expect(
        await harness.db.select(harness.db.stages).get(),
        isEmpty,
        reason: '清单项被当成阶段落库了 —— 那它就会上甘特',
      );

      // 卡片上不该出现「阶段 0/3」：那是阶段的进度，清单不算。
      expect(find.textContaining('阶段'), findsNothing);
    });

    testAppWidgets('三个视图上都只看得到任务本身，看不到清单项', (tester) async {
      await _pumpApp(tester);
      await _createWithChecklist(tester, '出门', ['带伞', '买菜']);

      for (final view in ['时间轴', '日历', '甘特']) {
        await tester.tap(find.text(view));
        await tester.pumpAndSettle();
        expect(
          find.text('带伞'),
          findsNothing,
          reason: '「$view」上出现了清单项 —— 它只该在详情页',
        );
      }
    });
  });

  testAppWidgets('清单与阶段可以同时有，互不影响', (tester) async {
    // 两者是**并列**的两种拆分，不是二选一。
    final harness = await _pumpApp(tester);
    await tapCreate(tester, TaskShape.staged);
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '搬家');
    await tester.pump();

    for (final name in ['打包', '搬运']) {
      await tapVisible(tester, TaskEditorPage.addStageKey);
      final fields = find.descendant(
        of: find.byKey(TaskEditorPage.stageSectionKey),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.last, name);
      await tester.pump();
    }
    await _addItem(tester, '找纸箱');
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    expect(await harness.db.select(harness.db.stages).get(), hasLength(2));
    expect(
      await harness.db.select(harness.db.checklistItems).get(),
      hasLength(1),
    );
    // 进度只数阶段（FR-TASK-02 的算式），清单不掺和。
    expect(find.textContaining('阶段 0/2'), findsOneWidget);
  });
}

/// 子任务清单（FR-TASK-09）—— **入口已经收起来了**。
///
/// ## 这一份 2026-09-10 换了守的东西
///
/// 用户：「把清单隐藏了，目前不需要这个」。于是编辑器上不再有那一区。
/// 原来这里的七条用例全是**驱动那个界面**的（点「加一项」、勾完成、
/// 删一项），入口没了，它们一条都跑不动。
///
/// 直接删掉是不对的：隐藏的是入口，**不是数据**。命令、表、DAO、
/// 导出里的那一段全都还在，草稿也照样把清单读进来、原样写回去。
/// 那条回写路径现在**没有任何界面会走**，也就没有任何人会发现它断了 ——
/// 而它一断，只要库里还有清单项，随便编辑一下那条任务就把它们抹了。
///
/// 所以这一份改成守两件事：
///
///  1. 那一区**确实不出现**（正面断言，不是「没人提过它」）；
///  2. 库里已有的清单项，**经过一次编辑保存之后还在**。
///
/// 第 2 条是这次改动真正的风险所在。它也顺带让「不参与时间排布」
/// 那条验收继续成立 —— 清单不撑长任务跨度、不上甘特。
///
/// 需求侧：FR-TASK-09 已经从 V1 挪到 V2（requirements.md），
/// 因为它的验收原话是「只在详情页显示」，而现在没有任何地方显示它。
/// 留在 V1 的话，追溯门禁会替一条界面上够不着的功能盖「已交付」的章。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/app_providers.dart';
import 'package:planning_assistant/data/database/app_database.dart';
import 'package:planning_assistant/domain/commands/task_command.dart';
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

/// 走真界面建一条单事项。起止是预填的，所以只要填个标题就能存。
Future<void> _createTask(WidgetTester tester, String title) async {
  await tapCreate(tester);
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), title);
  await tester.pump();
  await tapVisible(tester, TaskEditorPage.saveButtonKey);
}

/// 造出「库里有清单项」这个前置状态 —— 界面上已经没有入口了。
///
/// ## 走命令，不走库
///
/// 头一版直接 `into(checklistItems).insert(...)`。库里**确实**多了行
/// （`select` 数得到），而 `watchAllChecklistItems()` 那条流**一次都没再吐**，
/// 于是编辑器读到空清单，保存时把它们全打了墓碑 ——
/// 用例红在「清单没了」，而真正的原因是**夹具的写没被 drift 通知到**。
///
/// 排掉的路：显式 `notifyUpdates` 不管用；`pumpEventQueue()` 在 fake async
/// 里直接把用例挂死。走命令则是 app 自己那条路，流当场就吐 ——
/// **夹具与被测代码用同一条写路径，是这类问题最省事的解法。**
Future<void> _seedItems(
  WidgetTester tester,
  Harness harness,
  List<String> titles,
) async {
  final taskId = (await harness.db.select(harness.db.tasks).get()).single.id;
  final container = ProviderScope.containerOf(
    tester.element(find.byType(PlanningAssistantApp)),
  );
  await container
      .read(taskCommandDispatcherProvider)
      .dispatch(
        ReplaceChecklistCommand(
          taskId: taskId,
          items: [
            for (final (i, title) in titles.indexed)
              ChecklistItemSpec(id: 'seeded-$i', title: title, orderIndex: i),
          ],
        ),
      );
  await tester.pumpAndSettle();
}

Future<List<ChecklistItemRow>> _liveItems(Harness harness) async {
  final rows = await harness.db.select(harness.db.checklistItems).get();
  return [
    for (final r in rows)
      if (r.deletedAt == null) r,
  ];
}

void main() {
  testAppWidgets('清单区在编辑器上不出现', (tester) async {
    await _pumpApp(tester);
    await tapCreate(tester);

    // **要滚到底再断言**：`ListView` 只建看得见的那几项，
    // 不滚的话 `findsNothing` 对表单下半截恒真 —— 那时这条用例
    // 就算把整区画回来也照样绿。
    await tester.scrollUntilVisible(
      find.byKey(TaskEditorPage.saveButtonKey),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(TaskEditorPage.checklistSectionKey), findsNothing);
    expect(find.textContaining('清单'), findsNothing);
  });

  testAppWidgets('库里已有的清单项，编辑保存一次之后还在', (tester) async {
    // 这次改动真正的风险：入口没了，回写路径就没人走了 ——
    // 它一断，随便编辑一下那条任务就把清单抹了，而没有任何界面会喊。
    final harness = await _pumpApp(tester);
    await _createTask(tester, '出门');
    await _seedItems(tester, harness, ['带伞', '买菜']);
    expect((await _liveItems(harness)).length, 2, reason: '前提：夹具没把清单放进去');

    await openEditorFromCard(tester);
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '出门买菜');
    await tester.pump();
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    final rows = await _liveItems(harness)
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    expect(rows.map((r) => r.title), [
      '带伞',
      '买菜',
    ], reason: '保存把库里的清单抹了 —— 编辑器又去碰它了');
  });

  group('**不参与时间排布**（FR-TASK-09 的验收原话）', () {
    testAppWidgets('清单不撑长任务跨度，也不在甘特上分段', (tester) async {
      // 这是清单与阶段的分界线。阶段会把跨度撑到最后一个阶段的结束
      // （data-model §4.7），并在甘特上分成几段。
      // 清单一样都不该有 —— 有的话它就是第二种阶段了。
      final harness = await _pumpApp(tester);
      await _createTask(tester, '出门');
      final before = (await harness.db.select(harness.db.tasks).get()).single;
      await _seedItems(tester, harness, ['带伞', '买菜', '取快递']);

      await openEditorFromCard(tester);
      await tapVisible(tester, TaskEditorPage.saveButtonKey);

      final task = (await harness.db.select(harness.db.tasks).get()).single;
      expect(task.endDate, before.endDate, reason: '清单把任务的结束日期改了');
      expect(
        await harness.db.select(harness.db.stages).get(),
        isEmpty,
        reason: '清单项被当成阶段落库了 —— 那它就会上甘特',
      );
      // 卡片上不该出现「阶段 0/3」：那是阶段的进度，清单不算。
      expect(find.textContaining('阶段'), findsNothing);
    });

    testAppWidgets('三个视图上都只看得到任务本身，看不到清单项', (tester) async {
      final harness = await _pumpApp(tester);
      await _createTask(tester, '出门');
      await _seedItems(tester, harness, ['带伞', '买菜']);

      for (final view in ['时间轴', '日历', '甘特']) {
        await tester.tap(find.text(view));
        await tester.pumpAndSettle();
        expect(
          find.text('带伞'),
          findsNothing,
          reason: '「$view」上出现了清单项 —— 它不参与时间排布',
        );
      }
    });
  });
}

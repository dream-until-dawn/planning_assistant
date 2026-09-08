/// 删除与回收站（FR-TASK-08、task-lifecycle §1.1）。
///
/// ## 这一族债里最重的一笔
///
/// `DeleteTaskCommand` / `RestoreTaskCommand` 在领域层一直都在、也测过 ——
/// 而界面上**没有任何地方能删一条任务**。一个建了就删不掉的任务清单，
/// 用两天就没法用了。
///
/// 「删除进回收站、30 天内可恢复」这条需求于是一个字都没落地。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/design/theme/app_theme.dart';
import 'package:planning_assistant/features/settings/presentation/settings_page.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';
import 'package:planning_assistant/features/trash/presentation/trash_page.dart';

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

Future<void> _createTask(WidgetTester tester, String title) async {
  await tester.tap(find.byKey(AppShell.fabKey));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), title);
  await tester.pump();
  await tapVisible(tester, TaskEditorPage.saveButtonKey);
}

Future<void> _openTrash(WidgetTester tester) async {
  await tester.tap(find.byKey(AppShell.settingsKey));
  await tester.pumpAndSettle();
  await tapVisible(tester, SettingsPage.trashEntryKey);
}

void main() {
  testAppWidgets('删掉之后列表里没有了，而库里是墓碑不是真删', (tester) async {
    final harness = await _pumpApp(tester);
    await _createTask(tester, '买菜');
    expect(find.byType(TaskCard), findsOneWidget);

    await tester.tap(find.byType(TaskCard));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TaskEditorPage.deleteButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(TaskCard), findsNothing, reason: '删了还在列表上');

    // **软删除**：行还在，只是盖了墓碑（task-lifecycle §1.1）。
    // 物理删的话，回收站与将来的同步都无从谈起。
    final rows = await harness.db.select(harness.db.tasks).get();
    expect(rows, hasLength(1));
    expect(rows.single.deletedAt, isNotNull);
  });

  testAppWidgets('删完给一条撤销，点了就回来', (tester) async {
    // 删除是最需要反悔的操作，而「再点一次删除」不是撤销。
    await _pumpApp(tester);
    await _createTask(tester, '买菜');

    await tester.tap(find.byType(TaskCard));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TaskEditorPage.deleteButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('撤销'), findsOneWidget);
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();

    expect(find.byType(TaskCard), findsOneWidget);
    expect(find.text('买菜'), findsOneWidget);
  });

  testAppWidgets('新建页上没有删除入口 —— 那儿没东西可删', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(AppShell.fabKey));
    await tester.pumpAndSettle();
    expect(find.byKey(TaskEditorPage.deleteButtonKey), findsNothing);
  });

  testAppWidgets('哪怕把 onDeleted 接上，新建页也不显示删除', (tester) async {
    // ## 为什么要单独验这一条
    //
    // 上面那条走的是真路由，而真路由**根本没给新建页传 onDeleted** ——
    // 于是页面自己那句 `draft.isEditing &&` 去掉之后，上面那条照样绿
    // （变异演练里它活了下来）。两道守卫，只有外面那道被测到了。
    //
    // 这一条直接把 onDeleted 接上：那时只剩页面自己那道。
    await setScreenSize(tester, const Size(390, 844));
    final harness = appHarness();
    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: TaskEditorPage(onDeleted: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(TaskEditorPage.deleteButtonKey),
      findsNothing,
      reason: '新建页上出现了删除按钮 —— 那儿没东西可删',
    );
  });

  group('回收站', () {
    testAppWidgets('删掉的任务在里面，能恢复', (tester) async {
      await _pumpApp(tester);
      await _createTask(tester, '买菜');
      await tester.tap(find.byType(TaskCard));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TaskEditorPage.deleteButtonKey));
      await tester.pumpAndSettle();

      await _openTrash(tester);
      expect(find.byKey(TrashPage.pageKey), findsOneWidget);
      expect(find.text('买菜'), findsOneWidget);

      await tester.tap(
        find.descendant(of: find.byType(TrashPage), matching: find.text('恢复')),
      );
      await tester.pumpAndSettle();

      // 恢复之后回收站空了。
      expect(find.byKey(TrashPage.emptyKey), findsOneWidget);
    });

    testAppWidgets('一条都没删过时是空态，不是白屏', (tester) async {
      await _pumpApp(tester);
      await _createTask(tester, '买菜');
      await _openTrash(tester);
      expect(find.byKey(TrashPage.emptyKey), findsOneWidget);
    });

    testAppWidgets('恢复之后列表里又有了', (tester) async {
      await _pumpApp(tester);
      await _createTask(tester, '买菜');
      await tester.tap(find.byType(TaskCard));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TaskEditorPage.deleteButtonKey));
      await tester.pumpAndSettle();

      await _openTrash(tester);
      await tester.tap(
        find.descendant(of: find.byType(TrashPage), matching: find.text('恢复')),
      );
      await tester.pumpAndSettle();

      // 回到列表看一眼 —— 回收站空了不等于任务回到了活跃列表。
      Navigator.of(tester.element(find.byType(TrashPage))).pop();
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(SettingsPage))).pop();
      await tester.pumpAndSettle();

      expect(find.byType(TaskCard), findsOneWidget);
      expect(find.text('买菜'), findsOneWidget);
    });
  });
}

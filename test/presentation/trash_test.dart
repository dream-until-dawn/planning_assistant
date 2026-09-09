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
import 'package:planning_assistant/app_providers.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/design/theme/app_theme.dart';
import 'package:planning_assistant/domain/repositories/task_repository.dart';
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

/// 把回收站里那条任务的删除时刻挪到 [ago] 之前。
///
/// 走仓库而不是直接改库：`saveTask` 会不会把 `deletedAt` 顺手改掉
/// 是这条路径的一部分，绕开它就等于假设了它的行为。
Future<void> _backdate(WidgetTester tester, Duration ago) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(PlanningAssistantApp)),
  );
  final repo = container.read(taskRepositoryProvider);
  final now = container.read(clockProvider).nowUtc();
  final task = (await repo.findTasks(scope: TaskScope.trashed)).single;
  await repo.saveTask(task.copyWith(deletedAt: now.subtract(ago)));
  await tester.pumpAndSettle();
}

Future<void> _deleteFirst(WidgetTester tester) async {
  await tester.tap(find.byType(TaskCard));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(TaskEditorPage.deleteButtonKey));
  await tester.pumpAndSettle();
}

Future<void> _openTrash(WidgetTester tester) async {
  await tester.tap(find.byKey(AppShell.settingsKey));
  await tester.pumpAndSettle();
  await tapVisible(tester, SettingsPage.trashEntryKey);
}

void main() {
  testAppWidgets('FR-TASK-08 删掉之后列表里没有了，而库里是墓碑不是真删', (tester) async {
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
      await _deleteFirst(tester);

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
      await _deleteFirst(tester);

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

    group('还剩几天', () {
      // ## 这句话为什么值得单独测
      //
      // 它是**一句承诺**：写「还剩 12 天」就等于说 12 天内还能救回来。
      // 自动清理没接上之前这句话不敢写（那时只显示删除日期）；
      // 现在敢写了，就得保证它与清理判据说的是同一件事。
      testAppWidgets('刚删掉：还剩一整个保留期', (tester) async {
        await _pumpApp(tester);
        await _createTask(tester, '买菜');
        await _deleteFirst(tester);
        await _openTrash(tester);

        expect(find.textContaining('还剩 30 天'), findsOneWidget);
      });

      testAppWidgets('**差几小时到期时说「今天最后一天」，不说「还剩 1 天」**', (tester) async {
        // 29 天 20 小时。拿 `保留期 - 差值.inDays` 算的实现会显示
        // 「还剩 1 天」—— 而它今晚就被清了。这条测的正是那个差错。
        await _pumpApp(tester);
        await _createTask(tester, '买菜');
        await _deleteFirst(tester);
        await _backdate(tester, const Duration(days: 29, hours: 20));
        await _openTrash(tester);

        expect(find.textContaining('今天最后一天'), findsOneWidget);
        expect(find.textContaining('还剩'), findsNothing, reason: '多给了用户一天');
      });

      testAppWidgets('已过期但还没清：说清楚它什么时候没', (tester) async {
        // 清理只在启动时跑，所以「过期了还躺在这儿」是常态而非异常。
        await _pumpApp(tester);
        await _createTask(tester, '买菜');
        await _deleteFirst(tester);
        await _backdate(tester, const Duration(days: 40));
        await _openTrash(tester);

        expect(find.textContaining('下次启动时清理'), findsOneWidget);
      });

      testAppWidgets('保留期改小了，剩余天数跟着变', (tester) async {
        // 界面里写死 30 的实现在这里露馅。
        await _pumpApp(tester);
        await _createTask(tester, '买菜');
        await _deleteFirst(tester);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(PlanningAssistantApp)),
        );
        await container
            .read(settingsRepositoryProvider)
            .put('data.trashRetentionDays', 7, scope: 'global');
        await tester.pumpAndSettle();

        await _openTrash(tester);
        expect(find.textContaining('还剩 7 天'), findsOneWidget);
      });
    });
  });
}

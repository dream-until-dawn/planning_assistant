/// 多选与批量操作（view-specs §2.4「长按 → 进入多选模式，批量操作」）。
///
/// ## 这一批最容易做错的地方是语义，不是交互
///
/// 「完成一行」在重复任务上不是改 `tasks.status`，而是写一条例外；
/// 「删一行」是软删整条任务。批量若自己再判一遍「这行是某一次还是整条」，
/// 两处迟早分叉 —— 而分叉的表现是**「单个勾完成好好的，
/// 批量勾完成把整条重复任务标完成了」**，用户根本不会想到去比这两条路。
///
/// 所以批量动作**复用**单行动作，这里的用例也就重点验那件事：
/// 同一条重复任务，走批量和走单行，落库的形态要一样。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/app_providers.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/task/application/recurrence_draft.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';
import 'package:planning_assistant/features/views/task_list/presentation/task_list_page.dart';

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

Future<void> _create(
  WidgetTester tester,
  String title, {
  bool recurring = false,
}) async {
  await tester.tap(find.byKey(AppShell.fabKey));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), title);
  await tester.pump();
  if (recurring) {
    await tapVisible(tester, TaskEditorPage.recurrenceSwitchKey);
    await tapVisible(
      tester,
      TaskEditorPage.frequencyKey(RecurrenceFrequency.daily),
    );
  }
  await tapVisible(tester, TaskEditorPage.saveButtonKey);
}

/// 长按第 [i] 张卡片进入多选。
Future<void> _longPressCard(WidgetTester tester, int i) async {
  await tester.longPress(find.byType(TaskCard).at(i));
  await tester.pumpAndSettle();
}

void main() {
  group('进入与退出', () {
    testAppWidgets('长按一张卡片进入多选，选中条出现并显示数量', (tester) async {
      await _pumpApp(tester);
      await _create(tester, '买菜');
      expect(find.byKey(TaskListPage.selectionBarKey), findsNothing);

      await _longPressCard(tester, 0);

      expect(find.byKey(TaskListPage.selectionBarKey), findsOneWidget);
      expect(find.text('已选 1 项'), findsOneWidget);
    });

    testAppWidgets('多选模式下点卡片是选中，不是打开编辑', (tester) async {
      // 同一个手势在两种模式里做两件事 —— 走错的话，用户想多选
      // 却被弹进编辑页，而他刚长按建立起来的心智模型就断了。
      await _pumpApp(tester);
      await _create(tester, '买菜');
      await _create(tester, '取快递');

      await _longPressCard(tester, 0);
      await tester.tap(find.byType(TaskCard).at(1));
      await tester.pumpAndSettle();

      expect(find.byKey(TaskEditorPage.titleFieldKey), findsNothing);
      expect(find.text('已选 2 项'), findsOneWidget);
    });

    testAppWidgets('**把最后一个取消掉就退出多选**', (tester) async {
      // 「模式开着但一个都没选」是个能表达、却没人想清楚该长什么样的
      // 状态。不另存开关，模式 = 选中集合非空。
      await _pumpApp(tester);
      await _create(tester, '买菜');

      await _longPressCard(tester, 0);
      await tester.tap(find.byType(TaskCard).first);
      await tester.pumpAndSettle();

      expect(find.byKey(TaskListPage.selectionBarKey), findsNothing);
    });

    testAppWidgets('叉号退出多选，什么也不改', (tester) async {
      final harness = await _pumpApp(tester);
      await _create(tester, '买菜');

      await _longPressCard(tester, 0);
      await tapVisible(tester, TaskListPage.selectionCancelKey);

      expect(find.byKey(TaskListPage.selectionBarKey), findsNothing);
      final row = (await harness.db.select(harness.db.tasks).get()).single;
      expect(row.status, 'pending');
      expect(row.deletedAt, isNull);
    });

    testAppWidgets('多选模式下完成钮不响应 —— 一个框不表示两件事', (tester) async {
      await _pumpApp(tester);
      await _create(tester, '买菜');
      await _longPressCard(tester, 0);

      final button = tester.widget<TaskCard>(find.byType(TaskCard).first);
      expect(button.onToggleDone, isNull);
      expect(button.selected, isTrue);
    });
  });

  group('批量动作', () {
    testAppWidgets('批量完成两条，落库都变完成', (tester) async {
      final harness = await _pumpApp(tester);
      await _create(tester, '买菜');
      await _create(tester, '取快递');

      await _longPressCard(tester, 0);
      await tester.tap(find.byType(TaskCard).at(1));
      await tester.pumpAndSettle();
      await tapVisible(tester, TaskListPage.selectionDoneKey);

      final rows = await harness.db.select(harness.db.tasks).get();
      expect(rows.where((r) => r.status == 'done'), hasLength(2));
      // 做完之后退出多选 —— 否则那条选中条会一直挂着。
      expect(find.byKey(TaskListPage.selectionBarKey), findsNothing);
    });

    testAppWidgets('批量删除进回收站，不是物理删', (tester) async {
      final harness = await _pumpApp(tester);
      await _create(tester, '买菜');
      await _create(tester, '取快递');

      await _longPressCard(tester, 0);
      await tester.tap(find.byType(TaskCard).at(1));
      await tester.pumpAndSettle();
      await tapVisible(tester, TaskListPage.selectionDeleteKey);

      final rows = await harness.db.select(harness.db.tasks).get();
      expect(rows, hasLength(2), reason: '物理删了 —— 回收站与同步都无从谈起');
      expect(rows.where((r) => r.deletedAt != null), hasLength(2));
      expect(find.byType(TaskCard), findsNothing);
    });

    testAppWidgets('批量完成也给撤销，整批一起回到未完成', (tester) async {
      // **删除有撤销不等于完成也有。** 变异演练里「批量完成不给撤销」
      // 一开始活了下来 —— 因为撤销那条用例只验了删除。
      // 两个动作各自要有自己的撤销用例。
      final harness = await _pumpApp(tester);
      await _create(tester, '买菜');
      await _create(tester, '取快递');

      await _longPressCard(tester, 0);
      await tester.tap(find.byType(TaskCard).at(1));
      await tester.pumpAndSettle();
      await tapVisible(tester, TaskListPage.selectionDoneKey);
      expect(
        (await harness.db.select(harness.db.tasks).get()).where(
          (r) => r.status == 'done',
        ),
        hasLength(2),
        reason: '前提：两条都完成了',
      );

      expect(find.text('撤销'), findsOneWidget);
      await tester.tap(find.text('撤销'));
      await tester.pumpAndSettle();

      expect(
        (await harness.db.select(harness.db.tasks).get()).where(
          (r) => r.status == 'done',
        ),
        isEmpty,
        reason: '撤销之后还有留在完成状态的',
      );
    });

    testAppWidgets('**批量操作给一条撤销，整批一起回来**', (tester) async {
      // 单行滑动都配了撤销（§2.4），而批量一次动的是十几条 ——
      // 误触的代价按条数放大，撤销的必要性只会更高。
      final harness = await _pumpApp(tester);
      await _create(tester, '买菜');
      await _create(tester, '取快递');

      await _longPressCard(tester, 0);
      await tester.tap(find.byType(TaskCard).at(1));
      await tester.pumpAndSettle();
      await tapVisible(tester, TaskListPage.selectionDeleteKey);

      expect(find.text('撤销'), findsOneWidget);
      await tester.tap(find.text('撤销'));
      await tester.pumpAndSettle();

      final rows = await harness.db.select(harness.db.tasks).get();
      expect(
        rows.where((r) => r.deletedAt == null),
        hasLength(2),
        reason: '撤销只回来了一部分',
      );
    });
  });

  group('重复任务：批量与单行必须是同一套语义', () {
    testAppWidgets('批量完成一次发生，写的是例外，不是把整条标完成', (tester) async {
      // **这条是这一批的要害。** 重复任务的 `tasks.status` 恒为 pending
      // （data-model §4.3）；批量若走 `ChangeTaskStatusCommand`，
      // 领域层会直接抛，或者更糟 —— 悄悄把整条规则标成完成。
      final harness = await _pumpApp(tester);
      await _create(tester, '晨会', recurring: true);

      await _longPressCard(tester, 0);
      await tapVisible(tester, TaskListPage.selectionDoneKey);

      final task = (await harness.db.select(harness.db.tasks).get()).single;
      expect(task.status, 'pending', reason: '整条重复任务被标成完成了 —— 批量走了跟单行不一样的路');
      final overrides = await harness.db
          .select(harness.db.occurrenceOverrides)
          .get();
      expect(overrides, hasLength(1), reason: '没写例外 —— 那这一次的完成记在哪');
      expect(overrides.single.status, 'done');
    });

    testAppWidgets('同一条任务的两行一起选中，revision 只涨一格', (tester) async {
      // 一条逾期的重复任务在列表上有两行（逾期的那次 + 下一次，
      // 见 `expandForList`）。两行都选中再删，就会对同一条任务发两次删除。
      //
      // **挡住它的不是批量这一侧的去重**（那段代码写过又删了，见
      // `bulk_selection.dart` 里的注释），是 `softDeleteTask` 里
      // 那句 `if (task.isDeleted) return` —— 第二次连写都不写。
      //
      // 这条用例留着是因为那个性质值得钉住：重复删一条任务不该让
      // 同步信封的 revision 白涨，否则 V3 对端要为一条什么也没多变的
      // 记录再做一轮合并。与 R-05 那条是同一个判据。
      final harness = await _pumpApp(tester);
      await _create(tester, '晨会', recurring: true);

      // 把开始日挪到前天 —— 于是今天的列表上有「逾期」和「下一次」两行。
      final repo = ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
      ).read(taskRepositoryProvider);
      final task = (await repo.findTasks()).single;
      await repo.saveTask(task.copyWith(planDate: const PlanDate(2026, 9, 5)));
      await tester.pumpAndSettle();
      // **「逾期」组默认折叠**（§2.4），折叠时那几行压根没建出来。
      // 不展开的话下面选不到第二行，这条用例就成了自证。
      await tapVisible(tester, TaskListPage.groupHeaderKey('overdue'));
      expect(
        find.byType(TaskCard),
        findsAtLeast(2),
        reason: '前提：同一条任务要有两行才验得了去重',
      );

      final before = (await harness.db.select(harness.db.tasks).get()).single;

      await _longPressCard(tester, 0);
      await tester.tap(find.byType(TaskCard).at(1));
      await tester.pumpAndSettle();
      await tapVisible(tester, TaskListPage.selectionDeleteKey);

      final after = (await harness.db.select(harness.db.tasks).get()).single;
      expect(after.deletedAt, isNotNull, reason: '前提：删掉了');
      expect(
        after.revision,
        before.revision + 1,
        reason: '同一条任务被删了两次 —— revision 白涨了一格',
      );
    });

    testAppWidgets('选中的是「这一行」，不是同一条规则的每一行', (tester) async {
      // 选中集合存的是**行 id**。存 taskId 的话，选中「今天」
      // 会把同一条规则的其余各行也选上，而用户只点了一行。
      await _pumpApp(tester);
      await _create(tester, '晨会', recurring: true);
      await _create(tester, '买菜');

      await _longPressCard(tester, 0);
      expect(find.text('已选 1 项'), findsOneWidget);
    });
  });
}

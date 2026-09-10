/// 阶段与事项的**勾选状态双向同步**（用户第 6 条、task-lifecycle §4）。
///
/// ## 规则
///
///  · 勾事项 → 它的阶段都跟着勾；
///  · 勾阶段 → **全部勾完**事项才算完成；
///  · 两个方向都**可逆**（用户明确要的）。
///
/// ## 为什么要走界面而不是只测纯函数
///
/// `deriveStatusFromStages` 在领域层躺了很久，单测齐全，
/// **生产代码一个调用点都没有** —— 推导写好了，界面够不着。
/// 这个仓库反复撞上同一种缺陷（`isOverdue`、非重复的 `setStageDone`、
/// `primaryText` 的对比度…），它们的共同点是：
/// 纯函数那一侧全绿，而用户点下去什么也不会发生。
///
/// 所以这一份从卡片/弹层点起，一路验到库里的行。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/features/settings/application/registry.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/task/application/default_duration.dart';
import 'package:planning_assistant/features/task/application/recurrence_draft.dart';
import 'package:planning_assistant/features/task/application/task_shape.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';
import 'package:planning_assistant/features/views/calendar/presentation/calendar_page.dart';
import 'package:planning_assistant/features/views/shared/application/view_kind.dart';
import 'package:planning_assistant/features/views/shared/application/view_shared_state.dart';
import 'package:planning_assistant/features/views/task_list/presentation/occurrence_actions_sheet.dart';

import '../support/app_harness.dart';

const _today = PlanDate(2026, 9, 7);
const _tomorrow = PlanDate(2026, 9, 8);

Future<Harness> _pumpApp(
  WidgetTester tester, {
  bool advancingClock = false,
}) async {
  await setScreenSize(tester, const Size(390, 844));
  final harness = appHarness(advancingClock: advancingClock);
  await tester.pumpWidget(
    ProviderScope(overrides: harness.overrides, child: PlanningAssistantApp()),
  );
  await tester.pumpAndSettle();
  // 与 `stage_occurrence_test` 同一个理由：默认 +24 小时会让每天重复的
  // 两次在日历上叠着，而这一份要分别点开今天和明天那一次。
  await seedSetting(tester, defaultTaskDuration, DefaultTaskDuration.endOfDay);
  return harness;
}

/// 建一条带两个阶段的任务。[recurring] 为真时每天重复。
Future<void> _createStaged(
  WidgetTester tester, {
  bool recurring = false,
  List<String> names = const ['打包', '搬运'],
}) async {
  await tapCreate(
    tester,
    recurring ? TaskShape.recurringStaged : TaskShape.staged,
  );
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '搬家');
  await tester.pump();

  for (final name in names) {
    await addStage(tester, name);
  }

  if (recurring) {
    await tapVisible(
      tester,
      TaskEditorPage.frequencyKey(RecurrenceFrequency.daily),
    );
  }
  await tapVisible(tester, TaskEditorPage.saveButtonKey);
}

Future<void> _goToDay(WidgetTester tester, PlanDate date) async {
  if (find.byKey(CalendarPage.gridKey).evaluate().isEmpty) {
    await tapVisible(tester, AppShell.viewTabKey(ViewKind.calendar));
  }
  ProviderScope.containerOf(tester.element(find.byType(AppShell)))
      .read(viewSharedStateProvider.notifier)
      .focusDate(date);
  await tester.pumpAndSettle();
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byType(TaskCard).first);
  await tester.pumpAndSettle();
  expect(find.byKey(OccurrenceSheetKeys.sheet), findsOneWidget);
}

Future<void> _closeSheet(WidgetTester tester) async {
  final sheet = find.byKey(OccurrenceSheetKeys.sheet);
  if (sheet.evaluate().isEmpty) return;
  Navigator.of(tester.element(sheet)).pop();
  await tester.pumpAndSettle();
}

/// 弹层里勾/取消某一步。
Future<void> _tick(WidgetTester tester, String stageId) async {
  await tapVisible(tester, OccurrenceSheetKeys.stage(stageId));
  await tester.pumpAndSettle();
}

/// 弹层里那个勾选框现在是勾着的吗。
bool _ticked(WidgetTester tester, String stageId) => tester
    .widget<CheckboxListTile>(find.byKey(OccurrenceSheetKeys.stage(stageId)))
    .value!;

Future<List<String>> _stageIds(Harness harness) async {
  final rows = await harness.db.select(harness.db.stages).get();
  rows.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  return rows.map((r) => r.id).toList();
}

/// 库里阶段那一列的完成时刻，按 orderIndex。
Future<List<DateTime?>> _stageCompletedAt(Harness harness) async {
  final rows = await harness.db.select(harness.db.stages).get();
  rows.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  return [
    for (final r in rows)
      r.completedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(r.completedAt!, isUtc: true),
  ];
}

/// 库里阶段那一列的状态，按 orderIndex。
Future<List<String>> _stageStatuses(Harness harness) async {
  final rows = await harness.db.select(harness.db.stages).get();
  rows.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  return [for (final r in rows) r.status];
}

Future<String> _taskStatus(Harness harness) async =>
    (await harness.db.select(harness.db.tasks).get()).single.status;

/// 卡片上那个圆钮显示的是「已完成」吗。
///
/// 重复任务的 `tasks.status` 恒为 pending，这一行是不是完成只看
/// 这一次 —— 所以查库没用，得看卡片自己算出来的那个值。
bool _cardDone(WidgetTester tester) =>
    tester.widget<DoneButton>(find.byKey(TaskCard.doneButtonKey)).isDone;

void main() {
  group('不重复的阶段事项', () {
    testAppWidgets('勾事项 → 阶段都跟着勾；再取消 → 阶段都跟着回来（可逆）', (tester) async {
      final harness = await _pumpApp(tester);
      await _createStaged(tester);

      await tester.tap(find.byKey(TaskCard.doneButtonKey));
      await tester.pumpAndSettle();
      expect(await _taskStatus(harness), 'done');
      expect(await _stageStatuses(harness), ['done', 'done'], reason: '阶段没跟着勾');

      await tester.tap(find.byKey(TaskCard.doneButtonKey));
      await tester.pumpAndSettle();
      expect(await _taskStatus(harness), 'pending');
      expect(await _stageStatuses(harness), [
        'pending',
        'pending',
      ], reason: '取消完成时阶段没回滚 —— 用户要的是可逆');
    });

    testAppWidgets('**用户自己勾过的那一步，取消完成时留着**', (tester) async {
      // 评审打回来的那条（M-B1）。我原来的论证是「显式标完成时，
      // 用户那份进度在标完成的那一下就已经被盖掉了」——
      // **对已经 done 的阶段这句是假的**：级联刻意跳过它们
      // （那是我自己在 `completeTaskWithStages` 里写的），一次都没碰过。
      // 而回滚却回滚所有 done 的阶段，于是把用户亲手勾的那一步抹了。
      //
      // 这也和同一个改动里对 `skipped` 的处理自相矛盾：
      // 「这一步跳过」保得住，「这一步做完了」保不住，两者都是用户亲手记的。      //
      // ## 这条**不是**领域层那条的重复，别精简掉
      //
      // 领域层那条（`task_lifecycle_test`）验的是判据本身写得对不对，
      // 全程在内存里。这条走真库，多验一件它验不到的事：
      // **完成时刻存进去再读出来，还比得相等吗。**
      //
      // `completedAt` 落库是 `millisecondsSinceEpoch`（INT 列），
      // 而内存里的 `DateTime` 在 VM 上带微秒。今天两边都是从库里读出来的
      // （任务与阶段各查一次），截断得一样多，所以相等还成立；
      // 但只要有人把其中一侧换成现算的 `_now()`，截断就会让本该相等的
      // 两个值不等 —— 判据当场退化成「什么都不收回」，
      // 正是钉死时钟那个失效模式的反方向。
      //
      // 那个风险现在是**潜伏**的，不是活的。而这条用例就是它一旦变活时
      // 唯一会红的东西 —— 看到「领域层已经测过同样的事」就把它剪掉，
      // 剪掉的正是这个。（评审提的；与 §1.11.1 同一族：
      // 两条测试看着测同一件事，实际测的是不同的失效模式。）
      final harness = await _pumpApp(tester, advancingClock: true);
      await _createStaged(tester);
      final stages = await _stageIds(harness);

      // ① 用户自己勾第一步 —— 早于任何级联。
      await tapVisible(tester, TaskCard.stageKey(stages[0]));
      await tester.pumpAndSettle();
      expect(await _stageStatuses(harness), ['done', 'pending']);

      // ② 显式标完成：级联只补第二步，第一步原样不动。
      await tester.tap(find.byKey(TaskCard.doneButtonKey));
      await tester.pumpAndSettle();
      expect(await _stageStatuses(harness), ['done', 'done']);

      // **前提**：两步的完成时刻必须不同 —— 「哪些是级联写的」正是靠
      // 「完成时刻与任务的完成时刻相同」认出来的。钉死的时钟下两者
      // 会相等，判据当场退化成「全都是级联写的」，这条用例也就
      // 不再验它想验的东西了。所以这里用会走的时钟，并且明写这条前提。
      final at = await _stageCompletedAt(harness);
      expect(at[0], isNot(at[1]), reason: '两步完成于同一时刻，这条用例分辨不出「谁写的」');

      // ③ 取消完成：只收回级联补的那一步。
      await tester.tap(find.byKey(TaskCard.doneButtonKey));
      await tester.pumpAndSettle();
      expect(await _stageStatuses(harness), [
        'done',
        'pending',
      ], reason: '用户自己勾的第一步被取消完成抹掉了');
    });

    testAppWidgets('对照组：全是级联写的，取消完成就全收回', (tester) async {
      // 少了这条，上一条分不清「只收回级联写的」与「什么都不收回」。
      final harness = await _pumpApp(tester, advancingClock: true);
      await _createStaged(tester);

      await tester.tap(find.byKey(TaskCard.doneButtonKey));
      await tester.pumpAndSettle();
      expect(await _stageStatuses(harness), ['done', 'done']);

      await tester.tap(find.byKey(TaskCard.doneButtonKey));
      await tester.pumpAndSettle();
      expect(await _stageStatuses(harness), ['pending', 'pending']);
    });

    testAppWidgets('**勾满了才算完成**：勾一个不算，勾完第二个才算', (tester) async {
      final harness = await _pumpApp(tester);
      await _createStaged(tester);
      final stages = await _stageIds(harness);

      await _openSheet(tester);
      await _tick(tester, stages[0]);
      await _closeSheet(tester);
      expect(
        await _taskStatus(harness),
        isNot('done'),
        reason: '只勾了一半就把事项标完成了',
      );

      await _openSheet(tester);
      await _tick(tester, stages[1]);
      await _closeSheet(tester);
      expect(await _taskStatus(harness), 'done', reason: '全勾完了，事项还不算完成');
    });

    testAppWidgets('取消其中一个阶段 → 事项不再是完成', (tester) async {
      final harness = await _pumpApp(tester);
      await _createStaged(tester);
      final stages = await _stageIds(harness);

      await tester.tap(find.byKey(TaskCard.doneButtonKey));
      await tester.pumpAndSettle();
      expect(await _taskStatus(harness), 'done', reason: '前提：先完成了');

      await _openSheet(tester);
      await _tick(tester, stages[0]);
      await _closeSheet(tester);
      expect(await _taskStatus(harness), isNot('done'));
    });

    testAppWidgets('**弹层里的勾选框认得不重复任务的状态**', (tester) async {
      // 状态有两个存储位置：不重复在 `Stage.status`，重复在那张表。
      // 弹层一度只会读后者（对不重复的行拿到一张空表），于是
      // **不重复任务的勾选框永远是空的** —— 勾完关掉再打开，还是空的。
      final harness = await _pumpApp(tester);
      await _createStaged(tester);
      final stages = await _stageIds(harness);

      await _openSheet(tester);
      await _tick(tester, stages[0]);
      expect(_ticked(tester, stages[0]), isTrue, reason: '勾完当场就没打上勾');
      await _closeSheet(tester);

      await _openSheet(tester);
      expect(_ticked(tester, stages[0]), isTrue, reason: '重新打开，勾没了');
      expect(_ticked(tester, stages[1]), isFalse);
      await _closeSheet(tester);
    });

    testAppWidgets('**撤销保住已经勾过的那一步**', (tester) async {
      // 撤销若只是发一条反向的状态命令，走的是同一套级联
      // （已完成的全回 pending），它不知道哪一步本来就勾着 ——
      // 于是「完成 → 撤销」把进度从 1/2 抹成 0/2。
      final harness = await _pumpApp(tester);
      await _createStaged(tester);
      final stages = await _stageIds(harness);

      await _openSheet(tester);
      await _tick(tester, stages[0]);
      await _closeSheet(tester);

      await tester.tap(find.byKey(TaskCard.doneButtonKey));
      await tester.pumpAndSettle();
      expect(await _stageStatuses(harness), ['done', 'done']);

      await tester.tap(find.text('撤销'));
      await tester.pumpAndSettle();
      expect(await _stageStatuses(harness), [
        'done',
        'pending',
      ], reason: '撤销把用户自己勾的那一步也抹了');
    });
  });

  group('列表上的阶段子项（用户第 ② 条）', () {
    testAppWidgets('阶段摊在卡片下面，每一步一行', (tester) async {
      final harness = await _pumpApp(tester);
      await _createStaged(tester);
      final stages = await _stageIds(harness);

      expect(find.text('打包'), findsOneWidget);
      expect(find.text('搬运'), findsOneWidget);
      for (final id in stages) {
        expect(find.byKey(TaskCard.stageKey(id)), findsOneWidget);
      }
      // 摘要那一行照常在 —— 子项是明细，它是合计。
      expect(find.textContaining('阶段 0/2'), findsOneWidget);
    });

    testAppWidgets('在子项上勾一步，落库并且进度跟着变', (tester) async {
      final harness = await _pumpApp(tester);
      await _createStaged(tester);
      final stages = await _stageIds(harness);

      await tapVisible(tester, TaskCard.stageKey(stages[0]));
      await tester.pumpAndSettle();

      expect(await _stageStatuses(harness), ['done', 'pending']);
      expect(find.textContaining('阶段 1/2'), findsOneWidget);
      expect(_cardDone(tester), isFalse, reason: '只勾了一步就整条算完成了');

      await tapVisible(tester, TaskCard.stageKey(stages[1]));
      await tester.pumpAndSettle();
      expect(_cardDone(tester), isTrue, reason: '两步都勾完了，整条还不算完成');
    });

    testAppWidgets('再点一下取消，事项也跟着不再完成', (tester) async {
      final harness = await _pumpApp(tester);
      await _createStaged(tester);
      final stages = await _stageIds(harness);

      for (final id in stages) {
        await tapVisible(tester, TaskCard.stageKey(id));
        await tester.pumpAndSettle();
      }
      expect(_cardDone(tester), isTrue, reason: '前提：先全勾上');

      await tapVisible(tester, TaskCard.stageKey(stages[0]));
      await tester.pumpAndSettle();
      expect(await _stageStatuses(harness), ['pending', 'done']);
      expect(_cardDone(tester), isFalse);
    });

    testAppWidgets('**改了某一步，就把那条可能过期的撤销撤下来**', (tester) async {
      // 撤销闭包捕获的是点完成那一刻的阶段快照。提示还挂着的时候
      // 用户改了某一步，那份快照当场过期 —— 再点撤销会把这次改动盖掉。
      // 能撤销的窗口短一点，好过撤销做错事。
      final harness = await _pumpApp(tester);
      await _createStaged(tester);
      final stages = await _stageIds(harness);

      await tester.tap(find.byKey(TaskCard.doneButtonKey));
      await tester.pumpAndSettle();
      expect(find.text('撤销'), findsOneWidget, reason: '前提：提示挂着');

      await tapVisible(tester, TaskCard.stageKey(stages[0]));
      await tester.pumpAndSettle();
      expect(find.text('撤销'), findsNothing);
    });

    testAppWidgets('没有阶段的任务不摊出任何子项', (tester) async {
      // 对照组。少了它，「摊子项」这条断言在一个**永远摊**的实现下
      // 也全绿 —— 而那样每张卡片下面都会多出一片空白。
      await _pumpApp(tester);
      await tapCreate(tester);
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '买菜');
      await tester.pump();
      await tapVisible(tester, TaskEditorPage.saveButtonKey);

      expect(find.byType(TaskCard), findsOneWidget, reason: '前提：卡片在');
      expect(find.byType(Checkbox), findsNothing);
    });

    testAppWidgets('**只有列表摊**：日历上的同一条任务没有子项', (tester) async {
      // 日历的卡片挤在格子里，多摞几行会把同一天的其它任务顶出去。
      final harness = await _pumpApp(tester);
      await _createStaged(tester);
      final stages = await _stageIds(harness);
      expect(find.byKey(TaskCard.stageKey(stages[0])), findsOneWidget);

      await _goToDay(tester, _today);
      expect(find.byType(TaskCard), findsWidgets, reason: '前提：日历上有这张卡片');
      for (final id in stages) {
        expect(find.byKey(TaskCard.stageKey(id)), findsNothing);
      }
    });

    testAppWidgets('多选模式下子项不响应', (tester) async {
      // 与完成钮同一条：模式开着时，卡片上的每个框都该表示「选中」。
      final harness = await _pumpApp(tester);
      await _createStaged(tester);
      final stages = await _stageIds(harness);

      await tester.longPress(find.byType(TaskCard).first);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Checkbox>(find.byKey(TaskCard.stageKey(stages[0])))
            .onChanged,
        isNull,
      );
    });
  });

  group('重复的阶段事项：每一次各算各的', () {
    testAppWidgets('把某一次标完成 → 只有那一次的阶段跟着勾', (tester) async {
      final harness = await _pumpApp(tester);
      await _createStaged(tester, recurring: true);
      final stages = await _stageIds(harness);

      await _goToDay(tester, _today);
      await _openSheet(tester);
      await tapVisible(tester, OccurrenceSheetKeys.toggleDone);
      await tester.pumpAndSettle();

      await _openSheet(tester);
      expect(_ticked(tester, stages[0]), isTrue);
      expect(_ticked(tester, stages[1]), isTrue);
      await _closeSheet(tester);

      await _goToDay(tester, _tomorrow);
      await _openSheet(tester);
      for (final id in stages) {
        expect(_ticked(tester, id), isFalse, reason: '另一次也跟着勾上了');
      }
      await _closeSheet(tester);

      expect(await _stageStatuses(harness), [
        'pending',
        'pending',
      ], reason: '重复任务的 Stage.status 恒为 pending（data-model §4.3）');
    });

    testAppWidgets('勾满某一次的阶段 → 那一次算完成，别的次不动', (tester) async {
      final harness = await _pumpApp(tester);
      await _createStaged(tester, recurring: true);
      final stages = await _stageIds(harness);

      await _goToDay(tester, _today);
      await _openSheet(tester);
      await _tick(tester, stages[0]);
      await _closeSheet(tester);
      expect(_cardDone(tester), isFalse, reason: '只勾了一半，这一次就算完成了');

      await _openSheet(tester);
      await _tick(tester, stages[1]);
      await _closeSheet(tester);
      expect(_cardDone(tester), isTrue, reason: '全勾完了，这一次还不算完成');

      await _goToDay(tester, _tomorrow);
      expect(_cardDone(tester), isFalse, reason: '明天那一次被今天的进度带成完成了');
    });

    testAppWidgets('**用户自己勾过的那一步，取消这一次的完成时留着**', (tester) async {
      // 任务侧那条（M-B1）的另一半。两张表各存各的，规则必须是同一条 ——
      // 只改一条路，正是这个仓库反复踩的形状。
      //
      // 与上面那条不重复的同理，这条也走真库，覆盖「完成时刻存进去
      // 再读出来还比得相等吗」——`stage_occurrence_states` 与
      // `occurrence_overrides` 的 `completed_at` 都是毫秒 INT 列。
      // 别因为「领域层测过判据」就精简掉。
      final harness = await _pumpApp(tester, advancingClock: true);
      await _createStaged(tester, recurring: true);
      final stages = await _stageIds(harness);

      await _goToDay(tester, _today);
      // ① 用户自己勾第一步。
      await _openSheet(tester);
      await _tick(tester, stages[0]);
      await _closeSheet(tester);

      // ② 把这一次标完成 —— 级联只补第二步。
      await _openSheet(tester);
      await tapVisible(tester, OccurrenceSheetKeys.toggleDone);
      await tester.pumpAndSettle();

      // ③ 取消完成。
      await _openSheet(tester);
      await tapVisible(tester, OccurrenceSheetKeys.toggleDone);
      await tester.pumpAndSettle();

      await _openSheet(tester);
      expect(_ticked(tester, stages[0]), isTrue, reason: '用户自己勾的那一步被抹了');
      expect(_ticked(tester, stages[1]), isFalse, reason: '级联补的那一步该收回');
      await _closeSheet(tester);
    });

    testAppWidgets('取消某一次的完成 → 只清那一次的阶段', (tester) async {
      final harness = await _pumpApp(tester);
      await _createStaged(tester, recurring: true);
      final stages = await _stageIds(harness);

      await _goToDay(tester, _today);
      await _openSheet(tester);
      await tapVisible(tester, OccurrenceSheetKeys.toggleDone);
      await tester.pumpAndSettle();

      await _openSheet(tester);
      await tapVisible(tester, OccurrenceSheetKeys.toggleDone);
      await tester.pumpAndSettle();

      await _openSheet(tester);
      for (final id in stages) {
        expect(_ticked(tester, id), isFalse, reason: '取消完成之后阶段没回滚');
      }
      await _closeSheet(tester);

      final states = await harness.db
          .select(harness.db.stageOccurrenceStates)
          .get();
      expect(
        states.where((s) => s.status == 'done'),
        isEmpty,
        reason: '库里还留着 done 的阶段状态',
      );
    });
  });
}

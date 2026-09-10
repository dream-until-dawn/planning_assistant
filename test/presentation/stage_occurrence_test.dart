/// 重复的阶段事项：每一次各记各的进度（FR-TASK-07）。
///
/// ## 用户会怎么撞见它
///
/// 「每周三·健身」拆成热身 / 主训 / 拉伸。这周三做完热身，勾掉它 ——
/// 在这个提交之前，**下周三打开也是「1/3」**，因为阶段状态只有
/// `Stage.status` 一份，整条任务共用。
///
/// 表 `stage_occurrence_states` 从 M1 就在库里，导出也带着它，
/// 而领域层以上一片空白。又是「模型有旋钮、界面够不着」——
/// 这次连领域层都没接。
///
/// 这里走真库、真路由，从建任务一路验到卡片上的数字。
/// 纯函数那一侧在 `test/domain/stage_occurrence_state_test.dart`。
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

/// 夹具的今天与明天。
const _today = PlanDate(2026, 9, 7);
const _tomorrow = PlanDate(2026, 9, 8);

Future<Harness> _pumpApp(WidgetTester tester) async {
  await setScreenSize(tester, const Size(390, 844));
  final harness = appHarness();
  await tester.pumpWidget(
    ProviderScope(overrides: harness.overrides, child: PlanningAssistantApp()),
  );
  await tester.pumpAndSettle();
  // **默认时长改成「到当天结束」。**
  //
  // 出厂默认是 +24 小时（用户定的），于是每一次发生都盖到第二天 ——
  // 一条每天重复的任务，两次在日历上叠着。这一份要「连着两天各看一次」，
  // 叠着就分不清点开的是哪一次了。
  //
  // 这不是绕开那个默认值，是**把它从这一份的变量里拿掉**：
  // 这里验的是每次发生各存各的阶段状态（FR-TASK-07），
  // 跟默认时长没关系。跨天叠加本身另有用例管。
  await seedSetting(tester, defaultTaskDuration, DefaultTaskDuration.endOfDay);
  return harness;
}

/// 建一条每天重复、带三个阶段的任务。
///
/// **用「每天」而不是「每周」**：要连着两天各看一次，
/// 而每周的下一次在七天后。
Future<void> _createRecurringStaged(WidgetTester tester) async {
  await tapCreate(tester, TaskShape.recurringStaged);
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '健身');
  await tester.pump();

  for (final name in ['热身', '主训', '拉伸']) {
    await addStage(tester, name);
  }

  await tapVisible(
    tester,
    TaskEditorPage.frequencyKey(RecurrenceFrequency.daily),
  );
  await tapVisible(tester, TaskEditorPage.saveButtonKey);
}

/// 切到日历，并把聚焦日挪到 [date]。
///
/// **不能靠列表看两次发生**：列表对重复任务只展开「逾期的 + 下一次」
/// （`expandForList` 的注释写着理由），一条每天重复的任务在那儿
/// 永远只有一行。要连着看两天，得用对着某一天的视图。
Future<void> _goToDay(WidgetTester tester, PlanDate date) async {
  if (find.byKey(CalendarPage.gridKey).evaluate().isEmpty) {
    await tapVisible(tester, AppShell.viewTabKey(ViewKind.calendar));
  }
  ProviderScope.containerOf(tester.element(find.byType(AppShell)))
      .read(viewSharedStateProvider.notifier)
      .focusDate(date);
  await tester.pumpAndSettle();
}

/// 打开当天那一行的动作弹层。
Future<void> _openSheet(WidgetTester tester) async {
  // 这里要的是**抽屉本身**（在里面勾阶段），不是进编辑页。
  await tester.tap(find.byType(TaskCard).first);
  await tester.pumpAndSettle();
  expect(find.byKey(OccurrenceSheetKeys.sheet), findsOneWidget);
}

Future<void> _closeSheet(WidgetTester tester) async {
  Navigator.of(tester.element(find.byKey(OccurrenceSheetKeys.sheet))).pop();
  await tester.pumpAndSettle();
}

/// 弹层里勾掉某一步。
Future<void> _tick(WidgetTester tester, String stageId) async {
  await tapVisible(tester, OccurrenceSheetKeys.stage(stageId));
  await tester.pumpAndSettle();
}

/// 库里那三个阶段，按顺序。
Future<List<String>> _stageIds(Harness harness) async {
  final rows = await harness.db.select(harness.db.stages).get();
  rows.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  return rows.map((r) => r.id).toList();
}

void main() {
  testAppWidgets('**这一次勾了，另一次还是没勾**（R-50/R-51）', (tester) async {
    final harness = await _pumpApp(tester);
    await _createRecurringStaged(tester);
    final stages = await _stageIds(harness);

    await _goToDay(tester, _today);
    await _openSheet(tester);
    await _tick(tester, stages[1]); // 主训
    await _closeSheet(tester);

    // 今天这一次：主训已勾。
    await _openSheet(tester);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(OccurrenceSheetKeys.stage(stages[1])),
          )
          .value,
      isTrue,
    );
    await _closeSheet(tester);

    // 明天那一次：一步都没做。
    await _goToDay(tester, _tomorrow);
    await _openSheet(tester);
    for (final id in stages) {
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(OccurrenceSheetKeys.stage(id)))
            .value,
        isFalse,
        reason: '另一次跟着变完成了 —— 阶段状态还是整条任务共用的那一份',
      );
    }
    await _closeSheet(tester);
  });

  testAppWidgets('卡片上的进度也按这一次算', (tester) async {
    // 弹层对了而卡片没对的话，用户看到的是「列表说 0/3，点进去说 1/3」。
    final harness = await _pumpApp(tester);
    await _createRecurringStaged(tester);
    final stages = await _stageIds(harness);

    await _goToDay(tester, _today);
    expect(find.textContaining('0/3'), findsOneWidget);

    await _openSheet(tester);
    await _tick(tester, stages[0]);
    await _closeSheet(tester);

    expect(find.textContaining('1/3'), findsOneWidget, reason: '今天这一次该是 1/3');

    await _goToDay(tester, _tomorrow);
    expect(find.textContaining('0/3'), findsOneWidget, reason: '明天那一次仍是 0/3');
  });

  testAppWidgets('落库的是「这一步·这一次」，不是阶段本身', (tester) async {
    // 写进 `stages.status` 的实现在这里露馅：那一份是整条任务共用的。
    final harness = await _pumpApp(tester);
    await _createRecurringStaged(tester);
    final stages = await _stageIds(harness);

    await _openSheet(tester);
    await _tick(tester, stages[2]);
    await _closeSheet(tester);

    final states = await harness.db
        .select(harness.db.stageOccurrenceStates)
        .get();
    expect(states, hasLength(1));
    expect(states.single.stageId, stages[2]);
    expect(states.single.status, 'done');
    expect(states.single.completedAt, isNotNull, reason: '标了完成却没有完成时刻');

    final stageRows = await harness.db.select(harness.db.stages).get();
    expect(
      stageRows.where((s) => s.status == 'done'),
      isEmpty,
      reason: '写到 stages.status 上了 —— 那一份是每一次共用的',
    );
  });

  testAppWidgets('再点一下取消，完成时刻一并清掉', (tester) async {
    // 与 `applyStatusChange` 同一条不变量：completedAt 与 status 同进同退。
    // 不清的话，下次它显示成「未完成，但完成于上周三」。
    final harness = await _pumpApp(tester);
    await _createRecurringStaged(tester);
    final stages = await _stageIds(harness);

    await _openSheet(tester);
    await _tick(tester, stages[0]);
    await _tick(tester, stages[0]);
    await _closeSheet(tester);

    final states = await harness.db
        .select(harness.db.stageOccurrenceStates)
        .get();
    expect(states, hasLength(1), reason: '连点两下攒出了两行互相矛盾的状态');
    expect(states.single.status, 'pending');
    expect(states.single.completedAt, isNull);
  });

  testAppWidgets('**编辑器里不给重复任务勾阶段** —— 那一列没人读', (tester) async {
    // `Stage.status` 对重复任务是**死数据**：状态按每一次存
    // （data-model §3.2 的「死数据」那一段）。编辑器编的是整条任务，
    // 在那儿勾写进的是那一列 —— 勾了没反应，比没有这个框更糟。
    //
    // 序号顶上原来那个框的位置（它本来就是让位给勾选框的）。
    final harness = await _pumpApp(tester);
    await _createRecurringStaged(tester);
    final stages = await _stageIds(harness);

    await openEditorFromCard(tester);

    // **先滚到阶段区。** 不滚的话它压根没建出来，
    // 下面那句 `findsNothing` 就是自证（§1.11 那族）。
    await tester.scrollUntilVisible(
      find.byKey(TaskEditorPage.stageSectionKey),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('热身'), findsOneWidget, reason: '阶段区没渲染，下面那条就是自证');

    for (final id in stages) {
      expect(
        find.byKey(TaskEditorPage.stageDoneKey(id)),
        findsNothing,
        reason: '重复任务的编辑器里出现了阶段勾选框 —— 勾了不会有任何效果',
      );
    }
  });

  testAppWidgets('对照组：不重复的阶段任务里，编辑器照常给勾', (tester) async {
    // 少了这条，一个「一律不显示勾选框」的实现能让上面绿 ——
    // 而那会把不重复任务的阶段完成入口一起端掉（那是 M3 补过的债）。
    final harness = await _pumpApp(tester);
    await tapCreate(tester, TaskShape.staged);
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '搬家');
    await tester.pump();
    for (final name in ['打包', '搬运']) {
      await addStage(tester, name);
    }
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    await openEditorFromCard(tester);

    final ids = await _stageIds(harness);
    await tester.scrollUntilVisible(
      find.byKey(TaskEditorPage.stageSectionKey),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(TaskEditorPage.stageDoneKey(ids.first)), findsOneWidget);
  });

  testAppWidgets('**把单项任务改成重复，勾过的进度不会消失**', (tester) async {
    // 阶段状态有两个存储位置（不重复看 `Stage.status`，重复看那张表），
    // 于是改重复规则会改变「该读哪一份」。不迁移的话，用户勾过的进度
    // **当场从界面上消失** —— 数据一条没丢，只是读路径改看另一张空表。
    // 这类「没丢但看不见」比真丢更难查：没有任何报错。
    final harness = await _pumpApp(tester);

    // 建一条不重复的两阶段任务，勾掉第一步。
    await tapCreate(tester, TaskShape.staged);
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '搬家');
    await tester.pump();
    for (final name in ['打包', '搬运']) {
      await addStage(tester, name);
    }
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    final ids = await _stageIds(harness);
    await openEditorFromCard(tester);
    await tapVisible(tester, TaskEditorPage.stageDoneKey(ids.first));
    await tapVisible(tester, TaskEditorPage.saveButtonKey);
    expect(find.textContaining('阶段 1/2'), findsOneWidget, reason: '前提：勾上了');

    // 改成每天重复。**这一处要真的去拨开关** —— 它是从「不重复」
    // 转成「重复」，而不是新建时就选了重复形态。
    await openEditorFromCard(tester);
    await tapVisible(tester, TaskEditorPage.recurrenceSwitchKey);
    await tapVisible(
      tester,
      TaskEditorPage.frequencyKey(RecurrenceFrequency.daily),
    );
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    // **界面上仍然是 1/2** —— 进度搬到了第一次发生上。
    expect(
      find.textContaining('阶段 1/2'),
      findsOneWidget,
      reason: '改成重复之后勾过的进度不见了',
    );

    // 落库形态：阶段那一列归零，状态搬进了那张表。
    final stageRows = await harness.db.select(harness.db.stages).get();
    expect(
      stageRows.where((r) => r.status == 'done'),
      isEmpty,
      reason: '`Stage.status` 对重复任务是死数据，不该还留着 done',
    );
    final states = await harness.db
        .select(harness.db.stageOccurrenceStates)
        .get();
    expect(states, hasLength(1));
    expect(states.single.stageId, ids.first);
    expect(states.single.status, 'done');
  });

  testAppWidgets('**关掉重复时，第一次发生的进度搬回阶段勾选框**', (tester) async {
    // 阶段状态有两个存储位置：不重复看 `Stage.status`，重复看那张表。
    // 关掉重复之后读路径改看前者，而草稿里那一份对重复任务恒为 pending
    // （界面上根本不给勾）—— 不搬的话，用户勾过的进度**当场从界面上
    // 消失**，一保存就真的没了。
    //
    // 搬在**草稿这一层**：勾选框当场就带着正确的状态出现，
    // 用户在保存**之前**就看见了。走命令那条路会被
    // `ReplaceStagesCommand` 盖掉（recurrence_conversion.dart 记着）。
    final harness = await _pumpApp(tester);
    await _createRecurringStaged(tester);
    final stages = await _stageIds(harness);

    // 今天这一次，勾掉第一步。
    await _goToDay(tester, _today);
    await _openSheet(tester);
    await _tick(tester, stages.first);
    await _closeSheet(tester);
    expect(find.textContaining('1/3'), findsOneWidget, reason: '前提：勾上了');

    // 进编辑器关掉重复。
    await _openSheet(tester);
    await tester.tap(find.byKey(OccurrenceSheetKeys.editSeries));
    await tester.pumpAndSettle();
    await tapVisible(tester, TaskEditorPage.recurrenceSwitchKey);

    // **保存之前**，勾选框就该已经带着那份进度了。
    await tester.scrollUntilVisible(
      find.byKey(TaskEditorPage.stageSectionKey),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final box = tester.widget<Checkbox>(
      find.byKey(TaskEditorPage.stageDoneKey(stages.first)),
    );
    expect(box.value, isTrue, reason: '关掉重复之后，勾过的那一步变回了未勾');

    await tapVisible(tester, TaskEditorPage.saveButtonKey);
    final row = (await harness.db.select(harness.db.stages).get()).firstWhere(
      (r) => r.id == stages.first,
    );
    expect(row.status, 'done', reason: '落库之后进度还是丢了');
  });

  testAppWidgets('**先把阶段时间清光、再拨上全天**，关掉重复照样搬得回来（评审 S-3）', (tester) async {
    // ## 评审拼出来的一条链，这一条是去打它的
    //
    // `_stagesFromFirstOccurrence` 拿 `state.isAllDay` 去算「第一次」的
    // `OccurrenceKey`。而 `occurrence_key.dart` 明写着「`isAllDay` 决定
    // 形态，不可从 `minuteOfDay == 0` 反推」—— 所以旗标错了**不会报错**，
    // 只会算出一个匹配不上的 key，`states == null`，进度**静默不搬**。
    //
    // 拨得上全天这件事本身是逃生口给的：阶段时间清光之后推不出起止，
    // `_showsSpanFields` 让整个时间区回来，全天开关就在第一行。
    //
    // 阶段事项**没有资格带这个旗标**（`TaskShape.canBeAllDay`），
    // 所以这里也要问它 —— 与对话框那一处、与新建草稿那一处是同一个动作。
    final harness = await _pumpApp(tester);
    await _createRecurringStaged(tester);
    final stages = await _stageIds(harness);

    await _goToDay(tester, _today);
    await _openSheet(tester);
    await _tick(tester, stages.first);
    await _closeSheet(tester);
    expect(find.textContaining('1/3'), findsOneWidget, reason: '前提：勾上了');

    await _openSheet(tester);
    await tester.tap(find.byKey(OccurrenceSheetKeys.editSeries));
    await tester.pumpAndSettle();

    // ① 把三个阶段的时间**全清掉** —— 于是推不出起止。
    for (final id in stages) {
      await tapVisible(tester, TaskEditorPage.stageTimeKey(id));
      await tester.tap(find.byKey(TaskEditorPage.stageTimeClearKey));
      await tester.pumpAndSettle();
    }
    // ② 逃生口打开了：时间区回来，全天开关在第一行。
    //    **先滚上去再找** —— 表单是懒建的，清阶段时间时滚到了下半截，
    //    直接 `findsOneWidget` 会把「还没建出来」读成「不在」。
    await tester.scrollUntilVisible(
      find.byKey(TaskEditorPage.titleFieldKey),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(TaskEditorPage.startMomentKey),
      findsOneWidget,
      reason: '前提：推不出起止时逃生口该把时间区放出来',
    );
    // ③ **那个开关不该在这儿。** 逃生口放出来的是「起止」，
    //    不是「全天与否」—— 而阶段事项没有「全天」这个概念。
    //    链子断在这一环：拨不上，也就算不错那个 key。
    expect(
      find.byKey(TaskEditorPage.allDaySwitchKey),
      findsNothing,
      reason: '阶段事项拿到了全天开关 —— 拨上去就把「第一次」的 key 算错了',
    );

    // ④ 关掉重复。
    await tapVisible(tester, TaskEditorPage.recurrenceSwitchKey);

    await tester.scrollUntilVisible(
      find.byKey(TaskEditorPage.stageSectionKey),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final box = tester.widget<Checkbox>(
      find.byKey(TaskEditorPage.stageDoneKey(stages.first)),
    );
    expect(
      box.value,
      isTrue,
      reason: '拨过全天之后，那一次的进度就搬不回来了 —— key 算错了，而没有任何地方会报',
    );
  });

  testAppWidgets('**用户手动取消之后，再次转换不会把它改回来**（§4.2）', (tester) async {
    // task-lifecycle §4.2：**用户显式操作优先于推导**。
    // 那一节结尾写着「这条不对称是刻意的，必须有专门测试锁住
    //（否则将来有人「顺手统一一下」就悄悄改掉了）」——
    // 这条就是那把锁在「转换时继承进度」这个新位置上的实例。
    //
    // **这条测试我写过一次又删掉过一次。** 当时我把场景表述成
    // 「关掉→取消→再打开→再关掉，该不该重新搬」，觉得没有明显正确
    // 答案，于是判定那个条件「是精确性不是正确性」。
    // 换个表述答案就有了：**再次转换能不能覆盖用户刚做出的取消**。
    // 规格早就写过了，我没认出来。
    //
    // 所以这里断言的是**原则**（手动改动不被覆盖），
    // 不是机制（只在某个方向搬）—— 后者是变更检测器。
    final harness = await _pumpApp(tester);
    await _createRecurringStaged(tester);
    final stages = await _stageIds(harness);

    await _goToDay(tester, _today);
    await _openSheet(tester);
    await _tick(tester, stages.first);
    await _closeSheet(tester);

    await _openSheet(tester);
    await tester.tap(find.byKey(OccurrenceSheetKeys.editSeries));
    await tester.pumpAndSettle();

    Future<void> scrollToStages() async {
      await tester.scrollUntilVisible(
        find.byKey(TaskEditorPage.stageSectionKey),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    // 关掉重复 → 进度搬过来了。
    await tapVisible(tester, TaskEditorPage.recurrenceSwitchKey);
    await scrollToStages();
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(TaskEditorPage.stageDoneKey(stages.first)),
          )
          .value,
      isTrue,
      reason: '前提：搬过来了',
    );

    // **用户手动取消那一勾。**
    await tapVisible(tester, TaskEditorPage.stageDoneKey(stages.first));
    // 再打开重复、再关掉。
    await tapVisible(tester, TaskEditorPage.recurrenceSwitchKey);
    await tapVisible(
      tester,
      TaskEditorPage.frequencyKey(RecurrenceFrequency.daily),
    );
    await tapVisible(tester, TaskEditorPage.recurrenceSwitchKey);
    await scrollToStages();

    expect(
      tester
          .widget<Checkbox>(
            find.byKey(TaskEditorPage.stageDoneKey(stages.first)),
          )
          .value,
      isFalse,
      reason: '用户手动取消的那一勾被「搬」覆盖回去了 —— 违反 §4.2「显式操作优先」',
    );
  });

  testAppWidgets('对照组：只搬第一次那一份，别的发生不掺和', (tester) async {
    // 少了这条，一个「把任意一次的进度搬过来」的实现能让上面绿。
    final harness = await _pumpApp(tester);
    await _createRecurringStaged(tester);
    final stages = await _stageIds(harness);

    // **只勾明天那一次**，今天那一次不动。
    await _goToDay(tester, _tomorrow);
    await _openSheet(tester);
    await _tick(tester, stages.first);
    await _closeSheet(tester);

    await _goToDay(tester, _today);
    await _openSheet(tester);
    await tester.tap(find.byKey(OccurrenceSheetKeys.editSeries));
    await tester.pumpAndSettle();
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    final row = (await harness.db.select(harness.db.stages).get()).firstWhere(
      (r) => r.id == stages.first,
    );
    expect(row.status, 'pending', reason: '把别的发生的进度也搬过来了 —— 那不是这条任务现在这一次');
  });

  testAppWidgets('对照组：不重复的阶段任务不弹这个弹层', (tester) async {
    // 它没有「某一次」，阶段状态就在阶段自己身上 ——
    // 勾选仍在编辑器里（`stage_done_test.dart` 验那条路）。
    await _pumpApp(tester);
    await tapCreate(tester, TaskShape.staged);
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '搬家');
    await tester.pump();
    // **两个真阶段** —— 阶段事项至少要两个，每个都要有时间
    // （用户 2026-09-10「加强必填项校验」）。原来这里只点了一下
    // 「加一个阶段」、连名字都不填，那条任务从此存不下去。
    for (final name in ['打包', '搬运']) {
      await addStage(tester, name);
    }
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    await openEditorFromCard(tester);
    expect(find.byKey(OccurrenceSheetKeys.sheet), findsNothing);
    expect(find.byKey(TaskEditorPage.titleFieldKey), findsOneWidget);
  });
}

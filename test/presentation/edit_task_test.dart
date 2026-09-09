/// 编辑已有任务。
///
/// 在此之前**根本改不了任何任务**：`UpdateTaskFieldsCommand` 早就写好了，
/// 但没有一处 feature 代码用它，也没有编辑路由 —— 建完的任务，
/// 标题打错了就永远是错的。
///
/// FR-TASK-06「本次及以后」也卡在这上面：那是编辑的一种形态。
@TestOn('vm')
library;

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/features/task/application/task_shape.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';
import 'package:planning_assistant/features/views/task_list/presentation/occurrence_actions_sheet.dart';

import '../support/app_harness.dart';

Future<Harness> _pumpApp(WidgetTester tester) async {
  await setScreenSize(tester, const Size(390, 844));
  final harness = appHarness();
  await seedCategories(harness);
  await tester.pumpWidget(
    ProviderScope(overrides: harness.overrides, child: PlanningAssistantApp()),
  );
  await tester.pumpAndSettle();
  return harness;
}

/// 建一条任务，回到列表。
Future<void> _create(
  WidgetTester tester,
  String title, {
  bool recurring = false,
}) async {
  // 形态在面板上选定，进表单之后不必再拨重复开关。
  await tapCreate(
    tester,
    recurring ? TaskShape.recurringSingle : TaskShape.scratch,
  );
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), title);
  await tester.pump();
  await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
  await tester.pumpAndSettle();
}

void main() {
  group('不重复的任务：点卡片直接进编辑', () {
    testAppWidgets('表单里带着原来的内容，不是一张空表', (tester) async {
      // 空表看起来像「这条任务的内容全没了」。
      await _pumpApp(tester);
      await _create(tester, '买菜');

      await openEditorFromCard(tester);

      expect(find.text('编辑任务'), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(TaskEditorPage.titleFieldKey),
      );
      expect(field.controller?.text ?? '', '买菜');
    });

    testAppWidgets('改了标题保存，改的是同一条，不是新建一条', (tester) async {
      final harness = await _pumpApp(tester);
      await _create(tester, '买菜');
      final before = (await harness.db.select(harness.db.tasks).get()).single;

      await openEditorFromCard(tester);
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '买水果');
      await tester.pump();
      await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
      await tester.pumpAndSettle();

      final rows = await harness.db.select(harness.db.tasks).get();
      expect(rows, hasLength(1), reason: '编辑不该建出第二条');
      expect(rows.single.id, before.id, reason: 'ID 得是原来那个');
      expect(rows.single.title, '买水果');
    });

    testAppWidgets('清空备注真的清得掉', (tester) async {
      // 「不改」与「清空」在补丁语义里是两回事，最容易做成前者 ——
      // 表现是「删了备注保存，回来一看还在」。
      final harness = await _pumpApp(tester);

      await tapCreate(tester);
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '买菜');
      await tester.enterText(find.byKey(TaskEditorPage.noteFieldKey), '带袋子');
      await tester.pump();
      await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
      await tester.pumpAndSettle();

      await openEditorFromCard(tester);
      await tester.enterText(find.byKey(TaskEditorPage.noteFieldKey), '');
      await tester.pump();
      await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
      await tester.pumpAndSettle();

      expect(
        (await harness.db.select(harness.db.tasks).get()).single.note,
        isNull,
      );
    });

    testAppWidgets('阶段全删掉之后，库里也不剩', (tester) async {
      // 编辑时若不发 ReplaceStages，库里那些阶段原地不动 ——
      // 界面显示没有、库里还有。
      final harness = await _pumpApp(tester);

      await tapCreate(tester, TaskShape.staged);
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '写周报');
      await tester.pump();
      for (final title in ['第一步', '第二步']) {
        await tapVisible(tester, TaskEditorPage.addStageKey);
        // **不能直接 `as ValueKey<String>?`**：这一屏上还有别的带 key 的
        // 输入框（Material 自己的组件用的是 `ValueKey<StandardComponentType>`），
        // 硬转会抛 `_TypeError`，而那条报错跟「找不到阶段输入框」
        // 一点关系都没有。先判类型再取值。
        final field = find.byWidgetPredicate((w) {
          if (w is! TextField) return false;
          final key = w.key;
          return key is ValueKey<String> &&
              key.value.startsWith('editor-stage-');
        }).last;
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.enterText(field, title);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
      await tester.pumpAndSettle();
      expect(await harness.db.select(harness.db.stages).get(), hasLength(2));

      // 进编辑，把两个阶段都删掉。
      await openEditorFromCard(tester);
      // 表单是懒建的，阶段区在折线以下 —— 先滚过去，
      // 否则下面那个 `.first` 找的是一个还没建出来的按钮。
      await tester.scrollUntilVisible(
        find.byKey(TaskEditorPage.stageSectionKey),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      for (var i = 0; i < 2; i++) {
        final remove = find
            .byWidgetPredicate(
              (w) =>
                  w is IconButton &&
                  (w.key is ValueKey<String> &&
                      (w.key! as ValueKey<String>).value.startsWith(
                        'editor-stage-remove-',
                      )),
            )
            .first;
        await tester.ensureVisible(remove);
        await tester.pumpAndSettle();
        await tester.tap(remove);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
      await tester.pumpAndSettle();

      final live = (await harness.db.select(harness.db.stages).get()).where(
        (s) => s.deletedAt == null,
      );
      expect(live, isEmpty, reason: '界面上删掉的阶段，库里也该没有');
    });
  });

  group('重复任务：从弹层进编辑', () {
    testAppWidgets('弹层里有「编辑整条」，且说清作用范围', (tester) async {
      // 不说的话，用户会以为这是「只改这一次」——
      // 改完发现每一次都变了，那是最伤的一种误解。
      await _pumpApp(tester);
      await _create(tester, '晨会', recurring: true);

      // 这一条看的是**抽屉本身**，不进编辑页。
      await tester.tap(find.byType(TaskCard).first);
      await tester.pumpAndSettle();

      expect(find.byKey(OccurrenceSheetKeys.editSeries), findsOneWidget);
      expect(find.textContaining('每一次都会变'), findsOneWidget);
    });

    testAppWidgets('改标题之后，展开出来的每一行都跟着变', (tester) async {
      final harness = await _pumpApp(tester);
      await _create(tester, '晨会', recurring: true);

      await openEditorFromCard(tester);

      expect(find.text('编辑任务'), findsOneWidget);
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '站会');
      await tester.pump();
      await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('晨会'), findsNothing);
      expect(find.text('站会'), findsWidgets);
      final task = (await harness.db.select(harness.db.tasks).get()).single;
      expect(task.title, '站会');
      expect(task.recurrenceRule, isNotNull, reason: '只改标题不该把重复规则弄丢');
    });

    testAppWidgets('编辑时改得了「全天」了（R-27）', (tester) async {
      // **这条测试原来断言的是反面**：那时全天 ⇄ 定时会改变
      // occurrenceKey 的形态而没有迁移 key 的命令，所以开关是禁用的 ——
      // 让它能拨却存不下去，是又一个「改了没反应」的开关。
      //
      // `ConvertTaskAllDayModeCommand` 做出来之后这条**该变红**，
      // 于是改成钉住新行为。迁移本身在
      // `test/domain/all_day_conversion_test.dart` 与
      // `test/data/convert_all_day_test.dart` 里验。
      await _pumpApp(tester);
      await _create(tester, '晨会', recurring: true);

      await openEditorFromCard(tester);

      final sw = tester.widget<SwitchListTile>(
        find.byKey(TaskEditorPage.allDaySwitchKey),
      );
      expect(sw.onChanged, isNotNull, reason: '开关又被禁掉了');
    });
  });

  group('界面表达不了的规则，编辑时不许被抹掉', () {
    testAppWidgets('显示成只读一行，保存之后规则原样还在', (tester) async {
      // `RecurrenceDraft.fromRrule` 认不出 `BYSETPOS`（每月最后一个工作日）。
      // 当成「不重复」显示的话，用户改个标题一保存，
      // **规则就被悄悄抹掉了** —— 什么都没做却坏了东西。
      //
      // 夹具原本用的是 `BYDAY=-1FR`（每月最后一个周五）。界面把它做出来
      // 之后这条测试变红了 —— **红得对**：它钉的是「表达不了的规则怎么办」，
      // 而那条已经表达得了。换一条仍然表达不了的进来，
      // 别顺手把断言改松（那会让这条测试跟着能力边界一起消失）。
      final harness = await _pumpApp(tester);
      await _create(tester, '月度复盘');

      // 直接把库里那条规则换成界面表达不了的形态（模拟导入/同步来的数据）。
      final id = (await harness.db.select(harness.db.tasks).get()).single.id;
      await harness.db.customUpdate(
        'UPDATE tasks SET recurrence_rule = ?, plan_date = ? WHERE id = ?',
        variables: [
          const Variable<String>(
            'RRULE:FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1',
          ),
          const Variable<String>('2026-09-08'),
          Variable<String>(id),
        ],
        updates: {harness.db.tasks},
      );
      await tester.pumpAndSettle();

      // 现在它是重复任务了，点卡片弹的是动作层，从那里进编辑。
      await openEditorFromCard(tester);

      expect(
        find.byKey(TaskEditorPage.unsupportedRecurrenceKey),
        findsOneWidget,
        reason: '表达不了的规则要显示成只读说明，不能显示成「不重复」',
      );
      expect(find.byKey(TaskEditorPage.recurrenceSwitchKey), findsNothing);

      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '季度复盘');
      await tester.pump();
      await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
      await tester.pumpAndSettle();

      final task = (await harness.db.select(harness.db.tasks).get()).single;
      expect(task.title, '季度复盘');
      expect(
        task.recurrenceRule,
        'RRULE:FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1',
        reason: '改标题不该动到那条规则',
      );
    });

    testAppWidgets('对照组：认得出的规则照常可编辑', (tester) async {
      // 少了这条，一个「所有规则都当成表达不了」的实现能让上面绿，
      // 而那会让重复区在每一条任务上都变成只读。
      await _pumpApp(tester);
      await _create(tester, '晨会', recurring: true);

      await openEditorFromCard(tester);

      // **先滚过去再断言。**
      //
      // 这条任务现在是定时的（单/重复事项要求起止），日期区比从前多两行，
      // 把重复区推到了折线以下 —— 而表单是懒建的 `ListView`。
      // 不滚的话，`findsOneWidget` 报的是「没建出来」，
      // 而下面那条 `findsNothing` 会**因为同一个原因假绿**
      // （testing-strategy §1.11.1：否定断言要先证明肯定看得见）。
      await tester.scrollUntilVisible(
        find.byKey(TaskEditorPage.recurrenceSwitchKey),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(TaskEditorPage.recurrenceSwitchKey), findsOneWidget);
      expect(find.byKey(TaskEditorPage.unsupportedRecurrenceKey), findsNothing);
    });
  });
}

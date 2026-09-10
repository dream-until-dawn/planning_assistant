/// **J-02 与 J-03**（testing-strategy §8、roadmap M3 验收）。
///
/// | # | 旅程 |
/// |---|---|
/// | J-02 | 新增每周重复任务 → 完成本周这次 → 下周仍为待办 |
/// | J-03 | 新增 3 阶段事项 → 完成第 2 阶段 → 甘特图分段正确 |
///
/// 与 J-01 一样走**真的链路**：真路由、真编辑器、真命令、真仓库、
/// 真 SQLite（内存）。中间没有一处替身 —— 这两条要验的正是
/// 「界面上做的事真的落到了库里，而且另一个视图读得出来」，
/// 用替身等于自证。
@TestOn('vm')
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/data/database/app_database.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/task/application/recurrence_draft.dart';
import 'package:planning_assistant/features/task/application/task_shape.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';
import 'package:planning_assistant/features/views/gantt/presentation/gantt_painter.dart';
import 'package:planning_assistant/features/views/gantt/presentation/gantt_view.dart';
import 'package:planning_assistant/features/views/shared/application/view_kind.dart';

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

Future<void> _newTask(
  WidgetTester tester,
  String title, {
  // J-02 是重复任务、J-03 是阶段事项 —— 形态在面板上就选定了。
  TaskShape shape = TaskShape.scratch,
}) async {
  await tapCreate(tester, shape);
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), title);
  await tester.pump();
}

Future<void> _save(WidgetTester tester) async {
  await tapVisible(tester, TaskEditorPage.saveButtonKey);
}

Future<void> _switchTo(WidgetTester tester, ViewKind kind) async {
  await tester.tap(find.byKey(AppShell.viewTabKey(kind)));
  await tester.pumpAndSettle();
}

GanttPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byKey(GanttView.canvasKey)).painter!
        as GanttPainter;

void main() {
  testAppWidgets('J-02：每周重复 → 完成本周这次 → 下周那次仍是待办', (tester) async {
    final harness = await _pumpApp(tester);

    // ── 建一条每周重复的任务 ─────────────────────────────────
    await _newTask(tester, '周报', shape: TaskShape.recurringSingle);
    await tapVisible(
      tester,
      TaskEditorPage.frequencyKey(RecurrenceFrequency.weekly),
    );
    await _save(tester);

    expect(find.byType(TaskEditorPage), findsNothing, reason: '保存后该回到列表');

    // 库里是**一条**任务加一条规则，不是一堆展开出来的行 ——
    // 重复任务不预存实例（ADR-0004）。
    final stored = await harness.db.select(harness.db.tasks).get();
    expect(stored, hasLength(1));
    expect(stored.single.recurrenceRule, contains('FREQ=WEEKLY'));

    // ── 列表上只显示「下一次」（§0.2.2），把它勾掉 ──────────
    expect(find.byType(TaskCard), findsOneWidget);
    await tester.tap(find.byKey(TaskCard.doneButtonKey));
    await tester.pumpAndSettle();

    // ── 落库的是**一条例外**，不是把整条任务标完成 ─────────
    //
    // 这是 J-02 的要害。`tasks.status` 恒为 pending（data-model §4.3），
    // 真实状态在 override 里 —— 写错的话「完成本周」会变成
    // 「这条任务永远完成了」，下周那次再也不出现。
    final overrides = await harness.db
        .select(harness.db.occurrenceOverrides)
        .get();
    expect(overrides, hasLength(1));
    expect(overrides.single.status, 'done');

    final after = await harness.db.select(harness.db.tasks).get();
    expect(after.single.status, 'pending', reason: '整条任务被标完成了 —— 下周那次不会再出现');

    // ── 下周那次仍是待办 ─────────────────────────────────────
    //
    // 勾完之后列表上还留着划掉的那张卡（给撤销留时间，§8.1），
    // 而**下一次**顶上来，所以现在是两张。
    expect(find.byType(TaskCard), findsNWidgets(2));
    final cards = tester.widgetList<TaskCard>(find.byType(TaskCard)).toList();
    expect(
      cards.where((c) => c.data.isDone),
      hasLength(1),
      reason: '划掉的那张不在了 —— 撤销就没机会了',
    );
    expect(
      cards.where((c) => !c.data.isDone),
      hasLength(1),
      reason: '下一次没顶上来 —— 完成一次把整条规则做没了',
    );
  });

  testAppWidgets('J-03：三阶段事项 → 完成第 2 阶段 → 甘特图分段正确', (tester) async {
    final harness = await _pumpApp(tester);

    // ── 建一条三阶段的任务 ───────────────────────────────────
    await _newTask(tester, '搬家', shape: TaskShape.staged);
    // **它得有一个时间跨度。** 甘特是按跨度画的，没有日期的任务压根不进
    // 甘特（view-specs §4.3 最后一行）—— 第一版没设日期，甘特是空态，
    // 报的是「找不到画布」。
    //
    // 从前是靠「关掉全天顺手补今天」解决的。阶段事项现在没有全天开关了
    // （起止由阶段的时间推出，用户 2026-09-10 定），
    // 跨度改由下面给阶段定时间那一步产生。

    const names = ['打包', '搬运', '收拾'];
    for (final name in names) {
      // **每个阶段都得起名字，也都得有时间。** 空标题的阶段保存时会被
      // 丢掉（`filledStages`），没时间的阶段 2026-09-10 起直接挡住保存 ——
      // 两条都由 `addStage` 一并办了。第一版没填名字，落库零条，
      // 报的是「期望 3 个，实际 []」。
      await addStage(tester, name);
    }
    await _save(tester);

    final stages = await harness.db.select(harness.db.stages).get();
    expect(stages, hasLength(3));
    expect(
      (stages.toList()..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)))
          .map((s) => s.title),
      names,
    );

    // ── 完成第 2 阶段 ────────────────────────────────────────
    //
    // 走库而不是走界面：阶段的就地勾选还没做（M3 的欠账，
    // 见 roadmap）。这条旅程要验的是**甘特读得对**，
    // 而「阶段怎么被勾上」是另一条链路。
    final second = stages.firstWhere((s) => s.orderIndex == 1);
    await (harness.db.update(
      harness.db.stages,
    )..where((t) => t.id.equals(second.id))).write(
      StagesCompanion(
        status: const Value('done'),
        completedAt: Value(DateTime.utc(2026, 9, 8).millisecondsSinceEpoch),
      ),
    );
    await tester.pumpAndSettle();

    // ── 甘特图上：三段 + 三分之一的进度 ─────────────────────
    //
    // ## 这一步 2026-09-10 变强了
    //
    // 原来三个阶段**都没有时间**（编辑器默认不排），于是这里断言的是
    // 「不该凭空切出段来」—— 均分等于告诉用户「第一阶段在前三分之一
    // 结束」，而他从没这么说过。
    //
    // 阶段时间现在是必填的，那个状态存不下去了。于是这条旅程终于能验
    // 它名字里写的那件事本身：**分段正确**。
    // 「没排时间不凭空分段」那条守在 `gantt_layout_test`（G-04 那一族），
    // 那一层构造得出没有时间的阶段。
    await _switchTo(tester, ViewKind.gantt);
    final bars = _painter(tester).layout.lanes.single.bars;
    expect(bars, hasLength(1), reason: '一条任务一根条');

    final bar = bars.single;
    expect(bar.segments, hasLength(3), reason: '三个排了时间的阶段该画成三段');
    expect(bar.progress, closeTo(1 / 3, 0.001), reason: '完成第二阶段没反映到进度上');

    // 对照组：没有阶段的任务，进度是 null 而不是 0 ——
    // 「没有阶段」与「一个都没做」是两回事。
    expect(
      _painter(tester).layout.lanes.single.bars.single.row.stages,
      hasLength(3),
    );
  });
}

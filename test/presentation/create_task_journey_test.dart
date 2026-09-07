/// **J-01：冷启动 → 新建单项任务 → 列表可见**（roadmap M2 验收）。
///
/// 这条走的是**真的链路**：真 GoRouter、真编辑器、真命令、真仓库、
/// 真 SQLite（内存）。中间没有一处替身。
///
/// 之所以不用假仓库：这条旅程要验的正是「写进去的东西读得出来」，
/// 而假仓库的读写行为是我们**以为**的行为 —— 用它来验这件事等于自证。
/// 真库跑在同一进程里，一个用例开一个，快到无所谓。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/design/components/empty_state.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';

import '../support/app_harness.dart';

Future<Harness> _pumpApp(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final harness = appHarness();
  await tester.pumpWidget(
    ProviderScope(overrides: harness.overrides, child: PlanningAssistantApp()),
  );
  await tester.pumpAndSettle();
  return harness;
}

void main() {
  testWidgets('J-01：新建一条任务，回到列表就能看见', (tester) async {
    final harness = await _pumpApp(tester);

    // ── 冷启动落在空态上 ──────────────────────────────────────
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.byType(TaskCard), findsNothing);

    // ── 三次点击落库（M2 验收：≤3 次）────────────────────────
    // 1. 悬浮加号
    await tester.tap(find.byKey(AppShell.fabKey));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditorPage), findsOneWidget);

    // 2. 打字（标题框自动聚焦，不额外花一次点击）
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '买菜');
    await tester.pump();

    // 3. 保存
    await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
    await tester.pumpAndSettle();

    // ── 回到列表，任务在那儿 ─────────────────────────────────
    expect(find.byType(TaskEditorPage), findsNothing, reason: '保存后应当回到列表');
    expect(find.byType(EmptyState), findsNothing, reason: '有任务了就不该还是空态');
    expect(find.byType(TaskCard), findsOneWidget);
    expect(find.text('买菜'), findsOneWidget);

    // ── 真的落库了，不只是界面上有 ───────────────────────────
    // 少了这一条，一个「把标题塞进内存列表」的假实现也能让上面全绿。
    final stored = await harness.db.select(harness.db.tasks).get();
    expect(stored, hasLength(1));
    expect(stored.single.title, '买菜');

    await disposeTree(tester);
  });

  testWidgets('标题为空时保存按钮点不动', (tester) async {
    final harness = await _pumpApp(tester);

    await tester.tap(find.byKey(AppShell.fabKey));
    await tester.pumpAndSettle();

    // 一个字没打就点保存。
    await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(TaskEditorPage), findsOneWidget, reason: '不该保存成功并返回');
    expect(await harness.db.select(harness.db.tasks).get(), isEmpty);

    await disposeTree(tester);
  });

  testWidgets('只有空格的标题也不算填了', (tester) async {
    // 不 trim 的话能存出一条看着空白、却怎么也搜不到的任务。
    final harness = await _pumpApp(tester);

    await tester.tap(find.byKey(AppShell.fabKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '    ');
    await tester.pump();
    await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(TaskEditorPage), findsOneWidget);
    expect(await harness.db.select(harness.db.tasks).get(), isEmpty);

    await disposeTree(tester);
  });

  testWidgets('存完再开一次，表单是空的', (tester) async {
    // taskEditorProvider 是 autoDispose 的。不是的话，第二次进来
    // 标题框里还留着上一条的内容，用户会不小心建出重复任务。
    await _pumpApp(tester);

    await tester.tap(find.byKey(AppShell.fabKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '买菜');
    await tester.pump();
    await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppShell.fabKey));
    await tester.pumpAndSettle();

    // 保存按钮回到禁用态 = 草稿里的标题确实被清了。
    // 直接查输入框的文字不行：TextField 没有受控地绑定草稿，
    // 它自己的 controller 是新建的，本来就是空的 ——
    // 那样查等于验了个必然成立的事。
    final save = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(TaskEditorPage.saveButtonKey),
        matching: find.byType(InkWell),
      ),
    );
    expect(save.onTap, isNull, reason: '草稿没清干净，上一条的标题还在');

    await disposeTree(tester);
  });
}

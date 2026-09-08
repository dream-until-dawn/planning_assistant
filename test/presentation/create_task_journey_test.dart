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
import 'package:planning_assistant/design/components/app_chip.dart';
import 'package:planning_assistant/design/components/empty_state.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';

import '../support/app_harness.dart';

Future<Harness> _pumpApp(WidgetTester tester, {bool seed = false}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final harness = appHarness();
  // 默认**不播种分类**：有没有分类要每个用例显式表态，
  // 否则「空库时怎么显示」那类用例会莫名其妙有四个分类。
  if (seed) await seedCategories(harness);
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

  testWidgets('勾完成：就地划掉，不立即消失（§8.1）', (tester) async {
    final harness = await _pumpApp(tester);

    await tester.tap(find.byKey(AppShell.fabKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '交水电费');
    await tester.pump();
    await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
    await tester.pumpAndSettle();

    // 勾上
    await tester.tap(find.byKey(TaskCard.doneButtonKey));
    await tester.pumpAndSettle();

    final done = await harness.db.select(harness.db.tasks).get();
    expect(done.single.status, 'done', reason: '状态没落库');

    // **卡片还在**。完成即消失在误触时最伤：那条任务去哪了、
    // 怎么找回来，用户完全没有线索。
    expect(find.byType(TaskCard), findsOneWidget);
    expect(find.text('交水电费'), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);

    // 对照组：再点一下要能取消完成。
    // 少了这条，一个「只会置 done、不会撤回」的实现也能让上面全绿。
    await tester.tap(find.byKey(TaskCard.doneButtonKey));
    await tester.pumpAndSettle();

    final undone = await harness.db.select(harness.db.tasks).get();
    expect(undone.single.status, 'pending', reason: '取消完成应当回到 pending');

    await disposeTree(tester);
  });

  group('分类（FR-CFG-03、settings-spec §3.0）', () {
    testWidgets('选一个分类，落库的是它的 id，列表上显示它的名字', (tester) async {
      final harness = await _pumpApp(tester, seed: true);

      await tester.tap(find.byKey(AppShell.fabKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '写周报');
      await tester.pump();

      await tester.tap(
        find.byKey(TaskEditorPage.categoryChipKey('cat-default-briefcase')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
      await tester.pumpAndSettle();

      final stored = await harness.db.select(harness.db.tasks).get();
      expect(stored.single.categoryId, 'cat-default-briefcase');
      // 卡片上分类名以**文字**出现（design-system §8.1：颜色不是唯一载体）。
      expect(find.text('工作'), findsOneWidget);

      await disposeTree(tester);
    });

    testWidgets('选「未分类」写的是 NULL，不是某一行的 id（§3.0）', (tester) async {
      // 这是那条决定的落地检验：库里没有「未分类」那一行，
      // 选中它必须产出 NULL。若哪天有人给它建了一行，这条会红。
      final harness = await _pumpApp(tester, seed: true);

      await tester.tap(find.byKey(AppShell.fabKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '随便记一笔');
      await tester.pump();

      // 先选一个真分类，再改回未分类 —— 直接不选也是 null，
      // 那样验不出「选未分类」这个动作本身。
      await tester.tap(
        find.byKey(TaskEditorPage.categoryChipKey('cat-default-home')),
      );
      await tester.pumpAndSettle();

      // **中间这一步不能省**：只看最后落库的 null 的话，
      // 「两次点击都没生效」也会让这条通过 —— 而那正是要排除的情形。
      // 勾在哪个 Chip 上，是「点击真的生效了」的当场证据。
      expect(
        find.descendant(
          of: find.byKey(TaskEditorPage.categoryChipKey('cat-default-home')),
          matching: find.byIcon(SelectableChip.checkIcon),
        ),
        findsOneWidget,
        reason: '点了「生活」却没选中，后面的断言就没有意义了',
      );

      await tester.tap(find.byKey(TaskEditorPage.categoryChipKey(null)));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(TaskEditorPage.categoryChipKey(null)),
          matching: find.byIcon(SelectableChip.checkIcon),
        ),
        findsOneWidget,
        reason: '「未分类」没被选中',
      );

      await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
      await tester.pumpAndSettle();

      final stored = await harness.db.select(harness.db.tasks).get();
      expect(stored.single.categoryId, isNull);
      expect(find.text('未分类'), findsOneWidget);

      await disposeTree(tester);
    });

    testWidgets('「未分类」不是库里的一行', (tester) async {
      final harness = await _pumpApp(tester, seed: true);
      final rows = await harness.db.select(harness.db.categories).get();
      expect(rows.map((r) => r.name), isNot(contains('未分类')));
      expect(rows, hasLength(4));
      await disposeTree(tester);
    });

    testWidgets('不选分类时默认就是未分类', (tester) async {
      final harness = await _pumpApp(tester, seed: true);

      await tester.tap(find.byKey(AppShell.fabKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '买菜');
      await tester.pump();
      await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
      await tester.pumpAndSettle();

      final stored = await harness.db.select(harness.db.tasks).get();
      expect(stored.single.categoryId, isNull);

      await disposeTree(tester);
    });
  });

  group('框架自带的界面也说中文（NFR-A11Y-04）', () {
    testWidgets('日期选择器是中文的，不是 Select date / OK', (tester) async {
      // 真机上撞见过：满屏中文的应用里弹出一个英文对话框。
      // `flutter_localizations` 早就在 pubspec 里，只是没接上代理。
      //
      // **断言的是渲染出来的字，不是「有没有配 delegates」** ——
      // 后者配了但 supportedLocales 或 locale 不对，照样是英文。
      await _pumpApp(tester);

      await tester.tap(find.byKey(AppShell.fabKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TaskEditorPage.dateFieldKey));
      await tester.pumpAndSettle();

      expect(find.text('确定'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('OK'), findsNothing, reason: '出现英文按钮说明本地化没接上');

      // 关掉对话框，免得后面的 disposeTree 在弹层上拆树。
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await disposeTree(tester);
    });
  });

  group('日期栏', () {
    testWidgets('非全天时不给清空日期', (tester) async {
      // 清了就又回到「有时刻没哪天」。save() 那道兜底会补回来，
      // 但表单上不该出现那个瞬间 —— 用户看到的是「空着也能存」，
      // 存下去却有日期，两件事对不上。
      await _pumpApp(tester);
      await tester.tap(find.byKey(AppShell.fabKey));
      await tester.pumpAndSettle();

      // 关掉全天 → 自动补今天 → 清除按钮应当消失。
      await tester.tap(find.byKey(TaskEditorPage.allDaySwitchKey));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(TaskEditorPage.dateFieldKey),
          matching: find.byIcon(Icons.close),
        ),
        findsNothing,
        reason: '非全天时不该有清除按钮',
      );

      await disposeTree(tester);
    });

    testWidgets('对照组：全天时可以清空日期', (tester) async {
      // 否则「一律不给清」也能让上面那条绿，而那样日期就永远去不掉了。
      await _pumpApp(tester);
      await tester.tap(find.byKey(AppShell.fabKey));
      await tester.pumpAndSettle();

      // 全天状态下先关再开，让日期被补上又保留（关时补今天，开时不清日期）。
      await tester.tap(find.byKey(TaskEditorPage.allDaySwitchKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TaskEditorPage.allDaySwitchKey));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(TaskEditorPage.dateFieldKey),
          matching: find.byIcon(Icons.close),
        ),
        findsOneWidget,
        reason: '全天 + 有日期时应当能清掉',
      );

      await disposeTree(tester);
    });
  });
}

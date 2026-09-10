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
import 'package:planning_assistant/core/time/weekday.dart';
import 'package:planning_assistant/design/components/app_chip.dart';
import 'package:planning_assistant/design/components/empty_state.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/features/task/application/recurrence_draft.dart';
import 'package:planning_assistant/features/task/application/task_shape.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';

import '../support/app_harness.dart';

Future<Harness> _pumpApp(WidgetTester tester, {bool seed = false}) async {
  await setScreenSize(tester, const Size(390, 844));

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
  testAppWidgets('J-01：新建一条任务，回到列表就能看见', (tester) async {
    final harness = await _pumpApp(tester);

    // ── 冷启动落在空态上 ──────────────────────────────────────
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.byType(TaskCard), findsNothing);

    // ── 三次点击落库（M2 验收：≤3 次）────────────────────────
    // 1. 悬浮加号
    await tapCreate(tester);
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
  });

  testAppWidgets('标题为空时保存按钮点不动', (tester) async {
    final harness = await _pumpApp(tester);

    await tapCreate(tester);

    // 一个字没打就点保存。
    await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(TaskEditorPage), findsOneWidget, reason: '不该保存成功并返回');
    expect(await harness.db.select(harness.db.tasks).get(), isEmpty);
  });

  testAppWidgets('只有空格的标题也不算填了', (tester) async {
    // 不 trim 的话能存出一条看着空白、却怎么也搜不到的任务。
    final harness = await _pumpApp(tester);

    await tapCreate(tester);
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '    ');
    await tester.pump();
    await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(TaskEditorPage), findsOneWidget);
    expect(await harness.db.select(harness.db.tasks).get(), isEmpty);
  });

  testAppWidgets('存完再开一次，表单是空的', (tester) async {
    // taskEditorProvider 是 autoDispose 的。不是的话，第二次进来
    // 标题框里还留着上一条的内容，用户会不小心建出重复任务。
    await _pumpApp(tester);

    await tapCreate(tester);
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '买菜');
    await tester.pump();
    await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
    await tester.pumpAndSettle();

    await tapCreate(tester);

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
  });

  testAppWidgets('勾完成：就地划掉，不立即消失（§8.1）', (tester) async {
    final harness = await _pumpApp(tester);

    await tapCreate(tester);
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
  });

  group('分类（FR-CFG-03、settings-spec §3.0）', () {
    testAppWidgets('选一个分类，落库的是它的 id，列表上显示它的名字', (tester) async {
      final harness = await _pumpApp(tester, seed: true);

      await tapCreate(tester);
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '写周报');
      await tester.pump();

      await tester.tap(
        find.byKey(TaskEditorPage.categoryChipKey('cat-default-briefcase')),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, TaskEditorPage.saveButtonKey);

      final stored = await harness.db.select(harness.db.tasks).get();
      expect(stored.single.categoryId, 'cat-default-briefcase');
      // 卡片上分类名以**文字**出现（design-system §8.1：颜色不是唯一载体）。
      //
      // 限定在卡片里找：筛选条上也有一个「工作」Chip，
      // 不限定的话 find.text 同时命中两个 —— 而那两个是完全不同的东西，
      // 一个是「这条任务属于工作」，一个是「按工作筛选」。
      expect(
        find.descendant(of: find.byType(TaskCard), matching: find.text('工作')),
        findsOneWidget,
      );
    });

    testAppWidgets('选「未分类」写的是 NULL，不是某一行的 id（§3.0）', (tester) async {
      // 这是那条决定的落地检验：库里没有「未分类」那一行，
      // 选中它必须产出 NULL。若哪天有人给它建了一行，这条会红。
      final harness = await _pumpApp(tester, seed: true);

      await tapCreate(tester);
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

      await tapVisible(tester, TaskEditorPage.saveButtonKey);

      final stored = await harness.db.select(harness.db.tasks).get();
      expect(stored.single.categoryId, isNull);
      expect(
        find.descendant(of: find.byType(TaskCard), matching: find.text('未分类')),
        findsOneWidget,
      );
    });

    testAppWidgets('「未分类」不是库里的一行', (tester) async {
      final harness = await _pumpApp(tester, seed: true);
      final rows = await harness.db.select(harness.db.categories).get();
      expect(rows.map((r) => r.name), isNot(contains('未分类')));
      expect(rows, hasLength(4));
    });

    testAppWidgets('不选分类时默认就是未分类', (tester) async {
      final harness = await _pumpApp(tester, seed: true);

      await tapCreate(tester);
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '买菜');
      await tester.pump();
      await tapVisible(tester, TaskEditorPage.saveButtonKey);

      final stored = await harness.db.select(harness.db.tasks).get();
      expect(stored.single.categoryId, isNull);
    });
  });

  group('框架自带的界面也说中文（NFR-A11Y-04）', () {
    testAppWidgets('日期选择器是中文的，不是 Select date / OK', (tester) async {
      // 真机上撞见过：满屏中文的应用里弹出一个英文对话框。
      // `flutter_localizations` 早就在 pubspec 里，只是没接上代理。
      //
      // **断言的是渲染出来的字，不是「有没有配 delegates」** ——
      // 后者配了但 supportedLocales 或 locale 不对，照样是英文。
      await _pumpApp(tester);

      await tapCreate(tester, TaskShape.single);
      await tester.tap(find.byKey(TaskEditorPage.dateFieldKey));
      await tester.pumpAndSettle();

      expect(find.text('确定'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('OK'), findsNothing, reason: '出现英文按钮说明本地化没接上');

      // 关掉对话框，免得后面的 disposeTree 在弹层上拆树。
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    });
  });

  group('日期栏', () {
    testAppWidgets('非全天时不给清空日期', (tester) async {
      // 清了就又回到「有时刻没哪天」。save() 那道兜底会补回来，
      // 但表单上不该出现那个瞬间 —— 用户看到的是「空着也能存」，
      // 存下去却有日期，两件事对不上。
      await _pumpApp(tester);
      // **单事项预填就是非全天**（临时事项藏了日期栏，验不了这条），
      // 所以这里不用再拨开关 —— 拨了反而会切到全天，把前提翻过来。
      await tapCreate(tester, TaskShape.single);

      expect(
        find.descendant(
          of: find.byKey(TaskEditorPage.dateFieldKey),
          matching: find.byIcon(Icons.close),
        ),
        findsNothing,
        reason: '非全天时不该有清除按钮',
      );
    });

    testAppWidgets('对照组：全天时可以清空日期', (tester) async {
      // 否则「一律不给清」也能让上面那条绿，而那样日期就永远去不掉了。
      await _pumpApp(tester);
      await tapCreate(tester, TaskShape.single);

      // 单事项预填是非全天且带日期，拨成全天之后日期留着 —— 于是
      // 「全天 + 有日期」这个前提一步就摆好了。
      await tapVisible(tester, TaskEditorPage.allDaySwitchKey);

      expect(
        find.descendant(
          of: find.byKey(TaskEditorPage.dateFieldKey),
          matching: find.byIcon(Icons.close),
        ),
        findsOneWidget,
        reason: '全天 + 有日期时应当能清掉',
      );
    });
  });

  group('阶段事项（FR-TASK-02）', () {
    testAppWidgets('建一条两阶段的任务，卡片上显示进度', (tester) async {
      final harness = await _pumpApp(tester);

      await tapCreate(tester, TaskShape.staged);
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '写季度总结');
      await tester.pump();

      await tapVisible(tester, TaskEditorPage.addStageKey);
      await tapVisible(tester, TaskEditorPage.addStageKey);

      final fields = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '这一步做什么',
      );
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(0), '打草稿');
      await tester.enterText(fields.at(1), '定稿');
      await tester.pump();

      await tapVisible(tester, TaskEditorPage.saveButtonKey);

      // 卡片上的进度是**文字**（design-system §8.1：不靠颜色单独承载）。
      expect(find.textContaining('0/2'), findsOneWidget);

      // 真的落库了：kind 与两条阶段都在。
      final task = (await harness.db.select(harness.db.tasks).get()).single;
      expect(task.kind, 'staged');
      final stages = await harness.db.select(harness.db.stages).get();
      expect(stages.map((s) => s.title), containsAll(['打草稿', '定稿']));
      expect(stages.map((s) => s.orderIndex), containsAll([0, 1]));
    });

    testAppWidgets('只填一个阶段时保存按钮点不动，并说明原因', (tester) async {
      // 存下去会得到一个领域层直接拒绝的命令 —— 与其让它在保存时炸，
      // 不如当场挡住并告诉用户为什么。
      final harness = await _pumpApp(tester);

      await tapCreate(tester, TaskShape.staged);
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '写季度总结');
      await tester.pump();
      await tapVisible(tester, TaskEditorPage.addStageKey);

      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '这一步做什么',
      );
      await tester.enterText(field, '只有这一步');
      await tester.pump();

      expect(find.byKey(TaskEditorPage.blockedReasonKey), findsOneWidget);
      await tapVisible(tester, TaskEditorPage.saveButtonKey);

      expect(find.byType(TaskEditorPage), findsOneWidget, reason: '不该保存成功');
      expect(await harness.db.select(harness.db.tasks).get(), isEmpty);
    });

    testAppWidgets('对照组：不加阶段时不出现那句提示', (tester) async {
      // 否则「一直显示」也能让上面那条绿。
      await _pumpApp(tester);
      await tapCreate(tester);
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '买菜');
      await tester.pump();

      expect(find.byKey(TaskEditorPage.blockedReasonKey), findsNothing);
    });
  });

  group('阶段的时间段（FR-TASK-02：每阶段有独立时间段）', () {
    /// 建一条两阶段任务，并把标题填好。返回两个阶段行的 id。
    Future<List<String>> twoStages(WidgetTester tester) async {
      await tapCreate(tester, TaskShape.staged);
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '写周报');
      await tester.pump();
      // 阶段事项没有全天开关了：起止由阶段的时间推出，
      // 而阶段时间一律带时刻（用户 2026-09-10 定）。

      final ids = <String>[];
      for (final title in ['收集素材', '整理成稿']) {
        await tapVisible(tester, TaskEditorPage.addStageKey);
        final field = find
            .byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  (w.key is ValueKey<String> &&
                      (w.key! as ValueKey<String>).value.startsWith(
                        'editor-stage-',
                      )),
            )
            .last;
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.enterText(field, title);
        await tester.pumpAndSettle();
        ids.add(
          ((tester.widget(field) as TextField).key! as ValueKey<String>).value
              .replaceFirst('editor-stage-', ''),
        );
      }
      return ids;
    }

    testAppWidgets('给第二个阶段定时间 → 偏移与时长落库', (tester) async {
      final harness = await _pumpApp(tester);
      final ids = await twoStages(tester);

      // 默认对话框给的是「任务开始那一刻起、一小时」——
      // 直接确定，验的是这条默认值真的能用（而不是四个空栏位）。
      await tapVisible(tester, TaskEditorPage.stageTimeKey(ids[1]));
      await tester.tap(find.byKey(TaskEditorPage.stageTimeConfirmKey));
      await tester.pumpAndSettle();

      await tapVisible(tester, TaskEditorPage.saveButtonKey);

      final stages = await harness.db.select(harness.db.stages).get();
      expect(stages, hasLength(2));
      final timed = stages.firstWhere((s) => s.id == ids[1]);
      final untimed = stages.firstWhere((s) => s.id == ids[0]);

      expect(timed.startOffsetMinutes, 0, reason: '从任务开始那一刻起');
      expect(timed.durationMinutes, 60, reason: '默认一小时');
      // 对照：**没设的那个阶段不许被顺手填上** ——
      // 「给所有阶段都写个默认时长」也能让上面两条绿。
      expect(untimed.startOffsetMinutes, isNull);
      expect(untimed.durationMinutes, isNull);
    });

    testAppWidgets('「不定时间」把已设的清掉', (tester) async {
      final harness = await _pumpApp(tester);
      final ids = await twoStages(tester);

      await tapVisible(tester, TaskEditorPage.stageTimeKey(ids[0]));
      await tester.tap(find.byKey(TaskEditorPage.stageTimeConfirmKey));
      await tester.pumpAndSettle();
      // 再打开，选「不定时间」。
      await tapVisible(tester, TaskEditorPage.stageTimeKey(ids[0]));
      await tester.tap(find.byKey(TaskEditorPage.stageTimeClearKey));
      await tester.pumpAndSettle();

      await tapVisible(tester, TaskEditorPage.saveButtonKey);

      final stage = (await harness.db.select(harness.db.stages).get())
          .firstWhere((s) => s.id == ids[0]);
      expect(stage.startOffsetMinutes, isNull, reason: '清了就该真的清掉');
      expect(stage.durationMinutes, isNull, reason: '时长不该留着 —— 那是一段悬空的长度');
    });

    testAppWidgets('结束早于开始时确定按钮点不动', (tester) async {
      // 算出来会是负时长 —— 在甘特图上是一根往回长的条，
      // 而它能安安静静地落库，之后没有任何界面提示不对。
      await _pumpApp(tester);
      final ids = await twoStages(tester);

      await tapVisible(tester, TaskEditorPage.stageTimeKey(ids[0]));
      // 把结束日期往前挪一天。
      await tester.tap(find.byKey(TaskEditorPage.stageTimeEndDateKey));
      await tester.pumpAndSettle();
      // 日期选择器里点「上一个月」再选 1 号，稳妥地落在开始之前。
      await tester.tap(find.byTooltip('上个月'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1').first);
      await tester.pumpAndSettle();
      // **不能直接 find.text('确定')**：阶段时间对话框自己也有一个，
      // 两个一起匹配到会报「ambiguously found multiple」。
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('确定'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('结束不能早于开始'), findsOneWidget);
      final confirm = tester.widget<TextButton>(
        find.byKey(TaskEditorPage.stageTimeConfirmKey),
      );
      expect(confirm.onPressed, isNull, reason: '不合法时不该能确定');
    });
  });

  group('计划时间段（FR-TASK-01：可选的开始与结束）', () {
    testAppWidgets('结束开关一开就给个看得见的默认（与开始同一天），且落库', (tester) async {
      final harness = await _pumpApp(tester);

      await tapCreate(tester, TaskShape.single);
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '开会');
      await tester.pump();

      // **先拨成全天**：这一条要验的是「结束开关一开给的那个默认日期」，
      // 而同一天 + 一个比开始早的时刻会撞上「结束早于开始」——
      // 那条约束是对的，验默认日期时不该被它绊住。
      // 结束**时刻**能不能落库另有两处盯着（`write_path_reachability` 的
      // endMinute 探针、以及下面那条「切回全天会把结束时刻一起清掉」）。
      await tapVisible(tester, TaskEditorPage.allDaySwitchKey);

      // **先关再开** —— 这一条验的是「开关一开会给个看得见的默认」，
      // 所以得让它真的从关的状态开一次。单事项预填是开着的
      // （结束在 +24 小时那天），不先关掉就验不到那个默认。
      await tapVisible(tester, TaskEditorPage.endSwitchKey);
      await tapVisible(tester, TaskEditorPage.endSwitchKey);

      // 开关一开就该有一个看得见的默认（与开始同一天），
      // 而不是留一行「选个日期」等着再点一次。
      expect(find.byKey(TaskEditorPage.endDateFieldKey), findsOneWidget);

      await tapVisible(tester, TaskEditorPage.saveButtonKey);

      final task = (await harness.db.select(harness.db.tasks).get()).single;
      expect(task.endDate, isNotNull, reason: '结束日期该跟着落库');
      // 结束日期默认取开始那天 —— 这才是这一条钉的东西。
      expect(task.endDate, task.planDate);
    });

    testAppWidgets('对照组：不开那个开关就没有结束', (tester) async {
      // 少了这条，一个「永远写一个结束时间」的实现也能让上面绿。
      final harness = await _pumpApp(tester);
      await tapCreate(tester);
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '开会');
      await tester.pump();
      await tapVisible(tester, TaskEditorPage.saveButtonKey);

      final task = (await harness.db.select(harness.db.tasks).get()).single;
      expect(task.endDate, isNull);
      expect(task.endMinute, isNull);
    });

    testAppWidgets('切回全天会把结束时刻一起清掉', (tester) async {
      // 留着的话就是一条「全天但 18:00 结束」的任务 ——
      // 领域不变量直接拒绝，而用户看到的只是保存时炸了一下。
      final harness = await _pumpApp(tester);
      await tapCreate(tester, TaskShape.single);
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '开会');
      await tester.pump();

      // 单事项预填就是「非全天 + 有结束」，所以直接去设结束时刻。
      await tapVisible(tester, TaskEditorPage.endTimeFieldKey);
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      // 再切成全天。
      await tapVisible(tester, TaskEditorPage.allDaySwitchKey);

      await tapVisible(tester, TaskEditorPage.saveButtonKey);

      // 存下去了（没被不变量拒），而且时刻确实没了。
      expect(find.byType(TaskEditorPage), findsNothing, reason: '应当存成功并返回');
      final task = (await harness.db.select(harness.db.tasks).get()).single;
      expect(task.isAllDay, isTrue);
      expect(task.startMinute, isNull);
      expect(task.endMinute, isNull);
      expect(task.endDate, isNotNull, reason: '「哪天结束」与全天不矛盾，不该一起清掉');
    });
  });

  group('重复任务（FR-TASK-03/04）', () {
    testAppWidgets('建一条每周一三五的任务，规则以规范形落库', (tester) async {
      final harness = await _pumpApp(tester);

      await tapCreate(tester, TaskShape.recurringSingle);
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '晨会');
      await tester.pump();

      await tapVisible(
        tester,
        TaskEditorPage.frequencyKey(RecurrenceFrequency.weekly),
      );
      for (final d in [Weekday.monday, Weekday.wednesday, Weekday.friday]) {
        await tapVisible(tester, TaskEditorPage.weekdayKey(d));
      }

      await tapVisible(tester, TaskEditorPage.saveButtonKey);

      final task = (await harness.db.select(harness.db.tasks).get()).single;
      expect(task.recurrenceRule, 'RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR');
      // 打开重复必须补上日期 —— RRULE 的展开以 DTSTART 为锚点。
      expect(task.planDate, isNotNull);
    });

    testAppWidgets('卡片上看得出这条会重复', (tester) async {
      // 重复任务与单次任务在卡片上本来一模一样，而它们的完成、删除、
      // 修改语义完全不同 —— 分不出来的话，用户会以为删的是一次。
      await _pumpApp(tester);

      await tapCreate(tester, TaskShape.recurringSingle);
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '晨会');
      await tester.pump();
      await tapVisible(tester, TaskEditorPage.saveButtonKey);

      // 图标 + 文字都有（§8.1：不靠图标单独承载）。
      //
      // **不止一张**：「每天」在列表里展开成窗口内的每一天
      // （view-specs §0.2、`ListHorizon`），每一次都是一张卡片。
      expect(find.byIcon(TaskCard.recurringIcon), findsWidgets);
      expect(find.textContaining('每天'), findsWidgets);
    });

    testAppWidgets('卡片上的规则说明要准，不能只说对一半', (tester) async {
      // 一度是 `rule.contains('FREQ=WEEKLY')` 挑关键字拼句子，
      // 于是 INTERVAL=3 的规则在卡片上显示成「每周」——
      // 挑着认的部件拼出来的句子，缺的那部分不是没说，是说错了。
      await _pumpApp(tester);

      await tapCreate(tester, TaskShape.recurringSingle);
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '周会');
      await tester.pump();
      await tapVisible(
        tester,
        TaskEditorPage.frequencyKey(RecurrenceFrequency.weekly),
      );
      // 间隔 1 → 3。
      for (var i = 0; i < 2; i++) {
        await tapVisible(
          tester,
          TaskEditorPage.stepperIncKey(TaskEditorPage.intervalStepper),
        );
      }

      await tapVisible(tester, TaskEditorPage.saveButtonKey);

      // **不止一张卡片**：重复任务现在在列表里展开成多次发生
      // （view-specs §0.2），每一次都带着同一句规则说明。
      expect(find.textContaining('每 3 周'), findsWidgets);
      // 「每周」曾经是这里显示的内容 —— 它是错的，必须不在。
      // （「每 3 周」里不含「每周」这两个连续的字，所以这条不会自相矛盾。）
      expect(find.textContaining('未分类 · 每周'), findsNothing);
    });

    testAppWidgets('勾其中一次：不再抛异常，而且只影响那一次', (tester) async {
      // **这条以前是崩的。** 重复任务的 tasks.status 恒为 pending
      // （data-model §4.3，领域不变量强制），而完成钮走的是
      // ChangeTaskStatusCommand —— 落库前被不变量直接拒掉，
      // 用户点一下那个圈就抛 DomainInvariantViolation。
      final harness = await _pumpApp(tester);

      await tapCreate(tester, TaskShape.recurringSingle);
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '晨会');
      await tester.pump();
      await tapVisible(tester, TaskEditorPage.saveButtonKey);

      // **未来方向只展开一条**（view-specs §0.2.1）：新建的每日任务
      // 此刻只有「今天」这一次。
      expect(find.byType(TaskCard), findsOneWidget);

      await tester.tap(find.byKey(TaskCard.doneButtonKey).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '勾重复任务不该抛');

      // 勾掉之后「下一次」当场顶上来，而刚勾的那条还在原位（§8.1）。
      expect(
        find.byType(TaskCard),
        findsNWidgets(2),
        reason: '完成一次之后应当出现下一次，同时保留刚勾掉的那条给撤销留时间',
      );

      // 落的是**例外**，不是 tasks.status。
      final task = (await harness.db.select(harness.db.tasks).get()).single;
      expect(
        task.status,
        'pending',
        reason: '重复任务的 tasks.status 恒为 pending —— 真实状态在例外里',
      );
      final overrides = await harness.db
          .select(harness.db.occurrenceOverrides)
          .get();
      expect(overrides, hasLength(1), reason: '只该给被勾的那一次落一条例外');
      expect(overrides.single.status, 'done');
      expect(overrides.single.completedAt, isNotNull);
    });

    testAppWidgets('再勾一次 = 取消，例外被删掉', (tester) async {
      // 不是写一条 pending 的例外 —— 那会让「从没动过」与
      // 「动过又撤回」在库里长得不一样，而它们对用户是同一件事。
      final harness = await _pumpApp(tester);

      await tapCreate(tester, TaskShape.recurringSingle);
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '晨会');
      await tester.pump();
      await tapVisible(tester, TaskEditorPage.saveButtonKey);

      final done = find.byKey(TaskCard.doneButtonKey).first;
      await tester.tap(done);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TaskCard.doneButtonKey).first);
      await tester.pumpAndSettle();

      final live =
          (await harness.db.select(harness.db.occurrenceOverrides).get()).where(
            (o) => o.deletedAt == null,
          );
      expect(live, isEmpty, reason: '取消完成应当回到「跟随规则」，而不是留一条例外');
    });

    testAppWidgets('对照组：不重复的任务仍然走 tasks.status', (tester) async {
      // 两条路走错任何一条都会出问题：普通任务若走例外那条，
      // 完成状态会落在一张与它无关的表上，列表看起来毫无反应。
      final harness = await _pumpApp(tester);

      await tapCreate(tester);
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '买菜');
      await tester.pump();
      await tapVisible(tester, TaskEditorPage.saveButtonKey);

      await tester.tap(find.byKey(TaskCard.doneButtonKey).first);
      await tester.pumpAndSettle();

      final task = (await harness.db.select(harness.db.tasks).get()).single;
      expect(task.status, 'done');
      expect(
        await harness.db.select(harness.db.occurrenceOverrides).get(),
        isEmpty,
        reason: '不重复的任务不该产生例外行',
      );
    });

    testAppWidgets('对照组：不重复的任务没有那个标记', (tester) async {
      await _pumpApp(tester);
      await tapCreate(tester);
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '买菜');
      await tester.pump();
      await tapVisible(tester, TaskEditorPage.saveButtonKey);

      expect(find.byIcon(TaskCard.recurringIcon), findsNothing);
    });

    testAppWidgets('「到某天为止」没选日期时不给存', (tester) async {
      // 存下去会得到一条永不结束的规则，而用户以为它会停。
      final harness = await _pumpApp(tester);

      await tapCreate(tester, TaskShape.recurringSingle);
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '晨会');
      await tester.pump();
      await tapVisible(
        tester,
        TaskEditorPage.endModeKey(RecurrenceEndMode.until),
      );

      expect(find.byKey(TaskEditorPage.blockedReasonKey), findsOneWidget);
      await tapVisible(tester, TaskEditorPage.saveButtonKey);

      expect(find.byType(TaskEditorPage), findsOneWidget);
      expect(await harness.db.select(harness.db.tasks).get(), isEmpty);
    });
  });
}

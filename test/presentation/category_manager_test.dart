/// 分类管理（FR-CFG-03、settings-spec §3）。
///
/// 走真链路：真路由、真 provider、真仓库、真 SQLite（内存）。
/// 每条都断言**落库的那一行**，不只看界面 —— M2 里已经栽过一次
/// 「界面和草稿都对、写进去的却是空」（categoryId 那次）。
@TestOn('vm')
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/core/time/clock.dart';
import 'package:planning_assistant/data/database/dao/synced_dao.dart';
import 'package:planning_assistant/data/repositories/settings_repository_impl.dart';
import 'package:planning_assistant/design/tokens/colors.dart';
import 'package:planning_assistant/features/settings/presentation/category_manager_page.dart';
import 'package:planning_assistant/features/settings/presentation/settings_page.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';

import '../support/app_harness.dart';

Future<Harness> _pumpApp(WidgetTester tester, {bool seed = true}) async {
  await setScreenSize(tester, const Size(390, 844));
  final harness = appHarness();
  if (seed) await seedCategories(harness);
  await tester.pumpWidget(
    ProviderScope(overrides: harness.overrides, child: PlanningAssistantApp()),
  );
  await tester.pumpAndSettle();
  return harness;
}

/// 从列表页走到分类管理 —— **走真入口**，不直接 pump 那个页面。
/// 直接 pump 的话，「设置页里有没有这个入口」就没人验了。
Future<void> _openManager(WidgetTester tester) async {
  await tester.tap(find.byKey(AppShell.settingsKey));
  await tester.pumpAndSettle();
  await tapVisible(tester, SettingsPage.categoriesEntryKey);
  expect(find.byKey(CategoryManagerPage.pageKey), findsOneWidget);
}

/// 库里的分类，按 orderIndex 升序。
Future<List<String>> _names(Harness h) async {
  final repo = await h.db.select(h.db.categories).get();
  final live = repo.where((c) => c.deletedAt == null).toList()
    ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  return [for (final c in live) c.name];
}

/// 从把手起手往下拖 [dy]。
///
/// **分多步移动**：一步跳到位的话，中间那些「越过了谁的中线」的判定
/// 一次都不会发生，拖完等于没动 —— 而失败信息只是「顺序没变」，
/// 看起来像回调接错了。
Future<void> _dragDown(WidgetTester tester, Finder handle, double dy) async {
  final drag = await tester.startGesture(tester.getCenter(handle));
  await tester.pump(kLongPressTimeout + kPressTimeout);
  for (var i = 0; i < 10; i++) {
    await drag.moveBy(Offset(0, dy / 10));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await drag.up();
  await tester.pumpAndSettle();
}

void main() {
  testAppWidgets('从设置进得去，四个默认分类都在', (tester) async {
    final harness = await _pumpApp(tester);
    await _openManager(tester);

    for (final name in ['工作', '学习', '生活', '健康']) {
      expect(find.text(name), findsOneWidget);
    }
    // 「未分类」**不在这里**：它是 categoryId IS NULL，不是一行（§3.0）。
    // 界面上要有一句话说明，否则用户会以为它被漏了。
    expect(find.text('未分类'), findsNothing);
    expect(find.textContaining('「未分类」不是一个分类'), findsOneWidget);

    expect(await _names(harness), ['工作', '学习', '生活', '健康']);
  });

  group('新建', () {
    testAppWidgets('建一个，落库并排在最后', (tester) async {
      final harness = await _pumpApp(tester);
      await _openManager(tester);

      await tapVisible(tester, CategoryManagerPage.addButtonKey);
      await tester.enterText(
        find.byKey(CategoryManagerPage.nameFieldKey),
        '阅读',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CategoryManagerPage.nameConfirmKey));
      await tester.pumpAndSettle();

      expect(await _names(harness), ['工作', '学习', '生活', '健康', '阅读']);
    });

    testAppWidgets('颜色按调色板顺序取，不是随机也不是恒定', (tester) async {
      // settings-spec §3：「颜色从默认调色板按序取」。
      // 恒定一个色的话，用户连建三个分类会得到三个一模一样的，
      // 而颜色正是列表里用来扫视的东西。
      final harness = await _pumpApp(tester);
      await _openManager(tester);

      for (final name in ['阅读', '运动']) {
        await tapVisible(tester, CategoryManagerPage.addButtonKey);
        await tester.enterText(
          find.byKey(CategoryManagerPage.nameFieldKey),
          name,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(CategoryManagerPage.nameConfirmKey));
        await tester.pumpAndSettle();
      }

      final rows = await harness.db.select(harness.db.categories).get();
      final byName = {for (final c in rows) c.name: c.colorArgb};
      // 播种的四个占了第 0..3 个，新建的两个接着取第 4、5 个。
      expect(byName['阅读'], CategoryPalette.values[4]);
      expect(byName['运动'], CategoryPalette.values[5]);
    });

    testAppWidgets('空名字不给确定', (tester) async {
      // 存下去会得到一个在编辑器里点不中、卡片上什么也不显示的分类。
      await _pumpApp(tester);
      await _openManager(tester);

      await tapVisible(tester, CategoryManagerPage.addButtonKey);
      await tester.enterText(
        find.byKey(CategoryManagerPage.nameFieldKey),
        '   ',
      );
      await tester.pumpAndSettle();

      final confirm = tester.widget<TextButton>(
        find.byKey(CategoryManagerPage.nameConfirmKey),
      );
      expect(confirm.onPressed, isNull, reason: '一串空格不是名字');
    });
  });

  group('改名与改色', () {
    testAppWidgets('改名落库', (tester) async {
      final harness = await _pumpApp(tester);
      await _openManager(tester);

      await tapVisible(
        tester,
        CategoryManagerPage.renameKey('cat-default-briefcase'),
      );
      await tester.enterText(
        find.byKey(CategoryManagerPage.nameFieldKey),
        '正事',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CategoryManagerPage.nameConfirmKey));
      await tester.pumpAndSettle();

      expect(await _names(harness), ['正事', '学习', '生活', '健康']);
    });

    testAppWidgets('改色落库，而且只动这一个', (tester) async {
      final harness = await _pumpApp(tester);
      await _openManager(tester);

      const target = 0xFFC3B5F0; // 薰衣草
      await tapVisible(
        tester,
        CategoryManagerPage.colorKey('cat-default-briefcase'),
      );
      await tester.tap(find.byKey(CategoryManagerPage.colorOptionKey(target)));
      await tester.pumpAndSettle();

      final rows = await harness.db.select(harness.db.categories).get();
      final byId = {for (final c in rows) c.id: c};
      expect(byId['cat-default-briefcase']!.colorArgb, target);
      // 对照：「把所有分类都改成这个色」也能让上一条绿。
      expect(byId['cat-default-book']!.colorArgb, isNot(target));
    });
  });

  group('删除（FR-CFG-03 的正文）', () {
    testAppWidgets('要先确认，取消就什么都不动', (tester) async {
      // 删分类会动到不在当前屏幕上的一批任务，看不见的后果尤其要先问。
      final harness = await _pumpApp(tester);
      await _openManager(tester);

      await tapVisible(
        tester,
        CategoryManagerPage.deleteKey('cat-default-briefcase'),
      );
      expect(find.text('取消'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(await _names(harness), hasLength(4), reason: '取消就该什么都没发生');
    });

    testAppWidgets('确认后分类没了，它下面的任务变成未分类但还在', (tester) async {
      final harness = await _pumpApp(tester);

      // 先建一条挂在「工作」下的任务，走真编辑器。
      await tester.tap(find.byKey(AppShell.fabKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '写周报');
      await tester.pump();
      await tapVisible(
        tester,
        TaskEditorPage.categoryChipKey('cat-default-briefcase'),
      );
      await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
      await tester.pumpAndSettle();

      await _openManager(tester);
      await tapVisible(
        tester,
        CategoryManagerPage.deleteKey('cat-default-briefcase'),
      );
      await tester.tap(find.byKey(CategoryManagerPage.deleteConfirmKey));
      await tester.pumpAndSettle();

      expect(await _names(harness), ['学习', '生活', '健康']);

      final task = (await harness.db.select(harness.db.tasks).get()).single;
      expect(task.title, '写周报', reason: '任务不该跟着分类一起删');
      expect(
        task.categoryId,
        isNull,
        reason:
            '删分类后任务应当变成未分类 —— 留着死 id 的话，'
            '卡片显示「未分类」而按「未分类」筛却找不到它',
      );
    });

    testAppWidgets('删光了显示空态，而不是一片空白', (tester) async {
      // 全删光是合法状态（§3.1），所以空态的口气是说明不是催促。
      final harness = await _pumpApp(tester);
      await _openManager(tester);

      for (final id in [
        'cat-default-briefcase',
        'cat-default-book',
        'cat-default-home',
        'cat-default-heart',
      ]) {
        await tapVisible(tester, CategoryManagerPage.deleteKey(id));
        await tester.tap(find.byKey(CategoryManagerPage.deleteConfirmKey));
        await tester.pumpAndSettle();
      }

      expect(await _names(harness), isEmpty);
      expect(find.byKey(CategoryManagerPage.emptyKey), findsOneWidget);
    });
  });

  group('设为默认（settings-spec §3、§2.4 behavior.defaultCategoryId）', () {
    /// 从列表页开编辑器，返回落库的那条任务的 categoryId。
    Future<String?> createTaskAndReadCategory(
      WidgetTester tester,
      Harness harness,
    ) async {
      await tester.tap(find.byKey(AppShell.fabKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '随手记');
      await tester.pump();
      await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
      await tester.pumpAndSettle();
      final rows = await harness.db.select(harness.db.tasks).get();
      return rows.last.categoryId;
    }

    testAppWidgets('设了之后，新任务默认落在那个分类', (tester) async {
      final harness = await _pumpApp(tester);
      await _openManager(tester);

      await tapVisible(
        tester,
        CategoryManagerPage.defaultKey('cat-default-briefcase'),
      );
      // 文字也要说出来 —— 星标是图标，图标不单独承载信息（§8.1）。
      expect(find.text('工作（默认）'), findsOneWidget);

      // 回列表，建一条**什么都不选**的任务。
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byType(BackButton).first);
        await tester.pumpAndSettle();
      }
      expect(
        await createTaskAndReadCategory(tester, harness),
        'cat-default-briefcase',
      );
    });

    testAppWidgets('对照组：没设过默认时，新任务是未分类', (tester) async {
      // 少了这条，一个「永远写第一个分类」的实现也能让上面绿。
      final harness = await _pumpApp(tester);
      expect(await createTaskAndReadCategory(tester, harness), isNull);
    });

    testAppWidgets('再点一次就取消，回到未分类', (tester) async {
      // 设错了却没有回头路，是最容易让人恼火的一类交互。
      final harness = await _pumpApp(tester);
      await _openManager(tester);

      final key = CategoryManagerPage.defaultKey('cat-default-briefcase');
      await tapVisible(tester, key);
      expect(find.text('工作（默认）'), findsOneWidget);
      await tapVisible(tester, key);
      expect(find.text('工作（默认）'), findsNothing);
      expect(find.text('工作'), findsOneWidget);

      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byType(BackButton).first);
        await tester.pumpAndSettle();
      }
      expect(await createTaskAndReadCategory(tester, harness), isNull);
    });

    testAppWidgets('删掉默认分类之后，新任务不会挂到一个死 id 上', (tester) async {
      // 配置里留着被删分类的 id 的话，新建任务的 categoryId 会指向一个
      // 不存在的分类 —— 卡片回落显示「未分类」，按「未分类」筛却找不到它。
      // 与删分类那条路上刚修过的缺陷同一个形状，只是入口换成了配置。
      final harness = await _pumpApp(tester);
      await _openManager(tester);

      await tapVisible(
        tester,
        CategoryManagerPage.defaultKey('cat-default-briefcase'),
      );
      await tapVisible(
        tester,
        CategoryManagerPage.deleteKey('cat-default-briefcase'),
      );
      await tester.tap(find.byKey(CategoryManagerPage.deleteConfirmKey));
      await tester.pumpAndSettle();

      // 存下来的那个值也得收干净，不能只靠读侧兜底。
      // 只验「新任务是未分类」的话，读侧那道回落会把这件事**盖住** ——
      // 变异演练里就是这样：把这里的收尾整段删掉，一条测试都不红。
      // 而留着死 id 有它自己的后果：导出时带出去一条指向不存在分类的配置，
      // 而且那个分类若从回收站恢复，它会**悄悄又变回默认**。
      final stored = await harness.db.select(harness.db.settings).get();
      final row = stored.firstWhere(
        (r) => r.key == 'behavior.defaultCategoryId',
      );
      expect(row.valueJson, contains('uncategorized'));

      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byType(BackButton).first);
        await tester.pumpAndSettle();
      }
      expect(await createTaskAndReadCategory(tester, harness), isNull);
    });

    testAppWidgets('配置里直接躺着一个不存在的 id，也回落成未分类', (tester) async {
      // 上一条验的是**写侧收尾**（删的时候把配置一并收回）。
      // 这一条验**读侧兜底**：配置可能来自导入、同步、或降级安装，
      // 那些路径上没有「删除」这个动作可挂钩。两处都要有。
      final harness = await _pumpApp(tester);
      await DriftSettingsRepository(
        harness.db,
        const FixedWriterIdentity('test-device'),
        FixedClock(DateTime.utc(2026, 9, 7, 3)),
      ).put(
        'behavior.defaultCategoryId',
        'cat-does-not-exist',
        scope: 'global',
      );
      await tester.pumpAndSettle();

      expect(await createTaskAndReadCategory(tester, harness), isNull);
    });
  });

  group('拖拽排序', () {
    testAppWidgets('把第一个拖到第二个下面，顺序真的换了', (tester) async {
      // **真拖一次**，不是直接调 reorder(0, 1)。
      // `ReorderableListView` 的两个回调对 newIndex 的约定差一个 1
      // （已废弃的 onReorder 给的是「插到第几个之前」，onReorderItem
      // 给的是移走后的最终下标）。接错的表现是「往下拖一格等于没动」，
      // 只有真拖才验得出来。
      final harness = await _pumpApp(tester);
      await _openManager(tester);

      final first = find.text('工作');
      final startY = tester.getCenter(first).dy;
      final secondY = tester.getCenter(find.text('学习')).dy;

      // 从拖拽把手起手（整行不可拖，见页面里的说明）。
      final handle = find
          .descendant(
            of: find.byKey(CategoryManagerPage.rowKey('cat-default-briefcase')),
            matching: find.byIcon(Icons.drag_handle),
          )
          .first;
      await _dragDown(tester, handle, secondY - startY);

      expect(await _names(harness), [
        '学习',
        '工作',
        '生活',
        '健康',
      ], reason: '往下拖一格应当与下一个互换 —— 没换多半是 newIndex 的约定接反了');
    });

    testAppWidgets('排序写回的是连续的 0..n-1', (tester) async {
      // 只改动过的那两条的话，序号会长出空洞与重复；
      // 而「按 orderIndex 升序」在重复值上的顺序是未定义的 ——
      // 表现为「排好的顺序过一会儿自己变了」。
      final harness = await _pumpApp(tester);
      await _openManager(tester);

      final handle = find
          .descendant(
            of: find.byKey(CategoryManagerPage.rowKey('cat-default-briefcase')),
            matching: find.byIcon(Icons.drag_handle),
          )
          .first;
      final startY = tester.getCenter(find.text('工作')).dy;
      final secondY = tester.getCenter(find.text('学习')).dy;
      await _dragDown(tester, handle, secondY - startY);

      final rows =
          (await harness.db.select(harness.db.categories).get())
              .where((c) => c.deletedAt == null)
              .map((c) => c.orderIndex)
              .toList()
            ..sort();
      expect(rows, [0, 1, 2, 3]);
    });
  });

  testAppWidgets('新建的分类，编辑器里立刻选得到', (tester) async {
    // 管理页与编辑器是两个 feature，中间隔着一个流。
    // 少了这条，一个「只写库不推流」的实现能让上面全部绿。
    await _pumpApp(tester, seed: false);
    await _openManager(tester);

    await tapVisible(tester, CategoryManagerPage.addButtonKey);
    await tester.enterText(find.byKey(CategoryManagerPage.nameFieldKey), '阅读');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CategoryManagerPage.nameConfirmKey));
    await tester.pumpAndSettle();

    // 回列表，开编辑器。
    // `pageBack()` 找的是 Cupertino 的返回按钮，这里没有。
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byType(BackButton).first);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(AppShell.fabKey));
    await tester.pumpAndSettle();

    expect(find.text('阅读'), findsOneWidget);
  });
}

/// **J-06**（testing-strategy §8、roadmap M4 验收）。
///
/// | # | 旅程 |
/// |---|---|
/// | J-06 | 改主题/分类 → **全视图**即时生效 |
///
/// ## 「全视图」才是这条的重点
///
/// 设置页里那条已有的用例验的是「配置走到了主题里」—— 它只在设置页
/// 自己那棵子树上量。而 J-06 问的是另一件事：**改完之后，四个视图
/// 是不是都已经变了**。
///
/// 这两件事会分开坏：主题挂在 `MaterialApp` 上，四个视图理应都跟着；
/// 但只要有一个视图在 build 时把颜色/圆角**算好存起来**（缓存一份、
/// 或者从一个不重建的祖先里取），它就会停在旧值上，
/// 而设置页那条用例照样绿。
///
/// 「即时」同样要验：不重启、不切走再回来。所以每一步之后直接切视图看。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/design/theme/app_theme.dart';
import 'package:planning_assistant/design/tokens/dimensions.dart';
import 'package:planning_assistant/features/settings/presentation/category_manager_page.dart';
import 'package:planning_assistant/features/settings/presentation/settings_page.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';
import 'package:planning_assistant/features/views/shared/application/view_kind.dart';

import '../support/app_harness.dart';

Future<Harness> _pumpApp(WidgetTester tester) async {
  await setScreenSize(tester, const Size(390, 844));
  final harness = appHarness();
  await tester.pumpWidget(
    ProviderScope(overrides: harness.overrides, child: PlanningAssistantApp()),
  );
  await tester.pumpAndSettle();
  await seedCategories(harness);
  await tester.pumpAndSettle();
  return harness;
}

/// 建一条挂着「工作」分类的任务。
Future<void> _createInWorkCategory(WidgetTester tester) async {
  await tapCreate(tester);
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '写周报');
  await tester.pump();
  await tester.tap(
    find.byKey(TaskEditorPage.categoryChipKey('cat-default-briefcase')),
  );
  await tester.pumpAndSettle();
  await tapVisible(tester, TaskEditorPage.saveButtonKey);
}

/// 切到某个视图，并把**那个视图子树里**的圆角档位读出来。
///
/// 从视图自己的 element 取，而不是从根取 —— 从根取的话，
/// 一个「视图子树里缓存了旧主题」的实现照样绿，而那正是要防的。
Future<CornerStyle> _cornersIn(WidgetTester tester, ViewKind kind) async {
  await tapVisible(tester, AppShell.viewTabKey(kind));
  await tester.pumpAndSettle();
  return Theme.of(tester.element(find.byKey(AppShell.viewTabKey(kind))))
      .extension<AppShape>()!
      .corners;
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(AppShell.settingsKey));
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  Navigator.of(tester.element(find.byKey(SettingsPage.pageKey))).pop();
  await tester.pumpAndSettle();
}

void main() {
  testAppWidgets('J-06 改主题 → 四个视图都即时变了', (tester) async {
    await _pumpApp(tester);

    for (final kind in ViewKind.values) {
      expect(
        await _cornersIn(tester, kind),
        CornerStyle.standard,
        reason: '前提：${kind.name} 一开始是标准圆角',
      );
    }

    await _openSettings(tester);
    await tapVisible(
      tester,
      SettingsPage.optionKey('theme.cornerStyle', 'sharp'),
    );
    await tester.pumpAndSettle();
    await _back(tester);

    for (final kind in ViewKind.values) {
      expect(
        await _cornersIn(tester, kind),
        CornerStyle.sharp,
        reason: '${kind.name} 停在旧主题上了 —— 它多半自己缓存了一份',
      );
    }
  });

  testAppWidgets('J-06 改分类名 → 卡片上的名字即时变了', (tester) async {
    // 分类名在卡片上是**文字**（§8.1：颜色不是唯一载体），
    // 所以改名之后每张卡片都要跟着变。
    await _pumpApp(tester);
    await _createInWorkCategory(tester);

    Finder nameOnCard(String name) =>
        find.descendant(of: find.byType(TaskCard), matching: find.text(name));

    expect(nameOnCard('工作'), findsOneWidget, reason: '前提：卡片上写着「工作」');

    await _openSettings(tester);
    await tapVisible(tester, SettingsPage.categoriesEntryKey);
    await tapVisible(
      tester,
      CategoryManagerPage.renameKey('cat-default-briefcase'),
    );
    await tester.enterText(find.byKey(CategoryManagerPage.nameFieldKey), '正事');
    await tester.pump();
    await tapVisible(tester, CategoryManagerPage.nameConfirmKey);

    Navigator.of(tester.element(find.byKey(CategoryManagerPage.pageKey))).pop();
    await tester.pumpAndSettle();
    await _back(tester);

    expect(nameOnCard('正事'), findsOneWidget, reason: '改完名字卡片没跟着变');
    expect(nameOnCard('工作'), findsNothing, reason: '旧名字还留在卡片上');
  });

  testAppWidgets('J-06 对照组：没改任何东西时，切视图不会自己变', (tester) async {
    // 少了它，一个「每次切视图都随机/递增换个圆角」的实现
    // 在第一条里也能过 —— 它同样会在改完之后「变成」sharp。
    await _pumpApp(tester);
    for (var i = 0; i < 2; i++) {
      for (final kind in ViewKind.values) {
        expect(await _cornersIn(tester, kind), CornerStyle.standard);
      }
    }
  });
}

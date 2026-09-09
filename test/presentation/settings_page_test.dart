/// 设置页（settings-spec §4、FR-CFG-07、NFR-MAINT-04）。
///
/// FR-CFG-07 与 NFR-MAINT-04 说的是同一件事的两面：
/// 「新增一个配置项只需加一条声明，UI 自动渲染」＝「新增一个配置项
/// ≤ 1 处改动」。下面那条「每个暴露项都出现」是它的验收 ——
/// 页面**遍历注册表**渲染，注册表里多一条就自动多一行。
///
/// 最要紧的一条不是「页面画出来了」，而是**改了真的生效**：
/// 一个改完没反应的开关比没有更糟。所以这里走真库、真路由，
/// 改完之后去列表上看结果。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/design/theme/app_theme.dart';
import 'package:planning_assistant/design/tokens/dimensions.dart';
import 'package:planning_assistant/features/settings/application/registry.dart';
import 'package:planning_assistant/features/settings/domain/setting_spec.dart';
import 'package:planning_assistant/features/settings/presentation/settings_page.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';
import 'package:planning_assistant/features/views/task_list/presentation/task_list_page.dart';

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

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(AppShell.settingsKey));
  await tester.pumpAndSettle();
}

void main() {
  group('页面由注册表渲染（FR-CFG-07、NFR-MAINT-04）', () {
    testAppWidgets('每个暴露项都出现，隐藏项不出现', (tester) async {
      await _pumpApp(tester);
      await _openSettings(tester);

      for (final spec in settingsRegistry) {
        final finder = find.byKey(SettingsPage.itemKey(spec.key));
        if (spec.isExposed) {
          // **要先滚过去**：`ListView` 只建看得见的那几项，
          // 页面一长，靠后的项压根没进树 —— 断言会报「找不到」，
          // 而它其实只是还没建。加两项配置就让这条红过一次。
          await tester.scrollUntilVisible(finder, 200);
          await tester.pumpAndSettle();
          expect(finder, findsOneWidget, reason: '${spec.key} 该出现却没有');
        } else {
          expect(finder, findsNothing, reason: '${spec.key} 是隐藏项，不该出现');
        }
      }
    });

    testAppWidgets('每个 select 项的每个选项都画出来了', (tester) async {
      // 少画一个选项 = 那个值用户永远选不到，而它在注册表里看着是支持的。
      await _pumpApp(tester);
      await _openSettings(tester);

      for (final spec in settingsRegistry.where(
        (s) => s.isExposed && s.editor == SettingEditor.select,
      )) {
        for (final (value, _) in spec.optionsDynamic) {
          final finder = find.byKey(
            SettingsPage.optionKey(spec.key, '${spec.encodeDynamic(value)}'),
          );
          // 同上：靠后的项要先滚出来才建得出来。
          await tester.scrollUntilVisible(finder, 200);
          await tester.pumpAndSettle();
          expect(finder, findsOneWidget, reason: '${spec.key} 少了一个选项');
        }
      }
    });

    testAppWidgets('分组标题按 SettingGroup 的顺序出现', (tester) async {
      await _pumpApp(tester);
      await _openSettings(tester);

      final used = settingsRegistry
          .where((s) => s.isExposed)
          .map((s) => s.group)
          .toSet();
      for (final group in used) {
        final finder = find.text(group!.title);
        // 同上：靠后的分组要先滚出来才建得出来。
        //
        // 这条一度是**直接断言**的，于是「视图」组多加一个配置项之后，
        // 「行为」被挤出 cacheExtent，报的是「找不到『行为』」——
        // 看起来像分组渲染坏了，实际上只是没滚到。
        // `tapVisible` 的注释里记的是同一个坑的另一副面孔。
        await tester.scrollUntilVisible(finder, 200);
        await tester.pumpAndSettle();
        expect(finder, findsOneWidget);
      }
    });

    testAppWidgets('没有暴露项的分组不画空标题', (tester) async {
      await _pumpApp(tester);
      await _openSettings(tester);

      final used = settingsRegistry
          .where((s) => s.isExposed)
          .map((s) => s.group)
          .toSet();
      for (final group in SettingGroup.values.where((g) => !used.contains(g))) {
        expect(
          find.text(group.title),
          findsNothing,
          reason: '「${group.title}」这一组一个暴露项都没有，不该出现标题',
        );
      }
    });
  });

  group('改了真的生效', () {
    testAppWidgets('改「列表分组」，列表的分组标题跟着变', (tester) async {
      // 这条是整个设置页的意义所在。只验「页面画出来了」的话，
      // 一个写不进库的实现也能全绿。
      final harness = await _pumpApp(tester);

      // 先建一条有分类的任务，好让「按分类」分组有东西可分。
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

      // 默认按日期分组：这条没日期，所以在「无日期」组里。
      expect(
        find.byKey(TaskListPage.groupHeaderKey('no-date')),
        findsOneWidget,
      );

      await _openSettings(tester);
      await tester.tap(
        find.byKey(SettingsPage.optionKey('view.listGroupBy', 'category')),
      );
      await tester.pumpAndSettle();

      // 回到列表。**不用 tester.pageBack()** —— 它找的是 Cupertino 的
      // 返回键，而这里是 Material 的。
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          TaskListPage.groupHeaderKey('category:cat-default-briefcase'),
        ),
        findsOneWidget,
        reason: '改成按分类分组后，组标题应当是分类名',
      );
      expect(find.byKey(TaskListPage.groupHeaderKey('no-date')), findsNothing);

      // 而且真的落库了 —— 不只是内存里的一个变量。
      final rows = await harness.db.select(harness.db.settings).get();
      expect(rows.map((r) => r.key), contains('view.listGroupBy'));
    });

    testAppWidgets('选中态跟着当前值走', (tester) async {
      await _pumpApp(tester);
      await _openSettings(tester);

      // 默认是「按日期」。
      final byDate = find.byKey(
        SettingsPage.optionKey('view.listGroupBy', 'date'),
      );
      expect(
        find.descendant(of: byDate, matching: find.byIcon(Icons.check)),
        findsOneWidget,
        reason: '当前值应当有勾',
      );

      await tester.tap(
        find.byKey(SettingsPage.optionKey('view.listGroupBy', 'priority')),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: byDate, matching: find.byIcon(Icons.check)),
        findsNothing,
        reason: '换了之后旧的那个不该还带勾',
      );
    });

    testAppWidgets('圆角档位改完，卡片画出来的圆角跟着变', (tester) async {
      // 这条配置一路要穿过主题装配才到得了组件 ——
      // 中间断一节，设置页照样「看起来生效了」。
      await _pumpApp(tester);
      await _openSettings(tester);

      // 量**主题里的档位**，不是随便一个 DecoratedBox 的圆角。
      //
      // 初版抓了设置页里第一个 DecoratedBox —— 那是选项药丸，
      // 用的是 Radii.full，而 full 按约定本来就不参与档位缩放，
      // 于是「改了没变」被误判成缺陷。
      //
      // 「档位 → 组件画出来的圆角」那一段由
      // `design/component_assertions_test.dart` 验（三档三个值）；
      // 这里要验的是**配置能不能到达主题**。
      CornerStyle currentCorners() =>
          Theme.of(tester.element(find.byKey(SettingsPage.pageKey)))
              .extension<AppShape>()!
              .corners;

      expect(currentCorners(), CornerStyle.standard);

      await tester.tap(
        find.byKey(SettingsPage.optionKey('theme.cornerStyle', 'sharp')),
      );
      await tester.pumpAndSettle();

      expect(currentCorners(), CornerStyle.sharp, reason: '配置没走到主题里');
    });
  });
}

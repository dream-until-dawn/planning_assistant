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

    testAppWidgets('每个暴露项都画出了**能操作的控件**，没有一处占位文字', (tester) async {
      // ## 为什么「出现了」不够
      //
      // 上面那条只问「这一行在不在」。而 `_SettingTile` 对没实现的
      // 控件类型画的是一句灰字（「这个类型的控件还没做：toggle」）——
      // 那一行**照样在**，key 也照样有，于是那条完全通得过。
      //
      // 后果撞见过：`SettingEditor` 的默认值是 `toggle`，而 toggle
      // 一直没实现，于是**每一个暴露的布尔项都是一句灰字** ——
      // 提醒总开关、减少动效、免打扰、自动备份，四个开关用户一个也拨不动。
      // 真机截图上一眼就看见了，而 1699 条用例全绿。
      //
      // 「模型有旋钮、界面够不着」的又一例，所以补这一条。
      await _pumpApp(tester);
      await _openSettings(tester);

      for (final spec in settingsRegistry.where((s) => s.isExposed)) {
        final tile = find.byKey(SettingsPage.itemKey(spec.key));
        await tester.scrollUntilVisible(tile, 200);
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: tile, matching: find.textContaining('还没做')),
          findsNothing,
          reason: '${spec.key} 画的是占位文字 —— 它的 ${spec.editor.name} 控件没实现',
        );
      }
    });

    testAppWidgets('配置文件里把开关写坏了，页面照样是个开关（回落到默认值）', (tester) async {
      // ## 这条钉的是一句「到不了」的话
      //
      // settings-spec §5 明写着隐藏项可以由手改的配置文件覆盖，
      // 于是有人会问：**值的类型写错了会怎样？** 评审问的就是这个，
      // 猜测是「静默退回那句『控件还没做』的灰字」——
      // 那会让一个「数据坏了」看起来像一个「功能没做」。
      //
      // 实测不是：`SettingSpec<bool>.decode` 的返回类型就是 `bool`，
      // 解不动时回落到默认值。所以页面上永远是个能拨的开关。
      //
      // 把这条钉下来，是因为 `_SettingTile` 里那个 `as bool` 依赖它。
      //
      // **它被哪种改动推倒，演练过**：把 `settingDynamic` 改成跳过
      // decode、直接交出库里存的值（一个看着像优化的改动），
      // 这条当场报 `type 'String' is not a subtype of type 'bool'`。
      // 而只把某条 `decode` 改成遇坏值抛异常**不会**让它红 ——
      // 那一层外面还有一道 catch 回落到默认值。两件事都记下来，
      // 免得下一个人以为它守着后者。
      final harness = appHarness();
      await seedSettingBeforeApp(harness, autoBackupEnabled, false);
      // 绕开 SettingSpec 直接写一个坏值 —— 手改配置文件就是这样。
      await seedRawSetting(harness, autoBackupEnabled.key, 'yes');

      await setScreenSize(tester, const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: harness.overrides,
          child: PlanningAssistantApp(),
        ),
      );
      await tester.pumpAndSettle();
      await _openSettings(tester);

      final tile = find.byKey(SettingsPage.itemKey(autoBackupEnabled.key));
      await tester.scrollUntilVisible(tile, 200);
      await tester.pumpAndSettle();

      final toggle = find.descendant(of: tile, matching: find.byType(Switch));
      expect(toggle, findsOneWidget, reason: '坏值把开关变没了');
      expect(
        tester.widget<Switch>(toggle).value,
        autoBackupEnabled.defaultValue,
        reason: '坏值该回落到默认值',
      );
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
    testAppWidgets('拨一下开关，配置写进库，别的页面读到的也变了', (tester) async {
      // 开关这一类控件的「生效」尤其容易只做一半：`Switch` 自己会
      // **看起来**被拨过去（它是受控的，但 Flutter 的开关有动画），
      // 而值没写进库。所以断言落在**另一页读出来的那句话**上，
      // 不落在开关自己的外观上。
      await _pumpApp(tester);
      await _openSettings(tester);

      await tapVisible(tester, SettingsPage.toggleKey(autoBackupEnabled.key));
      await tapVisible(tester, SettingsPage.backupEntryKey);

      expect(find.text('自动备份：已关闭'), findsOneWidget);
    });

    testAppWidgets('改「列表分组」，列表的分组标题跟着变', (tester) async {
      // 这条是整个设置页的意义所在。只验「页面画出来了」的话，
      // 一个写不进库的实现也能全绿。
      final harness = await _pumpApp(tester);

      // 先建一条有分类的任务，好让「按分类」分组有东西可分。
      await tapCreate(tester);
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

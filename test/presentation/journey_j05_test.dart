/// **J-05**（testing-strategy §8、roadmap M4 验收）。
///
/// | # | 旅程 |
/// |---|---|
/// | J-05 | 导出 → 清空数据 → 导入 → 数据等价 |
///
/// ## 「数据等价」怎么判
///
/// 只看「任务又出现在列表里」是不够的：一个把备份里的**标题**读出来、
/// 别的字段全用默认值重建一遍的实现，在列表上一模一样。
///
/// 所以这条用例判两次：
///
///  1. **界面上**那条任务回来了、主题也回到备份时那一档 ——
///     这是用户看得见的那一半；
///  2. **整库导出与那份备份的 `data` 段逐字段相等** ——
///     这是看不见的那一半。它同时挡住两种错：字段丢了（重建得不全），
///     以及删掉的东西没清干净（`import` 是整库替换，不是合并）。
///
/// ## 为什么备份/恢复走界面，而配置用 `seedSetting`
///
/// 这条旅程要验的是**导出与导入这条路**，所以那两下必须点在真按钮上。
/// 配置只是「库里有点东西可验」的布景 —— 走设置页会让用例长一倍，
/// 而设置页自己有 `settings_page_test` 与 J-06 盯着。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/data/dto/export_bundle.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/features/data_transfer/presentation/backup_page.dart';
import 'package:planning_assistant/features/settings/application/registry.dart';
import 'package:planning_assistant/features/settings/presentation/settings_page.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';

import '../support/app_harness.dart';

Future<void> _openBackupPage(WidgetTester tester) async {
  await tester.tap(find.byKey(AppShell.settingsKey));
  await tester.pumpAndSettle();
  await tapVisible(tester, SettingsPage.backupEntryKey);
}

/// 从备份页退回列表：备份 → 设置 → 外壳，两下。
Future<void> _backToList(WidgetTester tester) async {
  await tapBack(tester);
  await tapBack(tester);
}

Brightness _brightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(AppShell))).brightness;

void main() {
  testAppWidgets('J-05 导出 → 清空数据 → 导入 → 数据等价', (tester) async {
    await setScreenSize(tester, const Size(390, 844));
    final harness = appHarness();
    // 自动备份先关掉：不关的话启动那一下就自己备了一份（空库的），
    // 而下面要恢复的是**建完任务之后**那一份 —— 两份混在一起说不清。
    await seedSettingBeforeApp(harness, autoBackupEnabled, false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides,
        child: PlanningAssistantApp(),
      ),
    );
    await tester.pumpAndSettle();
    await seedCategories(harness);
    await tester.pumpAndSettle();

    // ── 布景：一条任务 + 一项看得见的配置 ──────────────────────
    await tapCreate(tester);
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '写周报');
    await tester.pump();
    await tapVisible(tester, TaskEditorPage.saveButtonKey);
    expect(find.text('写周报'), findsOneWidget);

    await seedSetting(tester, themeMode, ThemeModeSetting.dark);
    expect(_brightness(tester), Brightness.dark, reason: '前提没摆好');

    // ── 导出：备份页上按「立即备份」 ────────────────────────────
    await _openBackupPage(tester);
    await tester.tap(find.byKey(BackupPage.backupNowKey));
    await tester.pumpAndSettle();
    await waitOutSnackBar(tester);

    final name = (await harness.backups.list()).single.name;
    final backedUp = decodeExportBundle(
      harness.backups.contentsOf(name),
    )['data'];

    // ── 清空：删掉任务、把配置改回去 ────────────────────────────
    await _backToList(tester);
    await openEditorFromCard(tester);
    await tester.tap(find.byKey(TaskEditorPage.deleteButtonKey));
    await tester.pumpAndSettle();
    expect(find.byType(TaskCard), findsNothing, reason: '没删掉，后面验的就是假的');

    await seedSetting(tester, themeMode, ThemeModeSetting.light);
    expect(_brightness(tester), Brightness.light);

    // ── 导入：恢复那一份 ────────────────────────────────────────
    await _openBackupPage(tester);
    await tester.tap(find.byKey(BackupPage.restoreKey(name)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(BackupPage.restoreConfirmKey));
    await tester.pumpAndSettle();

    // ── 等价（一）：用户看得见的那一半 ──────────────────────────
    await _backToList(tester);
    expect(find.text('写周报'), findsOneWidget, reason: '任务没回来');
    expect(_brightness(tester), Brightness.dark, reason: '配置没跟着回来');

    // ── 等价（二）：看不见的那一半 ──────────────────────────────
    // 再导出一次，与那份备份的 `data` 段比。**逐字段相等**才算等价：
    // 少一个字段、或者多一行没清掉的旧数据，都会在这里露出来。
    final now = await ExportService(harness.db).export(
      appVersion: '1.0.0',
      deviceId: 'test-device',
      exportedAt: DateTime.utc(2026, 9, 7, 3),
    );
    expect(now['data'], backedUp);
  });

  testAppWidgets('FR-DATA-04 恢复错了一份，能从「恢复前的那一份」退回来（评审 M4-B3）', (tester) async {
    // ## 为什么这一条要走界面、走真库
    //
    // `backup_service_test` 里那条同名的用例是拿假端口验的 ——
    // 它证明的是**服务这一层的编排**对。而「真的救得回来」还要跨过
    // 整库导出/导入那一段：一份存下来的 JSON 到底能不能把库还原成
    // 刚才的样子，只有真库答得了。
    //
    // 场景就是评审说的那个：「我以为这是昨天那份」—— 用户点错一份，
    // 今天干的活全没了。而自动备份默认 7 天一次，所以最坏一周。
    await setScreenSize(tester, const Size(390, 844));
    final harness = appHarness();
    await seedSettingBeforeApp(harness, autoBackupEnabled, false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides,
        child: PlanningAssistantApp(),
      ),
    );
    await tester.pumpAndSettle();
    await seedCategories(harness);
    await tester.pumpAndSettle();

    // ── 昨天：库里什么都没有，存一份 ──────────────────────────
    await _openBackupPage(tester);
    await tester.tap(find.byKey(BackupPage.backupNowKey));
    await tester.pumpAndSettle();
    await waitOutSnackBar(tester);
    final stale = (await harness.backups.list()).single.name;

    // ── 今天：干了一天活 ──────────────────────────────────────
    await _backToList(tester);
    await tapCreate(tester);
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '今天的活');
    await tester.pump();
    await tapVisible(tester, TaskEditorPage.saveButtonKey);
    expect(find.text('今天的活'), findsOneWidget);

    // ── 手滑：恢复到了昨天那一份 ──────────────────────────────
    await _openBackupPage(tester);
    await tester.tap(find.byKey(BackupPage.restoreKey(stale)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(BackupPage.restoreConfirmKey));
    await tester.pumpAndSettle();

    await _backToList(tester);
    expect(find.text('今天的活'), findsNothing, reason: '前提：确实恢复错了');

    // ── 退路：列表最上面那一份就是「恢复前」的状态 ────────────
    await _openBackupPage(tester);
    final rescue = (await harness.backups.list()).first.name;
    expect(rescue, isNot(stale), reason: '退路把要恢复的那一份盖掉了');
    await tester.tap(find.byKey(BackupPage.restoreKey(rescue)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(BackupPage.restoreConfirmKey));
    await tester.pumpAndSettle();

    await _backToList(tester);
    expect(find.text('今天的活'), findsOneWidget, reason: '退路没救回来');
  });
}

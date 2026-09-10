/// 备份页（FR-DATA-04/05、roadmap M4「导入导出 UI + 自动备份」）。
///
/// ## 这一份验的是「按钮真的接上了」
///
/// `backup_service_test` 已经把判断（起名、留几份、什么时候自动备）
/// 验完了。留给这一层的是那条最容易悄悄断掉的：**界面上那几下
/// 到底有没有走到服务**。画一个按钮摆着与真的去备份，在截图里
/// 长得一模一样 —— 这块功能的历史教训全是这一类
/// （「模型有旋钮、界面够不着」）。
///
/// 恢复与删除**都要先问一句**，所以每条路径都验到确认框那一步：
/// 少了确认，一次误触就把整库换掉了。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/features/data_transfer/presentation/backup_page.dart';
import 'package:planning_assistant/features/settings/application/registry.dart';
import 'package:planning_assistant/features/settings/presentation/settings_page.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';

import '../support/app_harness.dart';

/// 起一棵应用树，**自动备份先关掉**。
///
/// 不关的话，启动那一下就自己备了一份 —— 于是「一份都没有时是空态」
/// 这条根本摆不出前提，而「按了立即备份之后多了一份」也说不清
/// 多的是哪一份。自动备份自己那几条在 `auto_backup_test` 里验。
Future<Harness> _pumpApp(WidgetTester tester) async {
  await setScreenSize(tester, const Size(390, 844));
  final harness = appHarness();
  await seedSettingBeforeApp(harness, autoBackupEnabled, false);
  await tester.pumpWidget(
    ProviderScope(overrides: harness.overrides, child: PlanningAssistantApp()),
  );
  await tester.pumpAndSettle();
  return harness;
}

/// 设置 → 备份与恢复。**从设置页点进去**，不直接开路由 ——
/// 「设置里有没有这个入口」也是要验的东西之一。
Future<void> _openBackup(WidgetTester tester) async {
  await tester.tap(find.byKey(AppShell.settingsKey));
  await tester.pumpAndSettle();
  await tapVisible(tester, SettingsPage.backupEntryKey);
  expect(find.byKey(BackupPage.pageKey), findsOneWidget);
}

void main() {
  testAppWidgets('FR-DATA-05 一份备份都没有时是空态', (tester) async {
    await _pumpApp(tester);
    await _openBackup(tester);

    expect(find.byKey(BackupPage.emptyKey), findsOneWidget);
  });

  testAppWidgets('FR-DATA-05 按「立即备份」真的写出一份，并回一句话', (tester) async {
    final harness = await _pumpApp(tester);
    await _openBackup(tester);

    await tester.tap(find.byKey(BackupPage.backupNowKey));
    await tester.pumpAndSettle();

    // **问落盘的那一侧**，不是只看界面上多了一行 ——
    // 一个只往列表里塞一条假记录的实现在界面上一模一样。
    expect(harness.backups.count, 1);
    expect(find.byKey(BackupPage.emptyKey), findsNothing);
    // 没有回音的按钮会让人反复按，而每按一次就多一份。
    expect(find.text('已备份'), findsOneWidget);
  });

  testAppWidgets('FR-DATA-05 列表里那一行显示的是时刻，不是文件名', (tester) async {
    // 文件名是 UTC 的 ISO 串（`backup-2026-09-07T03-00-00.json`），
    // 用户读不出「哪一次」—— 而他要挑的正是「哪一次」。
    final harness = await _pumpApp(tester);
    await _openBackup(tester);
    await tester.tap(find.byKey(BackupPage.backupNowKey));
    await tester.pumpAndSettle();

    final name = (await harness.backups.list()).single.name;
    expect(find.text(name), findsNothing);
    expect(find.byKey(BackupPage.itemKey(name)), findsOneWidget);
  });

  testAppWidgets('FR-DATA-05 保留份数用的是配置里那个值，不是写死的', (tester) async {
    // 少了这条，`backupNow(keepCount: 5)` 里写死一个 5 也全绿 ——
    // 而那个隐藏项就成了摆设（FR-CFG-08 说的正是「隐藏项也要真的生效」）。
    final harness = appHarness();
    await seedSettingBeforeApp(harness, autoBackupEnabled, false);
    await seedSettingBeforeApp(harness, autoBackupKeepCount, 1);
    harness.backups.seed('backup-old.json', at: DateTime.utc(2026, 9, 1));
    harness.backups.seed('backup-mid.json', at: DateTime.utc(2026, 9, 2));

    await setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: harness.overrides,
        child: PlanningAssistantApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _openBackup(tester);

    await tester.tap(find.byKey(BackupPage.backupNowKey));
    await tester.pumpAndSettle();

    expect(
      harness.backups.count,
      1,
      reason: '保留数是 1，却留下了 ${harness.backups.count} 份',
    );
    expect(harness.backups.deleted..sort(), [
      'backup-mid.json',
      'backup-old.json',
    ]);
  });

  group('FR-DATA-04 恢复前先问一句', () {
    testAppWidgets('点「恢复」先弹确认，取消就什么也不做', (tester) async {
      final harness = await _pumpApp(tester);
      await _openBackup(tester);
      await tester.tap(find.byKey(BackupPage.backupNowKey));
      await tester.pumpAndSettle();
      // 「已备份」那条提示不等掉的话，后面那条永远排不上来。
      await waitOutSnackBar(tester);
      final name = (await harness.backups.list()).single.name;

      await tester.tap(find.byKey(BackupPage.restoreKey(name)));
      await tester.pumpAndSettle();
      expect(find.byKey(BackupPage.restoreConfirmKey), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      // 取消了就不该有「已恢复」那句话。
      expect(find.textContaining('已恢复'), findsNothing);
    });

    testAppWidgets('确认之后真的恢复了', (tester) async {
      final harness = await _pumpApp(tester);
      await _openBackup(tester);
      await tester.tap(find.byKey(BackupPage.backupNowKey));
      await tester.pumpAndSettle();
      // 「已备份」那条提示不等掉的话，后面那条永远排不上来。
      await waitOutSnackBar(tester);
      final name = (await harness.backups.list()).single.name;

      await tester.tap(find.byKey(BackupPage.restoreKey(name)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BackupPage.restoreConfirmKey));
      await tester.pumpAndSettle();

      expect(find.textContaining('已恢复'), findsOneWidget);
    });
  });

  group('FR-DATA-05 删除前也问一句', () {
    testAppWidgets('取消就不删', (tester) async {
      final harness = await _pumpApp(tester);
      await _openBackup(tester);
      await tester.tap(find.byKey(BackupPage.backupNowKey));
      await tester.pumpAndSettle();
      // 「已备份」那条提示不等掉的话，后面那条永远排不上来。
      await waitOutSnackBar(tester);
      final name = (await harness.backups.list()).single.name;

      await tester.tap(find.byKey(BackupPage.deleteKey(name)));
      await tester.pumpAndSettle();
      expect(find.byKey(BackupPage.deleteConfirmKey), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(harness.backups.count, 1, reason: '取消了却删了');
    });

    testAppWidgets('确认之后那一行消失，文件也没了', (tester) async {
      final harness = await _pumpApp(tester);
      await _openBackup(tester);
      await tester.tap(find.byKey(BackupPage.backupNowKey));
      await tester.pumpAndSettle();
      // 「已备份」那条提示不等掉的话，后面那条永远排不上来。
      await waitOutSnackBar(tester);
      final name = (await harness.backups.list()).single.name;

      await tester.tap(find.byKey(BackupPage.deleteKey(name)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(BackupPage.deleteConfirmKey));
      await tester.pumpAndSettle();

      expect(harness.backups.deleted, [name]);
      expect(find.byKey(BackupPage.itemKey(name)), findsNothing);
      // 列表刷了才看得到空态 —— 少了 `invalidate` 这一行会留在那儿。
      expect(find.byKey(BackupPage.emptyKey), findsOneWidget);
    });
  });

  group('FR-DATA-05 页头说清自动备份现在是什么状态', () {
    testAppWidgets('关着时说「已关闭」', (tester) async {
      await _pumpApp(tester);
      await _openBackup(tester);
      expect(find.text('自动备份：已关闭'), findsOneWidget);
    });

    testAppWidgets('开着时**每个档位都说人话**，且改完立刻变', (tester) async {
      // 遍历注册表里的档位，而不是挑一个写死 —— 一度写的是
      // 「每 $天数 天一次」，于是「每天」说成「每 1 天一次」、
      // 「每月」说成「每 30 天一次」（一个月不是 30 天）。
      // 挑一个档位断言的话，恰好挑中 7 就永远发现不了。
      //
      // 这条同时钉住「标签只有一个出处」：句子里的说法必须来自
      // `options`，加一个新档位不用记着还有第二处要改。
      await _pumpApp(tester);
      await _openBackup(tester);
      await seedSetting(tester, autoBackupEnabled, true);

      for (final (value, label) in autoBackupIntervalDays.options) {
        await seedSetting(tester, autoBackupIntervalDays, value);
        expect(
          find.text('自动备份：$label一次'),
          findsOneWidget,
          reason: '档位 $value 该说「$label」',
        );
      }
    });
  });
}

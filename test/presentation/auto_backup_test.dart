/// 启动时的自动备份（FR-DATA-05）。
///
/// ## 为什么这几条在 presentation 层，而不是跟着服务走
///
/// 「什么时候该备」那个判断已经在 `backup_service_test` 里验完了
/// （距上一份多久、关掉时不备、一份都没有时立刻备）。
/// 这一份问的是另一件事：**那个判断在启动时到底被喂进了什么**。
///
/// 配置是流式读出来的，而解析层对「还没读出来」的回落是**默认值**
/// —— 默认值恰好是「开着、7 天、留 5 份」。在首帧就问一次的实现
/// 在库里存着 `enabled = false` 时**照样会备一份**：
/// 备份成功、文件也在，界面上一点都看不出不对。
///
/// 所以下面第一条是这一份的主角：它是**唯一**能把那个错误分开的用例。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/features/settings/application/registry.dart';

import '../support/app_harness.dart';

Future<void> _boot(WidgetTester tester, Harness harness) async {
  await setScreenSize(tester, const Size(390, 844));
  await tester.pumpWidget(
    ProviderScope(overrides: harness.overrides, child: PlanningAssistantApp()),
  );
  await tester.pumpAndSettle();
}

void main() {
  testAppWidgets('FR-DATA-05 关掉自动备份之后，启动不该备份', (tester) async {
    final harness = appHarness();
    // **必须在第一帧之前就在库里** —— 启动之后再关，验的是另一件事。
    await seedSettingBeforeApp(harness, autoBackupEnabled, false);

    await _boot(tester, harness);

    expect(
      harness.backups.count,
      0,
      reason:
          '关掉了却还是备了 —— 多半是在配置读出来之前就问了一次，'
          '那时读到的是默认值（开着）',
    );
  });

  testAppWidgets('FR-DATA-05 开着且一份都没有时，启动备一份', (tester) async {
    // 上面那条的对照组。少了它，一个「永远不备份」的实现也能过 ——
    // 而那种实现在界面上同样看不出来（备份页只是一直空着）。
    final harness = appHarness();
    await _boot(tester, harness);

    expect(harness.backups.count, 1);
  });

  testAppWidgets('FR-DATA-05 最近一份还不到间隔时，启动不备', (tester) async {
    final harness = appHarness();
    // 默认 7 天一次；摆一份 1 天前的。
    harness.backups.seed(
      'backup-yesterday.json',
      at: DateTime.utc(2026, 9, 6, 3),
    );

    await _boot(tester, harness);

    expect(harness.backups.count, 1, reason: '刚备过又备了一份');
  });

  testAppWidgets('FR-DATA-05 间隔改成 1 天之后，那份 1 天前的就到期了', (tester) async {
    // 与上一条**只差一个配置**：同样的一份旧备份，间隔从 7 天改成 1 天，
    // 结论必须翻过来。翻不过来说明间隔那个配置根本没被读。
    final harness = appHarness();
    await seedSettingBeforeApp(harness, autoBackupIntervalDays, 1);
    harness.backups.seed(
      'backup-yesterday.json',
      at: DateTime.utc(2026, 9, 6, 3),
    );

    await _boot(tester, harness);

    expect(harness.backups.count, 2);
  });

  testAppWidgets('FR-DATA-05 自动备份写出来的是真的整库导出，不是空壳', (tester) async {
    // `appHarness` 发的是真的 `JsonExportAdapter`，所以这份文件里
    // 该有导出格式的头。断言它是为了挡住「写个占位文件就算备份了」——
    // 那种实现在「有没有多一份」上完全通得过。
    final harness = appHarness();
    await seedCategories(harness);
    await _boot(tester, harness);

    final name = (await harness.backups.list()).single.name;
    final contents = harness.backups.contentsOf(name);
    expect(contents, contains('"formatVersion"'));
    expect(contents, contains('"categories"'));
  });
}

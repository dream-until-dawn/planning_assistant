/// 零配置冒烟（FR-CFG-01、roadmap M4 验收）。
///
/// > 全新安装、**不进设置页**，所有功能可用。
///
/// ## 它与注册表自检不是一回事
///
/// `settings_registry_test` 验的是「每条配置的默认值自身合法、能往返」——
/// 那是**声明**层面的。这一份验的是**行为**：一个从没写过任何配置行的
/// 库，跑完整条链路不会有任何一处读到空值就塌下来。
///
/// 两者都绿才等于 FR-CFG-01 成立：默认值声明得再好，只要有一处代码
/// 绕过注册表直接读库、并且没有处理「读不到」，全新安装就是坏的 ——
/// 而那种缺陷**只有第一次装的人会遇到**，团队自己的机器上永远复现不了。
///
/// ## 收尾那条断言才是关键
///
/// 末尾断言 `settings` 表**一行都没有**。少了它，这份用例在一个
/// 「启动时把所有默认值写进库」的实现下照样全绿 —— 而那个实现
/// 恰恰把「零配置」变成了「启动时自动配置一遍」，两者在出问题时
/// 表现完全不同（后者的库里有一份可能过期的快照）。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/features/settings/presentation/settings_page.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/task/application/task_shape.dart';
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
  return harness;
}

Future<void> _create(WidgetTester tester, TaskShape shape, String title) async {
  await tapCreate(tester, shape);
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), title);
  await tester.pump();
  // 阶段事项要两个阶段、每个都要有时间（用户 2026-09-10「加强必填项校验」），
  // 否则保存键是灰的 —— 而这一份要验的是「零配置下链路走得通」，
  // 不是必填规则本身。
  if (shape.hasStages) {
    for (final name in ['打包', '搬运']) {
      await addStage(tester, name);
    }
  }
  await tapVisible(tester, TaskEditorPage.saveButtonKey);
}

void main() {
  testAppWidgets('FR-CFG-01 全新安装、不进设置页，一整条链路都走得通', (tester) async {
    final harness = await _pumpApp(tester);

    // ① 五种形态里挑三种建出来 —— 它们各自读不同的默认值
    //    （临时事项不读默认时长，单事项读，阶段事项还多读阶段那一路）。
    await _create(tester, TaskShape.scratch, '随手记');
    await _create(tester, TaskShape.single, '开会');
    await _create(tester, TaskShape.staged, '搬家');
    expect(find.byType(TaskCard), findsWidgets);

    // ② 四个视图挨个进一遍。任何一个视图在读不到配置时塌下来，
    //    全新安装的用户会看到一片空白，而他还没来得及做任何事。
    for (final kind in ViewKind.values) {
      await tapVisible(tester, AppShell.viewTabKey(kind));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '${kind.name} 视图在零配置下就崩了');
    }

    // ③ 回到列表，勾一条完成 —— 撤销提示的停留时长也是一条配置
    //    （`behavior.undoDurationSeconds`）。
    await tapVisible(tester, AppShell.viewTabKey(ViewKind.list));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(TaskCard.doneButtonKey).first);
    await tester.pumpAndSettle();
    expect(find.text('撤销'), findsOneWidget);

    // ④ 归档与回收站的入口在设置页里，但**这两页本身**读的是
    //    `data.trashRetentionDays`。进去看一眼它算不算得出「还剩几天」。
    await tester.tap(find.byKey(AppShell.settingsKey));
    await tester.pumpAndSettle();
    await tapVisible(tester, SettingsPage.trashEntryKey);
    expect(tester.takeException(), isNull, reason: '回收站在零配置下崩了');

    // ⑤ **一行配置都没写。**
    //
    // 上面全程没碰过任何开关，所以库里不该有配置行。
    // 有的话说明某处在启动时把默认值刷进了库 —— 那不是「零配置可用」，
    // 是「启动时自动配置一遍」，两者在出问题时表现完全不同。
    final settingRows = await harness.db.select(harness.db.settings).get();
    expect(settingRows, isEmpty, reason: '什么都没设，库里却有配置行 —— 默认值被刷进库了');
  });

  testAppWidgets('FR-CFG-01 对照组：真的改了配置，库里才有行', (tester) async {
    // 上一条那句「一行都没有」要有意义，得先证明这张表**写得进去** ——
    // 否则一个「配置压根不落库」的实现也能让它绿。
    final harness = await _pumpApp(tester);
    expect(await harness.db.select(harness.db.settings).get(), isEmpty);

    await tester.tap(find.byKey(AppShell.settingsKey));
    await tester.pumpAndSettle();
    await tapVisible(tester, SettingsPage.optionKey('theme.mode', 'dark'));
    await tester.pumpAndSettle();

    expect(
      await harness.db.select(harness.db.settings).get(),
      isNotEmpty,
      reason: '改了配置却没落库',
    );
  });
}

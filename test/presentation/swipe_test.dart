/// 列表的滑动手势（view-specs §2.4）。
///
/// 右滑完成、左滑推迟一天，两边都可在配置里改。
///
/// ## 为什么每条都要验「能不能反悔」
///
/// 滑动是**最容易误触**的手势 —— 列表本来就要上下滚，横向多走一点就
/// 触发了。而「推迟」把这一行从今天挪走，用户下一眼就找不到它。
/// 所以撤销不是锦上添花，是这个手势能不能上线的前提。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/features/settings/application/registry.dart';
import 'package:planning_assistant/features/settings/application/settings_providers.dart';
import 'package:planning_assistant/features/settings/domain/setting_spec.dart';
import 'package:planning_assistant/features/settings/presentation/settings_page.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';
import 'package:planning_assistant/features/views/task_list/presentation/task_list_page.dart';

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

/// 把某个方向的滑动动作改掉。走**真的写入口**（与设置页同一条路），
/// 不是塞一份假配置 —— 那样验的就不是「配置改了真的生效」。
Future<void> _setSwipe(
  WidgetTester tester,
  SettingSpec<SwipeAction> spec,
  SwipeAction action,
) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(PlanningAssistantApp)),
  );
  await container.read(settingsWriterProvider).set(spec, action);
  await tester.pumpAndSettle();
}

Future<void> _create(
  WidgetTester tester,
  String title, {
  bool recurring = false,
  bool withDate = true,
}) async {
  await tester.tap(find.byKey(AppShell.fabKey));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), title);
  await tester.pump();
  if (recurring) {
    await tapVisible(tester, TaskEditorPage.recurrenceSwitchKey);
  } else if (withDate) {
    // 关掉全天会补上今天 —— 这是给它一个日期最省事的路径。
    await tapVisible(tester, TaskEditorPage.allDaySwitchKey);
  }
  await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
  await tester.pumpAndSettle();
}

/// 横向拖一张卡片。[dx] 为正是右滑。
Future<void> _swipe(WidgetTester tester, double dx) async {
  await tester.drag(find.byType(TaskCard).first, Offset(dx, 0));
  await tester.pumpAndSettle();
}

bool _hasGroup(WidgetTester tester, String key) =>
    find.byKey(TaskListPage.groupHeaderKey(key)).evaluate().isNotEmpty;

void main() {
  group('右滑完成（默认）', () {
    testAppWidgets('滑完落库，且给撤销', (tester) async {
      final harness = await _pumpApp(tester);
      await _create(tester, '买菜');

      await _swipe(tester, 400);

      expect(
        (await harness.db.select(harness.db.tasks).get()).single.status,
        'done',
      );
      // **限定在 SnackBar 里找**：筛选条上也有一个「已完成」chip，
      // 直接 find.text 会匹配到两个。
      expect(
        find.descendant(of: find.byType(SnackBar), matching: find.text('已完成')),
        findsOneWidget,
        reason: '滑完要有反馈',
      );
      expect(find.text('撤销'), findsOneWidget);
    });

    testAppWidgets('点撤销能撤回来', (tester) async {
      final harness = await _pumpApp(tester);
      await _create(tester, '买菜');

      await _swipe(tester, 400);
      await tester.tap(find.text('撤销'));
      await tester.pumpAndSettle();

      expect(
        (await harness.db.select(harness.db.tasks).get()).single.status,
        'pending',
      );
    });
  });

  group('滑动删除（回收站做出来之后才敢放进手势里）', () {
    // 这个动作一度**不在可选项里**：滑一下就把整条重复任务删了，
    // 而当时唯一的退路是一条 Snackbar —— 划走了就找不回来。
    // 回收站做出来之后理由消失了：软删除，随时能恢复。

    testAppWidgets('滑一下进回收站，库里是墓碑不是真删', (tester) async {
      final harness = await _pumpApp(tester);
      await _create(tester, '买菜');
      await _setSwipe(tester, swipeLeft, SwipeAction.delete);

      await _swipe(tester, -400);

      expect(find.text('已移到回收站'), findsOneWidget);
      final rows = await harness.db.select(harness.db.tasks).get();
      expect(rows, hasLength(1), reason: '物理删了 —— 回收站就无从谈起');
      expect(rows.single.deletedAt, isNotNull);
    });

    testAppWidgets('撤销把它捞回来 —— 这条退路是这个手势能存在的前提', (tester) async {
      final harness = await _pumpApp(tester);
      await _create(tester, '买菜');
      await _setSwipe(tester, swipeLeft, SwipeAction.delete);

      await _swipe(tester, -400);
      await tester.tap(find.text('撤销'));
      await tester.pumpAndSettle();

      expect(
        (await harness.db.select(harness.db.tasks).get()).single.deletedAt,
        isNull,
      );
      expect(find.text('买菜'), findsOneWidget);
    });

    testAppWidgets('对照组：默认不是删除 —— 误开这个手势代价太大', (tester) async {
      final harness = await _pumpApp(tester);
      await _create(tester, '买菜');

      await _swipe(tester, -400);

      expect(
        (await harness.db.select(harness.db.tasks).get()).single.deletedAt,
        isNull,
        reason: '默认左滑变成删除了',
      );
    });
  });

  group('左滑推迟一天（默认）', () {
    testAppWidgets('普通任务：改的是它自己的日期', (tester) async {
      final harness = await _pumpApp(tester);
      await _create(tester, '买菜');
      final before = (await harness.db.select(harness.db.tasks).get()).single;

      await _swipe(tester, -400);

      final after = (await harness.db.select(harness.db.tasks).get()).single;
      expect(after.planDate, isNot(before.planDate));
      expect(find.text('已推迟到明天'), findsOneWidget);
    });

    testAppWidgets('撤销把它挪回原来那天', (tester) async {
      final harness = await _pumpApp(tester);
      await _create(tester, '买菜');
      final before = (await harness.db.select(harness.db.tasks).get()).single;

      await _swipe(tester, -400);
      await tester.tap(find.text('撤销'));
      await tester.pumpAndSettle();

      final after = (await harness.db.select(harness.db.tasks).get()).single;
      expect(
        after.planDate,
        before.planDate,
        reason: '撤销要回到**原来那天**，不是「今天减一天」',
      );
    });

    testAppWidgets('重复任务：只挪这一次，落的是例外', (tester) async {
      // 走错的后果不是「没反应」：改整条的话，推迟一次等于把往后
      // 每一次都挪了。
      final harness = await _pumpApp(tester);
      await _create(tester, '晨会', recurring: true);
      final before = (await harness.db.select(harness.db.tasks).get()).single;

      await _swipe(tester, -400);

      final after = (await harness.db.select(harness.db.tasks).get()).single;
      expect(
        after.planDate,
        before.planDate,
        reason: '规则的起点不该被动 —— 那会把往后每一次都挪走',
      );
      final overrides = await harness.db
          .select(harness.db.occurrenceOverrides)
          .get();
      expect(overrides, hasLength(1));
      expect(overrides.single.planDateOverride, isNotNull);
    });

    testAppWidgets('推迟之后那一行从「今天」挪到「明天」', (tester) async {
      await _pumpApp(tester);
      await _create(tester, '买菜');
      expect(_hasGroup(tester, 'today'), isTrue);

      await _swipe(tester, -400);

      expect(_hasGroup(tester, 'today'), isFalse);
      expect(_hasGroup(tester, 'tomorrow'), isTrue);
    });

    testAppWidgets('没有日期的任务：说一声，不是毫无反应', (tester) async {
      // 滑完什么都不发生，与「手势坏了」在用户看来一模一样。
      final harness = await _pumpApp(tester);
      await _create(tester, '想想去哪玩', withDate: false);

      await _swipe(tester, -400);

      expect(find.textContaining('推迟不了'), findsOneWidget);
      expect(
        (await harness.db.select(harness.db.tasks).get()).single.planDate,
        isNull,
      );
    });
  });

  group('两边都可配（settings-spec §2.4）', () {
    testAppWidgets('把右滑改成推迟，右滑就推迟', (tester) async {
      final harness = await _pumpApp(tester);
      await _create(tester, '买菜');
      final before = (await harness.db.select(harness.db.tasks).get()).single;

      await tester.tap(find.byKey(AppShell.settingsKey));
      await tester.pumpAndSettle();
      await tapVisible(
        tester,
        SettingsPage.optionKey('behavior.swipeRight', 'postpone'),
      );
      await tester.tap(find.byType(BackButton).first);
      await tester.pumpAndSettle();

      await _swipe(tester, 400);

      final after = (await harness.db.select(harness.db.tasks).get()).single;
      expect(after.status, 'pending', reason: '改成推迟之后右滑不该再完成');
      expect(after.planDate, isNot(before.planDate));
    });

    testAppWidgets('两边都设成「不做事」时，滑动不触发任何东西', (tester) async {
      final harness = await _pumpApp(tester);
      await _create(tester, '买菜');
      final before = (await harness.db.select(harness.db.tasks).get()).single;

      await tester.tap(find.byKey(AppShell.settingsKey));
      await tester.pumpAndSettle();
      for (final key in ['behavior.swipeRight', 'behavior.swipeLeft']) {
        await tapVisible(tester, SettingsPage.optionKey(key, 'none'));
      }
      await tester.tap(find.byType(BackButton).first);
      await tester.pumpAndSettle();

      await _swipe(tester, 400);
      await _swipe(tester, -400);

      final after = (await harness.db.select(harness.db.tasks).get()).single;
      expect(after.status, before.status);
      expect(after.planDate, before.planDate);

      // ↓ 对照组（测试策略 §7.1.1）：保护的是**实现选择**。
      //
      // 两边都不做事时**根本不包 Dismissible**。包着的话手势照样被吃掉：
      // 横向滑动会让卡片动一下再弹回来，看着像坏了 —— 而上面那两条
      // 断言（库里没变）在包着的时候也照样绿。
      expect(find.byType(Dismissible), findsNothing);
    });
  });
}

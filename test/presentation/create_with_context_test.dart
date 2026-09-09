/// 快速新增带上下文（FR-VIEW-07）。
///
/// 验收原话是「在时间轴 14:00 处长按新增，新任务默认时间为 14:00」。
///
/// ## 这条链路有四段，缺一段就白做
///
/// 视图喊「在这儿新建」→ 组合根拼成路由 → 路由把查询参数还原成初值 →
/// 表单拿它当默认值 → 保存时真的落库。
/// `timeline_page_test.dart` 盯的是第一段（长按算出的是哪一刻），
/// 这里盯的是**后面三段**：走真路由、真表单、真库，
/// 最后看落库那一行的 `plan_date` / `start_minute`。
///
/// 中间任何一段断掉，界面上都看不出异常 —— 表单照样打开、
/// 照样能保存，只是日期又变回了空。M2 里 `categoryId` 就是这么丢的：
/// draft 对、界面对，命令里没带上。
@TestOn('vm')
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';
import 'package:planning_assistant/features/views/shared/application/view_kind.dart';
import 'package:planning_assistant/features/views/shared/application/view_shared_state.dart';

import '../support/app_harness.dart';

/// 装好应用，可从任意路由起步。
Future<Harness> _pump(WidgetTester tester, {String? at}) async {
  await setScreenSize(tester, const Size(390, 844));
  final harness = appHarness();
  await tester.pumpWidget(
    ProviderScope(
      overrides: harness.overrides,
      child: PlanningAssistantApp(router: buildAppRouter(initialLocation: at)),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

Future<void> _saveAs(WidgetTester tester, String title) async {
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), title);
  await tester.pump();
  await tapVisible(tester, TaskEditorPage.saveButtonKey);
}

void main() {
  group('路由参数 → 表单初值 → 落库', () {
    testAppWidgets('带日期与时刻：建出来就是那一天那一刻', (tester) async {
      final harness = await _pump(
        tester,
        at: '/task/new?date=2026-09-20&minute=840',
      );
      await _saveAs(tester, '下午的事');

      final row = (await harness.db.select(harness.db.tasks).get()).single;
      expect(row.planDate, '2026-09-20');
      expect(row.startMinute, 14 * 60, reason: '14:00 长按建出来的任务没落在 14:00');
      expect(row.isAllDay, isFalse, reason: '给了时刻还当全天，那个时刻等于没给');
    });

    testAppWidgets('只带日期：是那一天的**全天**任务，不是 00:00', (tester) async {
      // 从日历翻到某天点加号，用户表达的是「这一天」。
      // 悄悄补一个 00:00 的话，它会跑到时间轴最顶上去。
      final harness = await _pump(tester, at: '/task/new?date=2026-09-20');
      await _saveAs(tester, '那天的事');

      final row = (await harness.db.select(harness.db.tasks).get()).single;
      expect(row.planDate, '2026-09-20');
      expect(row.isAllDay, isTrue);
      expect(row.startMinute, isNull);
    });

    testAppWidgets('对照组：什么都不带还是一张白纸', (tester) async {
      // 少了这条，一个「永远塞今天」的实现能让上面两条全绿 ——
      // 而设置页那类入口不在任何一天的语境里，硬塞一个「今天」
      // 会让它看起来像用户自己选的。
      final harness = await _pump(tester, at: '/task/new');
      await _saveAs(tester, '随时做');

      final row = (await harness.db.select(harness.db.tasks).get()).single;
      expect(row.planDate, isNull);
    });

    testAppWidgets('参数读不懂就当没给，不是崩在新建页上', (tester) async {
      // 手敲错的链接、将来小组件传错的参数 —— 后果只该是
      // 「初值没带上」，不该是打不开新建页。
      final harness = await _pump(
        tester,
        at: '/task/new?date=去年某天&minute=99999',
      );
      expect(find.byKey(TaskEditorPage.titleFieldKey), findsOneWidget);
      await _saveAs(tester, '照样建得出来');

      final row = (await harness.db.select(harness.db.tasks).get()).single;
      expect(row.planDate, isNull);
      expect(row.startMinute, isNull);
    });
  });

  group('加号带不带日期，看视图对不对着某一天', () {
    Future<void> focus(WidgetTester tester, PlanDate date) async {
      ProviderScope.containerOf(tester.element(find.byType(AppShell)))
          .read(viewSharedStateProvider.notifier)
          .focusDate(date);
      await tester.pumpAndSettle();
    }

    testAppWidgets('日历翻到 9/20 再点加号，建出来的落在 9/20', (tester) async {
      // 这是这条需求最常撞见的形态：用户明明正看着 9/20，
      // 建出来的任务却落在「随时」区，得再手动选一次日期。
      final harness = await _pump(tester);
      await tapVisible(tester, AppShell.viewTabKey(ViewKind.calendar));
      await focus(tester, const PlanDate(2026, 9, 20));

      await tester.tap(find.byKey(AppShell.fabKey));
      await tester.pumpAndSettle();
      await _saveAs(tester, '那天的事');

      final row = (await harness.db.select(harness.db.tasks).get()).single;
      expect(row.planDate, '2026-09-20');
    });

    testAppWidgets('**列表里点加号照旧建得出「随时」任务**', (tester) async {
      // 列表横跨所有日期，用户在那儿点加号没有指向任何一天。
      // 一律盖上「今天」的话，「随时」这一档就再也建不出来了 ——
      // 而它是 FR-VIEW-01 点了名的一档。
      //
      // 这条不是补充，是**这次改动差点造成的回归**：
      // 加号先前无条件带上了聚焦日，两条既有测试
      // （swipe_test「没有日期的任务」、settings_page_test「无日期分组」）
      // 一起变红，指的就是这件事。
      final harness = await _pump(tester);
      await focus(tester, const PlanDate(2026, 9, 20));

      await tester.tap(find.byKey(AppShell.fabKey));
      await tester.pumpAndSettle();
      await _saveAs(tester, '想想去哪玩');

      final row = (await harness.db.select(harness.db.tasks).get()).single;
      expect(row.planDate, isNull, reason: '列表里的加号把「随时」任务堵死了');
    });

    test('四个视图里只有列表不对着某一天', () {
      // 判据写在枚举上，这里把那份声明本身钉住 ——
      // 加视图的人会看见这条。
      expect(
        {for (final k in ViewKind.values) k: k.anchorsToDay},
        {
          ViewKind.list: false,
          ViewKind.timeline: true,
          ViewKind.calendar: true,
          ViewKind.gantt: true,
        },
      );
    });
  });

  group('路由拼装', () {
    test('两个分量各自可缺', () {
      expect(AppRoutes.newTaskAt(), '/task/new');
      expect(
        AppRoutes.newTaskAt(date: const PlanDate(2026, 9, 20)),
        '/task/new?date=2026-09-20',
      );
      expect(
        AppRoutes.newTaskAt(minute: MinuteOfDay(840)),
        '/task/new?minute=840',
      );
      expect(
        AppRoutes.newTaskAt(
          date: const PlanDate(2026, 9, 20),
          minute: MinuteOfDay(840),
        ),
        '/task/new?date=2026-09-20&minute=840',
      );
    });
  });
}

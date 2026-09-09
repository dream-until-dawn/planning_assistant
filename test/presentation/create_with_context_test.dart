/// 快速新增带上下文（FR-VIEW-07）。
///
/// 验收原话是「在某个时段上长按新增，新任务默认时间为那一刻」。
///
/// 原话点的是时间轴，那时它是**单日刻度尺**，画布上每一个 y 都对应
/// 一个时刻。改成跨天议程之后它没有那样的画布了 ——
/// 这条交互留在**甘特**上（`GanttView.canvasKey`，纵轴仍是时间），
/// 日历那边的对应形态是点某一天。
///
/// ## 这条链路有四段，缺一段就白做
///
/// 视图喊「在这儿新建」→ 组合根拼成路由 → 路由把查询参数还原成初值 →
/// 表单拿它当默认值 → 保存时真的落库。
/// `gantt_view_test.dart` 盯的是第一段（长按算出的是哪一刻），
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
import 'package:planning_assistant/features/task/application/task_shape.dart';
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

    testAppWidgets('日历翻到 9/20 再点加号选「单事项」，建出来的落在 9/20', (tester) async {
      // 这是这条需求最常撞见的形态：用户明明正看着 9/20，
      // 建出来的任务却落在「无日期」，得再手动选一次日期。
      //
      // **要选一个排时间的形态**：临时事项按定义不排时间，
      // 它会把加号带来的日期丢掉 —— 那是对的，但验不了这条需求。
      final harness = await _pump(tester);
      await tapVisible(tester, AppShell.viewTabKey(ViewKind.calendar));
      await focus(tester, const PlanDate(2026, 9, 20));

      await tapCreate(tester, TaskShape.single);
      await _saveAs(tester, '那天的事');

      final row = (await harness.db.select(harness.db.tasks).get()).single;
      expect(row.planDate, '2026-09-20');
    });

    testAppWidgets('**列表里选「单事项」落在今天，不是聚焦日**', (tester) async {
      // 列表横跨所有日期，用户在那儿点加号没有指向任何一天
      // （`ViewKind.anchorsToDay` 为 false）。所以加号不把聚焦日带过去 ——
      // 带过去的话，别处（日历）翻到 9/20 会让列表里建的任务
      // 莫名其妙落在 9/20。
      //
      // **注意验的是「不是 9/20」，不是「没有日期」**：
      // 单事项要求起止，拿不到语境时它落在今天。
      // 「没有日期」现在是临时事项那一档的事，见下一条。
      final harness = await _pump(tester);
      await focus(tester, const PlanDate(2026, 9, 20));

      await tapCreate(tester, TaskShape.single);
      await _saveAs(tester, '今天的事');

      final row = (await harness.db.select(harness.db.tasks).get()).single;
      expect(row.planDate, isNot('2026-09-20'), reason: '列表里的加号把聚焦日带过去了');
      expect(row.planDate, isNotNull, reason: '单事项要求有日期');
    });

    testAppWidgets('**「随时」任务由临时事项这一档建出来**', (tester) async {
      // 上一版里它是靠「列表的加号不带日期」间接达成的 ——
      // 加号先前无条件带上聚焦日时，两条既有测试
      // （swipe_test「没有日期的任务」、settings_page_test「无日期分组」）
      // 一起变红，指的就是这件事。
      //
      // 现在它有了自己的入口，而且**在哪个视图里都建得出来**：
      // 这一条在日历里建（那是最「对着某一天」的视图），
      // 建出来的照样没有日期。
      final harness = await _pump(tester);
      await tapVisible(tester, AppShell.viewTabKey(ViewKind.calendar));
      await focus(tester, const PlanDate(2026, 9, 20));

      await tapCreate(tester, TaskShape.scratch);
      await _saveAs(tester, '想想去哪玩');

      final row = (await harness.db.select(harness.db.tasks).get()).single;
      expect(row.planDate, isNull, reason: '临时事项被塞了一个日期');
    });

    testAppWidgets('**时间轴里点加号也建得出「随时」任务**', (tester) async {
      // 与列表同一条理由：议程横跨多天，聚焦日只决定它滚到哪，
      // 不表示「用户说的是这一天」。带上的话，从日历翻到 9/20
      // 再切过来点加号，建出来的会莫名其妙落在 9/20。
      final harness = await _pump(tester);
      await tapVisible(tester, AppShell.viewTabKey(ViewKind.timeline));
      await focus(tester, const PlanDate(2026, 9, 20));

      await tapCreate(tester);
      await _saveAs(tester, '想想去哪玩');

      final row = (await harness.db.select(harness.db.tasks).get()).single;
      expect(row.planDate, isNull, reason: '时间轴里的加号把「随时」任务堵死了');
    });

    test('横跨多天的两个视图不对着某一天', () {
      // 判据写在枚举上，这里把那份声明本身钉住 ——
      // 加视图的人会看见这条。
      //
      // 时间轴曾经是 true：那时它是**单日**刻度尺。改成跨天议程之后
      // 它与列表同类了 —— 在那儿点加号没有指向任何一天，
      // 一律盖上「今天」会把「随时做」那一类任务堵死。
      expect(
        {for (final k in ViewKind.values) k: k.anchorsToDay},
        {
          ViewKind.list: false,
          ViewKind.timeline: false,
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

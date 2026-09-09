/// 日历视图（view-specs §3、FR-VIEW-03）。
///
/// 排布的对错在 `month_grid_test` 与 `day_bands_test` 里按整数验过了。
/// 这里验的是**画出来的东西与那些整数对得上**：横条的左右边界落在哪一格、
/// 一条跨天的横条是不是**一个** widget（而不是三个拼的）、点一格会不会
/// 换掉下半屏。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/design/theme/app_theme.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/features/views/calendar/application/calendar_split.dart';
import 'package:planning_assistant/features/views/calendar/presentation/calendar_page.dart';
import 'package:planning_assistant/features/views/shared/application/view_shared_state.dart';

import '../support/app_harness.dart';

/// 2026-09-08 是周二；9 月那一屏（周一起）从 8-31 起。
const _today = PlanDate(2026, 9, 8);

/// 这一屏第一行的七天：8-31 .. 9-6。第二行 9-7 .. 9-13。
PlanDate _d(int monthDay) => PlanDate(2026, 9, monthDay);

Task _task(
  String id, {
  PlanDate? date = _today,
  PlanDate? endDate,
  int? start,
  bool isAllDay = false,
}) => Task(
  id: id,
  title: id,
  kind: TaskKind.single,
  timeZoneId: 'Asia/Shanghai',
  planDate: date,
  startMinute: start == null ? null : MinuteOfDay(start),
  endDate: endDate,
  isAllDay: isAllDay,
);

Future<void> _pump(
  WidgetTester tester, {
  List<Task> tasks = const [],
  Map<String, Object?> settings = const {},
  TimeGranularity granularity = TimeGranularity.month,
}) async {
  await setScreenSize(tester, const Size(390, 844));
  await tester.pumpWidget(
    ProviderScope(
      overrides: viewPipelineOverrides(
        tasks: tasks,
        settings: settings,
        today: _today,
      ),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: CalendarPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();

  ProviderScope.containerOf(tester.element(find.byType(CalendarPage)))
      .read(viewSharedStateProvider.notifier)
      .setGranularity(granularity);
  await tester.pumpAndSettle();
}

/// 不碰 `granularity`，走它自己的默认 —— 验「默认是什么」时不能先设一遍。
Future<void> _pumpDefault(WidgetTester tester) async {
  await setScreenSize(tester, const Size(390, 844));
  await tester.pumpWidget(
    ProviderScope(
      overrides: viewPipelineOverrides(today: _today),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: CalendarPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Rect _cell(WidgetTester tester, PlanDate date) =>
    tester.getRect(find.byKey(CalendarPage.dayKey(date)));

void main() {
  group('FR-VIEW-03 格子画对了', () {
    testAppWidgets('六行七列，第一格是上个月的 8-31', (tester) async {
      await _pump(tester);
      expect(
        find.byKey(CalendarPage.dayKey(const PlanDate(2026, 8, 31))),
        findsOneWidget,
      );
      expect(find.byKey(CalendarPage.dayKey(_d(30))), findsOneWidget);
      // 六行 × 七列 = 四十二格，一格不多一格不少。
      expect(
        find.byWidgetPredicate(
          (w) => w.key.toString().startsWith("[<'calendar-day-"),
        ),
        findsNWidgets(42),
      );
    });

    testAppWidgets('表头顺序跟着配置走', (tester) async {
      await _pump(tester, settings: {'view.firstDayOfWeek': 'sunday'});
      final header = find.descendant(
        of: find.byKey(CalendarPage.headerKey),
        matching: find.byType(Text),
      );
      expect(tester.widgetList<Text>(header).map((t) => t.data), [
        '日',
        '一',
        '二',
        '三',
        '四',
        '五',
        '六',
      ]);
      // 表头改了，格子也得跟着改 —— 两处各算一遍的话，
      // 表头写着「日」而那一列其实是周一。
      expect(
        find.byKey(CalendarPage.dayKey(const PlanDate(2026, 8, 30))),
        findsOneWidget,
      );
    });
  });

  group('横条：一条跨天任务是**一个** widget', () {
    testAppWidgets('左右边界正好落在起止那两格上', (tester) async {
      // 9-9 到 9-11，都在第二行。按格子拼的实现会得到三个 widget，
      // 而且格子边界上可能有缝 —— 缝在截图上看不出来，这条能。
      await _pump(
        tester,
        tasks: [_task('出差', date: _d(9), endDate: _d(11), isAllDay: true)],
      );

      final bands = find.byKey(CalendarPage.bandKey('出差', 1));
      expect(bands, findsOneWidget, reason: '一行里只该有一条，不是三段');

      final band = tester.getRect(bands);
      expect(band.left, closeTo(_cell(tester, _d(9)).left, 1.5));
      expect(band.right, closeTo(_cell(tester, _d(11)).right, 1.5));
    });

    testAppWidgets('跨行的任务：两行各一条，且各自贴到行的边', (tester) async {
      // 9-11（周五）到 9-15（下周二）。
      await _pump(
        tester,
        tasks: [_task('长假', date: _d(11), endDate: _d(15), isAllDay: true)],
      );

      final first = tester.getRect(find.byKey(CalendarPage.bandKey('长假', 1)));
      final second = tester.getRect(find.byKey(CalendarPage.bandKey('长假', 2)));

      expect(first.left, closeTo(_cell(tester, _d(11)).left, 1.5));
      expect(first.right, closeTo(_cell(tester, _d(13)).right, 1.5));
      expect(second.left, closeTo(_cell(tester, _d(14)).left, 1.5));
      expect(second.right, closeTo(_cell(tester, _d(15)).right, 1.5));
    });

    testAppWidgets('对照组：只占一天的定时任务不画横条，画色点', (tester) async {
      await _pump(tester, tasks: [_task('晨会', start: 9 * 60)]);
      expect(find.byKey(CalendarPage.bandKey('晨会', 1)), findsNothing);
      expect(find.byKey(CalendarPage.dayKey(_today)), findsOneWidget);
    });

    testAppWidgets('两条重叠的横条分层，不叠在一起', (tester) async {
      await _pump(
        tester,
        tasks: [
          _task('甲', date: _d(7), endDate: _d(10), isAllDay: true),
          _task('乙', date: _d(9), endDate: _d(12), isAllDay: true),
        ],
      );
      final a = tester.getRect(find.byKey(CalendarPage.bandKey('甲', 1)));
      final b = tester.getRect(find.byKey(CalendarPage.bandKey('乙', 1)));
      expect(a.top, isNot(closeTo(b.top, 1)), reason: '两条压在同一层上了');
    });
  });

  group('色点与「+N」', () {
    testAppWidgets('四件事：三个点 + 「+1」', (tester) async {
      await _pump(
        tester,
        tasks: [for (var i = 0; i < 4; i++) _task('事$i', start: (8 + i) * 60)],
      );
      expect(find.byKey(CalendarPage.overflowKey(_today)), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
    });

    testAppWidgets('对照组：正好三件事时不出现「+N」', (tester) async {
      await _pump(
        tester,
        tasks: [for (var i = 0; i < 3; i++) _task('事$i', start: (8 + i) * 60)],
      );
      expect(find.byKey(CalendarPage.overflowKey(_today)), findsNothing);
    });
  });

  group('点一格换下半屏', () {
    testAppWidgets('点别的日子，下面的列表跟着换', (tester) async {
      await _pump(
        tester,
        tasks: [
          _task('今天的', start: 9 * 60),
          _task('后天的', date: _d(10), start: 9 * 60),
        ],
      );
      expect(find.text('今天的'), findsOneWidget);
      expect(find.text('后天的'), findsNothing);

      await tester.tap(find.byKey(CalendarPage.dayKey(_d(10))));
      await tester.pumpAndSettle();

      expect(find.text('后天的'), findsOneWidget);
      expect(find.text('今天的'), findsNothing);
    });

    testAppWidgets('那一天空着时给一屏空态，不是空白', (tester) async {
      await _pump(tester, tasks: [_task('今天的', start: 9 * 60)]);
      await tester.tap(find.byKey(CalendarPage.dayKey(_d(20))));
      await tester.pumpAndSettle();
      expect(find.byKey(CalendarPage.selectedEmptyKey), findsOneWidget);
    });

    testAppWidgets('跨天任务在它盖到的每一天的列表里都出现', (tester) async {
      await _pump(
        tester,
        tasks: [_task('出差', date: _d(9), endDate: _d(11), isAllDay: true)],
      );
      for (final day in [9, 10, 11]) {
        await tester.tap(find.byKey(CalendarPage.dayKey(_d(day))));
        await tester.pumpAndSettle();
        expect(find.text('出差'), findsWidgets, reason: '9-$day 那天没有它');
      }
      await tester.tap(find.byKey(CalendarPage.dayKey(_d(12))));
      await tester.pumpAndSettle();
      expect(find.byKey(CalendarPage.selectedEmptyKey), findsOneWidget);
    });
  });

  group('滑动切月', () {
    testAppWidgets('往左划到十月，往右划回来', (tester) async {
      await _pump(tester);
      await tester.fling(
        find.byKey(CalendarPage.gridKey),
        const Offset(-300, 0),
        800,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(CalendarPage.dayKey(const PlanDate(2026, 10, 8))),
        findsOneWidget,
      );

      await tester.fling(
        find.byKey(CalendarPage.gridKey),
        const Offset(300, 0),
        800,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(CalendarPage.dayKey(_today)), findsOneWidget);
    });

    testAppWidgets('1-31 往后翻，聚焦日夹到 2-28 而不是造出 2-31', (tester) async {
      // ## 这条第一版验错了对象
      //
      // 原来断言的是「翻完之后 2-28 那一格在」。**去掉夹取照样绿** ——
      // 格子是按 `focused.year/month` 排的，聚焦日是 2-31 还是 2-28
      // 都排出同一个二月。变异演练里它活下来了。
      //
      // 而 `PlanDate` 的 const 构造器**不校验**（只有 `parse` 校验），
      // 所以 2-31 会安静地存在，然后在「选中哪一格」「那天有什么事」
      // 这些地方给出没人预料的答案。要验的是**聚焦日本身**。
      await _pump(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CalendarPage)),
      );
      container
          .read(viewSharedStateProvider.notifier)
          .focusDate(const PlanDate(2026, 1, 31));
      await tester.pumpAndSettle();

      await tester.fling(
        find.byKey(CalendarPage.gridKey),
        const Offset(-300, 0),
        800,
      );
      await tester.pumpAndSettle();

      expect(
        container.read(viewSharedStateProvider).focusedDate,
        const PlanDate(2026, 2, 28),
      );
      expect(
        find.byKey(CalendarPage.dayKey(const PlanDate(2026, 2, 28))),
        findsOneWidget,
      );
    });

    testAppWidgets('对照组：日号在下个月存在时不该被动过', (tester) async {
      // 少了这条，一个「一律夹到月末」的实现也能让上面绿 ——
      // 那样每翻一次月，聚焦日都会跳到月末。
      await _pump(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CalendarPage)),
      );
      await tester.fling(
        find.byKey(CalendarPage.gridKey),
        const Offset(-300, 0),
        800,
      );
      await tester.pumpAndSettle();
      expect(
        container.read(viewSharedStateProvider).focusedDate,
        const PlanDate(2026, 10, 8),
      );
    });
  });

  group('月/周切换：这个旋钮界面上够得着', () {
    // `granularity` 是共享状态里的字段，日历读它、甘特也要读它，
    // 但**一度没有任何地方写它** —— 用户永远停在默认那一档，
    // 月视图根本到不了。testing-strategy §1.6 那一族的又一次。

    testAppWidgets('默认是月视图（§3.1 那张表第一行）', (tester) async {
      // 不设 granularity，走默认的 `day` 档。
      await _pumpDefault(tester);
      expect(
        find.byWidgetPredicate(
          (w) => w.key.toString().startsWith("[<'calendar-day-"),
        ),
        findsNWidgets(42),
      );
    });

    testAppWidgets('点「周」变一行，点「月」变回六行', (tester) async {
      await _pumpDefault(tester);

      await tester.tap(find.byKey(CalendarPage.modeKey('week')));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w.key.toString().startsWith("[<'calendar-day-"),
        ),
        findsNWidgets(7),
      );

      await tester.tap(find.byKey(CalendarPage.modeKey('month')));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w.key.toString().startsWith("[<'calendar-day-"),
        ),
        findsNWidgets(42),
      );
    });

    testAppWidgets('切换写的是共享状态，不是日历自己存一份', (tester) async {
      // 自己存一份的话，切到甘特再回来就对不上了（FR-VIEW-05/06）。
      await _pumpDefault(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CalendarPage)),
      );

      await tester.tap(find.byKey(CalendarPage.modeKey('week')));
      await tester.pumpAndSettle();
      expect(
        container.read(viewSharedStateProvider).granularity,
        TimeGranularity.week,
      );
    });
  });

  group('周视图', () {
    testAppWidgets('一格的高度与月视图一样，不是被拉成六倍', (tester) async {
      // 比例定的是**行高**，不是格子区的高。直接把整块给一行的话，
      // 一行日期占掉大半屏，下面的列表挤没了；月↔周来回切时
      // 格子还会忽大忽小。模拟器上一眼就看见了。
      await _pump(tester, granularity: TimeGranularity.month);
      final monthRow = tester
          .getRect(find.byKey(CalendarPage.dayKey(_today)))
          .height;

      await _pump(tester, granularity: TimeGranularity.week);
      final weekRow = tester
          .getRect(find.byKey(CalendarPage.dayKey(_today)))
          .height;

      expect(weekRow, closeTo(monthRow, 1));
    });

    testAppWidgets('只有一行七格', (tester) async {
      await _pump(tester, granularity: TimeGranularity.week);
      expect(
        find.byWidgetPredicate(
          (w) => w.key.toString().startsWith("[<'calendar-day-"),
        ),
        findsNWidgets(7),
      );
      expect(find.byKey(CalendarPage.dayKey(_d(7))), findsOneWidget);
      expect(find.byKey(CalendarPage.dayKey(_d(13))), findsOneWidget);
    });
  });

  group('上下比例', () {
    // 这一组**用真库**（`appHarness`）而不是喂固定配置：
    // 「拖完记住了」这件事的一半在写入侧，喂固定配置的话写进去的东西
    // 没人读得到，测出来的只是「界面当场变了」，而那不是「记住」。

    Future<void> pumpReal(WidgetTester tester) async {
      await setScreenSize(tester, const Size(390, 844));
      final harness = appHarness(now: DateTime.utc(2026, 9, 8, 1));
      await tester.pumpWidget(
        ProviderScope(
          overrides: harness.overrides,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: CalendarPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // **月视图**：比例定的是行高，所以只有六行都在时，拖动的位移
      // 才与格子区的高度变化 1:1。周视图里拖一像素只动六分之一。
      ProviderScope.containerOf(tester.element(find.byType(CalendarPage)))
          .read(viewSharedStateProvider.notifier)
          .setGranularity(TimeGranularity.month);
      await tester.pumpAndSettle();
    }

    testAppWidgets('拖把手：格子变矮，而且松手之后不回弹', (tester) async {
      await pumpReal(tester);
      final before = tester.getRect(find.byKey(CalendarPage.gridKey)).height;

      // `touchSlopY: 0` 把手势识别器吃掉的那 20 逻辑像素去掉。
      // 不去掉的话这里得写 `before - 100`，而那个 100 是
      // `kDragSlopDefault` 减出来的 —— 把框架的常量抄进断言，
      // 框架改了这条会红，而红的原因跟被测的算术毫无关系。
      await tester.drag(
        find.byKey(CalendarPage.handleKey),
        const Offset(0, -120),
        touchSlopY: 0,
      );
      await tester.pumpAndSettle();

      final after = tester.getRect(find.byKey(CalendarPage.gridKey)).height;
      expect(after, lessThan(before));
      expect(after, closeTo(before - 120, 2), reason: '松手后弹回去了 —— 落库与交还的顺序反了');
    });

    // ## 下面两条为什么在**手指还没抬起来**的时候断言
    //
    // 夹取有两道：拖动时夹一次（`CalendarSplit.clamp`），从配置读回来时
    // 再夹一次（`calendarSplitRatio.decode`）。两道各自都对，但它们
    // **互相掩盖**：拖完松手之后读到的是配置里那份，已经被读侧夹过了，
    // 于是把拖动侧的夹取去掉，松手后的断言照样绿。
    //
    // 这正是 testing-strategy §3.1 记过的「两处防御互相掩盖」。
    // 要分开验，就得在**只有一道生效**的时刻看 —— 也就是拖动过程中。
    Future<void> dragAndHold(WidgetTester tester, double dy) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(CalendarPage.handleKey)),
      );
      await gesture.moveBy(Offset(0, dy));
      await tester.pump();
      addTearDown(() => gesture.up());
    }

    testAppWidgets('拖动过程中就压不成 0 —— 压没了就再也拖不回来', (tester) async {
      await pumpReal(tester);
      await dragAndHold(tester, -2000);

      expect(
        tester.getRect(find.byKey(CalendarPage.gridKey)).height,
        greaterThan(0),
      );
      // 把手还在，还能往回拖。
      expect(find.byKey(CalendarPage.handleKey), findsOneWidget);
    });

    testAppWidgets('拖动过程中也压不没下半屏', (tester) async {
      await pumpReal(tester);
      await dragAndHold(tester, 2000);

      // 下半屏那块还有高度 —— 空态那一屏还画得出来。
      expect(find.byKey(CalendarPage.selectedEmptyKey), findsOneWidget);
    });

    testAppWidgets('配置里存着越界的值时，读回来也要夹住', (tester) async {
      // 另一道：手改过的配置文件。这条与上面两条**验的是不同的那一道**。
      await setScreenSize(tester, const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: viewPipelineOverrides(
            today: _today,
            settings: const {'view.calendarSplitRatio': 0.99},
          ),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: CalendarPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // **量比例，不是看「下半屏还在不在」。**
      // 0.99 的比例下，下半屏还剩八个像素 —— 空态照样画得出来
      // （它自己会滚），于是「还在」这个断言两种实现都绿。
      // 第一版就是那么写的，变异里活了下来。
      final header = tester.getRect(find.byKey(CalendarPage.headerKey)).height;
      final handle = tester.getRect(find.byKey(CalendarPage.handleKey)).height;
      final grid = tester.getRect(find.byKey(CalendarPage.gridKey)).height;
      expect(
        grid / (844 - header - handle),
        lessThanOrEqualTo(CalendarSplit.max + 0.01),
        reason: '配置里那个 0.99 被照单全收了',
      );
    });
  });

  testAppWidgets('读库失败要显式一屏，不是空日历', (tester) async {
    await setScreenSize(tester, const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: viewPipelineOverrides(
          today: _today,
          tasksStream: Stream<List<Task>>.error(StateError('库炸了')),
        ),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: CalendarPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(CalendarPage.errorKey), findsOneWidget);
    expect(find.byKey(CalendarPage.gridKey), findsNothing);
  });
}

/// 时间轴视图（view-specs §1、FR-VIEW-01）。
///
/// 「一天怎么排」在 `timeline_blocks_test.dart` 里按整数验过了。
/// 这里验的是**它有没有被画出来**：块在不在、位置对不对、
/// 「随时」区收的是谁、当前时刻线只在今天出现、折叠的那几件点得开。
///
/// 位置断言用的是 `tester.getRect`，不是像素比对 —— 前者说得出
/// 「09:00 那一块的顶边应该在 432」，后者只会说「图不一样」。
@TestOn('vm')
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app_providers.dart';
import 'package:planning_assistant/core/time/clock.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/design/components/empty_state.dart';
import 'package:planning_assistant/design/theme/app_theme.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/value_objects/recurrence.dart';
import 'package:planning_assistant/features/views/shared/application/view_shared_state.dart';
import 'package:planning_assistant/features/views/timeline/presentation/timeline_metrics.dart';
import 'package:planning_assistant/features/views/timeline/presentation/timeline_page.dart';

import '../support/app_harness.dart';

const _today = PlanDate(2026, 9, 8);
const _yesterday = PlanDate(2026, 9, 7);

/// 默认刻度是 60 分钟一格，于是一分钟正好 0.8 逻辑像素。
double get _scale => TimelineMetrics.pixelsPerMinute(60);

Task _task(
  String id, {
  PlanDate? date = _today,
  int? start,
  PlanDate? endDate,
  int? end,
  bool isAllDay = false,
  String? rrule,
}) => Task(
  id: id,
  title: id,
  kind: TaskKind.single,
  timeZoneId: 'Asia/Shanghai',
  planDate: date,
  startMinute: start == null ? null : MinuteOfDay(start),
  endDate: endDate,
  endMinute: end == null ? null : MinuteOfDay(end),
  isAllDay: isAllDay,
  recurrence: rrule == null ? null : Recurrence.parse(rrule),
);

/// 装好一屏时间轴。
///
/// 时钟对到 [now]（默认 9/8 09:00 +08），**与 `todayProvider` 同一天** ——
/// 两者对不上的话「当前时刻线该不该出现」验的就不是时间轴的逻辑，
/// 而是夹具自己前后矛盾。
Future<void> _pump(
  WidgetTester tester, {
  List<Task> tasks = const [],
  Stream<List<Task>>? tasksStream,
  PlanDate focus = _today,
  DateTime Function()? now,
  Map<String, Object?> settings = const {},
  Stream<void>? tick,
  List<Override> extra = const [],
  VoidCallback? onCreateTask,
}) async {
  await setScreenSize(tester, const Size(390, 844));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...viewPipelineOverrides(
          tasks: tasks,
          today: _today,
          settings: settings,
          tasksStream: tasksStream,
          tick: tick ?? const Stream<void>.empty(),
        ),
        clockProvider.overrideWithValue(
          _MovingClock(now ?? () => DateTime.utc(2026, 9, 8, 1)),
        ),
        ...extra,
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: TimelinePage(onCreateTask: onCreateTask)),
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (focus != _today) {
    // 建完树**之后**再推 —— 在 build 里改 provider 会被 Riverpod 拦下。
    // 容器交给 `ProviderScope` 管，这样 `testAppWidgets` 拆树时
    // 连同 Riverpod 自己排的定时器一起收干净。
    ProviderScope.containerOf(tester.element(find.byType(TimelinePage)))
        .read(viewSharedStateProvider.notifier)
        .focusDate(focus);
    await tester.pumpAndSettle();
  }
}

/// 某一块在屏幕上的矩形。
Rect _blockRect(WidgetTester tester, String rowId) =>
    tester.getRect(find.byKey(TimelinePage.blockKey(rowId)));

void main() {
  group('块的位置由时刻决定', () {
    testAppWidgets('顶边 = 开始分钟 × 比例', (tester) async {
      await _pump(
        tester,
        tasks: [_task('晨会', start: 9 * 60, endDate: _today, end: 10 * 60)],
      );

      // 画布从 0 点开始，而首次定位把视口滚到了别处 —— 所以比的是
      // **相对于画布顶端**的偏移，不是屏幕坐标。
      final canvasTop = tester.getRect(find.byKey(TimelinePage.tickKey(0))).top;
      final rect = _blockRect(tester, '晨会');
      expect(rect.top - canvasTop, closeTo(9 * 60 * _scale, 0.5));
      expect(rect.height, closeTo(60 * _scale, 0.5));
    });

    testAppWidgets('高度∝时长：两小时的块是一小时的两倍高', (tester) async {
      await _pump(
        tester,
        tasks: [
          _task('短', start: 9 * 60, endDate: _today, end: 10 * 60),
          _task('长', start: 13 * 60, endDate: _today, end: 15 * 60),
        ],
      );
      expect(
        _blockRect(tester, '长').height,
        closeTo(_blockRect(tester, '短').height * 2, 0.5),
      );
    });

    testAppWidgets('没有时长的也点得着 —— 最小块高兜底（§1.2）', (tester) async {
      // 时长是 0，按比例算高度也是 0：不兜底的话它在屏幕上是一条线，
      // 点不着，而「点不着」与「没画出来」在截图上看起来一样。
      await _pump(tester, tasks: [_task('取快递', start: 10 * 60)]);
      expect(_blockRect(tester, '取快递').height, TimelineMetrics.minBlockHeight);
    });

    testAppWidgets('对照组：够长的块不会被拉到最小块高', (tester) async {
      // 少了这条，一个「所有块都 36 高」的实现也能让上面绿。
      await _pump(
        tester,
        tasks: [_task('长会', start: 9 * 60, endDate: _today, end: 12 * 60)],
      );
      expect(
        _blockRect(tester, '长会').height,
        greaterThan(TimelineMetrics.minBlockHeight),
      );
    });
  });

  group('重叠的并排', () {
    testAppWidgets('两个重叠的各占半宽，左右分开', (tester) async {
      await _pump(
        tester,
        tasks: [
          _task('甲', start: 9 * 60, endDate: _today, end: 11 * 60),
          _task('乙', start: 10 * 60, endDate: _today, end: 12 * 60),
        ],
      );
      final a = _blockRect(tester, '甲');
      final b = _blockRect(tester, '乙');
      expect(a.width, closeTo(b.width, 0.5));
      expect(a.left, lessThan(b.left), reason: '早的在左边');
      expect(a.right, lessThanOrEqualTo(b.left), reason: '不该压在一起');
    });

    testAppWidgets('对照组：不重叠的各占满宽', (tester) async {
      await _pump(
        tester,
        tasks: [
          _task('甲', start: 9 * 60, endDate: _today, end: 10 * 60),
          _task('乙', start: 11 * 60, endDate: _today, end: 12 * 60),
        ],
      );
      expect(
        _blockRect(tester, '甲').width,
        closeTo(_blockRect(tester, '乙').width, 0.5),
      );
      expect(_blockRect(tester, '甲').left, _blockRect(tester, '乙').left);
    });

    testAppWidgets('四个重叠：画三个，第四个折成「+1」，而且点得开', (tester) async {
      // 只画一个点不开的「+1」，那一件事在这一天就是**不可达**的 ——
      // 与 M2 里那条「到某天为止」的死路是同一种毛病。
      await _pump(
        tester,
        tasks: [
          for (var i = 0; i < 4; i++)
            _task(
              '并行$i',
              start: 9 * 60 + i * 10,
              endDate: _today,
              end: 12 * 60,
            ),
        ],
      );

      expect(find.byKey(TimelinePage.blockKey('并行3')), findsNothing);
      final pill = find.byKey(TimelinePage.overflowKey(9 * 60));
      expect(pill, findsOneWidget);
      expect(find.text('+1'), findsOneWidget);

      await tester.tap(pill);
      await tester.pumpAndSettle();
      expect(find.text('并行3'), findsOneWidget, reason: '折起来的那件要打得开');
    });

    testAppWidgets('「+N」不压在第三块上', (tester) async {
      await _pump(
        tester,
        tasks: [
          for (var i = 0; i < 4; i++)
            _task(
              '并行$i',
              start: 9 * 60 + i * 10,
              endDate: _today,
              end: 12 * 60,
            ),
        ],
      );
      final third = _blockRect(tester, '并行2');
      final pill = tester.getRect(find.byKey(TimelinePage.overflowKey(9 * 60)));
      expect(third.right, lessThanOrEqualTo(pill.left));
    });
  });

  group('「随时」区', () {
    testAppWidgets('全天任务进「随时」，不占时间轴', (tester) async {
      await _pump(tester, tasks: [_task('纪念日', isAllDay: true)]);
      expect(find.byKey(TimelinePage.anytimeKey), findsOneWidget);
      expect(find.byKey(TimelinePage.blockKey('纪念日')), findsNothing);
      expect(find.text('纪念日'), findsOneWidget);
    });

    testAppWidgets('一个无时刻任务都没有时，整块不出现', (tester) async {
      await _pump(
        tester,
        tasks: [_task('晨会', start: 9 * 60, endDate: _today, end: 10 * 60)],
      );
      expect(find.byKey(TimelinePage.anytimeKey), findsNothing);
    });
  });

  group('跨天的那一截', () {
    testAppWidgets('昨晚延续过来的从 00:00 画起，并标明「承接昨天」', (tester) async {
      await _pump(
        tester,
        tasks: [
          _task(
            '值夜',
            date: _yesterday,
            start: 22 * 60,
            endDate: _today,
            end: 6 * 60,
          ),
        ],
      );
      final canvasTop = tester.getRect(find.byKey(TimelinePage.tickKey(0))).top;
      expect(_blockRect(tester, '值夜').top - canvasTop, closeTo(0, 0.5));
      expect(find.text('↑ 承接昨天'), findsOneWidget);
      expect(find.text('↓ 延续到明天'), findsNothing);
    });

    testAppWidgets('延续到明天的标在下缘', (tester) async {
      await _pump(
        tester,
        tasks: [
          _task('值夜', start: 22 * 60, endDate: _today.addDays(1), end: 6 * 60),
        ],
      );
      expect(find.text('↓ 延续到明天'), findsOneWidget);
      expect(find.text('↑ 承接昨天'), findsNothing);
    });
  });

  group('当前时刻线', () {
    testAppWidgets('今天才有', (tester) async {
      // `viewPipelineOverrides` 里的 today 是 9/8，而 harness 的时钟
      // 停在 9/7 —— 所以这里显式把时钟对到 9/8 才谈得上「现在」。
      await _pump(tester, tasks: [_task('晨会', start: 9 * 60)]);
      expect(find.byKey(TimelinePage.nowLineKey), findsOneWidget);
    });

    testAppWidgets('别的日子没有 —— 在昨天画一条「现在」是假的', (tester) async {
      await _pump(
        tester,
        focus: _yesterday,
        tasks: [_task('晨会', date: _yesterday, start: 9 * 60)],
      );
      expect(find.byKey(TimelinePage.nowLineKey), findsNothing);
    });

    testAppWidgets('心跳到了就重画 —— 线会往下走', (tester) async {
      // 这条把「每分钟更新」验成**行为**而不是一句注释：
      // 掐掉心跳（默认 override 就是空流）之后线是静止的，
      // 那时「会不会动」根本没人验过。
      final ticks = StreamController<void>.broadcast();
      addTearDown(ticks.close);
      var now = DateTime.utc(2026, 9, 8, 1); // 东八区 09:00

      await _pump(
        tester,
        tasks: [_task('晨会', start: 9 * 60)],
        tick: ticks.stream,
        now: () => now,
      );

      final before = tester.getRect(find.byKey(TimelinePage.nowLineKey)).top;
      now = now.add(const Duration(minutes: 30));
      ticks.add(null);
      await tester.pumpAndSettle();
      final after = tester.getRect(find.byKey(TimelinePage.nowLineKey)).top;

      expect(after - before, closeTo(30 * _scale, 0.5));
    });
  });

  group('空态与错误态', () {
    testAppWidgets('这一天什么都没有 → 空态三件套', (tester) async {
      var tapped = false;
      await _pump(tester, onCreateTask: () => tapped = true);

      expect(find.byKey(TimelinePage.emptyKey), findsOneWidget);
      expect(find.byType(EmptyIllustration), findsOneWidget);
      expect(find.textContaining('要加点什么吗'), findsOneWidget);

      await tester.tap(find.text('新建任务'));
      expect(tapped, isTrue, reason: '点不动的按钮比没有按钮更糟');
    });

    testAppWidgets('读库失败要显式一屏，不是空画布', (tester) async {
      // 空画布与「我的任务全没了」长得一模一样，那是最吓人的误解。
      await _pump(
        tester,
        tasksStream: Stream<List<Task>>.error(StateError('库炸了')),
      );
      expect(find.byKey(TimelinePage.errorKey), findsOneWidget);
      expect(find.byKey(TimelinePage.emptyKey), findsNothing);
    });
  });

  group('刻度粒度同时决定纵向比例尺', () {
    // ## 为什么这一组要参数化
    //
    // `view.timelineTickMinutes` 是 FR 里明写的可配项（15/30/60），而它
    // **不只是加密刻度线** —— 一格恒为 `tickHeight`，所以选 15 分钟等于
    // 把一天拉长四倍。只在模拟器上手工验过的话，下次改布局时没人会重跑它，
    // 而失效的样子是「设置里改了没反应」：那一族缺陷这个项目已经撞过三次。

    for (final tick in [15, 30, 60]) {
      testAppWidgets('$tick 分钟一格：一格恒为 tickHeight，块按比例', (tester) async {
        await _pump(
          tester,
          tasks: [_task('晨会', start: 9 * 60, endDate: _today, end: 10 * 60)],
          settings: {'view.timelineTickMinutes': tick},
        );

        // 相邻两个刻度之间恒为一格高 —— 这是「比例尺变了」的直接证据。
        final first = tester
            .getRect(find.byKey(TimelinePage.tickKey(0)))
            .center
            .dy;
        final second = tester
            .getRect(find.byKey(TimelinePage.tickKey(tick)))
            .center
            .dy;
        expect(second - first, closeTo(TimelineMetrics.tickHeight, 0.5));

        // 一小时的块 = 60 分钟 × 该档比例。
        // 60 档下是 48，30 档下 96，15 档下 192 —— 三档必须各不相同，
        // 否则「改了没反应」就是绿的。
        expect(
          _blockRect(tester, '晨会').height,
          closeTo(60 * TimelineMetrics.pixelsPerMinute(tick), 0.5),
        );
      });
    }

    testAppWidgets('三档的块高确实两两不同 —— 否则上面三条可以一起绿', (tester) async {
      // 上面每条各自比对自己那一档的期望值。若哪天 `pixelsPerMinute`
      // 退化成常量，三条会一起绿（期望值也跟着退化成同一个数）——
      // 与「守卫比的是两张都过时的表」是同一种毛病。这条盯的是**期望值本身**。
      expect({
        for (final t in [15, 30, 60]) TimelineMetrics.pixelsPerMinute(t),
      }, hasLength(3));
    });

    testAppWidgets('默认一小时一格，00:00 与 23:00 都在', (tester) async {
      await _pump(tester, tasks: [_task('晨会', start: 9 * 60)]);
      expect(find.byKey(TimelinePage.tickKey(0)), findsOneWidget);
      expect(find.byKey(TimelinePage.tickKey(23 * 60)), findsOneWidget);
      expect(
        find.byKey(TimelinePage.tickKey(30)),
        findsNothing,
        reason: '60 分钟一格时不该有 00:30',
      );
    });
  });
}

/// 时钟可以往前走的假时钟 —— `FixedClock` 是钉死的，验不了「线会动」。
final class _MovingClock implements Clock {
  const _MovingClock(this._read);

  final DateTime Function() _read;

  @override
  DateTime nowUtc() => _read();
}

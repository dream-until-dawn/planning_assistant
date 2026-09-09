/// 竖向甘特视图（view-specs §4、FR-VIEW-04）。
///
/// 布局的对错在 `gantt_layout_test` 里按整数验过了。这里验的是
/// **画笔与布局对得上**：条的矩形落在哪、点中的是不是看得见的那一根、
/// 今日线只在窗口含今天时出现。
///
/// 条形层是 `CustomPainter` 画的，所以不能用 `find.byKey` 找一根条 ——
/// 直接问画笔（`GanttPainter.barAt`），那也正是界面点击走的同一条路。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/design/components/app_chip.dart';
import 'package:planning_assistant/design/theme/app_theme.dart';
import 'package:planning_assistant/domain/entities/category.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/features/views/gantt/application/gantt_providers.dart';
import 'package:planning_assistant/features/views/gantt/presentation/gantt_metrics.dart';
import 'package:planning_assistant/features/views/gantt/presentation/gantt_painter.dart';
import 'package:planning_assistant/features/views/gantt/presentation/gantt_view.dart';
import 'package:planning_assistant/features/views/shared/application/view_shared_state.dart';

import '../support/app_harness.dart';

const _today = PlanDate(2026, 9, 8);

Task _task(
  String id, {
  int from = 0,
  int? to,
  String? categoryId,
  int? startMinute,
  int? endMinute,
}) => Task(
  id: id,
  title: id,
  kind: TaskKind.single,
  timeZoneId: 'Asia/Shanghai',
  planDate: _today.addDays(from),
  startMinute: startMinute == null ? null : MinuteOfDay(startMinute),
  endDate: to == null ? null : _today.addDays(to),
  endMinute: endMinute == null ? null : MinuteOfDay(endMinute),
  isAllDay: startMinute == null,
  categoryId: categoryId,
);

Future<void> _pump(
  WidgetTester tester, {
  List<Task> tasks = const [],
  List<Category> categories = const [],
  Map<String, Object?> settings = const {},
}) async {
  await setScreenSize(tester, const Size(390, 844));
  await tester.pumpWidget(
    ProviderScope(
      overrides: viewPipelineOverrides(
        tasks: tasks,
        categories: categories,
        settings: settings,
        today: _today,
      ),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: GanttView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 把画笔取出来 —— 界面点击走的就是它的 `barAt`。
GanttPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byKey(GanttView.canvasKey)).painter!
        as GanttPainter;

void main() {
  group('FR-VIEW-04 可缩放时间粒度（日/周/月）', () {
    // 验收原话里的一款。补它之前，「日」是一扇**单向门**：
    // 它是默认值（所以不是死代码），而界面上唯一能设粒度的地方是
    // 日历那个月/周切换 —— 只有两档。用户点一下「月」，
    // 甘特的窗口就再也回不到 14 天。
    //
    // 与 M2 那条「选了『到某天为止』却没地方选日期」是一对镜像：
    // 那条是走进去出不来，这条是出去了回不来。
    // 而验收原话是「**可缩放**」—— 单向的切换不叫可缩放。
    //
    // 可追溯性门禁看不见这种：它只知道 FR-VIEW-04 被某条用例点过名。
    // 这是「点名 ≠ 测到」在**一条需求内部**的版本。

    testAppWidgets('三档给的窗口各不相同 —— 不是个装饰', (tester) async {
      await _pump(tester, tasks: [_task('a', from: 0, to: 1)]);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GanttView)),
      );

      final spans = <int>[];
      for (final g in TimeGranularity.values) {
        await tapVisible(tester, GanttView.granularityKey(g));
        final w = container.read(ganttWindowProvider);
        spans.add(w.start.differenceInDays(w.end).abs());
      }
      expect(spans.toSet(), hasLength(3), reason: '三档给出同样长的窗口，这个切换就是个装饰');
    });

    testAppWidgets('**「日」回得去** —— 补它之前那是一扇单向门', (tester) async {
      // 「日」是默认值，所以问题不是「设不上」，是**出去了回不来**：
      // 日历那个切换只有月/周，点过之后甘特再也回不到 14 天窗口。
      await _pump(tester, tasks: [_task('a', from: 0, to: 1)]);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GanttView)),
      );
      expect(
        container.read(viewSharedStateProvider).granularity,
        TimeGranularity.day,
        reason: '前提：默认就是「日」',
      );

      // 模拟用户在日历上点了「月」。
      container
          .read(viewSharedStateProvider.notifier)
          .setGranularity(TimeGranularity.month);
      await tester.pumpAndSettle();

      await tapVisible(tester, GanttView.granularityKey(TimeGranularity.day));
      expect(
        container.read(viewSharedStateProvider).granularity,
        TimeGranularity.day,
        reason: '回不到「日」—— 那扇门还是单向的',
      );
    });

    testAppWidgets('三档都设得上', (tester) async {
      await _pump(tester, tasks: [_task('a', from: 0, to: 1)]);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GanttView)),
      );

      for (final g in TimeGranularity.values) {
        await tapVisible(tester, GanttView.granularityKey(g));
        expect(
          container.read(viewSharedStateProvider).granularity,
          g,
          reason: '${g.name} 这一档设不上',
        );
      }
    });

    testAppWidgets('与日历共用同一份粒度（§0.1）', (tester) async {
      // 甘特自己存一份的话，从日历切过来两边对不上。
      await _pump(tester, tasks: [_task('a', from: 0, to: 1)]);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GanttView)),
      );
      container
          .read(viewSharedStateProvider.notifier)
          .setGranularity(TimeGranularity.week);
      await tester.pumpAndSettle();

      final chip = tester.widget<SelectableChip>(
        find.byKey(GanttView.granularityKey(TimeGranularity.week)),
      );
      expect(chip.selected, isTrue, reason: '甘特没跟着共享状态走');
    });
  });

  group('FR-VIEW-04 画出来的东西与布局对得上', () {
    testAppWidgets('一根条的矩形高度 = 跨度 × 比例', (tester) async {
      await _pump(tester, tasks: [_task('出差', to: 2)]);
      final painter = _painter(tester);
      final bar = painter.layout.lanes.single.bars.single;

      // 条从窗口起点往下第 bar.startMinute 分钟处开始。
      final top = bar.startMinute * GanttMetrics.pixelsPerMinute;
      final x = painter.width / 2;
      expect(painter.barAt(Offset(x, top + 4))?.id, '出差');

      // **两头之外都点不中。**
      //
      // 只验「里面点得中」是不够的：把顶端写死成 0（条全从画布顶上开始）
      // 之后，原来那个探针仍然落在条里 —— 变异演练里它活了下来。
      // 顶上那一下才分得开。
      expect(
        painter.barAt(Offset(x, top - 20)),
        isNull,
        reason: '条的上方不该有东西 —— 顶端没按 startMinute 算',
      );
      final bottom = bar.endMinute * GanttMetrics.pixelsPerMinute;
      expect(painter.barAt(Offset(x, bottom + 20)), isNull);
    });

    testAppWidgets('两条泳道左右分开 —— 点左边不该点中右边那根', (tester) async {
      await _pump(
        tester,
        tasks: [
          _task('工作的', to: 2, categoryId: 'work'),
          _task('私事', to: 2, categoryId: 'life'),
        ],
        categories: const [
          Category(
            id: 'life',
            name: '生活',
            colorArgb: 0xFF111111,
            icon: 'x',
            orderIndex: 0,
          ),
          Category(
            id: 'work',
            name: '工作',
            colorArgb: 0xFF222222,
            icon: 'x',
            orderIndex: 1,
          ),
        ],
      );
      final painter = _painter(tester);
      expect(painter.layout.lanes.map((l) => l.title), ['生活', '工作']);

      final y =
          painter.layout.lanes.first.bars.single.startMinute *
              GanttMetrics.pixelsPerMinute +
          4;
      expect(painter.barAt(Offset(painter.width * 0.25, y))?.id, '私事');
      expect(painter.barAt(Offset(painter.width * 0.75, y))?.id, '工作的');
    });

    testAppWidgets('两根条的框重叠时，点中的是画在上面那根', (tester) async {
      // 半小时的任务只有一个像素高，框会被撑到最小长度（六像素，
      // 也就是三小时）。紧随其后一小时的那根就落在它的框里。
      //
      // 从前往后找的话，点中的是**被盖住**的那一根 —— 屏幕上看着点了「后」，
      // 打开的是「先」。这条第一版用的是两根整天的条，各占四十八像素、
      // 前后相接却不重叠，于是从前从后都一样，变异活了下来。
      await _pump(
        tester,
        tasks: [
          _task('先', startMinute: 9 * 60, to: 0, endMinute: 9 * 60 + 30),
          _task('后', startMinute: 10 * 60, to: 0, endMinute: 10 * 60 + 30),
        ],
      );
      final painter = _painter(tester);
      final bars = painter.layout.lanes.single.bars;
      expect(bars, hasLength(2));
      expect(bars.map((b) => b.column).toSet(), {0}, reason: '两根在同一列才会叠框');

      // 「后」的顶端落在「先」被撑长的框之内。
      final firstBottom =
          bars[0].startMinute * GanttMetrics.pixelsPerMinute +
          GanttMetrics.minBarLength;
      final secondTop = bars[1].startMinute * GanttMetrics.pixelsPerMinute;
      expect(secondTop, lessThan(firstBottom), reason: '夹具没造出重叠的框');

      expect(
        painter.barAt(Offset(painter.width / 2, secondTop + 1))?.id,
        '后',
        reason: '点中了被盖住的那一根',
      );
    });

    testAppWidgets('泳道表头画的是泳道的名字', (tester) async {
      await _pump(tester, tasks: [_task('随便', to: 1)]);
      expect(find.byKey(GanttView.laneHeaderKey), findsOneWidget);
      expect(find.text('未分类'), findsOneWidget);
    });
  });

  group('今日线', () {
    testAppWidgets('窗口含今天时有', (tester) async {
      await _pump(tester, tasks: [_task('随便', to: 1)]);
      // 窗口从聚焦日往前三天开始，所以今天在第 3 天。
      expect(_painter(tester).todayOffsetMinutes, 3 * 1440);
    });

    testAppWidgets('聚焦到很久以后时就没有 —— 在不含今天的一段里画「今天」是假的', (tester) async {
      await _pump(tester, tasks: [_task('明年', from: 200, to: 202)]);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GanttView)),
      );
      container
          .read(viewSharedStateProvider.notifier)
          .focusDate(_today.addDays(200));
      await tester.pumpAndSettle();
      expect(_painter(tester).todayOffsetMinutes, isNull);
    });
  });

  group('空态与错误态', () {
    testAppWidgets('这段时间没有跨度可画 → 空态三件套', (tester) async {
      var tapped = false;
      await setScreenSize(tester, const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: viewPipelineOverrides(today: _today),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: GanttView(onCreateTask: ({date, minute}) => tapped = true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(GanttView.emptyKey), findsOneWidget);
      await tester.tap(find.text('新建任务'));
      expect(tapped, isTrue, reason: '点不动的按钮比没有按钮更糟');
    });

    testAppWidgets('读库失败要显式一屏，不是空画布', (tester) async {
      await setScreenSize(tester, const Size(390, 844));
      await tester.pumpWidget(
        ProviderScope(
          overrides: viewPipelineOverrides(
            today: _today,
            tasksStream: Stream<List<Task>>.error(StateError('库炸了')),
          ),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: GanttView()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(GanttView.errorKey), findsOneWidget);
      expect(find.byKey(GanttView.canvasKey), findsNothing);
    });
  });

  group('泳道维度这个旋钮够得着', () {
    // 夹具用 ASCII 名字：同一天开始的两条泳道按 id 兜底排，
    // 而中文按 UTF-16 码位比（乙 U+4E59 在 甲 U+7532 之前）——
    // 拿中文写期望值的话，红的原因是「我以为按笔画排」，不是代码错。
    testAppWidgets('改成「按任务」，泳道就按任务分', (tester) async {
      await _pump(
        tester,
        tasks: [_task('a-task', to: 2), _task('b-task', to: 2)],
        settings: {'view.ganttLaneBy': 'task'},
      );
      final titles = _painter(tester).layout.lanes.map((l) => l.title).toList();
      expect(titles, ['a-task', 'b-task']);
    });

    testAppWidgets('对照组：默认按分类时它们并在一条泳道里', (tester) async {
      await _pump(
        tester,
        tasks: [_task('a-task', to: 2), _task('b-task', to: 2)],
      );
      expect(_painter(tester).layout.lanes, hasLength(1));
    });
  });
}

/// 日历的数据源（view-specs §3、FR-VIEW-05/06）。
///
/// 这里验两件事：
///
/// 1. **日历自己读对了共享状态** —— 月/周档位、一周从周几起、窗口覆盖到
///    补进来的灰日期。
/// 2. **筛选是共用的那一份** —— 同一个筛选条件，三个视图看到的是同一批
///    任务。共享层最容易出的毛病不是「哪一侧算错了」，而是
///    「每一侧都对，但它们读的不是同一份」。
@TestOn('vm')
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/domain/entities/category.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/features/views/calendar/application/calendar_providers.dart';
import 'package:planning_assistant/features/views/calendar/application/day_bands.dart';
import 'package:planning_assistant/features/views/shared/application/view_shared_state.dart';
import 'package:planning_assistant/features/views/task_list/application/task_list_providers.dart';
import 'package:planning_assistant/features/views/timeline/application/timeline_providers.dart';

import '../support/app_harness.dart';

/// 2026-09-08 是周二，所以 9 月第一行（周一起）从 8-31 起。
const _today = PlanDate(2026, 9, 8);

Task _task(
  String id, {
  PlanDate? date = _today,
  PlanDate? endDate,
  int? start,
  bool isAllDay = false,
  String? categoryId,
}) => Task(
  id: id,
  title: id,
  kind: TaskKind.single,
  timeZoneId: 'Asia/Shanghai',
  planDate: date,
  startMinute: start == null ? null : MinuteOfDay(start),
  endDate: endDate,
  isAllDay: isAllDay,
  categoryId: categoryId,
);

Future<ProviderContainer> _container({
  List<Task> tasks = const [],
  List<Category> categories = const [],
  Map<String, Object?> settings = const {},
}) async {
  final c = ProviderContainer(
    overrides: viewPipelineOverrides(
      tasks: tasks,
      categories: categories,
      settings: settings,
      today: _today,
    ),
  );
  addTearDown(c.dispose);
  // **必须等** —— 同步读下游拿到的是 loading 的回落值，而那些回落
  // 被刻意设计成「看起来正常」（任务空表、配置默认值）。见它的注释。
  await settleViewPipeline(c);
  return c;
}

void main() {
  group('档位来自共享状态，日历不自己存一份', () {
    test('默认（day）按周处理 —— 一行', () async {
      // 「日」这一档日历没有对应形态。给一屏空白比给一个它不认识的
      // 档位强，所以按周画。
      final c = await _container();
      expect(c.read(calendarIsMonthProvider), isFalse);
      expect(c.read(calendarWeeksProvider), hasLength(1));
    });

    test('切到月 → 六行', () async {
      final c = await _container();
      c
          .read(viewSharedStateProvider.notifier)
          .setGranularity(TimeGranularity.month);
      expect(c.read(calendarWeeksProvider), hasLength(6));
    });

    test('从甘特那侧改档位，日历跟着变 —— 两边读的是同一份', () async {
      // 日历自己存一份的话，从甘特切过来时两边会对不上，
      // 而那正是 FR-VIEW-05/06 要避免的。
      final c = await _container();
      final shared = c.read(viewSharedStateProvider.notifier);
      shared.setGranularity(TimeGranularity.month);
      expect(c.read(calendarIsMonthProvider), isTrue);
      shared.setGranularity(TimeGranularity.week);
      expect(c.read(calendarIsMonthProvider), isFalse);
    });
  });

  group('一周从周几起，配置说了算', () {
    test('默认周一：9 月那一屏从 8-31 起', () async {
      final c = await _container();
      c
          .read(viewSharedStateProvider.notifier)
          .setGranularity(TimeGranularity.month);
      expect(
        c.read(calendarWeeksProvider).first.first.date,
        const PlanDate(2026, 8, 31),
      );
    });

    test('改成周日：整屏往前挪一天', () async {
      final c = await _container(settings: {'view.firstDayOfWeek': 'sunday'});
      c
          .read(viewSharedStateProvider.notifier)
          .setGranularity(TimeGranularity.month);
      expect(
        c.read(calendarWeeksProvider).first.first.date,
        const PlanDate(2026, 8, 30),
      );
    });

    test('表头顺序跟着一起变，不是各算各的', () async {
      // 两处各算一遍的话，表头写着「一」而那一列其实是周日 ——
      // 没人会把它当 bug 报，只会觉得这个日历怪怪的。
      final c = await _container(settings: {'view.firstDayOfWeek': 'sunday'});
      expect(
        c.read(calendarWeekdayOrderProvider).map((w) => w.label).toList(),
        ['日', '一', '二', '三', '四', '五', '六'],
      );
      expect(
        c.read(calendarWeeksProvider).first.map((cell) => cell.date.weekday),
        c.read(calendarWeekdayOrderProvider).map((w) => w.isoNumber),
      );
    });

    test('认不出的配置值回落到周一，不炸', () async {
      final c = await _container(settings: {'view.firstDayOfWeek': '星期八'});
      expect(c.read(firstDayOfWeekSettingProvider).isoNumber, 1);
    });
  });

  group('窗口盖住整屏，含补进来的灰日期', () {
    test('上个月尾巴上的任务也要有标记', () async {
      // 不盖的话月初那几格看起来是空的，而它们其实有事 ——
      // 用户会以为月初那几天没安排。
      final c = await _container(
        tasks: [_task('八月底', date: const PlanDate(2026, 8, 31), start: 540)],
      );
      c
          .read(viewSharedStateProvider.notifier)
          .setGranularity(TimeGranularity.month);
      final layout = c.read(calendarLayoutProvider);
      expect(layout.weeks.first.first.date, const PlanDate(2026, 8, 31));
      expect(layout.dots.first.first.rows.map((r) => r.id), ['八月底']);
    });

    test('layout 的形状与格子对得上', () async {
      final c = await _container();
      c
          .read(viewSharedStateProvider.notifier)
          .setGranularity(TimeGranularity.month);
      final layout = c.read(calendarLayoutProvider);
      expect(layout.bands, hasLength(layout.weeks.length));
      expect(layout.dots, hasLength(layout.weeks.length));
      for (final row in layout.dots) {
        expect(row, hasLength(7));
      }
    });

    test('被挤掉的横条算进那一格的「+N」', () async {
      // 不算的话那一格显示「满了三条横条」，第四条既没横条也没点，
      // 用户没有任何线索知道它存在。
      final c = await _container(
        tasks: [
          for (var i = 0; i < 4; i++)
            _task('并行$i', endDate: _today.addDays(2), isAllDay: true),
        ],
      );
      final layout = c.read(calendarLayoutProvider);
      final row = layout.weeks.first.indexWhere((c) => c.date == _today);
      expect(layout.bands.first.bands, hasLength(maxBandsPerWeek));
      expect(layout.dots.first[row].overflow, 1);
    });
  });

  group('下半屏那份列表', () {
    test('跨天任务在它盖到的每一天都要出现', () async {
      final c = await _container(
        tasks: [
          _task(
            '出差',
            date: _today.addDays(-1),
            endDate: _today.addDays(1),
            isAllDay: true,
          ),
        ],
      );
      expect(c.read(selectedDayRowsProvider).map((r) => r.id), ['出差']);

      c.read(viewSharedStateProvider.notifier).focusDate(_today.addDays(1));
      expect(c.read(selectedDayRowsProvider).map((r) => r.id), ['出差']);

      c.read(viewSharedStateProvider.notifier).focusDate(_today.addDays(2));
      expect(c.read(selectedDayRowsProvider), isEmpty);
    });

    test('全天/跨天排在前面，然后按时刻', () async {
      final c = await _container(
        tasks: [
          _task('下午', start: 15 * 60),
          _task('纪念日', isAllDay: true),
          _task('上午', start: 9 * 60),
        ],
      );
      expect(c.read(selectedDayRowsProvider).map((r) => r.id), [
        '纪念日',
        '上午',
        '下午',
      ]);
    });
  });

  group('筛选是共用的那一份（FR-VIEW-05）', () {
    // 共享层最容易出的毛病不是「哪一侧算错了」，而是**每一侧都对，
    // 但它们读的不是同一份**。M2 那次 durationMinutes 就是这个形状：
    // 引擎测了、视图测了，中间没人接。

    List<String> idsOf(ProviderContainer c, Provider<List<dynamic>> p) => [
      for (final r in c.read(p)) (r as dynamic).taskId as String,
    ];

    test('按分类筛掉的任务，三个视图一起消失', () async {
      final c = await _container(
        tasks: [
          _task('工作的', start: 9 * 60, categoryId: 'work'),
          _task('私事', start: 10 * 60, categoryId: 'life'),
        ],
        categories: const [
          Category(
            id: 'work',
            name: '工作',
            colorArgb: 0xFF000000,
            icon: 'circle',
            orderIndex: 0,
          ),
          Category(
            id: 'life',
            name: '生活',
            colorArgb: 0xFF111111,
            icon: 'circle',
            orderIndex: 1,
          ),
        ],
      );

      // 筛之前三处都有两条。
      expect(idsOf(c, calendarOccurrencesProvider), hasLength(2));
      expect(idsOf(c, timelineOccurrencesProvider), hasLength(2));
      expect(idsOf(c, filteredTasksProvider), hasLength(2));

      c
          .read(viewSharedStateProvider.notifier)
          .setFilter(const FilterSpec(categoryIds: {'work'}));

      for (final p in <Provider<List<dynamic>>>[
        calendarOccurrencesProvider,
        timelineOccurrencesProvider,
        filteredTasksProvider,
      ]) {
        expect(idsOf(c, p), ['工作的'], reason: '$p 没跟上共享的筛选');
      }
    });

    test('聚焦日也是共用的：日历改一天，时间轴跟着换', () async {
      final c = await _container(
        tasks: [
          _task('今天的', start: 9 * 60),
          _task('明天的', date: _today.addDays(1), start: 9 * 60),
        ],
      );
      expect(idsOf(c, timelineOccurrencesProvider), ['今天的']);

      // 日历上点了明天。
      c.read(viewSharedStateProvider.notifier).focusDate(_today.addDays(1));
      expect(idsOf(c, timelineOccurrencesProvider), [
        '明天的',
      ], reason: '时间轴还停在旧日期 —— 两边各存了一份聚焦日');
      expect(c.read(selectedDayRowsProvider).map((r) => r.taskId), ['明天的']);
    });
  });
}

/// 日历视图的数据源（view-specs §3）。
///
/// **视图不自己查库**（§0.2）—— 与列表、时间轴走同一条流，
/// 展开同样用 [expandInWindow]（窗口内一次不落）。
///
/// 一次算完整个月：格子、每一行的横条、每一格的色点。**不做成
/// 按天/按周的 family** —— 横条的层号本来就要在一整行里统一分配，
/// 拆成七个 provider 各算各的，第一件事就得是把它们再拼回去。
///
/// **按月的 family 是有的**（[calendarLayoutForProvider]）：跟手滑动
/// 要求相邻月份同时画得出来，而「一整月」正好是横条分层的自然边界。
/// 聚焦月那一份（[calendarLayoutProvider]）只是它的一个特例。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../../../app_providers.dart';
import '../../../../core/time/plan_date.dart';
import '../../../../core/time/weekday.dart';
import '../../../../domain/recurrence/recurrence_engine.dart';
import '../../../../domain/value_objects/task_status.dart';
import '../../../settings/application/registry.dart';
import '../../../settings/application/settings_providers.dart';
import '../../shared/application/occurrence_expansion.dart';
import '../../shared/application/task_filter.dart';
import '../../shared/application/task_occurrence.dart';
import '../../shared/application/task_providers.dart';
import '../../shared/application/view_shared_state.dart';
import 'day_bands.dart';
import 'month_grid.dart';

/// 日历现在是月视图还是周视图。
///
/// 取自**共享状态**的 `granularity`（§0.1「日/周/月，甘特与日历共用」）——
/// 日历自己再存一份的话，从甘特切过来时两边会对不上，
/// 而那正是 FR-VIEW-05/06 要避免的。
///
/// `day` 这一档日历没有对应形态，**按月处理** —— 月视图是日历的默认
/// （§3.1 那张表第一行）。按周处理的话，从别的视图切过来时日历默认
/// 是周视图，与规格相反。
/// **日历恒为月视图。**
///
/// 一度跟着共享的 `granularity` 走（§0.1「日/周/月，甘特与日历共用」），
/// 界面上还配了一个月/周切换。用户看过之后要求去掉周视图：
/// 一个月的格子已经能一眼看完，而「周」那一档既占一个控件的位置，
/// 又让「现在看的是哪一段」多了一种可能。
///
/// 保留这个 provider 而不是把 `true` 散到各处：`calendarWeeksProvider`
/// 与格子高度的算法都读它，将来若要恢复周视图，改这一处就够。
///
/// **甘特那边的粒度不受影响** —— 它有自己的日/周/月切换
/// （FR-VIEW-04 的验收原话），只是日历不再跟着变了。
final calendarIsMonthProvider = Provider<bool>((ref) => true);

/// 某一个月要画哪些格子。
final calendarWeeksForProvider =
    Provider.family<List<List<MonthCell>>, YearMonth>((ref, ym) {
      final start = ref.watch(firstDayOfWeekSettingProvider).isoNumber;

      return ref.watch(calendarIsMonthProvider)
          ? monthGrid(
              year: ym.year,
              month: ym.month,
              firstDayOfWeek: start,
            ).weeks
          : [weekOf(PlanDate(ym.year, ym.month, 1), firstDayOfWeek: start)];
    });

/// 聚焦的那一个月。跟手滑动时它是**中间那一页**。
final calendarMonthProvider = Provider<YearMonth>((ref) {
  final focused = ref.watch(viewSharedStateProvider).focusedDate;
  return YearMonth(focused.year, focused.month);
});

/// 这一屏要画哪些格子（聚焦月）。
final calendarWeeksProvider = Provider<List<List<MonthCell>>>(
  (ref) =>
      ref.watch(calendarWeeksForProvider(ref.watch(calendarMonthProvider))),
);

/// 一周从周几起（配置项 `view.firstDayOfWeek`）。
///
/// 单独一个 provider 是因为**表头也要用它**，而表头不该为了一个
/// 星期号去 watch 整张配置表。
final firstDayOfWeekSettingProvider = Provider<Weekday>(
  (ref) => settingOf(ref, firstDayOfWeek),
);

/// 星期表头的顺序（ISO 星期号）。
final calendarWeekdayOrderProvider = Provider<List<Weekday>>((ref) {
  final start = ref.watch(firstDayOfWeekSettingProvider).isoNumber;
  return [
    for (final iso in weekdayOrder(firstDayOfWeek: start)) Weekday.fromIso(iso),
  ];
});

/// 某一个月窗口里的全部发生，已筛选。
final calendarOccurrencesForProvider =
    Provider.family<List<TaskOccurrence>, YearMonth>((ref, ym) {
      final weeks = ref.watch(calendarWeeksForProvider(ym));
      if (weeks.isEmpty) return const [];
      final filter = ref.watch(viewSharedStateProvider).filter;

      return switch (ref.watch(visibleTasksProvider)) {
        AsyncData(:final value) => applyFilter(
          expandInWindow(
            tasks: value,
            overrides: switch (ref.watch(allOverridesProvider)) {
              AsyncData(:final value) => value,
              _ => const [],
            },
            // **整屏一个窗口**，含补进来的上/下月尾巴 —— 它们也要显示
            // 标记，否则月初那几格看起来是空的，而它们其实有事。
            window: DateRange(weeks.first.first.date, weeks.last.last.date),
            // 阶段进来算有效跨度（§4.7）—— 四视图共用同一个答案。
            stagesByTask: ref.watch(stagesByTaskProvider),
            stageStatesByTask: ref.watch(stageStatesByTaskProvider),
            engine: RecurrenceEngine(ref.watch(timeZoneResolverProvider)),
            includeSkipped: filter.statuses.contains(TaskStatus.skipped),
          ),
          filter,
        ),
        _ => const [],
      };
    });

/// 这一屏窗口里的全部发生（聚焦月），已筛选。
final calendarOccurrencesProvider = Provider<List<TaskOccurrence>>(
  (ref) => ref.watch(
    calendarOccurrencesForProvider(ref.watch(calendarMonthProvider)),
  ),
);

/// 一屏排好的日历。
@immutable
final class CalendarLayout {
  const CalendarLayout({
    required this.weeks,
    required this.bands,
    required this.dots,
  });

  final List<List<MonthCell>> weeks;

  /// 与 [weeks] 等长：第 i 行的横条。
  final List<WeekBands> bands;

  /// 与 [weeks] 同形状：第 i 行第 j 格的色点。
  final List<List<DayDots>> dots;
}

/// 某一个月的格子 + 横条 + 色点，一次算完。
final calendarLayoutForProvider = Provider.family<CalendarLayout, YearMonth>((
  ref,
  ym,
) {
  final weeks = ref.watch(calendarWeeksForProvider(ym));
  final rows = ref.watch(calendarOccurrencesForProvider(ym));

  final bands = [for (final w in weeks) weekBands(rows, w.first.date)];
  return CalendarLayout(
    weeks: weeks,
    bands: bands,
    dots: [
      for (final (i, week) in weeks.indexed)
        [
          for (final (j, cell) in week.indexed)
            // 这一格欠着的横条数要传进去 —— 不传的话那一格显示「满了
            // 三条横条」，被挤掉的第四条既没横条也没点，用户没有线索
            // 知道它存在。
            dayDots(rows, cell.date, hiddenBands: bands[i].hiddenByDay[j]),
        ],
    ],
  );
});

/// 聚焦月那一屏。
final calendarLayoutProvider = Provider<CalendarLayout>(
  (ref) =>
      ref.watch(calendarLayoutForProvider(ref.watch(calendarMonthProvider))),
);

/// 下半屏那份列表：选中的那一天有哪些事（§3.1）。
///
/// 没选过任何一天时就是**聚焦日**那天 —— 给一屏空白的话，
/// 刚进日历的用户会以为今天没安排。
final selectedDayRowsProvider = Provider<List<TaskOccurrence>>((ref) {
  final shared = ref.watch(viewSharedStateProvider);
  final date = shared.focusedDate;
  final rows = [
    for (final row in ref.watch(calendarOccurrencesProvider))
      if (_coversDay(row, date)) row,
  ];

  rows.sort((a, b) {
    // 全天/跨天的排在前面 —— 它们是这一天的「背景」，
    // 具体时刻的事排在它们下面。
    final ab = showsAsBand(a) ? 0 : 1;
    final bb = showsAsBand(b) ? 0 : 1;
    if (ab != bb) return ab.compareTo(bb);
    final am = a.startMinute?.value ?? 0;
    final bm = b.startMinute?.value ?? 0;
    return am != bm ? am.compareTo(bm) : a.id.compareTo(b.id);
  });
  return rows;
});

bool _coversDay(TaskOccurrence row, PlanDate date) {
  final start = row.planDate;
  if (start == null) return false;
  final end = row.effectiveEndDate ?? start;
  return !date.isBefore(start) && !date.isAfter(end);
}

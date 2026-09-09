/// 日历视图（view-specs §3、FR-VIEW-03）。
///
/// ```
/// │  一  二  三  四  五  六  日        │ ← 表头，顺序随 firstDayOfWeek
/// ├───┬───┬───┬───┬───┬───┬───┤
/// │ 31│ 1 │ 2 │ 3 │ 4 │ 5 │ 6 │
/// │   │▓▓▓▓▓▓▓▓▓▓▓│   │   │   │ ← 跨天任务：一条，贯穿，不断开
/// │   │ ● │ ●●│   │+2 │   │   │ ← 当天的事用色点
/// ├───┴───┴───┴───┴───┴───┴───┤
/// │ ════ 拖这里改上下比例 ════ │
/// ├───────────────────────────┤
/// │ 选中那天的任务列表          │
/// ```
///
/// **格子是自己搭的，不用 `table_calendar`**（§3.3 记了变更理由）：
/// 那个库的 builder 全是按格子调的，而「横条贯穿不断开」要的是
/// 一行一个 widget。自己搭之后横条就是 `Positioned`，不存在拼接缝。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app_providers.dart';
import '../../../../core/time/plan_date.dart';
import '../../../../design/components/app_chip.dart';
import '../../../../design/components/empty_illustration.dart';
import '../../../../design/components/empty_state.dart';
import '../../../../design/components/task_card.dart';
import '../../../../design/theme/app_theme.dart';
import '../../../../design/tokens/dimensions.dart';
import '../../../../domain/entities/category.dart';
import '../../../settings/application/motion.dart';
import '../../../settings/application/registry.dart';
import '../../../settings/application/settings_providers.dart';
import '../../shared/application/category_providers.dart';
import '../../shared/application/create_task_at.dart';
import '../../shared/application/task_occurrence.dart';
import '../../shared/application/task_providers.dart';
import '../../shared/application/view_shared_state.dart';
import '../../shared/presentation/occurrence_card_data.dart';
import '../../shared/presentation/toggle_done_action.dart';
import '../../task_list/presentation/occurrence_actions_sheet.dart';
import '../application/calendar_providers.dart';
import '../application/calendar_split.dart';
import '../application/day_bands.dart';
import '../application/month_grid.dart';
import 'calendar_metrics.dart';

/// 打开某条任务（重复的先问「改哪一次」）。
typedef OpenTask = void Function(String taskId, {String? from});

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({this.onCreateTask, this.onEditTask, super.key});

  final OpenTask? onEditTask;
  final CreateTaskAt? onCreateTask;

  static const Key gridKey = ValueKey('calendar-grid');

  /// 顶部那一行（现在是月份标题 + 翻月，一度是月/周切换）。
  static const Key modeToggleKey = ValueKey('calendar-mode-toggle');

  /// 当前月份的标题 —— 「看不出现在几月」是用户报的问题之一。
  static const Key monthTitleKey = ValueKey('calendar-month-title');
  static const Key prevMonthKey = ValueKey('calendar-prev-month');
  static const Key nextMonthKey = ValueKey('calendar-next-month');

  /// 月/周切换里的某一档。
  static Key modeKey(String mode) => ValueKey('calendar-mode-$mode');
  static const Key headerKey = ValueKey('calendar-header');
  static const Key handleKey = ValueKey('calendar-split-handle');
  static const Key selectedListKey = ValueKey('calendar-selected-list');
  static const Key selectedEmptyKey = ValueKey('calendar-selected-empty');
  static const Key errorKey = ValueKey('calendar-error');

  /// 某一格。
  static Key dayKey(PlanDate date) => ValueKey('calendar-day-$date');

  /// 某一格里的「+N」。
  static Key overflowKey(PlanDate date) => ValueKey('calendar-more-$date');

  /// 某一行里的某条横条。**带上行号** —— 一条跨两行的任务会有两条横条，
  /// 只用 taskId 的话两个 widget 会撞 key。
  static Key bandKey(String rowId, int week) =>
      ValueKey('calendar-band-$week-$rowId');

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  /// 拖拽中的比例。松手才落库 —— 每一帧都写一次配置的话，
  /// 一次拖拽会往 change_log 里塞几十条记录。
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    if (ref.watch(visibleTasksProvider).hasError) {
      return const EmptyState(
        key: CalendarPage.errorKey,
        illustration: EmptyIllustration(motif: EmptyMotif.offline),
        message: '没能读出这个月的安排。\n重开一次试试？',
      );
    }

    final double split = _dragging ?? ref.setting(calendarSplitRatio);

    return LayoutBuilder(
      builder: (context, constraints) {
        final usable =
            constraints.maxHeight -
            CalendarMetrics.headerHeight -
            CalendarMetrics.handleHeight;

        // **比例定的是「一格多高」，不是「格子区多高」。**
        //
        // 直接把 `usable * split` 给格子区的话，周视图那一行会被拉成
        // 月视图六行那么高 —— 一行日期占掉大半屏，下面的列表挤没了。
        // 而且月↔周来回切时格子会忽大忽小。
        //
        // 按「月视图六行」定出行高，再乘当前行数：月视图仍是
        // `usable * split`，周视图自然只占六分之一，多出来的归列表。
        final rowHeight = usable * split / weeksPerMonthView;
        final gridHeight = rowHeight * ref.watch(calendarWeeksProvider).length;

        return Column(
          children: [
            const _MonthHeader(key: CalendarPage.modeToggleKey),
            const _WeekdayHeader(key: CalendarPage.headerKey),
            SizedBox(
              height: gridHeight,
              child: _Grid(
                key: CalendarPage.gridKey,
                onEditTask: widget.onEditTask,
              ),
            ),
            _SplitHandle(
              key: CalendarPage.handleKey,
              onDelta: (dy) => setState(() {
                // 拖的是**格子区**的边，而比例定的是行高 —— 所以位移要
                // 按当前行数折回去，否则周视图里拖一格，屏幕上动六格。
                final rows = ref.read(calendarWeeksProvider).length;
                _dragging = CalendarSplit.clamp(
                  split + dy * weeksPerMonthView / (rows * usable),
                );
              }),
              onDone: () async {
                final value = _dragging;
                if (value == null) return;
                // **先落库，再交还给配置。**
                //
                // 反过来写（先清 `_dragging` 再异步写库）的话，中间那几帧
                // 读到的还是**旧**比例 —— 屏幕会先弹回去再跳到新位置。
                // 第一版就是那么写的，测试里表现为「拖完高度一点没变」。
                await ref
                    .read(settingsWriterProvider)
                    .set(calendarSplitRatio, value);
                if (mounted) setState(() => _dragging = null);
              },
            ),
            Expanded(
              child: _SelectedDayList(
                onEditTask: widget.onEditTask,
                onCreateTask: widget.onCreateTask,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 月 / 周切换。
///
/// **这个控件是补出来的。** `granularity` 是共享状态里的字段，日历读它、
/// 甘特也要读它，但**没有任何地方写它** —— 于是用户永远停在默认那一档，
/// 月视图根本到不了。又是一次「模型有旋钮、界面上够不着」
/// （testing-strategy §1.6）：这次是在模拟器上一眼看出来的，
/// 因为屏幕上只有一行日期，而规格说默认是六行。
/// 顶部那一行：**现在看的是哪个月**，以及翻月。
///
/// ## 为什么必须有它
///
/// 一度这里是个月/周切换，而**没有任何地方写着当前是几月**。
/// 用户报的原话：「看不出当前月份，左右滑动后就看不出现在几月份」——
/// 格子里只有日号，1 号到 30 号翻过去长得一模一样，
/// 划两下之后没有任何线索告诉你划到哪儿了。
///
/// 周视图那一档按用户要求去掉了（`calendarIsMonthProvider` 上有注释），
/// 空出来的位置正好给月份。
///
/// 左右箭头与横向滑动是同一件事的两条路：滑动更顺手，
/// 箭头对读屏用户可用 —— 与阶段那边「拖拽 + 箭头并存」同一条理由。
class _MonthHeader extends ConsumerWidget {
  const _MonthHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focused = ref.watch(viewSharedStateProvider).focusedDate;
    final shared = ref.read(viewSharedStateProvider.notifier);
    final text = Theme.of(context).textTheme;

    void shift(int months) {
      final m = focused.month + months;
      final year = focused.year + (m - 1) ~/ 12 - (m <= 0 ? 1 : 0);
      final month = ((m - 1) % 12 + 12) % 12 + 1;
      // 翻到 2 月时把 31 号夹成 28/29 —— 不夹的话 `PlanDate` 直接抛。
      final day = focused.day.clamp(1, PlanDate.daysInMonth(year, month));
      shared.focusDate(PlanDate(year, month, day));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.pageHorizontal,
        vertical: Spacing.xs,
      ),
      child: Row(
        children: [
          Text(
            '${focused.year} 年 ${focused.month} 月',
            key: CalendarPage.monthTitleKey,
            style: text.titleMedium,
          ),
          const Spacer(),
          IconButton(
            key: CalendarPage.prevMonthKey,
            icon: const Icon(Icons.chevron_left),
            tooltip: '上个月',
            onPressed: () => shift(-1),
          ),
          IconButton(
            key: CalendarPage.nextMonthKey,
            icon: const Icon(Icons.chevron_right),
            tooltip: '下个月',
            onPressed: () => shift(1),
          ),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends ConsumerWidget {
  const _WeekdayHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: CalendarMetrics.headerHeight,
      child: Row(
        children: [
          for (final w in ref.watch(calendarWeekdayOrderProvider))
            Expanded(
              child: Center(child: Text(w.label, style: text.bodySmall)),
            ),
        ],
      ),
    );
  }
}

/// 格子本体。**左右滑动跟手切月**（§3.2）。
///
/// ## 从「松手才切」改成跟手，改的是数据层
///
/// 上一版是 `onHorizontalDragEnd` + `AnimatedSwitcher`：手指在屏幕上
/// 拖的时候什么都不动，松手之后新的一页滑进来。规格写的是
/// 「左右滑动切月，**带惯性**」，而那一版**没有惯性可言** ——
/// 屏幕上没有任何东西跟着手指走。
///
/// 跟手要求相邻月份**同时画得出来**，而布局原本只按聚焦月算一份。
/// 所以先把 `calendarLayoutProvider` 拆成按月的 family
/// （`calendarLayoutForProvider`），这一层才有东西可翻。
/// —— 界面上的一句「跟手」，落在数据层是「一份变多份」。
///
/// ## 页号与月份的换算
///
/// `PageView` 要一个从 0 起的整数页号，而月份是无界的（两个方向都是）。
/// 取一个**固定锚点**（[_epoch]）当第 0 页，页号即「距锚点几个月」。
/// 锚点必须固定：拿「今天」当锚点的话，跨零点时所有页号会整体平移一格。
///
/// 页数取 [_pageCount]（锚点前后各约两百年）。**不是无限**：
/// `PageView` 支持无限只能靠 `itemCount: null` + 负页号的自定义
/// controller，而那要重写滚动物理。两百年的窗口对一个日程应用
/// 是刻意的上界，同 `ListHorizon.lookaheadDays` 那条。
class _Grid extends ConsumerStatefulWidget {
  const _Grid({required this.onEditTask, super.key});

  final OpenTask? onEditTask;

  /// 页号的原点。**任意但固定**的一个月。
  static const YearMonth epoch = YearMonth(2000, 1);

  /// 页号总数（约 ±200 年）。
  static const int pageCount = 4800;

  static int pageOf(YearMonth ym) => ym.differenceInMonths(epoch);

  static YearMonth monthOf(int page) => epoch.addMonths(page);

  @override
  ConsumerState<_Grid> createState() => _GridState();
}

class _GridState extends ConsumerState<_Grid> {
  PageController? _controller;

  /// 这一页是**滑动自己翻出来的**吗。
  ///
  /// `onPageChanged` 里改聚焦日会让 `build` 重跑，那时 controller 上的
  /// 页号已经是新的了 —— 若不认这一次，下面那段「外部改了聚焦日就
  /// 跟过去」会紧接着再 `animateToPage` 一次，动画打架。
  int? _settlingPage;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(calendarMonthProvider);
    final focused = ref.watch(viewSharedStateProvider).focusedDate;
    final shared = ref.read(viewSharedStateProvider.notifier);
    final reduced = reducedMotionOf(context, ref);
    final page = _Grid.pageOf(month);

    final controller = _controller ??= PageController(initialPage: page);

    // 聚焦日被**别处**改了（日历下方点了一天、从甘特切回来、
    // 顶部箭头），页面要跟过去。
    //
    // `hasClients` 之外还要判 `_settlingPage`：那是这一次滑动自己
    // 造成的变化，controller 已经在那一页上了，再动一次就是自己跟自己打架。
    if (controller.hasClients && _settlingPage != page) {
      final current = controller.page?.round();
      if (current != null && current != page) {
        // 隔一帧再动 —— build 里直接驱动动画会在同一帧里改布局。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !controller.hasClients) return;
          if (reduced) {
            controller.jumpToPage(page);
          } else {
            unawaited(
              controller.animateToPage(
                page,
                duration: Motion.slow,
                curve: Motion.slowCurve,
              ),
            );
          }
        });
      }
    }
    _settlingPage = null;

    return PageView.builder(
      controller: controller,
      itemCount: _Grid.pageCount,
      onPageChanged: (i) {
        final target = _Grid.monthOf(i);
        if (target == month) return;
        _settlingPage = i;
        shared.focusDate(_dayIn(target, focused.day));
      },
      itemBuilder: (context, i) =>
          _MonthGrid(month: _Grid.monthOf(i), onEditTask: widget.onEditTask),
    );
  }

  /// 翻到新的一个月时落在哪一天。
  ///
  /// 保持**同一个日号**，这样连着翻几个月不会把选中日越推越前。
  /// 日号不存在时（1/31 翻到 2 月）夹到当月最后一天 ——
  /// 而不是让 `PlanDate` 抛。
  PlanDate _dayIn(YearMonth ym, int day) => PlanDate(
    ym.year,
    ym.month,
    day.clamp(1, PlanDate.daysInMonth(ym.year, ym.month)),
  );
}

/// 一个月的六行格子。
///
/// **按月取自己的布局**（而不是接一个参数）：`PageView` 会预建左右两页，
/// 各取各的那一份，跟手时两边都是画好的。
class _MonthGrid extends ConsumerWidget {
  const _MonthGrid({required this.month, required this.onEditTask});

  final YearMonth month;
  final OpenTask? onEditTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(calendarLayoutForProvider(month));

    return Column(
      children: [
        for (final (i, week) in layout.weeks.indexed)
          Expanded(
            child: _WeekRow(
              week: week,
              bands: layout.bands[i],
              dots: layout.dots[i],
              weekIndex: i,
              onEditTask: onEditTask,
            ),
          ),
      ],
    );
  }
}

/// 一行七格 + 叠在上面的横条。
///
/// **横条画在这一层，不是画在每个格子里** —— 一条跨三天的横条是**一个**
/// `Positioned`，所以它不可能在格子边界上出现缝（§3.2「连续多日不断开」）。
class _WeekRow extends ConsumerWidget {
  const _WeekRow({
    required this.week,
    required this.bands,
    required this.dots,
    required this.weekIndex,
    required this.onEditTask,
  });

  final List<MonthCell> week;
  final WeekBands bands;
  final List<DayDots> dots;
  final int weekIndex;
  final OpenTask? onEditTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryByIdProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / daysPerWeek;

        return Stack(
          children: [
            Row(
              children: [
                for (final (i, cell) in week.indexed)
                  Expanded(
                    child: _DayCell(
                      key: CalendarPage.dayKey(cell.date),
                      cell: cell,
                      dots: dots[i],
                      categories: categories,
                    ),
                  ),
              ],
            ),
            for (final band in bands.bands)
              Positioned(
                key: CalendarPage.bandKey(band.row.id, weekIndex),
                top: CalendarMetrics.bandTop(band.lane),
                left: band.startIndex * cellWidth,
                width: band.spanDays * cellWidth,
                height: CalendarMetrics.bandHeight,
                child: _Band(
                  band: band,
                  color: _colorOf(band.row, categories),
                  onEditTask: onEditTask,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 一格。
class _DayCell extends ConsumerWidget {
  const _DayCell({
    required this.cell,
    required this.dots,
    required this.categories,
    super.key,
  });

  final MonthCell cell;
  final DayDots dots;
  final Map<String, Category> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final selected = ref.watch(viewSharedStateProvider).focusedDate;

    final isToday = cell.date == today;
    final isSelected = cell.date == selected;

    return Semantics(
      button: true,
      selected: isSelected,
      label: _semanticsLabel(cell.date, isToday, dots),
      excludeSemantics: true,
      child: InkWell(
        onTap: () =>
            ref.read(viewSharedStateProvider.notifier).focusDate(cell.date),
        child: Column(
          children: [
            Container(
              width: CalendarMetrics.dayCircle,
              height: CalendarMetrics.dayCircle,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // 今天：主色描边；选中：主色实心（§3.2）。
                // 两者可以同时成立，实心盖过描边。
                color: isSelected ? colors.brandFill : null,
                border: isToday && !isSelected
                    ? Border.all(color: colors.brandGraphic, width: 1.5)
                    : null,
              ),
              child: Text(
                '${cell.date.day}',
                style: text.bodySmall?.copyWith(
                  color: isSelected
                      ? colors.onBrand
                      // 补进来的上/下月尾巴画淡一些，但**仍然可读** ——
                      // 它们照样显示标记，点得动，不是装饰。
                      : (cell.inMonth ? null : colors.disabledText),
                ),
              ),
            ),
            const Spacer(),
            _Dots(dots: dots, date: cell.date, categories: categories),
            const SizedBox(height: Spacing.xxs),
          ],
        ),
      ),
    );
  }
}

/// 一格底部的色点与「+N」。
class _Dots extends StatelessWidget {
  const _Dots({
    required this.dots,
    required this.date,
    required this.categories,
  });

  final DayDots dots;
  final PlanDate date;
  final Map<String, Category> categories;

  @override
  Widget build(BuildContext context) {
    if (dots.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final row in dots.rows) ...[
          Container(
            width: CalendarMetrics.dotSize,
            height: CalendarMetrics.dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _colorOf(row, categories),
            ),
          ),
          const SizedBox(width: CalendarMetrics.dotGap),
        ],
        if (dots.overflow > 0)
          Text(
            '+${dots.overflow}',
            key: CalendarPage.overflowKey(date),
            style: text.bodySmall,
          ),
      ],
    );
  }
}

/// 一条横条。
class _Band extends StatelessWidget {
  const _Band({
    required this.band,
    required this.color,
    required this.onEditTask,
  });

  final DayBand band;
  final Color color;
  final OpenTask? onEditTask;

  @override
  Widget build(BuildContext context) {
    // 延续出去的那一头画成方的：圆角意味着「到这儿结束了」，
    // 而它其实还没完（§3.2）。
    final radius = Radius.circular(context.appShape.radius(Radii.xs));
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Semantics(
        button: true,
        label: band.row.title,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => _openRow(context, band.row, onEditTask),
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.28),
              borderRadius: BorderRadius.horizontal(
                left: band.continuesBefore ? Radius.zero : radius,
                right: band.continuesAfter ? Radius.zero : radius,
              ),
            ),
            // 格子只有一格宽，横条更窄 —— 用 `bodySmall` 时一条三四个字
            // 的标题就被省略号吃掉大半。用户报的原话：
            // 「任务 tag 文本太大了看不全」。
            // 换 `labelSmall` 并把内边距收到 2，同样宽度能多放两三个字。
            padding: const EdgeInsets.symmetric(horizontal: 2),
            alignment: Alignment.centerLeft,
            child: Text(
              band.row.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall,
            ),
          ),
        ),
      ),
    );
  }
}

/// 上下两半之间那条把手。
class _SplitHandle extends StatelessWidget {
  const _SplitHandle({required this.onDelta, required this.onDone, super.key});

  final ValueChanged<double> onDelta;
  final Future<void> Function() onDone;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onVerticalDragUpdate: (d) => onDelta(d.delta.dy),
      onVerticalDragEnd: (_) => onDone(),
      child: Semantics(
        label: '拖动调整日历与列表的高度',
        child: SizedBox(
          height: CalendarMetrics.handleHeight,
          child: Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 下半屏：选中那天的任务。
class _SelectedDayList extends ConsumerWidget {
  const _SelectedDayList({
    required this.onEditTask,
    required this.onCreateTask,
  });

  final OpenTask? onEditTask;
  final CreateTaskAt? onCreateTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(selectedDayRowsProvider);
    if (rows.isEmpty) {
      return EmptyState(
        key: CalendarPage.selectedEmptyKey,
        illustration: const EmptyIllustration(motif: EmptyMotif.calm),
        message: '这一天还空着。',
        actionLabel: onCreateTask == null ? null : '新建任务',
        // **带上选中的那一天**（FR-VIEW-07）。这句话说的就是「这一天」——
        // 点了却建出一条没有日期的任务，是自相矛盾。
        onAction: onCreateTask == null
            ? null
            : () => onCreateTask!(
                date: ref.read(viewSharedStateProvider).focusedDate,
              ),
      );
    }

    return ListView.separated(
      key: CalendarPage.selectedListKey,
      padding: const EdgeInsets.all(Spacing.pageHorizontal),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: Spacing.cardGap),
      itemBuilder: (context, i) {
        final row = rows[i];
        return TaskCard(
          key: ValueKey(row.id),
          data: cardDataOf(ref, row),
          onToggleDone: () => toggleDoneWithUndo(context, ref, row),
          onTap: () => _openRow(context, row, onEditTask),
        );
      },
    );
  }
}

Color _colorOf(TaskOccurrence row, Map<String, Category> categories) {
  final id = row.categoryId;
  final category = id == null ? null : categories[id];
  return category == null ? Uncategorized.color : Color(category.colorArgb);
}

String _semanticsLabel(PlanDate date, bool isToday, DayDots dots) {
  final count = dots.rows.length + dots.overflow;
  return '${date.month} 月 ${date.day} 日${isToday ? '，今天' : ''}'
      '${count == 0 ? '' : '，$count 件事'}';
}

void _openRow(BuildContext context, TaskOccurrence row, OpenTask? onEditTask) {
  if (row.isOccurrence) {
    showOccurrenceActions(context, row, onEditSeries: onEditTask);
  } else {
    onEditTask?.call(row.taskId);
  }
}

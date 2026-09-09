/// 竖向甘特视图（view-specs §4、FR-VIEW-04）。
///
/// ```
///        │ 学习    │ 工作    │ 生活    │   ← 泳道表头（吸顶）
/// ───────┼─────────┼─────────┼─────────┤
///  9/8 一│ ┃阶段1  │ ┃周报   │         │
///  9/9 二│ ┃       │ ┗━━━   │ ┃健身   │
///  9/10三│ ┃       │         │         │
/// ───────┴─────────┴─────────┴─────────┘
///    ↑ 时间轴（吸左）
/// ```
///
/// ## 条形层是**一次画完**的，不是每根条一个 Widget
///
/// §4.4 第 1 条。一屏两周、三条泳道、每条几根，Widget 数很快上百，
/// 而它们全都只是矩形。`CustomPainter` 一次 `drawRRect` 循环画完，
/// 滚动时不重建 Element 树。
///
/// 点击也由这一层接：`hitTest` 拿坐标反查是哪根条（[GanttPainter.barAt]），
/// 比给每根条套一个 `GestureDetector` 省得多。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app_providers.dart';
import '../../../../core/time/date_and_minute.dart';
import '../../../../core/time/plan_date.dart';
import '../../../../design/components/app_chip.dart';
import '../../../../design/components/empty_illustration.dart';
import '../../../../design/components/empty_state.dart';
import '../../../../design/theme/app_theme.dart';
import '../../../../design/tokens/dimensions.dart';
import '../../shared/application/create_task_at.dart';
import '../../shared/application/task_occurrence.dart';
import '../../shared/application/task_providers.dart';
import '../../shared/application/view_shared_state.dart';
import '../../task_list/presentation/occurrence_actions_sheet.dart';
import '../application/gantt_layout.dart';
import '../application/gantt_providers.dart';
import 'gantt_metrics.dart';
import 'gantt_painter.dart';

/// 打开某条任务（重复的先问「改哪一次」）。
typedef OpenTask = void Function(String taskId, {String? from});

class GanttView extends ConsumerStatefulWidget {
  const GanttView({this.onCreateTask, this.onEditTask, super.key});

  final OpenTask? onEditTask;
  final CreateTaskAt? onCreateTask;

  static const Key canvasKey = ValueKey('gantt-canvas');
  static const Key emptyKey = ValueKey('gantt-empty');
  static const Key errorKey = ValueKey('gantt-error');
  static const Key laneHeaderKey = ValueKey('gantt-lane-header');

  /// 时间粒度切换（FR-VIEW-04「可缩放时间粒度（日/周/月）」）。
  static Key granularityKey(TimeGranularity g) =>
      ValueKey('gantt-granularity-${g.name}');
  static const Key scrollKey = ValueKey('gantt-scroll');

  /// 某条泳道的表头。
  static Key laneKey(String? laneKey) => ValueKey('gantt-lane-$laneKey');

  @override
  ConsumerState<GanttView> createState() => _GanttViewState();
}

class _GanttViewState extends ConsumerState<GanttView> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(visibleTasksProvider).hasError) {
      return const EmptyState(
        key: GanttView.errorKey,
        illustration: EmptyIllustration(motif: EmptyMotif.offline),
        message: '没能读出这段时间的安排。\n重开一次试试？',
      );
    }

    final layout = ref.watch(ganttLayoutProvider);
    if (layout.isEmpty) {
      return EmptyState(
        key: GanttView.emptyKey,
        illustration: const EmptyIllustration(motif: EmptyMotif.span),
        message: '这段时间还没有安排。\n甘特图要有跨度才画得出来。',
        actionLabel: widget.onCreateTask == null ? null : '新建任务',
        // 甘特也是按日期锚定的视图，空态那句话说的是当前窗口 ——
        // 同时间轴与日历（FR-VIEW-07）。
        onAction: widget.onCreateTask == null
            ? null
            : () => widget.onCreateTask!(
                date: ref.read(viewSharedStateProvider).focusedDate,
              ),
      );
    }

    final today = ref.watch(todayProvider);
    final colors = context.appColors;
    final height = layout.totalMinutes * GanttMetrics.pixelsPerMinute;
    final onCreate = widget.onCreateTask;
    final granularity = ref.watch(viewSharedStateProvider).granularity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _GranularityToggle(),
        _LaneHeader(key: GanttView.laneHeaderKey, layout: layout),
        Expanded(
          child: SingleChildScrollView(
            key: GanttView.scrollKey,
            controller: _scroll,
            child: SizedBox(
              height: height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: GanttMetrics.dateGutter,
                    child: _DateGutter(layout: layout, today: today),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final painter = GanttPainter(
                          layout: layout,
                          width: constraints.maxWidth,
                          todayOffsetMinutes: _todayOffset(layout, today),
                          barColor: colors.brandGraphic,
                          gridColor: colors.borderSubtle,
                          doneColor: colors.doneFill,
                          nowColor: colors.brandGraphic,
                        );
                        return GestureDetector(
                          onTapUp: (details) {
                            final row = painter.barAt(details.localPosition);
                            if (row != null) _open(row);
                          },
                          // 长按空白＝在那一刻新建（FR-VIEW-07）。
                          //
                          // **落在条上时不新建**：长按已有任务的意图是
                          // 「对它做点什么」，不是「在它旁边加一条」。
                          // 时间轴上这条靠 `Stack` 的命中测试顺序实现
                          // （块在上、画布在下）；甘特整块画布是一个
                          // `CustomPaint`，没有那样的层次，所以在这里
                          // 显式问一次 `barAt`。
                          onLongPressStart: onCreate == null
                              ? null
                              : (details) {
                                  final at = details.localPosition;
                                  if (painter.barAt(at) != null) return;
                                  final when = painter.timeAt(
                                    at,
                                    tickMinutes: granularity.tickMinutes,
                                  );
                                  if (when == null) return;
                                  onCreate(
                                    date: when.date,
                                    minute: when.minute,
                                  );
                                },
                          child: CustomPaint(
                            key: GanttView.canvasKey,
                            painter: painter,
                            size: Size(constraints.maxWidth, height),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 今天距窗口起点多少分钟。不在窗口里就是 null（不画今日线）。
  int? _todayOffset(GanttLayout layout, PlanDate today) {
    final offset = today.differenceInDays(layout.windowStart) * minutesPerDay;
    if (offset < 0 || offset >= layout.totalMinutes) return null;
    return offset;
  }

  void _open(TaskOccurrence row) {
    if (row.isOccurrence) {
      showOccurrenceActions(context, row, onEditSeries: widget.onEditTask);
    } else {
      widget.onEditTask?.call(row.taskId);
    }
  }
}

/// 泳道表头（§4.2「吸顶」）。
class _LaneHeader extends StatelessWidget {
  const _LaneHeader({required this.layout, super.key});

  final GanttLayout layout;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;

    return Container(
      height: GanttMetrics.headerHeight,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.borderSubtle)),
      ),
      child: Row(
        children: [
          const SizedBox(width: GanttMetrics.dateGutter),
          for (final lane in layout.lanes)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
                child: Row(
                  key: GanttView.laneKey(lane.key),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 泳道色是**辅助**，名字才是信息载体（§8.1 那条原则）。
                    Container(
                      width: Spacing.sm,
                      height: Spacing.sm,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: lane.colorArgb == null
                            ? Uncategorized.color
                            : Color(lane.colorArgb!),
                      ),
                    ),
                    const SizedBox(width: Spacing.xs),
                    Flexible(
                      child: Text(
                        lane.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 左侧日期栏（§4.2「吸左」）。
class _DateGutter extends StatelessWidget {
  const _DateGutter({required this.layout, required this.today});

  final GanttLayout layout;
  final PlanDate today;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final days = layout.totalMinutes ~/ minutesPerDay;

    return Stack(
      children: [
        for (var i = 0; i < days; i++)
          Positioned(
            top: i * minutesPerDay * GanttMetrics.pixelsPerMinute,
            left: 0,
            right: 0,
            height: minutesPerDay * GanttMetrics.pixelsPerMinute,
            child: _DayLabel(
              date: layout.windowStart.addDays(i),
              isToday: layout.windowStart.addDays(i) == today,
              style: text.bodySmall,
              todayColor: colors.brandText,
            ),
          ),
      ],
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel({
    required this.date,
    required this.isToday,
    required this.style,
    required this.todayColor,
  });

  final PlanDate date;
  final bool isToday;
  final TextStyle? style;
  final Color todayColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: Spacing.xs, top: Spacing.xxs),
    child: Text(
      '${date.month}/${date.day}',
      textAlign: TextAlign.right,
      style: isToday
          ? style?.copyWith(color: todayColor, fontWeight: FontWeight.w600)
          : style,
    ),
  );
}

/// 时间粒度（FR-VIEW-04 验收里那句「可缩放时间粒度（日/周/月）」）。
///
/// ## 补它之前，「日」是一扇单向门
///
/// `TimeGranularity` 有三档，`ganttWindowDays` 三档都算了（14/35/90 天），
/// 甘特的窗口也确实跟着它变。而**界面上唯一能设它的地方是日历那个
/// 月/周切换**，只有两档。
///
/// `day` 是默认值，所以它不是死代码 —— 它是**回不去的起点**：
/// 用户在日历上点一下「月」或「周」，甘特的窗口就再也回不到 14 天。
/// 这与 M2 那条「选了『到某天为止』却没地方选日期」是一对镜像：
/// 那条是走进去出不来，这条是出去了回不来。
///
/// 而 FR-VIEW-04 的验收原话是「**可缩放**时间粒度（日/周/月）」——
/// 一个只能单向走的切换不叫可缩放。
///
/// 又是「模型有旋钮、界面够不着」，这次漏的是**验收栏里的一款** ——
/// 可追溯性门禁看不见这种，它只知道 FR-VIEW-04 被某条用例点过名。
///
/// ## 与日历共用同一份状态（§0.1）
///
/// 甘特自己存一份的话，从日历切过来两边对不上。
/// 日历只有月/周两档 —— 它的「周」那一档在 `day` 下也是选中的，
/// 因为日历本来就没有「日视图」（view-specs §3.3 只定义了月与周）。
class _GranularityToggle extends ConsumerWidget {
  const _GranularityToggle();

  static const _labels = {
    TimeGranularity.day: '日',
    TimeGranularity.week: '周',
    TimeGranularity.month: '月',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(viewSharedStateProvider).granularity;
    final shared = ref.read(viewSharedStateProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.pageHorizontal,
        Spacing.sm,
        Spacing.pageHorizontal,
        0,
      ),
      child: Row(
        children: [
          for (final g in TimeGranularity.values) ...[
            SelectableChip(
              key: GanttView.granularityKey(g),
              label: _labels[g]!,
              selected: current == g,
              onSelected: (_) => shared.setGranularity(g),
            ),
            const SizedBox(width: Spacing.sm),
          ],
        ],
      ),
    );
  }
}

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
import '../../../../design/components/empty_state.dart';
import '../../../../design/theme/app_theme.dart';
import '../../../../design/tokens/dimensions.dart';
import '../../shared/application/task_occurrence.dart';
import '../../shared/application/task_providers.dart';
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
  final VoidCallback? onCreateTask;

  static const Key canvasKey = ValueKey('gantt-canvas');
  static const Key emptyKey = ValueKey('gantt-empty');
  static const Key errorKey = ValueKey('gantt-error');
  static const Key laneHeaderKey = ValueKey('gantt-lane-header');
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
        illustration: EmptyIllustration(icon: Icons.cloud_off_outlined),
        message: '没能读出这段时间的安排。\n重开一次试试？',
      );
    }

    final layout = ref.watch(ganttLayoutProvider);
    if (layout.isEmpty) {
      return EmptyState(
        key: GanttView.emptyKey,
        illustration: const EmptyIllustration(icon: Icons.view_timeline),
        message: '这段时间还没有安排。\n甘特图要有跨度才画得出来。',
        actionLabel: widget.onCreateTask == null ? null : '新建任务',
        onAction: widget.onCreateTask,
      );
    }

    final today = ref.watch(todayProvider);
    final colors = context.appColors;
    final height = layout.totalMinutes * GanttMetrics.pixelsPerMinute;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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

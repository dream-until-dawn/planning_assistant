/// 时间轴视图（view-specs §1、FR-VIEW-01）。
///
/// ```
/// │  随时                                    │ ← 无时间任务区
/// │   ○ 买牛奶            ○ 回邮件            │
/// ├─────────────────────────────────────────┤
/// │ 08:00 ─────────────────────────────────  │
/// │       ┌──────────────┐                   │
/// │ 09:00 │ ▎晨会         │                  │ ← 高度∝时长
/// │       └──────────────┘                   │
/// │ ⋯                          ▬▬ 当前时刻线   │
/// ```
///
/// 「一天怎么排」全在 `timeline_blocks.dart`（纯函数），
/// 「谁跟谁并排」在 `overlap_layout.dart`（与甘特共用）——
/// 这里只负责把算好的分钟数换成像素。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/components/empty_state.dart';
import '../../../../design/components/task_card.dart';
import '../../../../design/theme/app_theme.dart';
import '../../../../design/tokens/dimensions.dart';
import '../../../../domain/value_objects/task_status.dart';
import '../../../settings/application/registry.dart';
import '../../../settings/application/settings_providers.dart';
import '../../shared/application/category_providers.dart';
import '../../shared/application/create_task_at.dart';
import '../../shared/application/overlap_layout.dart';
import '../../shared/application/task_occurrence.dart';
import '../../shared/application/task_providers.dart';
import '../../shared/presentation/occurrence_card_data.dart';
import '../../task_list/application/task_list_actions.dart';
import '../../task_list/presentation/occurrence_actions_sheet.dart';
import '../application/timeline_blocks.dart';
import '../application/timeline_providers.dart';
import 'timeline_metrics.dart';

/// 打开某条任务（重复的先问「改哪一次」）。
typedef OpenTask = void Function(String taskId, {String? from});

class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({this.onCreateTask, this.onEditTask, super.key});

  /// 打开某条任务的编辑页。**由组合根接上路由** —— 视图自己不认识路由表。
  final OpenTask? onEditTask;

  /// 空态里那个行动按钮。为 null 时按钮不出现。
  final CreateTaskAt? onCreateTask;

  static const Key scrollKey = ValueKey('timeline-scroll');
  static const Key emptyKey = ValueKey('timeline-empty');
  static const Key errorKey = ValueKey('timeline-error');

  /// 「随时」区。没有无时刻任务时整块不出现。
  static const Key anytimeKey = ValueKey('timeline-anytime');

  /// 空白处长按新建（FR-VIEW-07）。
  static const Key canvasKey = ValueKey('timeline-canvas');

  /// 当前时刻线。**只有「今天」才有**。
  static const Key nowLineKey = ValueKey('timeline-now-line');

  /// 某一块。参数是**行**的 id（`taskId#occurrenceKey`），不是 taskId ——
  /// 同一条规则展开出的几行会共用一个 taskId。
  static Key blockKey(String rowId) => ValueKey('timeline-block-$rowId');

  /// 某个刻度的标签。
  static Key tickKey(int minute) => ValueKey('timeline-tick-$minute');

  /// 折叠指示器（§1.2 的「+N」），按簇的起点标识。
  static Key overflowKey(int clusterStart) =>
      ValueKey('timeline-overflow-$clusterStart');

  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  final _scroll = ScrollController();

  /// 首次定位只做一次（§1.2「首次进入定位」）。
  ///
  /// 每次数据变化都重定位的话，用户滚到下午之后随便勾掉一件事，
  /// 视图就会跳回上午 —— 那是「自动」，不是「帮忙」。
  bool _positioned = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// 首帧之后滚到该看的地方。
  ///
  /// 今天 → 当前时刻**前一小时**；别的日子 → 当日第一件事。
  /// 两者都没有（空荡荡的一天）就停在 00:00，不硬滚。
  void _positionOnce(int tickMinutes, TimelineDay day, int? nowMinute) {
    if (_positioned) return;
    final target = nowMinute != null
        ? nowMinute - TimelineMetrics.leadInMinutes
        : (day.blocks.isEmpty ? null : day.blocks.first.startMinute);
    if (target == null) return;
    _positioned = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final offset = target * TimelineMetrics.pixelsPerMinute(tickMinutes);
      _scroll.jumpTo(offset.clamp(0, _scroll.position.maxScrollExtent));
    });
  }

  @override
  Widget build(BuildContext context) {
    // 读库失败要**显式一屏**：空画布与「任务全没了」长得一模一样。
    if (ref.watch(visibleTasksProvider).hasError) {
      return const EmptyState(
        key: TimelinePage.errorKey,
        illustration: EmptyIllustration(icon: Icons.cloud_off_outlined),
        message: '没能读出这一天的安排。\n重开一次试试？',
      );
    }

    final tickMinutes = ref.setting(timelineTickMinutes);
    final day = ref.watch(timelineDayProvider);
    // 心跳还没到时当作「没有现在」—— **不是当作 0 点**，
    // 那会在凌晨画一条假线。
    final nowMinute = switch (ref.watch(currentMinuteProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };

    if (day.isEmpty) {
      return EmptyState(
        key: TimelinePage.emptyKey,
        illustration: const EmptyIllustration(icon: Icons.wb_sunny_outlined),
        message: '这一天还没有安排，\n要加点什么吗？',
        actionLabel: widget.onCreateTask == null ? null : '新建任务',
        // **带上正看着的那一天**（FR-VIEW-07）。空态这一条尤其要紧：
        // 用户翻到一个空日子、看见「这一天还没有安排」、点了新建 ——
        // 他说的就是这一天，不带的话建出来的任务落在「随时」区。
        onAction: widget.onCreateTask == null
            ? null
            : () => widget.onCreateTask!(date: ref.read(timelineDateProvider)),
      );
    }

    _positionOnce(tickMinutes, day, nowMinute);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (day.allDay.isNotEmpty)
          _AnytimeSection(
            key: TimelinePage.anytimeKey,
            rows: day.allDay,
            onEditTask: widget.onEditTask,
          ),
        Expanded(
          child: SingleChildScrollView(
            key: TimelinePage.scrollKey,
            controller: _scroll,
            child: SizedBox(
              height: TimelineMetrics.dayHeight(tickMinutes),
              child: _DayCanvas(
                tickMinutes: tickMinutes,
                nowMinute: nowMinute,
                onEditTask: widget.onEditTask,
                onCreateTask: widget.onCreateTask,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 一天的画布：刻度 + 块 + 当前时刻线。
class _DayCanvas extends ConsumerWidget {
  const _DayCanvas({
    required this.tickMinutes,
    required this.nowMinute,
    required this.onEditTask,
    required this.onCreateTask,
  });

  final int tickMinutes;
  final int? nowMinute;
  final OpenTask? onEditTask;
  final CreateTaskAt? onCreateTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clusters = ref.watch(timelineLayoutProvider);
    final scale = TimelineMetrics.pixelsPerMinute(tickMinutes);

    return LayoutBuilder(
      builder: (context, constraints) {
        final laneWidth =
            constraints.maxWidth -
            TimelineMetrics.gutterWidth -
            Spacing.pageHorizontal;

        return Stack(
          children: [
            // **压在最底下，这一层的顺序是行为的一部分。**
            //
            // `Stack` 的命中测试按**从上到下**走，命中第一个就停 ——
            // 于是手指落在一个块上时，这一层根本轮不到被问。
            // 长按已有任务是「打开它」，长按空白才是「在这儿新建」。
            //
            // 把它挪到 children 末尾（最上层）就全反了：整块画布
            // 先被它吃掉，块连点都点不着。变异演练里 V-04 验的就是这个。
            //
            // 一度以为要靠给块补一个 `onLongPress` 来「抢」手势，
            // 那是多余的 —— 变异证明拿掉它行为不变（命中测试压根到不了下面）。
            if (onCreateTask != null)
              Positioned.fill(
                child: GestureDetector(
                  key: TimelinePage.canvasKey,
                  behavior: HitTestBehavior.translucent,
                  onLongPressStart: (details) => onCreateTask!(
                    date: ref.read(timelineDateProvider),
                    minute: TimelineMetrics.minuteAt(
                      details.localPosition.dy,
                      tickMinutes,
                    ),
                  ),
                ),
              ),
            _Ruler(tickMinutes: tickMinutes),
            for (final cluster in clusters) ...[
              // 有折叠时先把「+N」那一格的宽度**留出来**，
              // 再分列。不留的话它会盖在第三列的标题上 ——
              // 而那正是「+N」本该避免的事。
              for (final slot in cluster.slots)
                _slotPosition(
                  scale: scale,
                  laneWidth:
                      laneWidth -
                      (cluster.hidden.isEmpty ? 0 : TimelineMetrics.pillWidth),
                  slot: slot,
                  child: _BlockCard(
                    key: TimelinePage.blockKey(slot.item.row.id),
                    block: slot.item,
                    onEditTask: onEditTask,
                  ),
                ),
              if (cluster.hidden.isNotEmpty)
                Positioned(
                  key: TimelinePage.overflowKey(cluster.start),
                  top: cluster.start * scale,
                  right: Spacing.pageHorizontal,
                  width: TimelineMetrics.pillWidth - TimelineMetrics.columnGap,
                  height: TimelineMetrics.minBlockHeight,
                  child: _OverflowPill(
                    hidden: cluster.hidden,
                    onEditTask: onEditTask,
                  ),
                ),
            ],
            if (nowMinute != null)
              _NowLine(
                key: TimelinePage.nowLineKey,
                minute: nowMinute!,
                scale: scale,
              ),
          ],
        );
      },
    );
  }

  /// 把一格换算成 `Positioned`。
  ///
  /// 高度取 `max(时长, 最小块高)`：三十分钟的事在「一小时一格」下
  /// 只有 24 像素高，点不着（§1.2 最小块高 36）。没有时长的那些
  /// 高度是 0，全靠这个下限 —— 时长该是多少不由界面替用户假设。
  Widget _slotPosition({
    required double scale,
    required double laneWidth,
    required OverlapSlot<TimelineBlock> slot,
    required Widget child,
  }) {
    final block = slot.item;
    final columnWidth = laneWidth / slot.columnCount;
    return Positioned(
      top: block.startMinute * scale,
      left: TimelineMetrics.gutterWidth + slot.column * columnWidth,
      width: columnWidth - TimelineMetrics.columnGap,
      height: (block.durationMinutes * scale).clamp(
        TimelineMetrics.minBlockHeight,
        double.infinity,
      ),
      child: child,
    );
  }
}

/// 左侧刻度与横线。
class _Ruler extends StatelessWidget {
  const _Ruler({required this.tickMinutes});

  final int tickMinutes;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final scale = TimelineMetrics.pixelsPerMinute(tickMinutes);

    return Stack(
      children: [
        for (var m = 0; m < minutesPerDay; m += tickMinutes)
          Positioned(
            top: m * scale,
            left: 0,
            right: 0,
            child: Row(
              children: [
                SizedBox(
                  width: TimelineMetrics.gutterWidth,
                  child: Text(
                    hhmm(m),
                    key: TimelinePage.tickKey(m),
                    style: text.bodySmall,
                  ),
                ),
                Expanded(
                  child: ColoredBox(
                    color: colors.borderSubtle,
                    child: const SizedBox(height: 1),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 当前时刻线（§1.2，只在「今天」出现，每分钟更新）。
class _NowLine extends StatelessWidget {
  const _NowLine({required this.minute, required this.scale, super.key});

  final int minute;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final color = context.appColors.brandGraphic;

    return Positioned(
      // 线本身 2 像素高，往上挪 1 让它**居中压在**那一分钟上，
      // 而不是从那一分钟往下长。
      top: minute * scale - 1,
      left: TimelineMetrics.gutterWidth - Spacing.sm,
      right: 0,
      child: Semantics(
        label: '现在 ${hhmm(minute)}',
        child: Row(
          children: [
            // 左端一个实心圆点：在一堆灰色刻度线里，光靠颜色区分
            // 对色觉障碍的用户是无效的（NFR-A11Y-01），形状才是。
            Container(
              width: Spacing.sm,
              height: Spacing.sm,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Expanded(
              child: ColoredBox(color: color, child: const SizedBox(height: 2)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「随时」区（§1.2「无时间任务归入顶部『随时』区，不占时间轴」）。
///
/// 用的是与列表同一张卡片 —— 同一条任务在两个视图里长得一样，
/// 是 FR-VIEW-05「四视图共享数据源」在观感上的落点。
class _AnytimeSection extends ConsumerWidget {
  const _AnytimeSection({
    required this.rows,
    required this.onEditTask,
    super.key,
  });

  final List<TaskOccurrence> rows;
  final OpenTask? onEditTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      padding: const EdgeInsets.fromLTRB(
        Spacing.pageHorizontal,
        Spacing.sm,
        Spacing.pageHorizontal,
        Spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('随时', style: text.titleMedium),
          const SizedBox(height: Spacing.sm),
          // 「随时」的条数没有上限（一天可以攒二十件「哪天做都行」的事），
          // 所以这一区自己能滚，不把时间轴挤没。
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: rows.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: Spacing.cardGap),
              itemBuilder: (context, i) {
                final row = rows[i];
                return TaskCard(
                  key: ValueKey(row.id),
                  data: cardDataOf(ref, row),
                  onToggleDone: () => ref.read(toggleTaskDoneProvider)(row),
                  onTap: () => _openRow(context, row, onEditTask),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 时间轴上的一块。
class _BlockCard extends ConsumerWidget {
  const _BlockCard({required this.block, required this.onEditTask, super.key});

  final TimelineBlock block;
  final OpenTask? onEditTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = block.row;
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final category = row.categoryId == null
        ? null
        : ref.watch(categoryByIdProvider)[row.categoryId];
    final accent = category == null
        ? colors.brandGraphic
        : Color(category.colorArgb);
    final done = row.status == TaskStatus.done;
    final radius = BorderRadius.circular(context.appShape.radius(Radii.sm));

    return Semantics(
      button: true,
      label: '${row.title}，${_rangeLabel(block)}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: () => _openRow(context, row, onEditTask),
          child: Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: done ? 0.08 : 0.16),
              borderRadius: radius,
              // 跨天的那一头不画圆角也不画边：方头 + 半透明渐隐
              // 说的是「这一截还没完」（§1.2 跨天那一行）。
              border: Border(left: BorderSide(color: accent, width: 3)),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: Spacing.xxs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (block.continuesBefore)
                  Text('↑ 承接昨天', style: text.bodySmall),
                Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge?.copyWith(
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (block.continuesAfter)
                  Text('↓ 延续到明天', style: text.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 「+N」：这一簇里没排下的那些（§1.2「N>3 时改为『+N』堆叠，点击展开」）。
class _OverflowPill extends StatelessWidget {
  const _OverflowPill({required this.hidden, required this.onEditTask});

  final List<TimelineBlock> hidden;
  final OpenTask? onEditTask;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: '还有 ${hidden.length} 件，展开看',
      excludeSemantics: true,
      child: Material(
        color: colors.sunken,
        borderRadius: BorderRadius.circular(context.appShape.radius(Radii.sm)),
        child: InkWell(
          borderRadius: BorderRadius.circular(
            context.appShape.radius(Radii.sm),
          ),
          onTap: () => _showHidden(context, hidden, onEditTask),
          child: Center(
            child: Text('+${hidden.length}', style: text.labelLarge),
          ),
        ),
      ),
    );
  }
}

/// 展开被折叠的那些。
///
/// **必须有这条路**：只画一个「+3」而点不开的话，那三件事在这一天
/// 就是不可达的 —— 与 M2 里那条「到某天为止」的死路是同一种毛病。
void _showHidden(
  BuildContext context,
  List<TimelineBlock> hidden,
  OpenTask? onEditTask,
) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final block in hidden)
            ListTile(
              title: Text(block.row.title),
              subtitle: Text(_rangeLabel(block)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openRow(context, block.row, onEditTask);
              },
            ),
        ],
      ),
    ),
  );
}

/// 点一行：不重复的直接开编辑，重复的先问「改哪一次」。
void _openRow(BuildContext context, TaskOccurrence row, OpenTask? onEditTask) {
  if (row.isOccurrence) {
    showOccurrenceActions(context, row, onEditSeries: onEditTask);
  } else {
    onEditTask?.call(row.taskId);
  }
}

/// `540` → `09:00`。
String hhmm(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:'
    '${(minute % 60).toString().padLeft(2, '0')}';

String _rangeLabel(TimelineBlock block) => block.durationMinutes == 0
    ? hhmm(block.startMinute)
    : '${hhmm(block.startMinute)} 到 ${hhmm(block.endMinute)}';

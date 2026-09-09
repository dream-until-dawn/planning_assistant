/// 时间轴视图（view-specs §1、FR-VIEW-01）。
///
/// ```
/// │ 9月9日 今天                              │ ← 日期分隔
/// │ 09:00 ●┃ ┌────────────────────────────┐ │
/// │        ┃ │ ▎晨会              09:00   │ │
/// │        ┃ └────────────────────────────┘ │
/// │ 10:30 ●┃ ┌────────────────────────────┐ │
/// │        ┃ │ ▎写方案 · 收集材料           │ │ ← 阶段各占一行
/// │        ┃ └────────────────────────────┘ │
/// │ ─────── 现在 14:32 ───────────────────── │
/// │ 9月10日 明天                             │
/// │ 全天  ●┃ ┌────────────────────────────┐ │
/// ```
///
/// **时间是跳的**：只在有东西的时刻打点，空白时段不占高度。
/// 这是它与日历/甘特的分工 —— 那两个回答「这段时间有多满」，
/// 这个回答「接下来依次是什么」。
///
/// 「哪些次该出现」在 `expandForAgenda`，「怎么排成一列」在
/// `agenda_entries.dart`（都是纯函数）。这里只负责把它们摆成像素。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app_providers.dart';
import '../../../../core/time/date_and_minute.dart';
import '../../../../core/time/plan_date.dart';
import '../../../../design/components/empty_state.dart';
import '../../../../design/components/task_card.dart';
import '../../../../design/components/undo_snackbar.dart';
import '../../../../design/theme/app_theme.dart';
import '../../../../design/tokens/dimensions.dart';
import '../../../../domain/value_objects/task_status.dart';
import '../../shared/application/create_task_at.dart';
import '../../shared/application/task_occurrence.dart';
import '../../shared/application/task_providers.dart';
import '../../shared/presentation/occurrence_card_data.dart';
import '../../task_list/application/task_list_actions.dart';
import '../../task_list/presentation/occurrence_actions_sheet.dart';
import '../application/agenda_entries.dart';
import '../application/timeline_providers.dart';
import 'agenda_metrics.dart';

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

  /// 「现在」那条分隔线。只在**它两边都有东西**时出现（见 `_buildLines`）。
  static const Key nowKey = ValueKey('timeline-now');

  /// 一行。参数是 [AgendaEntry.id]：任务行是 `taskId#occurrenceKey`，
  /// 阶段行还要再缀上 `#stageId` —— 同一次的几个阶段各是独立的一行，
  /// 共用一个 key 的话 Flutter 的列表复用会认错行。
  static Key entryKey(String entryId) => ValueKey('timeline-entry-$entryId');

  /// 某一天的分隔。
  static Key dateKey(PlanDate date) => ValueKey('timeline-date-$date');

  /// 阶段行上的完成钮。参数同 [entryKey]。
  static Key stageDoneKey(String entryId) =>
      ValueKey('timeline-stage-done-$entryId');

  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  final _scroll = ScrollController();

  /// 已经为哪个聚焦日滚过了。
  ///
  /// 记「哪一天」而不是一个 bool：日历上选了 9/20 再切回来要滚到 9/20
  /// （FR-VIEW-06 的验收原话），而**同一天不重复滚** ——
  /// 每次数据变化都重定位的话，用户滚到下周随便勾掉一件事，
  /// 视图就跳回今天，那是「自动」，不是「帮忙」。
  PlanDate? _scrolledTo;

  /// 每一天的分隔在树上的位置，用来 `ensureVisible`。
  final _dateKeys = <PlanDate, GlobalKey>{};

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// 滚到聚焦的那一天（FR-VIEW-06：「日历选中 9/20 → 切时间轴 → 显示 9/20」）。
  ///
  /// 那一天没有东西时滚到**它之后最近的一天** —— 空手而归比滚错了更难解释。
  ///
  /// ## 为什么要重试
  ///
  /// 列表是懒建的：目标那天还没进过视口时，它的 `GlobalKey` 上没有
  /// context，`ensureVisible` 无从下手。所以先按**行序比例**跳过去
  /// （`maxScrollExtent` 对未建出的部分是估的，所以跳不准），
  /// 让目标进入构建范围，下一帧再对齐。
  ///
  /// 上限 [_maxScrollAttempts] 次：估算收敛得很快，而**没有上限的
  /// 「下一帧再来一次」是一个不会停的循环** —— 目标要是被筛掉了，
  /// 它每一帧都会重排一次。
  void _scrollToFocused(List<_Line> lines) {
    final target = ref.watch(timelineDateProvider);
    if (_scrolledTo == target) return;
    // 这一批行里根本没有那一天及之后 → 记下来，别每帧重试。
    final index = lines.indexWhere(
      (l) => l is _DateLine && !l.date.isBefore(target),
    );
    _scrolledTo = target;
    if (index < 0) return;

    var attempts = 0;
    void tryAlign() {
      if (!mounted || !_scroll.hasClients) return;
      final context =
          _dateKeys[(lines[index] as _DateLine).date]?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0,
          duration: Duration.zero,
        );
        return;
      }
      if (++attempts > _maxScrollAttempts) return;
      final ratio = index / lines.length;
      _scroll.jumpTo(
        (ratio * _scroll.position.maxScrollExtent).clamp(
          0,
          _scroll.position.maxScrollExtent,
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => tryAlign());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => tryAlign());
  }

  static const int _maxScrollAttempts = 3;

  @override
  Widget build(BuildContext context) {
    // 读库失败要**显式一屏**：空列表与「任务全没了」长得一模一样。
    if (ref.watch(visibleTasksProvider).hasError) {
      return const EmptyState(
        key: TimelinePage.errorKey,
        illustration: EmptyIllustration(icon: Icons.cloud_off_outlined),
        message: '没能读出你的安排。\n重开一次试试？',
      );
    }

    final entries = ref.watch(agendaEntriesProvider);
    if (entries.isEmpty) {
      return EmptyState(
        key: TimelinePage.emptyKey,
        illustration: const EmptyIllustration(icon: Icons.wb_sunny_outlined),
        message: '接下来没有排着的事，\n要加点什么吗？',
        actionLabel: widget.onCreateTask == null ? null : '新建任务',
        // **不带日期。** 议程横跨多天，用户在这儿点新建没有指向任何一天，
        // 一律盖上「今天」的话「随时做」那一类任务就再也建不出来了
        // （同 `ViewKind.anchorsToDay` 里列表那条的理由）。
        onAction: widget.onCreateTask == null
            ? null
            : () => widget.onCreateTask!(),
      );
    }

    // 心跳还没到就先不画「现在」—— **不是画在 0 点**，那是条假线。
    final now = switch (ref.watch(nowProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final lines = _buildLines(entries, now);
    _scrollToFocused(lines);

    final today = ref.watch(todayProvider);
    return ListView.builder(
      key: TimelinePage.scrollKey,
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: Spacing.giant),
      itemCount: lines.length,
      itemBuilder: (context, i) => switch (lines[i]) {
        final _DateLine line => _DateHeader(
          key: _dateKeys.putIfAbsent(line.date, GlobalKey.new),
          date: line.date,
          today: today,
        ),
        _NowLine(:final at) => _NowDivider(key: TimelinePage.nowKey, at: at),
        final _EntryLine line => _EntryRow(
          entry: line.entry,
          timeLabel: line.timeLabel,
          onEditTask: widget.onEditTask,
        ),
      },
    );
  }
}

/// 摊平成 `ListView` 要的那一列：日期分隔 + 行 +（可能有的）「现在」。
///
/// ## 时刻只在**变了**的时候写
///
/// 三条都排在 09:00 的话，把「09:00」写三遍是噪音 —— 时间栏要读起来
/// 像一串跳跃的刻度，不是每行一个标签。
///
/// ## 「现在」只在它两边都有东西时出现
///
/// 全是未来的事时，一条画在最上面的「现在」什么也没说明；
/// 全是逾期的事时同理。它的信息量来自**它把哪些分到了上面**。
List<_Line> _buildLines(List<AgendaEntry> entries, DateAndMinute? now) {
  // 第一条排在 now 之后的行。0 或 length 都表示「不夹在中间」。
  final split = now == null ? -1 : entries.indexWhere((e) => e.at.isAfter(now));
  final showNow = now != null && split > 0;

  final lines = <_Line>[];
  PlanDate? date;
  String? lastTime;

  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    // 「现在」排在下一条之前，也排在下一天的分隔之前 ——
    // 跨到明天的话，那条线属于今天的末尾。
    if (showNow && i == split) lines.add(_NowLine(now));

    if (entry.at.date != date) {
      date = entry.at.date;
      lastTime = null;
      lines.add(_DateLine(date));
    }
    final time = _timeOf(entry);
    lines.add(_EntryLine(entry, timeLabel: time == lastTime ? null : time));
    lastTime = time;
  }

  if (showNow && split == entries.length) lines.add(_NowLine(now));
  return lines;
}

/// 时间栏上写什么。全天的写「全天」，不写它那个占位的 00:00。
String _timeOf(AgendaEntry entry) =>
    entry.isAllDay ? '全天' : hhmm(entry.at.minute.value);

sealed class _Line {
  const _Line();
}

final class _DateLine extends _Line {
  const _DateLine(this.date);
  final PlanDate date;
}

final class _EntryLine extends _Line {
  const _EntryLine(this.entry, {required this.timeLabel});
  final AgendaEntry entry;

  /// null = 与上一行同一时刻，时间栏留空。
  final String? timeLabel;
}

final class _NowLine extends _Line {
  const _NowLine(this.at);
  final DateAndMinute at;
}

/// 一天的分隔。
class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date, required this.today, super.key});

  final PlanDate date;
  final PlanDate today;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final overdue = date.isBefore(today);

    return Padding(
      key: TimelinePage.dateKey(date),
      padding: const EdgeInsets.fromLTRB(
        Spacing.pageHorizontal,
        Spacing.xl,
        Spacing.pageHorizontal,
        Spacing.sm,
      ),
      child: Row(
        children: [
          Text(
            '${date.month}月${date.day}日',
            style: text.titleMedium?.copyWith(
              // 逾期那几天用 overdue.text，**不加感叹号也不铺红底**
              // （design-system §2.4 的低压力原则）。
              color: overdue ? colors.overdueText : null,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          // 「今天/明天/周几」是文字，不是颜色 —— 颜色不单独承载信息
          // （NFR-A11Y-01）。
          Text(_relativeLabel(date, today), style: text.bodySmall),
        ],
      ),
    );
  }
}

/// 「今天」「明天」「周三」「9 天前」。
String _relativeLabel(PlanDate date, PlanDate today) {
  final days = date.differenceInDays(today);
  return switch (days) {
    0 => '今天',
    1 => '明天',
    2 => '后天',
    -1 => '昨天',
    < 0 => '${-days} 天前',
    < 7 => _weekday(date),
    _ => '$days 天后',
  };
}

const List<String> _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

String _weekday(PlanDate date) => '周${_weekdays[date.weekday - 1]}';

/// 「现在」那条线。
class _NowDivider extends StatelessWidget {
  const _NowDivider({required this.at, super.key});

  final DateAndMinute at;

  @override
  Widget build(BuildContext context) {
    final color = context.appColors.brandGraphic;
    final text = Theme.of(context).textTheme;

    return Semantics(
      label: '现在 ${hhmm(at.minute.value)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.pageHorizontal,
          vertical: Spacing.sm,
        ),
        child: Row(
          children: [
            SizedBox(
              width: AgendaMetrics.gutterWidth,
              child: Text(
                hhmm(at.minute.value),
                textAlign: TextAlign.right,
                style: text.bodySmall?.copyWith(color: color),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            // 左端一个实心圆点：在一列灰线里，光靠颜色区分对色觉障碍
            // 的用户是无效的（NFR-A11Y-01），形状才是。
            Container(
              width: AgendaMetrics.dotSize,
              height: AgendaMetrics.dotSize,
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

/// 一行：左边时刻，中间那条竖轴，右边卡片。
class _EntryRow extends ConsumerWidget {
  const _EntryRow({
    required this.entry,
    required this.timeLabel,
    required this.onEditTask,
  });

  final AgendaEntry entry;
  final String? timeLabel;
  final OpenTask? onEditTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    // 圆点跟着时间文字走，字放大时一起往下 —— 拍一个固定偏移的话，
    // 2.8 倍字号下它会停在文字上方一大截。
    final dotTop = MediaQuery.textScalerOf(context).scale(Spacing.xs);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.pageHorizontal,
        Spacing.xs,
        Spacing.pageHorizontal,
        Spacing.xs,
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: AgendaMetrics.gutterWidth,
                child: timeLabel == null
                    ? null
                    : Text(
                        timeLabel!,
                        key: TimelinePage.entryKey('time-${entry.id}'),
                        textAlign: TextAlign.right,
                        style: text.bodySmall,
                      ),
              ),
              const SizedBox(width: AgendaMetrics.railWidth),
              Expanded(
                child: switch (entry) {
                  final TaskEntry e => _TaskLine(
                    key: TimelinePage.entryKey(e.id),
                    entry: e,
                    onEditTask: onEditTask,
                  ),
                  final StageEntry e => _StageLine(
                    key: TimelinePage.entryKey(e.id),
                    entry: e,
                    onEditTask: onEditTask,
                  ),
                },
              ),
            ],
          ),
          // 竖轴压在行的背面，跨满整行高 —— 一行接一行就连成一条线。
          // 用 `Positioned` 而不是 `IntrinsicHeight` 拉伸：卡片里有
          // `LayoutBuilder`，而 IntrinsicHeight 撑不了带 LayoutBuilder 的子树
          // （「LayoutBuilder does not support returning intrinsic dimensions」，
          // 见 `task_card.dart` 里那段）。
          Positioned(
            left: AgendaMetrics.railCenter - 1,
            top: 0,
            bottom: 0,
            width: 2,
            child: ColoredBox(color: colors.borderSubtle),
          ),
          // 时刻变了才打一个点 —— 点标的是「跳到了新的时刻」。
          if (timeLabel != null)
            Positioned(
              left: AgendaMetrics.railCenter - AgendaMetrics.dotSize / 2,
              top: dotTop,
              child: Container(
                width: AgendaMetrics.dotSize,
                height: AgendaMetrics.dotSize,
                decoration: BoxDecoration(
                  color: colors.brandGraphic,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 任务行：与列表同一张卡片。
///
/// 同一条任务在两个视图里长得一样，是 FR-VIEW-05「四视图共享数据源」
/// 在观感上的落点。
class _TaskLine extends ConsumerWidget {
  const _TaskLine({required this.entry, required this.onEditTask, super.key});

  final TaskEntry entry;
  final OpenTask? onEditTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = entry.row;
    return TaskCard(
      // 时刻已经写在左边那栏里了，卡片上再写一遍就是同一个时刻
      // 在一行里出现两次。
      data: cardDataOf(ref, row, withTime: false),
      onToggleDone: () => _toggleDone(context, ref, row),
      onTap: () => _openRow(context, row, onEditTask),
    );
  }
}

/// 阶段行。
///
/// 用户看过上一版之后的第一条意见就是「阶段是独立的卡片」。
/// 卡片比任务那张**矮一档**：它是任务的细分，视觉上不该压过任务本身。
class _StageLine extends ConsumerWidget {
  const _StageLine({required this.entry, required this.onEditTask, super.key});

  final StageEntry entry;
  final OpenTask? onEditTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final done = entry.status == TaskStatus.done;
    final radius = BorderRadius.circular(context.appShape.radius(Radii.md));
    // 阶段自己的颜色优先（甘特按它分段着色，两处必须是同一个答案）；
    // 没有就跟着任务的分类色。
    final accent = entry.stage.colorArgb != null
        ? Color(entry.stage.colorArgb!)
        : cardDataOf(ref, entry.row, withTime: false).categoryColor;

    return Semantics(
      button: true,
      label: '${entry.row.title} 的阶段：${entry.title}${done ? '，已完成' : ''}',
      excludeSemantics: true,
      child: Material(
        color: colors.sunken,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () => _openRow(context, entry.row, onEditTask),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.xs,
            ),
            child: Row(
              children: [
                // 完成钮直接摆在行上 —— 阶段的完成钮此前只在
                // 「改哪一次」那张底部弹层里，隔着两步（FR-TASK-07）。
                //
                // 用的是任务卡片那一个，不是 Material 的 `Checkbox`：
                // 同一屏上方框与圆钮表示同一件事，真机截图上一眼就
                // 能看出不对。
                DoneButton(
                  key: TimelinePage.stageDoneKey(entry.id),
                  isDone: done,
                  onPressed: () => ref
                      .read(occurrenceActionsProvider)
                      .setStageDone(entry.row, entry.stage.id, !done),
                ),
                Container(
                  width: TaskCard.stripeWidth,
                  height: Spacing.lg,
                  color: accent,
                ),
                const SizedBox(width: Spacing.iconToText),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelLarge?.copyWith(
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      // **归属写成文字。** 缩进和颜色都说不清它属于谁，
                      // 而阶段与任务之间可能隔着别的任务的行。
                      Text(
                        entry.row.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 勾完成，并给撤销。
///
/// **议程里勾掉的行会当场消失**（这个视图只装未完成的），所以撤销
/// 不是锦上添花：没有它的话，误触之后那一行去哪了都不知道。
/// 列表那边的完成钮一度就漏了这一条。
Future<void> _toggleDone(
  BuildContext context,
  WidgetRef ref,
  TaskOccurrence row,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final done = row.status == TaskStatus.done;
  final undo = await ref.read(toggleTaskDoneProvider)(row);
  showUndoSnackBar(
    messenger,
    done ? '已标为未完成：${row.title}' : '已完成：${row.title}',
    onUndo: undo,
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

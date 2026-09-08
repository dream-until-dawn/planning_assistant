/// 时间轴上一天的排布（view-specs §1）。
///
/// **纯函数**：给一天和一批行，出来的块是确定的。混进 widget 之后，
/// 「跨天任务在当天从几点画到几点」就得靠截图去看了。
library;

import 'package:meta/meta.dart';

import '../../../../core/time/plan_date.dart';
import '../../shared/application/task_occurrence.dart';

/// 一天有多少分钟。
const int minutesPerDay = 1440;

/// 时间轴上的一块。
///
/// [startMinute] / [endMinute] 都**已经裁到当天之内**（0..1440）。
@immutable
final class TimelineBlock {
  const TimelineBlock({
    required this.row,
    required this.startMinute,
    required this.endMinute,
    required this.continuesBefore,
    required this.continuesAfter,
  });

  final TaskOccurrence row;
  final int startMinute;
  final int endMinute;

  /// 这一块是从**前一天**延续过来的 —— 上边缘要渐隐，
  /// 而不是画成一条「从 00:00 开始」的实边（§1.2 跨天那一行）。
  final bool continuesBefore;

  /// 同理，延续到**后一天**。
  final bool continuesAfter;

  int get durationMinutes => endMinute - startMinute;
}

/// 一天的时间轴内容。
@immutable
final class TimelineDay {
  const TimelineDay({required this.blocks, required this.allDay});

  /// 有具体时刻的，按时间摆在轴上。
  final List<TimelineBlock> blocks;

  /// 没有时刻的，归「随时」区，不占时间轴（§1.2）。
  ///
  /// 全天任务、以及只有日期没有时刻的任务都在这里。
  final List<TaskOccurrence> allDay;

  bool get isEmpty => blocks.isEmpty && allDay.isEmpty;
}

/// 把 [rows]（已经是这个窗口里的发生）摆到 [date] 这一天上。
///
/// [rows] 里可能有别的日子的东西 —— 跨天任务尤其：它的开始在昨天，
/// 却要在今天画出下半截。所以这里按**覆盖区间**筛，不按开始日期筛。
TimelineDay timelineDayFor(List<TaskOccurrence> rows, PlanDate date) {
  final blocks = <TimelineBlock>[];
  final allDay = <TaskOccurrence>[];

  for (final row in rows) {
    final start = row.planDate;
    if (start == null) continue;

    // 没有时刻 → 「随时」。只看它在不在这一天上。
    final startMinute = row.startMinute;
    if (startMinute == null) {
      if (_coversDay(row, date)) allDay.add(row);
      continue;
    }

    // 用「从开始算起的第几分钟」统一处理跨天，省得到处比日期。
    final startOffset =
        start.differenceInDays(date) * minutesPerDay + startMinute.value;
    final endOffset = _endOffset(row, date, startOffset);

    // 判「在不在这一天上」时，零长的那些也得**占住它开始的那一分钟**。
    // 否则 00:00 的待办 endOffset 正好是 0，会跟「昨天 23:00 干到今天 00:00」
    // 一样被当成前一天的事，整块从当天消失 —— 与 overlap_layout 里
    // 把零长段撑成一个单位是同一个理由。
    final coverEnd = endOffset > startOffset ? endOffset : startOffset + 1;

    // 完全落在这一天之外。
    if (coverEnd <= 0 || startOffset >= minutesPerDay) continue;

    final clampedStart = startOffset < 0 ? 0 : startOffset;
    final clampedEnd = endOffset > minutesPerDay ? minutesPerDay : endOffset;
    blocks.add(
      TimelineBlock(
        row: row,
        startMinute: clampedStart,
        // 裁过之后 end 仍可能落在 start 前（零长块本来就是），
        // 收到 start 上，让 durationMinutes 不出现负数。
        endMinute: clampedEnd < clampedStart ? clampedStart : clampedEnd,
        continuesBefore: startOffset < 0,
        continuesAfter: endOffset > minutesPerDay,
      ),
    );
  }

  blocks.sort((a, b) {
    final byStart = a.startMinute.compareTo(b.startMinute);
    // 同一时刻开始时按 id 兜底，让顺序稳定 —— 否则同一天两次进入
    // 可能得到不同的左右排布。
    return byStart != 0 ? byStart : a.row.id.compareTo(b.row.id);
  });
  // 「随时」区没有时刻可排，按 id —— 真实 id 是 UUID v7，字典序 ≈ 创建序，
  // 与列表里的 `byId` 兜底是同一套（task_grouping）。
  allDay.sort((a, b) => a.id.compareTo(b.id));

  return TimelineDay(blocks: blocks, allDay: allDay);
}

/// 结束在「从 [date] 零点算起的第几分钟」。
///
/// 三种形态，对应领域里允许的三种数据（data-model §3.1）：
///
/// * 连结束日期都没有 → **与开始同一刻**（零长）。不替用户假设时长；
///   块高由界面按「最小块高」兜底（§1.2），那是显示的事，不是数据的事。
/// * 有结束日期、没有结束时刻 → **到那一天结束**。编辑器允许只选结束日
///   不选结束时刻（「从今天 14:00 忙到后天」），而 `Task` 的
///   `_endsBeforeItStarts` 也是按「那天的末尾」读这种形态的 ——
///   这里若按零长画，同一份数据在校验器和时间轴上就是两个意思，
///   而屏幕上只会表现为「跨天任务莫名其妙不跨天」。
/// * 两者都有 → 就是它。
int _endOffset(TaskOccurrence row, PlanDate date, int startOffset) {
  final endDate = row.endDate;
  if (endDate == null) return startOffset;
  final dayStart = endDate.differenceInDays(date) * minutesPerDay;
  // 末尾取 1440 而不是校验器里的 1439：那边比的是先后，差一分钟无妨；
  // 这边是画出来的长度，少一分钟就是当天末尾留一道缝。
  final endMinute = row.endMinute;
  return dayStart + (endMinute?.value ?? minutesPerDay);
}

/// 这一行有没有覆盖到 [date]（含跨天）。
bool _coversDay(TaskOccurrence row, PlanDate date) {
  final start = row.planDate!;
  final end = row.endDate ?? start;
  return !date.isBefore(start) && !date.isAfter(end);
}

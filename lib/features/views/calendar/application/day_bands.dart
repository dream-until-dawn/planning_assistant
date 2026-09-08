/// 月历格子里的横条与色点（view-specs §3.1、§3.2）。
///
/// ## 横条为什么要按「周」来算，而不是按「天」
///
/// §3.2 要求跨天任务「以横条贯穿，**连续多日不断开**」。按天算的话，
/// 每一格各自决定自己那一截画在第几层，于是同一条任务在周三是第一层、
/// 周四变成第二层 —— 视觉上就是断了。
///
/// 所以层号（[DayBand.lane]）必须**在一整行里统一分配**。一条任务跨到
/// 下一行时重新分层是可以的：那本来就是换行，读者不会指望它接上。
///
/// ## 分层用的是时间轴那套
///
/// 「谁跟谁不能占同一层」与「谁跟谁不能占同一列」是同一个问题，
/// 只是单位从分钟换成天。所以直接用 [layoutOverlaps]，
/// 时间轴、竖向甘特、月历三处共用一套（§1.2、§4.5、这里）。
library;

import 'package:meta/meta.dart';

import '../../../../core/time/plan_date.dart';
import '../../shared/application/overlap_layout.dart';
import '../../shared/application/task_occurrence.dart';

/// 一格里最多显示几个色点，超出的收成「+N」（§3.1）。
const int maxDotsPerCell = 3;

/// 一行里最多叠几条横条。
///
/// 超出的**不画**，由那一格的「+N」把它算进去 —— 一行叠五六条横条时
/// 格子里就只剩横条了，日期数字和色点全被挤没。
const int maxBandsPerWeek = 3;

/// 一行里的一条横条。
@immutable
final class DayBand {
  const DayBand({
    required this.row,
    required this.startIndex,
    required this.endIndex,
    required this.lane,
    required this.continuesBefore,
    required this.continuesAfter,
  });

  final TaskOccurrence row;

  /// 在这一行里从第几格开始、到第几格结束（**两端都含**，0..6）。
  final int startIndex;
  final int endIndex;

  /// 第几层，从 0 起。同一行内不重叠的横条会复用同一层。
  final int lane;

  /// 任务在**这一行之前**就开始了 —— 左端画成平的，不封口。
  final bool continuesBefore;

  /// 同理，延续到下一行。
  final bool continuesAfter;

  int get spanDays => endIndex - startIndex + 1;
}

/// 一行的横条排布结果。
@immutable
final class WeekBands {
  const WeekBands({required this.bands, required this.hiddenByDay});

  final List<DayBand> bands;

  /// 每一格里因为层数超限而没画出来的条数（下标 0..6）。
  ///
  /// **按天记，不是按条记**：一条被挤掉的横条跨三天，那三格各欠一个，
  /// 而第四格不欠。记成「这一行少了 1 条」的话，「+N」会在整行都显示同一个数。
  final List<int> hiddenByDay;

  int get laneCount => bands.isEmpty
      ? 0
      : bands.map((b) => b.lane).reduce((a, b) => a > b ? a : b) + 1;
}

/// 一行进横条还是进色点。
///
/// §3.2 的原话是「**全天**/跨天任务在格子顶部以横条贯穿」——
/// 两个条件，不是一个：只占一天的全天任务（纪念日、生日）也走横条，
/// 因为它没有时刻，用色点表示的话它会和「下午三点那件事」排在一起，
/// 而两者在日历上是不同的东西。
///
/// **这个判据只有这一处**。`weekBands` 与 `dayDots` 各写一遍的话，
/// 迟早有一天某类任务两处都进（一条三天的任务在三格里各留一个点，
/// 看起来像三件事）或者两处都不进（凭空消失）。
bool showsAsBand(TaskOccurrence row) {
  final start = row.planDate;
  if (start == null) return false;
  if (row.isAllDay) return true;
  final end = row.endDate;
  return end != null && end.isAfter(start);
}

/// 把覆盖 `[weekStart, weekStart+6]` 这一行的行摆成横条。
///
/// [rows] 可以是整个月窗口的行，这里自己筛（见 [showsAsBand]）。
WeekBands weekBands(List<TaskOccurrence> rows, PlanDate weekStart) {
  final weekEnd = weekStart.addDays(6);

  final inputs = <OverlapInput<_Segment>>[];
  for (final row in rows) {
    final start = row.planDate;
    if (start == null) continue;
    if (!showsAsBand(row)) continue;
    final end = row.endDate ?? start;
    if (end.isBefore(weekStart) || start.isAfter(weekEnd)) continue;

    final startIndex = start.isBefore(weekStart)
        ? 0
        : start.differenceInDays(weekStart);
    final endIndex = end.isAfter(weekEnd) ? 6 : end.differenceInDays(weekStart);
    inputs.add(
      OverlapInput(
        item: _Segment(
          row: row,
          startIndex: startIndex,
          endIndex: endIndex,
          continuesBefore: start.isBefore(weekStart),
          continuesAfter: end.isAfter(weekEnd),
        ),
        start: startIndex,
        // `layoutOverlaps` 是**左闭右开**的，而这里的 endIndex 含末端 ——
        // 加一转过去。不加的话，周一到周三与周三到周五会被判成不重叠，
        // 两条挤在同一层、在周三那格叠住。
        end: endIndex + 1,
      ),
    );
  }

  final bands = <DayBand>[];
  final hiddenByDay = List<int>.filled(7, 0);

  for (final cluster in layoutOverlaps(inputs, maxColumns: maxBandsPerWeek)) {
    for (final slot in cluster.slots) {
      final s = slot.item;
      bands.add(
        DayBand(
          row: s.row,
          startIndex: s.startIndex,
          endIndex: s.endIndex,
          lane: slot.column,
          continuesBefore: s.continuesBefore,
          continuesAfter: s.continuesAfter,
        ),
      );
    }
    for (final s in cluster.hidden) {
      for (var i = s.startIndex; i <= s.endIndex; i++) {
        hiddenByDay[i]++;
      }
    }
  }

  bands.sort((a, b) {
    final byLane = a.lane.compareTo(b.lane);
    return byLane != 0 ? byLane : a.startIndex.compareTo(b.startIndex);
  });
  return WeekBands(bands: bands, hiddenByDay: hiddenByDay);
}

/// 某一天格子里的色点（§3.1、§3.2）。
///
/// 收的是**横条不要的那些**（见 [showsAsBand]）——
/// 也就是有具体时刻、且只占这一天的事。
@immutable
final class DayDots {
  const DayDots({required this.rows, required this.overflow});

  /// 最多 [maxDotsPerCell] 行，按开始时刻排。
  final List<TaskOccurrence> rows;

  /// 没画出来的还有几个（含被挤掉的横条）。
  final int overflow;

  bool get isEmpty => rows.isEmpty && overflow == 0;
}

/// 排 [date] 这一格的色点。[hiddenBands] 是这一格欠着的横条数。
DayDots dayDots(
  List<TaskOccurrence> rows,
  PlanDate date, {
  int hiddenBands = 0,
}) {
  final onDay = <TaskOccurrence>[];
  for (final row in rows) {
    if (showsAsBand(row)) continue;
    if (row.planDate != date) continue;
    onDay.add(row);
  }

  onDay.sort((a, b) {
    // 没有时刻的排在有时刻的后面 —— 「几点」是更强的顺序信息。
    final am = a.startMinute?.value;
    final bm = b.startMinute?.value;
    if (am != bm) {
      if (am == null) return 1;
      if (bm == null) return -1;
      return am.compareTo(bm);
    }
    return a.id.compareTo(b.id);
  });

  final shown = onDay.take(maxDotsPerCell).toList();
  return DayDots(
    rows: shown,
    overflow: onDay.length - shown.length + hiddenBands,
  );
}

@immutable
final class _Segment {
  const _Segment({
    required this.row,
    required this.startIndex,
    required this.endIndex,
    required this.continuesBefore,
    required this.continuesAfter,
  });

  final TaskOccurrence row;
  final int startIndex;
  final int endIndex;
  final bool continuesBefore;
  final bool continuesAfter;
}

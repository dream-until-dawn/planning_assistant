/// 甘特的条形层（view-specs §4.4 第 1 条）。
///
/// **一次画完，不是每根条一个 Widget。** 一屏两周、三条泳道、每条几根，
/// Widget 数很快上百，而它们全都只是矩形 —— 一次 `drawRRect` 循环画完，
/// 滚动时不重建 Element 树。
///
/// ## 命中测试也在这一层
///
/// [barAt] 拿坐标反查是哪根条。给每根条套 `GestureDetector` 的话，
/// 上面那句「不建 Widget」就白说了。
///
/// ## 坐标怎么来的
///
/// 布局给的是「距窗口起点多少分钟」（`gantt_layout.dart` 里那段）。
/// 这里只做两个乘法：分钟 × [GanttMetrics.pixelsPerMinute] 得 y，
/// 泳道序号与列号得 x。**换粒度只改那个乘数，不重排布局** —— §4.4 第 4 条。
library;

import 'package:flutter/material.dart';

import '../../shared/application/task_occurrence.dart';
import '../application/gantt_layout.dart';
import 'gantt_metrics.dart';

class GanttPainter extends CustomPainter {
  GanttPainter({
    required this.layout,
    required this.width,
    required this.todayOffsetMinutes,
    required this.barColor,
    required this.gridColor,
    required this.doneColor,
    required this.nowColor,
  });

  final GanttLayout layout;
  final double width;

  /// 今天距窗口起点多少分钟。不在窗口里时为 null —— **那时不画今日线**，
  /// 在一段不含今天的时间里画一条「今天」是假的。
  final int? todayOffsetMinutes;

  final Color barColor;
  final Color gridColor;
  final Color doneColor;
  final Color nowColor;

  /// 上一次画出来的矩形，供 [barAt] 反查。
  ///
  /// **画的时候顺手记下来**，不另算一遍 —— 另算的话「点中的」与
  /// 「看见的」会各自演化，而那种错只在边缘几个像素上出现，
  /// 表现是「有时候点不中」。
  final List<({Rect rect, TaskOccurrence row})> _hitBoxes = [];

  double get _laneWidth =>
      layout.lanes.isEmpty ? width : width / layout.lanes.length;

  @override
  void paint(Canvas canvas, Size size) {
    _hitBoxes.clear();
    _paintGrid(canvas, size);

    for (final (laneIndex, lane) in layout.lanes.indexed) {
      final laneLeft = laneIndex * _laneWidth;
      for (final bar in lane.bars) {
        _paintBar(canvas, bar, laneLeft);
      }
    }

    _paintTodayLine(canvas, size);
  }

  /// 日界线 + 泳道分隔线。
  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    final days = layout.totalMinutes ~/ 1440;
    for (var i = 0; i <= days; i++) {
      final y = i * GanttMetrics.dayHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (var i = 1; i < layout.lanes.length; i++) {
      final x = i * _laneWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  void _paintBar(Canvas canvas, GanttBar bar, double laneLeft) {
    final columnWidth = _laneWidth / bar.columnCount;
    final left = laneLeft + bar.column * columnWidth + GanttMetrics.barGap;
    final right =
        laneLeft + (bar.column + 1) * columnWidth - GanttMetrics.barGap;

    final top = bar.startMinute * GanttMetrics.pixelsPerMinute;
    final rawBottom = bar.endMinute * GanttMetrics.pixelsPerMinute;
    // 零长的条也要看得见、点得着。
    final bottom = rawBottom - top < GanttMetrics.minBarLength
        ? top + GanttMetrics.minBarLength
        : rawBottom;

    final rect = Rect.fromLTRB(left, top, right, bottom);
    _hitBoxes.add((rect: rect, row: bar.row));

    // 被窗口截断的那一头画成方的：圆角意味着「到这儿结束了」，
    // 而它其实还没完（G-07）。
    const radius = Radius.circular(GanttMetrics.barGap * 2);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: bar.continuesBefore ? Radius.zero : radius,
        topRight: bar.continuesBefore ? Radius.zero : radius,
        bottomLeft: bar.continuesAfter ? Radius.zero : radius,
        bottomRight: bar.continuesAfter ? Radius.zero : radius,
      ),
      Paint()..color = barColor.withValues(alpha: 0.20),
    );

    for (final segment in bar.segments) {
      _paintSegment(canvas, segment, rect);
    }
  }

  /// 阶段分段（§4.3、G-04）。
  ///
  /// 已完成填实，未完成半透明 —— **外加一条左边线**：只靠透明度区分
  /// 的话，灰度屏与色觉障碍下两者几乎一样（§8.1 那条原则）。
  void _paintSegment(Canvas canvas, GanttSegment segment, Rect bar) {
    final top = segment.startMinute * GanttMetrics.pixelsPerMinute;
    final bottom =
        segment.endMinute * GanttMetrics.pixelsPerMinute -
        GanttMetrics.segmentGap;
    if (bottom <= top) return;

    final rect = Rect.fromLTRB(bar.left, top, bar.right, bottom);
    final color = segment.stage.colorArgb == null
        ? (segment.done ? doneColor : barColor)
        : Color(segment.stage.colorArgb!);

    canvas.drawRect(
      rect,
      Paint()..color = color.withValues(alpha: segment.done ? 0.85 : 0.35),
    );
    if (!segment.done) {
      canvas.drawRect(
        Rect.fromLTRB(rect.left, rect.top, rect.left + 2, rect.bottom),
        Paint()..color = color,
      );
    }
  }

  /// 今日线：横贯所有泳道（§4.3）。
  void _paintTodayLine(Canvas canvas, Size size) {
    final offset = todayOffsetMinutes;
    if (offset == null) return;
    final y = offset * GanttMetrics.pixelsPerMinute;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = nowColor
        ..strokeWidth = 2,
    );
  }

  /// 反查坐标落在哪根条上。没有就是 null。
  ///
  /// **从后往前找**：后画的在上面，点中的该是看得见的那一根。
  TaskOccurrence? barAt(Offset point) {
    for (final box in _hitBoxes.reversed) {
      if (box.rect.contains(point)) return box.row;
    }
    return null;
  }

  @override
  bool shouldRepaint(GanttPainter old) =>
      old.layout != layout ||
      old.width != width ||
      old.todayOffsetMinutes != todayOffsetMinutes ||
      old.barColor != barColor;
}

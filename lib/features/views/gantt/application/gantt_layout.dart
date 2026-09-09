/// 竖向甘特的布局（view-specs §4）。
///
/// ## 位置一律用「距窗口起点多少分钟」
///
/// 不是「第几天」也不是像素。理由是 §4.4 第 4 条：**缩放时不重算布局，
/// 只做变换**。粒度（日/周/月）如果进到布局里，每缩放一次就要重排一次
/// 泳道与列 —— 而那正是甘特最容易掉帧的地方。
///
/// 分钟是各档粒度的公约数，换算成像素是渲染层一个乘法的事。
///
/// ## 分列复用时间轴那套
///
/// 「同泳道同时段多任务时泳道内再分列（最多 3 列，超出折叠）」（§4.3）
/// 与时间轴的「同时段 N 个任务等宽并排」是同一个问题。
/// 所以用同一个 [layoutOverlaps]，时间轴、月历、甘特三处共用。
library;

import 'package:meta/meta.dart';

import '../../../../core/time/date_and_minute.dart';
import '../../../../core/time/plan_date.dart';
import '../../../../domain/entities/category.dart';
import '../../../../domain/entities/stage.dart';
import '../../../../domain/value_objects/task_status.dart';
import '../../shared/application/overlap_layout.dart';
import '../../shared/application/task_occurrence.dart';

/// 泳道按什么分（配置项 `view.ganttLaneBy`）。
///
/// 规格里还列了 `tag`，**没做** —— 模型里根本没有标签这个东西
/// （`domain/entities/` 下没有 tag）。摆一个选了没反应的选项，
/// 比没有这个选项更糟（同 settings 注册表那条原则）。
enum GanttLaneBy {
  category('category', '按分类'),
  task('task', '按任务');

  const GanttLaneBy(this.storageKey, this.label);

  final String storageKey;
  final String label;

  static GanttLaneBy fromStorageKey(String? key) {
    for (final v in values) {
      if (v.storageKey == key) return v;
    }
    return GanttLaneBy.category;
  }
}

/// 一根条里的一段（一个阶段）。
@immutable
final class GanttSegment {
  const GanttSegment({
    required this.stage,
    required this.startMinute,
    required this.endMinute,
    required this.done,
  });

  final Stage stage;

  /// 距**窗口起点**多少分钟。与 [GanttBar] 同一个原点，
  /// 免得渲染时还要做一次相对换算。
  final int startMinute;
  final int endMinute;

  /// 已完成的段落填实，未完成半透明 + 虚线边（§4.3「进度」）。
  final bool done;

  int get lengthMinutes => endMinute - startMinute;
}

/// 一根条。
@immutable
final class GanttBar {
  const GanttBar({
    required this.row,
    required this.startMinute,
    required this.endMinute,
    required this.column,
    required this.columnCount,
    required this.continuesBefore,
    required this.continuesAfter,
    required this.segments,
    required this.progress,
  });

  final TaskOccurrence row;

  /// 距窗口起点多少分钟，**已经裁到窗口之内**。
  final int startMinute;
  final int endMinute;

  final int column;
  final int columnCount;

  /// 窗口边界处被截断（G-07）：条延伸到边界、边缘渐隐，
  /// **不画成「结束」** —— 画成结束的话，一件跨到下个月的事
  /// 看起来就是这个月底做完了。
  final bool continuesBefore;
  final bool continuesAfter;

  /// 阶段分段。**只有排了时间的阶段才有段**（见 [progress]）。
  final List<GanttSegment> segments;

  /// 已完成的阶段占几成。没有阶段时为 null。
  ///
  /// ## 为什么需要它，而不是把没排时间的阶段也切成段
  ///
  /// 编辑器**默认不给阶段排时间** —— 用户加三个阶段、写个名字就存了。
  /// 那时 [segments] 是空的，于是「完成了第二阶段」在甘特上完全看不见。
  ///
  /// 一个诱人的做法是把条按阶段数**均分**。但那是在编造数据：
  /// 它等于告诉用户「第一阶段在前三分之一结束」，而用户从没这么说过。
  /// 与「不替用户假设时长」（§1.2）是同一条原则。
  ///
  /// 所以换一个诚实的表达：**进度**。它说的是「三件里做完了一件」，
  /// 不说「什么时候做的」。排了时间的阶段照常有段，两者不冲突。
  final double? progress;

  int get lengthMinutes => endMinute - startMinute;
}

/// 一条泳道。
@immutable
final class GanttLane {
  const GanttLane({
    required this.key,
    required this.title,
    required this.colorArgb,
    required this.bars,
    required this.hidden,
  });

  /// 分组键。分类泳道是 categoryId（未分类为 null），任务泳道是 taskId。
  final String? key;
  final String title;

  /// 泳道色。未分类与「按任务」时为 null，由渲染层取默认。
  final int? colorArgb;

  final List<GanttBar> bars;

  /// 超出列数上限被折起来的那些（§4.3）。
  final List<TaskOccurrence> hidden;

  int get columnCount => bars.isEmpty
      ? 1
      : bars.map((b) => b.columnCount).reduce((a, b) => a > b ? a : b);
}

/// 排好的一屏甘特。
@immutable
final class GanttLayout {
  const GanttLayout({
    required this.lanes,
    required this.windowStart,
    required this.totalMinutes,
  });

  final List<GanttLane> lanes;

  /// 窗口起点（所有 `startMinute` 的原点）。
  final PlanDate windowStart;

  /// 窗口一共多少分钟。
  final int totalMinutes;

  bool get isEmpty => lanes.every((l) => l.bars.isEmpty && l.hidden.isEmpty);
}

/// 一条泳道里最多几列（§4.3、G-03）。
const int maxColumnsPerLane = 3;

/// 排甘特。
///
/// [rows] 是窗口内的发生（已筛选）。**没有日期的不进来** ——
/// 「甘特的本质是时间跨度」（§4.3 最后一行），一件没有日期的事
/// 在时间轴上没有位置。
GanttLayout ganttLayout({
  required List<TaskOccurrence> rows,
  required PlanDate windowStart,
  required PlanDate windowEnd,
  required GanttLaneBy laneBy,
  List<Category> categories = const [],
}) {
  final total = (windowEnd.differenceInDays(windowStart) + 1) * minutesPerDay;

  // 先按泳道分桶。
  final buckets = <String?, List<TaskOccurrence>>{};
  for (final row in rows) {
    if (row.planDate == null) continue;
    final key = laneBy == GanttLaneBy.category ? row.categoryId : row.taskId;
    (buckets[key] ??= []).add(row);
  }

  final lanes = <GanttLane>[];
  for (final key in _orderedKeys(buckets.keys, laneBy, categories, buckets)) {
    final bucket = buckets[key]!;
    final inputs = <OverlapInput<TaskOccurrence>>[];
    for (final row in bucket) {
      final placed = _place(row, windowStart, total);
      if (placed == null) continue;
      inputs.add(OverlapInput(item: row, start: placed.$1, end: placed.$2));
    }

    final bars = <GanttBar>[];
    final hidden = <TaskOccurrence>[];
    for (final cluster in layoutOverlaps(
      inputs,
      maxColumns: maxColumnsPerLane,
    )) {
      for (final slot in cluster.slots) {
        final placed = _place(slot.item, windowStart, total)!;
        bars.add(
          GanttBar(
            row: slot.item,
            startMinute: placed.$1 < 0 ? 0 : placed.$1,
            endMinute: placed.$2 > total ? total : placed.$2,
            column: slot.column,
            columnCount: slot.columnCount,
            continuesBefore: placed.$1 < 0,
            continuesAfter: placed.$2 > total,
            segments: _segmentsOf(slot.item, placed.$1, total),
            progress: _progressOf(slot.item),
          ),
        );
      }
      hidden.addAll(cluster.hidden);
    }

    bars.sort((a, b) {
      final byStart = a.startMinute.compareTo(b.startMinute);
      return byStart != 0 ? byStart : a.row.id.compareTo(b.row.id);
    });

    // **空泳道不产出。** 一条任务的开始落在窗口之后时，它进了分桶
    // 却排不出条 —— 留着的话屏幕上多一列只有表头的空泳道，
    // 而那一列什么也没说明。
    if (bars.isEmpty && hidden.isEmpty) continue;

    lanes.add(
      GanttLane(
        key: key,
        title: _titleOf(key, laneBy, categories, bucket),
        colorArgb: laneBy == GanttLaneBy.category
            ? _categoryOf(key, categories)?.colorArgb
            : null,
        bars: bars,
        hidden: hidden,
      ),
    );
  }

  return GanttLayout(
    lanes: lanes,
    windowStart: windowStart,
    totalMinutes: total,
  );
}

/// 这一行在窗口里的 `[起, 止)`（分钟，**未裁**）。完全在窗口外时为 null。
///
/// 用**有效跨度**（data-model §4.7）—— 末阶段可能排到 `endDate` 之后，
/// 而四个视图必须给出同一个跨度（G-05）。
(int, int)? _place(TaskOccurrence row, PlanDate windowStart, int total) {
  final span = row.span;
  if (span == null) return null;

  final start = _minutesFrom(windowStart, span.start);
  // 零长的也要占住一分钟，否则它在窗口边界上会被判成「不在窗口里」，
  // 而且分列时谁也不跟谁重叠 —— 与 overlap_layout 里撑成一个单位同理。
  final end = _minutesFrom(windowStart, span.end);
  final effectiveEnd = end > start ? end : start + 1;

  if (effectiveEnd <= 0 || start >= total) return null;
  return (start, effectiveEnd);
}

int _minutesFrom(PlanDate origin, DateAndMinute at) =>
    at.date.differenceInDays(origin) * minutesPerDay + at.minute.value;

/// 阶段分段（G-04）。
/// 偏移是**相对这一次的开始**算的，而 [barStart] 就是那个开始
/// （距窗口起点多少分钟）—— 所以直接加，不需要再取一次锚点。
List<GanttSegment> _segmentsOf(TaskOccurrence row, int barStart, int total) {
  final out = <GanttSegment>[];
  for (final stage in row.stages) {
    final from = stage.startOffsetMinutes;
    if (from == null) continue;
    final segStart = barStart + from;
    final segEnd = barStart + (stage.endOffsetMinutes ?? from);
    if (segEnd <= 0 || segStart >= total) continue;
    out.add(
      GanttSegment(
        stage: stage,
        startMinute: segStart < 0 ? 0 : segStart,
        endMinute: segEnd > total ? total : segEnd,
        done: stage.status == TaskStatus.done,
      ),
    );
  }
  out.sort((a, b) => a.startMinute.compareTo(b.startMinute));
  return out;
}

/// 已完成的阶段占几成。没有阶段时为 null（不是 0 —— 「没有阶段」
/// 与「一个都没做」是两回事，画出来也该不一样）。
double? _progressOf(TaskOccurrence row) {
  if (row.stages.isEmpty) return null;
  final done = row.stages.where((s) => s.status == TaskStatus.done).length;
  return done / row.stages.length;
}

Category? _categoryOf(String? key, List<Category> categories) {
  if (key == null) return null;
  for (final c in categories) {
    if (c.id == key) return c;
  }
  return null;
}

String _titleOf(
  String? key,
  GanttLaneBy laneBy,
  List<Category> categories,
  List<TaskOccurrence> bucket,
) {
  if (laneBy == GanttLaneBy.task) return bucket.first.title;
  return _categoryOf(key, categories)?.name ?? '未分类';
}

/// 泳道顺序。
///
/// 分类按它自己的 `orderIndex`（用户在分类管理里排的那个顺序），
/// **未分类垫底** —— 它不是一个真的分类，摆在中间会打断用户排的次序。
/// 按任务时按最早开始排。
List<String?> _orderedKeys(
  Iterable<String?> keys,
  GanttLaneBy laneBy,
  List<Category> categories,
  Map<String?, List<TaskOccurrence>> buckets,
) {
  final list = keys.toList();
  if (laneBy == GanttLaneBy.category) {
    list.sort((a, b) {
      if (a == null) return 1;
      if (b == null) return -1;
      final ca = _categoryOf(a, categories);
      final cb = _categoryOf(b, categories);
      // 查不到的分类（被删了）排在有序的那些后面，但在「未分类」前面。
      if (ca == null && cb == null) return a.compareTo(b);
      if (ca == null) return 1;
      if (cb == null) return -1;
      final byOrder = ca.orderIndex.compareTo(cb.orderIndex);
      return byOrder != 0 ? byOrder : a.compareTo(b);
    });
  } else {
    list.sort((a, b) {
      final ra = buckets[a]!.first;
      final rb = buckets[b]!.first;
      final byDate = ra.planDate!.compareTo(rb.planDate!);
      return byDate != 0 ? byDate : (a ?? '').compareTo(b ?? '');
    });
  }
  return list;
}

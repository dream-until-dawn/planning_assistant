/// 重叠排布：一堆时间段，谁跟谁并排、各占多宽。
///
/// 时间轴（§1.2「同时段 N 个任务等宽并排，N>3 时改为『+N』堆叠」）与
/// 竖向甘特（§4.5 的 G-02/G-03）用的是**同一套算法**，只是单位不同 ——
/// 前者按分钟，后者按天。所以这里只认 `int`，不认时刻类型。
///
/// ## 为什么是「簇」而不是逐对判重叠
///
/// A 与 B 重叠、B 与 C 重叠、而 A 与 C 不重叠 —— 这时三个必须共用一套
/// 列宽，否则 A 和 C 会各自按「两列」算，画出来宽度对不齐、还会压到 B。
/// 所以先按**传递闭包**分簇，列数在簇内统一。
///
/// ## 为什么列数要封顶
///
/// 一天里挤了八件事的话，八列每列不到 40 像素，标题一个字都放不下 ——
/// 那不是信息密度，是把内容挤没了。超出的折成「+N」，点开再看（§1.2）。
library;

import 'package:meta/meta.dart';

/// 排布的输入：一段占位 `[start, end)` 与它对应的东西。
///
/// **左闭右开**：09:00–10:00 与 10:00–11:00 不算重叠。
/// 闭区间的话，紧挨着的两件事会被判成并排，白白折掉一半宽度。
@immutable
final class OverlapInput<T> {
  const OverlapInput({
    required this.item,
    required this.start,
    required this.end,
  });

  final T item;
  final int start;

  /// 结束位置。**允许等于 [start]**（没有时长的任务），
  /// 那时它只与「同一刻开始」的那些重叠。
  final int end;
}

/// 排好的一格。
@immutable
final class OverlapSlot<T> {
  const OverlapSlot({
    required this.item,
    required this.column,
    required this.columnCount,
  });

  final T item;

  /// 第几列，从 0 起。
  final int column;

  /// 所在簇一共几列 —— 宽度 = 可用宽 / [columnCount]。
  final int columnCount;
}

/// 一簇互相牵连的时间段。
@immutable
final class OverlapCluster<T> {
  const OverlapCluster({
    required this.slots,
    required this.hidden,
    required this.start,
    required this.end,
  });

  final List<OverlapSlot<T>> slots;

  /// 被折掉的那些（超出列数上限）。界面上显示成「+N」。
  final List<T> hidden;

  /// 簇的范围，供「+N」指示器定位。
  final int start;
  final int end;

  int get hiddenCount => hidden.length;
}

/// 把 [inputs] 排成若干簇。
///
/// [maxColumns] 是列数上限（§1.2 与 G-03 都取 3）。
/// 超出的按**开始时间**取前 [maxColumns] 个显示，其余折起来 ——
/// 按开始时间而不是随机：用户读时间轴是从上往下读的，
/// 折掉的应当是「后面还有」，不是「中间少了一个」。
List<OverlapCluster<T>> layoutOverlaps<T>(
  List<OverlapInput<T>> inputs, {
  int maxColumns = 3,
}) {
  if (inputs.isEmpty) return const [];

  // **零长度的段先撑成一个最小单位。**
  //
  // `[540, 540)` 是个空区间：它谁也不重叠，贪心分列时每一列都算「空着」，
  // 于是同一刻的两件事会被排进同一列 —— 画出来是叠在一起的两张卡片。
  // 撑成 `[540, 541)`（时间轴是一分钟，甘特是一天）之后，
  // 「同一刻」自然变成真重叠，而与「上一段正好在这一刻结束」仍然不重叠。
  final normalized = [
    for (final i in inputs)
      i.end > i.start
          ? i
          : OverlapInput(item: i.item, start: i.start, end: i.start + 1),
  ];

  final sorted = normalized
    ..sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      // 开始时间相同时按结束排，让长的排在前面 —— 贪心分列时
      // 先安置长的，短的更容易塞进已有的列。
      return byStart != 0 ? byStart : b.end.compareTo(a.end);
    });

  final clusters = <OverlapCluster<T>>[];
  var group = <OverlapInput<T>>[sorted.first];
  var groupEnd = sorted.first.end;

  void flush() {
    clusters.add(_layoutCluster(group, maxColumns));
  }

  for (final input in sorted.skip(1)) {
    // **左闭右开**：`start == groupEnd` 不算重叠，开新簇。
    // 零长度的段上面已经撑成一个单位了，这里不必再开例外。
    if (input.start < groupEnd) {
      group.add(input);
      if (input.end > groupEnd) groupEnd = input.end;
    } else {
      flush();
      group = [input];
      groupEnd = input.end;
    }
  }
  flush();

  return clusters;
}

OverlapCluster<T> _layoutCluster<T>(
  List<OverlapInput<T>> group,
  int maxColumns,
) {
  final visible = group.take(maxColumns).toList();
  final hidden = group.skip(maxColumns).map((i) => i.item).toList();

  // 贪心分列：每列记着它当前的结束位置，来一个就放进第一根「已经空出来」
  // 的列里；都没空就新开一列。
  //
  // 这样得到的列数是**这一簇真正同时并存的最大数量**，不是簇的大小 ——
  // A 09-10、B 10-11、C 09-11 三个连成一簇，但只需要两列。
  final columnEnds = <int>[];
  final assignment = <int>[];
  for (final input in visible) {
    var placed = -1;
    for (var c = 0; c < columnEnds.length; c++) {
      if (columnEnds[c] <= input.start) {
        placed = c;
        break;
      }
    }
    if (placed < 0) {
      columnEnds.add(input.end);
      placed = columnEnds.length - 1;
    } else {
      columnEnds[placed] = input.end;
    }
    assignment.add(placed);
  }

  final columnCount = columnEnds.isEmpty ? 1 : columnEnds.length;
  return OverlapCluster<T>(
    slots: [
      for (final (i, input) in visible.indexed)
        OverlapSlot<T>(
          item: input.item,
          column: assignment[i],
          columnCount: columnCount,
        ),
    ],
    hidden: hidden,
    start: group.map((i) => i.start).reduce((a, b) => a < b ? a : b),
    end: group.map((i) => i.end).reduce((a, b) => a > b ? a : b),
  );
}

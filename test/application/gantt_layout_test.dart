/// 竖向甘特的布局算法（view-specs §4.5 的 G-01..G-07）。
///
/// §4.5 那七条是规格点名要测的。除它们之外还有一组**性质**测试：
/// 随机造一屏输入，验四条不变量。理由是七条具名用例只覆盖它们各自的
/// 那个形状，而这个算法的坏法（同列的条叠在一起、条跑出窗口、
/// 折叠时丢了一根）在随机输入下才容易撞见。
@TestOn('vm')
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/domain/entities/category.dart';
import 'package:planning_assistant/domain/entities/stage.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';
import 'package:planning_assistant/features/views/gantt/application/gantt_layout.dart';
import 'package:planning_assistant/features/views/shared/application/task_occurrence.dart';

const _start = PlanDate(2026, 9, 7);
const _end = PlanDate(2026, 9, 20);
const _day = 1440;

PlanDate _d(int offset) => _start.addDays(offset);

TaskOccurrence _row(
  String id, {
  int from = 0,
  int? to,
  int? startMinute,
  int? endMinute,
  String? categoryId,
  List<Stage> stages = const [],
}) => TaskOccurrence(
  task: Task(
    id: id,
    title: id,
    kind: stages.isEmpty ? TaskKind.single : TaskKind.staged,
    timeZoneId: 'Asia/Shanghai',
    planDate: _d(from),
    startMinute: startMinute == null ? null : MinuteOfDay(startMinute),
    endDate: to == null ? null : _d(to),
    endMinute: endMinute == null ? null : MinuteOfDay(endMinute),
    isAllDay: startMinute == null,
    categoryId: categoryId,
  ),
  stages: stages,
);

Stage _stage(
  String id, {
  required int start,
  required int duration,
  bool done = false,
}) => Stage(
  id: id,
  taskId: 't',
  title: id,
  orderIndex: 0,
  startOffsetMinutes: start,
  durationMinutes: duration,
  status: done ? TaskStatus.done : TaskStatus.pending,
  completedAt: done ? DateTime.utc(2026, 9, 8) : null,
);

GanttLayout _layout(
  List<TaskOccurrence> rows, {
  GanttLaneBy laneBy = GanttLaneBy.category,
  List<Category> categories = const [],
}) => ganttLayout(
  rows: rows,
  windowStart: _start,
  windowEnd: _end,
  laneBy: laneBy,
  categories: categories,
);

void main() {
  test('G-01 单泳道单任务跨 3 天 → 一根连续条，长度 = 3 个时间单元', () {
    // 9/7 到 9/9 全天 = 三天。全天任务的结束读到那天的 23:59，
    // 所以长度是 3×1440 − 1 分钟 —— 差的那一分钟是「到当天末尾」
    // 那条读法的必然结果（data-model §3.1.1），不是算错。
    final layout = _layout([_row('出差', to: 2)]);
    expect(layout.lanes, hasLength(1));
    final bar = layout.lanes.single.bars.single;
    expect(bar.startMinute, 0);
    expect(bar.lengthMinutes, 3 * _day - 1);
    expect(bar.continuesBefore, isFalse);
    expect(bar.continuesAfter, isFalse);
  });

  test('G-02 同泳道两任务时间重叠 → 2 列，各占半宽', () {
    final layout = _layout([
      _row('甲', from: 0, to: 3),
      _row('乙', from: 2, to: 5),
    ]);
    final bars = layout.lanes.single.bars;
    expect(bars, hasLength(2));
    expect(bars.map((b) => b.column).toSet(), {0, 1});
    expect(bars.every((b) => b.columnCount == 2), isTrue);
  });

  test('G-02 对照组：不重叠的两个复用同一列', () {
    // 少了这条，一个「同泳道一律分列」的实现也能让上面绿 ——
    // 那样一条泳道里十件先后发生的事会挤成十列。
    final layout = _layout([
      _row('甲', from: 0, to: 1),
      _row('乙', from: 5, to: 6),
    ]);
    final bars = layout.lanes.single.bars;
    expect(bars.map((b) => b.column).toSet(), {0});
    expect(bars.every((b) => b.columnCount == 1), isTrue);
  });

  test('G-03 同泳道 4 个重叠 → 3 列 + 折叠指示', () {
    final layout = _layout([
      for (var i = 0; i < 4; i++) _row('并行$i', from: i, to: 8),
    ]);
    final lane = layout.lanes.single;
    expect(lane.bars, hasLength(maxColumnsPerLane));
    expect(lane.columnCount, 3);
    expect(lane.hidden.map((r) => r.id), ['并行3']);
  });

  test('G-03 对照组：正好三个不折', () {
    final layout = _layout([
      for (var i = 0; i < 3; i++) _row('并行$i', from: i, to: 8),
    ]);
    expect(layout.lanes.single.hidden, isEmpty);
    expect(layout.lanes.single.bars, hasLength(3));
  });

  test('G-04 三阶段任务 → 3 段，总长 = 任务跨度', () {
    final layout = _layout([
      _row(
        '搬家',
        from: 0,
        startMinute: 9 * 60,
        to: 2,
        endMinute: 18 * 60,
        stages: [
          _stage('打包', start: 0, duration: 120),
          _stage('搬运', start: 180, duration: 240),
          _stage('收拾', start: 24 * 60, duration: 300),
        ],
      ),
    ]);
    final bar = layout.lanes.single.bars.single;
    expect(bar.segments, hasLength(3));
    // 段落按开始排，且都落在条之内。
    expect(bar.segments.map((s) => s.startMinute).toList(), [
      bar.startMinute,
      bar.startMinute + 180,
      bar.startMinute + 24 * 60,
    ]);
    for (final seg in bar.segments) {
      expect(seg.startMinute, greaterThanOrEqualTo(bar.startMinute));
      expect(seg.endMinute, lessThanOrEqualTo(bar.endMinute));
    }
    // 总长仍是任务跨度（9/7 09:00 → 9/9 18:00），不是各段之和。
    expect(bar.lengthMinutes, 2 * _day + 9 * 60);
  });

  test('G-04 已完成的段落标出来 —— 进度不能只靠颜色深浅', () {
    final layout = _layout([
      _row(
        '搬家',
        from: 0,
        startMinute: 9 * 60,
        to: 0,
        endMinute: 18 * 60,
        stages: [
          _stage('打包', start: 0, duration: 60, done: true),
          _stage('搬运', start: 120, duration: 60),
        ],
      ),
    ]);
    final segs = layout.lanes.single.bars.single.segments;
    expect(segs.map((s) => s.done), [true, false]);
  });

  test('G-05 阶段偏移超出任务结束 → 跨度用 effectiveEnd', () {
    // 与时间轴、日历同一个跨度（data-model §4.7）。甘特自行扩展的话，
    // 同一条任务在两个视图里一长一短。
    final layout = _layout([
      _row(
        '搬家',
        from: 0,
        startMinute: 9 * 60,
        to: 0,
        endMinute: 10 * 60,
        stages: [_stage('搬运', start: 0, duration: 3 * _day)],
      ),
    ]);
    final bar = layout.lanes.single.bars.single;
    expect(bar.lengthMinutes, 3 * _day);
  });

  test('G-06 重复任务在窗口内多次发生 → 每次一根独立的条', () {
    // 同一条规则展开出的三次。按任务分泳道时它们在**同一条泳道**里，
    // 而那条泳道里是**三根条**，不是一根从头连到尾的。
    final rows = [
      for (var i = 0; i < 3; i++)
        _row('晨会', from: i * 3, startMinute: 9 * 60, to: i * 3, endMinute: 600),
    ];
    final layout = _layout(rows, laneBy: GanttLaneBy.task);
    expect(layout.lanes, hasLength(1));
    expect(layout.lanes.single.bars, hasLength(3));
    // 三根各自独立：起点两两相隔三天，中间是断开的。
    expect(layout.lanes.single.bars.map((b) => b.startMinute).toList(), [
      9 * 60,
      3 * _day + 9 * 60,
      6 * _day + 9 * 60,
    ]);
  });

  test('G-07 窗口边界处被截断 → 条延伸到边界，并标明还没完', () {
    final layout = _layout([_row('长项目', from: -5, to: 30)]);
    final bar = layout.lanes.single.bars.single;
    expect(bar.startMinute, 0);
    expect(bar.endMinute, layout.totalMinutes);
    expect(bar.continuesBefore, isTrue);
    expect(bar.continuesAfter, isTrue);
  });

  test('G-07 对照组：完全在窗口内的不标「还没完」', () {
    final bar = _layout([_row('短', from: 1, to: 2)]).lanes.single.bars.single;
    expect(bar.continuesBefore, isFalse);
    expect(bar.continuesAfter, isFalse);
  });

  group('泳道', () {
    test('按分类分，顺序随分类自己的 orderIndex，未分类垫底', () {
      final layout = _layout(
        [
          _row('a', categoryId: 'work'),
          _row('b'),
          _row('c', categoryId: 'life'),
        ],
        categories: const [
          Category(
            id: 'life',
            name: '生活',
            colorArgb: 1,
            icon: 'x',
            orderIndex: 0,
          ),
          Category(
            id: 'work',
            name: '工作',
            colorArgb: 2,
            icon: 'x',
            orderIndex: 1,
          ),
        ],
      );
      expect(layout.lanes.map((l) => l.title), ['生活', '工作', '未分类']);
    });

    test('没有日期的不进甘特（§4.3 最后一行）', () {
      const row = TaskOccurrence(
        task: Task(
          id: '总有一天',
          title: '总有一天',
          kind: TaskKind.single,
          timeZoneId: 'Asia/Shanghai',
        ),
      );
      expect(_layout([row]).isEmpty, isTrue);
    });

    test('完全在窗口外的不进来', () {
      expect(_layout([_row('去年', from: -60, to: -50)]).isEmpty, isTrue);
    });
  });

  group('随机一屏也要守住四条不变量', () {
    // 七条具名用例各覆盖一个形状。这个算法真正的坏法 —— 同列的条叠在
    // 一起、条跑出窗口、折叠时丢了一根 —— 在随机输入下才容易撞见。
    //
    // 种子写死：随机测试一旦不可复现，红了也查不下去。
    final rng = Random(20260909);

    List<TaskOccurrence> randomRows(int n) => [
      for (var i = 0; i < n; i++)
        () {
          final from = rng.nextInt(20) - 3;
          final len = rng.nextInt(6);
          return _row(
            'r$i',
            from: from,
            to: from + len,
            startMinute: rng.nextBool() ? rng.nextInt(24) * 60 : null,
            endMinute: rng.nextBool() ? rng.nextInt(24) * 60 : null,
            categoryId: ['work', 'life', null][rng.nextInt(3)],
          );
        }(),
    ];

    test('条不出窗口、不倒挂', () {
      for (var t = 0; t < 40; t++) {
        final layout = _layout(randomRows(12));
        for (final lane in layout.lanes) {
          for (final bar in lane.bars) {
            expect(bar.startMinute, inInclusiveRange(0, layout.totalMinutes));
            expect(bar.endMinute, inInclusiveRange(0, layout.totalMinutes));
            expect(bar.endMinute, greaterThanOrEqualTo(bar.startMinute));
          }
        }
      }
    });

    test('同泳道同一列的两根条不重叠', () {
      // 这是分列的**全部意义**。重叠了的话屏幕上是两根条压在一起，
      // 看起来像一根 —— 而那正是用户会当成「甘特画错了」的东西。
      for (var t = 0; t < 40; t++) {
        final layout = _layout(randomRows(12));
        for (final lane in layout.lanes) {
          final byColumn = <int, List<GanttBar>>{};
          for (final bar in lane.bars) {
            (byColumn[bar.column] ??= []).add(bar);
          }
          for (final entry in byColumn.entries) {
            final bars = entry.value
              ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
            for (var i = 1; i < bars.length; i++) {
              expect(
                bars[i].startMinute,
                greaterThanOrEqualTo(bars[i - 1].endMinute),
                reason: '第 ${entry.key} 列里两根条叠了',
              );
            }
          }
        }
      }
    });

    test('列数不超上限', () {
      for (var t = 0; t < 40; t++) {
        for (final lane in _layout(randomRows(12)).lanes) {
          expect(lane.columnCount, lessThanOrEqualTo(maxColumnsPerLane));
        }
      }
    });

    test('一根都不丢：画出来的 + 折起来的 = 进来的（窗口内那些）', () {
      // 折叠的实现最容易在这里出错：`skip(maxColumns)` 少算一个，
      // 那一根既不在 bars 里也不在 hidden 里，凭空消失。
      for (var t = 0; t < 40; t++) {
        final rows = randomRows(12);
        final layout = _layout(rows);
        final placed = <String>{
          for (final lane in layout.lanes) ...[
            ...lane.bars.map((b) => b.row.id),
            ...lane.hidden.map((r) => r.id),
          ],
        };
        // **`isEmpty` 不是 `lanes.isEmpty`**：开始落在窗口之后的行
        // 会进分桶却排不出条。第一版用的是 `lanes.isNotEmpty`，
        // 于是把两条根本排不进来的行算进了期望，红得莫名其妙。
        final expected = rows
            .where((r) => !_layout([r]).isEmpty)
            .map((r) => r.id)
            .toSet();
        expect(placed, expected);
      }
    });
  });
}

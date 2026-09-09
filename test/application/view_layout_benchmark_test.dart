/// 四视图布局的性能基准 —— M3 验收项「1000 条任务下不掉帧」的**一半**。
///
/// ## 它验的是什么，不验什么
///
/// 掉帧率要在 profile 模式的真机上量（NFR-PERF-02），这条测试量不了。
/// 它量的是**布局计算本身**，也就是 §4.4 第 3 条说的
/// 「布局计算是纯函数，可独立单测 + 基准测试」。
///
/// 这一半为什么值得单独量：一帧 16.7ms，而布局是**每帧都可能重跑**的
/// （滚动、切筛选、勾完成都会让 provider 重算）。布局要是自己就花掉
/// 十几毫秒，后面画得再快也来不及。反过来，布局快不等于不掉帧 ——
/// 那部分要真机说了算，见文件末尾那条记账。
///
/// ## 阈值怎么定的
///
/// 同 `recurrence_benchmark_test`：预热、取中位数、阈值留一个数量级的
/// 余量。它抓的是「慢了一个数量级」这种真退化（比如某处不小心写成
/// O(n²)），不是 20% 的波动。
///
/// **同时断言产出条数** —— 只测时间的话，一个「什么都不排」的实现
/// 会跑得飞快并且通过，那正是最典型的假绿。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/core/time/time_zone_resolver.dart';
import 'package:planning_assistant/domain/entities/category.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/recurrence/recurrence_engine.dart';
import 'package:planning_assistant/domain/value_objects/recurrence.dart';
import 'package:planning_assistant/features/views/calendar/application/day_bands.dart';
import 'package:planning_assistant/features/views/calendar/application/month_grid.dart';
import 'package:planning_assistant/features/views/gantt/application/gantt_layout.dart';
import 'package:planning_assistant/features/views/shared/application/occurrence_expansion.dart';
import 'package:planning_assistant/features/views/shared/application/task_occurrence.dart';
import 'package:planning_assistant/features/views/timeline/application/agenda_entries.dart';
import 'package:timezone/data/latest.dart' as tzdata;

const _today = PlanDate(2026, 9, 8);
const _engine = RecurrenceEngine(TzTimeZoneResolver());

/// 一帧 16.7ms。布局占掉一半就已经很紧张了，所以阈值取 8ms 的
/// 一个数量级余量 —— 实测在开发机上是个位数毫秒以内。
const _budget = Duration(milliseconds: 80);

const _taskCount = 1000;

/// 一千条任务：三成重复、三成跨天、三成有分类、其余零散。
///
/// **不是一千条一模一样的**：同构的输入会让分列、分桶这些地方
/// 恰好走最快的那条路，量出来的数字比真实情况好看。
List<Task> _thousandTasks() => [
  for (var i = 0; i < _taskCount; i++)
    Task(
      id: 't$i',
      title: '任务 $i',
      kind: TaskKind.single,
      timeZoneId: 'Asia/Shanghai',
      planDate: _today.addDays(i % 60 - 20),
      startMinute: i % 3 == 0 ? null : MinuteOfDay((i * 37) % 1380),
      endDate: i % 3 == 1 ? _today.addDays(i % 60 - 20 + (i % 4)) : null,
      endMinute: null,
      isAllDay: i % 3 == 0,
      categoryId: switch (i % 4) {
        0 => 'work',
        1 => 'life',
        2 => 'study',
        _ => null,
      },
      recurrence: i % 10 == 0 ? Recurrence.parse('RRULE:FREQ=WEEKLY') : null,
    ),
];

const _categories = [
  Category(id: 'work', name: '工作', colorArgb: 1, icon: 'x', orderIndex: 0),
  Category(id: 'life', name: '生活', colorArgb: 2, icon: 'x', orderIndex: 1),
  Category(id: 'study', name: '学习', colorArgb: 3, icon: 'x', orderIndex: 2),
];

/// 跑 [rounds] 轮取中位数，前几轮预热不计。
Duration _median(void Function() body, {int rounds = 7, int warmup = 3}) {
  for (var i = 0; i < warmup; i++) {
    body();
  }
  final samples = <int>[];
  for (var i = 0; i < rounds; i++) {
    final sw = Stopwatch()..start();
    body();
    sw.stop();
    samples.add(sw.elapsedMicroseconds);
  }
  samples.sort();
  return Duration(microseconds: samples[samples.length ~/ 2]);
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  late List<Task> tasks;
  setUp(() => tasks = _thousandTasks());

  test('展开一屏（一个月的窗口）', () {
    var rows = <TaskOccurrence>[];
    final took = _median(() {
      rows = expandInWindow(
        tasks: tasks,
        overrides: const [],
        window: DateRange(_today.addDays(-20), _today.addDays(20)),
        engine: _engine,
      );
    });
    expect(rows, isNotEmpty, reason: '什么都没展开的话，快是应该的');
    expect(rows.length, greaterThan(_taskCount ~/ 2));
    expect(took, lessThan(_budget), reason: '展开慢了：$took');
  });

  test('时间轴摊平成议程', () {
    final rows = expandForAgenda(
      tasks: tasks,
      overrides: const [],
      today: _today,
      engine: _engine,
    );
    var entries = agendaEntries(const []);
    final took = _median(() => entries = agendaEntries(rows));
    expect(entries, isNotEmpty);
    expect(took, lessThan(_budget), reason: '议程摊平慢了：$took');
  });

  test('展开成议程（每条任务只留两次）', () {
    var rows = <TaskOccurrence>[];
    final took = _median(() {
      rows = expandForAgenda(
        tasks: tasks,
        overrides: const [],
        today: _today,
        engine: _engine,
      );
    });
    expect(rows, isNotEmpty, reason: '什么都没展开的话，快是应该的');
    // 每条任务最多两行 —— 这既是行为，也是这条预算成立的前提。
    expect(rows.length, lessThanOrEqualTo(_taskCount * 2));
    expect(took, lessThan(_budget), reason: '议程展开慢了：$took');
  });

  test('日历排一个月（六行横条 + 四十二格色点）', () {
    final grid = monthGrid(year: 2026, month: 9);
    final rows = expandInWindow(
      tasks: tasks,
      overrides: const [],
      window: DateRange(grid.first, grid.last),
      engine: _engine,
    );
    var bandCount = 0;
    final took = _median(() {
      bandCount = 0;
      for (final week in grid.weeks) {
        final bands = weekBands(rows, week.first.date);
        bandCount += bands.bands.length;
        for (final (i, cell) in week.indexed) {
          dayDots(rows, cell.date, hiddenBands: bands.hiddenByDay[i]);
        }
      }
    });
    expect(bandCount, greaterThan(0));
    expect(took, lessThan(_budget), reason: '日历排布慢了：$took');
  });

  test('甘特排一屏（十四天）', () {
    final rows = expandInWindow(
      tasks: tasks,
      overrides: const [],
      window: DateRange(_today.addDays(-3), _today.addDays(10)),
      engine: _engine,
    );
    var layout = ganttLayout(
      rows: const [],
      windowStart: _today,
      windowEnd: _today,
      laneBy: GanttLaneBy.category,
    );
    final took = _median(() {
      layout = ganttLayout(
        rows: rows,
        windowStart: _today.addDays(-3),
        windowEnd: _today.addDays(10),
        laneBy: GanttLaneBy.category,
        categories: _categories,
      );
    });
    expect(layout.lanes, isNotEmpty);
    expect(took, lessThan(_budget), reason: '甘特排布慢了：$took');
  });

  test('条数翻倍时耗时不该翻四倍 —— 挡住悄悄写成 O(n²)', () {
    // ## 这条量的是**排布**，不是展开
    //
    // 第一版量的是 `expandInWindow`。实测比值 **0.95** —— 也就是
    // 一千条与两千条一样快。那说明耗时压根不由任务数主导（时区解析、
    // 规则展开这些固定开销盖过了循环），于是往里注入一个 O(n²)
    // 之后比值也只到 1.71，阈值放到 6 自然抓不住。
    //
    // **量错了对象的基准，就是一条永远绿的测试。**
    //
    // 排布函数是纯的、没有固定开销，增长看得见。实测（开发机，各三轮）：
    //
    // | 实现 | 比值 |
    // |---|---|
    // | 现在这版 | 1.28 / 1.35 / 1.72 |
    // | 注入 O(n²) | 4.15 / 4.51 |
    //
    // 阈值 3 落在两者中间，两侧各留一倍多的余量。
    // 比值不到 2 是因为超出三列的行会被折起来，折的那部分很便宜。
    final rows = expandInWindow(
      tasks: _thousandTasks(),
      overrides: const [],
      window: DateRange(_today.addDays(-20), _today.addDays(20)),
      engine: _engine,
    );
    final doubled = [...rows, ...rows];

    Duration run(List<TaskOccurrence> input) => _median(
      () => ganttLayout(
        rows: input,
        windowStart: _today.addDays(-20),
        windowEnd: _today.addDays(20),
        laneBy: GanttLaneBy.category,
        categories: _categories,
      ),
      rounds: 9,
    );

    // **先把两边都跑一遍再计时。**
    //
    // 不这么做的话，先量的那个要替后量的那个付 JIT 编译的账 ——
    // 实测比值是 **0.79～0.95**：行数翻倍反而更快。
    // 比值小于 1 本身就是「量法坏了」的信号，不是「代码很快」。
    run(rows);
    run(doubled);

    final a = run(rows).inMicroseconds;
    final b = run(doubled).inMicroseconds;
    expect(
      b,
      lessThan(a * 3),
      reason: '${rows.length} 行 $a µs、${doubled.length} 行 $b µs —— 增长得不像线性',
    );
  });
}

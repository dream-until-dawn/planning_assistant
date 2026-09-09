/// 甘特排布的**随机种子**性质测试。
///
/// ## 它与 `gantt_layout_test.dart` 里那一组的区别
///
/// 那一组的种子是**写死的**（`Random(20260909)`）—— 可复现，
/// 但评审指出了它名不副实的地方：
///
/// > 种子固定 → 每次跑的是同一批输入。可复现是对的，但它不会发现
/// > 「没人想到的输入组合」，而那恰是性质测试相对黄金用例的**唯一**增量。
///
/// 也就是说：固定种子的「性质测试」其实是**一大块固定夹具**，
/// 名字给的承诺比机制大。与我们在 golden 上分「断言型 / 快照型」
/// （§7.1）是同一个毛病的另一处。
///
/// 这个文件补上那份增量：**每次跑都换种子**。
///
/// ## 它不进主门禁
///
/// 用 `@Tags(['fuzz'])` 标着，`dart_test.yaml` 把它从默认运行里排除。
/// 理由不是「怕它红」，是**红的时机不受控**：
/// 一条随机测试可能在任何一次无关的提交上突然变红，
/// 而那时人正在看另一件事。把它排除出门禁之后，
/// 它红的时候是有人主动去跑它 —— 那时他愿意查。
///
/// ```bash
/// flutter test --tags fuzz --run-skipped
/// ```
///
/// （`--run-skipped` 是必须的：`dart_test.yaml` 里用的是 `skip`，
/// 光给 `--tags` 只是「选中它」，跳过那一条仍然生效。）
///
/// **失败时打印种子**，那是这类测试唯一能被查下去的方式：
/// 拿那个种子去 `gantt_layout_test.dart` 里加一条固定用例，
/// 缺陷就从「偶发」变成「具名」。
@Tags(['fuzz'])
@TestOn('vm')
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/features/views/gantt/application/gantt_layout.dart';
import 'package:planning_assistant/features/views/shared/application/task_occurrence.dart';

const _start = PlanDate(2026, 9, 1);
const _days = 21;

TaskOccurrence _row(
  String id, {
  required int from,
  required int to,
  int? startMinute,
  int? endMinute,
  String? categoryId,
}) => TaskOccurrence(
  task: Task(
    id: id,
    title: id,
    kind: TaskKind.single,
    timeZoneId: 'Asia/Shanghai',
    categoryId: categoryId,
    planDate: _start.addDays(from),
    startMinute: startMinute == null ? null : MinuteOfDay(startMinute),
    endDate: _start.addDays(to),
    endMinute: endMinute == null ? null : MinuteOfDay(endMinute),
    isAllDay: startMinute == null,
  ),
);

GanttLayout _layout(List<TaskOccurrence> rows) => ganttLayout(
  rows: rows,
  windowStart: _start,
  windowEnd: _start.addDays(_days - 1),
  laneBy: GanttLaneBy.category,
  categories: const [],
);

void main() {
  test('随机一屏守住四条不变量（随机种子，失败会打印它）', () {
    // 每次跑都换种子。**这正是这个文件存在的理由** ——
    // 固定种子的那一组跑的永远是同一批输入。
    //
    // 种子取自一个**没播种的 `Random`**，不是 `DateTime.now()`：
    // 「测试代码不得使用真实时钟」那条守卫会拦下后者（而且拦得对 ——
    // 它防的是把当前时刻当输入的用例）。这里要的只是一点熵，
    // 而 `Random()` 自己就有，还省了一条守卫豁免。
    final seed = Random().nextInt(1 << 32);
    final rng = Random(seed);

    List<TaskOccurrence> randomRows(int n) => [
      for (var i = 0; i < n; i++)
        () {
          final from = rng.nextInt(_days + 6) - 3;
          final len = rng.nextInt(8);
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

    // 失败信息里必须带种子 —— 否则这条测试红了也查不下去，
    // 而查不下去的随机测试比没有更糟：它只会教人重跑一次。
    final seedNote = '种子 $seed —— 拿它去 gantt_layout_test.dart 加一条固定用例';

    for (var round = 0; round < 60; round++) {
      final layout = _layout(randomRows(2 + rng.nextInt(14)));

      for (final lane in layout.lanes) {
        // ① 不出窗口、不倒挂。
        for (final bar in lane.bars) {
          expect(
            bar.startMinute,
            inInclusiveRange(0, layout.totalMinutes),
            reason: seedNote,
          );
          expect(
            bar.endMinute,
            inInclusiveRange(0, layout.totalMinutes),
            reason: seedNote,
          );
          expect(
            bar.endMinute,
            greaterThanOrEqualTo(bar.startMinute),
            reason: seedNote,
          );
        }

        // ② 同一列的两根条不重叠 —— 分列的全部意义。
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
              reason: '第 ${entry.key} 列里两根条叠了。$seedNote',
            );
          }
        }

        // ③ 列数不超上限。
        for (final bar in lane.bars) {
          expect(bar.column, lessThan(maxColumnsPerLane), reason: seedNote);
        }
      }
    }
  });
}

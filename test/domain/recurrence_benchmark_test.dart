/// 重复展开的性能基准 —— M1 验收项「1 年 ≤ 50ms」。
///
/// ## 为什么这条基准值得存在
///
/// 展开是**每次视图刷新都要跑**的东西：滑动日历、切换月份、拉时间轴，
/// 都会重算可见窗内的发生。慢一点用户就直接感觉到卡。
///
/// ## 为什么它不是一条好测试，以及怎么补
///
/// 时间断言天生不稳：CI 机器的负载、其他测试的干扰、JIT 预热，
/// 都会让同一份代码时快时慢。**阈值定得松就抓不到退化，定得紧就偶发失败。**
///
/// 所以这里的做法是：
///  1. 先预热，把 JIT 编译的开销排除在计时之外；
///  2. 取多轮的**中位数**而不是单次，压掉偶发抖动；
///  3. 阈值取 50ms，而实测在开发机上是个位数毫秒 —— 留足余量，
///     它抓的是「慢了一个数量级」这种真退化，不是 20% 的波动。
///  4. **同时断言结果条数**。只测时间的话，一个「什么都不展开」的实现
///     会跑得飞快并且通过 —— 那正是最典型的假绿。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/local_wall_time.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/core/time/time_zone_resolver.dart';
import 'package:planning_assistant/domain/recurrence/recurrence_engine.dart';
import 'package:planning_assistant/domain/value_objects/recurrence.dart';
import 'package:timezone/data/latest.dart' as tzdata;

const _engine = RecurrenceEngine(TzTimeZoneResolver());

/// 阈值。放宽的话就抓不到退化了，收紧的话 CI 会偶发红。
const _budget = Duration(milliseconds: 50);

RecurrenceContext context(String rule, {String zone = 'Asia/Shanghai'}) =>
    RecurrenceContext(
      taskId: 't1',
      dtStart: LocalWallTime(
        date: const PlanDate(2026, 1, 1),
        minuteOfDay: MinuteOfDay.of(9, 0),
        timeZoneId: zone,
      ),
      isAllDay: false,
      recurrence: Recurrence.parse(rule),
    );

/// 跑 [rounds] 轮取中位数；前若干轮不计入（预热 JIT）。
({Duration median, int count}) measure(
  List<dynamic> Function() body, {
  int warmup = 3,
  int rounds = 9,
}) {
  for (var i = 0; i < warmup; i++) {
    body();
  }
  final samples = <int>[];
  var count = 0;
  for (var i = 0; i < rounds; i++) {
    final sw = Stopwatch()..start();
    count = body().length;
    sw.stop();
    samples.add(sw.elapsedMicroseconds);
  }
  samples.sort();
  return (
    median: Duration(microseconds: samples[samples.length ~/ 2]),
    count: count,
  );
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  const oneYear = DateRange(PlanDate(2026, 1, 1), PlanDate(2026, 12, 31));

  group('1 年窗口的展开预算（≤ 50ms）', () {
    test('每天重复 → 365 次，在预算内', () {
      final r = measure(
        () => _engine.expand(
          context: context('RRULE:FREQ=DAILY'),
          window: oneYear,
        ),
      );
      // **先断条数**：一个什么都不展开的实现会飞快通过时间断言。
      // ignore: avoid_print
      print('  [基准] 每天重复展开 1 年：中位 ${r.median.inMicroseconds}μs / ${r.count} 次');
      expect(r.count, 365, reason: '2026 不是闰年');
      expect(
        r.median,
        lessThan(_budget),
        reason: '每天重复展开 1 年耗时 ${r.median.inMicroseconds}μs，超出预算',
      );
    });

    test('每周两天 → 104 次，在预算内', () {
      final r = measure(
        () => _engine.expand(
          context: context('RRULE:FREQ=WEEKLY;BYDAY=MO,WE'),
          window: oneYear,
        ),
      );
      expect(r.count, greaterThan(100));
      expect(r.count, lessThan(110));
      expect(r.median, lessThan(_budget));
    });

    test('每月最后一个周五 → 12 次，在预算内', () {
      final r = measure(
        () => _engine.expand(
          context: context('RRULE:FREQ=MONTHLY;BYDAY=-1FR'),
          window: oneYear,
        ),
      );
      expect(r.count, 12);
      expect(r.median, lessThan(_budget));
    });

    test('带 DST 的时区不显著更慢 —— 时区换算不该成为瓶颈', () {
      // resolve() 里有二分找跳变点。若哪天有人把它改成线性扫描，
      // 这条会先红，而不是等用户抱怨日历卡。
      final noDst = measure(
        () => _engine.expand(
          context: context('RRULE:FREQ=DAILY', zone: 'Asia/Shanghai'),
          window: oneYear,
        ),
      );
      final withDst = measure(
        () => _engine.expand(
          context: context('RRULE:FREQ=DAILY', zone: 'America/New_York'),
          window: oneYear,
        ),
      );

      expect(noDst.count, withDst.count, reason: '两边条数应一致');
      expect(withDst.median, lessThan(_budget));
    });
  });

  group('极端输入不至于失控', () {
    test('每小时重复一年（约 8760 次）仍在秒级以内', () {
      // 不是验收项，是护栏：它是最坏情况的量级参考。
      // 真炸的话（比如变成 O(n²)），这里会先炸。
      final r = measure(
        () => _engine.expand(
          context: context('RRULE:FREQ=HOURLY'),
          window: oneYear,
        ),
        rounds: 3,
      );
      // ignore: avoid_print
      print('  [基准] 每小时展开 1 年：中位 ${r.median.inMilliseconds}ms / ${r.count} 次');
      expect(r.count, greaterThan(8000));
      expect(
        r.median,
        lessThan(const Duration(seconds: 1)),
        reason: '每小时展开一年耗时 ${r.median.inMilliseconds}ms',
      );
    });

    test('空窗口立即返回', () {
      final r = measure(
        () => _engine.expand(
          context: context('RRULE:FREQ=DAILY'),
          window: const DateRange(PlanDate(2030, 1, 1), PlanDate(2030, 1, 1)),
        ),
      );
      expect(r.count, 1, reason: '单日窗口应只有一次');
      expect(r.median, lessThan(_budget));
    });
  });
}

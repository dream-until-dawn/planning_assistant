/// 任务的有效跨度（data-model §4.7、甘特 G-05）。
///
/// §4.7 那条规则的要害是**四视图共用同一个答案**。所以这里不只验
/// 「算得对」，还验「阶段超出结束时间时，跨度确实被撑开了」——
/// 后者才是这条规则存在的理由：不撑开的话甘特会自己撑，
/// 于是同一条任务在甘特里比在时间轴里长。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/date_and_minute.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/domain/entities/stage.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/services/effective_span.dart';

const _day = PlanDate(2026, 9, 8);

Task _task({PlanDate? endDate, int? endMinute, bool isAllDay = false}) => Task(
  id: 't',
  title: 't',
  kind: TaskKind.staged,
  timeZoneId: 'Asia/Shanghai',
  planDate: _day,
  startMinute: isAllDay ? null : MinuteOfDay.of(9, 0),
  endDate: endDate,
  endMinute: endMinute == null ? null : MinuteOfDay(endMinute),
  isAllDay: isAllDay,
);

Stage _stage(String id, {int? start, int? duration}) => Stage(
  id: id,
  taskId: 't',
  title: id,
  orderIndex: 0,
  startOffsetMinutes: start,
  durationMinutes: duration,
);

EffectiveSpan _span(Task task, {List<Stage> stages = const []}) =>
    effectiveSpan(
      start: DateAndMinute(
        _day,
        task.isAllDay ? MinuteOfDay.midnight : MinuteOfDay.of(9, 0),
      ),
      end: storedEnd(
        endDate: task.endDate,
        endMinute: task.isAllDay ? null : task.endMinute,
      ),
      stages: stages,
    );

void main() {
  group('没有阶段时就是存储的那一段', () {
    test('有头有尾', () {
      final span = _span(_task(endDate: _day, endMinute: 10 * 60));
      expect(span.start, DateAndMinute(_day, MinuteOfDay.of(9, 0)));
      expect(span.end, DateAndMinute(_day, MinuteOfDay.of(10, 0)));
    });

    test('没写结束 → 零长，不替用户假设时长', () {
      final span = _span(_task());
      expect(span.end, span.start);
    });

    test('有结束日期没有结束时刻 → 那天的 23:59', () {
      // 与校验器、展开折算、时间轴三处同一个读法（§3.1.1）。
      final span = _span(_task(endDate: _day.addDays(1)));
      expect(span.end, DateAndMinute(_day.addDays(1), MinuteOfDay(1439)));
    });

    test('全天任务也按那天末尾', () {
      final span = _span(_task(endDate: _day.addDays(2), isAllDay: true));
      expect(span.end.date, _day.addDays(2));
      expect(span.end.minute.value, 1439);
    });
  });

  group('阶段可以把跨度撑开（G-05）', () {
    test('末阶段超出 endDate 时，跨度用阶段那一头', () {
      // 这条就是 §4.7 存在的理由。不撑开的话甘特会自己撑，
      // 于是同一条任务在甘特里比在时间轴里长。
      final span = _span(
        _task(endDate: _day, endMinute: 10 * 60),
        stages: [
          _stage('a', start: 0, duration: 60),
          _stage('b', start: 60, duration: 24 * 60), // 到第二天 10:00
        ],
      );
      expect(span.end, DateAndMinute(_day.addDays(1), MinuteOfDay.of(10, 0)));
    });

    test('对照组：阶段没超出时，跨度还是存储的那一头', () {
      // 少了这条，一个「一律用阶段末尾」的实现也能让上面绿 ——
      // 那样「任务排到 18:00，阶段只排到 11:00」会显示成 11:00 结束。
      final span = _span(
        _task(endDate: _day, endMinute: 18 * 60),
        stages: [_stage('a', start: 0, duration: 120)],
      );
      expect(span.end, DateAndMinute(_day, MinuteOfDay.of(18, 0)));
    });

    test('没排时间的阶段不会改掉跨度', () {
      // 注：这条**区分不了**「跳过它」与「当成 0」——
      // 补 0 的结果就是任务开始那一刻，而它永远赢不了取最大。
      // 实现那边把这件事写明了，这里不假装测到了。
      final span = _span(
        _task(endDate: _day, endMinute: 18 * 60),
        stages: [_stage('a'), _stage('b', start: null, duration: 999)],
      );
      expect(span.end, DateAndMinute(_day, MinuteOfDay.of(18, 0)));
    });

    test('阶段有开始没时长 → 那一刻，不是零', () {
      final span = _span(_task(), stages: [_stage('a', start: 180)]);
      expect(span.end, DateAndMinute(_day, MinuteOfDay.of(12, 0)));
    });

    test('取的是**最大**，不是最后一个', () {
      // 阶段按 orderIndex 排，但偏移不保证递增（用户可以把第二阶段
      // 排在第一阶段之前）。取「最后一个」的话跨度会短一截。
      final span = _span(
        _task(),
        stages: [
          _stage('长', start: 0, duration: 600),
          _stage('短', start: 0, duration: 30),
        ],
      );
      expect(span.end, DateAndMinute(_day, MinuteOfDay.of(19, 0)));
    });

    test('跨天的阶段偏移用 floorDiv，不是截断', () {
      // 负偏移界面上造不出来，但换算本身要对 —— 这条盯的是
      // `shiftFrom` 那个 floorDiv（`-30 ~/ 1440 == 0` 会算成当天 -30 分）。
      final span = _span(
        _task(),
        stages: [_stage('a', start: -600, duration: 0)],
      );
      // 起点 9:00 往前 600 分 = 前一天 23:00 —— 但它比开始早，
      // 所以不该把结束拉回去。
      expect(span.end, span.start);
    });
  });

  group('结束永远不早于开始', () {
    test('哪怕存的结束早于开始（脏数据）', () {
      // 库里可能有早期版本或导入进来的坏数据。返回一个倒挂的区间的话，
      // 甘特会画出负高度然后抛。
      final span = _span(_task(endDate: _day.addDays(-1), endMinute: 60));
      expect(span.end.isBefore(span.start), isFalse);
      expect(span.end, span.start);
    });
  });
}

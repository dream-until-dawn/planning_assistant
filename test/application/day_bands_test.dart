/// 月历格子里的横条与色点（view-specs §3.1、§3.2）。
///
/// §3.2 那句「以横条贯穿，**连续多日不断开**」在屏幕上很难验：
/// 断没断开看的是两格之间有没有缝，而缝可能只有半个像素。
/// 但它在数据上是一句确定的话 —— **同一条任务在同一行里只有一条横条，
/// 且层号只有一个**。断开的实现在这里会给出两条、或者两个层号。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/features/views/calendar/application/day_bands.dart';
import 'package:planning_assistant/features/views/shared/application/task_occurrence.dart';

/// 2026-09-07 是周一。
const _mon = PlanDate(2026, 9, 7);

PlanDate _d(int offset) => _mon.addDays(offset);

TaskOccurrence _row(
  String id, {
  int from = 0,
  int? to,
  int? start,
  bool isAllDay = false,
}) => TaskOccurrence(
  task: Task(
    id: id,
    title: id,
    kind: TaskKind.single,
    timeZoneId: 'Asia/Shanghai',
    planDate: _d(from),
    startMinute: start == null ? null : MinuteOfDay(start),
    endDate: to == null ? null : _d(to),
    isAllDay: isAllDay,
  ),
);

DayBand _band(WeekBands w, String id) =>
    w.bands.singleWhere((b) => b.row.id == id);

void main() {
  group('横条：一条任务在一行里只有一条', () {
    test('周二到周四：一条，从第 1 格到第 3 格', () {
      final w = weekBands([_row('出差', from: 1, to: 3)], _mon);
      expect(w.bands, hasLength(1), reason: '按天算的实现会给出三条');
      final b = w.bands.single;
      expect((b.startIndex, b.endIndex), (1, 3));
      expect(b.spanDays, 3);
      expect(b.continuesBefore, isFalse);
      expect(b.continuesAfter, isFalse);
    });

    test('跨到下一行：这一行裁到周日，标明「还没完」', () {
      final w = weekBands([_row('长假', from: 4, to: 9)], _mon);
      final b = w.bands.single;
      expect((b.startIndex, b.endIndex), (4, 6));
      expect(b.continuesAfter, isTrue);
      expect(b.continuesBefore, isFalse);
    });

    test('从上一行延续过来：这一行从周一起', () {
      final w = weekBands([_row('长假', from: -3, to: 2)], _mon);
      final b = w.bands.single;
      expect((b.startIndex, b.endIndex), (0, 2));
      expect(b.continuesBefore, isTrue);
      expect(b.continuesAfter, isFalse);
    });

    test('整行贯穿：两头都标', () {
      final w = weekBands([_row('两周的活', from: -2, to: 9)], _mon);
      final b = w.bands.single;
      expect((b.startIndex, b.endIndex), (0, 6));
      expect(b.continuesBefore, isTrue);
      expect(b.continuesAfter, isTrue);
    });

    test('完全不沾这一行的不进来', () {
      expect(weekBands([_row('上周', from: -6, to: -2)], _mon).bands, isEmpty);
      expect(weekBands([_row('下周', from: 8, to: 10)], _mon).bands, isEmpty);
    });

    test('对照组：正好在周一结束的，还是要在', () {
      // 少了这条，一个把「结束日 <= 行首」当成不沾边的实现也能让上面绿。
      final w = weekBands([_row('上周末', from: -2, to: 0)], _mon);
      expect(w.bands.single.endIndex, 0);
    });
  });

  group('层号在一整行里统一分配', () {
    test('首尾相接的两条要分层，不能挤在同一层', () {
      // 周一到周三、周三到周五 —— 周三那格两条都在。
      // 按左闭右开算（不给 endIndex 加一）的话，它们会被判成不重叠，
      // 同层叠住，而屏幕上看起来就是「周三那天少了一条」。
      final w = weekBands([
        _row('甲', from: 0, to: 2),
        _row('乙', from: 2, to: 4),
      ], _mon);
      expect(_band(w, '甲').lane, isNot(_band(w, '乙').lane));
    });

    test('对照组：真正错开的两条复用同一层', () {
      // 周一到周二、周四到周五。都分层的话，一行里白白多占一层高度。
      final w = weekBands([
        _row('甲', from: 0, to: 1),
        _row('乙', from: 3, to: 4),
      ], _mon);
      expect(_band(w, '甲').lane, _band(w, '乙').lane);
      expect(w.laneCount, 1);
    });

    test('三条互相重叠 → 三层', () {
      final w = weekBands([
        for (var i = 0; i < 3; i++) _row('并行$i', from: 0, to: 5),
      ], _mon);
      expect(w.laneCount, 3);
      expect(w.bands.map((b) => b.lane).toSet(), {0, 1, 2});
    });

    test('输入顺序不影响层号', () {
      // 数据源的顺序不该决定谁在上面 —— 那会让同一个月进两次长得不一样。
      List<(String, int)> lanes(List<TaskOccurrence> rows) =>
          [for (final b in weekBands(rows, _mon).bands) (b.row.id, b.lane)]
            ..sort((a, b) => a.$1.compareTo(b.$1));
      final a = _row('甲', from: 0, to: 3);
      final b = _row('乙', from: 1, to: 5);
      expect(lanes([a, b]), lanes([b, a]));
    });
  });

  group('层数超限时，欠账记在**天**上', () {
    test('第四条不画，它盖到的那几格各欠一个', () {
      final w = weekBands([
        for (var i = 0; i < 3; i++) _row('并行$i', from: 0, to: 6),
        _row('第四条', from: 2, to: 3),
      ], _mon);

      expect(w.bands, hasLength(maxBandsPerWeek));
      expect(w.bands.any((b) => b.row.id == '第四条'), isFalse);
      // 只有周三周四欠着，不是整行。
      expect(w.hiddenByDay, [0, 0, 1, 1, 0, 0, 0]);
    });

    test('对照组：正好三条时一格都不欠', () {
      // 少了这条，一个「超过两条就折」的实现也能让上面绿。
      final w = weekBands([
        for (var i = 0; i < 3; i++) _row('并行$i', from: 0, to: 6),
      ], _mon);
      expect(w.bands, hasLength(3));
      expect(w.hiddenByDay, everyElement(0));
    });
  });

  group('谁走横条、谁走色点 —— 只有一个判据', () {
    test('全天任务哪怕只占一天也走横条（§3.2「全天/跨天」是两个条件）', () {
      // 用色点表示的话，纪念日会和「下午三点那件事」排在一起，
      // 而它们在日历上是不同的东西。
      final row = _row('纪念日', isAllDay: true);
      expect(showsAsBand(row), isTrue);
      expect(weekBands([row], _mon).bands, hasLength(1));
      expect(dayDots([row], _mon).rows, isEmpty);
    });

    test('有时刻、只占一天的走色点', () {
      final row = _row('晨会', start: 9 * 60);
      expect(showsAsBand(row), isFalse);
      expect(weekBands([row], _mon).bands, isEmpty);
      expect(dayDots([row], _mon).rows, hasLength(1));
    });

    test('每一行都恰好落在一处 —— 不重不漏', () {
      // 两处各写一遍判据的话，迟早有一类任务两处都进（一条三天的任务
      // 在三格里各留一个点，看起来像三件事）或者两处都不进（凭空消失）。
      final rows = [
        _row('全天单日', isAllDay: true),
        _row('全天跨日', to: 2, isAllDay: true),
        _row('定时单日', start: 9 * 60),
        _row('定时跨日', start: 22 * 60, to: 1),
        _row('没写结束'),
      ];

      final bandIds = weekBands(rows, _mon).bands.map((b) => b.row.id).toSet();
      final dotIds = <String>{
        for (var i = 0; i < 7; i++)
          ...dayDots(rows, _d(i)).rows.map((r) => r.id),
      };

      expect(bandIds.intersection(dotIds), isEmpty, reason: '有任务两处都画了');
      expect(
        bandIds.union(dotIds),
        rows.map((r) => r.id).toSet(),
        reason: '有任务两处都没画 —— 它在日历上凭空消失了',
      );
    });

    test('没有日期的两处都不进', () {
      // 它不落在任何一天上。这是唯一允许「两处都不在」的一类，
      // 所以上面那条不能拿它当夹具。
      const row = TaskOccurrence(
        task: Task(
          id: '总有一天',
          title: '总有一天',
          kind: TaskKind.single,
          timeZoneId: 'Asia/Shanghai',
        ),
      );
      expect(showsAsBand(row), isFalse);
      expect(weekBands([row], _mon).bands, isEmpty);
      expect(dayDots([row], _mon).rows, isEmpty);
    });
  });

  group('色点', () {
    test('最多三个，多的收进「+N」', () {
      final rows = [
        for (var i = 0; i < 5; i++) _row('事$i', start: (8 + i) * 60),
      ];
      final dots = dayDots(rows, _mon);
      expect(dots.rows, hasLength(maxDotsPerCell));
      expect(dots.overflow, 2);
    });

    test('对照组：正好三个时不显示「+N」', () {
      final rows = [
        for (var i = 0; i < 3; i++) _row('事$i', start: (8 + i) * 60),
      ];
      expect(dayDots(rows, _mon).overflow, 0);
    });

    test('被挤掉的横条也算进这一格的「+N」', () {
      // 不算的话，那一格显示「满了三条横条」，而第四条既没横条也没点，
      // 用户没有任何线索知道它存在。
      final dots = dayDots(const [], _mon, hiddenBands: 2);
      expect(dots.rows, isEmpty);
      expect(dots.overflow, 2);
      expect(dots.isEmpty, isFalse, reason: '只有欠账也不算空格子');
    });

    test('按时刻排，没时刻的垫底', () {
      final rows = [
        _row('晚', start: 20 * 60),
        _row('没时刻'),
        _row('早', start: 8 * 60),
      ];
      expect(dayDots(rows, _mon).rows.map((r) => r.id), ['早', '晚', '没时刻']);
    });

    test('只收这一天的', () {
      final rows = [_row('今天', start: 60), _row('明天', from: 1, start: 60)];
      expect(dayDots(rows, _mon).rows.map((r) => r.id), ['今天']);
      expect(dayDots(rows, _d(1)).rows.map((r) => r.id), ['明天']);
    });
  });
}

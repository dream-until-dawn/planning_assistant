/// 对账（notifications.md §5、N-10/N-11）。
///
/// 这一份与 `notification_planner_test` 分开：那边算「该排什么」，
/// 这边算「与已排的差在哪」。合在一起测的话，一个把两步都做错但错得
/// 互相抵消的实现能过 —— 而它们本来就是两个可以各自替换的判断。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/local_wall_time.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/domain/services/notification_planner.dart';
import 'package:planning_assistant/domain/services/notification_reconciler.dart';

final _base = DateTime.utc(2026, 3, 10, 1);

PlannedNotification _planned(String key, {int hoursFromBase = 0}) {
  final at = _base.add(Duration(hours: hoursFromBase));
  return PlannedNotification(
    key: key,
    trigger: LocalWallTime(
      date: const PlanDate(2026, 3, 10),
      minuteOfDay: MinuteOfDay.of(9 + hoursFromBase, 0),
      timeZoneId: 'Asia/Shanghai',
    ),
    triggerUtc: at,
    taskIds: const ['t1'],
    title: key,
  );
}

ScheduledNotification _existing(
  String key, {
  required int osId,
  int hoursFromBase = 0,
}) => ScheduledNotification(
  osId: osId,
  key: key,
  fireAtUtc: _base.add(Duration(hours: hoursFromBase)),
);

void main() {
  group('N-10 缺的补上', () {
    test('系统列表少 2 条 → 正好补这 2 条', () {
      final diff = reconcileSchedule(
        planned: [_planned('a'), _planned('b'), _planned('c')],
        existing: [_existing('a', osId: 1)],
      );

      expect(diff.toSchedule.map((p) => p.key), ['b', 'c']);
      expect(diff.toCancel, isEmpty, reason: '什么都没多，不该取消任何东西');
    });

    test('一条都没排过 → 全排', () {
      final diff = reconcileSchedule(
        planned: [_planned('a'), _planned('b')],
        existing: const [],
      );
      expect(diff.toSchedule, hasLength(2));
      expect(diff.toCancel, isEmpty);
    });
  });

  group('N-11 多的取消', () {
    test('系统列表多 3 条（任务已删）→ 正好取消这 3 条', () {
      final diff = reconcileSchedule(
        planned: [_planned('a')],
        existing: [
          _existing('a', osId: 1),
          _existing('x', osId: 2),
          _existing('y', osId: 3),
          _existing('z', osId: 4),
        ],
      );

      expect(diff.toCancel, [2, 3, 4]);
      expect(diff.toSchedule, isEmpty, reason: 'a 已经排着且时刻没变，不该重排');
    });

    test('计划空了 → 全取消', () {
      final diff = reconcileSchedule(
        planned: const [],
        existing: [_existing('a', osId: 1), _existing('b', osId: 2)],
      );
      expect(diff.toCancel, [1, 2]);
      expect(diff.toSchedule, isEmpty);
    });
  });

  group('**没变的一条都不动**', () {
    test('计划与已排完全一致 → 两边都空', () {
      // 稳定 key 换来的就是这个。少了它，每次续排都是全删全建 ——
      // 白占系统配额，而且每一次都是真的系统调用。
      final diff = reconcileSchedule(
        planned: [_planned('a'), _planned('b', hoursFromBase: 2)],
        existing: [
          _existing('a', osId: 1),
          _existing('b', osId: 2, hoursFromBase: 2),
        ],
      );
      expect(diff.toSchedule, isEmpty);
      expect(diff.toCancel, isEmpty);
    });
  });

  group('时刻变了：旧的取消，新的重排', () {
    test('同一个 key 换了时刻 → 同时出现在两边', () {
      // N-01 在这一层的落地：任务时间改了，已排的那条得挪。
      final diff = reconcileSchedule(
        planned: [_planned('a', hoursFromBase: 5)],
        existing: [_existing('a', osId: 7)],
      );

      expect(diff.toCancel, [7]);
      expect(diff.toSchedule.single.key, 'a');
      expect(
        diff.toSchedule.single.triggerUtc,
        _base.add(const Duration(hours: 5)),
      );
    });

    test('对照组：时刻一样就不重排', () {
      // 少了它，一个「凡是已排的都重排一遍」的实现在上面那条里也能过。
      final diff = reconcileSchedule(
        planned: [_planned('a')],
        existing: [_existing('a', osId: 7)],
      );
      expect(diff.toCancel, isEmpty);
      expect(diff.toSchedule, isEmpty);
    });
  });

  group('同一个 key 出现两行', () {
    test('留 osId 小的那条，另一条取消', () {
      // 一次发生只该有一条排期。留着的话它会在同一时刻响第二遍，
      // 而用户不知道为什么同一件事响了两次。
      final diff = reconcileSchedule(
        planned: [_planned('a')],
        existing: [_existing('a', osId: 9), _existing('a', osId: 4)],
      );

      expect(diff.toCancel, [9], reason: '该留下 osId 小的那条');
      expect(diff.toSchedule, isEmpty, reason: '留下的那条时刻没变，不必重排');
    });

    test('挑哪一条不看输入顺序', () {
      final a = reconcileSchedule(
        planned: [_planned('a')],
        existing: [_existing('a', osId: 9), _existing('a', osId: 4)],
      );
      final b = reconcileSchedule(
        planned: [_planned('a')],
        existing: [_existing('a', osId: 4), _existing('a', osId: 9)],
      );
      expect(a.toCancel, b.toCancel);
    });

    test('重复的那条同时也不在计划里 → 两条都取消，且不重复取消', () {
      final diff = reconcileSchedule(
        planned: const [],
        existing: [_existing('a', osId: 9), _existing('a', osId: 4)],
      );
      expect(diff.toCancel..sort(), [4, 9]);
      expect(diff.toCancel.toSet(), hasLength(2), reason: '同一个 osId 取消了两遍');
    });
  });
}

/// 续排的编排（notifications.md §2/§5、FR-NOTI-04）。
///
/// 判断都在两个纯函数里，这一份验的是**这个类自己剩下的那点东西**：
/// 顺序、权限门、精度降级、以及落库的时机。
///
/// 平台与存储都用假实现 —— 被替换掉的那两个东西里没有任何判断，
/// 所以假实现不会把要测的逻辑一起替换掉。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/local_wall_time.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/core/time/time_zone_resolver.dart';
import 'package:planning_assistant/domain/entities/occurrence.dart';
import 'package:planning_assistant/domain/entities/reminder.dart';
import 'package:planning_assistant/domain/repositories/scheduled_notification_store.dart';
import 'package:planning_assistant/domain/services/notification_planner.dart';
import 'package:planning_assistant/domain/services/notification_reconciler.dart';
import 'package:planning_assistant/domain/value_objects/occurrence_key.dart';
import 'package:planning_assistant/domain/value_objects/quiet_hours_behavior.dart';
import 'package:planning_assistant/features/reminder/application/reminder_scheduler.dart';
import 'package:planning_assistant/platform/notification/notification_platform.dart';
import 'package:timezone/data/latest.dart' as tzdata;

const _zone = 'Asia/Shanghai';
const _resolver = TzTimeZoneResolver(fixedCurrentZoneId: _zone);
final _now = DateTime.utc(2026, 3, 7, 16);

/// 记下每一次调用**以及顺序** —— 「先取消再排」正是靠这条流水验的。
final class _FakePlatform implements NotificationPlatform {
  _FakePlatform({this.canNotify = true, this.canScheduleExact = true});

  bool canNotify;
  bool canScheduleExact;

  final List<String> calls = [];
  final List<({int osId, ReminderScheduleMode mode, String key})> scheduled =
      [];
  final List<int> cancelled = [];
  var readyCount = 0;

  @override
  Future<NotificationCapabilities> capabilities() async =>
      (canNotify: canNotify, canScheduleExact: canScheduleExact);

  @override
  Future<void> ensureReady() async {
    readyCount++;
    calls.add('ready');
  }

  @override
  Future<void> schedule(
    PlannedNotification notification, {
    required int osId,
    required ReminderScheduleMode mode,
  }) async {
    calls.add('schedule:$osId');
    scheduled.add((osId: osId, mode: mode, key: notification.key));
  }

  @override
  Future<void> cancel(int osId) async {
    calls.add('cancel:$osId');
    cancelled.add(osId);
  }

  @override
  Future<List<int>> pluginPendingIds() async => [];

  @override
  Future<bool> requestNotifyPermission() async => canNotify;

  @override
  Future<void> openExactAlarmSettings() async {}
}

final class _FakeStore implements ScheduledNotificationStore {
  _FakeStore([List<ScheduledNotification>? seed])
    : rows = [...?seed],
      _next =
          (seed?.map((r) => r.osId).fold<int>(0, (a, b) => a > b ? a : b) ??
              0) +
          1;

  final List<ScheduledNotification> rows;
  int _next;

  @override
  Future<List<ScheduledNotification>> loadAll() async => [...rows];

  @override
  Future<int> nextOsId() async => _next++;

  @override
  Future<void> remove(int osId) async =>
      rows.removeWhere((r) => r.osId == osId);

  @override
  Future<void> save(ScheduledNotification row) async => rows.add(row);
}

Occurrence _occ({String taskId = 't1', int day = 10, int hour = 9}) {
  final start = LocalWallTime(
    date: PlanDate(2026, 3, day),
    minuteOfDay: MinuteOfDay.of(hour, 0),
    timeZoneId: _zone,
  );
  return Occurrence(
    taskId: taskId,
    key: OccurrenceKey.fromWallTime(start, isAllDay: false),
    start: start,
    isAllDay: false,
  );
}

ReminderOnOccurrence _pair({
  String taskId = 't1',
  int day = 10,
  int hour = 9,
}) => (
  occurrence: _occ(taskId: taskId, day: day, hour: hour),
  reminder: Reminder(
    id: 'r-$taskId',
    taskId: taskId,
    kind: ReminderKind.relativeToStart,
    offsetMinutes: 0,
  ),
  title: taskId,
);

const ReminderSettings _settings = (
  enabled: true,
  defaultOffsetMinutes: -15,
  allDayMinute: MinuteOfDay.midnight,
  quietHoursEnabled: false,
  quietStart: MinuteOfDay.midnight,
  quietEnd: MinuteOfDay.midnight,
  quietBehavior: QuietHoursBehavior.postpone,
  mergeThreshold: 3,
  maxScheduled: 400,
);

Future<ResyncOutcome> _run(
  _FakePlatform platform,
  _FakeStore store,
  List<ReminderOnOccurrence> pairs,
) => ReminderScheduler(platform, store).resync(
  pairs: pairs,
  settings: _settings,
  nowUtc: _now,
  window: (fromUtc: _now, toUtc: _now.add(const Duration(days: 14))),
  zones: _resolver,
);

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('权限门', () {
    test('没有通知权限 → 一条都不排，连渠道都不建', () {
      // 排了也不会显示，只是在系统里堆一批永远不会露面的闹钟。
      final platform = _FakePlatform(canNotify: false);
      final store = _FakeStore();

      return _run(platform, store, [_pair()]).then((out) {
        expect(out.blockedByPermission, isTrue);
        expect(out.mode, isNull);
        expect(platform.calls, isEmpty, reason: '连 ensureReady 都不该调');
        expect(store.rows, isEmpty);
      });
    });

    test('对照组：有权限就照排', () async {
      final platform = _FakePlatform();
      final out = await _run(platform, _FakeStore(), [_pair()]);
      expect(out.blockedByPermission, isFalse);
      expect(out.scheduled, 1);
    });
  });

  group('N-14 的可测那一半：精度降级', () {
    // 真机那一半已降级为不验收（notifications.md §11）——
    // 而「查询说不能精确时选哪个 mode」这一步在这里测得了，
    // 它也正是 N-14 真正要求的那个行为。
    test('精确可用 → exact', () async {
      final platform = _FakePlatform();
      final out = await _run(platform, _FakeStore(), [_pair()]);
      expect(out.mode, ReminderScheduleMode.exact);
      expect(platform.scheduled.single.mode, ReminderScheduleMode.exact);
    });

    test('精确不可用 → **inexact，而不是不排**', () async {
      final platform = _FakePlatform(canScheduleExact: false);
      final out = await _run(platform, _FakeStore(), [_pair()]);

      expect(out.mode, ReminderScheduleMode.inexact);
      expect(platform.scheduled.single.mode, ReminderScheduleMode.inexact);
      expect(out.scheduled, 1, reason: '降级是「精度降一档」，不是「不提醒了」');
    });
  });

  group('顺序', () {
    test('**先取消再排**', () async {
      // 时刻变了的那些同时出现在两边。先排后取消的话，新排的那条会被
      // 紧接着的取消按同一个 id 干掉，而它看起来只是「这条提醒没响」。
      final store = _FakeStore([
        ScheduledNotification(
          osId: 1,
          key: 't1#r-t1#2026-03-10T09:00',
          fireAtUtc: DateTime.utc(2026, 3, 9, 1),
        ),
      ]);
      final platform = _FakePlatform();

      await _run(platform, store, [_pair()]);

      // **先确认这真的是「同一个 key、时刻变了」那条路**：key 对不上的话，
      // 观察到的仍然是「取消一条 + 排一条」（旧的不在计划里、新的没排过），
      // 于是下面那条顺序断言在一个完全不同的场景里也成立 ——
      // 它验的就不再是它声称的那件事了。
      expect(
        platform.scheduled.single.key,
        't1#r-t1#2026-03-10T09:00',
        reason: '播进去的 key 与计划算出来的对不上，这条用例验的不是重排',
      );
      expect(platform.cancelled, [1]);
      expect(platform.scheduled, hasLength(1));
      expect(
        platform.calls.indexOf('cancel:1'),
        lessThan(platform.calls.indexWhere((c) => c.startsWith('schedule:'))),
      );
    });

    test('建渠道在排期之前', () async {
      final platform = _FakePlatform();
      await _run(platform, _FakeStore(), [_pair()]);
      expect(platform.calls.first, 'ready', reason: '渠道不存在时通知不会显示');
    });
  });

  group('落库', () {
    test('排出去的都记下来了，key 与时刻对得上', () async {
      final store = _FakeStore();
      await _run(_FakePlatform(), store, [_pair(), _pair(taskId: 't2')]);

      expect(store.rows, hasLength(2));
      expect(
        store.rows.map((r) => r.osId).toSet(),
        hasLength(2),
        reason: 'id 撞了',
      );
    });

    test('取消掉的从库里也抹掉了', () async {
      final store = _FakeStore([
        ScheduledNotification(
          osId: 1,
          key: '已经不在计划里',
          fireAtUtc: DateTime.utc(2026, 3, 9),
        ),
      ]);
      await _run(_FakePlatform(), store, const []);
      expect(store.rows, isEmpty);
    });

    test('**没变的一条都不动** —— 不重排也不重新落库', () async {
      final store = _FakeStore();
      final platform = _FakePlatform();

      await _run(platform, store, [_pair()]);
      final afterFirst = [...store.rows];

      await _run(platform, store, [_pair()]);

      expect(platform.scheduled, hasLength(1), reason: '第二次续排又排了一遍');
      expect(platform.cancelled, isEmpty);
      expect(store.rows.map((r) => r.osId), afterFirst.map((r) => r.osId));
    });
  });
}

/// 已排期通知的落库（data-model §3.10、notifications.md §5）。
///
/// 用真库（内存 SQLite），不打桩 —— 这一层要保的正是「写进去的读得回来」，
/// 打桩之后验的就只剩「我调了自己写的哪个方法」。
@TestOn('vm')
library;

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/data/database/app_database.dart';
import 'package:planning_assistant/data/repositories/scheduled_notification_store_impl.dart';
import 'package:planning_assistant/domain/services/notification_planner.dart';
import 'package:planning_assistant/domain/services/notification_reconciler.dart';
import 'package:planning_assistant/domain/value_objects/occurrence_key.dart';

final _at = DateTime.utc(2026, 3, 10, 1);

String _key(String taskId, String reminderId, String occ) => notificationKeyOf(
  taskId: taskId,
  reminderId: reminderId,
  occurrenceKey: OccurrenceKey.parse(occ),
);

void main() {
  late AppDatabase db;
  late DriftScheduledNotificationStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftScheduledNotificationStore(db);
  });
  tearDown(() => db.close());

  group('存取往返', () {
    test('写进去的读得回来，key 与时刻都对得上', () async {
      final row = ScheduledNotification(
        osId: 5,
        key: _key('t1', 'r1', '2026-03-10T09:00'),
        fireAtUtc: _at,
      );
      await store.save(row);

      final back = await store.loadAll();
      expect(back, hasLength(1));
      expect(back.single.osId, 5);
      expect(back.single.key, row.key, reason: 'key 拆开又拼回来变了样');
      expect(back.single.fireAtUtc, _at);
    });

    test('全天那种 key（没有时刻）也往返得了', () async {
      // `OccurrenceKey` 有两种形态。只测带时刻的那种，
      // 一个把日期硬当成 `yyyy-MM-ddTHH:mm` 解析的实现也能过。
      final row = ScheduledNotification(
        osId: 1,
        key: _key('t1', 'r1', '2026-03-10'),
        fireAtUtc: _at,
      );
      await store.save(row);
      expect((await store.loadAll()).single.key, row.key);
    });

    test('同一个 osId 再写一次是覆盖，不是插出第二行', () async {
      await store.save(
        ScheduledNotification(
          osId: 5,
          key: _key('t1', 'r1', '2026-03-10T09:00'),
          fireAtUtc: _at,
        ),
      );
      await store.save(
        ScheduledNotification(
          osId: 5,
          key: _key('t1', 'r1', '2026-03-10T09:00'),
          fireAtUtc: _at.add(const Duration(hours: 2)),
        ),
      );

      final back = await store.loadAll();
      expect(back, hasLength(1));
      expect(back.single.fireAtUtc, _at.add(const Duration(hours: 2)));
    });

    test('形状不对的 key 抛异常，不悄悄落一行坏数据', () {
      expect(
        () => store.save(
          ScheduledNotification(osId: 1, key: '没有分隔符', fireAtUtc: _at),
        ),
        throwsFormatException,
      );
    });
  });

  group('remove', () {
    test('删掉之后读不到了', () async {
      await store.save(
        ScheduledNotification(
          osId: 5,
          key: _key('t1', 'r1', '2026-03-10T09:00'),
          fireAtUtc: _at,
        ),
      );
      await store.remove(5);
      expect(await store.loadAll(), isEmpty);
    });

    test('删一个不存在的 id 是空操作，不抛', () async {
      await store.remove(999);
      expect(await store.loadAll(), isEmpty);
    });

    test('只删指定那一行', () async {
      for (var i = 1; i <= 3; i++) {
        await store.save(
          ScheduledNotification(
            osId: i,
            key: _key('t$i', 'r$i', '2026-03-10T09:00'),
            fireAtUtc: _at,
          ),
        );
      }
      await store.remove(2);
      expect((await store.loadAll()).map((r) => r.osId), [1, 3]);
    });
  });

  group('nextOsId', () {
    test('空表从 1 开始', () async {
      expect(await store.nextOsId(), 1);
    });

    test('**取 max + 1，不是 count + 1**', () async {
      // count + 1 在「删掉中间几行」之后会撞上还活着的 id ——
      // 撞了的后果是排第二条时系统把第一条顶掉，且没有任何报错。
      for (final id in [1, 2, 3]) {
        await store.save(
          ScheduledNotification(
            osId: id,
            key: _key('t$id', 'r$id', '2026-03-10T09:00'),
            fireAtUtc: _at,
          ),
        );
      }
      await store.remove(1);
      await store.remove(2);

      expect(await store.loadAll(), hasLength(1), reason: '前提：只剩一行了');
      expect(await store.nextOsId(), 4, reason: 'count+1 会给出 2，而 2 刚被删、3 还活着');
    });

    test('**id 永不复用** —— 连最大那条被取消之后也不复用', () async {
      // 上一版这里钉的是相反的行为（复用），而它安全的理由写在
      // 另一个文件里（`resync` 先取消再删库）。评审指出那个形状不好：
      // **跨文件的时序约定迟早会被人对调，而不存在的约定不会。**
      // 所以约定被去掉了 —— 取消的那一行留成墓碑，max 就掉不下去。
      await store.save(
        ScheduledNotification(
          osId: 9,
          key: _key('t1', 'r1', '2026-03-10T09:00'),
          fireAtUtc: _at,
        ),
      );
      await store.remove(9);

      expect(await store.loadAll(), isEmpty, reason: '取消之后不该再读得到');
      expect(await store.nextOsId(), 10, reason: '复用了刚被取消的 id');
    });

    test('墓碑只留最高那一行 —— 这张表不会一直涨', () async {
      // 全留的话表无限长，全删的话 max 会掉、id 又复用了。
      // 留最高的那一行是这两者之间唯一的解，开销 O(1)。
      for (final id in [1, 2, 3]) {
        await store.save(
          ScheduledNotification(
            osId: id,
            key: _key('t$id', 'r$id', '2026-03-10T09:00'),
            fireAtUtc: _at,
          ),
        );
      }
      for (final id in [1, 2, 3]) {
        await store.remove(id);
      }

      final rows = await db.select(db.scheduledNotifications).get();
      expect(rows.map((r) => r.osNotificationId), [3], reason: '墓碑不止一行');
      expect(await store.nextOsId(), 4);
    });
  });

  group('状态列', () {
    test('只读 scheduled 的行', () async {
      // 表里还允许 fired / cancelled。它们要是也被读回来，
      // 对账会把一条早就响过的通知当成「还排着」，于是永远不补排。
      await db
          .into(db.scheduledNotifications)
          .insert(
            ScheduledNotificationsCompanion.insert(
              osNotificationId: const Value(3),
              reminderId: 'r1',
              taskId: 't1',
              occurrenceKey: '2026-03-10T09:00',
              fireAtInstant: _at.millisecondsSinceEpoch,
              state: 'fired',
            ),
          );
      await store.save(
        ScheduledNotification(
          osId: 4,
          key: _key('t2', 'r2', '2026-03-10T10:00'),
          fireAtUtc: _at,
        ),
      );

      expect((await store.loadAll()).map((r) => r.osId), [4]);
    });
  });
}

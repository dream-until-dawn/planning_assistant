/// [ScheduledNotificationStore] 的 Drift 实现。
///
/// ## 为什么这张表**不走命令管道**
///
/// 「所有数据变更走同一条 `TaskCommand` 管道」是给**要同步的实体**定的
/// （overview §4）—— 管道的产出是 `change_log`，而 change_log 是同步信封
/// 的来源。`scheduled_notifications` 是**设备本地**的：系统通知 ID 在别的
/// 设备上毫无意义，同过去只会造成误取消（表定义里写着这条）。
///
/// 让它进 change_log 的话，每次续排都会往 outbox 里灌一批注定要被对端丢弃
/// 的变更 —— 而且回放测试会因为「回放后 os id 不一样」而永远对不上。
/// 与导入导出、change_log 回放走裸路径是同一个理由：它们不是「操作」。
library;

import 'package:drift/drift.dart';

import '../../domain/repositories/scheduled_notification_store.dart';
import '../../domain/services/notification_planner.dart';
import '../../domain/services/notification_reconciler.dart';
import '../../domain/value_objects/occurrence_key.dart';
import '../database/app_database.dart';

/// 已排期通知的状态列取值（表定义里那三个）。
///
/// V1 写 `scheduled` 与 `cancelled` 两种。`fired` 不写 —— 它要靠通知回调
/// 才知道，而那条回调在应用没运行时收不到。
const String kScheduledState = 'scheduled';

/// 取消掉的那一条**留一行墓碑**，不物理删。
///
/// 这一行存在的唯一理由是**让 `max(osNotificationId)` 不会掉下去**，
/// 见 [DriftScheduledNotificationStore.nextOsId]。
const String kCancelledState = 'cancelled';

final class DriftScheduledNotificationStore
    implements ScheduledNotificationStore {
  const DriftScheduledNotificationStore(this._db);

  final AppDatabase _db;

  @override
  Future<List<ScheduledNotification>> loadAll() async {
    final rows = await (_db.select(
      _db.scheduledNotifications,
    )..where((t) => t.state.equals(kScheduledState))).get();

    return [
      for (final r in rows)
        ScheduledNotification(
          osId: r.osNotificationId,
          // 拼回对账认的那个串 —— **走 `notificationKeyOf`，不在这里手拼**。
          key: notificationKeyOf(
            taskId: r.taskId,
            reminderId: r.reminderId,
            occurrenceKey: OccurrenceKey.parse(r.occurrenceKey),
          ),
          fireAtUtc: DateTime.fromMillisecondsSinceEpoch(
            r.fireAtInstant,
            isUtc: true,
          ),
        ),
    ];
  }

  @override
  Future<void> save(ScheduledNotification row) async {
    final parts = parseNotificationKey(row.key);
    await _db
        .into(_db.scheduledNotifications)
        .insertOnConflictUpdate(
          ScheduledNotificationsCompanion.insert(
            osNotificationId: Value(row.osId),
            reminderId: parts.reminderId,
            taskId: parts.taskId,
            occurrenceKey: parts.occurrenceKey.value,
            fireAtInstant: row.fireAtUtc.millisecondsSinceEpoch,
            state: kScheduledState,
          ),
        );
  }

  @override
  Future<void> remove(int osId) async {
    await _db.transaction(() async {
      // **标成已取消，不物理删** —— 删掉最大那条会让下一个 id 掉回去，
      // 于是新排的通知复用一个刚被取消的 id。
      await (_db.update(
        _db.scheduledNotifications,
      )..where((t) => t.osNotificationId.equals(osId))).write(
        const ScheduledNotificationsCompanion(state: Value(kCancelledState)),
      );

      // 墓碑只留**最高的那一行**：它是撑住 `max` 的那一个，其余的留着
      // 只会让这张表无限长。留一行的开销是 O(1)，而「全删」会让 max 掉、
      // 「全留」会让表一直涨。
      final highest = await _highestCancelled();
      if (highest == null) return;
      await (_db.delete(_db.scheduledNotifications)..where(
            (t) =>
                t.state.equals(kCancelledState) &
                t.osNotificationId.isSmallerThanValue(highest),
          ))
          .go();
    });
  }

  Future<int?> _highestCancelled() async {
    final q = _db.selectOnly(_db.scheduledNotifications)
      ..addColumns([_db.scheduledNotifications.osNotificationId.max()])
      ..where(_db.scheduledNotifications.state.equals(kCancelledState));
    return q
        .map((r) => r.read(_db.scheduledNotifications.osNotificationId.max()))
        .getSingleOrNull();
  }

  @override
  Future<int> nextOsId() async {
    // **max + 1，而 max 算上墓碑行 —— 于是 id 永不复用。**
    //
    // 上一版的 max 只算活着的行，所以删掉最大那条之后 id 会被复用。
    // 那**当时**是安全的，但安全的理由在另一个文件里：
    // `ReminderScheduler.resync` 先让系统取消、再从库里删。
    // 评审指出这个形状不好 —— **跨文件的时序约定迟早会被人对调，
    // 而不存在的约定不会**。所以约定被去掉了，不是加一层小心。
    //
    // count + 1 更不行：删掉中间几行之后它会撞上还活着的 id，
    // 而撞了的后果是排第二条时系统把第一条顶掉，且没有任何报错。
    final query = _db.selectOnly(_db.scheduledNotifications)
      ..addColumns([_db.scheduledNotifications.osNotificationId.max()]);
    final maxId = await query
        .map((r) => r.read(_db.scheduledNotifications.osNotificationId.max()))
        .getSingleOrNull();
    return (maxId ?? 0) + 1;
  }
}

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
/// V1 只写 `scheduled` 一种：`fired` 要靠通知回调才知道，而那条回调在
/// 应用没运行时收不到；`cancelled` 的行我们直接删掉 —— 留着一行
/// 「已取消」除了让对账多一种要排除的状态，没有别的用处。
const String kScheduledState = 'scheduled';

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
    await (_db.delete(
      _db.scheduledNotifications,
    )..where((t) => t.osNotificationId.equals(osId))).go();
  }

  @override
  Future<int> nextOsId() async {
    // **max + 1，不是 count + 1**：删掉中间几行之后 count 会撞上还活着的 id，
    // 而撞了的后果是排第二条时系统把第一条顶掉，且没有任何报错。
    //
    // **max 取的是还活着的行，所以删掉最大那条之后 id 会被复用。**
    // 这是安全的，但安全的理由不在这儿，而在 `ReminderScheduler.resync`：
    // 它**先让系统取消、再从库里删**。所以一个能被复用的 id，
    // 对应的系统闹钟必定已经不在了。
    //
    // 反过来说：将来若有谁把「删库」挪到「取消」之前，复用就会顶掉
    // 一条还活着的闹钟 —— 那时要改的是这里（改成单独存一个计数器），
    // 不是在那边补一层小心。
    final query = _db.selectOnly(_db.scheduledNotifications)
      ..addColumns([_db.scheduledNotifications.osNotificationId.max()]);
    final maxId = await query
        .map((r) => r.read(_db.scheduledNotifications.osNotificationId.max()))
        .getSingleOrNull();
    return (maxId ?? 0) + 1;
  }
}

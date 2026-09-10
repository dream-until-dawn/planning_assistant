/// 已排期通知的落库口（`scheduled_notifications` 表，data-model §3.10）。
///
/// **单独一个端口，不并进 `TaskRepository`**：这张表是**设备本地**的
/// （系统通知 ID 同步到别的设备毫无意义，还会造成误取消 —— 表定义里
/// 写着这条），而 `TaskRepository` 管的全是要同步的实体。
/// 混在一起的话，「哪些表进同步信封」这个问题在接口层面就说不清了。
library;

import '../services/notification_reconciler.dart';

abstract interface class ScheduledNotificationStore {
  /// 当前记着的全部排期。
  Future<List<ScheduledNotification>> loadAll();

  /// 记下一条新排的。
  Future<void> save(ScheduledNotification row);

  /// 抹掉一条（已取消或已触发）。
  Future<void> remove(int osId);

  /// 分配一个没被用过的系统通知 ID。
  ///
  /// **由存储分配而不是从 key 哈希出来**：哈希会撞，而撞了的后果是
  /// 两条提醒共用一个 id —— 排第二条时系统把第一条**顶掉**，
  /// 而且没有任何报错。少一条提醒是查不出来的那种缺陷。
  Future<int> nextOsId();
}

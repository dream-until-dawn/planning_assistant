/// 排期能力的**接口**（notifications.md §2）。
///
/// 排期的判断全在 `planNotifications` / `reconcileSchedule` 两个纯函数里，
/// 这一层薄到只剩「照计划调 schedule / cancel」—— 所以它可以用一个假实现
/// 完整替换，而被替换掉的东西里没有任何判断。
///
/// **接口住在 `platform/`，实现也住在这儿**：`features/reminder/` 依赖它，
/// 而 platform 不得依赖 features（module-map §3）。
library;

import '../../domain/services/notification_planner.dart';

/// 当前这台设备允许我们做到哪一步（FR-NOTI-04）。
typedef NotificationCapabilities = ({
  /// 通知权限拿到了没有。**没有就一条都别排** —— 排了也不会显示，
  /// 而系统里堆着一批永远不会露面的闹钟。
  bool canNotify,

  /// 精确闹钟可不可用。不可用时降级，见 [ReminderScheduleMode]。
  bool canScheduleExact,
});

/// 排期精度。**两档，不是五档**。
///
/// 插件的 `AndroidScheduleMode` 有五个取值，但这一层只暴露两个 ——
/// 「要不要精确」是我们唯一会做的决定，另外三个取值（`exact`、`inexact`、
/// `alarmClock`）在本产品里都已被否掉，理由写在 notifications.md §4.4：
/// 前两个在 Doze 下不执行，`alarmClock` 会在状态栏常驻闹钟图标。
///
/// 把五个取值原样透出来，等于把那三条已经做完的决定又摊回给调用方。
enum ReminderScheduleMode {
  /// 精确且能穿透 Doze（`exactAllowWhileIdle`）。
  exact,

  /// 不精确但仍能穿透 Doze（`inexactAllowWhileIdle`）。
  ///
  /// **降级目标是它，不是 `inexact`**：后者在 Doze 下可能被推到下一个
  /// 维护窗口，对「今天 9 点的会」等于失效。既然已经放弃精确，
  /// 至少要保住「会响」。
  inexact,
}

/// 通知平台。
abstract interface class NotificationPlatform {
  /// 建渠道、装回调。**排期前必须调一次**（渠道不存在时通知不会显示）。
  Future<void> ensureReady();

  /// 查当前能力，不弹任何界面。
  Future<NotificationCapabilities> capabilities();

  /// 申请通知权限（Android 13+ 才有实际动作）。
  Future<bool> requestNotifyPermission();

  /// 跳到系统的「精确闹钟」设置页。**这一步只能引导，不能代劳。**
  Future<void> openExactAlarmSettings();

  /// 排一条。[osId] 由调用方分配并落库 —— 取消时要用它。
  Future<void> schedule(
    PlannedNotification notification, {
    required int osId,
    required ReminderScheduleMode mode,
  });

  Future<void> cancel(int osId);

  /// 插件那份排期清单里的 id。
  ///
  /// ⚠️ **这不是系统的清单**：插件读的是它自己写在 SharedPreferences 里的
  /// JSON（notifications.md §5）。用它对账查得出「我们的库与插件记账不一致」，
  /// 查不出「系统把闹钟丢了」。
  Future<List<int>> pluginPendingIds();
}

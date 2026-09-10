/// 把「该排什么」变成「真的排出去」（notifications.md §2、FR-NOTI-01/02）。
///
/// 三步，每一步的判断都在别处：
///
/// 1. `planNotifications` 算出窗口内该排的（纯函数）；
/// 2. `reconcileSchedule` 与已排的比出差（纯函数）；
/// 3. 这里照着差去调平台，并把结果落库。
///
/// 所以这个类自己**只剩顺序与错误处理**。它值得单独存在，是因为
/// 那个顺序有两处不能颠倒 —— 见 [resync] 里的注释。
library;

import '../../../core/time/time_zone_resolver.dart';
import '../../../domain/repositories/scheduled_notification_store.dart';
import '../../../domain/services/notification_planner.dart';
import '../../../domain/services/notification_reconciler.dart';
import '../../../platform/notification/notification_platform.dart';

/// 一次续排的结果。给设置页的状态卡片用（FR-NOTI-04 要求「UI 状态可查」）。
typedef ResyncOutcome = ({
  /// 通知权限没拿到 —— 这一轮一条都没排。
  bool blockedByPermission,

  /// 这一轮实际用的精度。[blockedByPermission] 为真时是 null。
  ReminderScheduleMode? mode,

  int scheduled,
  int cancelled,
});

final class ReminderScheduler {
  /// 位置参数，同 `CommandDispatcher(repo, clock)` 那一套 ——
  /// 具名的话字段名要公开（Dart 不允许 `this._x` 当具名参数），
  /// 而这两个协作者不该从外面读得到。
  const ReminderScheduler(this._platform, this._store);

  final NotificationPlatform _platform;
  final ScheduledNotificationStore _store;

  /// 按当前数据把窗口内的排期重算一遍。
  ///
  /// **这是 §5 说的第 3 道保险，也是唯一真的兜底那道**：它不问「系统还剩
  /// 什么」，只按数据重算 —— 前两道（插件的 boot receiver、
  /// `pendingNotificationRequests` 对账）读的是同一份 SharedPreferences，
  /// 系统真丢了闹钟它们都发现不了。
  Future<ResyncOutcome> resync({
    required List<ReminderOnOccurrence> pairs,
    required ReminderSettings settings,
    required DateTime nowUtc,
    required ScheduleWindow window,
    required TimeZoneResolver zones,
  }) async {
    final caps = await _platform.capabilities();

    // 没有通知权限就**一条都不排**（§4.4）。排了也不会显示，
    // 只是在系统里堆一批永远不会露面的闹钟，白占那个上限。
    if (!caps.canNotify) {
      return (
        blockedByPermission: true,
        mode: null,
        scheduled: 0,
        cancelled: 0,
      );
    }

    // 渠道不存在时通知不显示，所以排期之前必须先建。
    await _platform.ensureReady();

    final planned = planNotifications(
      pairs: pairs,
      settings: settings,
      nowUtc: nowUtc,
      window: window,
      zones: zones,
    );
    final diff = reconcileSchedule(
      planned: planned,
      existing: await _store.loadAll(),
    );

    // 精确不可用就降级（N-14 的判断这一半）。
    final mode = caps.canScheduleExact
        ? ReminderScheduleMode.exact
        : ReminderScheduleMode.inexact;

    // **先取消再排，顺序不能反。** 时刻变了的那些同时出现在两边，
    // 先排后取消的话，新排的那条会被紧接着的取消按同一个 id 干掉 ——
    // 而它看起来只是「这条提醒没响」。
    for (final osId in diff.toCancel) {
      await _platform.cancel(osId);
      await _store.remove(osId);
    }

    for (final p in diff.toSchedule) {
      final osId = await _store.nextOsId();
      await _platform.schedule(p, osId: osId, mode: mode);
      // **排完才落库**：反过来的话，`schedule` 抛异常会留下一条
      // 「库里说排了、系统里没有」的记录，而对账把它当成「已排」，
      // 于是那条提醒再也补不回来。
      await _store.save(
        ScheduledNotification(osId: osId, key: p.key, fireAtUtc: p.triggerUtc),
      );
    }

    return (
      blockedByPermission: false,
      mode: mode,
      scheduled: diff.toSchedule.length,
      cancelled: diff.toCancel.length,
    );
  }
}

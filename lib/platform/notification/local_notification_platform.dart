/// [NotificationPlatform] 的 `flutter_local_notifications` 实现。
///
/// 这一层**不做任何判断** —— 该排什么、排在什么时刻、超了上限丢哪些，
/// 全在两个纯函数里定好了。这里只负责把 [PlannedNotification] 翻译成
/// 插件的入参，以及把插件的能力查询翻译成 [NotificationCapabilities]。
///
/// 判断留在这一层的话，它就只能靠真机验证 —— 而真机那三项已经降级
/// （notifications.md §11）。
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/services/notification_planner.dart';
import 'notification_platform.dart';

/// 常规提醒的渠道（notifications.md §9）。
///
/// **渠道建好之后重要性改不了**（Android 限制），所以初版就要定对；
/// 真要改只能换渠道 ID，而换 ID 会让用户之前的免打扰设置失效。
const AndroidNotificationChannel kReminderChannel = AndroidNotificationChannel(
  'task_reminder',
  '任务提醒',
  description: '到点提醒你该做什么',
  importance: Importance.high,
);

/// 合并摘要的渠道。重要性低一档 —— 它是「这一刻有几件事」的汇总，
/// 不该和单条提醒一样打断人。
const AndroidNotificationChannel kDigestChannel = AndroidNotificationChannel(
  'task_digest',
  '每日概览',
  description: '同一时刻有多项安排时的汇总',
);

final class LocalNotificationPlatform implements NotificationPlatform {
  LocalNotificationPlatform(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> ensureReady() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final android = _android;
    if (android == null) return;
    await android.createNotificationChannel(kReminderChannel);
    await android.createNotificationChannel(kDigestChannel);
  }

  @override
  Future<NotificationCapabilities> capabilities() async {
    final android = _android;
    if (android == null) {
      // 非 Android（测试宿主、将来的桌面端）：不谎报能力。
      return (canNotify: false, canScheduleExact: false);
    }
    // **两个查询在旧系统上恒为 true**（版本门 API 31 / 33，见 §4.3）。
    // 这里照实返回 —— 把「这台机器上这个查询没有意义」写进判断的话，
    // 就得在这一层判断系统版本，而那正是要留给上层的东西。
    final canNotify = await android.areNotificationsEnabled() ?? false;
    final canExact = await android.canScheduleExactNotifications() ?? false;
    return (canNotify: canNotify, canScheduleExact: canExact);
  }

  @override
  Future<bool> requestNotifyPermission() async =>
      await _android?.requestNotificationsPermission() ?? false;

  @override
  Future<void> openExactAlarmSettings() async {
    // 插件把「跳设置页」和「请求权限」做成了同一个调用。
    await _android?.requestExactAlarmsPermission();
  }

  @override
  Future<void> schedule(
    PlannedNotification notification, {
    required int osId,
    required ReminderScheduleMode mode,
  }) async {
    final channel = notification.isDigest ? kDigestChannel : kReminderChannel;
    await _plugin.zonedSchedule(
      id: osId,
      title: notification.title,
      body: notification.body,
      // **墙钟 + 时区现场解析成 TZDateTime**，不用已经算好的
      // `triggerUtc`：插件要的就是带时区的本地时刻，而墙钟才是
      // 时区变了之后仍然正确的那一份（§6）。
      scheduledDate: tz.TZDateTime(
        tz.getLocation(notification.trigger.timeZoneId),
        notification.trigger.date.year,
        notification.trigger.date.month,
        notification.trigger.date.day,
        notification.trigger.minuteOfDay.hour,
        notification.trigger.minuteOfDay.minute,
      ),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
        ),
      ),
      androidScheduleMode: switch (mode) {
        ReminderScheduleMode.exact => AndroidScheduleMode.exactAllowWhileIdle,
        ReminderScheduleMode.inexact =>
          AndroidScheduleMode.inexactAllowWhileIdle,
      },
      // 深链到那条任务（§8）。摘要没有单一任务，带空串。
      payload: notification.isDigest ? '' : notification.taskIds.first,
    );
  }

  @override
  Future<void> cancel(int osId) => _plugin.cancel(id: osId);

  @override
  Future<List<int>> pluginPendingIds() async {
    final pending = await _plugin.pendingNotificationRequests();
    return [for (final p in pending) p.id];
  }
}

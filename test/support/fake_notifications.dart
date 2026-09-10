/// 通知平台与排期存储的假实现，给 widget 测试用。
///
/// **不是「不做事」的空壳**：它们把每一次调用都记下来，于是
/// 「续排到底有没有真的发生」在测试里问得出来 —— 而这正是这块功能
/// 最容易悄悄断掉的地方（接不上就等于没有）。
library;

import 'package:planning_assistant/domain/repositories/scheduled_notification_store.dart';
import 'package:planning_assistant/domain/services/notification_planner.dart';
import 'package:planning_assistant/domain/services/notification_reconciler.dart';
import 'package:planning_assistant/platform/notification/notification_platform.dart';

/// 记账式的假平台。
final class FakeNotificationPlatform implements NotificationPlatform {
  FakeNotificationPlatform({
    this.canNotify = true,
    this.canScheduleExact = true,
  });

  bool canNotify;
  bool canScheduleExact;

  final List<PlannedNotification> scheduled = [];
  final List<int> cancelled = [];
  var readyCount = 0;
  var capabilityChecks = 0;

  /// 申请通知权限调了几次。状态卡片上那个按钮**有没有真的干活**问它 ——
  /// 画一个按钮摆着与真的去申请，在界面上长得一模一样。
  var permissionRequests = 0;

  /// 跳系统「精确闹钟」设置页调了几次。
  var exactSettingsOpened = 0;

  /// 至今排出去的那些通知的 key，按排的顺序。
  List<String> get scheduledKeys => [for (final n in scheduled) n.key];

  @override
  Future<NotificationCapabilities> capabilities() async {
    capabilityChecks++;
    return (canNotify: canNotify, canScheduleExact: canScheduleExact);
  }

  @override
  Future<void> ensureReady() async => readyCount++;

  @override
  Future<void> schedule(
    PlannedNotification notification, {
    required int osId,
    required ReminderScheduleMode mode,
  }) async {
    scheduled.add(notification);
    lastMode = mode;
  }

  ReminderScheduleMode? lastMode;

  @override
  Future<void> cancel(int osId) async => cancelled.add(osId);

  @override
  Future<List<int>> pluginPendingIds() async => const [];

  @override
  Future<bool> requestNotifyPermission() async {
    permissionRequests++;
    return canNotify;
  }

  @override
  Future<void> openExactAlarmSettings() async => exactSettingsOpened++;
}

/// 内存版排期存储。
final class InMemoryScheduledNotificationStore
    implements ScheduledNotificationStore {
  final List<ScheduledNotification> rows = [];
  int _next = 1;

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

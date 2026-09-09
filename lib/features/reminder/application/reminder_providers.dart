/// 提醒这一块的接线（notifications.md §2/§3）。
///
/// 前面几层（纯函数、平台接口、编排）都能各自测，但**接不上就等于没有** ——
/// 这个仓库反复撞的就是那一种：模型有旋钮、界面够不着。所以这个文件的
/// 每一条 provider 都要有一条用例从真的触发点走到真的调用。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../core/time/minute_of_day.dart';
import '../../../domain/entities/reminder.dart';
import '../../../domain/recurrence/recurrence_engine.dart';
import '../../../domain/repositories/scheduled_notification_store.dart';
import '../../../domain/services/notification_planner.dart';
import '../../../platform/notification/local_notification_platform.dart';
import '../../../platform/notification/notification_platform.dart';
import '../../settings/application/registry.dart';
import '../../settings/application/settings_providers.dart';
import '../../views/shared/application/occurrence_expansion.dart';
import '../../views/shared/application/task_providers.dart';
import 'reminder_pairs.dart';
import 'reminder_scheduler.dart';

/// 通知平台。测试里覆盖成假实现。
final notificationPlatformProvider = Provider<NotificationPlatform>(
  (ref) => LocalNotificationPlatform(FlutterLocalNotificationsPlugin()),
);

/// 已排期通知的落库口。**与仓储一样在组合根注入**（`bootstrap.dart`）——
/// 这一层拿不到 `AppDatabase`，那是 data 层的东西。
final scheduledNotificationStoreProvider = Provider<ScheduledNotificationStore>(
  (ref) => throw StateError(
    'scheduledNotificationStoreProvider 必须在 ProviderScope 的 overrides 中提供',
  ),
);

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => ReminderScheduler(
    ref.watch(notificationPlatformProvider),
    ref.watch(scheduledNotificationStoreProvider),
  ),
);

/// 按 taskId 分组，**纯函数**。
///
/// 单独抽出来是因为续排**不能走派生 provider**，见 [remindersByTaskProvider]。
Map<String, List<Reminder>> groupRemindersByTask(List<Reminder> all) {
  final out = <String, List<Reminder>>{};
  for (final r in all) {
    if (r.deletedAt != null) continue;
    (out[r.taskId] ??= []).add(r);
  }
  return out;
}

/// 全部提醒，按 taskId 索引。**给界面用**。
///
/// ## 续排不读它
///
/// 一个**没人 watch 的派生 provider，`read` 出来可能是旧值**：
/// 上游 `allRemindersProvider` 已经推到 `-60` 了，这一个 `read` 回来还是
/// `-15`。表现极难认：监听触发了、次数也对，唯独那一轮算出「什么都没变」，
/// 而紧接着手动再调一次立刻就对。
///
/// 所以 `resyncNow` 直接读源头的 `allRemindersProvider`，
/// 自己用 [groupRemindersByTask] 分组 —— 中间少一层，就少一个会滞后的缓存。
final remindersByTaskProvider = Provider<Map<String, List<Reminder>>>(
  (ref) => groupRemindersByTask(switch (ref.watch(allRemindersProvider)) {
    AsyncData(:final value) => value,
    _ => const <Reminder>[],
  }),
);

final allRemindersProvider = StreamProvider<List<Reminder>>(
  (ref) => ref.watch(taskRepositoryProvider).watchAllReminders(),
);

/// 十二条 `reminder.*` 的当前取值，凑成排期要的那个记录。
final reminderSettingsProvider = Provider<ReminderSettings>(
  (ref) => (
    enabled: settingOf(ref, reminderEnabled),
    defaultOffsetMinutes: settingOf(ref, defaultReminderOffset),
    allDayMinute: MinuteOfDay(settingOf(ref, allDayReminderMinute)),
    quietHoursEnabled: settingOf(ref, quietHoursEnabled),
    quietStart: MinuteOfDay(settingOf(ref, quietHoursStart)),
    quietEnd: MinuteOfDay(settingOf(ref, quietHoursEnd)),
    quietBehavior: settingOf(ref, quietHoursBehavior),
    mergeThreshold: settingOf(ref, reminderMergeThreshold),
    maxScheduled: settingOf(ref, reminderMaxScheduled),
  ),
);

/// 触发一轮续排。
///
/// **做成 Notifier，而不是一个抓着 `Ref` 的普通对象。**
/// 后者一开始是那么写的：`Provider((ref) => ReminderSync(ref))` 把 ref 存进
/// 长命对象里。表现是**改了数据之后那一轮续排读到的还是旧值** ——
/// 监听确实触发了（能数出调用次数），手动再调一次立刻就对，
/// 唯独被触发的那一次算出「什么都没变」。抓着的那个 ref 属于一个
/// 已经不在的 provider 实例。
///
/// Notifier 的 `ref` 与它自己同生共死，被 watch 着就一直有效。
final class ReminderSyncNotifier extends Notifier<void> {
  @override
  void build() {}

  Ref get _ref => ref;

  /// 按当前数据把窗口内的排期重算一遍。
  ///
  /// **窗口从「现在」起算，不从今天零点**：从零点起算的话，今天已经过去的
  /// 那些时刻会进计划，然后被 `planNotifications` 逐条丢掉（过去的排不了）——
  /// 结果一样，但每次续排都白算一遍今天上午。
  Future<ResyncOutcome> resyncNow() async {
    final ref = _ref;
    final now = ref.read(clockProvider).nowUtc();
    final days = settingOf(ref, reminderWindowDays);
    final today = ref.read(todayProvider);

    final rows = expandInWindow(
      tasks: switch (ref.read(visibleTasksProvider)) {
        AsyncData(:final value) => value,
        _ => const [],
      },
      overrides: switch (ref.read(allOverridesProvider)) {
        AsyncData(:final value) => value,
        _ => const [],
      },
      window: DateRange(today, today.addDays(days)),
      stagesByTask: ref.read(stagesByTaskProvider),
      stageStatesByTask: ref.read(stageStatesByTaskProvider),
      engine: RecurrenceEngine(ref.read(timeZoneResolverProvider)),
    );

    return ref
        .read(reminderSchedulerProvider)
        .resync(
          pairs: reminderPairsOf(
            rows: rows,
            // **读源头，不读派生的那一个**（见 `remindersByTaskProvider`）。
            remindersByTask: groupRemindersByTask(switch (ref.read(
              allRemindersProvider,
            )) {
              AsyncData(:final value) => value,
              _ => const [],
            }),
          ),
          settings: ref.read(reminderSettingsProvider),
          nowUtc: now,
          window: (fromUtc: now, toUtc: now.add(Duration(days: days))),
          zones: ref.read(timeZoneResolverProvider),
        );
  }
}

final reminderSyncProvider = NotifierProvider<ReminderSyncNotifier, void>(
  ReminderSyncNotifier.new,
);

/// 最近一次续排的结果，给设置页的状态卡片看（FR-NOTI-04）。
final class LastResyncNotifier extends Notifier<ResyncOutcome?> {
  @override
  ResyncOutcome? build() => null;

  void record(ResyncOutcome outcome) => state = outcome;
}

final lastResyncProvider = NotifierProvider<LastResyncNotifier, ResyncOutcome?>(
  LastResyncNotifier.new,
);

/// 把续排挂到**真的会发生的事件**上。
///
/// 包在应用外壳外面即可。两个触发点：
///
///  · **进前台**（含冷启动）—— §5 说的第 3 道保险，也是唯一真的兜底那道；
///  · **数据变了** —— 任务、例外、提醒、配置任一变化。
///
/// 只挂第一个的话，「刚改完提醒时间，切出去再切回来才生效」；
/// 只挂第二个的话，系统在应用没运行时清掉的排期永远补不回来。
class ReminderSyncScope extends ConsumerStatefulWidget {
  const ReminderSyncScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ReminderSyncScope> createState() => _ReminderSyncScopeState();
}

class _ReminderSyncScopeState extends ConsumerState<ReminderSyncScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 冷启动也算一次「进前台」——`resumed` 在冷启动时不一定来。
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  Future<void> _sync() async {
    if (!mounted) return;
    final outcome = await ref.read(reminderSyncProvider.notifier).resyncNow();
    if (!mounted) return;
    ref.read(lastResyncProvider.notifier).record(outcome);
  }

  @override
  Widget build(BuildContext context) {
    // 数据变了就重排。**listen 而不是 watch**：watch 会让整棵子树重建，
    // 而这里要的只是一个副作用。
    // **watch 着它，让它别被自动回收** —— 它的 `ref` 就是续排读数据用的
    // 那一个，实例没了那个 ref 也就跟着失效（见 `ReminderSyncNotifier`）。
    ref.watch(reminderSyncProvider);
    ref.listen(visibleTasksProvider, (_, _) => _sync());
    ref.listen(allRemindersProvider, (_, _) => _sync());
    ref.listen(allOverridesProvider, (_, _) => _sync());
    ref.listen(reminderSettingsProvider, (_, _) => _sync());
    return widget.child;
  }
}

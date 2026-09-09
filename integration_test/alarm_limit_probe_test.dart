/// 探针：Android 对单应用待触发闹钟的实际上限（notifications.md §3 的 ⬜）。
///
/// ## 这不是一条验收测试，是一次测量
///
/// 它跑在真机/模拟器上，排 [_probeCount] 条通知，然后由**外部**去数系统里
/// 真正挂了几条。结论写进 `docs/05-engineering/probe-artifacts/`。
///
/// ## 规格里原来的测法**测不出东西**
///
/// §3 写的是「排 N 条并用 `pendingNotificationRequests()` 回读实际条数，
/// 找到真实拐点」。读插件源码之后这条路是断的：
///
/// ```java
/// // FlutterLocalNotificationsPlugin.java:1617
/// private void pendingNotificationRequests(Result result) {
///   ArrayList<NotificationDetails> scheduledNotifications =
///       loadScheduledNotifications(applicationContext);   // ← SharedPreferences
/// ```
///
/// `loadScheduledNotifications` 读的是插件自己写在 SharedPreferences 里的
/// 一段 JSON（同文件 :536），**不问 AlarmManager**。所以那个回读永远等于
/// 你排进去的条数 —— 一个不可能失败的探针，正是「永远绿的测试等于没有测试」。
///
/// 真实状态只能从**进程外**看：
///
/// ```
/// adb shell dumpsys alarm | grep com.dreamuntildawn.planning_assistant
/// ```
///
/// 所以这里的断言只管一件事：**插件自己认为它排了 N 条**。
/// 那是这一侧唯一能断言的事实，也正是要拿去和 dumpsys 对照的那个数。
/// 两者不一致，就是系统悄悄丢了 —— 而那才是探针要找的拐点。
///
/// ## ⚠️ 跑在什么系统上，决定这次测量值多少
///
/// `SCHEDULE_EXACT_ALARM` 的版本门在 API 31、`POST_NOTIFICATIONS` 在 API 33
/// （插件源码 `:797` / `:1921`）。**低于这两个版本，下面那两句权限断言恒真**，
/// 量到的是「所有现代约束都不生效时的上限」，不是设计要防的那个。
/// 2026-09-09 在 Android 9 / API 28 上量到 600/600 无拐点，正是这种情况 ——
/// 结论与它的适用范围记在 notifications.md §11。
///
/// ## ⚠️ 别在存着真实数据的设备上跑
///
/// `flutter test integration_test/...` 跑完会**卸载应用**，连带清掉数据。
/// 用空 AVD，或走 `flutter install` + 应用内入口。
@TestOn('vm')
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 一次排多少条。取 600 是因为坊间流传的上限在 500 上下 ——
/// 要跨过那个数才看得见拐点，只排 100 条的话两边都会是 100。
const int _probeCount = 600;

/// 留给进程外 dumpsys 的测量窗口。见测试末尾那段注释。
const Duration _measureWindow = Duration(seconds: 45);

/// 探针用的渠道，与生产渠道（`task_reminder` / `task_digest`）分开：
/// 渠道的重要性建好之后改不了（§9），探针不该污染生产渠道。
const _channel = AndroidNotificationChannel(
  'probe_alarm_limit',
  '探针：闹钟上限',
  importance: Importance.defaultImportance,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FlutterLocalNotificationsPlugin plugin;

  setUp(() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

    plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    // 上一轮探针留下的排期会把这一轮的计数污染掉。
    await plugin.cancelAll();
  });

  testWidgets('排 $_probeCount 条，看插件与系统各认几条', (tester) async {
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    expect(android, isNotNull, reason: '这条探针只在 Android 上有意义');

    // Android 13+ 不给权限就排不出去，那时数出来的 0 说明的是权限，
    // 不是上限 —— 会把探针的结论引到完全错误的方向上，所以先断言。
    final granted = await android!.requestNotificationsPermission();
    expect(granted, isTrue, reason: '通知权限被拒，这一轮数出来的不是上限');

    await android.createNotificationChannel(_channel);
    final canExact = await android.canScheduleExactNotifications();

    // 排到足够远的将来，免得探针跑着跑着自己弹出来。
    final base = tz.TZDateTime.now(tz.local).add(const Duration(days: 2));
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        importance: Importance.defaultImportance,
      ),
    );

    for (var i = 0; i < _probeCount; i++) {
      await plugin.zonedSchedule(
        id: i,
        title: '探针 $i',
        scheduledDate: base.add(Duration(minutes: i)),
        notificationDetails: details,
        androidScheduleMode: canExact == true
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }

    final pending = await plugin.pendingNotificationRequests();

    // **这一侧唯一断言得了的事实**：插件自己认为它排了这么多条。
    // 系统真挂了几条要从进程外看（见文件头的 dumpsys 命令）。
    expect(
      pending,
      hasLength(_probeCount),
      reason: '插件连自己那份记账都没记满 —— 那是 zonedSchedule 抛了，不是系统的上限',
    );

    // 探针的产出。CI 不跑这个文件，输出由人读了写进 probe-artifacts。
    // ignore: avoid_print
    print(
      'PROBE canScheduleExact=$canExact requested=$_probeCount '
      'pluginPending=${pending.length}',
    );

    // **测量窗口必须开在测试还活着的时候。**
    //
    // `flutter test integration_test/...` 跑完会把应用**卸载**，
    // 而卸载会连同它挂在 AlarmManager 上的闹钟一起清掉 ——
    // 于是事后再 dumpsys 数到的永远是 0，看起来像「系统一条都没接受」，
    // 实际上说明的只是「应用已经不在了」。第一次就是这么被误导的。
    //
    // 所以停在这儿，留出一段时间给进程外的 dumpsys 去数。
    await Future<void>.delayed(_measureWindow);
  });
}

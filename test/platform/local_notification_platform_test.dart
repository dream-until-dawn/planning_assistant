/// 平台适配层的**翻译**（notifications.md §4.4、§9）。
///
/// ## 为什么这一层也要测
///
/// 它「只是转发」，但转发里藏着三个真的决定：走哪个渠道、用哪个
/// `AndroidScheduleMode`、payload 放什么。这三个都是**写错了不会报错**
/// 的东西 —— 通知照样排出去，只是重要性不对、Doze 下不响、或者点开
/// 跳不到任务。而真机验证那几项已经降级（§11），这里不测就没人测了。
///
/// ## 怎么测
///
/// 打插件的**方法通道**（`dexterous.com/flutter/local_notifications`），
/// 把发出去的参数原样记下来。这样验的是「我们递给插件什么」——
/// 而不是「我们调了自己写的哪个方法」，后者重构一次就红，且什么都不保。
@TestOn('vm')
library;

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/local_wall_time.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/domain/services/notification_planner.dart';
import 'package:planning_assistant/platform/notification/local_notification_platform.dart';
import 'package:planning_assistant/platform/notification/notification_platform.dart';
import 'package:timezone/data/latest.dart' as tzdata;

const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

/// 固定用一个**很远的将来**。
///
/// 插件的 `zonedSchedule` 会自己校验「必须是将来的时刻」
/// （`helpers.dart:16`），所以夹具不能用一个已经过去的日期 ——
/// 那样这一份会在某一天集体变红，而红的原因与它要测的东西无关。
///
/// **不读真实时钟去算「明年」**：测试里不得使用真实时钟
/// （testing-strategy §4，有守卫盯着）。取一个够远的常量，
/// 断言就仍然是字面量。
const _year = 2200;

PlannedNotification _planned({
  String key = 'k1',
  List<String> taskIds = const ['t1'],
  String title = '开会',
}) => PlannedNotification(
  key: key,
  trigger: LocalWallTime(
    date: const PlanDate(_year, 3, 10),
    minuteOfDay: MinuteOfDay.of(8, 45),
    timeZoneId: 'Asia/Shanghai',
  ),
  triggerUtc: DateTime.utc(_year, 3, 10, 0, 45),
  taskIds: taskIds,
  title: title,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tzdata.initializeTimeZones);

  late List<MethodCall> calls;
  late LocalNotificationPlatform platform;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'initialize' => true,
            'areNotificationsEnabled' => true,
            'canScheduleExactNotifications' => true,
            'pendingNotificationRequests' => <Map<String, Object?>>[
              {'id': 7},
              {'id': 9},
            ],
            _ => null,
          };
        });
    // 插件在真机上由平台注册填这个静态实例；VM 测试里没有那一步，
    // 于是 `FlutterLocalNotificationsPlatform.instance` 是个未初始化的
    // late 字段。手动装上 Android 那一份，它内部走的就是上面这条被打桩的
    // 方法通道 —— **打的仍然是通道，不是我们自己的方法**。
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    platform = LocalNotificationPlatform(FlutterLocalNotificationsPlugin());
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  Map<String, Object?> argsOf(String method) => Map<String, Object?>.from(
    calls.firstWhere((c) => c.method == method).arguments as Map,
  );

  /// `scheduleMode` 与渠道都在 `platformSpecifics` 里面，不在顶层
  /// （插件源码 `platform_flutter_local_notifications.dart:260`）。
  Map<String, Object?> androidArgs() => Map<String, Object?>.from(
    argsOf('zonedSchedule')['platformSpecifics']! as Map,
  );

  group('降级：mode 的翻译（N-14 的落点）', () {
    test('exact → exactAllowWhileIdle', () async {
      await platform.schedule(
        _planned(),
        osId: 1,
        mode: ReminderScheduleMode.exact,
      );
      expect(
        androidArgs()['scheduleMode'],
        AndroidScheduleMode.exactAllowWhileIdle.name,
      );
    });

    test('inexact → **inexactAllowWhileIdle，不是 inexact**', () async {
      // `inexact` 在 Doze 下可能被推到下一个维护窗口，对「今天 9 点的会」
      // 等于失效。既然已经放弃精确，至少要保住「会响」。
      // 规格初版就误写成了 `inexact`，所以这条把两个名字都钉死。
      await platform.schedule(
        _planned(),
        osId: 1,
        mode: ReminderScheduleMode.inexact,
      );
      expect(
        androidArgs()['scheduleMode'],
        AndroidScheduleMode.inexactAllowWhileIdle.name,
      );
      expect(
        androidArgs()['scheduleMode'],
        isNot(AndroidScheduleMode.inexact.name),
      );
    });
  });

  group('渠道与内容', () {
    test('单条走 task_reminder，摘要走 task_digest', () async {
      await platform.schedule(
        _planned(),
        osId: 1,
        mode: ReminderScheduleMode.exact,
      );
      expect(androidArgs()['channelId'], kReminderChannel.id);

      calls.clear();
      await platform.schedule(
        _planned(taskIds: const ['t1', 't2', 't3', 't4']),
        osId: 2,
        mode: ReminderScheduleMode.exact,
      );
      expect(androidArgs()['channelId'], kDigestChannel.id);
    });

    test('payload 是任务 id —— 点开要跳得到那条任务', () async {
      await platform.schedule(
        _planned(taskIds: const ['task-42']),
        osId: 1,
        mode: ReminderScheduleMode.exact,
      );
      expect(argsOf('zonedSchedule')['payload'], 'task-42');
    });

    test('摘要没有单一任务，payload 留空而不是随便挑一条', () async {
      await platform.schedule(
        _planned(taskIds: const ['a', 'b', 'c', 'd']),
        osId: 1,
        mode: ReminderScheduleMode.exact,
      );
      expect(argsOf('zonedSchedule')['payload'], '');
    });

    test('标题与 id 原样递过去', () async {
      await platform.schedule(
        _planned(title: '交周报'),
        osId: 99,
        mode: ReminderScheduleMode.exact,
      );
      final args = argsOf('zonedSchedule');
      expect(args['id'], 99);
      expect(args['title'], '交周报');
    });

    test('**排的是墙钟那一刻**：08:45 上海，不是 triggerUtc 直接当本地时间', () async {
      // 只留绝对时刻的话，时区一变「早上 8:45」就飞到别的钟点上（§6）。
      await platform.schedule(
        _planned(),
        osId: 1,
        mode: ReminderScheduleMode.exact,
      );
      expect(
        argsOf('zonedSchedule')['scheduledDateTime'],
        startsWith('$_year-03-10T08:45'),
      );
    });
  });

  group('能力查询与建渠道', () {
    test('ensureReady 建了两个渠道', () async {
      await platform.ensureReady();
      final created = calls
          .where((c) => c.method == 'createNotificationChannel')
          .map((c) => Map<String, Object?>.from(c.arguments as Map)['id'])
          .toList();
      expect(created, [kReminderChannel.id, kDigestChannel.id]);
    });

    test('capabilities 问的是两个查询，照实返回', () async {
      final caps = await platform.capabilities();
      expect(caps.canNotify, isTrue);
      expect(caps.canScheduleExact, isTrue);
      expect(
        calls.map((c) => c.method),
        containsAll(<String>[
          'areNotificationsEnabled',
          'canScheduleExactNotifications',
        ]),
      );
    });

    test('cancel 把 id 递过去', () async {
      await platform.cancel(13);
      expect(Map<String, Object?>.from(argsOf('cancel'))['id'], 13);
    });

    test('pluginPendingIds 读回插件那份清单', () async {
      expect(await platform.pluginPendingIds(), [7, 9]);
    });
  });
}

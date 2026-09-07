/// 时区初始化的行为契约。
///
/// 这个文件的存在本身就是一条教训：`initializeTimeZones()` 看起来像
/// 「初始化时区」，实际只加载数据库，**不设置 `tz.local`**。
/// 少了 `setLocalLocation()` 时一切照常运行、不抛任何异常，
/// 只是 `tz.local.name` 恒为 `Etc/UTC` —— 北京用户设的「每天 07:00」
/// 会被记成 UTC 07:00，实际在当地 15:00 触发。
///
/// **静默的错误必须有测试盯着**，否则只能等用户报「闹钟晚了 8 小时」。
@TestOn('vm')
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/time_zone_bootstrap.dart';
import 'package:planning_assistant/core/time/time_zone_resolver.dart';
import 'package:planning_assistant/platform/timezone/platform_time_zone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const _resolver = TzTimeZoneResolver();

void main() {
  // 必须在任何 group 体执行前完成：下面要拿 defaultBinaryMessenger。
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tzdata.initializeTimeZones);

  // 每个用例后复位，避免测试间互相污染 tz.local 这个全局状态。
  tearDown(() => tz.setLocalLocation(tz.getLocation(kFallbackZoneId)));

  group('setUpLocalTimeZone', () {
    test('设置真实本地时区后 currentZoneId() 返回非 Etc/UTC', () async {
      // 评审方点名的证明：这一条直接对应上面那个静默 bug。
      // 先确认起点确实是 Etc/UTC（否则这条测试可能因为其他用例的残留而假绿）。
      tz.setLocalLocation(tz.getLocation('Etc/UTC'));
      expect(_resolver.currentZoneId(), 'Etc/UTC', reason: '前置条件');

      final result = await setUpLocalTimeZone(
        const FakeTimeZoneSource('Asia/Shanghai').currentZoneId,
      );

      expect(result.fellBack, isFalse);
      expect(result.zoneId, 'Asia/Shanghai');
      expect(_resolver.currentZoneId(), 'Asia/Shanghai');
      expect(_resolver.currentZoneId(), isNot('Etc/UTC'));
      expect(tz.local.name, 'Asia/Shanghai');
    });

    test('设备报 Asia/Calcutta 时不崩，归一为 Asia/Kolkata', () async {
      // 评审方点名的用例。Android 上这是**常态**而非异常路径。
      final result = await setUpLocalTimeZone(
        const FakeTimeZoneSource('Asia/Calcutta').currentZoneId,
      );

      expect(result.fellBack, isFalse, reason: '别名是已知标识，不该走降级');
      expect(result.zoneId, 'Asia/Kolkata');
      expect(_resolver.currentZoneId(), 'Asia/Kolkata');
    });

    test('设备报未知时区 → 降级到 UTC，但 fellBack 为真且保留原值', () async {
      final result = await setUpLocalTimeZone(
        const FakeTimeZoneSource('Mars/Olympus_Mons').currentZoneId,
      );

      expect(result.zoneId, kFallbackZoneId);
      expect(result.fellBack, isTrue, reason: '降级必须可见，不能静默');
      expect(
        result.reportedZoneId,
        'Mars/Olympus_Mons',
        reason: '设备原值要留着，否则无法诊断',
      );
      expect(result.failure, isNotNull);
      // 即便降级，tz.local 也必须是可用的，App 不能因此崩溃。
      expect(tz.local.name, kFallbackZoneId);
    });

    test('平台调用失败 → 同样降级且可见', () async {
      final result = await setUpLocalTimeZone(
        FakeTimeZoneSource(
          'irrelevant',
          error: StateError('channel 未注册'),
        ).currentZoneId,
      );

      expect(result.fellBack, isTrue);
      expect(result.zoneId, kFallbackZoneId);
      expect(result.failure, isA<StateError>());
      // 平台没返回值，reportedZoneId 自然为空 —— 这与「返回了但不认识」可区分。
      expect(result.reportedZoneId, isNull);
    });

    test('toString 在降级时带出诊断信息', () {
      // 降级信息只有进了日志才有用，格式塌了等于没记。
      const ok = TimeZoneSetupResult(zoneId: 'Asia/Shanghai', fellBack: false);
      expect(ok.toString(), contains('Asia/Shanghai'));

      const bad = TimeZoneSetupResult(
        zoneId: 'Etc/UTC',
        fellBack: true,
        reportedZoneId: 'Mars/Olympus_Mons',
        failure: 'boom',
      );
      expect(bad.toString(), contains('Mars/Olympus_Mons'));
      expect(bad.toString(), contains('降级'));
    });
  });

  group('MethodChannelTimeZoneSource', () {
    const channel = MethodChannel(
      'com.dreamuntildawn.planning_assistant/timezone',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('转达平台返回的标识，包括旧式别名', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getLocalTimeZone');
        return 'Asia/Calcutta';
      });
      // 归一是 resolver 的职责，本层只如实转达 —— 边界要清楚。
      expect(
        await const MethodChannelTimeZoneSource().currentZoneId(),
        'Asia/Calcutta',
      );
    });

    test('平台返回 null 或空串时抛异常，不返回空字符串', () async {
      // 空串一路传下去会变成「未知时区」，错误现场离根因太远。
      for (final bad in [null, '']) {
        messenger.setMockMethodCallHandler(channel, (call) async => bad);
        expect(
          const MethodChannelTimeZoneSource().currentZoneId(),
          throwsA(isA<PlatformException>()),
          reason: '平台返回 ${bad == null ? 'null' : '空串'} 时',
        );
      }
    });
  });
}

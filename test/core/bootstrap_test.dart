/// 启动装配（`lib/bootstrap.dart`）。
///
/// ## 它此前是零覆盖，而且门禁看不见
///
/// `flutter test --coverage` 只对被至少一个测试**加载过**的文件插桩。
/// 谁都不 import 的文件既不在分子也不在分母 —— 覆盖率照样「四层达标」。
///
/// bootstrap 偏偏是最不该没人验的一块：时区初始化、顶层错误兜底、
/// ProviderScope 装配全在这里，而它的失败方式全是**静默**的
/// （时区没设成功 → 所有任务时间偏移，不抛任何异常）。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/bootstrap.dart';
import 'package:planning_assistant/core/time/time_zone_bootstrap.dart';
import 'package:planning_assistant/core/time/time_zone_resolver.dart';
import 'package:planning_assistant/platform/timezone/platform_time_zone.dart';
import 'package:timezone/timezone.dart' as tz;

const _resolver = TzTimeZoneResolver();

/// 取出 bootstrap 放进 ProviderScope 的时区结果。
///
/// 经真实的 Widget 树读取，而不是直接调 `setUpLocalTimeZone` ——
/// 后者会跳过 bootstrap 自己的装配代码，那正是要验的部分。
Future<TimeZoneSetupResult> runBootstrap(
  WidgetTester tester,
  PlatformTimeZoneSource source,
) async {
  late TimeZoneSetupResult captured;
  await bootstrap(
    () => Consumer(
      builder: (context, ref, _) {
        captured = ref.watch(timeZoneSetupProvider);
        return const SizedBox.shrink();
      },
    ),
    timeZoneSource: source,
  );
  await tester.pump();
  return captured;
}

void main() {
  // bootstrap 会改全局的 tz.local，用例之间必须复位。
  tearDown(() => tz.setLocalLocation(tz.getLocation(kFallbackZoneId)));

  testWidgets('装配后 tz.local 是设备报的时区，不是 Etc/UTC', (tester) async {
    // 这条守的是那个静默 bug：`initializeTimeZones()` 只加载数据库、
    // 不设置 tz.local，缺了第二步 `currentZoneId()` 恒为 Etc/UTC，
    // 北京设的「每天 07:00」被记成当地 15:00。
    final result = await runBootstrap(
      tester,
      const FakeTimeZoneSource('Asia/Shanghai'),
    );

    expect(result.fellBack, isFalse);
    expect(result.zoneId, 'Asia/Shanghai');
    expect(_resolver.currentZoneId(), 'Asia/Shanghai');
    expect(tz.local.name, isNot('Etc/UTC'));
  });

  testWidgets('结果经 Provider 暴露，UI 能读到', (tester) async {
    // 用 Provider 而不是全局变量，就是为了让降级提示能被 Widget 测试覆盖。
    final result = await runBootstrap(
      tester,
      const FakeTimeZoneSource('America/New_York'),
    );
    expect(result.zoneId, 'America/New_York');
  });

  testWidgets('设备报旧式别名时归一，不降级', (tester) async {
    // Android 上 Asia/Calcutta 是常态而非异常路径。
    final result = await runBootstrap(
      tester,
      const FakeTimeZoneSource('Asia/Calcutta'),
    );

    expect(result.fellBack, isFalse);
    expect(result.zoneId, 'Asia/Kolkata');
  });

  testWidgets('平台调用失败时降级但仍能启动，且降级可见', (tester) async {
    // App 不能因为读不到时区就起不来；但降级必须留痕，
    // 否则用户只会看到「时间莫名其妙不对」。
    final result = await runBootstrap(
      tester,
      FakeTimeZoneSource('irrelevant', error: StateError('channel 未注册')),
    );

    expect(result.fellBack, isTrue);
    expect(result.zoneId, kFallbackZoneId);
    expect(result.failure, isA<StateError>());
    expect(tester.takeException(), isNull, reason: '降级不该让启动崩掉');
  });

  testWidgets('设备报未知时区时同样降级并保留原值供诊断', (tester) async {
    final result = await runBootstrap(
      tester,
      const FakeTimeZoneSource('Mars/Olympus_Mons'),
    );

    expect(result.fellBack, isTrue);
    expect(result.reportedZoneId, 'Mars/Olympus_Mons');
  });

  testWidgets('未在 overrides 中提供时，读 provider 会明确报错', (tester) async {
    // 默认实现是 `throw StateError` 而不是返回一个假值 ——
    // 返回假值的话，忘了装配就会退化成「时区永远是 UTC」，
    // 与那个静默 bug 一模一样。
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            ref.watch(timeZoneSetupProvider);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    // Riverpod 3 会把 provider 内抛出的异常包一层，所以断的是消息内容
    // 而不是类型 —— 断类型会因为 Riverpod 换包装方式而假红，
    // 但「读到未装配的 provider 要爆」这条语义是稳定的。
    final error = tester.takeException();
    expect(error, isNotNull);
    expect('$error', contains('ProviderScope'));
  });
}

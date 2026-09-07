/// 应用初始化编排。
///
/// `main.dart` 只负责调用它；这里也不写业务，只做启动期的装配顺序编排。
/// 依据 docs/01-architecture/module-map.md §1。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'app_providers.dart';
import 'core/time/clock.dart';
import 'core/time/time_zone_bootstrap.dart';
import 'core/time/time_zone_resolver.dart';
import 'platform/timezone/platform_time_zone.dart';

/// 启动应用。
///
/// [appBuilder] 由调用方提供，便于集成测试替换根 Widget。
/// [timeZoneSource] 可注入，便于测试与桌面端。
Future<void> bootstrap(
  Widget Function() appBuilder, {
  PlatformTimeZoneSource timeZoneSource = const MethodChannelTimeZoneSource(),
  Clock clock = const SystemClock(),
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 顶层错误兜底（NFR-REL-01）：任何未捕获异常都必须落日志，绝不静默吞掉。
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kReleaseMode) {
      // TODO(M4): 落本地滚动日志文件，不外发（NFR-PRIV-01）
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('未捕获的异步异常: $error');
    return true;
  };

  // ── 时区：两步都必须做 ────────────────────────────────────────
  // initializeTimeZones() 只加载数据库，**不设置 tz.local**。
  // 少了第二步，tz.local.name 恒为 Etc/UTC，于是每条任务的 timeZoneId
  // 都被记成 UTC —— 北京设的「每天 07:00」变成当地 15:00，且完全静默。
  tzdata.initializeTimeZones();
  final tzResult = await setUpLocalTimeZone(timeZoneSource.currentZoneId);
  if (tzResult.fellBack) {
    // 降级必须可见：此后创建的任务时区是错的。
    debugPrint('时区初始化降级: $tzResult');
    // TODO(M2): 在设置页展示提示，引导用户手动选择时区
  }

  // TODO(M1-C): 数据库初始化
  // TODO(M4): 通知渠道创建 → 提醒对账

  runApp(
    ProviderScope(
      // 组合根：`app_providers.dart` 里的声明在这里、且只在这里拿到实现。
      overrides: [
        clockProvider.overrideWithValue(clock),
        timeZoneResolverProvider.overrideWithValue(const TzTimeZoneResolver()),
        timeZoneSetupProvider.overrideWithValue(tzResult),
      ],
      child: appBuilder(),
    ),
  );
}

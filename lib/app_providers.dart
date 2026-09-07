/// **应用级 Provider 声明**（module-map §1）。
///
/// 这里只有**声明**，没有实现 —— 每一个都在 `bootstrap.dart` 里被覆盖。
/// 没覆盖就抛，不给默认值。
///
/// ## 为什么单独一个文件，而不是塞进 `core/` 或某个 feature
///
/// - **不能放 `core/`**：那样 `core/` 就得 import `flutter_riverpod`，
///   而 `domain/` 合法地 import `core/` 且**禁止任何 Flutter 依赖**
///   （NFR-MAINT-02）。两条边各自合法，复合起来领域层就静默地
///   拖进了 Flutter，而分层守卫只看直接 import，抓不到 ——
///   与 `layer_dependency_test` 里 B6 记的是同一个形状。
/// - **不能放某个 feature**：时钟、数据库这些是全应用的，
///   放进哪个 feature 都会让别的 feature 反向依赖它。
///
/// 所以放在组合根：feature 依赖的是**声明**，实现在 `bootstrap` 注入。
///
/// ## 为什么不给默认值
///
/// `Provider((ref) => const SystemClock())` 看着方便，代价是
/// **忘记覆盖时不会报错**，测试里会静默用上真实时钟 ——
/// 于是「测试依赖真实时间」这种缺陷要等到某天半夜跑 CI 才暴露。
/// 抛异常让「忘了注入」在第一次读取时就炸。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/time/clock.dart';
import 'core/time/time_zone_bootstrap.dart';
import 'core/time/time_zone_resolver.dart';

Never _mustOverride(String what) =>
    throw StateError('$what 必须在 ProviderScope 的 overrides 中提供');

/// 全应用唯一的时钟。**任何地方都不许直接 `DateTime.now()`**
/// —— 那条由架构守卫盯着。
final clockProvider = Provider<Clock>((ref) => _mustOverride('clockProvider'));

/// 时区初始化的结果，供 UI 在降级时提示用户。
///
/// 用 Provider 暴露而不是全局变量，是为了让 Widget 测试能覆盖它。
final timeZoneSetupProvider = Provider<TimeZoneSetupResult>(
  (ref) => _mustOverride('timeZoneSetupProvider'),
);

/// 时区换算器。**墙钟与绝对时刻之间的换算只能经它**（ADR-0005）——
/// 自己拿 `DateTime` 加减时区偏移在 DST 边界上一定是错的。
final timeZoneResolverProvider = Provider<TimeZoneResolver>(
  (ref) => _mustOverride('timeZoneResolverProvider'),
);

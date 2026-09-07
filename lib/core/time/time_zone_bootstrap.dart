/// 时区初始化。
///
/// **这一步不可省，且不能只做一半**（见 `TzTimeZoneResolver` 的类注释）：
/// `initializeTimeZones()` 只加载数据库，**不设置 `tz.local`**。
/// 缺了 `setLocalLocation()` 时 `tz.local.name` 恒为 `Etc/UTC`，
/// 于是每条任务的 `timeZoneId` 都被记成 UTC —— 北京设的「每天 07:00」
/// 会变成当地 15:00。**完全静默，不抛任何异常。**
library;

import 'package:timezone/timezone.dart' as tz;

import 'time_zone_resolver.dart';

/// 初始化结果。
///
/// 带 [fellBack] 是因为**降级必须可见**：设备报了一个我们识别不了的时区时，
/// 静默用 UTC 顶上就是上面那个 bug 的另一种形态。UI 应据此提示用户手动选时区。
final class TimeZoneSetupResult {
  const TimeZoneSetupResult({
    required this.zoneId,
    required this.fellBack,
    this.reportedZoneId,
    this.failure,
  });

  /// 实际生效的时区（已归一）。
  final String zoneId;

  /// 是否因无法识别设备时区而降级。
  final bool fellBack;

  /// 设备原本报的值。降级时用于诊断与上报。
  final String? reportedZoneId;

  /// 降级原因。
  final Object? failure;

  @override
  String toString() => fellBack
      ? 'TimeZoneSetupResult(降级到 $zoneId，设备报的是 $reportedZoneId，因 $failure)'
      : 'TimeZoneSetupResult($zoneId)';
}

/// 降级时使用的时区。
const String kFallbackZoneId = 'Etc/UTC';

/// 设置 `tz.local`。**调用方必须已完成 `initializeTimeZones()`。**
///
/// [readZoneId] 由 bootstrap 传入平台实现；测试注入假实现。
/// 返回结果里的 [TimeZoneSetupResult.fellBack] 必须被调用方检查 ——
/// 降级意味着此后创建的任务时区是错的。
Future<TimeZoneSetupResult> setUpLocalTimeZone(
  Future<String> Function() readZoneId,
) async {
  String? reported;
  try {
    reported = await readZoneId();
    final normalized = TzTimeZoneResolver.normalizeZoneId(reported);
    tz.setLocalLocation(tz.getLocation(normalized));
    return TimeZoneSetupResult(zoneId: normalized, fellBack: false);
  } catch (e) {
    // 平台调用失败、或设备报了 tz 数据库里没有的标识。
    // 降级让 App 仍可用，但把这件事显式暴露出去。
    tz.setLocalLocation(tz.getLocation(kFallbackZoneId));
    return TimeZoneSetupResult(
      zoneId: kFallbackZoneId,
      fellBack: true,
      reportedZoneId: reported,
      failure: e,
    );
  }
}

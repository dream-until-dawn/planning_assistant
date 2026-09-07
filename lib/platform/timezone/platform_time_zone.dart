/// 读取设备的 IANA 时区标识。
///
/// **为什么不用 `flutter_timezone`**（M0 移交清单里挂着的取舍，此处结清）：
/// 该包仍使用旧的 Kotlin Gradle Plugin，AGP 9 已警告「未来版本将构建失败」
/// （environment-notes §3.3）。而我们自己的 `android/` 模块由 AGP 内置 Kotlin
/// 构建，不受该问题影响 —— 一个约 20 行的 MethodChannel 就够，
/// 少一个依赖，也规避了已知的未来构建失败。
library;

import 'package:flutter/services.dart';

/// 设备时区来源。接口化以便测试注入。
abstract interface class PlatformTimeZoneSource {
  /// 设备当前的 IANA 时区标识，如 `Asia/Shanghai`。
  ///
  /// 可能返回**旧式别名**（如 `Asia/Calcutta`）—— Android 至今仍有大量设备如此。
  /// 归一交给 `TzTimeZoneResolver.normalizeZoneId()`，本接口只负责如实转达。
  Future<String> currentZoneId();
}

/// 经 MethodChannel 读取 `java.util.TimeZone.getDefault().getID()`。
final class MethodChannelTimeZoneSource implements PlatformTimeZoneSource {
  const MethodChannelTimeZoneSource();

  static const MethodChannel _channel = MethodChannel(
    'com.dreamuntildawn.planning_assistant/timezone',
  );

  @override
  Future<String> currentZoneId() async {
    final id = await _channel.invokeMethod<String>('getLocalTimeZone');
    if (id == null || id.isEmpty) {
      throw PlatformException(code: 'EMPTY_TIMEZONE', message: '平台返回了空的时区标识');
    }
    return id;
  }
}

/// 固定值，测试专用。
final class FakeTimeZoneSource implements PlatformTimeZoneSource {
  const FakeTimeZoneSource(this.zoneId, {this.error});

  final String zoneId;

  /// 非 null 时模拟平台调用失败。
  final Object? error;

  @override
  Future<String> currentZoneId() async {
    if (error != null) throw error!;
    return zoneId;
  }
}

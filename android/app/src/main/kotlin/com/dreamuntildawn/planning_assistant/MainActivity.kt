package com.dreamuntildawn.planning_assistant

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

/**
 * 应用入口。
 *
 * 目前只注册一个 MethodChannel：读取设备的 IANA 时区标识。
 *
 * 为什么不用 flutter_timezone 包：它仍使用旧的 Kotlin Gradle Plugin，
 * AGP 9 已警告未来版本将构建失败（docs/05-engineering/environment-notes.md §3.3）。
 * 本模块由 AGP 内置 Kotlin 构建，不受该问题影响，二十行代码即可替代整个依赖。
 */
class MainActivity : FlutterActivity() {

    private companion object {
        const val TIMEZONE_CHANNEL = "com.dreamuntildawn.planning_assistant/timezone"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TIMEZONE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // 注意：可能返回旧式别名（如 Asia/Calcutta）。
                    // 归一在 Dart 侧的 TzTimeZoneResolver.normalizeZoneId() 做，
                    // 这里只如实转达设备报的值。
                    "getLocalTimeZone" -> result.success(TimeZone.getDefault().id)
                    else -> result.notImplemented()
                }
            }
    }
}

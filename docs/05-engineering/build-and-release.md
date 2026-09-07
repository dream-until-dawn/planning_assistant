# 构建与发布

> 本文的配置**均已在 M0 探针中实测通过**（成功产出 debug APK 并在模拟器运行），
> 相关坑与依据见[环境探针结论](environment-notes.md)。

## 1. 前置条件

| 项 | 要求 |
|---|---|
| Flutter | 3.47.0 stable（Dart 3.13.0） |
| JDK | 17 |
| Android SDK | 见 §3 关于 compileSdk 的决策 |
| 项目路径 | **必须纯 ASCII**（AGP 硬性拒绝非 ASCII 路径） |
| `GRADLE_USER_HOME` | 必须纯 ASCII |
| 网络 | Maven Central 在本环境返回 403，**必须配镜像**，见 §2 |

## 2. Gradle 仓库配置（必须，否则构建失败）

`android/settings.gradle.kts` 的 `pluginManagement.repositories` 与
`android/build.gradle.kts` 的 `allprojects.repositories` 都要写成：

```kotlin
repositories {
    maven { url = uri("https://maven.aliyun.com/repository/public") }
    maven { url = uri("https://maven.aliyun.com/repository/google") }
    maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
    google()
    mavenCentral()
}
```

> 不配时的报错极具误导性（曾出现 `Cannot invoke "java.util.List.get(int)" because "path" is null`，
> 完全看不出是网络问题）。踩过一次就够了，写在这里。

## 3. `android/app/build.gradle.kts` 必要配置

```kotlin
android {
    compileSdk = 37   // 见下方决策

    compileOptions {
        isCoreLibraryDesugaringEnabled = true   // flutter_local_notifications 硬性要求
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.dreamuntildawn.planning_assistant"
        minSdk = 26          // 见 §3.1
        targetSdk = flutter.targetSdkVersion
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

### 3.1 `minSdk = 26` 的理由

| 因素 | 说明 |
|---|---|
| 通知渠道（`NotificationChannel`）是 API 26 引入 | 低于 26 需要写两套通知代码 |
| API 26 以下设备在当前市场占比极低 | 收益远小于维护成本 |
| Flutter 默认 minSdk 更低，但我们主动抬高 | 换取通知代码只有一条路径 |

> ⬜ 若后续发现目标用户中有大量低版本设备，再评估降级 —— 但那需要数据支撑，不是猜测。

### 3.2 `compileSdk` 的未决决策（M0 检查表项）

当前用 `compileSdk = 37`，因为 `permission_handler_android` 强制要求，
而本机 android-37.0 是 **rc2 预览版**。

**但是**：`flutter_local_notifications 22.3.0` 自带 `requestNotificationsPermission()` 与
`requestExactAlarmsPermission()`（[已读源码确认](../04-platform/notifications.md#43-可用的-api-已核实存在于-2230)），
本项目的权限需求可能根本用不到 `permission_handler`。

**M0 要做的决定**：

- 若能移除 `permission_handler` → `compileSdk` 降回稳定版 36，脱离预览版依赖 ✅ 首选
- 若确实需要 → 保留 37，并在发版前确认 android-37 已转正式版

## 4. `AndroidManifest.xml` 必要声明

```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />

<application ...>
    <receiver android:exported="false"
        android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
        <intent-filter>
            <action android:name="android.intent.action.BOOT_COMPLETED"/>
            <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
            <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        </intent-filter>
    </receiver>
</application>
```

`POST_NOTIFICATIONS` 与 `VIBRATE` 由插件自带，不用重复声明（已读插件 manifest 确认）。

**不声明** `USE_EXACT_ALARM`，理由见[通知设计 §4.2](../04-platform/notifications.md)。

## 5. 构建命令

```bash
# 开发调试
flutter run -d <device>

# Debug 包（M0 已实测通过）
flutter build apk --debug

# Release 包，按 ABI 拆分（体积大幅下降）
flutter build apk --release --split-per-abi

# AAB（上架用）
flutter build appbundle --release
```

> M0 实测：debug APK 约 157MB（含全部 ABI + 调试信息）。
> Release + `--split-per-abi` 后体积会大幅下降，具体数字待 M5 实测填入。

## 6. 签名

1. 生成密钥库，**放在仓库之外**：

```bash
keytool -genkey -v -keystore <仓库外路径>/planning-assistant.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias planning-assistant
```

2. `android/key.properties`（**必须加入 `.gitignore`**）：

```properties
storePassword=...
keyPassword=...
keyAlias=planning-assistant
storeFile=<仓库外的绝对路径>/planning-assistant.jks
```

3. `build.gradle.kts` 读取该文件配置 `signingConfigs.release`。

> ⚠️ 密钥库一旦丢失，**已上架应用无法再更新**。备份到至少两个独立位置。
> 仓库里绝不出现密钥库与密码 —— `.gitignore` 必须包含 `key.properties` 与 `*.jks`。

## 7. 发布检查表

- [ ] 版本号与构建号已递增（构建号不复用）
- [ ] 全量测试通过 + 架构守卫通过
- [ ] `flutter build appbundle --release` 成功
- [ ] **在真机上装了 release 包并跑通[集成测试的关键旅程](testing-strategy.md#8-集成测试覆盖的关键旅程)** —— debug 能跑不代表 release 能跑（混淆、tree-shaking 会带来差异）
- [ ] 断网启动正常（V1 不联网，且字体不得运行时下载）
- [ ] 权限流程走一遍：拒绝通知权限 / 拒绝精确闹钟，App 均能正常使用并给出提示
- [ ] 冷启动时间 ≤ 1.5s（NFR-PERF-01）
- [ ] 深色模式与 200% 字号下无破版
- [ ] 数据导出 → 卸载重装 → 导入，数据完整

## 8. CI（M0 建立）

| 阶段 | 内容 |
|---|---|
| analyze | `dart analyze`，零 error 零 warning |
| codegen 校验 | 跑一次 build_runner，检查工作区是否干净 |
| test | 全量测试 + 覆盖率门禁 |
| guard | 架构守卫 + 坏测试扫描 + 文档同步检查 |
| build | `flutter build apk --debug` 至少要过 |

> CI 环境同样需要配 §2 的镜像，或使用能访问 Maven Central 的网络。

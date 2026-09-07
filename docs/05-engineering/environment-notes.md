# 本机环境探针结论

> **全部结论均为实测**，不是文档摘抄或记忆。测试日期：2026-09-07。
> 探针**工程**（含构建产物）为一次性资源，已删除；但**结论的可复现依据**
> （`pubspec.lock`、最小复现脚本）已入库于 [`probe-artifacts/`](probe-artifacts/README.md)。

## 1. 工具链现状

| 项 | 实测值 | 结论 |
|---|---|---|
| Flutter | 3.47.0 stable | ✅ |
| Dart | 3.13.0 | ✅ |
| Android SDK | 37.0.0-rc2 @ `C:\MyApp\Android\Sdk` | ⚠️ **预览版**，见 §3.2 |
| Platform | android-37.0 | |
| JDK | OpenJDK 17.0.11（Android Studio 内置 jbr） | ✅ |
| AGP | 9.1.0（Flutter 模板默认） | ⚠️ 很新，见 §3.3 |
| Kotlin plugin | 2.4.0 | |
| NDK | 已装 28.2.13676358、29.0.14033849 | ✅ 原生编译可用 |
| Android licenses | 全部已接受 | ✅ |
| 模拟器 | `emulator-5554` 在线（另有 2 个 AVD） | ✅ 可做运行时验证 |
| Visual Studio C++ 组件 | 缺失 | ⚠️ 仅影响 Windows 桌面构建，**不影响出安卓包** |

## 2. 已验证可行（构建 + 运行时双验证）

用完整依赖集构建 debug APK **成功**，安装到模拟器**运行成功**，实测输出：

```
PROBE_OK drift_rows=3            ← 第 3 次启动累计 3 行：数据确实持久化落盘
PROBE_OK sqlite=3.53.4           ← sqlite3 3.x 原生库经 native assets 正确打包并加载
PROBE_OK rrule_roundtrip=true    ← 注意：此样本不含 UNTIL。含 UNTIL 时有损，见 §2.2
PROBE_OK rrule_next=2026-09-08,2026-09-10,2026-09-22,2026-09-24
PROBE_OK rrule_monthend=2026-01-31,2026-03-31,2026-05-31,2026-07-31
PROBE_OK notif_init=true         ← flutter_local_notifications 初始化成功
```

### 2.1 关键领域行为确认（对应[重复引擎](../02-domain/recurrence-engine.md) §7 探针 P-1/P-2）

| 探针 | 结论 |
|---|---|
| **P-1** `FREQ=MONTHLY;BYMONTHDAY=31` | **跳过**没有 31 号的月份（2、4、6 月缺席），**不顺延到月末**。这是 RFC 5545 的正确语义，但与多数用户直觉相反 → UI 必须在选择「每月 31 号」时给出明确提示，并提供「每月最后一天」（`BYMONTHDAY=-1`）作为替代选项 |
| **P-2** RRULE 往返 | ⚠️ **不含 `UNTIL` 时无损；含 `UNTIL` 时有损** —— 见 §2.2 |
| 隔周多日展开 | `FREQ=WEEKLY;INTERVAL=2;BYDAY=TU,TH` 从 9/7(周一) 起 → 9/8、9/10、**跳过一周**、9/22、9/24，行为正确 |

### 2.2 🔴 补测推翻了初版的一个结论：RRULE 往返在含 `UNTIL` 时有损

初版只用 `RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=TU,TH`（不含 `UNTIL`）测出 `roundtrip=true`，
就写下了「RRULE 字符串严格往返」。补一条带 `UNTIL` 的样本后，结论当场被推翻：

```
输入            : RRULE:FREQ=DAILY;UNTIL=20260930T235959Z
toString()      : RRULE:FREQ=DAILY;UNTIL=20260930T235959      ← Z 丢失，lossless=false
isTimeUtc:true  : RRULE:FREQ=DAILY;UNTIL=20260930T235959Z     ← lossless=true
```

- **根因**：`RecurrenceRuleToStringOptions.isTimeUtc` 默认 `false`（读包源码 `encoder.dart:133` 确认）。
- **危害**：丢掉 `Z` 后的串按 RFC 5545 是「浮动本地时间」，而 DTSTART 带 TZID 时该值 MUST 为真 UTC。
  也就是**我们自己的导出会产出不合规的规则串**。`rrule` 自己解析回来仍等值，
  所以**本地往返测试发现不了**，只有外部消费者（服务端、`.ics` 互通）会错 —— 而这两者正是 ADR-0004 的立论依据。
- **对策**：禁止直接 `toString()`，统一走带 `isTimeUtc: true` 的封装，见
  [重复引擎 §2.3](../02-domain/recurrence-engine.md#23-编码-rrule-必须显式开启-istimeutc强制)。

### 2.3 `UNTIL` 不做时区换算（实测）

```
FREQ=DAILY;UNTIL=20260930T095959Z, start=墙钟 09-28T23:00
  → [09-28T23:00, 09-29T23:00]          09-30T23:00 被丢掉
FREQ=DAILY;UNTIL=20260930T235959Z, 同一 start
  → [09-28T23:00, 09-29T23:00, 09-30T23:00]
```

全程无时区参数参与，边界完全由裸值比较决定 → 朴素比较属实。
换算责任必须落在 `core/time`，见[重复引擎 §2.2](../02-domain/recurrence-engine.md#22-until-的时间域必须显式换算)。

另实测：`UNTIL` 恰为某实例时刻时该实例**被包含**（闭区间），与 RFC 5545 §3.3.10
"bounds the recurrence rule in an inclusive manner" 一致。

> 复现方式：`docs/05-engineering/probe-artifacts/rrule/` 下有可直接 `dart run` 的探针源码与 lock。

### 2.4 宿主机测试可行性（对应[测试策略](testing-strategy.md) §2.1）

`flutter test` 在本机 Windows 宿主直接跑通 drift 的 `NativeDatabase.memory()`：

```
HOST_SQLITE=3.53.4
00:00 +1: All tests passed!
```

- **不需要** Visual Studio C++ 组件（原先担心的阻塞不存在）。
- 验证不止于「跑通」：测试中故意插入重复主键并断言 `throwsA(isA<SqliteException>())` 通过，
  证明约束是由真实 SQL 引擎执行的，而不是一个来者不拒的桩。
- **结论**：数据层测试可以全部跑在宿主机上，秒级反馈，无需模拟器。

## 3. 环境陷阱（必须绕开，否则构建必挂）

### 3.1 🔴 Maven Central 不可达（403 Forbidden）

**实测**：

| 仓库 | HTTP 状态 |
|---|---|
| `repo.maven.apache.org` | **403 Forbidden** |
| `maven.aliyun.com/repository/public` | 200 ✅ |
| `dl.google.com`（Google Maven） | 200 ✅ |
| `maven.aliyun.com/repository/gradle-plugin` | 404（没有 AGP 9.1.0，需回落 Google Maven） |

**后果**：不配镜像时，Gradle 构建报的错误**极具误导性** —— 出现过 `Cannot invoke "java.util.List.get(int)" because "path" is null` 这种完全看不出是网络问题的内部异常。加镜像后该错误直接消失。

**对策**：项目的 `android/settings.gradle.kts` 与 `android/build.gradle.kts` 的 `repositories` 块必须为：

```kotlin
repositories {
    maven { url = uri("https://maven.aliyun.com/repository/public") }
    maven { url = uri("https://maven.aliyun.com/repository/google") }
    maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
    google()          // AGP 等 Google 独有构件的兜底，实测直连可用
    mavenCentral()    // 最后兜底
}
```

镜像放前面、官方源保留在后，保证换到能访问 Maven Central 的网络环境时依然可构建。

### 3.2 🟠 `permission_handler` 强制 compileSdk 37（预览版）

`permission_handler_android` 要求 `compileSdk = 37`，而本机的 android-37.0 是 **rc2 预览版**。

**当前处置**：在 `android/app/build.gradle.kts` 显式写 `compileSdk = 37`，已验证可构建可运行。

**待决**：`flutter_local_notifications` 22.x 自带通知权限申请能力，`permission_handler` 未必必需。
M0 检查表中列一项：评估移除 `permission_handler`，把 compileSdk 降回稳定版 36。详见 [ADR-0007](../06-adr/ADR-0007-toolchain-pinning.md)。

### 3.3 🟠 AGP 9 弃用警告

- `flutter_timezone` 仍使用旧的 Kotlin Gradle Plugin，AGP 9 已警告「未来版本将构建失败」。
- 应对：M0 检查表加一项 —— 评估用 `flutter_local_notifications` 自带的时区能力或 `timezone` 包直接读取，替换 `flutter_timezone`。

### 3.4 🔴 `flutter_local_notifications` 需要 core library desugaring

不配置时报 `requires core library desugaring to be enabled`。必须在 `android/app/build.gradle.kts`：

```kotlin
android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

版本 `2.1.4` 取自该插件自身的 `android/build.gradle`，非猜测。

### 3.5 🔴 路径不得含非 ASCII 字符

AGP 直接拒绝：`Your project path contains non-ASCII characters.`

本机用户名为中文（`C:\Users\沁心`），因此：

- ✅ 项目在 `C:\VScodeProject\planning_assistant`（纯 ASCII），安全。
- ✅ `GRADLE_USER_HOME=C:\MyApp\Android\gradle`（纯 ASCII），已提前规避。
- ❌ **任何临时构建产物都不要放在用户主目录下**。

### 3.6 🟠 `PUB_CACHE=C:\Temp`

本机 pub 缓存被指到 `C:\Temp`。副作用：任何位于 `C:\Temp` 之下的目录都会被 pub 认为「在缓存内」，执行 `flutter pub get` 会直接失败：

```
Cannot operate on packages inside the cache.
```

**对策**：临时 Flutter 工程一律建在 `C:\Temp` 之外。

### 3.7 🟡 Impeller opt-out 警告

模拟器运行时出现 `Impeller opt-out deprecated` 警告。M0 检查表列一项：确认真实工程的 `AndroidManifest.xml` 未设置 `io.flutter.embedding.android.EnableImpeller=false`，也未传 `--no-enable-impeller`。

## 4. Dart 依赖解析的硬约束（实测）

在 Dart 3.13.0 下，以下组合**无法共存**，踩过两次：

| 冲突 | 现象 | 解法 |
|---|---|---|
| `riverpod_lint 3.1.9` + 显式声明 `custom_lint` | 版本求解失败：前者需 `analyzer_plugin ^0.14.0`，`custom_lint 0.8.1`（当前最新）需 `^0.13.0` | **不要显式声明 `custom_lint`**。riverpod_lint 3.1.9 已改用 Dart 原生分析器插件协议（`analysis_server_plugin`） |
| `riverpod_generator 4.0.9` + `freezed ^3.x` | 前者需 `analyzer >=13.0.0 <15.0.0`；pub 在 `^3.x` 下会选取的每个 freezed 版本 analyzer 上界都 `< 13`，无交集 | `freezed` 必须升到 **`^4.0.1`**（`>=13.0.0 <15.0.0`，可共存） |

完整版本表与那个「不声明 analyzer 的预发布版」例外见[技术栈 §6.1](../01-architecture/tech-stack.md#61-freezed-为什么必须是-4x完整论证)。

> **这一条被反复修正了三次，过程本身比结论有价值**：
> 1. 初版写「freezed 3.x 只到 analyzer 9–11」—— 那是 3.2.5 一段的值，被当成了全部 3.x。
> 2. 评审方以缓存里唯一的 `freezed-3.2.3`（`>=7.5.9 <9.0.0`）为据说数字错了 —— 那同样是单样本外推，
>    而且这个包的约束在 3.x 内部**非单调**（3.2.1/3.2.2 已是 `^8.0.0`，3.2.3 又退回 `<9.0.0`），
>    从任一版本都推不出全貌。
> 3. 拉 pub.dev 原始 JSON 全量枚举后才发现：16 个 3.x 版本中还有一个 `3.0.0-0.0.dev`
>    **完全不声明 analyzer**，使「任何版本都不允许 analyzer ≥ 13」这句字面失效。
>
> 教训不是「要多测几个」，而是：**完整枚举之后还要检查枚举里的异常项，并把结论的作用域写准**。
> 见[测试策略 §1.2](testing-strategy.md)。

完整锁定版本见[技术栈与版本矩阵](../01-architecture/tech-stack.md)。

## 5. API 变更提醒（实测踩到）

`flutter_local_notifications` 22.x 的 `initialize` 已改为**具名参数**：

```dart
// 旧（≤21.x）：位置参数
await plugin.initialize(initializationSettings);
// 22.x：具名参数
await plugin.initialize(settings: initializationSettings);
```

## 6. M0 环境检查表

实现开始前逐条确认：

- [ ] 项目 `android/` 下两个 gradle 文件已配阿里云镜像（§3.1）
- [ ] `compileSdk` 决策落地：保留 `permission_handler` 用 37，或移除后降回 36（§3.2）
- [ ] core library desugaring 已启用（§3.4）
- [ ] `flutter_timezone` 的替代方案已评估（§3.3）
- [ ] Impeller 未被显式关闭（§3.7）
- [ ] `uuid` 包的 v7 生成 API 已实测确认（见[横切关注点](../01-architecture/cross-cutting.md) §2）
- [ ] 重复引擎探针 P-3/P-4/P-5 已完成并转化为测试用例

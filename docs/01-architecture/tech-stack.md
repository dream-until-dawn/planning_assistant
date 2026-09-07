# 技术栈与版本矩阵

> 表中版本号**全部来自实际解析结果**（`flutter pub get` 后的 `pubspec.lock`），不是估计值。
> 解析环境：Flutter 3.47.0 / Dart 3.13.0，日期 2026-09-07。
> 该组合已通过构建 + 模拟器运行时双重验证，见[环境探针结论](../05-engineering/environment-notes.md)。
>
> **可复现**：产出本表的 `pubspec.yaml` + `pubspec.lock` 已入库于
> [`docs/05-engineering/probe-artifacts/dependency-matrix/`](../05-engineering/probe-artifacts/README.md)，
> 任何人都能重跑解析并逐条比对，不依赖本机 pub cache 是否还在。

## 1. 选型总览

| 领域 | 选择 | ADR |
|---|---|---|
| 应用平台 | Flutter（Android 优先） | [ADR-0001](../06-adr/ADR-0001-flutter-as-app-platform.md) |
| 状态管理 / DI | Riverpod 3 + 代码生成 | [ADR-0002](../06-adr/ADR-0002-riverpod-clean-layering.md) |
| 本地持久化 | Drift（SQLite） | [ADR-0003](../06-adr/ADR-0003-drift-sqlite-persistence.md) |
| 重复规则 | RFC 5545 RRULE（`rrule` 包） | [ADR-0004](../06-adr/ADR-0004-rfc5545-recurrence.md) |
| 时间模型 | 墙钟 + IANA 时区 | [ADR-0005](../06-adr/ADR-0005-local-time-model.md) |
| 同步预备 | 记录级同步信封 + outbox | [ADR-0006](../06-adr/ADR-0006-sync-ready-record-envelope.md) |
| 工具链固定 | 见 | [ADR-0007](../06-adr/ADR-0007-toolchain-pinning.md) |
| 路由 | go_router | 声明式、深链友好，为 V2 小组件点击跳转留口 |
| 不可变模型 | freezed 4 + json_serializable | 值语义 + 免费的 `copyWith`/`==`/JSON |

## 2. 运行时依赖（实测锁定版本）

| 包 | 版本 | 用途 | 备注 |
|---|---|---|---|
| `flutter_riverpod` | 3.4.3 | 状态管理 / DI | |
| `riverpod_annotation` | 4.0.7 | 代码生成注解 | |
| `go_router` | 18.0.1 | 路由 | |
| `drift` | 2.34.4 | 类型安全 SQLite | |
| `drift_flutter` | 0.3.1 | Flutter 集成（DB 路径、连接） | |
| `sqlite3` | 3.5.2 | 原生 SQLite 绑定 | **3.x 自带原生库**，见 §4 |
| `path_provider` | 2.1.6 | 应用目录 | |
| `shared_preferences` | 2.5.5 | 极少量启动期标志位 | 配置主体在 DB，不在这里 |
| `freezed_annotation` | 3.1.0 | 不可变模型注解 | |
| `json_annotation` | 4.12.0 | JSON 注解 | |
| `uuid` | 4.6.0 | ID 生成 | v7 可用性待 M0 确认 |
| `intl` | 0.20.3 | 日期/数字本地化 | |
| `rrule` | 0.2.18 | RFC 5545 重复规则 | 时区无关，见 §5 |
| `flutter_local_notifications` | 22.3.0 | 本地通知 | 需 desugaring；`initialize` 是具名参数 |
| `timezone` | 0.11.1 | IANA 时区库 | |
| `flutter_timezone` | 5.1.0 | 读系统时区 | ⚠️ AGP 9 已警告其 KGP 用法 |
| `table_calendar` | 3.2.1 | 日历视图基础 | 仅作为月/周格子骨架，样式全部自定义 |

## 3. 开发期依赖

| 包 | 版本 | 用途 |
|---|---|---|
| `build_runner` | 2.16.1 | 代码生成驱动 |
| `drift_dev` | 2.34.6 | Drift 代码生成 + schema 快照 |
| `riverpod_generator` | 4.0.9 | Provider 代码生成 |
| `riverpod_lint` | 3.1.9 | Riverpod 专用 lint |
| `freezed` | 4.0.1 | 不可变模型生成 |
| `json_serializable` | 6.14.1 | JSON 编解码生成 |
| `flutter_lints` | 6.0.0 | 基础 lint 规则 |
| `mocktail` | 1.0.5 | 测试替身 |
| `fake_async` | 1.3.3 | 时间相关测试 |

> `analyzer` 被解析到 14.3.0，`analysis_server_plugin` 到 0.3.22 —— 这套是 Dart 新版分析器插件体系。

## 4. `sqlite3_flutter_libs` 已废弃（重要）

实测发现：`sqlite3_flutter_libs 0.6.0+eol` 的 CHANGELOG 明确写着该包已废弃 ——
`sqlite3` 包从 3.x 起自带原生库，不再需要 Flutter 专用的构建脚本。

**结论**：

- **不要**在 `pubspec.yaml` 里声明 `sqlite3_flutter_libs`。
- `drift_flutter 0.3.1` 仍会拉入 `0.6.0+eol` 这个**空壳包**，其唯一作用是阻止旧的 0.5.x 构建脚本被使用。这是正常的，无需处理。
- 已实测确认：APK 中原生 SQLite 正常加载，运行时报告版本 **3.53.4**。

## 5. `rrule` 包的已知特性

- **时区无关**：要求所有 `DateTime` 的 `isUtc == true`，但内部按纯墙钟处理。这正好匹配我们的时间模型（[ADR-0005](../06-adr/ADR-0005-local-time-model.md)），把时区换算的责任留在 `core/time`。
- `BYMONTHDAY=31` 在无 31 号的月份**跳过而非顺延**（已实测，符合 RFC），UI 需据此设计提示。
- 🔴 **`toString()` 默认丢掉 `UNTIL` 的 `Z` 后缀，往返有损**（已实测）。
  根因是 `RecurrenceRuleToStringOptions.isTimeUtc` 默认 `false`。
  必须走封装并显式传 `isTimeUtc: true`，否则导出的规则串不符合 RFC 5545 ——
  见[重复引擎 §2.3](../02-domain/recurrence-engine.md#23-编码-rrule-必须显式开启-istimeutc强制)。
  不含 `UNTIL` 的规则往返无损。
- 🔴 **`UNTIL` 只做朴素比较，不做任何时区换算**（已实测）。存储为真 UTC、展开在墙钟域，
  两者之间必须显式换算，否则边界静默错一次 —— 见[重复引擎 §2.2](../02-domain/recurrence-engine.md#22-until-的时间域必须显式换算)。

> ⚠️ 本节前两版曾写「RRULE 字符串严格往返（已实测）」。那个结论是**只用一条不含 `UNTIL`
> 的规则**测出来的，属于单样本推全称，补测后被推翻。教训见
> [测试策略 §1.1](../05-engineering/testing-strategy.md)。

## 6. 依赖解析的硬约束（踩过的坑）

| 约束 | 原因 | 处置 |
|---|---|---|
| **不要显式声明 `custom_lint`** | `riverpod_lint 3.1.9` 需 `analyzer_plugin ^0.14.0`；`custom_lint 0.8.1`（当前最新）需 `analyzer_plugin ^0.13.0`。pub 求解器的原话是 "every version of custom_lint requires freezed_annotation ^2.2.0 or uuid ^3.0.6 or analyzer_plugin ^0.13.0"，与 riverpod 3.x 的依赖不可共存 | 由 `riverpod_lint` 自行管理插件依赖 |
| `freezed` 必须 `^4.0.1` | 见下方 §6.1 的完整论证 | 锁 `freezed: ^4.0.1` |
| ~~`compileSdk = 37`~~ | 曾因 `permission_handler_android` 强制 | **M0 已解决**：移除该依赖，`compileSdk = 36`（稳定版），不再依赖预览版 SDK |
| core library desugaring 必开 | `flutter_local_notifications` 硬性要求 | `desugar_jdk_libs:2.1.4` |
| Gradle 仓库必须配镜像 | Maven Central 在本网络环境返回 403 | 见[环境探针结论](../05-engineering/environment-notes.md) §3.1 |

### 6.1 `freezed` 为什么必须是 4.x（完整论证）

**结论**：`riverpod_generator 4.0.9` 需 `analyzer >=13.0.0 <15.0.0`（读其 pubspec 确认）。
**pub 在 `^3.x` 约束下会选取的每一个 freezed 版本，其 analyzer 上界都 `< 13`**，与之无交集。故必须用 4.x。

依据是 pub.dev API 的**原始 JSON**（`https://pub.dev/api/packages/freezed`，本地解析 `versions[].pubspec.dependencies.analyzer`），不是抽样、不是二手概括：

| freezed 版本 | analyzer 约束 |
|---|---|
| 3.0.0 – 3.0.3 | `>=7.0.0 <8.0.0` |
| 3.0.4 – 3.1.0 | `>=6.9.0 <8.0.0` |
| 3.2.0 | `>=7.5.9 <8.0.0` |
| 3.2.1, 3.2.2 | `^8.0.0` |
| 3.2.3 | `>=7.5.9 <9.0.0` |
| 3.2.4 | `^9.0.0` |
| **3.2.5**（最高稳定 3.x） | `>=9.0.0 <11.0.0` |
| 3.2.6-dev.1 | `>=12.0.0 <13.0.0` |
| **4.0.1**（采用） | `>=13.0.0 <15.0.0` ✅ |

⚠️ **一个必须写明的例外**：`3.0.0-0.0.dev`（2024-05-18）**完全不声明 `analyzer` 依赖**
（其 dependencies 只有 `collection` / `macros` / `meta`，是已停摆的 macros 实验分支）。
因此「freezed 3.x 的**任何**版本都不允许 analyzer ≥ 13」这句**字面上不成立** —— 不约束即不禁止。
它不影响结论，因为它是预发布版：pub 在未显式开启预发布时不会选中它。
但结论的**作用域必须写准**：是「pub 会选取的版本」，不是「任何版本」。

> 这条注释本身就是 [测试策略 §1.2](../05-engineering/testing-strategy.md) 的案例：
> 该约束在 3.x 内部是**非单调**的（3.2.1/3.2.2 已到 `^8.0.0`，3.2.3 又退回 `>=7.5.9 <9.0.0`），
> 所以「按手头那个版本推断整个 3.x」在这个包上注定失败。

复现脚本见 [`probe-artifacts/freezed-constraints/`](../05-engineering/probe-artifacts/README.md)。

## 7. 刻意不引入的东西

| 没选 | 为什么 |
|---|---|
| `sqlite3_flutter_libs` | 已 EOL（§4） |
| `custom_lint` 显式依赖 | 与 riverpod_lint 冲突（§6） |
| `permission_handler` | 会强制 `compileSdk 37`（当前仍是预览版），而 `flutter_local_notifications` 已自带本项目所需的两个权限申请 API。M0 移除后 compileSdk 降回稳定版 36 |
| 任何全局单例 / service locator | 与 Riverpod 的可测试性目标冲突，且难以在测试中隔离 |
| 通用 UI 组件库（如 GetWidget） | 「可爱清新」需要自己的视觉语言，套通用库反而要打大量补丁 |
| 状态管理二号方案 | 一个项目只允许一种状态管理范式 |
| 后端 SDK（Firebase 等） | V1 不联网（NFR-PRIV-01）；V3 的同步走用户自持存储，见[云同步预研](../04-platform/future-sync.md) |

## 8. 版本升级纪律

- `pubspec.lock` **入库**（应用不是库，必须可复现构建）。
- 依赖升级单独开 PR，不与功能改动混在一起。
- 升级 PR 必须附：`flutter pub outdated` 输出 + 全量测试通过 + **模拟器实跑一次**（编译通过不等于能跑，本项目已经踩过）。

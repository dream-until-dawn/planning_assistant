# M0 工程基建 · 执行记录

> 日期：2026-09-07 · 分支 `feat/m0-scaffold`
>
> 本文的重点不是「做了什么」，而是**每一条守卫机制变红时的实际输出**。
> 按[测试策略 §1.4](testing-strategy.md)：只说「我验过了」不算数。

## 1. 待决项的落地结果

### 1.1 ✅ `compileSdk` 降回稳定版 36

**决定**：移除 `permission_handler`，`compileSdk = 36`。

理由：`flutter_local_notifications 22.3.0` 自带 `requestNotificationsPermission()` 与
`requestExactAlarmsPermission()`（已读源码确认），V1 的权限需求（通知 + 精确闹钟）由它全覆盖。
而 `permission_handler_android` 会强制 `compileSdk = 37`，本机的 android-37.0 仍是 **rc2 预览版**。

**验证**：`flutter build apk --debug` 成功（117.4s），不再依赖任何预览版 SDK。

> 这条把[环境探针结论 §3.2](environment-notes.md) 标记的 🟠 风险彻底消除，而不是绕过。

### 1.2 ✅ `minSdk = 26`

通知渠道（`NotificationChannel`）是 API 26 引入，低于它需要维护两套通知代码。见[构建与发布 §3.1](build-and-release.md)。

### 1.3 ✅ `uuid` 的 v7 可用，且**时间有序性**成立

`uuid 4.6.0` 提供 `v7()`（读源码 `lib/uuid.dart:745` 确认）。

但「能调用」不是我们要的性质 —— 选 v7 是因为它的前 48 bit 是毫秒时间戳，
**字典序 ≈ 生成时序**，对 SQLite 主键索引友好。只断言「能调用」的测试对
「包把 v7 实现成了 v4」完全免疫，因此 `test/domain/id_generator_test.dart` 断言的是：

| 断言 | 为什么 |
|---|---|
| 版本号位为 7、variant 位合法 | 格式正确 |
| 10000 个无重复 | 唯一性 |
| **跨毫秒生成的 ID 字典序 == 生成顺序** | **这才是选 v7 的理由** |
| 前 48 bit 可解析为生成时刻（误差 < 5s） | 时间戳布局符合规范 |

### 1.4 ⏸ `flutter_timezone` 未引入（推迟到 M1 决定）

M0 未引入该依赖，因此 AGP 9 的 KGP 弃用警告**当前不存在**。
M1 需要读取系统时区时再决定：用 `flutter_timezone`，还是在本项目 `android/` 内写一个
约 20 行的 MethodChannel（我们自己的 app 模块由 AGP 内置 Kotlin 构建，不受 KGP 问题影响）。
倾向后者 —— 少一个依赖，且规避已知的未来构建失败。

### 1.5 ✅ Impeller 未被关闭

全仓 grep 无 `EnableImpeller`，未传 `--no-enable-impeller`。

### 1.6 ✅ 重复引擎探针 P-1..P-5 全部完成并转为常驻测试

在 `test/domain/rrule_library_contract_test.dart`，共 14 条。
**期望值全部来自 RFC 5545 或手算**，每条注明依据 —— 不是「跑一遍看输出」。

其中 P-5 的 10 年展开用例，初稿期望值我手算成 3653，实际 3652
（10 × 365 + 2 个闰日）。**这条测试抓住的是我的算术错误，不是库的行为错误** ——
期望值来自独立来源时，它抓的既可能是实现的错，也可能是作者的错，两者都算数。

---

## 2. 守卫有效性证明（M0 的核心验收）

### 2.1 架构守卫：注入 4 处违规，全部变红

注入 `lib/domain/policies/_violation_probe.dart`，含四类违规。实际输出：

```
00:00 +1 -1: 分层依赖方向正确（module-map §3） [E]
  发现 2 处分层违规：
    - lib/domain/policies/_violation_probe.dart:3
        import 'package:flutter/material.dart';
        违反: domain 必须零 Flutter 依赖（NFR-MAINT-02）
    - lib/domain/policies/_violation_probe.dart:4
        import '../../data/repositories/_stub.dart';
        违反: domain 不得依赖 data（依赖倒置：data 实现 domain 的接口）

00:00 +1 -2: 领域层与应用层不得直接调用 DateTime.now()（cross-cutting §1.2） [E]
  发现 1 处直接调用 DateTime.now()：
    - lib/domain/policies/_violation_probe.dart:7
        DateTime when() => DateTime.now();
        违反: 时间必须经注入的 Clock 取得，否则时间相关逻辑无法测试

00:00 +1 -3: 领域层与数据层不得用 assert 表达不变量（cross-cutting §3.1） [E]
  发现 1 处用 assert 表达的不变量：
    - lib/domain/policies/_violation_probe.dart:10
        assert(x != null);
        违反: assert 在 release 构建中被剥离；不变量必须显式 throw

00:00 +1 -3: Some tests failed.
```

删除探针后：

```
00:00 +4: All tests passed!
```

**四类违规全部被抓到，诊断精确到文件与行号，还原后回绿。**

> 守卫里还有一条容易被忽略的用例：**「lib/ 下有可供扫描的源码」**。
> 没有它的话，一个扫到 0 个文件的守卫会报绿 —— 而那个绿没有任何信息量。

### 2.2 文档链接校验器：自检 + 对真实仓库演示失败

见[测试策略 §1.4.1](testing-strategy.md)，两个方向的输出已在那里留档。
要点：自检的期望值改为**手算对照表**后，注入 slug 缺陷会 `exit=2` 且不再继续扫仓库。

### 2.3 CI 里也做同一件事，不只写在文档里

`.github/workflows/ci.yml` 有一个专门的步骤：**注入违规 → 断言守卫变红 → 还原 → 断言回绿**。

若守卫因任何原因失灵（正则写错、路径判断错、文件扫不到），CI 会在这一步暴露它，
而不是等到它对着真实违规报绿之后才被发现。

---

## 3. 交付物

| 项 | 状态 |
|---|---|
| Flutter 工程骨架（按 [module-map](../01-architecture/module-map.md) 建目录） | ✅ 72 个目录 |
| Gradle 阿里云镜像（两个文件） | ✅ |
| core library desugaring + `desugar_jdk_libs:2.1.4` | ✅ |
| `AndroidManifest`：`RECEIVE_BOOT_COMPLETED` / `SCHEDULE_EXACT_ALARM` / 启动接收器 | ✅ |
| `analysis_options.yaml`（含 riverpod_lint） | ✅ |
| `core/result`、`core/time`、`core/id` 最小实现 | ✅ |
| 架构守卫测试（4 条） | ✅ 已证明能红 |
| rrule 契约测试（14 条） | ✅ |
| uuid v7 测试（5 条） | ✅ |
| 应用冒烟（2 条） | ✅ |
| CI（analyze / format / codegen 校验 / test / **守卫有效性** / build） | ✅ |
| `flutter build apk --debug` | ✅ |

**测试总数 26，`dart analyze --fatal-infos --fatal-warnings` 零问题。**

---

## 4. 未完成 / 移交 M1

| 项 | 说明 |
|---|---|
| 断网启动验证（字体已打包） | M0 未引入自定义字体，暂无可验对象；随 M2 设计系统一并验 |
| `flutter_timezone` 的取舍 | 见 §1.4，M1 需要读系统时区时再定 |
| 代码生成校验在 CI 中的实效 | 当前无带注解的源文件，该步骤形同空跑；M1 引入 drift/freezed 后才真正生效 |
| 覆盖率门禁 | 当前仅骨架，设阈值无意义；M1 领域层成型后按[测试策略 §3.3](testing-strategy.md) 设 90%/80% |

> 第 3 条值得记：**一个当前没有作用对象的 CI 步骤，和一个失灵的 CI 步骤在观测上同样是绿的。**
> M1 引入第一个 `.g.dart` 时，必须当场验证它能因「忘了重新生成」而变红。

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

### 2.1b 🔴 但守卫的第一版有 3 处漏报 + 1 处假阳性（评审方变异演练发现）

**上面那次演示只证明了「已实现的规则能红」，没有证明「该实现的规则都实现了」。**
评审方对守卫本身做变异演练，注入 4 个探针，结果是 **3 个被放过、1 个误报**：

| 探针 | 第一版结果 | 问题 |
|---|---|---|
| `DateTime.timestamp()` | ❌ 放过 | 只匹配字面量 `DateTime.now()`。而 `DateTime.timestamp()` 是 dart:core 自 3.0 起的正式 API，同样读环境时钟，**完全落在规则的意图内** |
| 跨 feature 引用 presentation | ❌ 放过 | 逐格转写 module-map §3 表格时**漏了最后一行** |
| barrel 文件 `domain/repositories.dart` | ❌ 放过 | 模式带尾斜杠，只挡目录形式 |
| `lib/data/repositories/core/x.dart` import domain | ❌ **误报** | `_layerOf` 用任意位置子串匹配，路径含 `/core/` 就判为 core 层 |

四条我都独立复现了。**第四条最严重**：它把「data 依赖 domain」这个正常的依赖倒置方向报成违规。
**假阳性比漏报更伤守卫 —— 它会训练人去绕开守卫。**

修复后重跑同一组探针（前三个应红、第四个应绿）：

```
分层依赖方向正确 [E]
    - lib/features/task/presentation/_probe_c.dart:1
        违反: presentation 不得持有 Repository（写路径必须经 TaskCommand，FR-AI-01）

feature 之间不得跨 presentation 引用（module-map §3 末行） [E]
    - lib/features/task/presentation/_probe_b.dart:1
        违反: feature「task」的 presentation 不得引用 feature「settings」的 presentation

领域层与应用层不得直接读环境时钟 [E]
    - lib/domain/policies/_probe_a.dart:2
        违反: DateTime.timestamp() 直接读环境时钟；必须经注入的 Clock

（_probe_d.dart 不再出现 —— 假阳性消失）
```

删除全部探针后：`00:00 +6: All tests passed!`

**修复过程中守卫又抓到了自己**：新增的「测试代码不得使用真实时钟」守卫，
把守卫自身源码里的规则定义行（`'DateTime.now()'` 作为字符串字面量）报成了违规。
已加入白名单并逐条注明理由 —— 白名单是守卫的盲区，不能随手加。

> 这一轮印证了 [testing-strategy §1.4 第 ② 条](testing-strategy.md)刚补上的那句：
> **变异演练不是建立时做一次的仪式。** 守卫每次实质性改动后都要重跑 ——
> 我在这次修复中就两次让它抓到了新问题。

### 2.1c 坏测试扫描器 `tool/lint_tests.dart`（补齐 S3）

[测试策略 §3.4](testing-strategy.md) 写了这个工具，但此前**只写在文档里没有实现** ——
按本项目自己的标准，「文档写着有、实际没有的守卫」比没写更危险：它会让人以为坏测试已被自动拦截。

已实现并接入 CI。自检（手写坏样本 + 手写期望）：

```
--- 自检：坏测试扫描器能否正确失败 ---
  命中: 被注释掉的断言
  命中: 按平台静默跳过
  命中: skip 必须附说明字符串
  命中: 测试块内没有任何断言
  误报好样本: 否
  结果: PASS —— 四类坏测试都能让它变红，好测试不误报
```

对真实仓库演示失败（注入无断言测试 + 被注释掉的断言）：

```
扫描 5 个测试文件
发现 3 处问题：
  被注释掉的断言 —— 要么删掉整条测试，要么修好它
    test/domain/_bad_test.dart:10
      // expect(1, 2);
  测试块内没有任何断言 —— 它只能发现崩溃，发现不了错误
    test/domain/_bad_test.dart:4
      test('无断言的测试')
```

退出码：有坏测试 `exit=1`，无坏测试 `exit=0`，自检失败 `exit=2`。
删除注入文件后回到「未发现结构上不可能失败的测试」。

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
| 架构守卫测试（**6 条**） | ✅ 已证明能红，且经变异演练修掉 3 漏报 + 1 假阳性 |
| 坏测试扫描器 `tool/lint_tests.dart` | ✅ 自检 + 真实仓库失败演示 |
| rrule 契约测试（14 条） | ✅ |
| uuid v7 测试（5 条） | ✅ |
| 应用冒烟（2 条） | ✅ |
| CI（analyze / format / codegen 校验 / test / **守卫有效性** / build） | ✅ |
| `flutter build apk --debug` | ✅ |

**测试总数 28，`dart analyze --fatal-infos --fatal-warnings` 零问题，`dart format` 无差异。**

---

## 4. 未完成 / 移交 M1

> 评审方指出的 S3（文档写了但未实现的两条守卫）已在本轮补齐：
> `tool/lint_tests.dart` 见 §2.1c；「测试代码不得使用真实时钟」已作为守卫测试的一条实现。
> 两条都不再是「文档写着有、实际没有」。

| 项 | 说明 |
|---|---|
| 断网启动验证（字体已打包） | M0 未引入自定义字体，暂无可验对象；随 M2 设计系统一并验 |
| `flutter_timezone` 的取舍 | 见 §1.4，M1 需要读系统时区时再定 |
| 代码生成校验在 CI 中的实效 | 当前无带注解的源文件，该步骤形同空跑；M1 引入 drift/freezed 后才真正生效 |
| 覆盖率门禁 | 当前仅骨架，设阈值无意义；M1 领域层成型后按[测试策略 §3.3](testing-strategy.md) 设 90%/80% |

> 第 3 条值得记：**一个当前没有作用对象的 CI 步骤，和一个失灵的 CI 步骤在观测上同样是绿的。**
> M1 引入第一个 `.g.dart` 时，必须当场验证它能因「忘了重新生成」而变红。

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

### 1.4 ✅ `flutter_timezone` 未引入（M1-A 已结清）

M0 未引入该依赖，因此 AGP 9 的 KGP 弃用警告**当前不存在**。

**M1-A 结论：采用自写 MethodChannel，不引入 `flutter_timezone`**。
实现见 `android/.../MainActivity.kt`（约 20 行）与
`lib/platform/timezone/platform_time_zone.dart`。理由：我们自己的 app 模块由
AGP 内置 Kotlin 构建，不受 KGP 问题影响；少一个依赖，且规避已知的未来构建失败。

接口化（`PlatformTimeZoneSource`）后可注入假实现，测试不依赖真机；
设备报旧式别名（如 `Asia/Calcutta`）的归一在 `TzTimeZoneResolver.normalizeZoneId()`。

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

### 2.1d 🔴 第二轮变异演练：整片目录零守卫覆盖，而它报绿

上一轮修完后我以为守卫已经可信了。评审方第二轮演练找到一个**性质完全不同**的问题。

`_layerOf` 用 `^features/([^/]+)/([^/]+)/` 识别 feature，只认两级。
而 [module-map §1](../01-architecture/module-map.md) 规定的四视图是**三级**：

```
lib/features/views/gantt/presentation/x.dart
                  ↑ group(1)=views, group(2)=gantt → 不是层段 → 返回 null
```

于是 **`features/views/` 整片目录不被分类，六条规则全部静默失效**。
而那正好是 M3 四个视图所在、全项目最大的一块，也是最需要「不得绕过 Provider 直接查库」的地方。

实测：在 `lib/features/views/gantt/presentation/` 放一个同时 import `data/` 与
`domain/repositories/` 的文件，**六条守卫一条都没报**。

**这与前一轮的失效方式不同**：

| | 失效方式 | 能否靠注入违规发现 |
|---|---|---|
| 第一轮（3 漏报 + 1 假阳性） | 规则写错 / 漏写 | ✅ 能 |
| **第二轮（B3）** | 文件**根本没被扫** | ❌ **不能** —— 注入的违规文件本身就在盲区里 |

不被扫描的文件报绿，和干净的文件报绿，**观测上无法区分**。

#### 修法：治标 + 治本

**治标**：`_classify` 改为在 `features/` 之下寻找第一个层段，feature 名取该段之前的完整路径
（`features/views/gantt/presentation/` → feature = `views/gantt`）。

**治本**：新增守卫 **「lib/ 下每个文件都必须被分类到某一层」**，未分类即违规。
它把「未分类 → 静默放行」变成「未分类 → 变红」，因此**将来任何新的目录形状都会当场暴露**，
而不是安静地脱离守卫。豁免名单只有 `main.dart` / `app.dart` / `bootstrap.dart` 三条，各有理由。

修复后三条验证输出：

```
分层依赖方向正确（module-map §3） [E]
    - lib/features/views/gantt/presentation/_probe_f.dart:1
        违反: presentation 不得依赖 data
    - lib/features/views/gantt/presentation/_probe_f.dart:2
        违反: presentation 不得持有 Repository（写路径必须经 TaskCommand，FR-AI-01）

feature 之间不得跨 presentation 引用 [E]
    - lib/features/task/presentation/_probe_e.dart:1
        import '../../settings/presentation/settings_page.dart';
        违反: feature「task」的 presentation 不得引用 feature「settings」的 presentation

lib/ 下每个文件都必须被分类到某一层（否则守卫对它静默失效） [E]
  以下 2 个文件不属于任何一层，所有分层规则对它们静默失效：
    - lib/features/views/gantt/_probe_g.dart
    - lib/some_stray_file.dart
```

删除全部探针后：`00:00 +7: All tests passed!`

#### 顺带修掉的 S4 与观察项

- **S4 相对路径绕过**：跨 feature 守卫原先匹配 import 串里的 `features/` 字样，
  而 `import '../../settings/presentation/x.dart'` 根本没有这个字样。
  现在**先把 import 归一成 lib 相对路径**，层规则 / barrel 展开 / 跨 feature 判定三处共用同一套归一化，
  而不是各自对原始字符串做子串匹配。
- **白名单子串匹配**：改为锚定确切文件名，否则将来的 `task_id_generator_test.dart`
  会被静默豁免真实时钟检查。

> **这是「守卫可信度」的第三层**：
> ① 已实现的规则能红 → 注入违规可验；
> ② 该实现的规则都实现了 → 逐条比对文档可验；
> ③ **已实现的规则在所有该生效的地方都生效** → 只能靠「未分类即失败」这类**结构性断言**兜底，
> 因为它的失效方式是沉默的。

### 2.1e 🔴 第三轮：修 B3 时**过冲**，守卫开始禁止文档规定的设计

B3 的修法把 feature 名取成「层段之前的完整路径」，于是 `views/timeline` 与 `views/shared`
成了两个不同的 feature。实测：

```
feature 之间不得跨 presentation 引用 [E]
    - lib/features/views/timeline/presentation/timeline_page.dart:1
        import '../../shared/presentation/filter_bar.dart';
        违反: feature「views/timeline」的 presentation 不得引用 feature「views/shared」的 presentation
```

**但这正是文档规定要做的事**：[module-map §1](../01-architecture/module-map.md) 把
`views/shared/` 与四视图并列；[view-specs §0.3](../03-design/view-specs.md) 写明顶部筛选条是
「**同一个组件，同一份状态**」。守卫会在 M2/M3 一动手就红，而红的是正确代码。

#### 三轮失效方式的对比

| 轮次 | 失效方式 | 症状 | 「注入违规 → 红」能否发现 |
|---|---|---|---|
| 1 | 规则写错 / 漏写 | 错误代码变绿 | ✅ 能 |
| 2 (B3) | 文件根本没被扫 | 错误代码变绿，**且无声** | ❌ 不能（违规文件在盲区里） |
| 3 (B4) | 规则**管得太宽** | **正确代码变红** | ❌ **永远不能** |

B3 与 B4 是同一次改动的一体两面。第 3 类的症状与前两类相反，因此
**单向验证（只验「违规必红」）对它完全免疫**。

#### 修法：feature 粒度与层位置解耦

| | 取法 | 例（`features/views/gantt/presentation/x.dart`） |
|---|---|---|
| feature 名 | `features/` 之后的**第一段** | `views` |
| 层 | 从第 2 段起、任意深度上**第一个**层段 | `presentation` |

于是 `views/gantt` 与 `views/shared` 同属 feature `views`（可互相引用），
而 `views` 与 `task` 之间仍然受约束。B3 修的是「层认不出来」，不需要连 feature 粒度一起改。

#### 治本：守卫自带**双向**夹具表

这是本轮最重要的产出。守卫里新增三条不依赖仓库现状的测试：

| 夹具 | 锁住什么 |
|---|---|
| `_legalCases`（9 条） | **文档明文规定的正常写法必须判绿** —— 含共享筛选条、依赖倒置、路径含 `core` 段的 data 层文件等 |
| `_illegalCases`（9 条） | 违规必须判红，**且理由对得上**（不是随便红一下） |
| import 解析 | 条件 import / 跨行 import 的每个 URI 都要取到，注释里的不能取 |

为此把判定逻辑抽成纯函数 `checkImport(文件路径, import目标)`，夹具用合成输入直接驱动它。
**只跑真实文件的话，「正常写法被误判」要等到 M2 写页面时才暴露。**

#### 顺带修掉的 S5 / S6

`_importRe` 是逐行正则、只取第一个字符串字面量，被两种合法写法绕过：

```dart
// S5 条件 import —— 只有第一个 URI 被检查
import 'stub.dart' if (dart.library.io) 'package:planning_assistant/data/x.dart';
// S6 跨行 import
import
    'package:planning_assistant/data/x.dart';
```

改为按 `;` 切分指令、取出每条指令的**全部**字符串字面量，并先剥掉注释。
两条一起解决，将来的 `export ... show/hide` 也不用再补一次。

修复后：两个探针都变红（`违反: presentation 不得依赖 data`），
`timeline_page.dart` 不再被误判，`views/gantt → task` 仍然变红。

#### 顺带修掉一处文档自相矛盾

module-map §2 标题写「feature 内部结构（**强制统一**）」却只给了两级形态，
与 §1 的 `features/views/<view>/` 三级结构**自相矛盾**，此前没有任何东西检验过。
守卫照 §1 实现就撞上了 §2 的措辞 —— **这是守卫的功劳**。
§2 已改写为允许一层可选子模块，并明确「feature 边界在第一段」。

### 2.1f 🔴 第四轮：分类成功了，但那个桶里没有规则

一个文件、四条违规、**九条守卫全绿**：

```dart
// lib/features/task/domain/_probe_j.dart
import 'package:flutter/material.dart';                       // 违反 NFR-MAINT-02
import 'package:planning_assistant/data/.../drift_repo.dart'; // 违反依赖倒置
class ProbeJ {
  DateTime when() => DateTime.now();           // 违反 cross-cutting §1.2
  void check(Object? x) { assert(x != null); } // 违反 cross-cutting §3.1
}
```
```
00:00 +9: All tests passed!
```

根因是**键的数量对不上**：`_classify` 能产出 8 个层键，`_forbidden` 只有 7 个 ——
少了 `feature_domain`。而时钟守卫与 assert 守卫的过滤条件写的是 `layer == 'domain'`，
`feature_domain` 同样落在外面。一个桶，四条规则一起失效。

#### 与 B3 是同一类别，但走的是另一扇门

| | 失效路径 | 「未分类即违规」能否发现 |
|---|---|---|
| B3 | 文件**没被分类** → 无规则可套 | ✅ 能 |
| **B5** | 文件**分类成功**，但那个桶在规则表里没条目 | ❌ **不能** —— 它分类成功了 |

上一轮的结构性断言覆盖了「文件 → 层」这一跳，**没覆盖「层 → 规则」那一跳**。

#### 治本：把「层 → 规则」也锁住

新增一组四条断言（`守卫自身的完备性`）：

| 断言 | 防什么 |
|---|---|
| `_classify` 能产出的每个层键，都必须有禁止项或显式声明无禁止项 | B5 本身 |
| `_forbidden` 里不得出现 `_classify` 产不出的键 | 键名拼错 → 该条规则永远匹配不上，静默失效 |
| 所有层过滤集合只含合法层键 | 同上，针对时钟/assert 守卫的层集合 |
| 每个「领域性质」的层必须同时受时钟与 assert 约束 | 将来新增层键时只补 `_forbidden` 却漏掉按层过滤的守卫 |

配套把 `allLayerKeys` 改为**从 `_topLevelLayers` 与 `_layerSegments` 派生**而非手写 ——
它与 `_classify` 用同一对基础集合，因此不可能漂移。
时钟/assert 守卫的过滤也从零散的字面量比较改成**具名集合**。

#### 三条验证输出

**① 探针 J 四条违规齐发**（修复后）：

```
分层依赖与跨 feature 规则 [E]
    违反: feature 的 domain 层同样必须零 Flutter 依赖（NFR-MAINT-02）
    违反: feature 的 domain 不得依赖 data
领域层与应用层不得直接读环境时钟 [E]
    违反: DateTime.now() 直接读环境时钟；必须经注入的 Clock
领域层与数据层不得用 assert 表达不变量 [E]
    违反: assert 在 release 构建中被剥离；不变量必须显式 throw
```

**② 正向夹具**（防止修成一刀切）：`features/task/domain/` 引 `core/time/clock.dart` **判绿**，
与 `features/task/domain/` 引 Flutter / 引 `data/` 必须判红一并进了夹具表。

**③ 新断言自己能失败**（故意删掉 `_forbidden` 的 `feature_domain` 键）：

```
_classify 能产出的每个层键，都必须有禁止项或显式声明无禁止项 [E]
  Expected: empty
    Actual: ['feature_domain']
  以下层键没有任何规则，落进该桶的文件不受任何约束，而且它们**分类是成功的**，
  因此「未分类即违规」那条断言也发现不了： feature_domain 。
```

#### 又一处文档的洞（同样是守卫撞出来的）

module-map §2 明文允许建 `features/<name>/domain/`，而 **§3 的依赖规则表里根本没有这一行**。
守卫照 §3 逐格转写，表里没有的格自然转写不出来。§3 已补该行，并写明与顶层 `domain/` 同样严格。

> **两类断言，管的是两件事**：
> · 夹具表 → **规则内容**对不对；
> · 完备性断言 → 规则**有没有被套到所有该套的地方**。
> B3/B5 这一类失效，规则内容全是对的。这两者需要不同的断言，缺一不可。

### 2.1g ⚠️ B6：已知未封的一扇门（**M1 待办，不要当成已解决**）

评审方在 M0 通过时找到第五种失效，并**建议不要在 M0 修**。我同意，记录如下。

```dart
// lib/features/task/application/repo_exports.dart
export 'package:planning_assistant/domain/repositories/task_repository.dart';
// ↑ application 依赖 domain 接口，合法

// lib/features/task/presentation/task_page.dart
import '../application/repo_exports.dart';
class TaskPage { TaskRepository? repo; }
// ↑ presentation 依赖本 feature 的 application，合法
```
```
00:00 +13: All tests passed!
```

**presentation 拿到了 `TaskRepository`，FR-AI-01 被破坏，而没有任何一条 import 边违规。**

#### 与前四种不同类

| | 问题出在哪 |
|---|---|
| B3 / B5 | 规则**没被套到**某些文件上 → 枚举式结构断言可以封死 |
| **B6** | 规则**被正确套到了每一个文件上**，判定也没错 —— 约束本身是关于**可达性**的，而守卫看的是**相邻性** |

路径分析在原理上看不到它：要抓它得跟着 `export` 边算传递闭包，或做符号级分析。

**这不是刁钻构造**：application 层放一个 `exports.dart` 汇总本 feature 对外类型，
是 Dart 里很常见的写法。有人为少写几行 import 建了这么个 barrel，
FR-AI-01 就悄悄失效了 —— 而它是 [ADR-0002](../06-adr/ADR-0002-riverpod-clean-layering.md)「写入路径唯一」
与 V4 Agent 链路的承重墙。

#### 为什么不在 M0 修通用解

1. **当前代码库里没有任何可被它利用的实例** —— 没有 Repository、没有 barrel、没有 presentation。
   现在建闭包分析，是给一个还不存在的东西上锁，**而且锁的正确性无从验证**：
   没有真实样本可以拿来验「抓得住真的、放得过假的」。这恰好违反本项目
   [§1.4](testing-strategy.md) 反复确认的规矩。
2. **正确修法要等 M1 的形状定了才知道**。传递闭包只是一种；也可能一条更窄的规则就够。
   现在定，多半会像 B4 一样过冲。

#### M0 只做了可验证的那一半（窄规则）

给 `feature_application` 加了一条**仅对 `export` 生效**的规则：
可以 `import` Repository 接口，**不得转手 re-export**。一行规则，堵住 FR-AI-01 这面承重墙上的入口。

它是**现在就能双向验证**的，因此符合准入标准：

```
export 专属规则：application 可以 import Repository，但不得 re-export   ✅
  · checkImport(file, target)                → 空（import 判绿，不得误判）
  · checkImport(file, target, isExport: true) → 命中「不得 re-export Repository」
  · barrel 变体 domain/repositories.dart      → 同样命中
```

真实探针注入后：

```
分层依赖与跨 feature 规则 [E]
    违反: application 不得 re-export Repository —— 那会让 presentation 经本 feature
          的 barrel 间接拿到它，绕过 TaskCommand（FR-AI-01）。import 它是允许的
```

#### 明确的未完成状态：剩余入口已枚举完，共三条

**通用的可达性分析没有做。** 「其它层 re-export」具体是哪些，已推导并**逐条实测确认开着**：

| # | 洗白路线 | 实测 |
|---|---|---|
| 1 | `platform/` → `export` Repository | ✅ 开着 |
| 2 | `domain/entities/` → `export ../repositories/` | ✅ 开着 |
| 3 | `features/*/domain/` → `export` Repository | ✅ 开着 |
| 3b | 同上，但**跨 feature** 消费（`features/settings/domain/` 被 `features/task/presentation/` 引用） | ✅ 开着 —— 跨 feature 规则只管 presentation→presentation，管不到这条 |

**枚举的完整性推导**（按 `_forbidden` 表逐层过，不是「想到几条算几条」）：
presentation 能引用的层是 `core` / `design` / `domain` / `platform` / 本 feature 的
`application` 与 `domain`；其中 `core` 与 `design` 禁 `/domain/`，`application` 已被
export 规则封住，`data` 虽能拿到 Repository 但 presentation 引用不到它 —— 剩下的**恰好三条**。

> 这个枚举**否掉了「再打三个补丁」这个选项**。路线 2（`domain/entities/barrel.dart` 汇总导出）
> 是 Dart 里最自然的写法之一，补丁式修法会一直漏。
> **它反过来证明了「不做通用解、明确移交 M1」是对的**：这个洞的形状本就需要闭包分析。

#### M1 的双向验收用例（四条一起给，缺一条就区分不出「修对了」和「一刀切」）

| 用例 | 修法上线后必须 |
|---|---|
| 路线 1 / 2 / 3 / 3b | **全部变红** |
| `domain/repositories/_barrel.dart` 再导出自己 | **仍然绿** —— 不得一刀切禁掉所有 export |
| `application` **import**（非 export）Repository | **仍然绿** |

最后两条是防过冲的：只验「洗白路线变红」区分不出「修对了」与「把 export 整个禁掉」，
而后者会在 M1 写第一个 domain barrel 时立刻炸。这正是 [§2.1e](#21e-第三轮修-b3-时过冲守卫开始禁止文档规定的设计) 的教训。

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
| 架构守卫测试（**14 条**：双向夹具 + 完备性断言 + export 专属规则） | ✅ 四种失效方式各修一轮；第五种（B6 可达性）已记录，通用解移交 M1 |
| 坏测试扫描器 `tool/lint_tests.dart` | ✅ 自检 + 真实仓库失败演示 |
| rrule 契约测试（14 条） | ✅ |
| uuid v7 测试（5 条） | ✅ |
| 应用冒烟（2 条） | ✅ |
| CI（analyze / format / codegen 校验 / test / **守卫有效性** / build） | ✅ |
| `flutter build apk --debug` | ✅ |

**测试总数 36，`dart analyze --fatal-infos --fatal-warnings` 零问题，`dart format` 无差异。**

---

## 4. 未完成 / 移交 M1

> 评审方指出的 S3（文档写了但未实现的两条守卫）已在本轮补齐：
> `tool/lint_tests.dart` 见 §2.1c；「测试代码不得使用真实时钟」已作为守卫测试的一条实现。
> 两条都不再是「文档写着有、实际没有」。

| 项 | 说明 |
|---|---|
| **B6 可达性绕过（通用解）** | ⚠️ **未解决**。只封了 `application` re-export 这一个入口。剩余入口已枚举完并实测确认：`platform/`、`domain/entities/`、`features/*/domain/`（含跨 feature 变体）共三条。M1 需做闭包分析而非补丁，验收用例见 §2.1g |
| 断网启动验证（字体已打包） | M0 未引入自定义字体，暂无可验对象；随 M2 设计系统一并验 |
| ~~`flutter_timezone` 的取舍~~ | ✅ **M1-A 已结清**：自写 MethodChannel，不引入该包。见 §1.4 |
| ~~代码生成校验在 CI 中的实效~~ | ✅ **M1-C 已结清**。引入 drift 表定义后实测：把「改了注解但没重新生成」的状态入索引（索引 = 新源码 + 旧 `.g.dart`），CI 跑完 `build_runner` 后 `git diff` 有 **75 行**差异 → `exit 1`。同时验证了 format 与 codegen 两步不打架（drift 产物本身即 `dart format` 干净） |
| 覆盖率门禁 | 当前仅骨架，设阈值无意义；M1 领域层成型后按[测试策略 §3.3](testing-strategy.md) 设 90%/80% |

> 第 3 条值得记：**一个当前没有作用对象的 CI 步骤，和一个失灵的 CI 步骤在观测上同样是绿的。**
> M1 引入第一个 `.g.dart` 时，必须当场验证它能因「忘了重新生成」而变红。

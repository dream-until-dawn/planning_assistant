# 测试策略

> **本项目的第一原则：永远绿的测试等于没有测试。**
> 一个测试的价值不在于它今天通过，而在于**当实现被改坏时它会失败**。
> 本文的大半篇幅在讲怎么证明测试真的有这个能力。

## 1. 测试有效性的判定标准

任何测试进入代码库前，作者必须能回答：

> **「如果我把被测实现改成什么样，这个测试会红？」**

答不上来的测试**不许合入**。这不是修辞 —— 见 §3 的执行机制。

### 1.1 明令禁止的测试反模式

| 反模式 | 例子 | 为什么是垃圾 |
|---|---|---|
| 无断言测试 | 只调用一遍函数，不 `expect` | 只能发现崩溃，发现不了错误 |
| 重言测试 | `expect(sut.value, sut.value)` | 恒真 |
| 对着实现抄 | 期望值由「跑一遍看输出」直接粘贴 | 实现错了测试跟着错 |
| 过度 mock | 把被测对象的协作者全 mock，断言的全是「调用了什么」 | 测的是实现细节，重构必红、改坏不红 |
| 捕获式断言 | `expect(() => f(), returnsNormally)` 作为唯一断言 | 同无断言 |
| 快照即真理 | golden 文件出错时直接 `--update-goldens` | golden 变成了「记录现状」而不是「校验预期」 |
| 条件跳过 | `if (Platform.isWindows) return;` 悄悄跳过 | 永远绿的经典手法 |
| **单样本推全称** | 用一条数据验证后写下「严格往返」「所有版本都…」 | 见 §1.2，本项目已经栽过一次 |
| **用 `assert` 表达不变量** | `assert(不变量)` | release 构建整条剥离 → debug 绿、线上零保护。见[横切关注点 §3.1](../01-architecture/cross-cutting.md) |

> 「对着实现抄」是最隐蔽的一种。对策：**期望值必须有独立来源** ——
> 手算、查 RFC、查规范文档、或用探针实测**并把实测过程记录在文档里**（如
> [环境探针结论](environment-notes.md) §2.1 中 `BYMONTHDAY=31` 的实测记录）。
>
> 更强的做法：**规范给期望值，探针只负责验证库是否符合规范**。
> 若反过来让库的实际输出决定期望值，库有 bug 时测试会跟着一起错。
> [重复引擎 §7](../02-domain/recurrence-engine.md) 的探针表因此专门加了一列「规范依据」。

### 1.2 单样本不能支撑全称结论（本项目的真实教训）

设计阶段我们用 `RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=TU,TH` 测出 `roundtrip=true`，
就在三份文档里写下了「**RRULE 字符串严格往返**（已实测）」。

补一条带 `UNTIL` 的样本后，结论立刻被推翻：`toString()` 会丢掉 `UNTIL` 的 `Z` 后缀，
产出**不符合 RFC 5545** 的规则串。更糟的是 `rrule` 自己解析回来仍是等值的，
所以**任何只用本地往返做断言的测试都发现不了**，只有外部消费者（服务端、`.ics` 互通）会错 ——
而这两者正是我们选择 RRULE 格式的全部理由。

**由此定下的规矩**：

1. 「严格 / 所有 / 总是 / 永远」这类**全称词**出现在结论里时，必须给出**覆盖各个分支的样本集**，
   而不是一条样本。往返类结论尤其要覆盖**每一个可选字段**。
2. 往返测试不能只断言 `decode(encode(x)) == x`（语义等价），
   还要断言 `encode(x) == 原始字符串`（**字节等价**），否则编码缺陷会被解码端的宽容掩盖。
3. 评审时看到「已实测」三个字，要问的是**测了几个样本、覆盖了哪些分支**。

## 2. 测试金字塔与责任划分

```
                  ▲  integration_test/   真机 / 模拟器端到端
                 ╱ ╲   少量、覆盖关键旅程（新增任务→看见→提醒）
                ╱   ╲
               ╱     ╲ test/presentation/ + test/golden/
              ╱       ╲  Widget 行为 + 视觉回归
             ╱         ╲
            ╱           ╲ test/application/  UseCase 编排
           ╱             ╲
          ╱               ╲ test/data/  Drift 真实内存库（不 mock DB）
         ╱                 ╲
        ╱───────────────────╲ test/domain/  纯 Dart，最厚的一层
```

| 层 | 用什么 | 不用什么 |
|---|---|---|
| `test/domain/` | 纯函数、值对象、真实实现 | **零 mock**（领域层没有依赖，无可 mock） |
| `test/data/` | **真实 SQLite 内存库**（`NativeDatabase.memory()`） | 不 mock DAO —— mock 掉数据库就测不出 SQL 写错 |
| `test/application/` | 真实领域层 + Fake 仓储（手写，非 mock 框架） | 少用 mocktail 的 `verify`，多断言最终状态 |
| `test/presentation/` | `ProviderScope` override 注入 Fake | 不打桩 Widget 内部 |
| `integration_test/` | 真实全栈 | — |

### 2.1 为什么数据层坚持用真实 SQLite

Drift 支持 `NativeDatabase.memory()`，跑得比 mock 只慢一点，但能抓到：外键约束、唯一索引冲突、
SQL 语法错误、事务回滚行为、迁移脚本错误。这些恰恰是 mock 永远抓不到、而线上一定会炸的东西。

> ✅ **已实测确认可行**（2026-09-07）：`flutter test` 在本机 Windows 宿主上直接跑通
> `NativeDatabase.memory()`，报告 SQLite **3.53.4**，**不需要 Visual Studio C++ 组件**。
> 验证方式不只是「跑通」——测试里故意插入重复主键并断言抛出 `SqliteException`，
> 确认这是真的 SQL 引擎在执行约束，而不是一个什么都接受的桩。

## 3. 执行机制：怎么保证上面这些不是口号

### 3.1 变异演练（Mutation Drill）—— 核心机制

每个里程碑结束时，对**关键模块**做一次变异演练：

1. 从下表挑选变异算子，手工改坏实现（改一处，跑全量测试，还原）。
2. 记录「哪些变异没被任何测试抓到」。
3. **每个存活的变异必须补一条测试**，或书面说明为什么可以放过。
4. 结果记入 `docs/05-engineering/mutation-drills/M{n}.md`，入库。

| 变异算子 | 具体做法 |
|---|---|
| 边界移位 | `<` ↔ `<=`，`>` ↔ `>=` |
| 常量篡改 | `0` → `1`，`30` → `31` |
| 条件反转 | `if (x)` → `if (!x)` |
| 返回值替换 | 返回空列表 / null / 默认值 |
| 语句删除 | 删掉一次赋值、一次 `await`、一次事务提交 |
| 顺序调换 | 交换两条相邻语句 |
| 异常吞掉 | 把 `throw` 改成 `return` |

**强制变异演练的模块**（这些地方出错用户会直接受损）：

- 重复引擎（`domain/recurrence/`）
- 状态机（`domain/policies/`）
- 时间换算（`core/time/`）
- 同步信封与 outbox 写入（`data/outbox/`）
- 导入导出往返（`data/dto/`）

### 3.2 反向测试优先（Red-First）

**任何 bug 修复的第一个提交必须是「一条会红的测试」**，第二个提交才是修复。
PR 里能看到测试从红变绿。这条由 code review 检查。

### 3.3 CI 门禁

| 门禁 | 阈值 | 失败后果 |
|---|---|---|
| 全量测试通过 | 100% | 阻止合并 |
| 领域层行覆盖率 | ≥ 90% | 阻止合并 |
| 数据层行覆盖率 | ≥ 80% | 阻止合并 |
| 整体行覆盖率 | ≥ 70% | 警告 |
| 分层依赖守卫 | 0 违规 | 阻止合并 |
| `dart analyze` | 0 error、0 warning | 阻止合并 |
| 重复引擎基准 | 展开 1 年 ≤ 50ms | 阻止合并 |
| 无断言测试扫描 | 0 处 | 阻止合并 |

> **覆盖率是必要条件不是充分条件**。90% 覆盖率的重言测试依然一文不值。
> 覆盖率门禁的真正作用是防止「新代码完全没测试」，杀死坏测试靠 §3.1 的变异演练。

### 3.4 自动化的坏测试扫描

`tool/lint_tests.dart` 在 CI 中运行，扫描 `test/` 目录并报错：

- 测试函数体内没有任何 `expect(` / `expectLater(`
- 出现 `if (Platform.` 或 `if (kIsWeb)` 形式的跳过
- 出现被注释掉的 `expect(`
- `skip:` 参数未附带说明字符串

## 4. 时间相关测试的特殊纪律

时间是本项目最大的 bug 温床，也是最容易写出永远绿测试的地方。

1. **禁止真实时钟**。所有测试注入 `FixedClock` 或 `fake_async`。
   守卫扫描：`test/` 下出现 `DateTime.now()` 即报错。
2. **必须跨时区跑**。关键测试集参数化在 `Asia/Shanghai`、`America/New_York`（有 DST）、
   `UTC`、`Pacific/Kiritimati`（UTC+14）四个时区各跑一遍。
3. **必须覆盖 §边界**：闰年 2/29、月末 29/30/31、DST 跳表与回拨、跨年、跨时区迁移。
   完整清单见[重复引擎](../02-domain/recurrence-engine.md) §6。

## 5. 黄金用例表（Golden Cases）

领域层的核心行为用**表驱动测试**，用例表与期望值**写在文档里**，测试代码只是读表执行：

| 表 | 位置 | 条目数（V1 目标） |
|---|---|---|
| 重复展开 | [重复引擎 §6](../02-domain/recurrence-engine.md) | ≥ 30 |
| 状态迁移 | [任务生命周期 §7](../02-domain/task-lifecycle.md) | ≥ 25（含全部非法迁移） |
| 时间换算 | [横切关注点 §1](../01-architecture/cross-cutting.md) | ≥ 20 |
| 导入导出往返 | [数据模型 §6](../02-domain/data-model.md) | ≥ 10 |

好处：期望值经过文档评审，而不是「作者跑一遍抄下来的」。

## 6. 架构守卫测试

`test/architecture/layer_dependency_test.dart` 解析 `lib/**/*.dart` 的 import，断言
[模块与目录规范](../01-architecture/module-map.md) §3 的依赖规则。额外守卫：

| 守卫 | 断言 |
|---|---|
| 领域层纯净 | `lib/domain/**` 不含 `package:flutter/` |
| 写路径唯一 | `lib/features/*/presentation/**` 不 import `domain/repositories/` |
| 时钟注入 | `lib/domain/**` 与 `lib/features/*/application/**` 不含 `DateTime.now()` |
| 软删除不遗漏 | 所有 DAO 查询方法经由带 `deletedAt IS NULL` 的基类（用生成代码检查） |
| 命令可序列化 | 每个 `TaskCommand` 子类都有 JSON 往返测试 |

## 7. 视觉回归（Golden Tests）

- 覆盖设计系统的基础组件 + 四视图的典型状态（空态、单条、密集、超长文本、200% 字号）。
- **明暗主题各一份**。
- golden 更新必须单独提交，PR 描述说明「为什么视觉变了」。
  **禁止**在功能 PR 里顺手 `--update-goldens`。

## 8. 集成测试覆盖的关键旅程

| # | 旅程 |
|---|---|
| J-01 | 冷启动 → 新增单项任务 → 在四个视图都能看见 |
| J-02 | 新增每周重复任务 → 完成本周这次 → 下周仍为待办 |
| J-03 | 新增 3 阶段事项 → 完成第 2 阶段 → 甘特图分段正确 |
| J-04 | 设提醒 → 改任务时间 → 提醒时刻跟着变 |
| J-05 | 导出 → 清空数据 → 导入 → 数据等价 |
| J-06 | 改主题/分类 → 全视图即时生效 |
| J-07 | 杀进程重启 → 已提交数据仍在 |

## 9. 测试目录约定

```
test/
├── domain/           纯 Dart，跑得最快，最先跑
├── data/             真实内存 SQLite
├── application/      UseCase
├── presentation/     Widget
├── golden/           视觉回归 + goldens/ 图片
├── architecture/     守卫测试
├── support/          共享工具：FixedClock、FakeRepositories、建造器
└── README.md         本文的执行摘要 + 新人须知
integration_test/     端到端
```

**测试数据一律用建造器**（`TaskBuilder().withStages(3).recurringWeekly().build()`），
不手写巨型字面量 —— 否则加一个字段要改几百处，最后没人愿意加测试。

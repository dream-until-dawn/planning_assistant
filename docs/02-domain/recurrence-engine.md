# 重复规则引擎

> 对应需求 FR-TASK-03/04/05/06/07、NFR-REL-03、NFR-PERF-04。
> 这是全项目**最容易出错**的模块，也是测试投入最重的模块。

## 1. 职责边界

引擎是**纯函数**，输入输出都是值对象，不碰数据库、不碰时区系统 API：

```dart
/// 在 [window] 内展开 [task] 的所有发生实例，应用 [overrides] 后返回。
List<Occurrence> expand({
  required RecurrenceContext task,   // DTSTART + RRULE + 时长 + 时区
  required DateRange window,         // 可见时间窗（墙钟日期）
  required List<OccurrenceOverride> overrides,
});
```

不在引擎职责内：查库、排通知、决定 UI 展示顺序。

## 2. 规则的存储形态

存 **RFC 5545 的 `RRULE:` 字符串**，不发明私有格式。理由见 [ADR-0004](../06-adr/ADR-0004-rfc5545-recurrence.md)：

- 与 iCalendar / Google Calendar / 系统日历互通，将来导入导出 `.ics` 不失真；
- 云端（V3）用任何语言的成熟库都能解析，不需要移植客户端逻辑；
- 已有经过验证的 Dart 实现（`rrule` 包），不必自造。

### 2.1 V1 支持的规则子集

| UI 上的说法 | 生成的 RRULE |
|---|---|
| 每天 | `FREQ=DAILY` |
| 每 N 天 | `FREQ=DAILY;INTERVAL=N` |
| 每周的周一/三/五 | `FREQ=WEEKLY;BYDAY=MO,WE,FR` |
| 每 N 周 | `FREQ=WEEKLY;INTERVAL=N;BYDAY=…` |
| 工作日 | `FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR` |
| 每月 15 号 | `FREQ=MONTHLY;BYMONTHDAY=15` |
| 每月最后一天 | `FREQ=MONTHLY;BYMONTHDAY=-1` |
| 每月第 2 个周五 | `FREQ=MONTHLY;BYDAY=2FR` |
| 每月最后一个周五 | `FREQ=MONTHLY;BYDAY=-1FR` |
| 每年 5 月 20 日 | `FREQ=YEARLY;BYMONTH=5;BYMONTHDAY=20` |
| 结束条件：重复 N 次 | 追加 `COUNT=N` |
| 结束条件：到某日止 | 追加 `UNTIL=yyyyMMddTHHmmssZ`（**真 UTC**，且必须取该日**日终**，见 §2.2 与 §6.1c） |

> **UI 只暴露上表**。用户不需要看见 RRULE 语法。
> 但存储层保留完整 RRULE 表达能力 —— 从导入的 `.ics` 来的复杂规则能被正确保存与展开，只是 UI 显示为「自定义规则」且编辑时提示会简化。

### 2.2 `UNTIL` 的时间域必须显式换算

这是本引擎**唯一一处**时间域会被搞混的地方，且错了不会报错，只会静默多一次或少一次。

**两条互相矛盾的约束**：

| 约束 | 来源 |
|---|---|
| DTSTART 为「local time + TZID」时，`UNTIL` **MUST** 是真 UTC | RFC 5545 §3.3.10 原文：<br>"If the 'DTSTART' property is specified as a date with UTC time **or a date with local time and time zone reference**, then the UNTIL rule part MUST be specified as a date with UTC time."（已回原文核对） |
| 展开全程在「假 UTC 墙钟域」进行（§4） | `rrule` 包的设计 |

而 **`rrule` 对 `UNTIL` 只做朴素比较，不做任何时区换算**（已实测，见下）。
两者直接冲突：把真 UTC 的 `UNTIL` 丢进墙钟域比较，边界必错。

**实测证据**（纯 Dart 探针，`rrule 0.2.18`）：

```
FREQ=DAILY;UNTIL=20260930T095959Z，start = 墙钟 09-28T23:00
  → 实例 = [09-28T23:00, 09-29T23:00]      09-30T23:00 被丢掉
FREQ=DAILY;UNTIL=20260930T235959Z，同一 start
  → 实例 = [09-28T23:00, 09-29T23:00, 09-30T23:00]
```

没有任何时区参数参与，边界完全由裸值比较决定 —— 证实是朴素比较。

**具体后果**（若不换算，直接把真 UTC 的 UNTIL 喂进去）：

| 场景 | 错误 |
|---|---|
| `Pacific/Kiritimati` (UTC+14)，「每天 23:00，到 9/30 止」 | 最后一次**凭空消失** |
| `America/New_York` (UTC-4)，「每天 01:00，到 9/30 止」 | **多出一次** 10/1 |

反过来，若为了让展开正确而存「墙钟值加个 `Z`」，则导出的 RRULE 串不符合 RFC，
服务端与外部 `.ics` 会按真 UTC 解读，偏差最多 ±14 小时 ——
而「服务端能独立解析」与「`.ics` 互通不失真」正是 [ADR-0004](../06-adr/ADR-0004-rfc5545-recurrence.md) 立论的两根支柱。

#### 决定：存储用真 UTC，喂给 rrule 前换算成墙钟

```
        存储 / 导出（RFC 合规）              引擎内部（假 UTC 墙钟域）
   RRULE:...;UNTIL=20260930T095959Z  ◄──────────────►  09-30T23:59:59
                    ▲                                        ▲
                    │  core/time:                            │
                    │    untilForStorage(wall, tzid) ────────┘
                    └─── untilForExpansion(utc, tzid) ◄───────
```

`core/time` 暴露且**仅暴露**这一对函数，禁止在别处做 `UNTIL` 的时区拼接：

```dart
/// 墙钟结束点 → 可写入 RRULE 的真 UTC（导出、落库时用）
DateTime untilForStorage(LocalWallTime wallEnd, String timeZoneId);

/// 存储中的真 UTC UNTIL → 可喂给 rrule 的假 UTC 墙钟值（展开时用）
DateTime untilForExpansion(DateTime utcUntil, String timeZoneId);
```

两者必须满足**往返恒等**：`untilForExpansion(untilForStorage(w, tz), tz) == w`，这条本身就是一条测试。

同样受影响的还有[数据模型 §4.4](data-model.md#44-本次及以后修改怎么实现fr-task-06) 的「本次及以后」分裂点。

> `COUNT` **不受此影响**（纯计数，与时区无关），因此在测试中作为对照组：
> 同一规则用 `COUNT` 表达时四个时区结果应完全一致，用 `UNTIL` 表达时若换算错则会分叉。

### 2.3 编码 RRULE 必须显式开启 `isTimeUtc`（强制）

**`rrule` 的 `toString()` 默认会丢掉 `UNTIL` 的 `Z` 后缀**（实测）：

```
输入 : RRULE:FREQ=DAILY;UNTIL=20260930T235959Z
toString() 输出 : RRULE:FREQ=DAILY;UNTIL=20260930T235959     ← Z 没了，往返有损
```

根因：`RecurrenceRuleToStringOptions.isTimeUtc` 默认为 `false`（已读包源码确认）。

丢掉 `Z` 之后的串按 RFC 5545 是**浮动本地时间**，而 §2.2 引用的条款明确要求此处必须是真 UTC ——
也就是说，**我们自己的导出路径会产出不合规的规则串**，外部解析器会按浮动时间理解它。
`rrule` 自己解析回来仍是等值的（它把无 `Z` 的值也当 UTC），所以**本地测试不会发现**，只有外部消费者会错。

**强制做法**：项目内**禁止直接调用 `rule.toString()`**，一律走封装：

```dart
// domain/recurrence 内唯一的编码出口
const _codec = RecurrenceRuleStringCodec(
  toStringOptions: RecurrenceRuleToStringOptions(isTimeUtc: true),
);
String encodeRrule(RecurrenceRule r) => _codec.encode(r);
```

lint 规则：`lib/` 下出现 `RecurrenceRule` 实例的 `.toString()` 调用即报错。

#### 正确的往返性质不是「字节等价于输入串」

补测多部件规则后发现：**即使开了 `isTimeUtc: true`，输出也不会字节等价于输入**，因为编码器会重排部件：

```
输入 : RRULE:FREQ=MONTHLY;BYMONTHDAY=-1;UNTIL=20261231T155959Z
输出 : RRULE:FREQ=MONTHLY;UNTIL=20261231T155959Z;BYMONTHDAY=-1     ← 顺序变了
```

但这**不是缺陷**：RFC 5545 的 RRULE 各部件是**无序**的，重排后语义完全等同。
真正要断言的是下面三条（6 个样本实测全部 PASS，其中 4 个字节不等价）：

| 性质 | 断言 | 为什么 |
|---|---|---|
| **C1 合规性** | 含 `UNTIL` 的输出必须匹配 `UNTIL=\d{8}T\d{6}Z` | 缺 `Z` 就是浮动时间，违反 RFC 且误导外部解析器 |
| **C2 语义往返** | `decode(encode(x)) == x` | 不丢信息 |
| **C3 规范形幂等** | `encode(decode(encode(x))) == encode(x)` | 我们的编码是稳定的规范形，不会每存一次变一次 |

**由此定下的存储规则**：落库时存**我们自己 `encodeRrule()` 产出的规范形**，
而不是用户输入或 `.ics` 导入的原始串。这样库里的规则串形态唯一、可比较、可去重。

#### 由此得到一条可检查的数据不变量

对库中**任何**一条 `tasks.recurrenceRule`（记为 `s`）：

```
encode(decode(s)) == s          // s 必须已经是规范形
```

这不是又一条编解码性质，而是**对数据本身的约束**，可以直接跑在真实数据上：

- 由 C3（幂等）可推出：只要 `s` 是 `encode()` 的产物，该式必然成立。
  因此它等价于断言「**所有入库路径都经过了 `encodeRrule()`**」——
  包括 `.ics` 导入、云端下发（V3）、以及将来 Agent 产出的命令（V4）。
- 一旦某条路径忘了规范化，这条不变量立刻变红，而 C1/C2/C3 都不会 ——
  因为它们只考察编解码器本身，不考察**调用方有没有用它**。

落地方式：

| 位置 | 做法 |
|---|---|
| 写入路径 | `CommandDispatcher` 在持久化前统一规范化，不依赖各调用方自觉 |
| 测试 | R-09i：导入一条**非规范序**的外部规则，断言入库后满足上式 |
| 数据自检 | 启动时的一致性检查（与迁移检查同一入口）扫描全表，发现违反即记日志并自动规范化 |

> 这条是评审方提出的视角：编解码性质对了，不代表**每条数据都真的走了那条路**。
> 前者是单元测试能覆盖的，后者只能靠对数据下断言。

> **这一节被自己的探针连续推翻了两次**：
> 初版用一条不含 `UNTIL` 的规则测出「严格往返」；补 `UNTIL` 样本后推翻，改成「加 `isTimeUtc` 即严格无损」；
> 再补多部件样本后**又**被推翻 —— 因为那次仍然只测了单部件的 `FREQ=DAILY;UNTIL=…`。
> 教训见[测试策略 §1.2](../05-engineering/testing-strategy.md)：
> **样本集必须覆盖各个分支，而不是「多加一个样本」就算数。**

## 3. 展开算法

```
输入: DTSTART(墙钟) + RRULE + duration + timeZoneId + window + overrides
                     │
      ┌──────────────▼───────────────┐
   1. │ 在「墙钟域」展开原始发生时刻     │  ← rrule 包，全程 isUtc=true 的假 UTC
      └──────────────┬───────────────┘
                     │  得到 rawStarts: List<LocalWallTime>
      ┌──────────────▼───────────────┐
   2. │ 每个 rawStart 算出 occurrenceKey │  key = 原始墙钟串，见 data-model §4.2
      └──────────────┬───────────────┘
                     │
      ┌──────────────▼───────────────┐
   3. │ 应用 overrides:               │
      │  · skip   → 丢弃              │
      │  · modify → 覆盖字段（可能移出/移入窗口）│
      └──────────────┬───────────────┘
                     │
      ┌──────────────▼───────────────┐
   4. │ 补齐被 modify 移入窗口的实例    │  ← 关键：override 可能把窗口外的一次挪进来
      └──────────────┬───────────────┘
                     │
      ┌──────────────▼───────────────┐
   5. │ 按 start 排序，返回 Occurrence  │
      └──────────────────────────────┘
```

### 3.1 第 4 步为什么必须存在

用户把 10 月 5 日那次挪到了 9 月 8 日。当前窗口是 9 月，展开 9 月的规则时不会产生 10/5 那次，于是这条被挪进来的实例会**凭空消失**。

因此展开时必须**额外查询 window 内 `planDateOverride` 命中的所有 override**，即使它们的原始时刻在窗口外。这是最容易漏的一个 bug，已列入必测用例（§6）。

## 4. 时区处理

`rrule` 包是**时区无关**的：它要求所有 `DateTime` 的 `isUtc == true`，但把它们当作纯墙钟处理。这刚好符合我们的模型：

```
墙钟展开（rrule，假 UTC）  ──► LocalWallTime 列表
                                     │
                     只在需要绝对时刻时（排通知/排序跨时区任务）
                                     ▼
              TimeZoneResolver.toInstant(wall, task.timeZoneId)
```

**绝不**把用户的本地 `DateTime.now()` 直接喂给 `rrule`。统一走 `core/time` 的转换器（见[横切关注点](../01-architecture/cross-cutting.md) §1）。

⚠️ **`UNTIL` 是这条流程唯一的例外入口**：它在存储中是**真 UTC**，必须先经 `untilForExpansion()`
换算成墙钟值才能进入上图，否则边界会静默错一次。完整论证见 §2.2。

### 4.1 夏令时的两种坑

| 情形 | 现象 | 本项目的处理 |
|---|---|---|
| 春季跳表：02:00→03:00，02:30 不存在 | 「每天 02:30」这一天没有合法时刻 | 顺延到该时段结束后的第一个合法时刻（03:00），并在实例上打 `dstAdjusted` 标记供 UI 提示 |
| 秋季回拨：01:30 出现两次 | 一个墙钟对应两个瞬时 | 取**第一个**（较早的 UTC offset），与多数日历应用一致 |

> 中国大陆当前无夏令时，但用户可能出国，且 `timeZoneId` 可为任意 IANA 值。这两条必须有测试，不能因为「国内用不到」就不做 —— 那正是「永远绿的测试」的温床。

#### 4.1.1 时长语义：墙钟，且**两端各自独立解析**（决定）

跨 DST 时「声明 3 小时、实际经过 2 或 4 小时」不是缺陷，是墙钟语义的必然结果。
但实现做了选择而文档没写下来，等于没决定 —— 此处定死。

| 决定 | 内容 |
|---|---|
| 时长语义 | **墙钟**。`durationMinutes` 是墙钟分钟数，不是绝对时长 |
| 解析方式 | `start` 与 `end` **各自**过一遍 `resolve()`，互不影响 |
| 结果 | 两端都保证是该时区当天**真实存在**的墙钟 |

**为什么不选 RFC 5545 时间型 `DURATION`（`PT3H`）的精确时长语义**：本项目的存储是
`endDate` / `endMinute`（墙钟端点），不是时长（data-model §3.1）。选精确时长等于
在 ADR-0005 之外再引入第二套时间模型 —— 同一条任务的两个端点用两种语义，
任何跨 DST 的推理都要先问「这个字段是哪种」。宁可接受墙钟语义的固有后果。

**必须两端都解析**：只解析 `start` 的话，`end` 会落在一个当天不存在的墙钟上。
后果不止显示错 —— `reminders.kind = relativeToEnd` 排期时会对 `end` 做换算，
换算结果与 UI 显示的时刻不一致，两边永久对不上。

跨 DST 时的实际经过时长（可与声明值不同）：

| 场景 | 输入 | `end` | 实际经过 |
|---|---|---|---|
| 春季跳表当日 | `America/New_York` 01:00 + 180min | 04:00 | **120 分钟** |
| 春季跳表，`end` 落进空隙 | 同上 01:30 + 60min | **03:00**（02:30 不存在，已顺延） | 30 分钟 |
| 秋季回拨当日 | 同上 01:00 + 180min | 04:00 | **240 分钟** |
| 普通日对照 | 同上 01:00 + 180min | 04:00 | 180 分钟 |
| 跨天（无 DST） | 23:00 + 120min | 次日 01:00 | 120 分钟 |

需要「绝对时长」的场景（如统计实际投入时间）由调用方用
`toInstant(end) - toInstant(start)` 自行计算，**不改存储语义**。

## 5. 性能

NFR-PERF-04 要求「展开 1 年实例 ≤ 50ms」。措施：

1. **惰性 + 窗口化**：只展开可见窗口 + 前后各一屏的缓冲，不展开全部历史。
2. **记忆化**：缓存键 `(taskId, task.revision, windowStart, windowEnd)`；任务 `revision` 变化即失效。
3. **`COUNT`/`UNTIL` 前置截断**：先算规则的理论终点，窗口整体在其后时直接返回空列表，不进入迭代。
4. **基准测试作为门禁**：`test/domain/recurrence_benchmark_test.dart` 断言耗时上限；变慢即 CI 红。

## 6. 必测用例清单

这份清单是[测试策略](../05-engineering/testing-strategy.md)里「黄金用例表」的一部分。**每一条都必须能被一个具体的实现缺陷弄红**。

### 6.1 基础展开

| # | 用例 | 期望 |
|---|---|---|
| R-01 | `FREQ=DAILY` 从 9/7 起，窗口 9/7–9/13 | 7 个实例 |
| R-02 | `FREQ=DAILY;INTERVAL=3` | 9/7, 9/10, 9/13 |
| R-03 | `FREQ=WEEKLY;BYDAY=MO,WE,FR` | 只落在周一三五 |
| R-04 | `FREQ=DAILY;COUNT=3` | 恰好 3 个，第 4 个不出现 |
| R-05 | `FREQ=DAILY;UNTIL=<恰为某实例时刻>` | **包含**该实例。依据：RFC 5545 §3.3.10「bounds the recurrence rule in an **inclusive** manner」（原文核对），实测亦确认 |
| R-06 | `UNTIL` 早于某实例 1 秒 | 排除该实例（闭区间的另一侧边界） |

### 6.1b `UNTIL` 的时区边界（§2.2 的直接验收，初版一条都没有）

这组用例的期望值来自 RFC + 手算，**不是**跑一遍看输出。

| # | 时区 | 规则（用户视角） | 期望 |
|---|---|---|---|
| R-07 | `Pacific/Kiritimati` (UTC+14) | 每天 **23:00**，到 9/30 止 | 9/30 那次**存在**（最容易被错误丢弃的情形） |
| R-08 | `America/New_York` (UTC-4/-5) | 每天 **01:00**，到 9/30 止 | 10/1 那次**不存在**（最容易被错误多出的情形） |
| R-09 | `Pacific/Niue` (UTC-11) | 每天 **00:30**，到 9/30 止 | 9/30 那次存在，10/1 不存在 |
| R-09b | `Asia/Shanghai` (UTC+8) | 每天 23:30，到 9/30 止 | 9/30 那次存在 |
| R-09c | **对照组**：R-07..R-09b 改用 `COUNT` 表达 | 四个时区结果**完全一致**（`COUNT` 与时区无关）。若 `UNTIL` 组分叉而 `COUNT` 组一致，即定位到换算缺陷 |
| R-09d | `untilForExpansion(untilForStorage(w, tz), tz) == w` | 对上述全部时区往返恒等 |
| R-09e | `encodeRrule()` 的 **C1/C2/C3**（§2.3） | 样本集必须**覆盖各分支**：无 `UNTIL` / 单部件 + `UNTIL` / 多部件 + `UNTIL` / `COUNT` / 带负序号 `BYDAY`。断言合规性 + 语义往返 + 规范形幂等，**不断言字节等价于输入串** |

### 6.1c 「到某日止」的日终语义（探针场景 4 暴露的产品级坑）

实测：同一条 `UNTIL=20260910T000000Z`

| DTSTART 时刻 | 展开结果 |
|---|---|
| `00:00` | 4 次，末次 **9/10** |
| `07:00` | 3 次，末次 **9/9** ← 9/10 那次**静默消失** |

用户在 UI 上选的是「重复到 9 月 10 日**为止**」，心智里 9/10 当天应当包含在内。
若实现时把结束日期直接当成该日 `00:00` 去写 `UNTIL`，**所有非零点开始的任务都会少一次** ——
而这是绝大多数任务。

**规则**：UI 的「到某日止」必须解释为**该日在任务时区的日终**（`23:59:59` 墙钟），
再经 `untilForStorage()` 换算成真 UTC。

| # | 用例 | 期望 |
|---|---|---|
| R-09f | 「每天 07:00，到 9/10 止」 | 包含 9/10 那次（共 N 次），**不是** N-1 次 |
| R-09g | 「每天 00:00，到 9/10 止」 | 同样包含 9/10 |
| R-09h | 「每天 23:00，到 9/10 止」，任务时区 UTC+14 | 包含 9/10 那次 |
| R-09i | 导入非规范序的外部规则（如 `FREQ=MONTHLY;BYMONTHDAY=-1;UNTIL=…Z`） | 入库后满足 `encode(decode(s)) == s`（§2.3 的数据不变量）。这条**专门用来抓「某条写入路径漏了规范化」**，C1/C2/C3 都抓不到 |

### 6.2 月末与闰年（最容易错）

| # | 用例 | 期望 |
|---|---|---|
| R-10 | `FREQ=MONTHLY;BYMONTHDAY=31` 从 1/31 起 | **跳过** 2、4、6、9、11 月（这些月没有 31 号），不是「顺延到月末」 |
| R-11 | `FREQ=MONTHLY;BYMONTHDAY=-1` | 每月最后一天，2 月给出 28/29 |
| R-12 | `FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=29` | 只在闰年出现 |
| R-13 | `FREQ=MONTHLY;BYDAY=-1FR` 跨年 | 每月最后一个周五正确 |

> R-10 的行为**必须先用探针实测确认**再写死期望值，不能凭记忆断言 —— 见 §7。

### 6.3 例外与覆盖

| # | 用例 | 期望 |
|---|---|---|
| R-20 | skip 掉窗口内一次 | 该次不出现，其余不变 |
| R-21 | modify 改标题 | 只有该次标题变 |
| R-22 | **把窗口外的一次挪进窗口** | 该次出现（§3.1 的坑） |
| R-23 | **把窗口内的一次挪出窗口** | 该次消失，原位置不留残影 |
| R-24 | 对同一次先 modify 再 skip | 最终不出现 |
| R-25 | 完成某一次后，任务 `status` 仍为 `pending` | 其它次不受影响（data-model §4.3） |
| R-26 | 导入含 `EXDATE` 的 `.ics` | 每个 EXDATE 转成一条 `action=skip` 的 override；展开时该日不出现。**引擎不读 `recurrenceExDates` 列**（[data-model §4.5](data-model.md#45-recurrenceexdates-在-v1-不参与展开决定)） |
| R-27 | 全天重复任务已有 override，切换为定时任务 | 相关 override 的 `occurrenceKey` 在同一事务内从 `yyyy-MM-dd` 迁移为 `yyyy-MM-ddTHH:mm`，例外不失联（[data-model §4.6](data-model.md#46-occurrencekey-的格式区分全天与定时)） |
| R-28 | 全天重复任务的 override | `occurrenceKey` 为纯日期，无 `T00:00` 后缀 |

### 6.4 「本次及以后」分裂

| # | 用例 | 期望 |
|---|---|---|
| R-30 | 在第 5 次处分裂 | 前 4 次的完成记录保留；第 5 次起用新规则 |
| R-31 | 分裂点恰为第 1 次 | 原任务被整体替换，不留空规则任务 |
| R-32 | 分裂后再分裂 | `splitFromTaskId` 链正确 |

### 6.5 时区与夏令时

| # | 用例 | 期望 |
|---|---|---|
| R-40 | `Asia/Shanghai` 每天 09:00，设备切到 `Europe/London` | 仍显示 09:00（墙钟不变） |
| R-41 | `America/New_York` 每天 02:30，跨春季跳表日 | 该日顺延到 03:00 且打标记 |
| R-42 | `America/New_York` 每天 01:30，跨秋季回拨日 | 只出现一次，取较早的瞬时 |
| R-43 | 跨时区后重排通知 | 绝对触发时刻按新时区重算 |

### 6.6 阶段 × 重复

| # | 用例 | 期望 |
|---|---|---|
| R-50 | 3 阶段的每周任务，完成本周第 2 阶段 | 只有本周第 2 阶段变完成 |
| R-51 | 同上，下周同一阶段 | 仍为 pending |
| R-52 | 任务开始时间整体后移 2 小时 | 所有阶段跟随后移（相对偏移语义） |

## 7. 实现前必须做的探针（M1 第一件事）

**探针的定位（重要）**：期望值来自**规范**，探针只是**验证库是否符合规范**。
反过来「跑一遍看输出、把输出当期望」正是[测试策略 §1.1](../05-engineering/testing-strategy.md) 明令禁止的「对着实现抄」。
因此下表每一项都必须先填「规范依据」，再谈实测结果；两者不一致时，**以规范为准，在引擎内加显式修正层**。

| 探针 | 要确认什么 | 规范依据（期望的来源） | 实测结果 |
|---|---|---|---|
| P-1 | `FREQ=MONTHLY;BYMONTHDAY=31` 在无 31 号的月份 | RFC 5545 §3.3.10：`BYMONTHDAY` 指定的日期在该月不存在时，该次不产生（不顺延） | ✅ **符合**：2026 年得 `01-31, 03-31, 05-31, 07-31`，2/4/6 月缺席 |
| P-2 | `fromString()` / 编码 是否严格往返 | RFC 5545 §3.3.10：DTSTART 带 TZID 时 `UNTIL` MUST 为真 UTC（故必须带 `Z`） | ⚠️ **不符合（默认配置下）**：`toString()` 丢掉 `Z`，往返有损。加 `isTimeUtc: true` 后无损。**已在 §2.3 加强制封装** |
| P-3 | `UNTIL` 是闭区间还是开区间 | RFC 5545 §3.3.10 原文："bounds the recurrence rule in an **inclusive** manner" → **闭区间**，期望值现在即可写死 | ✅ **符合**：`UNTIL` 恰为某实例时刻时该实例被包含 |
| P-3b | `UNTIL` 是否按时区换算 | RFC 要求真 UTC；包本身无时区输入 | ✅ **已实测：朴素比较，不做换算** → 换算责任归 `core/time`（§2.2） |
| P-4 | `BYDAY=-1FR` 等负序号 | RFC 5545 §3.3.10 允许 `BYDAY` 带正负序号 | ⬜ M1 待测 |
| P-5 | 大范围展开（10 年 `FREQ=DAILY`）耗时与内存 | 无规范依据，属性能预算（NFR-PERF-04） | ⬜ M1 待测 |

> **规矩**：探针结论写进[环境探针结论](../05-engineering/environment-notes.md)并转化为测试用例后，才允许写引擎实现。
>
> P-2 是这条规矩价值的最好例证：初版只用一条**不含 `UNTIL`** 的规则测了往返，就写下了
> 「RRULE 字符串严格往返」的结论。补上带 `UNTIL` 的样本后，结论当场被推翻。
> **单样本不能支撑全称结论** —— 这条已写进测试策略。

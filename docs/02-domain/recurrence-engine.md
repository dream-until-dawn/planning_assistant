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
| 结束条件：到某日止 | 追加 `UNTIL=yyyyMMddTHHmmssZ` |

> **UI 只暴露上表**。用户不需要看见 RRULE 语法。
> 但存储层保留完整 RRULE 表达能力 —— 从导入的 `.ics` 来的复杂规则能被正确保存与展开，只是 UI 显示为「自定义规则」且编辑时提示会简化。

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

### 4.1 夏令时的两种坑

| 情形 | 现象 | 本项目的处理 |
|---|---|---|
| 春季跳表：02:00→03:00，02:30 不存在 | 「每天 02:30」这一天没有合法时刻 | 顺延到该时段结束后的第一个合法时刻（03:00），并在实例上打 `dstAdjusted` 标记供 UI 提示 |
| 秋季回拨：01:30 出现两次 | 一个墙钟对应两个瞬时 | 取**第一个**（较早的 UTC offset），与多数日历应用一致 |

> 中国大陆当前无夏令时，但用户可能出国，且 `timeZoneId` 可为任意 IANA 值。这两条必须有测试，不能因为「国内用不到」就不做 —— 那正是「永远绿的测试」的温床。

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
| R-05 | `FREQ=DAILY;UNTIL=20260910T000000Z` | 含 9/10 与否符合 RFC（闭区间） |

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

`rrule` 包的以下行为**必须实测确认**，不得凭文档或记忆断言：

| 探针 | 要确认什么 | 状态 |
|---|---|---|
| P-1 | `RRULE:FREQ=MONTHLY;BYMONTHDAY=31` 在无 31 号的月份是跳过还是顺延 | ✅ **已实测：跳过**（2026 年结果为 `01-31, 03-31, 05-31, 07-31`，2/4/6 月缺席）。R-10 的期望值据此写死 |
| P-2 | `toString()` 与 `fromString()` 是否严格往返 | ✅ **已实测：严格往返** |
| P-3 | `UNTIL` 是闭区间还是开区间 | ⬜ M1 待测 |
| P-4 | `BYDAY=-1FR` 等负序号支持情况 | ⬜ M1 待测 |
| P-5 | 大范围展开（10 年 `FREQ=DAILY`）的耗时与内存 | ⬜ M1 待测 |

> **规矩**：探针结论写进[环境探针结论](../05-engineering/environment-notes.md)并转化为测试用例后，才允许写引擎实现。
> 若某项行为与需求不符（例如 P-1 的语义我们想要「顺延」），则在引擎内做**显式修正层**，而不是改需求去迁就库。

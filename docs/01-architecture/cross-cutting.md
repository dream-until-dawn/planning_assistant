# 横切关注点

这些问题如果不在第一天统一，后面每个模块都会各写一套，最终无法同步、无法测试。

## 1. 时间与时区（最高优先级）

### 1.1 三种时间，绝不混用

| 类型 | 用途 | 存储形态 | Dart 表示 |
|---|---|---|---|
| `Instant` | 绝对时刻：创建时间、修改时间、通知实际触发时刻 | UTC 毫秒整数 | `DateTime`（`isUtc == true`） |
| `LocalWallTime` | 用户心智中的计划时间：「9 月 8 日 09:00」 | `planDate`(TEXT `yyyy-MM-dd`) + `minuteOfDay`(INT) + `timeZoneId`(TEXT) | 自定义值对象 |
| `PlanDate` | 纯日期（全天任务） | TEXT `yyyy-MM-dd` | 自定义值对象 |

**为什么计划时间不存 UTC 时间戳**：用户设了「每天 07:00 起床」，飞到伦敦后应该还是当地 07:00，而不是变成 00:00。
这是日历类应用的经典正确做法（iCalendar 的 `DTSTART;TZID=` 语义）。详见 [ADR-0005](../06-adr/ADR-0005-local-time-model.md)。

### 1.2 转换只允许经过一个地方

`core/time/` 暴露唯一的转换器：

```dart
abstract interface class Clock { DateTime nowUtc(); }          // 可注入，测试用固定时钟
abstract interface class TimeZoneResolver {                     // 可注入
  String currentZoneId();
  DateTime toInstant(LocalWallTime wall);                       // 墙钟 → 绝对时刻
  LocalWallTime toWallTime(DateTime instant, String zoneId);    // 绝对时刻 → 墙钟
}
```

**禁止**在业务代码里直接调用 `DateTime.now()`。守卫测试会扫描 `lib/domain` 与 `lib/features/*/application` 下的
`DateTime.now()` 调用并报错 —— 否则时间相关逻辑无法测试，这类测试就会变成「永远绿」的摆设。

### 1.3 必须专门测的边界

夏令时切换日（跳过的小时 / 重复的小时）、闰年 2/29、月末 29–31 日的「每月」重复、
跨年、时区变更后已排期提醒的重算。用例清单见 [重复引擎](../02-domain/recurrence-engine.md) §6。

## 2. 标识符

- 全部实体主键用 **UUID v7**（时间有序，索引友好，且天然避免云端合并时的主键冲突）。
- 由 `core/id/IdGenerator` 生成，接口化以便测试注入确定性序列。
- **禁止**用自增整数主键：云同步时必然冲突。

> ⚠️ 待验证项：`uuid: ^4.6.0` 的 v7 生成 API 名称与可用性需在 M0 用一行测试确认；
> 若不可用则在 `core/id/` 内自实现（v7 规范简单：48bit 毫秒 + 随机位）。此项列入 M0 检查表。

## 3. 错误处理

三类错误，处理方式不同：

| 类别 | 例子 | 处理 |
|---|---|---|
| **领域失败**（预期内） | 阶段时间早于任务开始、重复规则非法 | 返回 `Result.failure(DomainFailure)`，UI 显示可读文案。**不抛异常** |
| **基础设施失败** | DB 写入失败、文件不可写 | 抛 `InfraException`，在 Application 层捕获转 `Result` |
| **程序缺陷** | 空断言失败、状态机非法迁移 | 让它崩（debug）/ 记录并上报（release），**绝不静默吞掉** |

顶层由 `bootstrap.dart` 安装 `FlutterError.onError` 与 `PlatformDispatcher.instance.onError`，
统一落本地日志文件（NFR-REL-01）。

## 4. 日志

`core/logging/AppLogger` 门面，实现可替换。
- Debug：控制台 + 本地文件
- Release：仅本地滚动文件（上限 5MB，保留 3 份），**不外发**（NFR-PRIV-01）
- 日志中禁止出现任务标题等用户内容，只记 ID 与事件类型。

## 5. 国际化

- 全部文案走 `flutter_localizations` + `.arb`，首发 `zh-CN`，同时维护 `en` 作为「有没有硬编码文案」的探测器。
- 守卫：Widget 测试在 `en` locale 下跑一遍，出现中文即视为硬编码泄漏。
- 日期/数字格式一律走 `intl`，不手拼字符串。

## 6. 配置读取

配置是**全局横切**的：主题、视图偏好、提醒默认值都要被到处读。
统一走 `settingsProvider`（见 [配置中心规格](../03-design/settings-spec.md)），
读取时**永远有值**（读不到就返回声明的默认值），调用方不需要处理 null（FR-CFG-01/08）。

## 7. 并发与事务

- 所有多表写入必须在一个 Drift 事务内完成，**包括 outbox 写入**（FR-DATA-03 的一致性前提）。
- 长耗时计算（大范围重复展开、导入导出）走 `compute()` 隔离，避免掉帧（NFR-PERF-02）。
- 领域层保持纯同步纯函数，便于放进 isolate。

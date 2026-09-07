# 领域术语表（统一语言）

> 本表是**代码命名的唯一依据**。文档、类名、表名、变量名必须使用这里的英文术语，不得同义词混用
> （例：不得同时出现 `Repeat` 与 `Recurrence`，统一用 `Recurrence`）。

## 1. 核心实体

| 中文 | 英文 | 定义 | 反例（禁止使用） |
|---|---|---|---|
| 任务 | `Task` | 计划的聚合根。用户心智中「一件要做的事」 | ~~Todo~~、~~Item~~、~~Plan~~ |
| 任务形态 | `TaskKind` | `single`（单项）\| `staged`（阶段事项） | ~~TaskType~~ |
| 阶段 | `Stage` | 阶段事项内部有序的子区段，有独立时间与状态 | ~~Phase~~、~~Step~~、~~SubTask~~ |
| 清单项 | `ChecklistItem` | 任务详情内的轻量勾选项，**不参与时间排布** | ~~SubTask~~ |
| 重复规则 | `Recurrence` | 描述「什么时候重复发生」的规则，RFC 5545 语义 | ~~Repeat~~、~~Schedule~~ |
| 发生实例 | `Occurrence` | 重复规则在某一具体时刻的一次发生 | ~~Instance~~、~~Event~~ |
| 例外 | `OccurrenceOverride` | 对某一次 `Occurrence` 的单独修改或跳过 | ~~Exception~~（与语言关键词冲突） |
| 分类 | `Category` | 用户自定义分组，带颜色与图标，单选 | ~~Group~~、~~Folder~~ |
| 标签 | `Tag` | 用户自定义标记，多选 | ~~Label~~ |
| 提醒 | `Reminder` | 任务上的一条提醒设置（相对或绝对） | ~~Notification~~（那是系统层的产物） |
| 通知 | `Notification` | 由 `Reminder` 实际投递到系统通知栏的那条消息 | — |

## 2. 时间相关（最容易出错，务必区分）

| 中文 | 英文 | 定义 |
|---|---|---|
| 瞬时 | `Instant` | 绝对时间点，UTC 毫秒时间戳。用于 `createdAt`、实际触发时刻 |
| 本地墙钟 | `LocalWallTime` | 「9 月 8 日 09:00」这种不带时区的日历时间。用户心智中的计划时间 |
| 时区 | `TimeZoneId` | IANA 时区标识（如 `Asia/Shanghai`） |
| 计划日 | `PlanDate` | `yyyy-MM-dd` 的纯日期，无时间部分 |
| 分钟偏移 | `MinuteOfDay` | 从当日 00:00 起的分钟数（0..1439） |
| 时间窗 | `TimeSpanSpec` | 计划的起止，可能只有开始、只有日期、或完整起止 |

> **铁律**：计划时间用 `LocalWallTime + TimeZoneId` 存储，**不存 UTC 时间戳**。
> 理由与后果见 [ADR-0005](../06-adr/ADR-0005-local-time-model.md)。

## 3. 视图与交互

| 中文 | 英文 | 定义 |
|---|---|---|
| 时间轴视图 | `TimelineView` | 单日纵向时刻表 |
| 列表视图 | `ListView` → 代码用 `TaskListView` | 分组列表（避让 Flutter 的 `ListView`） |
| 日历视图 | `CalendarView` | 月/周格子 |
| 竖向甘特视图 | `GanttView` | 纵轴时间、横轴泳道的跨天进度图 |
| 泳道 | `Lane` | 甘特图中的一列，可按分类或任务划分 |
| 今日概览 | `TodayDigest` | 不依赖 UI 的「今天有什么」查询结果，供小组件/通知复用 |

## 4. 架构与数据

| 中文 | 英文 | 定义 |
|---|---|---|
| 用例 | `UseCase` | 应用层的一个业务动作，如 `CompleteOccurrence` |
| 命令 | `TaskCommand` | 可序列化的写操作意图。**所有写入的唯一入口** |
| 仓储 | `Repository` | 领域层定义的持久化接口，数据层实现 |
| 同步信封 | `SyncEnvelope` | 每条可同步记录都携带的元数据字段组 |
| 变更日志 | `ChangeLogEntry` / outbox | 一条已提交写操作的记录，供回放与将来推送云端 |
| 墓碑 | `Tombstone` | 软删除记录（`deletedAt` 非空），同步必需，不可物理删除 |
| 配置项 | `SettingSpec` | 一个配置项的声明（键、类型、默认值、是否暴露给用户） |

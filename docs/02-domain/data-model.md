# 数据模型

> 本文是 schema 的唯一真相来源。**改 Drift 表必须在同一个 PR 改本文**（见 [工程规范](../05-engineering/conventions.md) §5）。
> 术语一律使用[术语表](../00-product/glossary.md)。

## 1. 设计原则

1. **重复任务不预存实例**。DB 里只存规则与例外，实例按需展开（[ADR-0004](../06-adr/ADR-0004-rfc5545-recurrence.md)）。否则「永不结束的每日任务」需要无限行。
2. **计划时间存墙钟，不存 UTC**（[ADR-0005](../06-adr/ADR-0005-local-time-model.md)）。
3. **每张可同步表都带同步信封**，从第一天起就带（[ADR-0006](../06-adr/ADR-0006-sync-ready-record-envelope.md)）。后补代价远大于现在带上。
4. **软删除**：可同步实体一律 `deletedAt` 打墓碑，物理删除只发生在「清空回收站」且已同步之后。
5. **行 ⇄ JSON 一一对应**：每张表的列集合 = 导出 JSON 对象的字段集合，服务端无需客户端逻辑即可解析（FR-DATA-04）。

## 2. 实体关系

```
                    ┌───────────┐
                    │ Category  │◄──────┐
                    └───────────┘       │ categoryId (nullable)
                                        │
┌────────┐  taskTags   ┌──────────────────────────┐
│  Tag   │◄───────────►│          Task            │  聚合根
└────────┘             │  kind: single | staged   │
                       │  recurrenceRule: RRULE?  │
                       └───┬───────┬───────┬──────┘
                           │       │       │
          ┌────────────────┘       │       └──────────────┐
          │                        │                      │
    ┌─────▼─────┐         ┌────────▼────────┐    ┌────────▼────────┐
    │   Stage   │         │ ChecklistItem   │    │    Reminder     │
    │ 有序·相对  │         │ 轻量勾选         │    │ 相对/绝对        │
    └─────┬─────┘         └─────────────────┘    └────────┬────────┘
          │                                               │
          │  ┌──────────────────────┐                     │
          └─►│ StageOccurrenceState │                     │
             │ 每个发生实例的阶段状态  │                     │
             └──────────────────────┘                     │
                                                          │
             ┌──────────────────────┐          ┌──────────▼───────────┐
             │ OccurrenceOverride   │          │ ScheduledNotification│
             │ 单次跳过/修改/完成     │          │ 仅本地，不同步         │
             └──────────────────────┘          └──────────────────────┘
```

## 3. 表定义

### 3.1 `tasks`

| 列 | 类型 | 约束 | 说明 |
|---|---|---|---|
| `id` | TEXT | PK | UUID v7 |
| `title` | TEXT | NOT NULL | |
| `note` | TEXT | NULL | Markdown 子集 |
| `kind` | TEXT | NOT NULL | `single` \| `staged` |
| `categoryId` | TEXT | NULL, FK→categories.id ON DELETE SET NULL | 删分类不删任务（FR-CFG-03） |
| `priority` | INT | NOT NULL DEFAULT 2 | 0 无 / 1 低 / 2 普通 / 3 高 / 4 紧急 |
| `status` | TEXT | NOT NULL DEFAULT 'pending' | 非重复任务的状态；重复任务此列恒为 `pending`，真实状态在 override |
| `isAllDay` | BOOL | NOT NULL DEFAULT 0 | |
| `planDate` | TEXT | NULL | `yyyy-MM-dd`。重复任务即 DTSTART 的日期 |
| `startMinute` | INT | NULL | 0..1439，`isAllDay=1` 时为 NULL |
| `endDate` | TEXT | NULL | 跨天任务的结束日 |
| `endMinute` | INT | NULL | |
| `timeZoneId` | TEXT | NOT NULL | IANA，创建时的时区 |
| `recurrenceRule` | TEXT | NULL | RFC 5545 `RRULE:` 串。NULL = 不重复 |
| `recurrenceExDates` | TEXT | NULL | JSON 数组，被排除的 occurrenceKey（保留用于导入 `.ics`） |
| `splitFromTaskId` | TEXT | NULL | 「本次及以后」分裂的溯源，见 §4.4 |
| `colorArgb` | INT | NULL | 任务级颜色覆盖；NULL 则用分类色 |
| `icon` | TEXT | NULL | |
| `sortOrder` | REAL | NOT NULL DEFAULT 0 | 手动排序（浮点便于插入中间） |
| `completedAt` | INT | NULL | Instant ms |
| `archivedAt` | INT | NULL | |
| **同步信封** | | | 见 §5 |

**索引**：`(deletedAt, planDate)`、`(categoryId)`、`(recurrenceRule)` 部分索引（`WHERE recurrenceRule IS NOT NULL`）、`(status, deletedAt)`

### 3.2 `stages`

阶段时间用**相对偏移**表达，理由见 §4.1。

| 列 | 类型 | 约束 | 说明 |
|---|---|---|---|
| `id` | TEXT | PK | |
| `taskId` | TEXT | NOT NULL, FK→tasks.id ON DELETE CASCADE | |
| `title` | TEXT | NOT NULL | |
| `orderIndex` | INT | NOT NULL | 从 0 起连续 |
| `startOffsetMinutes` | INT | NULL | 相对任务（或该次发生）开始的分钟偏移 |
| `durationMinutes` | INT | NULL | |
| `colorArgb` | INT | NULL | 甘特图分段色 |
| `status` | TEXT | NOT NULL DEFAULT 'pending' | 仅非重复任务使用 |
| `completedAt` | INT | NULL | |
| **同步信封** | | | |

**索引**：`(taskId, orderIndex)`

### 3.3 `checklist_items`

| 列 | 类型 | 说明 |
|---|---|---|
| `id` | TEXT PK | |
| `taskId` | TEXT NOT NULL FK CASCADE | |
| `title` | TEXT NOT NULL | |
| `isDone` | BOOL NOT NULL DEFAULT 0 | |
| `orderIndex` | INT NOT NULL | |
| **同步信封** | | |

### 3.4 `occurrence_overrides`

对某一次发生的单独处理，相当于 iCalendar 的 `RECURRENCE-ID` + 修改。

| 列 | 类型 | 说明 |
|---|---|---|
| `id` | TEXT PK | |
| `taskId` | TEXT NOT NULL FK CASCADE | |
| `occurrenceKey` | TEXT NOT NULL | **原始**发生时刻的墙钟串 `yyyy-MM-ddTHH:mm`（未被修改前的），唯一标识是哪一次 |
| `action` | TEXT NOT NULL | `skip` \| `modify` |
| `status` | TEXT NULL | 该次的状态 |
| `completedAt` | INT NULL | |
| `titleOverride` | TEXT NULL | NULL = 继承任务 |
| `noteOverride` | TEXT NULL | |
| `planDateOverride` | TEXT NULL | 把这一次挪到别的日期 |
| `startMinuteOverride` | INT NULL | |
| `endDateOverride` | TEXT NULL | |
| `endMinuteOverride` | INT NULL | |
| **同步信封** | | |

**唯一索引**：`(taskId, occurrenceKey)` —— 一次发生最多一条例外。

### 3.5 `stage_occurrence_states`

重复的阶段事项，每次发生的每个阶段有独立状态（FR-TASK-07）。

| 列 | 类型 | 说明 |
|---|---|---|
| `id` | TEXT PK | |
| `taskId` | TEXT NOT NULL FK CASCADE | |
| `stageId` | TEXT NOT NULL FK CASCADE | |
| `occurrenceKey` | TEXT NOT NULL | |
| `status` | TEXT NOT NULL | |
| `completedAt` | INT NULL | |
| **同步信封** | | |

**唯一索引**：`(stageId, occurrenceKey)`

> 只有被交互过的 (阶段, 发生) 才落行 —— 未触碰的阶段视为 `pending`，不占存储。

### 3.6 `categories`

| 列 | 类型 | 说明 |
|---|---|---|
| `id` | TEXT PK | |
| `name` | TEXT NOT NULL | |
| `colorArgb` | INT NOT NULL | |
| `icon` | TEXT NOT NULL | 图标标识串（不存二进制） |
| `orderIndex` | INT NOT NULL | |
| `isSystemDefault` | BOOL NOT NULL DEFAULT 0 | 「未分类」这条不可删 |
| **同步信封** | | |

首次启动写入的默认分类见[配置中心规格](../03-design/settings-spec.md) §4。

### 3.7 `tags` / `task_tags`

- `tags`：`id`、`name`、`colorArgb` + 同步信封。
- `task_tags`：`taskId`、`tagId` + 同步信封，PK `(taskId, tagId)`。

> 联结表也带同步信封 —— 否则云端无法表达「解除了一个标签关联」。

### 3.8 `reminders`

| 列 | 类型 | 说明 |
|---|---|---|
| `id` | TEXT PK | |
| `taskId` | TEXT NOT NULL FK CASCADE | |
| `kind` | TEXT NOT NULL | `relativeToStart` \| `relativeToEnd` \| `absolute` |
| `offsetMinutes` | INT NULL | 负数 = 提前；`kind` 为相对时必填 |
| `absoluteDate` | TEXT NULL | `kind=absolute` 时的墙钟日期 |
| `absoluteMinute` | INT NULL | |
| `isEnabled` | BOOL NOT NULL DEFAULT 1 | |
| **同步信封** | | |

### 3.9 `scheduled_notifications`（**本地表，不同步、不导出**）

排期簿记，见[通知设计](../04-platform/notifications.md)。

| 列 | 类型 | 说明 |
|---|---|---|
| `osNotificationId` | INT PK | 传给系统的 ID |
| `reminderId` | TEXT NOT NULL | 溯源 |
| `taskId` | TEXT NOT NULL | |
| `occurrenceKey` | TEXT NOT NULL | |
| `fireAtInstant` | INT NOT NULL | UTC ms |
| `state` | TEXT NOT NULL | `scheduled` \| `fired` \| `cancelled` |

### 3.10 `settings`

| 列 | 类型 | 说明 |
|---|---|---|
| `key` | TEXT PK | 见[配置注册表](../03-design/settings-spec.md) |
| `valueJson` | TEXT NOT NULL | 统一 JSON 编码，类型由注册表声明 |
| `scope` | TEXT NOT NULL | `global`（参与同步）\| `device`（不同步） |
| **同步信封** | | |

### 3.11 `change_log`（outbox）

| 列 | 类型 | 说明 |
|---|---|---|
| `seq` | INTEGER PK AUTOINCREMENT | 本地单调序号 |
| `entityType` | TEXT NOT NULL | `task` / `stage` / … |
| `entityId` | TEXT NOT NULL | |
| `op` | TEXT NOT NULL | `upsert` \| `delete` |
| `payloadJson` | TEXT NULL | upsert 时为该行的完整 JSON |
| `occurredAt` | INT NOT NULL | Instant ms |
| `deviceId` | TEXT NOT NULL | |
| `syncedAt` | INT NULL | V3 用；V1 恒为 NULL |

**索引**：`(syncedAt)`（找待推送）、`(entityType, entityId)`

> V1 就写这张表。它在 V1 内部也有价值：**回放一致性测试**（清库后按 seq 回放应还原等价状态）是发现「写操作绕过命令管道」的最有效手段。

## 4. 关键建模决策

### 4.1 为什么阶段用相对偏移而不是绝对日期

| 方案 | 优点 | 致命问题 |
|---|---|---|
| 绝对日期 | 直观 | **重复的阶段事项无法表达** —— 每周发生一次，阶段日期该写哪一周的？ |
| **相对偏移**（采纳） | 重复与非重复统一；整体挪任务时阶段自动跟随 | 用户改任务结束日时阶段不自动缩放 |

UI 层始终展示绝对日期，编辑时换算回偏移。「不自动缩放」是刻意的：静默改变用户排好的阶段时长比不改更糟。需要整体缩放时提供显式的「等比调整阶段」操作。

### 4.2 `occurrenceKey` 为什么用「原始发生时刻」

如果一次发生被挪到别的日期，它的 key **仍是原始时刻**。否则「把 9/8 那次挪到 9/10」之后，规则再次展开时会在 9/8 又生成一个未被覆盖的实例 —— 出现重影。

这与 iCalendar `RECURRENCE-ID` 语义一致，也保证将来导入导出 `.ics` 时不失真。

### 4.3 为什么重复任务的 `tasks.status` 恒为 `pending`

重复任务本身没有「完成」这个状态，只有某一次发生被完成。把状态写在任务行上会导致「完成了今天的，明天的也显示已完成」。

状态一律落在 `occurrence_overrides.status`。**这条是硬约束，由领域层不变量检查强制**，并有专门的回归测试。

### 4.4 「本次及以后」修改怎么实现（FR-TASK-06）

不改历史，而是**分裂**：

1. 原任务的 RRULE 追加 `UNTIL=<分割点前一刻>`；
2. 新建任务，`recurrenceRule` 为新规则，`planDate` 为分割点；
3. 新任务记 `splitFromTaskId`，用于将来「合并回去」与同步溯源。

好处：历史发生的完成记录原样保留，且云端合并时不需要理解「部分修改」这种复杂语义。

## 5. 同步信封（每张可同步表都有）

| 列 | 类型 | 语义 |
|---|---|---|
| `createdAt` | INT NOT NULL | Instant ms |
| `updatedAt` | INT NOT NULL | Instant ms，每次本地写入更新 |
| `deletedAt` | INT NULL | 非空即墓碑 |
| `revision` | INT NOT NULL DEFAULT 1 | 每次本地写入 +1 |
| `lastWriterId` | TEXT NOT NULL | 写入方设备 ID |
| `remoteVersion` | TEXT NULL | 服务端返回的版本标记（V1 恒 NULL） |

**规则**：

- 所有查询默认带 `WHERE deletedAt IS NULL`，由 DAO 基类统一加，避免遗漏。
- `revision` + `updatedAt` + `lastWriterId` 足以支撑 V3 的 LWW（最后写入者胜）与冲突检测，详见[云同步预研](../04-platform/future-sync.md)。
- **不参与同步的表**：`scheduled_notifications`、`change_log` 自身、`settings` 中 `scope='device'` 的行。

## 6. 导出格式（FR-DATA-04）

```jsonc
{
  "formatVersion": 1,              // 导出格式版本，与 DB schemaVersion 解耦
  "schemaVersion": 1,              // 导出时的 DB schema 版本
  "appVersion": "1.0.0",
  "exportedAt": 1757203200000,     // Instant ms
  "deviceId": "…",
  "counts": { "tasks": 128, "stages": 40 },   // 校验用
  "data": {
    "categories": [],
    "tags": [],
    "taskTags": [],
    "tasks": [],
    "stages": [],
    "checklistItems": [],
    "occurrenceOverrides": [],
    "stageOccurrenceStates": [],
    "reminders": [],
    "settings": []                 // 仅 scope=global
  }
}
```

- 字段名 = 列名（lowerCamelCase），逐字段对应，无嵌套加工。
- 墓碑行**照常导出**（否则导入方无法知道某条被删了）。
- 导出/导入必须通过**往返测试**：导出 → 清库 → 导入 → 逐表逐字段比对（FR-CFG-06）。
- 同时在 `docs/schema/export-v1.schema.json` 维护 JSON Schema，服务端（V3）以此为契约。

## 7. 迁移策略

- Drift `schemaVersion` 从 1 起，**只增不改**。
- 每次升版：写迁移步骤 + 用 `drift_dev schema dump` 固化旧版 schema 快照 + 写迁移测试（FR-DATA-05）。
- 迁移前自动把 DB 文件复制一份到 `backup/pre-migration-v{n}.db`（NFR-REL-02）。
- **禁止**破坏性迁移（删列 / 改列语义）；需要变更时新增列 + 数据回填 + 旧列停用。

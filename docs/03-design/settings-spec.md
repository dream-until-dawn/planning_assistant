# 配置中心规格

> 对应 FR-CFG-01..08、NFR-MAINT-04。
> 核心要求：**能自定义的都留出口，全部有默认值，不开放给用户的也能靠默认值正常工作。**

## 1. 设计：配置注册表

每个配置项是一条**声明**，而不是散落在代码里的常量：

```dart
class SettingSpec<T> {
  final String key;              // 'theme.primaryColor'，点分命名空间
  final T defaultValue;          // 必填，永远有值
  final SettingScope scope;      // global(参与同步) | device(不同步)
  final SettingExposure exposure;// exposed(设置页可见) | hidden(仅配置文件可改)
  final String? group;           // 设置页分组
  final SettingEditor editor;    // 渲染成什么控件：switch/select/slider/color/...
  final T Function(Object json) decode;
  final Object Function(T value) encode;
  final String? Function(T value)? validate;  // 返回错误文案或 null
}
```

全部声明集中在 `lib/features/settings/registry.dart`。

**由此得到的性质**：

| 性质 | 怎么来的 |
|---|---|
| FR-CFG-01 永远有默认值 | `defaultValue` 必填；读取接口返回 `T` 而非 `T?` |
| FR-CFG-07 新增配置只改一处 | 设置页遍历注册表自动渲染，不写死 UI |
| FR-CFG-08 隐藏项也能用 | `exposure: hidden` 的项不进设置页，但参与读取、导出与导入 |
| 可测试 | 注册表是纯数据，可断言「每项都有默认值」「key 无重复」「默认值通过自身校验」 |

### 1.1 读取接口

```dart
T setting<T>(SettingSpec<T> spec);        // 同步读，永远有值
Stream<T> watchSetting<T>(SettingSpec<T> spec);
```

调用方**不需要处理 null**，也不需要知道值从哪来（DB 有值用 DB 的，没有用默认值）。

### 1.2 注册表自检（测试）

| 断言 |
|---|
| key 全局唯一 |
| 每个 `defaultValue` 都能通过自身的 `validate` |
| 每个 `defaultValue` 都能 `encode` 后 `decode` 回等值（往返） |
| `exposed` 的项都有 `group` 与本地化文案 key |
| 每个 `group` 至少有一个 `exposed` 项（否则设置页出现空分组） |

---

## 2. 配置项全表

图例：**暴露**列 `✅` = V1 设置页可见；`🔒` = 隐藏项（用默认值，可经导入的配置文件覆盖）。

### 2.1 外观 `theme.*`

| key | 类型 | 默认值 | 暴露 | 说明 |
|---|---|---|---|---|
| `theme.mode` | enum | `system` | ✅ | 跟随系统 / 亮 / 暗 |
| `theme.primaryColor` | color | `#7FD1C1` | ✅ | 主色，选择后自动校验对比度 |
| `theme.cornerStyle` | enum | `standard` | ✅ | soft / standard / sharp |
| `theme.fontScale` | double | `1.0` | ✅ | 0.85–1.4，与系统缩放**相乘**。最坏有效缩放 1.4×2.0=**2.8**，golden 必须覆盖，见[设计系统 §3.1](design-system.md#31-缩放是两层相乘golden-必须覆盖到实际最坏值) |
| `theme.reduceMotion` | bool | `false` | ✅ | 同时响应系统设置，取「或」 |
| `theme.showCompletedStrikethrough` | bool | `true` | ✅ | 已完成任务是否加删除线 |
| `theme.cardDensity` | enum | `comfortable` | ✅ | compact / comfortable |
| `theme.secondaryColor` | color | `#FFB7C5` | 🔒 | 次色 |
| `theme.tertiaryColor` | color | `#FFD79A` | 🔒 | 点缀色 |
| `theme.shadowIntensity` | double | `1.0` | 🔒 | 阴影强度倍率 0–1.5 |
| `theme.enableCompletionParticles` | bool | `true` | 🔒 | 完成时的粒子效果 |

### 2.2 视图 `view.*`

| key | 类型 | 默认值 | 暴露 | 说明 |
|---|---|---|---|---|
| `view.defaultView` | enum | `list` | ✅ | list / timeline / calendar / gantt |
| `view.firstDayOfWeek` | enum | `monday` | ✅ | |
| `view.showCompleted` | bool | `true` | ✅ | |
| `view.timelineTickMinutes` | int | `60` | ✅ | 15 / 30 / 60 |
| `view.listGroupBy` | enum | `date` | ✅ | date / category / priority / status |
| `view.listSortBy` | enum | `time` | ✅ | time / priority / created / manual |
| `view.calendarMode` | enum | `month` | ✅ | month / week |
| `view.ganttLaneBy` | enum | `category` | ✅ | category / task / tag |
| `view.ganttGranularity` | enum | `day` | ✅ | day / week / month |
| `view.timelineStartHour` | int | `6` | 🔒 | 时间轴默认可视起点 |
| `view.timelineEndHour` | int | `23` | 🔒 | |
| `view.calendarMaxDotsPerCell` | int | `3` | 🔒 | |
| `view.ganttMaxColumnsPerLane` | int | `3` | 🔒 | 超出折叠 |
| `view.collapseOverdueGroup` | bool | `true` | 🔒 | 逾期分组默认折叠 |
| `view.minTimeBlockHeight` | double | `36` | 🔒 | dp |

### 2.3 提醒 `reminder.*`

| key | 类型 | 默认值 | 暴露 | 说明 |
|---|---|---|---|---|
| `reminder.enabled` | bool | `true` | ✅ | 总开关 |
| `reminder.defaultOffsetMinutes` | int | `-15` | ✅ | 新任务默认提前量 |
| `reminder.quietHoursEnabled` | bool | `false` | ✅ | 免打扰 |
| `reminder.quietHoursStart` | int | `1320` (22:00) | ✅ | MinuteOfDay |
| `reminder.quietHoursEnd` | int | `420` (07:00) | ✅ | |
| `reminder.quietHoursBehavior` | enum | `postpone` | ✅ | postpone(顺延到结束) / suppress(丢弃) |
| `reminder.allDayReminderMinute` | int | `540` (09:00) | ✅ | 全天任务几点提醒 |
| `reminder.mergeThreshold` | int | `3` | 🔒 | 同一时段超过 N 条则合并为一条摘要 |
| `reminder.scheduleWindowDays` | int | `14` | 🔒 | 滚动排期窗口，见[通知设计](../04-platform/notifications.md) |
| `reminder.maxScheduled` | int | `400` | 🔒 | 系统待触发上限保护 |
| `reminder.vibrate` | bool | `true` | 🔒 | |
| `reminder.sound` | string | `default` | 🔒 | |

### 2.4 行为 `behavior.*`

| key | 类型 | 默认值 | 暴露 | 说明 |
|---|---|---|---|---|
| `behavior.defaultDurationMinutes` | int | `60` | ✅ | 新任务默认时长 |
| `behavior.defaultCategoryId` | string | `uncategorized` | ✅ | |
| `behavior.defaultPriority` | int | `2` | ✅ | 普通 |
| `behavior.swipeRight` | enum | `complete` | ✅ | complete / postpone / delete / none |
| `behavior.swipeLeft` | enum | `postpone` | ✅ | 同上 |
| `behavior.postponeMinutes` | int | `1440` | ✅ | 「推迟」推多久，默认 1 天 |
| `behavior.confirmOnDelete` | bool | `true` | ✅ | |
| `behavior.undoDurationSeconds` | int | `5` | 🔒 | 撤销 Snackbar 停留时长 |
| `behavior.quickAddSnapMinutes` | int | `15` | 🔒 | 长按新增时的时间吸附粒度 |
| `behavior.autoStartOnFirstStage` | bool | `true` | 🔒 | 阶段**部分完成**时父任务是否自动转 `inProgress`。关闭时保持 `pending`，其余状态推导不受影响 —— 精确语义见[任务生命周期 §4.1](../02-domain/task-lifecycle.md#41-配置项-behaviorautostartonfirststage-的作用范围此处消除了与配置规格的冲突) |

### 2.5 数据 `data.*`

| key | 类型 | 默认值 | 暴露 | 说明 |
|---|---|---|---|---|
| `data.autoBackupEnabled` | bool | `true` | ✅ | |
| `data.autoBackupIntervalDays` | int | `7` | ✅ | |
| `data.trashRetentionDays` | int | `30` | ✅ | 回收站保留期 |
| `data.autoBackupKeepCount` | int | `5` | 🔒 | 保留几份备份 |
| `data.exportIncludeTombstones` | bool | `true` | 🔒 | 导出是否含墓碑（同步需要） |
| `data.deviceId` | string | 首启生成 | 🔒 | scope=**device**，不同步 |

### 2.6 实验性 `lab.*`（V1 全部关闭且隐藏，为后续期次预留）

| key | 类型 | 默认值 | 暴露 | 期次 |
|---|---|---|---|---|
| `lab.homeWidgetEnabled` | bool | `false` | 🔒 | V2 |
| `lab.persistentNotification` | bool | `false` | 🔒 | V2 |
| `lab.cloudSyncEnabled` | bool | `false` | 🔒 | V3 |
| `lab.cloudEndpoint` | string | `''` | 🔒 | V3 |
| `lab.emailReminderEnabled` | bool | `false` | 🔒 | V3 |
| `lab.voiceInputEnabled` | bool | `false` | 🔒 | V4 |
| `lab.agentEnabled` | bool | `false` | 🔒 | V4 |

> 这些项 V1 就在注册表里声明。好处：数据结构与导出格式**从 V1 起就是最终形态**，
> V2/V3 不需要为了加配置而改导出格式版本。

### 2.7 设备级 `device.*`（scope=device，不同步）

| key | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `device.notificationPermissionAsked` | bool | `false` | 是否已请求过通知权限 |
| `device.exactAlarmAvailable` | bool | `false` | 精确闹钟是否可用（每次启动刷新） |
| `device.lastKnownTimeZone` | string | 系统值 | 用于检测时区变更并重排提醒 |
| `device.lastBackupAt` | int | `0` | |

---

## 3. 分类管理（FR-CFG-03）

分类是**实体不是配置项**（存 `categories` 表），但管理入口在设置页。

| 操作 | 规则 |
|---|---|
| 新增 | 颜色从[默认调色板](design-system.md#25-分类默认调色板)按序取，可改 |
| 编辑 | 名称、颜色、图标 |
| 排序 | 拖拽，改 `orderIndex` |
| 删除 | 其下任务 `categoryId` 置 NULL（迁到「未分类」），**不级联删任务** |
| 设为默认 | 写入 `behavior.defaultCategoryId` |

**「未分类」不可删**（`isSystemDefault = 1`），删除按钮对它禁用。

### 3.1 首次启动的默认分类

| 名称 | 颜色 | 图标 |
|---|---|---|
| 未分类 | `#A9A5B0` | `inbox` |
| 工作 | `#7FD1C1` | `briefcase` |
| 学习 | `#A8C8F0` | `book` |
| 生活 | `#FFB7C5` | `home` |
| 健康 | `#A8D8B9` | `heart` |

用户可全部删除（除「未分类」）或改名，不做保护。

---

## 4. 设置页信息架构

```
设置
├─ 外观            theme.*  的 exposed 项
├─ 视图偏好        view.*
├─ 提醒            reminder.*  + 权限状态卡片
├─ 分类管理        → 二级页
├─ 行为            behavior.*
├─ 数据            data.* + 导出 / 导入 / 立即备份 / 回收站
└─ 关于            版本、开源许可、隐私说明（明确写「本应用不联网」）
```

分组与顺序由 `SettingSpec.group` 与注册表中的声明顺序决定 —— 加一项配置不用改这个页面。

## 5. 导入导出配置

- 配置随[数据导出](../02-domain/data-model.md#6-导出格式fr-data-04)一并输出（仅 `scope=global`）。
- 导入时：
  - 认识的 key → 校验后写入，校验失败则**保留原值并记录警告**，不中断导入；
  - 不认识的 key → **原样保留在库中**（前向兼容：新版本导出的文件在旧版本导入后，升级回新版本数据仍在）；
  - `scope=device` 的项**永不导入**。
- 隐藏项（`exposure: hidden`）可以通过这条路径被修改 —— 这就是 FR-CFG-08 说的「不开放给用户配置也能用」的完整含义：普通用户用默认值，高级用户可以改配置文件。

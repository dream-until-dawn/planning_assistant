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

全部声明集中在 `lib/features/settings/application/registry.dart`。

> 规格初版写的是 `features/settings/registry.dart`（直接放在 feature 根下）。
> 分层守卫判它「未分类到任何一层」—— 判得对：`lib/` 下不在层目录里的文件，
> 守卫对它的一切约束都静默失效。挪进 `application/`：
> 它是**声明数据**，不是界面也不是领域不变量。

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
| `theme.fontScale` | double | `1.0` | ✅ | 0.85–1.4，与系统缩放**相乘**。最坏有效缩放 1.4×2.0=**2.8**，golden 必须覆盖，见[设计系统 §3.4](design-system.md#34-缩放是两层相乘golden-必须覆盖到实际最坏值) |
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
| `view.firstDayOfWeek` | enum | `monday` | ✅ | 周一 / 周日 / 周六（其余四个没有地区用作周起始日） |
| `view.showCompleted` | bool | `true` | ✅ | |
| ~~`view.timelineTickMinutes`~~ | — | — | ❌ | **已删**，见 §2.4b |
| `view.listGroupBy` | enum | `date` | ✅ | date / category / priority / status |
| `view.listSortBy` | enum | `time` | ✅ | time / priority / created / manual |
| ~~`view.calendarMode`~~ | — | — | ❌ | **不做**，见 §2.4a |
| `view.ganttLaneBy` | enum | `category` | ✅ | category / task / tag |
| `view.ganttGranularity` | enum | `day` | ✅ | day / week / month |
| `view.calendarMaxDotsPerCell` | int | `3` | 🔒 | |
| `view.ganttMaxColumnsPerLane` | int | `3` | 🔒 | 超出折叠 |
| `view.collapseOverdueGroup` | bool | `true` | 🔒 | 逾期分组默认折叠 |

### 2.4b 时间轴那三条随刻度尺一起删了

`view.timelineTickMinutes`（15/30/60）、`view.timelineStartHour` /
`view.timelineEndHour`、`view.minTimeBlockHeight` 配的都是**连续刻度尺**：
一格多高、从几点画到几点、最短的块不低于多少。

时间轴按用户要求改成跳跃排布（[视图规格 §1](view-specs.md#1-时间轴视图-timelineviewfr-view-01)）
之后，那把尺子没有了 —— 没有「一格」，没有「可视起点」，
块高由卡片内容决定。留着的话，设置页上会有一个**选了没反应的下拉**，
而那比没有这个选项更糟（同 §2.4a 与「默认视图」那条的判断）。

已存的配置值不需要迁移：认不出的 key 读出来没人要，下次写回时自然消失。

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

### 2.4a `view.calendarMode` 不做 —— 它与共享状态抢同一件事

原表里有一条 `view.calendarMode`（month / week）。做日历时发现它与
[视图规格 §0.1](view-specs.md#01-共享状态) 的 `granularity`（日/周/月，
**甘特与日历共用**）说的是同一件事。

两者都存在的话，「现在是月还是周」就有了两个来源：从甘特切到日历时读哪一个？
用户在日历上切到周视图，甘特那边的粒度跟不跟着变？——这两个问题没有好答案，
而 FR-VIEW-05/06 要求的恰恰是「切视图时状态保持」。

**保留共享状态那一份，配置项不做。** 「重启后回到上次的月/周」是另一回事
（那是持久化，不是第二个真值来源），要做的话是一条隐藏项，等有人真的提再说。

### 2.4 行为 `behavior.*`

| key | 类型 | 默认值 | 暴露 | 说明 |
|---|---|---|---|---|
| `behavior.defaultDurationMinutes` | int | `60` | ✅ | 新任务默认时长 |
| `behavior.defaultCategoryId` | string | `uncategorized` | 🔒* | *不在设置页里，入口是[分类管理](#3-分类管理fr-cfg-03)每一行上的星标 —— 它的选项是用户自己的分类（运行时数据），而注册表里的 `select` 只能列静态选项。值为 `uncategorized` 时表示未分类；**这只是这一项配置的取值，不是第三种「未分类」的编码**（§3.0 仍然只认 `categoryId IS NULL`）。读出来时若指向一个已被删除的分类，回落成未分类 |
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
| 设为默认 | 写入 `behavior.defaultCategoryId`。再点一次取消（回到未分类）——设错了没有回头路是最容易让人恼火的一类交互。删掉正好是默认的那个分类时，配置一并收回未分类 |

### 3.0 ⚠️「未分类」是 **NULL**，不是一行

初版这里有个歧义：§3.1 把「未分类」列为一条种子数据
（`isSystemDefault = 1`、不可删），而 §3 的删除规则又是
「其下任务 `categoryId` 置 NULL（迁到「未分类」）」。

两条放一起，**同一个用户可见状态就有两种编码**：

| 编码 | 怎么产生的 |
|---|---|
| `categoryId = NULL` | 删掉某个分类，FK 的 `ON DELETE SET NULL` 自动产生 |
| `categoryId = 未分类那一行` | 用户在编辑器里主动选了「未分类」 |

而且第一种**躲不掉** —— 外键约束就是那么定义的。于是每个查询、
每次分组与筛选都要把两种当同一种处理，漏一处就出现「有两个未分类」
或者「删完分类的任务从列表里消失了」。

**决定：`categoryId == null` ⇔ 未分类，且不建那一行。**

- 种子数据只有真正的四个分类（见 §3.1）。
- 「未分类」在界面上照常出现、照常可选，选中即写 NULL。
- 它不可删不是因为有保护逻辑，而是因为**它不是一行**，没有可删的东西。
- `categories.isSystemDefault` 这一列因此当前**没有使用者**。留着不动
  （删列要迁移，且 V3 同步的老数据里可能有它），但**不得**拿它来表达
  「未分类」—— 那会把刚去掉的第二种编码又请回来。

### 3.1 首次启动的默认分类

| 名称 | 颜色 | 图标 |
|---|---|---|
| 工作 | `#7FD1C1` | `briefcase` |
| 学习 | `#A8C8F0` | `book` |
| 生活 | `#FFB7C5` | `home` |
| 健康 | `#A8D8B9` | `heart` |

用户可全部删除或改名，不做保护 —— 全删光也没关系，
那时所有任务都是「未分类」，而那是个合法状态（§3.0）。

「未分类」的显示样式：名称`未分类`、色 `#A9A5B0`、图标 `inbox`。
**它是渲染时的常量，不是数据。**

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

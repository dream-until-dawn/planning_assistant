# 通知设计（V1）

> 对应 FR-NOTI-01..04。
> 本文中标注「✅ 已核实」的条目来自 `flutter_local_notifications 22.3.0` 的**源码与 README 实读**，
> 标注「⬜ 待验证」的必须在 M4 用真机/模拟器实测后再定稿，**不得凭印象实现**。

## 1. 难点在哪

本地通知看起来简单，实际有三个硬约束：

1. **不能一次排无限个**。「每天 07:00」是无限序列，系统不可能接受无限个待触发闹钟。
2. **系统会杀掉排期**。重启、强制停止、系统清理都可能丢失已排期的通知。
3. **精确闹钟需要权限，且可能被拒**。Android 12+ 起收紧，被拒后只能降级为非精确。

## 2. 架构

```
任务/提醒变更 ──► ReminderScheduler ──► 计算「窗口内应触发的通知」
                        │                        │
                        │                   与 scheduled_notifications 表比对
                        │                        │
                        │              ┌─────────┴─────────┐
                        │              ▼                   ▼
                        │        需新增的 schedule    需取消的 cancel
                        │              │                   │
                        └──────────────┴───────────────────┘
                                       ▼
                        flutter_local_notifications.zonedSchedule
```

- `ReminderScheduler` 位于 `lib/features/reminder/application/`，依赖 `platform/notification/` 的**接口**。
- 计算「窗口内应触发哪些通知」是**纯函数**，可脱离系统 API 单测：

```dart
List<PlannedNotification> planNotifications({
  required List<Occurrence> occurrences,   // 已展开的实例
  required List<Reminder> reminders,
  required ReminderSettings settings,      // 免打扰、默认提前量等
  required DateTime nowUtc,
  required DateRange window,
});
```

这个纯函数承载了几乎全部业务逻辑（免打扰顺延、合并、去重、上限截断），因此**测试成本极低、覆盖可以做满**。真正碰系统 API 的部分薄到只剩「按计划调用 schedule/cancel」。

## 3. 滚动窗口排期（FR-NOTI-02）

| 参数 | 配置项 | 默认 |
|---|---|---|
| 窗口长度 | `reminder.scheduleWindowDays` | 14 天 |
| 排期上限 | `reminder.maxScheduled` | 400 条 |

**续排触发点**：

| 时机 | 说明 |
|---|---|
| App 进入前台 | 主要手段，最可靠 |
| 任务/提醒/配置发生变更 | 只重排受影响的部分 |
| 设备重启后 | 见 §5 |
| 时区变更 | 见 §6 |

**超上限时的截断策略**：按触发时刻升序保留前 N 条，丢弃最远的。因为最近的更可能真的被用到，而远期的会在下次续排时补上。

> ⬜ **待验证（M4）**：Android 对单应用待触发 `AlarmManager` 闹钟数量的实际上限。
> 网上流传的数字不一致，**必须实测**：写一个循环排 N 条并用 `pendingNotificationRequests()`
> 回读实际条数，找到真实拐点，再据此定 `maxScheduled` 的默认值。
> 现在的 400 是保守估计，**不是**已验证的数字。

## 4. 权限

### 4.1 需要的权限（✅ 已核实）

| 权限 | 谁声明 | 说明 |
|---|---|---|
| `POST_NOTIFICATIONS` | 插件自带 | Android 13+ 运行时权限 |
| `VIBRATE` | 插件自带 | |
| `RECEIVE_BOOT_COMPLETED` | **应用自己声明** | 重启后恢复排期（FR-NOTI-03） |
| `SCHEDULE_EXACT_ALARM` | **应用自己声明** | 精确闹钟，用户可在设置里授予 |

插件自身的 `AndroidManifest.xml` 只声明了 `VIBRATE` 与 `POST_NOTIFICATIONS`（已读源码确认），
后两个必须写在应用的 manifest 里，同时还要注册插件提供的启动接收器：

```xml
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
    </intent-filter>
</receiver>
```

### 4.2 `USE_EXACT_ALARM` 不用（决定）

该权限无需用户授予，但据插件 README 引述的官方文档，它面向闹钟/日历类应用，
**可能受应用商店审核与审计**。本产品是计划助手，为一个「更方便」的权限承担上架风险不划算。

**采用 `SCHEDULE_EXACT_ALARM` + 引导用户授予 + 优雅降级**。

### 4.3 可用的 API（✅ 已核实存在于 22.3.0）

| API | 用途 |
|---|---|
| `requestNotificationsPermission()` | 请求通知权限 |
| `requestExactAlarmsPermission()` | 引导用户授予精确闹钟 |
| `canScheduleExactNotifications()` | 查询精确闹钟当前是否可用 |
| `pendingNotificationRequests()` | 回读实际待触发列表（**排期一致性自检的关键**） |
| `zonedSchedule(...)` | 按时区排期 |
| `cancel(id:)` / `cancelAll()` | 取消 |

> 由于插件已自带这两个权限申请能力，**`permission_handler` 对通知场景并非必需**。
> 这直接关系到能否把 `compileSdk` 从预览版 37 降回稳定版 36，见
> [环境探针结论 §3.2](../05-engineering/environment-notes.md)。M0 检查表项。

### 4.4 降级策略（FR-NOTI-04）

| 状态 | 行为 | UI |
|---|---|---|
| 通知权限被拒 | 不排期 | 设置页显示状态卡片 + 一键跳系统设置 |
| 精确闹钟不可用 | 用 `AndroidScheduleMode.inexact` 继续排 | 明确告知「提醒可能延迟几分钟」，不假装一切正常 |
| 两者都可用 | `exactAllowWhileIdle` | — |

`AndroidScheduleMode` 的四个取值已读源码确认：`alarmClock` / `exact` / `exactAllowWhileIdle` / `inexact`。
选 `exactAllowWhileIdle` 而非 `alarmClock`：后者会在系统状态栏显示闹钟图标，对计划助手来说过于喧宾夺主。

## 5. 重启恢复（FR-NOTI-03）

两道保险：

1. 注册插件的 `ScheduledNotificationBootReceiver`（§4.1），由插件自行恢复。
2. App 下次启动时，用 `pendingNotificationRequests()` 回读系统实际待触发列表，
   与本地 `scheduled_notifications` 表**对账**：缺的补排，多的取消。

> 第 2 条是关键。只依赖第 1 条等于把正确性交给外部组件，而这恰恰是**测不出来**的部分。
> 对账逻辑是纯函数（输入两个列表，输出差异），可以做满测试。

## 6. 时区变更

`device.lastKnownTimeZone` 记录上次已知时区。每次启动比对：

- 不同 → 全量重排（墙钟不变，但绝对触发时刻变了）
- 相同 → 增量续排

> ⬜ **待验证（M4）**：Android 时区变更广播 `ACTION_TIMEZONE_CHANGED` 是否需要单独监听，
> 还是「下次启动时检查」已经足够。倾向后者（更省电、更简单），但要实测确认在时区改变后、
> App 未启动期间不会触发错误时刻的提醒。

## 7. 免打扰（FR-CFG 的 `reminder.quietHours*`）

| 配置 | 行为 |
|---|---|
| `postpone`（默认） | 落在免打扰时段内的提醒顺延到时段结束时刻 |
| `suppress` | 直接丢弃这一次 |

跨零点的时段（22:00–07:00）必须正确处理 —— 这是经典的 off-by-one 温床，列为必测。

## 8. 通知内容

由**纯函数**生成，不依赖 Widget（为 V2 的常驻通知与桌面小组件复用）：

```dart
NotificationContent buildReminderContent(Occurrence occ, ReminderSettings s);
String buildDigestText(TodayDigest digest);   // V2 常驻通知复用
```

- 标题 = 任务标题；正文 = 时间 + 分类（+ 阶段进度，若为阶段事项）。
- 同一时刻超过 `reminder.mergeThreshold`（默认 3）条时合并为一条摘要：「今天 09:00 有 5 项安排」。
- 点击通知 → 深链到该任务详情（go_router 深链，V2 小组件复用同一套路由）。

## 9. 通知渠道

| 渠道 ID | 名称 | 重要性 | 用途 |
|---|---|---|---|
| `task_reminder` | 任务提醒 | HIGH | 常规提醒 |
| `task_digest` | 每日概览 | DEFAULT | 合并摘要 / V2 常驻 |

渠道在首次排期前创建（`createNotificationChannel`，✅ 已核实存在）。
渠道创建后其重要性**无法由应用修改**（Android 限制），所以初版就要定对，改动需换渠道 ID。

## 10. 必测用例

| # | 用例 | 期望 |
|---|---|---|
| N-01 | 相对提醒（提前 15 分钟），任务时间改了 | 触发时刻跟着变 |
| N-02 | 重复任务，窗口 14 天，每日提醒 | 排 14 条，不多不少 |
| N-03 | 同上，超过 `maxScheduled` | 按时刻升序截断，保留最近的 |
| N-04 | 免打扰 22:00–07:00，提醒在 23:30 | `postpone` 时顺延到 07:00 |
| N-05 | 同上，提醒在 06:59 | 顺延到 07:00（边界） |
| N-06 | 同上，提醒在 07:00 整 | **不**顺延（边界，闭开区间要明确） |
| N-07 | 跳过某一次发生 | 该次的提醒被取消 |
| N-08 | 完成某一次发生 | 该次的提醒被取消 |
| N-09 | 删除任务 | 所有相关提醒被取消 |
| N-10 | 对账：系统列表少 2 条 | 补排这 2 条 |
| N-11 | 对账：系统列表多 3 条（任务已删） | 取消这 3 条 |
| N-12 | 时区从上海改到伦敦 | 全量重排，墙钟时刻不变 |
| N-13 | 同一时刻 5 条提醒，阈值 3 | 合并为 1 条摘要 |
| N-14 | 精确闹钟不可用 | 降级为 inexact，且 UI 状态可查 |

N-01..N-13 全部可在**纯 Dart 层**用假时钟与假通知平台测完，不需要设备。
只有 N-14 与实际触发时刻精度需要真机验证（M4 的手工验收项）。

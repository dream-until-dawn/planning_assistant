# 🔬 桌面小组件与通知栏常驻（V2 预研）

> 本文按[文档公约](../README.md#文档公约)第 3 条分「已验证的事实」与「未验证的假设」两栏。
> **不得把假设当结论使用。** V2 立项时先把假设逐条转成事实，再动手。

## 1. 目标

| 能力 | 说明 |
|---|---|
| 桌面小组件 | 主屏显示今日任务，可勾选完成，点击跳转 |
| 通知栏常驻 | 一条常驻通知显示今日概览（FR-NOTI-05） |

## 2. ✅ 已验证的事实

| # | 事实 | 依据 |
|---|---|---|
| F-1 | `home_widget 0.9.4` 可解析安装，与本项目 V1 依赖集**无版本冲突** | M0 依赖探针实测（该包在完整依赖集中一并解析成功） |
| F-2 | 该包已支持 **Jetpack Glance**（源码中含 `HomeWidgetGlanceState.kt`、`HomeWidgetGlanceWidgetReceiver.kt`） | 读包内 Android 源码 |
| F-3 | 该包提供后台更新链路：`HomeWidgetBackgroundReceiver` / `BackgroundService` / `BackgroundWorker` / `Scheduler` | 同上 |
| F-4 | 数据传递方式为 `saveWidgetData` + `updateWidget`（键值），非直接共享数据库 | 读包 README |
| F-5 | 本机 Android SDK / NDK / AGP 可构建含原生代码的插件 | M0 已成功构建含 4 个原生插件的 APK |

## 3. ⬜ 未验证的假设（V2 必须先验）

| # | 假设 | 风险 | 怎么验 |
|---|---|---|---|
| A-1 | 小组件里勾选完成能可靠回写到主应用数据库 | **高**。若不可靠，小组件只能只读 | 写最小原型：Glance 按钮 → 后台回调 → 打开 Drift 库写入 → 主应用能看到 |
| A-2 | 后台 isolate 中可以打开同一个 Drift/SQLite 文件而不损坏数据 | **高**。SQLite 多进程访问需 WAL + 正确的锁处理 | 原型中并发读写压测；确认 `journal_mode=WAL` 已开 |
| A-3 | 小组件刷新频率能满足「跨零点自动换成新的一天」 | 中 | 用 `HomeWidgetScheduler` 排零点刷新并观察数日 |
| A-4 | 常驻通知在国产 ROM 上不被清理 | **高**。国产 ROM 后台策略差异极大 | 至少在 2–3 个主流 ROM 真机上验证 |
| A-5 | Glance 能实现「可爱清新」的视觉（大圆角、柔和阴影） | 中 | Glance 的样式能力弱于 Compose，需先做视觉原型确认可接受的降级方案 |

> A-1/A-2 是**是否值得做**的决定性因素。若小组件无法写回，产品价值大打折扣（只能看不能勾），
> 那时应重新评估优先级，而不是硬做。

## 4. V1 已经为此留好的口子

| 留口 | 位置 | V2 怎么用 |
|---|---|---|
| `TodayDigest` 查询不依赖 Widget | [架构总览 §6](../01-architecture/overview.md) | 后台 isolate 直接调用 |
| `buildDigestText()` 纯函数 | [通知设计 §8](notifications.md) | 常驻通知与小组件共用文案 |
| 写操作全部经 `TaskCommand` | FR-AI-01 | 小组件的「完成」只需构造一个 Command |
| go_router 深链 | [技术栈](../01-architecture/tech-stack.md) | 小组件点击 → 深链到任务详情 |
| `lab.homeWidgetEnabled` / `lab.persistentNotification` 配置项 | [配置中心 §2.6](../03-design/settings-spec.md) | 直接翻开关，不改导出格式 |

**M1 验收时会检查这些口子确实可用**（例如：写一个不启动 Flutter binding 的纯 Dart 测试取到今日概览）。

## 5. 技术路线（待 §3 验证后定稿）

```
                    Flutter 主应用
                          │  写入
                          ▼
                    Drift / SQLite (WAL)
                          ▲
                          │ 后台 isolate 读写
              ┌───────────┴────────────┐
              │  home_widget 后台回调   │
              └───────────┬────────────┘
                          │ saveWidgetData
                          ▼
                 Glance AppWidget (Kotlin)
                    渲染 + 勾选按钮
```

备选（若 A-2 不成立）：小组件只读 `saveWidgetData` 写入的快照，勾选动作改为**唤起主应用**完成。
体验略差但可靠，作为兜底方案。

## 6. 视觉规格（草案，待 A-5 验证）

| 尺寸 | 内容 |
|---|---|
| 2×2 | 今日剩余数量 + 最近一项 |
| 4×2 | 今日前 3 项，带完成钮 |
| 4×4 | 今日全部 + 分类色条 |

配色沿用[设计系统](../03-design/design-system.md)，但需确认 Glance 支持的圆角与阴影能力。

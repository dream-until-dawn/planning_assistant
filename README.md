# Planning Assistant · 计划助手

> 一个「可爱清新」风格的每日计划助手。用 Flutter 实现，第一版交付 Android APK。

支持单项任务、**阶段事项**（一个事项多个阶段）与**定时计划**（每日/每周/每月…），
提供**时间轴 / 列表 / 日历 / 竖向甘特**四种视图，配置项丰富且全部带默认值。

## 当前状态

**📐 设计阶段** —— 本项目遵循**文档先行**：实现动作之前，对应的设计文档必须先存在。
目前完整的架构与设计文档已就位，工程骨架尚未搭建（对应路线图的 M0）。

👉 **[文档中心](docs/README.md)** —— 从这里开始阅读

| 想知道 | 看这里 |
|---|---|
| 做什么、不做什么 | [产品愿景与范围](docs/00-product/vision-and-scope.md) |
| 具体要哪些能力 | [需求规格 FR/NFR](docs/00-product/requirements.md) |
| 怎么分层、代码放哪 | [架构总览](docs/01-architecture/overview.md) · [模块与目录规范](docs/01-architecture/module-map.md) |
| 用什么技术、为什么 | [技术栈与版本矩阵](docs/01-architecture/tech-stack.md) · [ADR](docs/06-adr/README.md) |
| 数据怎么存、怎么同步 | [数据模型](docs/02-domain/data-model.md) |
| 长什么样 | [设计系统](docs/03-design/design-system.md) · [四视图规格](docs/03-design/view-specs.md) |
| 怎么保证质量 | [测试策略](docs/05-engineering/testing-strategy.md) |
| 分几期做 | [路线图与里程碑](docs/07-roadmap/roadmap.md) |

## 技术栈

Flutter 3.47 / Dart 3.13 · Riverpod 3 · Drift (SQLite) · go_router · freezed
重复规则遵循 **RFC 5545**（与 iCalendar 互通）。

完整版本矩阵见[技术栈文档](docs/01-architecture/tech-stack.md)，其中所有版本号均为**实际解析并验证**所得。

## 开发环境准备

⚠️ 本项目对构建环境有几个**硬性要求**，不满足会以极具误导性的报错失败。
动手前请先读 **[环境探针结论](docs/05-engineering/environment-notes.md)**，重点：

- 项目路径必须**纯 ASCII**（AGP 拒绝非 ASCII 路径）
- Gradle 仓库必须配镜像（本网络环境下 Maven Central 返回 403）
- 必须启用 core library desugaring（`flutter_local_notifications` 硬性要求）

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter build apk --debug
```

## 路线图

| 版本 | 内容 |
|---|---|
| **V1** | 三种任务形态 · 四视图 · 配置中心 · 本地通知 · 导入导出 |
| V2 | 桌面小组件 · 通知栏常驻 |
| V3 | 云端同步 / 恢复 · 云端读取任务并发邮件 |
| V4 | 语音识别 · AI Agent |

V2–V4 的能力在 V1 阶段就已在架构上留好接口，并逐条列出了验收方式 ——
见[架构总览 §6](docs/01-architecture/overview.md)。

## 隐私

V1 **不联网、不采集任何遥测**，只申请通知与精确闹钟权限。
后续版本的云同步是用户显式开启的可选项。

## 许可

见 [LICENSE](LICENSE)。

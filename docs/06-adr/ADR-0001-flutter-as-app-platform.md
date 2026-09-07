# ADR-0001：用 Flutter 作为应用平台

**状态**：✅ 已采纳 · 2026-09-07

## 背景

第一版交付 Android APK，后续要做桌面小组件、通知栏常驻，更远期可能上其它平台。
仓库 README 已写明「flutter 实现的计划助手」，本机已装 Flutter 3.47.0 stable 与完整 Android 工具链。

## 决策

**用 Flutter 开发，Android 优先。** 需要原生能力的部分（小组件、通知接收器）写 Kotlin 原生代码，
经插件桥接。

## 后果

**收益**

- 四个视图（尤其竖向甘特）需要大量自定义绘制，Flutter 的 `CustomPainter` 与统一渲染管线在这方面成本最低。
- 「可爱清新」需要精细控制圆角、阴影、动效，Flutter 的完全自绘保证跨设备一致。
- 一套代码，将来上其它平台的边际成本低。
- 已实测：完整依赖集（含原生 SQLite、通知插件）可成功构建 APK 并在模拟器运行。

**代价**

- 桌面小组件**必须**写原生 Kotlin（Glance / RemoteViews），Flutter 帮不上忙。这是 V2 的主要风险，见[小组件预研](../04-platform/future-widget.md)。
- 包体积大于纯原生（M0 实测 debug APK 157MB，release 拆 ABI 后待测）。
- 依赖 Flutter 生态的插件质量，已经踩到 `flutter_timezone` 用旧 KGP 被 AGP 9 警告的问题。

## 被否决的方案

| 方案 | 为什么不选 |
|---|---|
| 原生 Kotlin + Compose | 小组件与通知会更顺手，但四视图的自绘工作量更大，且放弃跨平台可能。仓库定位已是 Flutter |
| React Native | 高性能自绘图表（甘特）体验不如 Flutter；小组件同样要写原生 |
| 纯 Web / PWA | 无法做桌面小组件与可靠的本地闹钟通知，直接排除 |

## 什么情况下该推翻

- 若 V2 实测发现 Flutter ↔ Glance 的数据回写链路不可靠到无法接受（见预研 A-1/A-2），
  且小组件被判定为核心价值 —— 那时应重新评估是否值得为小组件转原生。
- 若包体积成为用户抱怨的主要来源。

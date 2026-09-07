# 架构决策记录（ADR）

任何「为什么不选 B」的问题，答案必须在这里，而不是散落在聊天记录里。

## 格式

每条 ADR 包含：**背景 → 决策 → 后果（含代价）→ 被否决的方案 → 什么情况下该推翻这条决策**。

最后一节尤其重要：一条不说明何时失效的决策，会在情况变化后仍被当作教条遵守。

## 状态

| # | 决策 | 状态 | 日期 |
|---|---|---|---|
| [0001](ADR-0001-flutter-as-app-platform.md) | 用 Flutter 作为应用平台 | ✅ 已采纳 | 2026-09-07 |
| [0002](ADR-0002-riverpod-clean-layering.md) | Riverpod 3 + 分层 Clean 架构 | ✅ 已采纳 | 2026-09-07 |
| [0003](ADR-0003-drift-sqlite-persistence.md) | Drift（SQLite）作为本地持久化 | ✅ 已采纳 | 2026-09-07 |
| [0004](ADR-0004-rfc5545-recurrence.md) | 重复规则用 RFC 5545 RRULE | ✅ 已采纳 | 2026-09-07 |
| [0005](ADR-0005-local-time-model.md) | 计划时间存墙钟 + IANA 时区 | ✅ 已采纳 | 2026-09-07 |
| [0006](ADR-0006-sync-ready-record-envelope.md) | V1 就带同步信封与 outbox | ✅ 已采纳 | 2026-09-07 |
| [0007](ADR-0007-toolchain-pinning.md) | 工具链版本固定与镜像策略 | ✅ 已采纳 | 2026-09-07 |

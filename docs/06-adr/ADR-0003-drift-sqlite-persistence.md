# ADR-0003：Drift（SQLite）作为本地持久化

**状态**：✅ 已采纳 · 2026-09-07

## 背景

需求要求「数据结构方便落盘/加载，方便后续云端同步/恢复，且可由云端读取」。
同时四视图需要按时间窗、分类、状态做复杂查询，并以响应式流驱动 UI。

## 决策

**用 Drift 2.34.4（SQLite）**，配合 `drift_flutter 0.3.1`。
**不声明** `sqlite3_flutter_libs`（已 EOL，`sqlite3` 3.x 自带原生库）。

## 后果

**收益**

- 类型安全的 SQL：查询写错在编译期就报，而不是运行时。
- `watch()` 提供响应式流，天然驱动四个视图的自动刷新。
- 正规的 schema 迁移机制 + `drift_dev schema dump` 可固化历史版本做迁移测试。
- 行 ⇄ JSON 一一对应，导出格式无需额外加工层，服务端可独立解析。
- **已实测**：`flutter test` 在 Windows 宿主直接跑通 `NativeDatabase.memory()`（SQLite 3.53.4），
  数据层测试可以用真实 SQL 引擎而不是 mock，秒级反馈，**不需要** Visual Studio C++ 组件。
- **已实测**：APK 中原生 SQLite 正常加载与持久化（多次启动数据累积）。

**代价**

- 需要 `build_runner` 生成代码。
- Drift 会为表 `Tasks` 生成同名数据类 `Task`，与领域实体撞名 —— 约定用 `@DataClassName('TaskRow')` 规避。
- 比 NoSQL 方案多写 schema 定义。

## 被否决的方案

| 方案 | 为什么不选 |
|---|---|
| Isar / ObjectBox | 读写更快、API 更简；但复杂关联查询与 schema 演进较弱，且 Isar v3 维护状态存疑。本项目的查询复杂度（时间窗 + 多条件筛选 + 分组）正是关系型的强项 |
| 纯 JSON 文件 + 内存索引 | 天然可直传云端，但上千条后查询与并发写入成为瓶颈，且无事务保证 —— 而 outbox 与业务表必须同事务写入 |
| `sqflite`（裸 SQL） | 没有类型安全、没有响应式流、迁移要手写，Drift 的收益正是补上这些 |
| `sqlite3_flutter_libs` | **已 EOL**，其 0.6.0+eol 版本已被作者清空所有代码 |

## 什么情况下该推翻

- 若性能实测发现 SQLite 在本项目的查询模式下达不到 NFR-PERF-02（1000 条 60fps）——
  但更可能的原因是查询或索引写得不对，应先优化。
- 若将来 Drift 与 Flutter 版本出现长期不兼容。

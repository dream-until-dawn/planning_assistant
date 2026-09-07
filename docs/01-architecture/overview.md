# 架构总览

## 1. 架构目标

按重要性排序（冲突时以序号在前者为准）：

1. **领域可独立演进**：任务/重复/时间的业务规则不依赖 Flutter、不依赖数据库实现，可在纯 Dart VM 下秒级跑完测试。
2. **写入路径唯一**：所有数据变更走同一条 `TaskCommand` 管道 —— 这是 V3 云同步与 V4 AI Agent 的前提。
3. **读取路径可复用**：查询结果不绑定 Widget，V2 的桌面小组件与通知能直接复用（`TodayDigest`）。
4. **可扩展性有边界**：新增视图不碰领域层，新增配置项只改一处，新增实体有固定套路。

## 2. 分层

```
┌──────────────────────────────────────────────────────────────┐
│  Presentation  (lib/features/*/presentation, lib/design)     │
│  Widget · 路由 · 主题 · 视图状态                                │
│  规则：只依赖 Application 暴露的 Provider，不 import data/      │
└───────────────┬──────────────────────────────────────────────┘
                │ 读: watch(provider)   写: dispatch(TaskCommand)
┌───────────────▼──────────────────────────────────────────────┐
│  Application   (lib/features/*/application)                  │
│  UseCase · Riverpod Provider · 视图模型编排 · 跨模块协调        │
│  规则：依赖 Domain 接口；不认识 Drift/Widget                    │
└───────────────┬──────────────────────────────────────────────┘
                │ 接口调用
┌───────────────▼──────────────────────────────────────────────┐
│  Domain        (lib/domain)                                  │
│  实体 · 值对象 · 状态机 · 重复引擎 · Repository 抽象接口         │
│  规则：零 Flutter 依赖，零 IO，纯函数优先                        │
└───────────────▲──────────────────────────────────────────────┘
                │ 实现接口（依赖倒置）
┌───────────────┴──────────────────────────────────────────────┐
│  Data          (lib/data)                                    │
│  Drift 表定义 · DAO · Repository 实现 · JSON 编解码 · outbox   │
│  规则：可以认识 Domain，绝不被 Domain 认识                       │
└──────────────────────────────────────────────────────────────┘
     ┌────────────────────────────────────────────────────┐
     │  Platform  (lib/platform)  通知 · 权限 · 文件 · 时区  │
     │  以接口形式注入，测试中可整体替换为 Fake             │
     └────────────────────────────────────────────────────┘
```

**依赖方向只有一条**：`Presentation → Application → Domain ← Data`。
Domain 是依赖倒置的中心，它**只被依赖，不依赖任何人**。

> 这条规则由自动化守卫测试强制（`test/architecture/layer_dependency_test.dart`，见 [测试策略](../05-engineering/testing-strategy.md) §6），
> 违规会让 CI 变红，而不是靠人自觉。

## 3. 读路径：响应式查询

```
Drift 表  ──watch()──►  DAO Stream  ──映射──►  Domain 实体 Stream
                                                     │
                                        Application: 组合/过滤/展开重复
                                                     │
                                          ┌──────────┴──────────┐
                                    视图 Provider          TodayDigest
                                    (4 个视图各自的)       (小组件/通知复用)
```

关键点：

- **重复任务不预存实例**。DB 里只有规则和例外；`Occurrence` 由 `RecurrenceEngine` 在查询时按可见时间窗展开。理由见 [ADR-0004](../06-adr/ADR-0004-rfc5545-recurrence.md)。
- 展开结果带缓存（按 `(taskId, revision, windowStart, windowEnd)` 记忆化），避免滚动时重复计算。
- 四个视图**共用同一份** `visibleOccurrencesProvider`，各自只做布局，不各自查库。这是 FR-VIEW-05/06 能成立的基础。

## 4. 写路径：单一命令管道

```
UI 交互 / (V4) AI Agent / (V3) 云端拉取
              │
              ▼
      TaskCommand (可序列化)
              │
              ▼
   CommandDispatcher  ── 校验 ──► 领域不变量检查
              │
              ▼
      Repository (事务)
              │
        ┌─────┴─────┐
        ▼           ▼
    业务表      ChangeLog(outbox)   ← 同一事务内写入，保证一致
        │
        ▼
   Drift 变更通知 → 读路径 Stream 自动刷新
        │
        ▼
   ReminderScheduler 重排受影响的提醒
```

为什么值得多这一层：

| 收益 | 兑现时机 |
|---|---|
| 撤销/重做只需实现 Command 的逆操作 | V1 |
| 变更日志天然产生，无需在每个仓储方法里手写埋点 | V1 |
| 云端下发的变更与本地操作走完全相同的校验路径 | V3 |
| AI Agent 只需输出 JSON 形态的 Command，无需理解 UI | V4 |

**约束**：Presentation 层不得持有 Repository 引用。由守卫测试强制（NFR-MAINT-01、FR-AI-01）。

## 5. 模块（feature）划分

按**用户能感知的能力**切，不按技术切：

```
lib/features/
  task/          任务的增删改查、详情、编辑器
  views/         四个视图（timeline / list / calendar / gantt）
  settings/      配置中心
  reminder/      提醒的设置与排期
  data_transfer/ 导入导出与备份
  shell/         应用外壳：底部导航、路由、启动流程
```

每个 feature 内部固定三层目录：`presentation/` `application/` （必要时）`domain/`。
跨 feature 只能通过 Application 层的 Provider 通信，**禁止跨 feature import presentation**。

## 6. 为后续期次留的口子（逐条可验收）

| 期次 | 能力 | V1 就必须存在的东西 | 验收方式 |
|---|---|---|---|
| V2 | 桌面小组件 | `TodayDigest` 查询不依赖任何 Widget；DB 位于可被独立进程打开的路径 | 写一个纯 Dart 测试，不启动 Flutter binding 就能取到今日概览 |
| V2 | 通知栏常驻 | 通知文案由纯函数 `buildDigestText(TodayDigest)` 生成 | 该函数有独立单测 |
| V3 | 云同步 | 全表 `SyncEnvelope` + outbox；导出 JSON 自描述 | 变更日志回放测试：清库后回放 outbox 应还原等价状态 |
| V3 | 云端发邮件 | 导出 JSON 有 JSON Schema，服务端无需客户端逻辑即可解析 | schema 校验测试 |
| V4 | 语音 / Agent | 写操作 100% 经由 `TaskCommand`，且 Command 可 JSON 往返 | Command 序列化往返测试 + 架构守卫测试 |

> 这些口子在 M1 结束时集中验收一次。**没通过就不进 M2**，避免「留口」变成口号。

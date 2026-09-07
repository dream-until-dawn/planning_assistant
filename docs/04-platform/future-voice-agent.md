# 🔬 语音识别与 AI Agent（V4 预研）

> 分「已验证的事实」与「未验证的假设」两栏。
> 目标：用户说一句「下周一下午三点和张三开会，提前半小时提醒我」，应用就把任务建好。

## 1. 链路

```
麦克风 ──► 语音识别(ASR) ──► 文本 ──► Agent ──► TaskCommand(JSON) ──► 校验 ──► 执行
                                                      │
                                              用户确认（可撤销）
```

**关键设计**：Agent 的输出**不是**直接的数据库操作，而是 `TaskCommand` —— 一个可序列化、
可校验、可展示给用户确认、可撤销的意图对象。

## 2. ✅ 已验证的事实（V1 已落实）

| # | 事实 | 依据 |
|---|---|---|
| F-1 | 所有写操作都经由 `TaskCommand`，UI 层不直接调 Repository | FR-AI-01，由架构守卫测试强制 |
| F-2 | 每个 `TaskCommand` 都有 JSON 往返测试 | [测试策略 §6](../05-engineering/testing-strategy.md) |
| F-3 | 命令执行路径带完整领域校验，非法命令会被拒绝而不是写坏数据 | [架构总览 §4](../01-architecture/overview.md) |
| F-4 | `lab.voiceInputEnabled` / `lab.agentEnabled` 配置项已在 V1 注册表中声明 | [配置中心 §2.6](../03-design/settings-spec.md) |

> F-1 + F-3 意味着：Agent 出错时**伤害有上界** —— 它只能产生「合法但可能不是用户想要的」命令，
> 不能产生「破坏数据一致性」的写入。这是把 Agent 接进来的安全前提。

## 3. ⬜ 未验证的假设 / 未决问题

| # | 问题 | 备注 |
|---|---|---|
| A-1 | ASR 方案：系统内置 / 端上模型 / 云端 API | 与 NFR-PRIV-01（不联网）直接冲突，**必须由用户显式开启并明确告知数据去向** |
| A-2 | 中文口语的时间表达解析准确率 | 「下周一」「大后天」「这个月底」「每隔一天」等，需实测语料 |
| A-3 | Agent 放端上还是云端 | 端上模型体积/性能 vs 云端隐私成本 |
| A-4 | 离线可用性 | 若 ASR 或 Agent 需联网，无网时如何降级 |
| A-5 | 误识别的纠正成本 | 若纠正比手动输入还慢，功能没有价值 |

## 4. 设计原则（现在就定下，避免 V4 走偏）

1. **永远先确认再执行**。Agent 产出的命令以「预览卡片」形式展示（「要创建：周一 15:00 与张三开会，提前 30 分钟提醒」），用户点确认才落库。
2. **一切可撤销**。命令走同一条管道，撤销复用既有能力。
3. **隐私默认关闭**。语音与 Agent 默认关闭；开启时用不含营销话术的直白文案说明数据流向。
4. **失败要说人话**。听不懂就说听不懂并保留原始文本供用户手动编辑，**不要瞎猜着建一个错任务** —— 错任务比不建任务更糟。
5. **不做「智能建议」**。不主动推荐用户该做什么。这与[产品愿景](../00-product/vision-and-scope.md)的低压力原则冲突。

## 5. `TaskCommand` 的形态（V1 就要定好）

```dart
sealed class TaskCommand {
  Map<String, Object?> toJson();
  // 每个子类都必须有 fromJson + 往返测试
}

// V1 需要的命令（示例，非全集）
CreateTask, UpdateTask, DeleteTask, RestoreTask,
CompleteOccurrence, SkipOccurrence, MoveOccurrence,
SplitRecurrenceFrom,            // 「本次及以后」
AddStage, ReorderStages, CompleteStage,
SetReminder, RemoveReminder,
UpsertCategory, DeleteCategory,
UpdateSetting,
```

> **V1 的责任**：把这套命令定义好、序列化测好。V4 的 Agent 只是这套命令的另一个调用方。
> 如果 V1 偷懒让 UI 直接调 Repository，V4 就得推倒重来 —— 这就是为什么 FR-AI-01 是 V1 需求而不是 V4 需求。

## 6. V4 立项前必须先做的事

1. 收集 200 条真实中文口语计划表达作为测试语料（可以从 V1 用户自己的使用中积累）。
2. 用该语料评测候选 ASR 与 Agent 方案，**先出准确率数字再谈实现**。
3. 若准确率不足以让「说一句话」比「点三下」更快，**不做**。

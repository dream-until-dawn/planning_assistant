# Planning Assistant · 文档中心

> 一个「可爱清新」风格的每日计划助手。第一版交付 Android APK。
> 本项目遵循 **文档先行**：任何实现动作之前，对应的设计文档必须先存在并通过评审。

## 阅读顺序

| # | 文档 | 回答什么问题 | 状态 |
|---|------|------------|------|
| 1 | [产品愿景与范围](00-product/vision-and-scope.md) | 做什么、不做什么、为谁做 | ✅ 定稿 |
| 2 | [需求规格 FR/NFR](00-product/requirements.md) | 具体要哪些能力，验收标准是什么 | ✅ 定稿 |
| 3 | [领域术语表](00-product/glossary.md) | 团队统一语言（代码命名以此为准） | ✅ 定稿 |
| 4 | [架构总览](01-architecture/overview.md) | 怎么分层、依赖方向、数据流 | ✅ 定稿 |
| 5 | [技术栈与版本矩阵](01-architecture/tech-stack.md) | 用什么、为什么、锁哪个版本 | ✅ 探针验证 |
| 6 | [模块与目录规范](01-architecture/module-map.md) | 代码放哪、模块边界在哪 | ✅ 定稿 |
| 7 | [横切关注点](01-architecture/cross-cutting.md) | 时间/ID/错误/日志/国际化怎么统一 | ✅ 定稿 |
| 8 | [数据模型](02-domain/data-model.md) | 实体、关系、表结构、同步信封 | ✅ 定稿 |
| 9 | [重复规则引擎](02-domain/recurrence-engine.md) | 定时计划怎么展开、例外怎么存 | ✅ 定稿 |
| 10 | [任务生命周期](02-domain/task-lifecycle.md) | 状态机与合法迁移 | ✅ 定稿 |
| 11 | [设计系统](03-design/design-system.md) | 颜色/字体/圆角/间距/动效 token | ✅ 定稿 |
| 12 | [四视图规格](03-design/view-specs.md) | 时间轴/列表/日历/竖向甘特 | ✅ 定稿 |
| 13 | [配置中心规格](03-design/settings-spec.md) | 所有可配置项与默认值 | ✅ 定稿 |
| 14 | [通知设计](04-platform/notifications.md) | V1 本地通知怎么排期与重排 | ✅ 定稿 |
| 15 | [桌面小组件预研](04-platform/future-widget.md) | V2 可行性与技术路径 | 🔬 预研 |
| 16 | [云同步预研](04-platform/future-sync.md) | V3 同步协议与冲突解决 | 🔬 预研 |
| 17 | [语音与 Agent 预研](04-platform/future-voice-agent.md) | V4 语音指令到任务的链路 | 🔬 预研 |
| 18 | [工程规范](05-engineering/conventions.md) | 命名/提交/分支/评审 | ✅ 定稿 |
| 19 | [测试策略](05-engineering/testing-strategy.md) | 怎么保证「测试不是永远绿的」 | ✅ 定稿 |
| 20 | [构建与发布](05-engineering/build-and-release.md) | 怎么出可安装的 APK | ✅ 定稿 |
| 21 | [本机环境探针结论](05-engineering/environment-notes.md) | 环境坑与规避方式 | ✅ 实测 |
| 21b | [探针产物](05-engineering/probe-artifacts/README.md) | 上一条结论的可复现依据（lock + 复现脚本） | ✅ 可复跑 |
| 21c | [M0 执行记录](05-engineering/m0-record.md) | 工程基建的落地结果与**守卫变红的实际输出** | ✅ 已完成 |
| 21d | [变异演练 · M1-A 时间](05-engineering/mutation-drills/M1-A-time.md) | 8 个变异，1 个存活并已补测 | ✅ |
| 21e | [变异演练 · M1-B 重复引擎](05-engineering/mutation-drills/M1-B-recurrence.md) | 10 个变异全部被抓 | ✅ |
| 22 | [架构决策记录 ADR](06-adr/README.md) | 关键选型的理由与代价 | ✅ 7 条 |
| 23 | [路线图与里程碑](07-roadmap/roadmap.md) | 分几期、每期验收什么 | ✅ 定稿 |

## 文档公约

1. **可追溯**：需求有编号（`FR-x`/`NFR-x`），设计文档引用需求编号，测试用例引用设计章节。
2. **决策留痕**：任何「为什么不选 B」的问题，答案必须在 `06-adr/` 里，而不是散落在聊天记录。
3. **预研文档不写空话**：标记 🔬 的文档必须包含「已验证的事实」与「未验证的假设」两栏，禁止把假设写成结论。
4. **文档随代码改**：改了 schema 必须同一个 PR 改 `data-model.md`，CI 会检查（见 [工程规范](05-engineering/conventions.md)）。

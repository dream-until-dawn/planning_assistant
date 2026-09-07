# 模块与目录规范

## 1. 顶层目录

```
planning_assistant/
├── android/                   Android 原生壳（V2 小组件的原生代码也落这里）
├── docs/                      本文档中心
├── lib/
│   ├── main.dart              入口：仅做 bootstrap，不写业务
│   ├── bootstrap.dart         初始化编排（DB、时区、通知、错误捕获）
│   ├── app.dart               MaterialApp + 路由 + 主题装配
│   │
│   ├── core/                  与业务无关的基础设施（可整包复制到别的项目）
│   │   ├── result/            Result/Failure 类型
│   │   ├── time/              Instant / LocalWallTime / 时区工具
│   │   ├── id/                ID 生成（UUID v7）
│   │   ├── logging/           日志门面
│   │   └── extensions/
│   │
│   ├── domain/                领域层：零 Flutter 依赖
│   │   ├── entities/          Task / Stage / Occurrence / Category / ...
│   │   ├── value_objects/     TimeSpanSpec / Recurrence / Priority / ...
│   │   ├── recurrence/        重复引擎（纯函数）
│   │   ├── policies/          业务规则（状态迁移、冲突检测、提醒计算）
│   │   ├── commands/          TaskCommand 定义
│   │   └── repositories/      抽象接口（只有接口，没有实现）
│   │
│   ├── data/                  数据层：Domain 接口的实现
│   │   ├── database/          Drift：表定义、DAO、迁移
│   │   ├── mappers/           Drift 行 ⇄ Domain 实体
│   │   ├── repositories/      Repository 实现
│   │   ├── dto/               JSON DTO（导入导出、将来的云端载荷）
│   │   └── outbox/            变更日志写入与回放
│   │
│   ├── platform/              与设备打交道的一切，全部接口化
│   │   ├── notification/      本地通知（V1）
│   │   ├── permission/        权限申请
│   │   ├── storage/           文件路径、导出落盘
│   │   ├── timezone/          系统时区读取
│   │   └── widget/            (V2) 桌面小组件桥接
│   │
│   ├── design/                设计系统（见 03-design/design-system.md）
│   │   ├── tokens/            颜色/间距/圆角/字体/时长 token
│   │   ├── theme/             ThemeData 装配、明暗主题
│   │   ├── components/        可复用基础组件（按钮、卡片、Chip、空态…）
│   │   └── illustrations/     插画与图标
│   │
│   ├── features/              按用户能力切分的功能模块
│   │   ├── shell/             外壳：导航、路由表、启动页
│   │   ├── task/              任务 CRUD 与编辑器
│   │   ├── views/             四视图
│   │   │   ├── shared/        共享的可见实例 Provider、筛选状态
│   │   │   ├── timeline/
│   │   │   ├── task_list/
│   │   │   ├── calendar/
│   │   │   └── gantt/
│   │   ├── settings/          配置中心
│   │   ├── reminder/          提醒设置与排期
│   │   └── data_transfer/     导入导出、备份
│   │
│   └── l10n/                  本地化 arb 资源
│
├── test/                      见 05-engineering/testing-strategy.md
│   ├── domain/                纯 Dart 单测（最厚的一层）
│   ├── data/                  Drift 内存库集成测试 + 迁移测试
│   ├── application/           UseCase 测试
│   ├── presentation/          Widget 测试
│   ├── golden/                视觉回归
│   └── architecture/          分层依赖守卫测试
├── integration_test/          真机端到端
└── tool/                      开发脚本（codegen、schema dump、发版）
```

## 2. feature 内部结构（强制统一）

```
features/<name>/[<子模块>/]
├── presentation/    Page / Widget / 局部状态
├── application/     Provider / UseCase / 视图模型
└── domain/          仅当该 feature 有自己独有的领域概念时才建，否则不建
```

**允许一层可选的子模块**：当一个 feature 内部有多个并列的同类模块时（§1 中
`features/views/` 下的 `shared` / `timeline` / `task_list` / `calendar` / `gantt` 就是如此），
可以在 feature 名与层目录之间加一级。层目录的三个名字**不变**，这一点是强制的。

| 形态 | 例 | feature 名 |
|---|---|---|
| 两级 | `features/task/presentation/` | `task` |
| 三级（带子模块） | `features/views/gantt/presentation/` | **`views`** |

> ⚠️ **feature 边界在第一段**：`views/gantt` 与 `views/shared` 属于**同一个 feature**，
> 因此它们之间可以直接引用（view-specs §0.3 的「同一个筛选条组件」正依赖这一点），
> 而 §3 的「不得跨 feature 引用 presentation」约束的是 `views` 与 `task` 之间。
>
> 初版 §2 只写了两级形态、且标注「强制统一」，与 §1 的三级结构自相矛盾。
> 该矛盾是在 M0 写守卫时被撞出来的：守卫照 §1 实现，就违反了 §2 的措辞
> —— 详见 [M0 执行记录 §2.1e](../05-engineering/m0-record.md)。

**禁止**在 feature 里建 `data/`。所有持久化实现都归 `lib/data/`，避免同一张表被多处写。

## 3. 依赖规则（由 `test/architecture/layer_dependency_test.dart` 强制）

| 层 | 允许 import | 禁止 import |
|---|---|---|
| `core/` | Dart SDK、极少数纯工具包 | `domain/` `data/` `features/` `platform/` `design/` |
| `domain/` | `core/` | **任何** `package:flutter/*`、`data/`、`features/`、`platform/`、`design/` |
| `data/` | `core/` `domain/` | `features/` `design/` `platform/`（平台能力经构造注入） |
| `platform/` | `core/` `domain/`(仅值对象) | `data/` `features/` |
| `design/` | `core/` Flutter | `domain/` `data/` `features/` |
| **`features/*/domain/`** | `core/`、顶层 `domain/` | **与顶层 `domain/` 同样严格**：`package:flutter/*`、`data/`、`platform/`、`design/` |
| `features/*/application/` | `core/` `domain/` `platform/` 接口 | `data/` 具体实现（只依赖抽象）、其它 feature 的 `presentation/` |
| `features/*/presentation/` | `core/` `design/` 本 feature 的 `application/` | `data/` `domain/repositories/`、其它 feature 的 `presentation/` |

> ⚠️ **`features/*/domain/` 这一行初版是缺的**，而 §2 又明文允许建这个目录。
> 守卫照本表逐格转写，表里没有的格自然转写不出来 —— 于是 `features/<name>/domain/`
> 落进一个**没有任何规则**的桶：Flutter 依赖、data 依赖、`DateTime.now()`、`assert`
> 四类违规同时存在而九条守卫全绿。
>
> **feature 本地的 domain 仍然是 domain**，NFR-MAINT-02 的「领域层零 Flutter 依赖、
> 可在纯 Dart VM 下测试」对它同样成立，否则「新增一个 feature 就能绕过领域层纯净性」。
> 经过见 [M0 执行记录 §2.1f](../05-engineering/m0-record.md)。

守卫测试的实现方式：解析 `lib/**/*.dart` 的 import 语句，按上表规则断言。
**新增违规会让 CI 变红**，这是 NFR-MAINT-01 的兑现方式。

## 4. 命名约定

| 对象 | 规则 | 例 |
|---|---|---|
| 文件 | `snake_case.dart` | `recurrence_engine.dart` |
| 类 | `UpperCamelCase`，用[术语表](../00-product/glossary.md)的词 | `OccurrenceOverride` |
| Drift 表类 | 复数 | `Tasks`、`Stages` |
| Drift 生成的行类 | 单数（drift 自动） | `Task`→ 冲突时用 `TaskRow` |
| Repository 接口 | `XxxRepository` | `TaskRepository` |
| Repository 实现 | `DriftXxxRepository` | `DriftTaskRepository` |
| UseCase | 动宾短语 | `CompleteOccurrence` |
| Provider | 名词 + `Provider` 后缀由 riverpod_generator 生成 | `visibleOccurrencesProvider` |
| 测试文件 | 被测文件名 + `_test.dart` | `recurrence_engine_test.dart` |

> ⚠️ Drift 会为表 `Tasks` 生成数据类 `Task`，与领域实体 `Task` 同名。
> **约定**：Drift 生成的行类统一在表定义里用 `@DataClassName('TaskRow')` 重命名，领域实体独占 `Task` 这个名字。

## 5. 新增东西的标准动作

| 想加什么 | 要动哪些地方 | 不该动哪里 |
|---|---|---|
| 一个新视图 | `features/views/<new>/` + 路由表 + 视图偏好枚举 | 领域层、数据层 |
| 一个新配置项 | `settings/registry.dart` 加一条 `SettingSpec` | 设置页 UI（自动渲染） |
| 一个新任务字段 | Drift 表 + 迁移 + 实体 + mapper + DTO + `data-model.md` | 视图（除非要展示） |
| 一个新的重复模式 | `domain/recurrence/` + 测试 | 其它所有层 |
| 一个新平台能力 | `platform/<cap>/` 接口 + 实现 + Fake | 领域层 |

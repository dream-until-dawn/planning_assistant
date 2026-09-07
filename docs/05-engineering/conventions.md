# 工程规范

## 1. 分支策略

```
main                    永远可构建、可出包。受保护，只接受 PR 合并
 ├─ feat/<scope>-<简述>  功能
 ├─ fix/<scope>-<简述>   缺陷
 ├─ docs/<简述>          纯文档
 ├─ chore/<简述>         构建、依赖、脚手架
 └─ spike/<简述>         探针。**允许烂代码，但禁止合入 main**，结论写进文档后删除分支
```

- `<scope>` 用 feature 名：`task` / `views` / `settings` / `reminder` / `data` / `domain` / `design`。
- 例：`feat/domain-recurrence-engine`、`fix/views-gantt-overlap`。

### 1.1 spike 分支的纪律

探针的产物是**文档结论**，不是代码。探针分支合入 main 是本项目明确禁止的事
—— 探针代码没有测试、没有错误处理，一旦混进主干就会变成技术债的种子。

> 本项目的 M0 探针工程建在仓库之外（`C:\VScodeProject\probe_apk`），结论写进
> [环境探针结论](environment-notes.md)，代码不入库。这是范例。

## 2. 提交信息

```
<type>(<scope>): <一句话，祈使句，不加句号>

<可选正文：为什么这么改，不是改了什么>

<可选脚注：Refs FR-TASK-05>
```

`type`：`feat` / `fix` / `docs` / `test` / `refactor` / `perf` / `build` / `chore`

**要求**：

- 正文回答**为什么**。「改了什么」看 diff 就知道，「为什么」只有作者知道。
- 修 bug 的提交必须引用对应的失败测试（见 [测试策略 §3.2](testing-strategy.md)）。
- 一个提交只做一件事。「顺手改了个格式」要单独提交。

## 3. PR 检查表

合入 main 前逐条确认：

- [ ] 全量测试通过，且**新增/修改的代码有能失败的测试**（不是覆盖率数字，是能失败）
- [ ] 修 bug 的 PR 里能看到测试从红变绿
- [ ] `dart analyze` 零 error 零 warning
- [ ] 架构守卫测试通过（分层依赖、时钟注入、领域层纯净）
- [ ] 改了 schema → 同 PR 更新了[数据模型](../02-domain/data-model.md) + 写了迁移测试
- [ ] 改了配置项 → 同 PR 更新了[配置中心规格](../03-design/settings-spec.md)
- [ ] 改了颜色 → 对比度测试通过
- [ ] 改了 golden → **单独提交**，PR 描述说明为什么视觉变了
- [ ] 没有新增硬编码颜色 / 尺寸 / 时长 / 文案
- [ ] 没有新增 `DateTime.now()` 直调

## 4. 代码生成

```bash
dart run build_runner build --delete-conflicting-outputs
```

- 生成产物（`*.g.dart` / `*.freezed.dart`）**入库**。理由：不入库时 CI 与新环境要先跑一次生成，
  且 review 时看不到生成结果的变化。入库的代价是偶尔的合并冲突，用「冲突时重新生成」解决即可。
- 生成产物**不参与 review**，`.gitattributes` 标记为 `linguist-generated`。
- 改了带注解的文件后忘记重新生成，会被 CI 抓到（CI 会跑生成并检查工作区是否干净）。

## 5. 文档与代码同步（CI 强制）

| 改动 | 必须同 PR 改的文档 |
|---|---|
| `lib/data/database/**` | [数据模型](../02-domain/data-model.md) |
| `lib/features/settings/registry.dart` | [配置中心规格](../03-design/settings-spec.md) |
| `lib/design/tokens/**` | [设计系统](../03-design/design-system.md) |
| `lib/domain/recurrence/**` | [重复引擎](../02-domain/recurrence-engine.md) |
| `pubspec.yaml` 依赖变化 | [技术栈与版本矩阵](../01-architecture/tech-stack.md) |

CI 用一个脚本检查：若 PR 触及左列路径而未触及右列文件，**报错并要求作者显式说明原因**
（可以用 `[skip-doc-check: 理由]` 放行，但理由会留在 PR 记录里）。

> 这条规则的价值在于：文档过期比没有文档更有害 —— 它会让人相信错的东西。

## 6. Lint

在 `flutter_lints 6.0.0` 基础上额外开启（`analysis_options.yaml`）：

| 规则 | 目的 |
|---|---|
| `prefer_const_constructors` 等 const 系列 | 性能 |
| `always_declare_return_types` | 可读性 |
| `avoid_print` | 用日志门面 |
| `require_trailing_commas` | diff 更干净 |
| `unawaited_futures` | 防止漏 await（异步 bug 温床） |
| `avoid_dynamic_calls` | 类型安全 |
| 自定义：禁止硬编码颜色 | 走设计 token |
| 自定义：禁止 `DateTime.now()` | 走注入的 Clock |
| `riverpod_lint` 全套 | Provider 用法正确性 |

> ⚠️ **不要显式声明 `custom_lint` 依赖** —— 与 `riverpod_lint 3.1.9` 版本冲突，
> 详见[技术栈 §6](../01-architecture/tech-stack.md)。

## 7. 代码风格

- 一律 `dart format`（默认 80 列）。格式化由 pre-commit 或 CI 强制，**不在 review 里讨论格式**。
- 文件超过 300 行考虑拆分；Widget build 方法超过 60 行必须拆。
- 注释写「为什么」，不写「是什么」。
  代码能自解释的地方不写注释；反常识的地方**必须**写（例如 `BYMONTHDAY=31` 会跳过月份这种）。
- 公开 API（跨层使用的类与方法）写 dartdoc。

## 8. 版本号

`主.次.修订+构建号`，如 `1.0.0+1`。

- 主：不兼容的数据格式变更
- 次：新增功能（对应路线图的 V2/V3/V4）
- 修订：缺陷修复
- 构建号：每次出包 +1，**不复用**

## 9. 评审要点（按重要性排序）

1. **测试能不能失败** —— 见[测试策略 §1](testing-strategy.md)。这是第一位的。
2. **不变量有没有用 `assert` 表达** —— release 会剥离，等于没写。见[横切关注点 §3.1](../01-architecture/cross-cutting.md)
3. **「已实测」的结论覆盖了几个样本** —— 单样本不支撑全称结论，见[测试策略 §1.2](testing-strategy.md)
4. 是否违反分层依赖
5. 是否引入了不可测的时间/随机/IO 直调
6. 边界条件（空、单个、大量、超长文本、极端日期、**极端时区 UTC+14 / UTC-11**）
7. 命名是否符合[术语表](../00-product/glossary.md)
8. 性能（只在热路径上较真）
9. 风格（交给工具，人不看）

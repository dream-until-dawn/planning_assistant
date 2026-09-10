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
  **已实测有效**（M1-C）：把「改了注解但没重新生成」的状态入索引后，CI 跑完生成 `git diff` 有 75 行差异并 `exit 1`。见 [m0-record](m0-record.md)。

### 4.1 改了 Drift 表定义时，还要更新 schema 快照

`build_runner` **不会**更新 `drift_schemas/`。漏了这一步不影响编译、不影响功能测试，
只会让 v1 基线与真实表定义脱节 —— 而它要到写 v2 迁移时才被需要，那时已无法确定线上的真实形状。

```bash
dart run drift_dev schema dump lib/data/database/app_database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/data/generated_migrations/
```

漏跑会被 `test/data/migration_test.dart` 的「当前表定义与 v1 快照逐列一致」抓到。
**注意该用例不能用 drift 文档里的 `startAt(n)` + `migrateAndValidate(db, n)` 写法** ——
那是拿快照跟自己比，当前表定义根本没参与，永远绿。原委见该文件的头部注释。

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

此外 CI 跑文档链接校验，**带自检**：

```bash
python tool/check_doc_links.py --self-test
```

`--self-test` 会先用已知坏链证明校验器能正确变红，再校验全仓。
不带自检的校验结果不予采信 —— 理由见[测试策略 §1.4](testing-strategy.md)。

> 这条规则的价值在于：文档过期比没有文档更有害 —— 它会让人相信错的东西。

### 5.1 需求可追溯性

```bash
python tool/check_traceability.py --self-test
```

**它在 `ci.yml` 的「需求可追溯性」那一步跑。** 这句话是规矩的一部分：
一条门禁写进文档而没接进 CI，和没有门禁是一回事 ——
这一条自己就当过一段时间的反面教材（见
[测试策略 §1.19](testing-strategy.md#119-一条没接进-ci-的门禁和没有门禁是一回事)）。

**每条 V1 需求都要有测试点它的名。** 全集来自 `requirements.md` 的编号本身，
不来自代码 —— 这是仓库里唯一一条不靠代码定义自己全集的检查，
理由见[测试策略 §1.15](testing-strategy.md#115-完备性守卫只能守住它认识的那个全集)。

没被点名的必须**显式列进豁免表并写清由谁承担**（哪个里程碑、或哪份文档）。
空着理由的豁免会让那张表变成垃圾桶。

**编号必须写在 `test(...)` / `group(...)` 的描述里，写在注释里不算。**
扫全文的话一条注释就能让需求变绿，而注释不会执行。收窄之后这条门禁与
`lint_tests.dart` **复合**：后者拒绝没有断言的测试，于是
「被一个用例点名」+「那个用例有断言」比单独任何一条都强。

`--verbose` 会打印每条需求是被**哪个文件的哪条用例**点名的。
这条门禁很弱，而对付「虚假安全感」的办法不是把匹配做强，
是**把它的弱点做成可见的** —— 一眼扫过去就能看出哪条只是被蹭了一下。

它是**下限**，不是验收：漏网的抓不住，「一条用例都没点过」一定抓得住。
M3 末尾第一次跑它翻出两条从没落地的 V1 需求（FR-TASK-07、FR-TASK-09）；
收窄到用例描述之后又翻出一条**假覆盖**：NFR-PERF-02（掉帧率）此前靠
一句注释算作有覆盖，而那个基准量的是排布耗时，不是掉帧 —— 已改为豁免。
那条需求后来由用户明确**降级为 V1 不验收**（[需求 §7.1.1](../00-product/requirements.md)）：
开发期只有模拟器，而模拟器的帧时间由宿主机调度决定，拿它当验收比不测更糟。

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
- **跑的是 `dart format lib test tool`，不是 `dart format .`。** 后者会顺手重排
  `docs/05-engineering/probe-artifacts/` 下的探针留档 —— 那些是「当时真跑过的
  那一份」的记录，改了它们就不再是记录了。门禁（ci.yml）只扫那三个目录，
  所以本地按 `.` 跑出来的「改了 N 个文件」里有一部分是纯噪声。
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

## 8.1 送审时怎么报范围

**提交数一律用命令数，不靠记忆：**

```bash
git rev-list --count main..HEAD
```

评审那侧用这个数**界定评审范围** —— 报少了，多出来的提交没人看。
M3 送审时报了 9，实际 11；两个提交就这么擦过去了。

同样要写清的还有：

- **送审的是哪个 commit**（`git rev-parse HEAD`）。分支会继续往前走，
  「M3 通过」通过的是当时那一版，不是这个分支的永久状态；
- **送审之后新增的提交要单独说**，不能靠上一次的「通过」覆盖。

## 9. 评审要点（按重要性排序）

1. **测试能不能失败** —— 见[测试策略 §1](testing-strategy.md)。这是第一位的。
2. **不变量有没有用 `assert` 表达** —— release 会剥离，等于没写。见[横切关注点 §3.1](../01-architecture/cross-cutting.md)
3. **「已实测」的结论覆盖了几个样本** —— 单样本不支撑全称结论，见[测试策略 §1.2](testing-strategy.md)
4. **这条断言在什么改动下会红** —— 要落到**具体断言**上，不是落到「我们要写 golden」上。
   「字号 2.8 下卡片不破版」在什么改动下会红？若答案是「把 `maxLines` 从 2 改成 1」，
   它测的是截断；若答案是「改任何一个间距 token」，那它其实是**快照**而不是断言。
   **注意标签不改变它变红的条件**：拿 golden 图去比的东西就是快照，
   注释里标成「断言」也不会变。分法与验证方式见
   [测试策略 §7.1](testing-strategy.md#71-断言型与快照型必须用机制分开不是用命名)。
5. **机制性论证能不能推出一条你还没看过的预测** —— 见 §9.1
6. **带「必须这样写」注释的实现细节，有没有对照组** —— 若没有任何测试会因为
   换成另一种写法而变红，那句注释迟早被合理地删掉。
   见[测试策略 §7.1.1](testing-strategy.md#711-第三类保护实现选择的对照组)
7. 是否违反分层依赖
8. 是否引入了不可测的时间/随机/IO 直调
9. 边界条件（空、单个、大量、超长文本、极端日期、**极端时区 UTC+14 / UTC-11**）
10. 命名是否符合[术语表](../00-product/glossary.md)

### 9.1 怎么判断一段「论证」是不是只是把观察换了个说法

> **一个机制性论证，必须能推出一条你还没看过的预测。**
> 推不出来，那它就不是机制，是观察的复述。

来自评审会话，起因是 M1 里一处**结论正确但论证错误**的推理 ——
这类比「结论错」更难自查，因为验证结论时它是绿的。

拿那次对照：

| | |
|---|---|
| 观察 E | 399 条重度用库的测试下，Drift 表定义文件的命中数为 0 |
| 论证 R | 生成的 `$TasksTable` 声明了全部字段，基类 getter 运行时从不执行 |
| **R 的独立预测** | 那就该在生成文件里找到这些 getter 的 override |
| 一查 | `get $primaryKey` 12 次，`get primaryKey` **0 次** → R 假 |
| 结论 C | 「可以排除」仍真，但理由必须换 |

关键在于那条预测**不是 E 本身**。如果从 R 能推出的唯一东西就是「所以命中数是 0」，
那 R 只是 E 的复述，没有增加任何可证伪内容 —— **这时候「论证」这个词是虚的**。

**怎么用**：把论证里的机制那句话拎出来，问「如果它成立，还有什么必须为真、
而我还没看过？」答不上来就是信号；答得上来就去查，查完要么加固、要么塌掉。

它作用在**已经写下来的论证**上，不依赖当时是否心虚 —— 这是它比
「觉得没把握就标出来」强的地方：后者只能捞到自己意识到在跳的那些。

它也不万能：R 可能推出的预测恰好也真（机制错而表现一致）。
但它把「靠感觉」变成了一个每次都能执行的动作。
8. 性能（只在热路径上较真）
9. 风格（交给工具，人不看）

# 任务生命周期与状态机

> 对应需求 FR-TASK-08。状态迁移的合法性由领域层强制。
>
> ⚠️ **不变量与迁移校验一律用显式 `throw` 表达，禁止用 `assert`** —— 见 §3.1。

## 1. 状态集合

```dart
enum TaskStatus { pending, inProgress, done, skipped }
```

| 状态 | 含义 | 在视图中 |
|---|---|---|
| `pending` | 待办，默认状态 | 全部视图可见 |
| `inProgress` | 进行中（用户显式标记，或阶段事项已有阶段完成） | 高亮显示 |
| `done` | 已完成 | 受「显示已完成」配置控制 |
| `skipped` | 主动跳过（不是失败，只是这次不做） | 默认隐藏，弱化显示 |

### 1.1 归档与删除**不是状态**

这两件事都用**时间戳列**表达，与 `status` 正交：

| 事实 | 表达方式 | 判定 |
|---|---|---|
| 已归档 | `tasks.archivedAt`（INT NULL） | `archivedAt IS NOT NULL` |
| 已删除 | `tasks.deletedAt`（INT NULL，墓碑） | `deletedAt IS NOT NULL` |

**为什么归档不放进 `TaskStatus`**（此处修正了初版设计）：

重复任务的 `status` 恒为 `pending`（§3），若归档是一个 status 值，则**重复任务永远无法被归档**，
「是否已归档」对重复/非重复任务就成了两套判定逻辑，所有视图的过滤条件都要分叉。
用 `archivedAt IS NOT NULL` 表达后，两类任务的判定完全一致，且与 `deletedAt` 同构。

归档时把当时的 `status` 快照到 `tasks.statusBeforeArchive`，取消归档时还原（见[数据模型 §3.1](data-model.md#31-tasks)）。

**统一的可见性判定**（所有视图、所有查询共用，实现为一个谓词函数，不各自手写）：

```
活跃      : deletedAt IS NULL AND archivedAt IS NULL
归档列表  : deletedAt IS NULL AND archivedAt IS NOT NULL
回收站    : deletedAt IS NOT NULL
```

## 2. 状态机

```
                    ┌──────────────────────────────┐
                    │                              │ 取消完成
                    ▼                              │
              ┌──────────┐   开始    ┌────────────┐ │
    ────────► │ pending  │ ────────► │ inProgress │ │
     创建     └────┬─────┘           └──────┬─────┘ │
                  │  │                     │       │
           完成    │  │ 跳过         完成    │       │
                  │  │                     │       │
                  ▼  ▼                     ▼       │
             ┌─────────┐             ┌─────────┐   │
             │ skipped │             │  done   │───┘
             └─────────┘             └─────────┘

  归档 / 取消归档是与上图**正交**的一维：
    archivedAt = null  ⇄  archivedAt = now
  归档时快照 status 到 statusBeforeArchive；取消归档时还原，status 本身不变。
```

### 2.1 合法迁移表

| 从 \ 到 | pending | inProgress | done | skipped |
|---|---|---|---|---|
| **pending** | — | ✅ | ✅ | ✅ |
| **inProgress** | ✅ | — | ✅ | ✅ |
| **done** | ✅ | ✅ | — | ❌ |
| **skipped** | ✅ | ❌ | ❌ | — |

❌ = 抛 `IllegalTransitionException`（**显式抛出，不是 assert**）。

> `done → skipped` 被禁止是刻意的：已完成的事再标「跳过」没有语义，多半是误操作。UI 应先取消完成。

### 2.2 归档维度的规则

| 操作 | 规则 |
|---|---|
| 归档 | 任何 `status` 下都允许；`statusBeforeArchive = status`，`archivedAt = now` |
| 取消归档 | `status = statusBeforeArchive ?? pending`，`archivedAt = null`，`statusBeforeArchive = null` |
| 归档态下改 status | **禁止**（抛异常）。要改先取消归档 —— 否则 `statusBeforeArchive` 会与现实脱节 |
| 归档重复任务 | 允许，且与非重复任务走**完全相同**的路径（这正是把归档移出枚举的收益） |

## 3. 重复任务的特殊规则

**硬约束**：重复任务（`recurrenceRule != null`）的 `tasks.status` **恒为 `pending`**。

| 操作 | 落在哪 |
|---|---|
| 完成「今天这次」 | `occurrence_overrides` 新增/更新一行，`status = done` |
| 跳过「今天这次」 | `occurrence_overrides`，`action = skip` |
| 归档整个重复任务 | `tasks.archivedAt` 置值（与非重复任务同路径） |

### 3.1 不变量必须显式抛出，不用 `assert`

```dart
// ✅ 正确：release 包里同样生效
void checkTaskInvariants(Task task) {
  if (task.recurrenceRule != null && task.status != TaskStatus.pending) {
    throw DomainInvariantViolation(
      'recurring task ${task.id} must keep status=pending; '
      'per-occurrence status lives in occurrence_overrides',
    );
  }
}
```

```dart
// ❌ 错误：Dart 的 assert 只在 debug/JIT 下执行，
//        AOT release 构建会把整条语句移除 —— 正式包里零保护。
assert(task.recurrenceRule == null || task.status == TaskStatus.pending);
```

**这不是风格问题**：用 `assert` 表达的不变量，会让对应测试在 debug 下变绿、在 release 下失去意义 ——
按[测试策略 §1](../05-engineering/testing-strategy.md) 的标准，那是一条「测不出真实缺陷的测试」。
通则写在[横切关注点 §3.1](../01-architecture/cross-cutting.md)，并列入[评审要点](../05-engineering/conventions.md#9-评审要点按重要性排序)。

理由见[数据模型 §4.3](data-model.md#43-为什么重复任务的-tasksstatus-恒为-pending)。

## 4. 阶段事项的状态推导

父任务状态**不是**独立存储的自由值，而是由阶段状态推导出来的投影：

| 阶段情况 | 推导出的父任务状态 |
|---|---|
| 全部 `pending` | `pending` |
| 部分完成 | `inProgress` |
| 全部 `done` 或 `skipped`（至少一个 `done`） | `done` |
| 全部 `skipped` | `skipped` |

### 4.1 配置项 `behavior.autoStartOnFirstStage` 的作用范围（此处消除了与配置规格的冲突）

该配置**只控制「部分完成 → `inProgress`」这一条**，不影响其余推导：

| 配置值 | 部分完成时的父任务状态 |
|---|---|
| `true`（默认） | `inProgress` |
| `false` | 保持 `pending`（父任务不因子阶段自动「开始」） |

其余三行推导**无条件生效**，不受该配置影响。
UI 无论配置如何都显示阶段进度（`2/5`），所以关掉它不会丢失信息，只是父任务不自动变色。

> 初版把 §4 写成「无条件推导」而[配置规格](../03-design/settings-spec.md)又提供了开关，两处矛盾。
> 此处以「配置只管这一行」收口，并加测试 L-10/L-11 锁住两种取值。

### 4.2 父任务与阶段**双向同步，两个方向都可逆**

| 用户的动作 | 跟着发生的事 |
|---|---|
| 把父任务标 `done` | 所有 `pending` / `inProgress` 的阶段一并标 `done` |
| 取消父任务完成 | 所有 `done` 的阶段一并回 `pending` |
| 勾/取消某个阶段 | 父任务状态按 §4 的表重新投影 —— **全部勾完才是 `done`** |

`skipped` 的阶段**两个方向都不动**：「跳过」是用户对那一步的判断，
盖成 `done` 是替他改结论；而「全部 settled 且至少一个 `done`」推出来照样是 `done`，
所以放着不动不会让父子状态对不上。

重复任务走的是同一套规则，只是状态落在另外两张表：
父任务那一半写 `occurrence_overrides`，阶段那一半写 `stage_occurrence_states`
（`tasks.status` 与 `Stage.status` 对重复任务恒为 `pending`，见 §4.3 与
[数据模型 §4.3](data-model.md#43-为什么重复任务的-tasksstatus-恒为-pending)）。

#### 这一条原本是相反的，理由不成立

初版写的是「取消父任务完成时**不**回滚阶段」，理由是
「破坏用户已记录的阶段进度比留下不一致更糟」，并注明「这条不对称是刻意的」。

那个理由**站不住**。走到「取消完成」这一步时父任务是 `done`，而 `done` 只有两种来法：

- 阶段全部 settled 推导出来的 —— 那时没有「进度」可破坏，全都做完了；
- 用户直接标完成、级联盖上去的 —— **那份进度在标完成的那一下就已经被盖掉了**。

所以旧规则保住的是级联自己写下的值，不是用户记的。
真正需要保护的是**「勾了一半 → 标完成 → 反悔」**这一串，
而那由撤销负责：撤销还原的是**阶段快照**，不是发一条反向的状态命令
（反向命令走同一套级联，会把本来就勾着的那一步一起清掉，进度从 1/2 变成 0/2）。

> 规则翻过来了，锁它的测试（L-05 / L-06）**改写而不是删掉** ——
> 删掉的话，将来谁把它改回不对称，没有任何东西会红。

#### 投影不查迁移表

由阶段推出来的状态**不经过 §2.1 的合法迁移表**。迁移表约束的是「用户能直接按哪一下」：
`done → skipped` 被禁掉，是因为直接按出这一步多半是误操作。
但把最后一个 `done` 的阶段改成「跳过」之后，父任务除了 `skipped` 没有别的值可取 ——
那时抛异常，用户看到的是「这个阶段改不动」：一条给误操作准备的护栏，挡住了一次完全正当的操作。

三种情况不投影，父任务保持原状态：**没有阶段**（推导给不出值）、
**重复任务**（`status` 恒为 `pending`）、**已归档**（状态冻结，见 §2.2 ——
跟着阶段改会把「取消归档还原成什么」悄悄改掉）。

## 5. 完成时间的记录

- `completedAt` 记录**实际点击完成的瞬时**（Instant，UTC ms），不是计划时间。
- 取消完成时 `completedAt` 置 NULL。
- 用于将来的统计与「按完成时间排序」。

## 6. 删除与回收站

```
删除 ──► deletedAt = now  （墓碑，仍在库中）
           │
           ├── 30 天内：回收站可见，可恢复（deletedAt = NULL）
           │
           └── 超过 30 天且已同步（V1 恒视为已同步）：物理删除
```

- 保留期是配置项 `data.trashRetentionDays`，默认 30。
- 删除父任务时，子实体（阶段、清单项、提醒、例外）**一并打墓碑**，不物理级联删除 —— 否则恢复时子数据丢失。
- 物理清理由启动时的一次后台任务执行（实现见 `features/trash/application/trash_purge.dart`）。
  它是**尽力而为**的：失败只记一笔，不拦启动 —— 清理没跑成的后果是多留几天，
  而为它拦住启动的后果是应用打不开。
- **剩余时间与清理判据同源**（`timeUntilPurge`）。界面上的「还剩几天」
  若自己拿天数差算一遍，会与判据分叉：删除 29 天 20 小时时它算出「还剩 1 天」，
  而清理判的是「差值 > 30 天」—— 当晚一过就真清了。
- 仓库一侧另有一道硬约束：`purgeDeleted` 的 SQL 带 `deleted_at IS NOT NULL`。
  调用方算错了，最坏是清早了，抹不掉活数据。

## 7. 必测用例

| # | 用例 | 期望 |
|---|---|---|
| L-01 | 每一对非法迁移（`done→skipped`、`skipped→inProgress`、`skipped→done`） | 抛 `IllegalTransitionException`，状态不变 |
| L-02 | 归档 `inProgress` 的任务 → 取消归档 | 回到 `inProgress`，而非一律回 `pending` |
| L-03 | 重复任务尝试把 `tasks.status` 设为 `done` | 抛 `DomainInvariantViolation` |
| L-03b | **同上，在 release 语义下（不依赖 assert）** | 仍然抛出 —— 用一个不含 assert 的纯函数调用路径验证 |
| L-04 | 阶段全部完成 | 父任务推导为 `done` |
| L-05 | 父任务标完成 | 所有阶段变 `done` |
| L-06 | 父任务取消完成 | 阶段状态**保持不变** |
| L-07 | 删除父任务 | 所有子实体打墓碑，无一物理删除 |
| L-08 | 恢复已删任务 | 子实体一并恢复 |
| L-09 | 超期清理 | 只清理超过保留期的，边界日不清 |
| L-10 | `autoStartOnFirstStage=true`，5 阶段完成 2 个 | 父任务 `inProgress` |
| L-11 | `autoStartOnFirstStage=false`，同上 | 父任务保持 `pending`，且阶段进度仍显示 2/5 |
| L-12 | **归档一个重复任务** | 成功；`archivedAt` 非空且 `status` 仍为 `pending`（不变量不被破坏） |
| L-13 | 归档态下尝试改 `status` | 抛异常 |
| L-14 | 活跃/归档/回收站三个谓词 | 对同一批任务分类互斥且完备（无任务落在两类或零类中） |

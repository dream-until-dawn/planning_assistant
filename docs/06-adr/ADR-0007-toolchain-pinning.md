# ADR-0007：工具链版本固定与镜像策略

**状态**：✅ 已采纳 · 2026-09-07

## 背景

M0 探针过程中，构建连续失败四次，原因分别是：Maven Central 403、compileSdk 不足、
缺 core library desugaring、项目路径含非 ASCII 字符。其中 **Maven Central 403 报出的是
`Cannot invoke "java.util.List.get(int)" because "path" is null`** —— 完全看不出是网络问题。

同时依赖解析也踩了两次坑（`custom_lint` 与 `riverpod_lint` 冲突、`freezed 3.x` 与
`riverpod_generator 4.0.9` 的 analyzer 版本冲突）。

## 决策

1. **`pubspec.lock` 入库**。应用不是库，必须可复现构建。
2. **Gradle 仓库配置阿里云镜像在前、官方源在后**，写进仓库而不是靠开发者本地配置。
3. **不显式声明 `custom_lint`**，由 `riverpod_lint` 自行管理其插件依赖。
4. **`freezed` 锁 `^4.0.1`**（`3.x` 与 `riverpod_generator 4.0.9` 的 analyzer 约束冲突）。
5. **依赖升级单独开 PR**，必须附 `flutter pub outdated` 输出 + 全量测试 + **模拟器实跑一次**。
6. **所有构建相关的环境坑写进[环境探针结论](../05-engineering/environment-notes.md)**，
   而不是留在某个人的记忆里。

## 后果

**收益**

- 新环境（新机器、CI）能一次构建成功，不用重新踩一遍四个坑。
- 报错误导性极强的问题（§背景）有明确的排查线索。
- 依赖冲突的解法有据可查，不会下次又花时间二分定位。

**代价**

- 镜像地址写进仓库，对不在该网络环境的开发者是冗余的 ——
  但因为官方源保留在后作为兜底，不会造成失败，只是多一次探测。
- `pubspec.lock` 入库会带来偶尔的合并冲突。

## 被否决的方案

| 方案 | 为什么不选 |
|---|---|
| 镜像配在开发者本地 `~/.gradle/init.gradle` | 换机器、换人、CI 都要重新配，且新人第一次构建必然失败并看到误导性报错 |
| 不锁 `pubspec.lock` | 「今天能构建、明天不能」，且难以复现用户报告的问题 |
| 依赖随功能 PR 一起升 | 出问题时无法区分是功能改坏了还是依赖升坏了 |
| 只做「编译通过」验证 | 已经证明不够：编译通过的探针在运行时因 API 变更而失败过 |

## 第 5 条的由来

M0 期间发生过：APK 构建成功，但装到模拟器上什么都没输出 ——
原因是 `flutter_local_notifications` 22.x 把 `initialize` 改成了具名参数，
而那次构建实际上失败了、装的是旧包。**「编译通过」与「能跑」是两件事。**

## 什么情况下该推翻

- 网络环境变化，Maven Central 可直连 —— 那时镜像仍可保留（只是不再被命中），无需改动。
- `custom_lint` 与 `riverpod_lint` 的冲突在上游修复后，第 3 条可放宽。
- `freezed` 与 `riverpod_generator` 的 analyzer 约束对齐后，第 4 条可放宽。

> 每次 Flutter 大版本升级时重新走一遍[环境探针结论 §6 的 M0 检查表](../05-engineering/environment-notes.md)。

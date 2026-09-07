# 探针产物（可复现性附件）

> 这些**不是应用代码**，不参与构建、不参与 CI 的测试统计。
> 它们是[环境探针结论](../environment-notes.md)与[技术栈矩阵](../../01-architecture/tech-stack.md)的**可复现依据**。

## 为什么要入库

[工程规范 §1.1](../conventions.md) 规定「探针代码不入库」，本目录**不违反**该规定：

- 入库的是**结论的可验证依据**（`pubspec.lock`、最小复现脚本、实测输出），不是探针工程本身；
- 完整的探针工程（含 2.3GB 构建产物）已按规矩删除；
- 没有它们，`tech-stack.md` 里的 29 个版本号会退化成**无法查证的断言** ——
  一旦本机 pub cache 被清理，任何人（包括未来的我们）都无从复核。

这与 [ADR-0007](../../06-adr/ADR-0007-toolchain-pinning.md) 第 1 条「`pubspec.lock` 入库以保证可复现」是同一个理由。

## 内容

### `dependency-matrix/`

产出[技术栈与版本矩阵](../../01-architecture/tech-stack.md) §2/§3 全部版本号的依赖解析。

| 文件 | 说明 |
|---|---|
| `pubspec.yaml` | 完整依赖集（与 V1 计划一致） |
| `pubspec.lock` | 解析结果，**版本矩阵的唯一依据** |

**复现**（需 Flutter 3.47.0 / Dart 3.13.0）：

```bash
cp -r docs/05-engineering/probe-artifacts/dependency-matrix /tmp/dm && cd /tmp/dm
flutter pub get      # 注意：目录不能位于 PUB_CACHE 之下，见 environment-notes §3.6
```

> 该目录**刻意不含** `sqlite3_flutter_libs`（已 EOL）与 `custom_lint`（与 riverpod_lint 冲突）——
> 两者都是文档中的结论，此处即为其证据：不声明它们，解析成功。

### `rrule/`

产出[重复引擎 §2.2/§2.3](../../02-domain/recurrence-engine.md) 与[环境探针结论 §2.3/§2.4](../environment-notes.md) 的实测依据。

| 文件 | 验证什么 |
|---|---|
| `bin/probe.dart` | `UNTIL` 的闭/开区间、是否做时区换算、`toString()` 往返、`COUNT` 对照组 |
| `bin/probe2.dart` | `isTimeUtc: true` 能否修复 `Z` 丢失；无 `Z` 的串解析回什么 |

**复现**（纯 Dart，无需 Flutter/Android）：

```bash
cp -r docs/05-engineering/probe-artifacts/rrule /tmp/rr && cd /tmp/rr
dart pub get && dart run bin/probe.dart && dart run bin/probe2.dart
```

**关键实测输出**（2026-09-07，`rrule 0.2.18`）：

```
--- UNTIL 是闭区间 ---
FREQ=DAILY;UNTIL=20260910T000000Z, start=09-07
  → [09-07, 09-08, 09-09, 09-10]        UNTIL 当刻的实例被包含

--- UNTIL 不做时区换算（朴素比较）---
FREQ=DAILY;UNTIL=20260930T095959Z, start=墙钟 09-28T23:00
  → [09-28T23:00, 09-29T23:00]          09-30T23:00 被丢掉
FREQ=DAILY;UNTIL=20260930T235959Z, 同一 start
  → [09-28T23:00, 09-29T23:00, 09-30T23:00]

--- toString() 丢掉 Z（往返有损）---
输入            : RRULE:FREQ=DAILY;UNTIL=20260930T235959Z
toString()      : RRULE:FREQ=DAILY;UNTIL=20260930T235959     lossless=false
isTimeUtc:true  : RRULE:FREQ=DAILY;UNTIL=20260930T235959Z    lossless=true

--- 无 Z 的串解析回什么 ---
with Z    -> until=2026-09-30 23:59:59.000Z  isUtc=true
without Z -> until=2026-09-30 23:59:59.000Z  isUtc=true
equal rules? true      ← 本地解析等值，所以只做本地往返断言的测试发现不了这个缺陷

--- COUNT 对照组（与时区无关）---
FREQ=DAILY;COUNT=3 → 三个实例，不受 UNTIL 问题影响
```

> 最后两条合起来解释了为什么这个缺陷会漏过去：
> **编码端有错，解码端宽容，本地往返测试恒绿。**
> 因此[测试策略 §1.2](../testing-strategy.md) 要求往返测试必须断言**字节等价**而不只是语义等价。

## 维护规矩

- 依赖版本变更时，**同一个 PR** 里重新生成 `dependency-matrix/pubspec.lock` 并更新版本矩阵。
- 探针脚本发现新结论时，把输出追加到本文件，并同步更新对应的设计文档。
- 本目录下的 `.dart` 文件不计入测试覆盖率，也不受应用的 lint 规则约束。

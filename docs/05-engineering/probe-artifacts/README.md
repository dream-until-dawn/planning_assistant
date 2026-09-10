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
| `bin/until_timezone.dart` | **同一用户意图**在 UTC+14 / UTC-4 / UTC+0 下，「RFC 真 UTC 的 UNTIL」与「墙钟 UNTIL」展开结果是否一致（§2.2 的判据）；以及 R-05 期望值对 DTSTART 时刻的依赖 |
| `bin/canonical_form.dart` | 多部件规则下的 **C1 合规 / C2 语义往返 / C3 规范形幂等**，以及为什么字节等价是错误的断言 |

**复现**（纯 Dart，无需 Flutter/Android）：

```bash
cp -r docs/05-engineering/probe-artifacts/rrule /tmp/rr && cd /tmp/rr
dart pub get
for f in probe probe2 until_timezone canonical_form; do dart run bin/$f.dart; done
```

> `until_timezone.dart` 的**场景 3（UTC+0 对照组）**是这组探针里最该看的一条：
> 偏移为 0 时两种写法必然重合，所以**任何只在单一时区（尤其是本机时区）下跑的探针都不可能暴露该缺陷**。
> 这不是探针写得不够细，是缺陷的形状决定的 —— 时间相关的验证必须参数化时区。

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

--- 同一用户意图「重复到 09-30 当天为止」在不同时区（until_timezone.dart）---
Pacific/Kiritimati UTC+14, 每天 23:00
  (A) RFC 真 UTC UNTIL 20260930T095959Z → 5 次, 末次 09-29T23:00   ⚠ 少一次
  (B) 墙钟   UNTIL   20260930T235959Z → 6 次, 末次 09-30T23:00
America/New_York UTC-4, 每天 01:00
  (A) RFC 真 UTC UNTIL 20261001T035959Z → 7 次, 末次 10-01T01:00   ⚠ 多一次
  (B) 墙钟   UNTIL   20260930T235959Z → 6 次, 末次 09-30T01:00
UTC+0 对照组 → 两种写法结果一致

--- 「到某日止」的日终语义 ---
UNTIL=20260910T000000Z, DTSTART 07:00 → 3 次, 末次 09-09   ← 9/10 静默丢失
UNTIL=20260910T000000Z, DTSTART 00:00 → 4 次, 末次 09-10

--- 规范形性质（canonical_form.dart，6 个样本）---
C1 合规(UNTIL 带 Z)  失败 0/6
C2 语义往返          失败 0/6
C3 规范形幂等        失败 0/6
字节等价于原输入串   失败 4/6   ← 部件被重排，但无害：RFC 部件无序
```

> 最后两条合起来解释了为什么这个缺陷会漏过去：
> **编码端有错，解码端宽容，本地往返测试恒绿。**
> 因此[测试策略 §1.2](../testing-strategy.md) 要求往返测试必须断言**字节等价**而不只是语义等价。

### `freezed-constraints/`

产出[技术栈 §6.1](../../01-architecture/tech-stack.md#61-freezed-为什么必须是-4x完整论证)「为什么必须用 freezed 4.x」的完整依据。

| 文件 | 说明 |
|---|---|
| `enumerate.py` | 拉 pub.dev 原始 JSON，枚举某个包**全部版本**的某项依赖约束，并单独列出「未声明该依赖」的例外项 |

**复现**（只需 Python 3，无需 Dart）：

```bash
python docs/05-engineering/probe-artifacts/freezed-constraints/enumerate.py freezed analyzer 13
```

**为什么值得单独留一个脚本**：这条结论是**全称**的（「每个 3.x 版本都不允许 analyzer ≥ 13」），
而全称结论只能由完整枚举支撑。本项目在这条上连续错了三轮 ——
先是双方各自从单个版本外推，再是一次概括式抓取给出与磁盘文件矛盾的答案，
最后全量枚举才发现还有个不声明 analyzer 的预发布版。经过写进
[测试策略 §1.3](../testing-strategy.md)。

> 该包的 analyzer 约束在 3.x 内部**非单调**（3.2.1/3.2.2 已是 `^8.0.0`，3.2.3 又退回 `<9.0.0`），
> 所以「按手头那个版本推断整个 3.x」在它身上注定失败，不是运气问题。

### `alarm-limit/`（无独立目录，探针在 `integration_test/`）

产出[通知设计 §11](../../04-platform/notifications.md) 那次测量的依据。

**探针本体**：`integration_test/alarm_limit_probe_test.dart`。它**不能**做成
本目录下的独立 Dart 工程 —— 要真的排闹钟就得有 Android 应用与插件在场，
所以它以 integration test 的形式留在仓库里（CI 不跑它）。

**复现**：

```bash
flutter test integration_test/alarm_limit_probe_test.dart -d <device>
# 测试会在末尾停 45 秒，趁这段时间从进程外数：
adb shell dumpsys alarm | grep -c "Alarm{.*com.dreamuntildawn.planning_assistant"
```

**实测输出**（2026-09-09，雷电模拟器 **Android 9 / API 28**）：

```
PROBE canScheduleExact=true requested=600 pluginPending=600
dumpsys: Alarm{ 行 600 / operation 行 600 / tag 行 600     ← 系统实收 600，无拐点
```

**这次测量最重要的产出不是那个数，是两条方法学结论**：

1. **`pendingNotificationRequests()` 量不了这件事。** 它读的是插件自己写在
   SharedPreferences 里的 JSON（`FlutterLocalNotificationsPlugin.java:1617 → :536`），
   不问 AlarmManager —— 回读永远等于排进去的条数。规格里原本就是这么写的，
   照着做会得到一个**不可能失败的探针**。真实状态只能从进程外看。
2. **API 28 上量到的数说明不了 API 31+ 的事。** `SCHEDULE_EXACT_ALARM`
   与 `POST_NOTIFICATIONS` 的版本门分别在 API 31 / 33，低于它们两个权限查询
   恒为 true。这台机器上「600 条全收」是在所有现代约束都不生效的前提下量的。
   → 与 `rrule/` 那条「只在单一时区跑的探针不可能暴露该缺陷」同型：
   **探针的适用范围由它跑在什么上面决定，不由它测了多少条决定。**

> ⚠️ **别用 `flutter test integration_test/` 去测存着真实数据的设备。**
> 它跑完会卸载应用，连带清掉应用数据。第一次就是这么把模拟器上的演示数据
> 弄没的，而且事后 dumpsys 数到 0 会看起来像「系统一条都没接受」——
> 实际上说明的只是「应用已经不在了」。设备探针要么用空 AVD，
> 要么走 `flutter install` + 应用内入口。

## 维护规矩

- 依赖版本变更时，**同一个 PR** 里重新生成 `dependency-matrix/pubspec.lock` 并更新版本矩阵。
- 探针脚本发现新结论时，把输出追加到本文件，并同步更新对应的设计文档。
- 本目录下的 `.dart` 文件不计入测试覆盖率，也不受应用的 lint 规则约束。

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""按目录检查覆盖率门槛（testing-strategy §3.3）。

## 为什么按目录分别设阈值，而不是一个全局数字

全局阈值会被稀释：领域层写得再好，只要生成代码或 UI 骨架占了足够行数，
总数就能达标，而**最需要被覆盖的那一层反而可以很差**。
按目录分设阈值后，每一层各自达标，稀释不了。

## 排除生成产物

`*.g.dart` / `*.freezed.dart` 是生成的，覆盖它们既没有信息量，也会稀释分母。

## --self-test

与本仓库其余工具同一规矩：先用**已知的**覆盖率数据证明它能正确判红判绿，
再去看真实数据。一个永远返回「达标」的门禁比没有门禁更糟。

退出码：0 达标 / 1 未达标 / 2 用法或环境问题。
"""

from __future__ import annotations

import argparse
import sys
from collections import defaultdict
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

REPO_ROOT = Path(__file__).resolve().parent.parent

# 目录前缀 → 最低行覆盖率（百分比）。见 testing-strategy §3.3。
THRESHOLDS: list[tuple[str, float]] = [
    ("lib/domain/", 90.0),
    ("lib/data/", 80.0),
    ("lib/core/", 90.0),
    # platform/ 是接口 + 薄适配层，逻辑少但每一处都在真机路径上。
    # 门槛比领域层低一档：MethodChannel 的失败分支要真机才能触发，
    # 定成 90% 会逼人写「为覆盖而覆盖」的假测试。
    ("lib/platform/", 80.0),
]

GENERATED_SUFFIXES = (".g.dart", ".freezed.dart")

# 只被代码生成器读取、运行时从不执行的文件。
#
# Drift 的表定义（`TextColumn get id => text()();` 这类）是 **codegen 的输入**：
# 生成出的 `$TasksTable extends Tasks` 自己声明了全部 149 个
# `late final GeneratedColumn` 字段，把基类的 getter 全覆盖掉了。
# 实测 399 条测试重度使用数据库，这些行的命中数仍是 0 —— 不是没测到，
# 是它们本就不执行。
#
# 与 `.g.dart` 同类：把它们计入分母，只会用「永远不可能覆盖的行」
# 稀释真正该被覆盖的那部分。
#
# **这个清单必须短，且每条都要能说清「为什么运行时不执行」。**
# 拿它当「这块不好测」的垃圾桶，覆盖率门禁就废了。
CODEGEN_INPUT_PREFIXES = ("lib/data/database/tables/",)


def parse_lcov(text: str) -> dict[str, tuple[int, int]]:
    """返回 {文件路径: (已覆盖行数, 总行数)}。"""
    result: dict[str, tuple[int, int]] = {}
    current: str | None = None
    hit = total = 0
    for line in text.splitlines():
        if line.startswith("SF:"):
            current = line[3:].strip().replace("\\", "/")
            hit = total = 0
        elif line.startswith("DA:"):
            _, _, payload = line.partition(":")
            _, _, count = payload.partition(",")
            total += 1
            if int(count) > 0:
                hit += 1
        elif line.strip() == "end_of_record" and current is not None:
            result[current] = (hit, total)
            current = None
    return result


def summarize(
    files: dict[str, tuple[int, int]],
) -> tuple[dict[str, tuple[int, int]], list[str]]:
    """按阈值前缀汇总，并列出未被任何前缀覆盖的文件。"""
    buckets: dict[str, list[int]] = defaultdict(lambda: [0, 0])
    unmatched: list[str] = []

    for path, (hit, total) in files.items():
        if path.endswith(GENERATED_SUFFIXES):
            continue
        if path.startswith(CODEGEN_INPUT_PREFIXES):
            continue
        for prefix, _ in THRESHOLDS:
            if path.startswith(prefix):
                buckets[prefix][0] += hit
                buckets[prefix][1] += total
                break
        else:
            unmatched.append(path)

    return {k: (v[0], v[1]) for k, v in buckets.items()}, sorted(unmatched)


def report(files: dict[str, tuple[int, int]], *, quiet: bool = False) -> bool:
    buckets, unmatched = summarize(files)
    ok = True

    for prefix, threshold in THRESHOLDS:
        hit, total = buckets.get(prefix, (0, 0))
        if total == 0:
            if not quiet:
                print("  {:<16} 没有可统计的行 —— 该层是空的？".format(prefix))
            continue
        pct = hit * 100.0 / total
        passed = pct >= threshold
        ok = ok and passed
        if not quiet:
            print("  {:<16} {:6.2f}%  ({}/{})  门槛 {:.0f}%  {}".format(
                prefix, pct, hit, total, threshold,
                "达标" if passed else "**未达标**"))

    if unmatched and not quiet:
        # 不报错但要说出来：新增的顶层目录没设阈值时，它是完全没人管的。
        print("  未被任何阈值覆盖的文件（{} 个），如属新层请补阈值：".format(
            len(unmatched)))
        for path in unmatched[:10]:
            print("    - {}".format(path))

    return ok


def _self_test() -> bool:
    """用构造的数据证明门禁能正确判红判绿。期望写死在这里。"""
    cases: list[tuple[str, dict[str, tuple[int, int]], bool]] = [
        ("全部达标", {
            "lib/domain/a.dart": (95, 100),
            "lib/data/b.dart": (85, 100),
            "lib/core/c.dart": (90, 100),
        }, True),
        ("领域层差 1 个百分点", {
            "lib/domain/a.dart": (89, 100),
            "lib/data/b.dart": (85, 100),
            "lib/core/c.dart": (90, 100),
        }, False),
        ("数据层差一点", {
            "lib/domain/a.dart": (95, 100),
            "lib/data/b.dart": (79, 100),
            "lib/core/c.dart": (90, 100),
        }, False),
        ("恰好等于门槛应算达标", {
            "lib/domain/a.dart": (90, 100),
            "lib/data/b.dart": (80, 100),
            "lib/core/c.dart": (90, 100),
        }, True),
        ("生成产物不参与统计（否则会稀释分母）", {
            "lib/domain/a.dart": (95, 100),
            "lib/domain/a.g.dart": (0, 5000),
            "lib/data/b.dart": (85, 100),
            "lib/core/c.dart": (90, 100),
        }, True),
        ("codegen 输入（Drift 表定义）不参与统计", {
            "lib/domain/a.dart": (95, 100),
            "lib/data/b.dart": (85, 100),
            "lib/data/database/tables/task_tables.dart": (0, 500),
            "lib/core/c.dart": (90, 100),
        }, True),
        ("但普通的 data/ 文件仍然算 —— 排除清单不能越界", {
            "lib/domain/a.dart": (95, 100),
            "lib/data/b.dart": (0, 500),
            "lib/core/c.dart": (90, 100),
        }, False),
        ("同层多文件按行数加权，不是按文件平均", {
            # 900/1000 = 90%，达标；若按文件平均则是 (100+80)/2 = 90% 也达标，
            # 所以再加一个极端样本区分两种算法。
            "lib/domain/big.dart": (900, 1000),
            "lib/domain/tiny.dart": (0, 1),
            "lib/data/b.dart": (85, 100),
            "lib/core/c.dart": (90, 100),
        }, False),  # 900/1001 = 89.9% → 未达标（按文件平均会是 50%，也不达标）
    ]

    ok = True
    for name, files, expected in cases:
        actual = report(files, quiet=True)
        if actual != expected:
            ok = False
            print("  [自测失败] {}：期望 {}，实际 {}".format(
                name, "达标" if expected else "未达标",
                "达标" if actual else "未达标"))

    print("自测：{} 个已知样本，结果 {}".format(len(cases), "PASS" if ok else "FAIL"))
    return ok


def main() -> int:
    parser = argparse.ArgumentParser(description="按目录检查覆盖率门槛")
    parser.add_argument("lcov", nargs="?", type=Path,
                        default=REPO_ROOT / "coverage" / "lcov.info")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test and not _self_test():
        return 1

    if not args.lcov.exists():
        sys.stderr.write(
            "找不到 {}。请先运行：flutter test --coverage\n".format(args.lcov))
        return 2

    files = parse_lcov(args.lcov.read_text(encoding="utf-8"))
    if not files:
        sys.stderr.write("lcov 文件里没有任何记录 —— 覆盖率采集失败了？\n")
        return 2

    print("覆盖率（{} 个文件）：".format(len(files)))
    ok = report(files)
    if not ok:
        print("\n未达到 testing-strategy §3.3 的门槛。")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

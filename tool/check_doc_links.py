#!/usr/bin/env python3
"""校验 docs/ 下所有 Markdown 的站内链接与锚点。

设计原则见 docs/05-engineering/testing-strategy.md §1.4：
**校验工具本身必须先被证明能正确失败**，否则它报的绿和红都不可信。
因此本脚本自带 --self-test：用已知含坏链的临时样本喂给自己，
断言「恰好检出这些、且不多报」，通不过就直接退出非零。

用法:
    python tool/check_doc_links.py              # 校验仓库
    python tool/check_doc_links.py --self-test  # 先自检，再校验仓库（CI 用这个）
"""

from __future__ import annotations

import os
import re
import sys
import tempfile
import urllib.parse

LINK_RE = re.compile(r"\[([^\]]*)\]\(([^)]+)\)")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.+)$", re.M)


def slugify(heading: str) -> str:
    """GitHub 风格锚点。

    注意：不能用「码位大于某个阈值就保留」这类判据——那会把全角括号（）、
    破折号等 CJK 标点当作文字保留下来，导致大量假失败。
    这里显式地只保留字母数字（汉字属字母）、空格与连字符。
    """
    s = heading.strip().lower()
    s = re.sub(r"[`*_\[\]()]", "", s)
    s = "".join(ch for ch in s if ch.isalnum() or ch in " -")
    return re.sub(r"\s+", "-", s.strip())


# 带字母后缀的小节（`6.1b` / `2.1g`）必须整体捕获。
# 不带 `[a-z]?` 的话，`### 6.1b` 会回溯成 `6` —— 于是同一文件里的
# `6.1b/6.1c/6.1d` 全塌成 `6`，报出一堆假重号。
# 这个 bug 是新检查上线时自己报出来的：它在 recurrence-engine 与
# m0-record 上各报了一处「重复」，一查全是自己的回溯问题。
# **校验器的报告同样要先验证再采信**，与对待兄弟会话的结论同一条规矩。
SECTION_NUM_RE = re.compile(r"^#{2,6}\s+(\d+(?:\.\d+)*[a-z]?)[.、\s]", re.M)


def check_duplicate_section_numbers(
    files: list[str],
) -> list[tuple[str, str, str]]:
    """同一文件内的 `§X.Y` 编号不得重复。

    ## 为什么这条比「锚点可达」更接近我们实际依赖的性质

    锚点可达只保证「点了能跳」。但本项目的 prose 与测试名普遍用
    **「§X.Y」当寻址方式**（`对应 recurrence-engine §6`、`见 cross-cutting §3.1`），
    而人是**按编号去翻**的，不是按锚点跳的。编号唯一是这套寻址的前提。

    实际踩到过：`design-system.md` 一度有两个 `### 3.1`
    （字体打包 / 缩放相乘）。两个标题文字不同 → slug 不同 → 锚点都能解析
    → **252 条链接全绿**。而另外两份文档的链接文案写的是「设计系统 §3.1」，
    读者按编号翻，一半概率落到错的那节。

    「全绿且没用」正是这个项目反复在抓的形状 —— 校验器验的是它能验的，
    不是我们依赖的。
    """
    problems: list[tuple[str, str, str]] = []
    for f in files:
        text = open(f, encoding="utf-8").read()
        seen: dict[str, int] = {}
        for m in SECTION_NUM_RE.finditer(text):
            num = m.group(1)
            seen[num] = seen.get(num, 0) + 1
        for num, count in sorted(seen.items()):
            if count > 1:
                problems.append((f, f"§{num} 出现 {count} 次", "DUPLICATE_SECTION_NUM"))
    return problems


def collect_markdown(root: str) -> list[str]:
    out: list[str] = []
    for dirpath, _dirnames, filenames in os.walk(root):
        for fn in filenames:
            if fn.endswith(".md"):
                out.append(os.path.join(dirpath, fn).replace("\\", "/"))
    return sorted(out)


def check(files: list[str]) -> tuple[list[tuple[str, str, str]], int, int]:
    """返回 (问题列表, 链接总数, 锚点总数)。"""
    headings: dict[str, set[str]] = {}
    for f in files:
        text = open(f, encoding="utf-8").read()
        headings[f] = {slugify(m.group(2)) for m in HEADING_RE.finditer(text)}

    problems: list[tuple[str, str, str]] = []
    total = anchors = 0
    for f in files:
        text = open(f, encoding="utf-8").read()
        for m in LINK_RE.finditer(text):
            link = m.group(2).strip()
            if link.startswith(("http://", "https://", "mailto:", "#!")):
                continue
            total += 1
            path, _, frag = link.partition("#")
            path = urllib.parse.unquote(path)
            target = (
                f
                if path == ""
                else os.path.normpath(
                    os.path.join(os.path.dirname(f), path)
                ).replace("\\", "/")
            )
            if not os.path.exists(target):
                problems.append((f, link, "FILE_NOT_FOUND"))
                continue
            if frag and target.endswith(".md"):
                anchors += 1
                if frag not in headings.get(target, set()):
                    problems.append((f, link, "ANCHOR_NOT_FOUND"))
    return problems, total, anchors


# 手算的 (标题 -> 锚点) 对照表。
#
# 这些期望值**必须手算**，绝不能由 slugify() 自己产生 —— 否则 slugify 出错时，
# 标题那侧与链接那侧会同向偏移、永远相等，自检对 slug 算法的任何缺陷完全免疫。
# 这正是 docs/05-engineering/testing-strategy.md 1.1 说的「对着实现抄」。
#
# 每一条都另有独立佐证：仓库里存在指向该锚点的真实链接，且当前可达。
# 三条都含全角括号（），因为那是最容易被误当作汉字保留下来的字符。
SLUG_CASES: list[tuple[str, str]] = [
    (
        "2.3 编码 RRULE 必须显式开启 `isTimeUtc`（强制）",
        "23-编码-rrule-必须显式开启-istimeutc强制",
    ),
    (
        "9. 评审要点（按重要性排序）",
        "9-评审要点按重要性排序",
    ),
    (
        "6.1 `freezed` 为什么必须是 4.x（完整论证）",
        "61-freezed-为什么必须是-4x完整论证",
    ),
]


def check_slugify() -> bool:
    """先验证 slug 算法本身，再谈链接匹配。期望值全部来自手算。"""
    ok = True
    for heading, expected in SLUG_CASES:
        actual = slugify(heading)
        if actual != expected:
            ok = False
            print("  slugify 不符手算期望:")
            print(f"      标题 {heading}")
            print(f"      期望 {expected}")
            print(f"      实得 {actual}")
    print(f"  slug 算法: {'PASS' if ok else 'FAIL'}"
          f"（{len(SLUG_CASES)} 条手算样本，均含全角括号）")
    return ok


def self_test() -> bool:
    """证明校验器能失败：喂已知坏输入，断言恰好检出、且不误报好输入。"""
    print("--- 自检：校验器能否正确失败 ---")
    if not check_slugify():
        print("  结果: FAIL —— slug 算法本身有缺陷，其对仓库的一切结论均不可信")
        return False

    good_anchor = SLUG_CASES[0][1]
    with tempfile.TemporaryDirectory() as d:
        a = os.path.join(d, "a.md").replace("\\", "/")
        b = os.path.join(d, "b.md").replace("\\", "/")
        with open(b, "w", encoding="utf-8") as fh:
            fh.write("# B\n\n## 2.3 编码 RRULE 必须显式开启 `isTimeUtc`（强制）\n")
        with open(a, "w", encoding="utf-8") as fh:
            fh.write(
                "# A\n"
                f"[good file](b.md)\n"
                f"[good anchor](b.md#{good_anchor})\n"
                "[bad file](nope.md)\n"
                "[bad anchor](b.md#this-heading-does-not-exist)\n"
                "[external](https://example.com/x.md)\n"
            )
        problems, total, anchors = check([a, b])

        # 编号重复：两个 §3.1 标题文字不同，slug 不同，锚点都能解析 ——
        # 「链接全绿」而编号已经撞了。这一组证明新加的检查能看见它。
        dup = os.path.join(d, "dup.md").replace("\\", "/")
        with open(dup, "w", encoding="utf-8") as fh:
            fh.write(
                "# D\n\n## 3. 字体\n\n### 3.1 字体必须打包\n\n"
                "### 3.2 字族\n\n### 3.1 缩放是两层相乘\n"
            )
        clean = os.path.join(d, "clean.md").replace("\\", "/")
        with open(clean, "w", encoding="utf-8") as fh:
            fh.write(
                "# C\n\n## 3. 字体\n\n### 3.1 字体必须打包\n\n"
                "### 3.2 字族\n\n### 3.3 缩放是两层相乘\n"
            )
        dup_problems = check_duplicate_section_numbers([dup])
        clean_problems = check_duplicate_section_numbers([clean])

    kinds = sorted(k for _f, _l, k in problems)
    expected = ["ANCHOR_NOT_FOUND", "FILE_NOT_FOUND"]
    link_ok = kinds == expected and total == 4 and anchors == 2

    dup_kinds = [k for _f, _l, k in dup_problems]
    dup_ok = dup_kinds == ["DUPLICATE_SECTION_NUM"] and not clean_problems

    ok = link_ok and dup_ok

    print(f"  样本: 2 条好链 + 1 条坏文件 + 1 条坏锚点 + 1 条外链(应跳过)")
    print(f"  检出: {kinds}")
    print(f"  统计: 站内链接={total}(期望4)  带锚点={anchors}(期望2)")
    print(f"  编号重复: 重号样本检出={dup_kinds}  正常样本误报={len(clean_problems)} 处")
    if ok:
        print("  结果: PASS —— 坏链能让它变红，好链不误报，重号能被检出且不误报正常编号")
    else:
        print("  结果: FAIL —— 校验器本身有问题，其对仓库的结论一律不可信")
    return ok


def main() -> int:
    if "--self-test" in sys.argv:
        if not self_test():
            return 2
        print()

    root = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    files = collect_markdown(os.path.join(root, "docs"))
    readme = os.path.join(root, "README.md").replace("\\", "/")
    if os.path.exists(readme):
        files.append(readme)

    problems, total, anchors = check(files)
    problems += check_duplicate_section_numbers(files)
    print(f"文档 {len(files)} 篇 · 站内链接 {total} 条 · 其中带锚点 {anchors} 条")
    if problems:
        print(f"发现 {len(problems)} 处问题：")
        for f, link, kind in problems:
            print(f"  {kind:18s} {f}\n{'':20s}-> {link}")
        return 1
    print("全部可达。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

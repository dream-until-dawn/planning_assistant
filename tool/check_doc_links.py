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


def self_test() -> bool:
    """证明校验器能失败：喂已知坏链，断言恰好检出、且不误报好链。"""
    good_anchor = slugify("2.3 编码 RRULE 必须显式开启 `isTimeUtc`（强制）")
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

    kinds = sorted(k for _f, _l, k in problems)
    expected = ["ANCHOR_NOT_FOUND", "FILE_NOT_FOUND"]
    ok = kinds == expected and total == 4 and anchors == 2

    print("--- 自检：校验器能否正确失败 ---")
    print(f"  样本: 2 条好链 + 1 条坏文件 + 1 条坏锚点 + 1 条外链(应跳过)")
    print(f"  检出: {kinds}")
    print(f"  统计: 站内链接={total}(期望4)  带锚点={anchors}(期望2)")
    if ok:
        print("  结果: PASS —— 坏链能让它变红，好链不误报，全角括号锚点不误报")
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

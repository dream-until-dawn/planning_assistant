#!/usr/bin/env python3
"""枚举 pub.dev 上某个包全部版本的某项依赖约束。

存在的理由：`tech-stack.md` §6.1 对 freezed 3.x 下了一个全称结论。
全称结论必须由完整枚举支撑，而不是由「本机 pub cache 里恰好有的那个版本」支撑
——后者在 freezed 上注定失败，因为它的 analyzer 约束在 3.x 内部是非单调的。

用法:
    python enumerate.py                      # 默认 freezed 的 analyzer 约束
    python enumerate.py <package> <dep>      # 例: python enumerate.py drift sqlite3

注意：必须拉原始 JSON 自己解析。经小模型概括的二手结果不可作为依据
（本项目已踩过：一次概括式抓取给出的 freezed 3.x 约束与磁盘上的 pubspec 直接矛盾）。
"""

import json
import re
import sys
import urllib.request

API = "https://pub.dev/api/packages/{}"


def version_key(v: str):
    core = v.split("-")[0].split("+")[0]
    return ([int(x) for x in core.split(".")], "-" in v, v)


def allows(constraint: str | None, target_major: int) -> bool | None:
    """该约束是否允许 <target_major>.x。None 表示未声明该依赖（即不构成限制）。"""
    if constraint is None:
        return None
    m = re.match(r"^\^(\d+)\.", constraint.strip())
    if m:
        lo = int(m.group(1))
        return lo <= target_major < lo + 1
    ub = re.search(r"<\s*(\d+)\.", constraint)
    lb = re.search(r">=\s*(\d+)\.", constraint)
    hi = int(ub.group(1)) if ub else 10**9
    lo = int(lb.group(1)) if lb else 0
    return lo <= target_major < hi


def main() -> None:
    pkg = sys.argv[1] if len(sys.argv) > 1 else "freezed"
    dep = sys.argv[2] if len(sys.argv) > 2 else "analyzer"
    target = int(sys.argv[3]) if len(sys.argv) > 3 else 13

    with urllib.request.urlopen(API.format(pkg), timeout=60) as r:
        data = json.load(r)

    rows = [
        (v["version"], ((v.get("pubspec") or {}).get("dependencies") or {}).get(dep))
        for v in data["versions"]
    ]
    rows.sort(key=lambda t: version_key(t[0]))

    print(f"{pkg}: {len(rows)} 个版本，逐条列出 `{dep}` 约束\n")
    undeclared = []
    permitting = []
    for ver, c in rows:
        verdict = allows(c, target)
        flag = ""
        if verdict is None:
            flag = "  <-- 未声明该依赖：不构成限制"
            undeclared.append(ver)
        elif verdict:
            flag = f"  <-- 允许 {dep} {target}.x"
            permitting.append(ver)
        print(f"  {ver:16s} {dep}: {c}{flag}")

    print()
    print(f"允许 {dep} {target}.x 的版本   : {permitting or '无'}")
    print(f"未声明 {dep} 的版本（例外项）: {undeclared or '无'}")
    print()
    print("提醒：完整枚举之后仍要逐一检查『未声明』这类例外项，")
    print("      并据此把结论的作用域写准（例如『pub 会选取的版本』而非『任何版本』）。")


if __name__ == "__main__":
    main()

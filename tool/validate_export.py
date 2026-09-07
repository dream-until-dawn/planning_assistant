#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""用 JSON Schema 校验导出包 —— **完全独立于客户端代码**。

## 为什么要有这个脚本

架构总览 §6 里 V3 那一格写着：「导出 JSON 有 JSON Schema，服务端无需客户端
逻辑即可解析」。这句话如果只由 Dart 测试来验，验的是「我们自己的代码能读懂
自己写的东西」—— 那是废话，任何格式都满足。

真正要证明的是：**一个不认识 Flutter、不认识 Drift、不认识这个项目的程序，
只拿到 schema 和文件，就能判断这个文件合不合法。** 所以这里用 Python +
标准的 `jsonschema` 库，不 import 任何本项目的东西，也不复用任何 Dart 逻辑。

## --self-test

与 `check_doc_links.py`、`lint_tests.dart` 同样的规矩：校验器自己必须先被
证明**能变红**。一个永远返回「通过」的校验器与没有校验器等价，而且更糟 ——
它会让人以为格式被守住了。

自测用几个**已知非法**的样本，断言每一个都被拒，并且合法样本被放行。
期望值写死在这里，不从被测函数取。

退出码：0 通过 / 1 校验失败 / 2 用法或环境问题。
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

try:
    from jsonschema import Draft202012Validator
except ImportError:  # pragma: no cover - 环境问题，不是校验失败
    sys.stderr.write(
        "缺少 jsonschema 库。请先安装：\n"
        "    pip install jsonschema\n"
        "（本脚本刻意只依赖标准的 JSON Schema 实现，不依赖本项目代码）\n"
    )
    sys.exit(2)

# Windows 控制台默认 GBK，打印非 ASCII 字符会抛 UnicodeEncodeError ——
# 校验通过却因为一个对勾而退出码非零，是最容易误导人的失败方式。
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

REPO_ROOT = Path(__file__).resolve().parent.parent
SCHEMA_PATH = REPO_ROOT / "docs" / "schema" / "export-v1.schema.json"


def load_schema(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def validate(schema: dict[str, Any], instance: Any) -> list[str]:
    """返回错误描述列表；空列表表示通过。"""
    validator = Draft202012Validator(schema)
    errors = sorted(validator.iter_errors(instance), key=lambda e: list(e.path))
    return [
        "  {}: {}".format(
            "/".join(str(p) for p in e.absolute_path) or "(根)",
            e.message,
        )
        for e in errors
    ]


# ---------------------------------------------------------------------------
# 自测
# ---------------------------------------------------------------------------

_ENVELOPE = {
    "createdAt": 1,
    "updatedAt": 1,
    "deletedAt": None,
    "revision": 1,
    "lastWriterId": "dev",
    "remoteVersion": None,
}

_EMPTY_SECTIONS = {
    "categories": [],
    "tags": [],
    "taskTags": [],
    "tasks": [],
    "stages": [],
    "checklistItems": [],
    "occurrenceOverrides": [],
    "stageOccurrenceStates": [],
    "reminders": [],
    "settings": [],
}


def _minimal_task(**overrides: Any) -> dict[str, Any]:
    task = {
        "id": "t1",
        "title": "任务",
        "note": None,
        "kind": "single",
        "categoryId": None,
        "priority": 2,
        "status": "pending",
        "statusBeforeArchive": None,
        "isAllDay": 0,
        "planDate": None,
        "startMinute": None,
        "endDate": None,
        "endMinute": None,
        "timeZoneId": "Asia/Shanghai",
        "recurrenceRule": None,
        "recurrenceExDates": None,
        "splitFromTaskId": None,
        "colorArgb": None,
        "icon": None,
        "sortOrder": 0,
        "completedAt": None,
        "archivedAt": None,
    }
    task.update(_ENVELOPE)
    task.update(overrides)
    return task


def _bundle(tasks: list[dict[str, Any]] | None = None,
            **top_overrides: Any) -> dict[str, Any]:
    tasks = tasks if tasks is not None else []
    data = dict(_EMPTY_SECTIONS)
    data["tasks"] = tasks
    bundle = {
        "formatVersion": 1,
        "schemaVersion": 1,
        "appVersion": "1.0.0",
        "exportedAt": 1757203200000,
        "deviceId": "dev",
        "counts": {k: len(v) for k, v in data.items()},
        "data": data,
    }
    bundle.update(top_overrides)
    return bundle


def _self_test(schema: dict[str, Any]) -> bool:
    """已知好/坏样本各跑一遍。期望写死在这里，不从被测函数取。"""
    good_cases: list[tuple[str, Any]] = [
        ("空库", _bundle()),
        ("一条任务", _bundle([_minimal_task()])),
        ("墓碑行照常导出", _bundle([_minimal_task(deletedAt=1757203200000)])),
        ("归档任务带 statusBeforeArchive",
         _bundle([_minimal_task(archivedAt=1, statusBeforeArchive="done")])),
        ("重复任务带规范形 RRULE",
         _bundle([_minimal_task(recurrenceRule="RRULE:FREQ=DAILY")])),
        ("二次编码的 exDates 是字符串",
         _bundle([_minimal_task(recurrenceExDates='["2026-03-15"]')])),
    ]

    bad_cases: list[tuple[str, Any]] = [
        ("formatVersion 不是 1", _bundle(formatVersion=2)),
        ("缺少 data 段", {"formatVersion": 1, "schemaVersion": 1,
                          "appVersion": "1", "exportedAt": 1,
                          "deviceId": "d", "counts": {}}),
        ("data 缺一个段", _bundle(data={k: v for k, v in _EMPTY_SECTIONS.items()
                                        if k != "reminders"})),
        ("多出未知的顶层字段", _bundle(extraneous="x")),
        ("任务的 status 是未知值",
         _bundle([_minimal_task(status="exploded")])),
        ("任务的 kind 是未知值", _bundle([_minimal_task(kind="weird")])),
        ("priority 越界", _bundle([_minimal_task(priority=99)])),
        ("startMinute 越界（1440）",
         _bundle([_minimal_task(startMinute=1440)])),
        ("planDate 格式不是 yyyy-MM-dd",
         _bundle([_minimal_task(planDate="2026/03/08")])),
        ("isAllDay 用了布尔而不是 0/1",
         _bundle([_minimal_task(isAllDay=True)])),
        ("任务缺少 timeZoneId",
         _bundle([{k: v for k, v in _minimal_task().items()
                   if k != "timeZoneId"}])),
        ("任务缺少信封的 revision",
         _bundle([{k: v for k, v in _minimal_task().items()
                   if k != "revision"}])),
        ("任务多出未知字段", _bundle([_minimal_task(mystery="?")])),
        ("recurrenceExDates 写成了数组而不是 JSON 字符串",
         _bundle([_minimal_task(recurrenceExDates=["2026-03-15"])])),
        ("settings 的 scope 是 device（不该导出）",
         _bundle(data=dict(_EMPTY_SECTIONS, settings=[dict(
             _ENVELOPE, key="k", valueJson="{}", scope="device")]))),
    ]

    ok = True
    for name, instance in good_cases:
        errors = validate(schema, instance)
        if errors:
            ok = False
            print("  [自测失败] 合法样本被拒：{}\n{}".format(
                name, "\n".join(errors)))

    for name, instance in bad_cases:
        if not validate(schema, instance):
            ok = False
            print("  [自测失败] 非法样本却通过了：{}".format(name))

    print("自测：{} 个合法样本 + {} 个非法样本，结果 {}".format(
        len(good_cases), len(bad_cases), "PASS" if ok else "FAIL"))
    if ok:
        print("  -> schema 既能放行合法包，也能拒绝上述每一类畸形包")
    return ok


def main() -> int:
    parser = argparse.ArgumentParser(
        description="用 JSON Schema 校验导出包（不依赖本项目的任何代码）")
    parser.add_argument("files", nargs="*", type=Path,
                        help="要校验的导出 JSON 文件")
    parser.add_argument("--schema", type=Path, default=SCHEMA_PATH)
    parser.add_argument("--self-test", action="store_true",
                        help="先用已知好/坏样本证明校验器本身有效")
    args = parser.parse_args()

    if not args.schema.exists():
        sys.stderr.write("找不到 schema：{}\n".format(args.schema))
        return 2

    schema = load_schema(args.schema)

    # schema 自身也要合法，否则下面的校验结果全无意义。
    try:
        Draft202012Validator.check_schema(schema)
    except Exception as exc:  # noqa: BLE001
        sys.stderr.write("schema 本身不合法：{}\n".format(exc))
        return 2
    print("schema 自身合法：{}".format(args.schema.relative_to(REPO_ROOT)))

    if args.self_test and not _self_test(schema):
        return 1

    if not args.files:
        if not args.self_test:
            sys.stderr.write("没有指定要校验的文件；用 --self-test 只跑自测\n")
            return 2
        return 0

    failed = False
    for path in args.files:
        if not path.exists():
            sys.stderr.write("找不到文件：{}\n".format(path))
            return 2
        with path.open(encoding="utf-8") as f:
            instance = json.load(f)
        errors = validate(schema, instance)
        if errors:
            failed = True
            print("[失败] {} 校验不通过（{} 处）：".format(path, len(errors)))
            print("\n".join(errors[:20]))
        else:
            print("[通过] {}".format(path))

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

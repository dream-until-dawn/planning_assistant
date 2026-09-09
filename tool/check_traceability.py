#!/usr/bin/env python3
"""每条 V1 需求都要有测试点它的名。

## 为什么要这条门禁

「每月 15 号」「每月最后一个周五」是 FR-TASK-03 验收栏点名的两种，
到 M3 收尾时仍然造不出来，而三层测试都是绿的 ——
引擎的黄金用例、可达性守卫、编解码往返，
三个全集都来自**代码**，没有一个来自**需求**
（testing-strategy §1.15）。

所以补这一条：全集是 requirements.md 里的编号本身。
它只回答一个很弱的问题 —— **有没有测试提到过这条需求** ——
弱，但它是唯一一条不靠代码定义自己全集的检查。

## 它不能回答什么

提到 ≠ 测到。一条 `// FR-TASK-02` 的注释就能让它变绿。
所以它是**下限**，不是验收：漏网的它抓不住，
但「一条测试都没提过」这种情况它一定抓得住。
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REQ = ROOT / 'docs' / '00-product' / 'requirements.md'

# 只管 V1。V2+ 的需求现在没有实现，本来就不该有测试。
ROW = re.compile(r'^\|\s*((?:FR|NFR)-[A-Z]+-\d+)\s*\|(.+)$')

# 这些需求由文档、构建或人工流程承担，代码里点不到名。
# **每一条都要写清楚由谁承担** —— 空着的话，这张豁免表会变成垃圾桶。
EXEMPT = {
    # ── 后续版本，架构留口即可 ──────────────────────────────
    'FR-DATA-06': 'V3 云同步（ADR-0006 已留信封）',
    'FR-DATA-07': 'V3 云端邮件提醒',
    'FR-AI-02': 'V4 语音输入',
    'FR-AI-03': 'V4 自然语言 → TaskCommand',
    'FR-NOTI-05': 'V2 通知栏常驻',
    'NFR-PRIV-02': 'V3 同步必须显式开启并加密',

    # ── M4：配置与提醒 ─────────────────────────────────────
    'FR-NOTI-01': 'M4 提醒排期',
    'FR-NOTI-02': 'M4 滚动窗口排期',
    'FR-NOTI-03': 'M4 重启恢复',
    'FR-NOTI-04': 'M4 精确闹钟权限降级',
    'FR-CFG-05': 'M4 提醒偏好（免打扰时段等）',
    'NFR-REL-01': 'M4 未捕获异常落本地日志（bootstrap.dart 里的 TODO(M4)）',

    # ── M5：打磨与出包 ─────────────────────────────────────
    'FR-CFG-08': 'M5 导入导出（隐藏项要在导出 JSON 里可见）',
    'FR-DATA-01': 'M5「App 强杀不丢已提交写入」要的是真机集成测试',
    'NFR-PERF-01': 'M5 冷启动打点，真机',
    # **这一条是收窄匹配之后才露出来的。** 收窄前它「有覆盖」——
    # 因为 `view_layout_benchmark_test.dart` 的注释里提到了它。
    # 而那个基准量的是**排布函数的耗时**，不是**掉帧率**：
    # 一个 O(n²) 的排布可能仍然不掉帧，一个 O(n) 的排布配上过度重建
    # 也可能掉帧。两者不是一回事，模拟器的帧时间也不充数。
    'NFR-PERF-02': (
        'V1 降级为不验收（用户 2026-09-09 决定，requirements §7.1.1）—— '
        '模拟器量不了掉帧，基准测的是排布耗时；拿到真机后按原方案补'
    ),
    'NFR-PERF-03': 'M5 写入到 UI 更新计时，真机',
    'NFR-REL-02': 'M5 迁移失败保留升级前副本 —— v1 还没有上一版可迁',

    # ── 真缺口：本该在 M3 落地，没落 ────────────────────────
    #
    # 这两条不是「排在后面」，是**排在这儿而漏了**。
    # 放进豁免表只是为了让门禁能跑，不是免了它们的账 ——
    # roadmap 里各有一条记着。
    # FR-TASK-07 当晚就补完了，所以不在这张表里 —— 它现在由
    # stage_occurrence_state_test.dart 与 stage_occurrence_test.dart 点名。
    # FR-TASK-09 也补完了 —— 现在由 checklist_test.dart 点名。
    # 这张表里于是**一条真缺口都不剩**，剩下的全是排在后面的里程碑。
}


BASELINE = ROOT / 'tool' / 'traceability_baseline.txt'

# 豁免的理由必须点名一个里程碑或版本 —— 「以后再说」不算理由。
MILESTONE = re.compile(r'\b(M[0-9]|V[1-9])\b')


def baseline():
    """基线里允许的豁免编号。"""
    out = set()
    for line in BASELINE.read_text(encoding='utf-8').splitlines():
        line = line.strip()
        if line and not line.startswith('#'):
            out.add(line)
    return out


def check_exemptions(exempt, allowed):
    """豁免表的棘轮：只许缩短，而且每条都要写明由谁承担。

    ## 为什么需要这条

    豁免表本身是诚实的 —— 每条都写了理由。要防的是**它长得比覆盖快**：
    那时它就从「记账」变成「仪式」，谁都可以往里加一行让门禁变绿，
    而加的时候没有人会拦。

    棘轮的做法是让「加一条豁免」变成一个**需要说出口的动作**：
    得同时改两个文件，其中基线那个除了放行什么也不做。

    与 `layer_dependency_test.dart` 里 lint 白名单的反僵尸守卫同源，
    评审提的。
    """
    problems = []
    for rid in sorted(set(exempt) - allowed):
        problems.append(
            f'  · {rid} 不在基线里 —— 新增豁免要同时改 '
            f'{BASELINE.name}，那一步是故意的'
        )
    for rid, why in sorted(exempt.items()):
        if not MILESTONE.search(why):
            problems.append(f'  · {rid} 的豁免理由没点名里程碑：{why!r}')
    return problems


def requirements():
    """(编号, 期次) —— 期次列在第三格，V2+ 的跳过。"""
    out = []
    for line in REQ.read_text(encoding='utf-8').splitlines():
        m = ROW.match(line.strip())
        if not m:
            continue
        cells = [c.strip() for c in m.group(2).split('|')]
        # NFR 的表没有「期次」列，一律当 V1。
        phase = cells[1] if len(cells) >= 3 and m.group(1).startswith('FR') else 'V1'
        out.append((m.group(1), phase))
    return out


# 「FR-VIEW-05/06」「R-40/R-41/R-42」这种缩写在文档和测试里到处都是。
# 只认全称的话，`FR-VIEW-05/06` 里的 06 会被算成没人提过 ——
# **这条工具第一版就是这么误报的**，而误报比不报更糟：
# 一条会喊狼来了的门禁，下一个人只会学会无视它。
MENTION = re.compile(r'((?:FR|NFR)-[A-Z]+)-(\d+(?:/\d+)*)')

# **只看 `test(...)` / `group(...)` 的描述，不扫全文。**
#
# 扫全文的话，一条注释就能让一条需求变绿 —— 而注释不会执行。
# 文件头写一句「本文件对应 FR-XX」很容易，它和「真有一条用例在验它」
# 是两回事。
#
# 收窄之后这条门禁与 `lint_tests.dart` **复合**：后者拒绝没有断言的
# 测试，于是「被一个 test 点名」+「那个 test 有断言」，
# 比单独任何一条都强。
CASE = re.compile(
    r'(?:test|group|testWidgets|testAppWidgets)\s*\(\s*'
    r'([\'"])(.*?)\1',
    re.S,
)


def mentioned(text: str) -> dict:
    """用例描述里点了名的需求编号 → 点它的那条描述。展开缩写形式。"""
    out = {}
    for case in CASE.finditer(text):
        desc = case.group(2)
        for prefix, tail in MENTION.findall(desc):
            for num in tail.split('/'):
                out.setdefault(f'{prefix}-{num}', desc.strip())
    return out


def _self_test() -> int:
    """先证明这条校验能变红，再去校验全仓。

    与 `check_doc_links.py --self-test` 同一个规矩（conventions §5）：
    一条从没红过的门禁，和没有门禁是一回事。
    这里要证的有两件，**都栽过**：

     · 缩写认得出来 —— 第一版只认全称，于是测试里写的
       `FR-VIEW-05/06` 被算成「06 没人提过」，报了个假缺口。
       会喊狼来了的门禁，下一个人只会学会无视它。
     · 真缺的时候会红 —— 否则它就只是个复读机。
    """
    cases = [
        ('FR-VIEW-05/06 都算数',
         "test('FR-VIEW-05/06 切视图', () {});",
         {'FR-VIEW-05', 'FR-VIEW-06'}),
        ('单个编号',
         "group('见 FR-TASK-03 验收栏', () {});", {'FR-TASK-03'}),
        ('三连缩写',
         "test('R-50 与 NFR-REL-01/02/03', () {});",
         {'NFR-REL-01', 'NFR-REL-02', 'NFR-REL-03'}),
        ('不是编号的不认',
         "test('FR-TASK 与 ABC-1', () {});", set()),
        # ── 下面四条钉的是「收窄到用例描述」这件事本身 ──────────
        ('注释里的不算', '/// 本文件对应 FR-TASK-01', set()),
        ('文件头 library 注释里的也不算',
         '/// FR-CFG-02 主题配置\nlibrary;', set()),
        ('双引号的描述也认得出',
         'test("FR-DATA-04 导出", () {});', {'FR-DATA-04'}),
        # 这一条是**给正则本身**的：`\b` 写成普通串会变成退格符，
        # 那样 CASE 一个都匹配不上、整条门禁空转着报绿。
        # 同样的escape 坑今天栽过三次（endDate lint 也是），所以钉住。
        ('testAppWidgets 也认',
         "testAppWidgets('FR-VIEW-07 长按新建', (t) async {});",
         {'FR-VIEW-07'}),
    ]
    bad = 0
    for name, text, want in cases:
        got = set(mentioned(text))
        if got != want:
            print(f'  自检失败：{name} —— 期望 {want}，实得 {got}')
            bad += 1

    # ── 第 9 类：**端到端，而且成对** ────────────────────────
    #
    # 上面那些验的全是提取函数 `mentioned()`。而这条工具的存在理由是
    # 「**缺了会红**」—— 在补这一段之前，那一半一条都没验过。
    # 提取得再准，如果缺了不会红，整条工具还是摆设。
    #
    # **必须成对**：只验「缺一条会红」的话，一个 `return 1` 的实现
    # 也能过。这与 R-27 撞车那里配的对照组是同一个动作。
    reqs = [('FR-ZZ-01', 'V1'), ('FR-ZZ-02', 'V1'), ('FR-ZZ-09', 'V2')]
    full = [
        ('a_test.dart', "test('FR-ZZ-01 甲', () {});"),
        ('b_test.dart', "group('FR-ZZ-02 乙', () {});"),
    ]
    pairs = [
        ('缺一条 → 报出来', full[:1], ['FR-ZZ-02']),
        ('一条不缺 → 不报', full, []),
        # V2 的不算数：它本来就还没实现，报它等于每次都红。
        ('V2 的不参与', full, []),
        # 豁免的也不算 —— 但豁免表是**另一份声明**，
        # 不该顺手让「点了名」这件事也失效。
        ('豁免的不报', [], ['FR-ZZ-02']),
    ]
    for name, corpus, want in pairs:
        exempt = {'FR-ZZ-01'} if name == '豁免的不报' else set()
        missing, _, _ = evaluate(reqs, corpus, exempt)
        if missing != want:
            print(f'  自检失败：{name} —— 期望缺 {want}，实得缺 {missing}')
            bad += 1

    # ── 第 10 类：豁免表的棘轮 ────────────────────────────
    #
    # 同样**成对**：只验「越界会报」的话，一个「一律报」的实现也能过。
    ratchets = [
        ('基线内的豁免放行', {'FR-ZZ-01': 'M4 提醒'}, {'FR-ZZ-01'}, 0),
        ('基线外的豁免拦住', {'FR-ZZ-02': 'M4 提醒'}, {'FR-ZZ-01'}, 1),
        ('缩短随时可以', {}, {'FR-ZZ-01', 'FR-ZZ-02'}, 0),
        ('理由不点名里程碑就拦住', {'FR-ZZ-01': '以后再说'}, {'FR-ZZ-01'}, 1),
    ]
    for name, exempt, allowed, want in ratchets:
        got = len(check_exemptions(exempt, allowed))
        if (got > 0) != (want > 0):
            print(
                f'  自检失败：{name} —— '
                f'期望{"报" if want else "放行"}，实得 {got} 处'
            )
            bad += 1

    if bad:
        print(f'自检没过（{bad} 条）—— 校验结果不予采信')
        return 1
    print(
        f'自检通过（{len(cases)} 条提取 + {len(pairs)} 条端到端 '
        f'+ {len(ratchets)} 条棘轮）'
    )
    return 0


def evaluate(reqs, corpus, exempt):
    """(缺的, 被谁点了名) —— **不碰 IO**，好让自检能喂合成语料。

    抽出来是为了让「真缺的时候会红」可测。在此之前这一段长在 `main`
    里，于是自检只能验提取函数 `mentioned()`；
    而这条工具的**存在理由**是「缺了会红」，那一半一条都没验过 ——
    docstring 承诺了两件事，机制只兑现一件。
    """
    where = {}
    for name, text in corpus:
        for rid, desc in mentioned(text).items():
            where.setdefault(rid, (name, desc))

    missing, covered = [], []
    for rid, phase in reqs:
        if phase != 'V1' or rid in exempt:
            continue
        # 要的是**一条用例**点名。只在注释里出现不算 ——
        # 那是实现在自称完成，不是有人验过。
        (covered if rid in where else missing).append(rid)
    return missing, covered, where


def main(argv: list) -> int:
    if '--self-test' in argv and _self_test() != 0:
        return 1

    ratchet = check_exemptions(EXEMPT, baseline())
    if ratchet:
        print(f'豁免表有 {len(ratchet)} 处问题：')
        for line in ratchet:
            print(line)
        return 1

    corpus = [
        (p.relative_to(ROOT).as_posix(), p.read_text(encoding='utf-8'))
        for p in (ROOT / 'test').rglob('*.dart')
    ]
    missing, covered, where = evaluate(requirements(), corpus, EXEMPT)

    total = len(covered) + len(missing)
    print(f'V1 需求 {total} 条，豁免 {len(EXEMPT)} 条')

    # **把每条是在哪儿被点名的打出来**（`--verbose`）。
    #
    # 这条门禁很弱（点名 ≠ 测到），而对付「虚假安全感」的办法不是把匹配
    # 做强，是把它的弱点**做成可见的**：一眼扫过去就能看出哪条需求
    # 只是被一个名字里带编号的用例蹭了一下。
    if '--verbose' in argv:
        for rid in sorted(covered):
            rel, desc = where[rid]
            print(f'  {rid:<14} {rel}')
            print(f'  {"":<14}   {desc}')

    if missing:
        print(f'没有任何用例点名的 {len(missing)} 条：')
        for rid in missing:
            print(f'  · {rid}')
        print('（编号要写在 test(...) / group(...) 的描述里，注释里不算）')
        return 1
    print("每条都有用例点名")
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

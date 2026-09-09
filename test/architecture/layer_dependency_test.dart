/// 分层依赖守卫（NFR-MAINT-01：「分层依赖方向由自动化检查强制」）。
///
/// 强制 docs/01-architecture/module-map.md §3 的依赖规则，以及
/// docs/05-engineering/testing-strategy.md §6 的额外守卫。
///
/// **本文件被变异演练打回过四轮**，每一轮的失效原理都不同：
///  1. 规则写错 / 漏写 —— 注入违规能发现。
///  2. 三层 feature 路径整片不被分类，规则**静默**失效而守卫报绿 ——
///     注入违规发现不了，因为违规文件本身在盲区里。
///  3. 修第 2 条时**过冲**，把 view-specs 明文规定的共享组件判成违规 ——
///     症状是**正确代码变红**，注入违规的验法永远发现不了。
///  4. `feature_domain` 桶存在但规则表里没有条目 —— 文件**分类是成功的**，
///     所以第 2 条加的「未分类即违规」也抓不到。
///
/// 由此定下三件事：
///  · 验收必须**双向**（违规必红 + 文档规定的正常写法必绿）
///  · 结构性断言要覆盖**两跳**：文件 → 层，层 → 规则
///  · 每次实质性改动后重跑变异演练，不是建立时做一次的仪式
///
/// **已知未封的一扇（B6，M1 待办）**：约束是关于**可达性**的，而本守卫看的是
/// **相邻性**。application 合法 import Repository 再 re-export，presentation 合法
/// import 本 feature 的 application —— 没有任何一条边违规，但复合起来破坏 FR-AI-01。
/// 此处只用 `_forbiddenExportOnly` 堵住了这一个具体入口，**通用解（传递闭包 /
/// 符号级分析）留到 M1** —— 那时才有真实样本可验证它抓得住真的、放得过假的。
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _packageName = 'planning_assistant';
const _layerSegments = {'presentation', 'application', 'domain'};
const _topLevelLayers = {'core', 'domain', 'data', 'platform', 'design'};

/// `_classify()` 可能产出的**全部**层键。
///
/// 由两个基础集合派生而不是手写，因此不可能与 `_classify` 漂移。
/// 「每个层键都必须有规则」那条断言拿它当全集 —— 见 B5：
/// 上一版 `_forbidden` 只有 7 个键，而 `_classify` 能产出 8 个，
/// 于是 `features/<name>/domain/` 落进一个没有任何规则的桶，四条违规全绿。
final Set<String> allLayerKeys = {
  ..._topLevelLayers,
  for (final s in _layerSegments) 'feature_$s',
};

/// 「领域性质」的层。feature 本地的 domain 仍然是 domain ——
/// 否则「新增一个 feature 就能绕过领域层纯净性」（NFR-MAINT-02）。
const domainLikeLayers = {'domain', 'feature_domain'};

/// 禁止直接读环境时钟的层。
const clockRestrictedLayers = {
  'domain',
  'feature_domain',
  'feature_application',
};

/// 禁止用 assert 表达不变量的层。
const assertRestrictedLayers = {'domain', 'feature_domain', 'data'};

/// 显式声明「本层无禁止项」的层，必须注明理由。
/// 目前为空 —— 每一层都有至少一条约束。
const layersWithoutRules = <String, String>{};

/// 不属于任何一层、但允许存在于 `lib/` 下的文件。每条都要有理由。
const _unlayeredAllowList = {
  'main.dart', // 入口，只调 bootstrap
  'app.dart', // MaterialApp 装配
  'bootstrap.dart', // 初始化编排
  // 组合根的 Provider **声明**（实现全部在 bootstrap 里覆盖）。
  // 不能塞进 core/：那样 core 就要 import flutter_riverpod，而 domain
  // 合法地 import core 且禁止 Flutter —— 两条合法的边复合出一条违规，
  // 且分层守卫只看直接 import，抓不到。同 B6 的形状。
  'app_providers.dart',
};

bool _isGeneratedPath(String relToLib) =>
    relToLib.startsWith('l10n/generated/');

String _norm(String path) => path.replaceAll(r'\', '/');

String? _relToLib(String path) {
  final p = _norm(path);
  final i = p.indexOf('lib/');
  return i < 0 ? null : p.substring(i + 4);
}

/// 文件的层与所属 feature。
///
/// **feature 粒度与层位置是两件事，必须解耦**：
///  · feature 名 = `features/` 之后的**第一段**（`views`）
///  · 层         = 从第 2 段起、任意深度上**第一个**命中的层段（`presentation`）
///
/// 上一版把 feature 取成「层段之前的完整路径」，于是 `views/timeline` 与
/// `views/shared` 成了两个 feature，把 module-map §1 与 view-specs §0.3 规定的
/// 共享筛选条判成了跨 feature 违规。修「层认不出来」不需要连 feature 粒度一起改。
({String layer, String? feature})? _classify(String relToLib) {
  final segs = relToLib.split('/');
  if (segs.length < 2) return null;

  if (_topLevelLayers.contains(segs.first)) {
    return (layer: segs.first, feature: null);
  }
  if (segs.first == 'features') {
    for (var i = 2; i < segs.length - 1; i++) {
      if (_layerSegments.contains(segs[i])) {
        return (layer: 'feature_${segs[i]}', feature: segs[1]);
      }
    }
  }
  return null;
}

/// 把 import 目标归一成 lib 相对路径；外部包原样返回。
String _resolveImport(String target, String fromFileRelToLib) {
  const selfPrefix = 'package:$_packageName/';
  if (target.startsWith(selfPrefix)) {
    return target.substring(selfPrefix.length);
  }
  if (target.startsWith('package:') || target.startsWith('dart:')) {
    return target;
  }
  final out = fromFileRelToLib.split('/')..removeLast();
  for (final seg in target.split('/')) {
    if (seg == '.' || seg.isEmpty) continue;
    if (seg == '..') {
      if (out.isNotEmpty) out.removeLast();
    } else {
      out.add(seg);
    }
  }
  return out.join('/');
}

String _matchable(String resolved) =>
    resolved.startsWith('package:') || resolved.startsWith('dart:')
    ? resolved
    : '/$resolved';

List<String> _withBarrel(String dirPattern) => [
  dirPattern,
  '${dirPattern.substring(0, dirPattern.length - 1)}.dart',
];

const Map<String, List<(String, String)>> _forbiddenRaw = {
  'core': [
    ('/domain/', 'core 不得依赖 domain'),
    ('/data/', 'core 不得依赖 data'),
    ('/features/', 'core 不得依赖 features'),
    ('/platform/', 'core 不得依赖 platform'),
    ('/design/', 'core 不得依赖 design'),
  ],
  'domain': [
    ('package:flutter/', 'domain 必须零 Flutter 依赖（NFR-MAINT-02）'),
    ('/data/', 'domain 不得依赖 data（依赖倒置：data 实现 domain 的接口）'),
    ('/features/', 'domain 不得依赖 features'),
    ('/platform/', 'domain 不得依赖 platform'),
    ('/design/', 'domain 不得依赖 design'),
  ],
  'data': [
    ('/features/', 'data 不得依赖 features'),
    ('/design/', 'data 不得依赖 design'),
    ('/platform/', 'data 不得依赖 platform（平台能力经构造注入）'),
  ],
  'platform': [
    ('/data/', 'platform 不得依赖 data'),
    ('/features/', 'platform 不得依赖 features'),
  ],
  'design': [
    ('/domain/', 'design 不得依赖 domain'),
    ('/data/', 'design 不得依赖 data'),
    ('/features/', 'design 不得依赖 features'),
  ],
  'feature_application': [
    ('/data/', 'feature 的 application 层只依赖抽象，不得依赖 data 的具体实现'),
    ('/presentation/', 'application 不得依赖任何 presentation'),
  ],
  'feature_domain': [
    // feature 本地的 domain 与顶层 domain 受同样约束，见 module-map §3。
    ('package:flutter/', 'feature 的 domain 层同样必须零 Flutter 依赖（NFR-MAINT-02）'),
    ('/data/', 'feature 的 domain 不得依赖 data'),
    ('/platform/', 'feature 的 domain 不得依赖 platform'),
    ('/design/', 'feature 的 domain 不得依赖 design'),
  ],
  'feature_presentation': [
    ('/data/', 'presentation 不得依赖 data'),
    (
      '/domain/repositories/',
      'presentation 不得持有 Repository（写路径必须经 TaskCommand，FR-AI-01）',
    ),
    // 组合根装配页面并**注入**路由跳转（外壳的 onOpenSettings、
    // 设置页的 onOpenCategories 都是这么接的）。页面反过来 import 它
    // 就成了环：app.dart → settings_page.dart → app.dart。
    //
    // 补这条是因为真写出来过一次：设置页里直接
    // `context.go(AppRoutes.categories)` —— 编译过、分析过、当时全部守卫
    // 也绿，因为 `app.dart` 在不分层白名单里，没有任何一条规则管得到它。
    ('/app.dart', 'presentation 不得依赖组合根 app.dart；路由跳转由组合根注入回调'),
  ],
};

/// **仅对 `export` 生效**的禁止项（`import` 不受这些约束）。
///
/// 存在的理由见 B6：两条各自合法的边复合起来会破坏约束 ——
/// application 合法地 import `domain/repositories/`，再把它 re-export 出去，
/// presentation 合法地 import 本 feature 的 application，于是 presentation
/// 拿到了 Repository，FR-AI-01 被破坏，而**没有任何一条边违规**。
///
/// 通用解（跟着 export 边算传递闭包）留到 M1 —— 那时才有真实样本可以验证
/// 「抓得住真的、放得过假的」。这里先用一条窄规则堵住 FR-AI-01 这面承重墙上的洞：
/// application **可以** import Repository 接口，但**不得转手再导出**。
const Map<String, List<(String, String)>> _forbiddenExportOnlyRaw = {
  'feature_application': [
    (
      '/domain/repositories/',
      'application 不得 re-export Repository —— 那会让 presentation 经本 feature '
          '的 barrel 间接拿到它，绕过 TaskCommand（FR-AI-01）。import 它是允许的',
    ),
  ],
};

final Map<String, List<(String, String)>> _forbiddenExportOnly = {
  for (final e in _forbiddenExportOnlyRaw.entries)
    e.key: [
      for (final (pattern, rule) in e.value)
        if (pattern.startsWith('/') && pattern.endsWith('/'))
          ...(_withBarrel(pattern).map((p) => (p, rule)))
        else
          (pattern, rule),
    ],
};

final Map<String, List<(String, String)>> _forbidden = {
  for (final e in _forbiddenRaw.entries)
    e.key: [
      for (final (pattern, rule) in e.value)
        if (pattern.startsWith('/') && pattern.endsWith('/'))
          ...(_withBarrel(pattern).map((p) => (p, rule)))
        else
          (pattern, rule),
    ],
};

/// 对一条 (文件, import 目标) 做全部路径规则判定。
///
/// 抽成纯函数，是为了让夹具表能用合成输入**双向**验证它 ——
/// 只跑真实文件的话，「正常写法被误判」这类缺陷要等到 M2 写页面时才暴露。
List<String> checkImport(
  String fileRelToLib,
  String importTarget, {
  bool isExport = false,
}) {
  final c = _classify(fileRelToLib);
  if (c == null) return const [];
  final out = <String>[];
  final resolved = _resolveImport(importTarget, fileRelToLib);
  final matchable = _matchable(resolved);

  for (final (pattern, rule)
      in _forbidden[c.layer] ?? const <(String, String)>[]) {
    if (matchable.contains(pattern)) out.add(rule);
  }
  if (isExport) {
    for (final (pattern, rule)
        in _forbiddenExportOnly[c.layer] ?? const <(String, String)>[]) {
      if (matchable.contains(pattern)) out.add(rule);
    }
  }

  if (c.layer == 'feature_presentation' && c.feature != null) {
    final target = _classify(resolved);
    if (target?.layer == 'feature_presentation' &&
        target?.feature != null &&
        target!.feature != c.feature) {
      out.add(
        'feature「${c.feature}」的 presentation 不得引用 feature「${target.feature}」的 '
        'presentation；跨 feature 只能经 application 层的 Provider 通信',
      );
    }
  }
  return out;
}

/// 取出文件里全部 import/export 指令的**所有** URI。
///
/// 按 `;` 切分而不是逐行，且取出每条指令里的全部字符串字面量 ——
/// 逐行正则会被两种合法写法绕过：
///  · 条件 import：`import 'a.dart' if (dart.library.io) 'b.dart';` 只看得到第一个
///  · 跨行 import：`import\n    'a.dart';`
List<({int lineNo, String raw, String uri, bool isExport})> _importUris(
  String source,
) {
  // 先去掉注释，避免注释里的 import 字样与字符串被当真
  final cleaned = source
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'//[^\n]*'), '');

  final out = <({int lineNo, String raw, String uri, bool isExport})>[];
  final directive = RegExp(
    r'(?:^|\n)\s*(import|export)\b([^;]*);',
    dotAll: true,
  );
  final literal = RegExp('''['"]([^'"]+)['"]''');

  for (final m in directive.allMatches(cleaned)) {
    final lineNo = '\n'.allMatches(cleaned.substring(0, m.start)).length + 1;
    final isExport = m.group(1) == 'export';
    final body = m.group(2)!;
    final raw = m.group(0)!.trim().replaceAll(RegExp(r'\s+'), ' ');
    for (final lit in literal.allMatches(body)) {
      out.add((
        lineNo: lineNo,
        raw: raw,
        uri: lit.group(1)!,
        isExport: isExport,
      ));
    }
  }
  return out;
}

List<File> _dartFiles(String dir) {
  final d = Directory(dir);
  if (!d.existsSync()) return const [];
  return d
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.endsWith('.g.dart'))
      .where((f) => !f.path.endsWith('.freezed.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

/// 夹具：**文档明文规定的正常写法，必须全部判绿**。
///
/// 这一半是三轮变异演练里最晚补上的：前两轮只验「违规必红」，
/// 而 B4 的症状是「正确代码变红」—— 单向验证永远发现不了。
const _legalCases = <(String file, String import, String why)>[
  (
    'features/views/timeline/presentation/timeline_page.dart',
    '../../shared/presentation/filter_bar.dart',
    'module-map §1 把 views/shared 与四视图并列；view-specs §0.3 规定筛选条是「同一个组件」',
  ),
  (
    'features/views/gantt/presentation/gantt_view.dart',
    'package:planning_assistant/features/views/shared/presentation/filter_bar.dart',
    '同上，package: 写法',
  ),
  (
    'features/task/presentation/task_editor.dart',
    'package:planning_assistant/features/task/application/task_providers.dart',
    'presentation 依赖本 feature 的 application 是正常方向',
  ),
  (
    'features/task/application/task_providers.dart',
    'package:planning_assistant/domain/entities/task.dart',
    'application 依赖 domain 是正常方向',
  ),
  (
    'data/repositories/drift_task_repository.dart',
    'package:planning_assistant/domain/repositories/task_repository.dart',
    'data 实现 domain 的接口 —— 依赖倒置的正常方向',
  ),
  (
    'data/repositories/core/mapper.dart',
    'package:planning_assistant/domain/entities/task.dart',
    '路径里含 core 段但实际在 data 层（S2 那处假阳性）',
  ),
  (
    'domain/policies/task_policy.dart',
    'package:planning_assistant/core/time/clock.dart',
    'domain 依赖 core 是允许的',
  ),
  (
    'features/task/domain/task_rules.dart',
    'package:planning_assistant/core/time/clock.dart',
    'feature 本地 domain 依赖 core 同样允许（正向，防止 B5 被修成一刀切）',
  ),
  (
    'design/components/task_card.dart',
    'package:flutter/material.dart',
    'design 层就是 Flutter 组件',
  ),
  (
    'features/views/gantt/presentation/gantt_painter.dart',
    'package:flutter/material.dart',
    'presentation 层用 Flutter 是正常的',
  ),
];

/// 夹具：**必须判违规的写法**。
const _illegalCases = <(String file, String import, String expectContains)>[
  (
    'domain/entities/task.dart',
    'package:flutter/material.dart',
    '零 Flutter 依赖',
  ),
  (
    'features/task/domain/task_rules.dart',
    'package:flutter/material.dart',
    '零 Flutter 依赖',
  ),
  (
    'features/task/domain/task_rules.dart',
    'package:planning_assistant/data/database/db.dart',
    'domain 不得依赖 data',
  ),
  (
    'domain/entities/task.dart',
    '../../data/database/db.dart',
    'domain 不得依赖 data',
  ),
  (
    'features/views/gantt/presentation/x.dart',
    'package:planning_assistant/data/repositories/y.dart',
    'presentation 不得依赖 data',
  ),
  (
    'features/views/gantt/presentation/x.dart',
    'package:planning_assistant/domain/repositories/y.dart',
    '不得持有 Repository',
  ),
  (
    'features/task/presentation/x.dart',
    'package:planning_assistant/domain/repositories.dart',
    '不得持有 Repository',
  ),
  (
    'features/settings/presentation/x.dart',
    'package:planning_assistant/app.dart',
    '不得依赖组合根',
  ),
  (
    // 相对路径写法也要判红，否则换个写法就绕过去了。
    'features/settings/presentation/x.dart',
    '../../../app.dart',
    '不得依赖组合根',
  ),
  (
    'features/views/gantt/presentation/x.dart',
    'package:planning_assistant/features/task/presentation/y.dart',
    '不得引用 feature',
  ),
  (
    'features/task/presentation/x.dart',
    '../../settings/presentation/y.dart',
    '不得引用 feature',
  ),
  (
    'features/task/application/x.dart',
    'package:planning_assistant/features/task/presentation/y.dart',
    'application 不得依赖任何 presentation',
  ),
  (
    'core/time/clock.dart',
    'package:planning_assistant/domain/entities/task.dart',
    'core 不得依赖 domain',
  ),
];

void main() {
  final libFiles = _dartFiles('lib');
  final testFiles = _dartFiles('test');

  group('守卫自身的完备性（每个桶都必须落在某条规则下）', () {
    // 这一组与下面的夹具组管的是**不同的事**：
    //   夹具组  → 规则内容对不对
    //   本组    → 规则有没有被套到所有该套的地方
    // B3/B5 那一类失效，规则内容全是对的，问题在于某些文件根本不受任何规则约束。
    // 「未分类即违规」锁住了「文件 → 层」这一跳，本组锁住「层 → 规则」那一跳。

    test('_classify 能产出的每个层键，都必须有禁止项或显式声明无禁止项', () {
      final missing = <String>[];
      for (final key in allLayerKeys) {
        final hasRules = (_forbidden[key] ?? const []).isNotEmpty;
        final declaredEmpty = layersWithoutRules.containsKey(key);
        if (!hasRules && !declaredEmpty) missing.add(key);
      }
      expect(
        missing,
        isEmpty,
        reason:
            '以下层键没有任何规则，落进该桶的文件不受任何约束，'
            '而且它们**分类是成功的**，因此「未分类即违规」那条断言也发现不了：'
            ' ${missing.join(', ')} 。'
            '要么在 _forbidden 里补条目，要么在 layersWithoutRules 里显式声明并注明理由。',
      );
    });

    test('_forbidden 里不得出现 _classify 产不出的层键（拼写错会静默失效）', () {
      final unknown = _forbidden.keys.where((k) => !allLayerKeys.contains(k));
      expect(unknown, isEmpty, reason: '这些键永远匹配不上任何文件：$unknown');
    });

    test('所有层过滤集合都只含合法层键', () {
      final sets = {
        'domainLikeLayers': domainLikeLayers,
        'clockRestrictedLayers': clockRestrictedLayers,
        'assertRestrictedLayers': assertRestrictedLayers,
      };
      for (final e in sets.entries) {
        expect(
          e.value.difference(allLayerKeys),
          isEmpty,
          reason: '${e.key} 含有 _classify 产不出的键，那部分过滤永远不生效',
        );
      }
    });

    test('每个「领域性质」的层都必须同时受时钟与 assert 约束', () {
      // 防止将来新增层键时，只补了 _forbidden 却漏掉这两条按层过滤的守卫。
      final domainish = allLayerKeys.where((k) => k.endsWith('domain')).toSet();
      expect(
        domainish.difference(domainLikeLayers),
        isEmpty,
        reason: '以下领域性质的层未被 domainLikeLayers 收录',
      );
      for (final k in domainish) {
        expect(clockRestrictedLayers, contains(k), reason: '$k 未受时钟守卫约束');
        expect(
          assertRestrictedLayers,
          contains(k),
          reason: '$k 未受 assert 守卫约束',
        );
      }
    });
  });

  group('守卫自身的双向夹具（不依赖仓库现状）', () {
    test('文档规定的正常写法必须全部判绿', () {
      final wrong = <String>[];
      for (final (file, imp, why) in _legalCases) {
        final v = checkImport(file, imp);
        if (v.isNotEmpty) {
          wrong.add(
            '  $file\n    import $imp\n    ($why)\n    却被判: ${v.join('; ')}',
          );
        }
      }
      expect(
        wrong,
        isEmpty,
        reason:
            '以下 ${wrong.length} 处**正确写法**被误判为违规 —— '
            '假阳性会训练人去绕开守卫：\n${wrong.join('\n')}',
      );
    });

    test('违规写法必须全部判红，且理由对得上', () {
      final missed = <String>[];
      for (final (file, imp, expectContains) in _illegalCases) {
        final v = checkImport(file, imp);
        if (!v.any((r) => r.contains(expectContains))) {
          missed.add(
            '  $file\n    import $imp\n    期望包含「$expectContains」，实得: $v',
          );
        }
      }
      expect(
        missed,
        isEmpty,
        reason: '以下 ${missed.length} 处违规被放过或理由不符：\n${missed.join('\n')}',
      );
    });

    test('export 专属规则：application 可以 import Repository，但不得 re-export', () {
      // 双向：同一对 (文件, 目标)，import 判绿、export 判红。
      // 若只验 export 变红，会区分不出「修对了」和「把 application 依赖
      // Repository 整个禁掉」—— 后者会在 M1 写 UseCase 时立刻炸。
      const file = 'features/task/application/repo_exports.dart';
      const target =
          'package:planning_assistant/domain/repositories/task_repository.dart';

      expect(
        checkImport(file, target),
        isEmpty,
        reason: 'application **import** Repository 接口是正常方向，不得误判',
      );
      expect(
        checkImport(file, target, isExport: true),
        anyElement(contains('不得 re-export Repository')),
        reason: 'export 会让 presentation 经本 feature 的 barrel 间接拿到它（FR-AI-01）',
      );
      // barrel 变体同样要挡住
      expect(
        checkImport(
          file,
          'package:planning_assistant/domain/repositories.dart',
          isExport: true,
        ),
        anyElement(contains('不得 re-export Repository')),
      );
    });

    test('条件 import 与跨行 import 的每个 URI 都被取出', () {
      const source = '''
import 'stub.dart'
    if (dart.library.io) 'package:planning_assistant/data/x.dart'
    if (dart.library.html) 'package:planning_assistant/design/y.dart';
import
    'package:planning_assistant/domain/z.dart';
// import 'package:planning_assistant/data/commented_out.dart';
''';
      final uris = _importUris(source).map((e) => e.uri).toList();
      expect(uris, [
        'stub.dart',
        'package:planning_assistant/data/x.dart',
        'package:planning_assistant/design/y.dart',
        'package:planning_assistant/domain/z.dart',
      ], reason: '条件分支的 URI、跨行 URI 都要取到，注释里的不能取');
    });
  });

  test('视图侧不得直接读原始结束时刻（data-model §4.7）', () {
    // ## 这条守的是什么
    //
    // §4.7 那句「有效跨度由领域层派生，**不得各自计算**」现在靠
    // `shared_span_test` 钉着 —— 而那条守卫的作用域到 **provider 为止**：
    // 三个视图的 provider 都走 `row.span`，它就绿。
    // 将来某个 painter 直接读 `row.endDate` 画东西，它不会红。
    //
    // 后果是具体的：末阶段排到 `endDate` 之后的任务，
    // 甘特画到阶段结束、时间轴画到存储的结束 —— 同一条任务两个长度。
    //
    // ## 它是名字启发式，不是类型分析
    //
    // **这一点必须写明。** `endMinute` 在视图层是个合法的字段名 ——
    // `GanttBar.endMinute`、`TimelineBlock.endMinute` 都是视图自己的
    // 值对象，跟任务的存储结束没关系。一律禁掉的话要挂几十条白名单，
    // 而白名单是守卫的盲区。
    //
    // 所以只盯**接收者名字**：这个仓库里表示任务或发生的就是这几个。
    // 够不着的写法是有的（`final x = row; x.endDate`）——
    // 写在这儿是为了下一个人知道它的边界在哪，而不是以为它管全了。
    const receivers = ['row', 'task', 'occurrence'];

    // 白名单锚定确切文件名，每条写清理由。
    const allowed = {
      // 派生跨度的定义处：`endDate`/`endMinute` 的委托就在它身上。
      'task_occurrence.dart',
      // 展开时要把存储的起止算成原始跨度，那是 `span` 的**上游**。
      'occurrence_expansion.dart',
    };

    // **必须用 raw 串拼**：普通串里的 `\b` 是退格符，不是单词边界 ——
    // 那样的正则一个都匹配不上，这条守卫会**空转着报绿**。写这条时就踩了，
    // 是「故意写一处违规看它红不红」这一步把它揪出来的（§1.4 那条规矩）。
    final pattern = RegExp(
      r'\b(' + receivers.join('|') + r')\.(endDate|endMinute)\b',
    );
    final violations = <String>[];
    var scanned = 0;
    for (final file in libFiles) {
      final rel = _relToLib(file.path);
      if (rel == null || !rel.startsWith('features/views/')) continue;
      if (allowed.contains(rel.split('/').last)) continue;
      scanned++;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trim().startsWith('//')) continue;
        if (pattern.hasMatch(lines[i])) {
          violations.add('  - lib/$rel:${i + 1}  ${lines[i].trim()}');
        }
      }
    }

    // 自检：白名单把该扫的全排除掉的话，这条守卫就成了复读机。
    expect(scanned, greaterThan(5), reason: '视图层只扫到 $scanned 个文件，守卫大概率失效了');
    expect(
      violations,
      isEmpty,
      reason:
          '视图侧直接读了原始结束时刻，请改用 row.span / effectiveEnd：\n'
          '${violations.join('\n')}',
    );
  });

  test('视图侧不得直接读 stage.status（FR-TASK-07）', () {
    // ## 它防的和上面那条是同一件事
    //
    // 阶段状态有两个存储位置：不重复的任务在 `Stage.status`，
    // 重复的在 `stage_occurrence_states`。分流只写在
    // `stageStatusFor` / `TaskOccurrence.stageStatus` 两处。
    //
    // **这条 lint 是补上来的，而且是补给一个真发生过的缺陷。**
    // 补 FR-TASK-07 时卡片与单次弹层都改走了新判据，**甘特没改** ——
    // 它自己 `stage.status == done` 算分段着色与进度。于是同一条重复
    // 任务，列表说「阶段 1/2」、甘特说「0/2」，两边都不报错。
    // 当时全套测试是绿的。
    //
    // 同上一条：**名字启发式，不是类型分析**。只盯 `stage.` / `s.`
    // 这两个接收者名 —— 这个仓库里表示一个阶段的就是它们。
    const receivers = ['stage', 's'];
    const allowed = {
      // 分流本身住在这儿。
      'stage_occurrence_status.dart',
      // 行上的唯一入口，它调上面那个。
      'task_occurrence.dart',
    };

    final pattern = RegExp(r'\b(' + receivers.join('|') + r')\.status\b');
    final violations = <String>[];
    var scanned = 0;
    for (final file in libFiles) {
      final rel = _relToLib(file.path);
      if (rel == null || !rel.startsWith('features/views/')) continue;
      if (allowed.contains(rel.split('/').last)) continue;
      scanned++;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trim().startsWith('//')) continue;
        if (pattern.hasMatch(lines[i])) {
          violations.add('  - lib/$rel:${i + 1}  ${lines[i].trim()}');
        }
      }
    }

    expect(scanned, greaterThan(5), reason: '视图层只扫到 $scanned 个文件，守卫大概率失效了');
    expect(
      violations,
      isEmpty,
      reason:
          '视图侧直接读了阶段自己的状态，请改用 row.stageStatus(stage)：\n'
          '${violations.join('\n')}',
    );
  });

  test('两条视图侧 lint 的白名单文件都真的存在（防止白名单变僵尸）', () {
    // 白名单锚的是文件名。文件改了名而白名单没跟着改的话，
    // 那一条豁免会**静默失效**：守卫开始扫一个本该豁免的文件，
    // 或者更糟 —— 一条早就不存在的豁免留在表里，
    // 下一个人以为它还在挡着什么。
    const named = {
      'task_occurrence.dart',
      'occurrence_expansion.dart',
      'stage_occurrence_status.dart',
    };
    final present = {
      for (final f in _dartFiles('lib')) _norm(f.path).split('/').last,
    };
    for (final name in named) {
      expect(present, contains(name), reason: '白名单里的 $name 已经不存在了');
    }
  });

  /// 允许构造 `SnackBarAction` 的文件。**每条要写理由。**
  ///
  /// 名单锚定确切文件名，不做子串匹配 —— 同 `endDate` lint 那条白名单。
  const snackBarActionOwners = {
    // 全项目发提示的唯一入口。`persist: false` 那一行就在它身上。
    'undo_snackbar.dart',
  };

  test('构造 SnackBarAction 的地方必须在名单里', () {
    // ## 这条与下面那条守的**不是同一件事**
    //
    // 下面那条是**逐处的性质检查**：凡是带 action 的提示都得写
    // `persist: false`。它守得住「第五处忘了写」，
    // **守不住「第五处照抄一整套、而且写对了」** —— 那时它绿，
    // 而重复回来了。四份拷贝加同一段长注释，正是这次要消掉的东西。
    //
    // 所以「`scanned` 从 4 降到 1」不是那条守卫变弱了：
    // 它从来就没在守这一件事。评审点出来的。
    //
    // ## 为什么是名单，不是禁令
    //
    // 将来真要加一个**非撤销**的动作提示（「查看」「重试」都是合理
    // 需求），路要通 —— 但得在名单里留下一行，而那一行就是下一个
    // 评审者会看见的东西。**一刀切会挡住合理需求，名单不会。**
    //
    // 我一度以「不带 action 的提示没有 persist 这个坑，一刀切会拦掉
    // 合法用法」否掉过收紧。那个反驳**落在规则之外**：它说的是禁止
    // 构造 `SnackBar`，而这里管的是 `SnackBarAction` ——
    // 不带 action 的提示里根本没有它。反例不在规则的论域里。
    final outsiders = <String>[];
    for (final file in libFiles) {
      final rel = _relToLib(file.path);
      if (rel == null) continue;
      final name = rel.split('/').last;
      if (snackBarActionOwners.contains(name)) continue;
      if (file.readAsStringSync().contains('SnackBarAction')) {
        outsiders.add('  - lib/$rel');
      }
    }

    expect(
      outsiders,
      isEmpty,
      reason:
          '带动作的提示请走 `showUndoSnackBar`；确实需要新的一类动作，'
          '就把文件加进 snackBarActionOwners 并写明理由：\n'
          '${outsiders.join('\n')}',
    );
  });

  test('SnackBarAction 名单里的文件都真的在，而且真的构造了它', () {
    // 反僵尸（同白名单那条）：名单锚的是文件名。
    //
    // 但这里多验一层「**真的构造了**」—— 光验文件存在的话，
    // 把入口挪走之后名单会变成一条对着空文件的豁免，
    // 而下一个人以为它还在挡着什么。
    final present = {
      for (final f in _dartFiles('lib')) _norm(f.path).split('/').last: f,
    };
    for (final name in snackBarActionOwners) {
      final file = present[name];
      expect(file, isNotNull, reason: '名单里的 $name 已经不存在了');
      expect(
        file!.readAsStringSync().contains('SnackBarAction'),
        isTrue,
        reason: '$name 已经不构造 SnackBarAction 了，这条豁免该删',
      );
    }
  });

  test('带撤销按钮的 SnackBar 必须显式写 persist: false', () {
    // ## 为什么要一条守卫，而不是「记住就行」
    //
    // Flutter 的 `SnackBar` 里有一行：
    //
    //     persist = persist ?? action != null;
    //
    // **带 action 的提示默认永不自动消失。** 而这个应用里每一条提示
    // 都带「撤销」—— 于是全都是永久的，`duration` 设了也没用
    //（计时器回调第一句就是 `if (snackBar.persist) return;`）。
    //
    // 用户报的原话：「下方的轻提示永远不会消失」。四处提示全中。
    //
    // 这是一条**默认值与我们的意图相反**的 API：不写就是错的，
    // 而错的表现在代码里完全看不出来 —— 那正是该由守卫盯着的形状，
    // 靠「下次记得」是守不住的。
    // ## 两处启发式，写明它们的边界
    //
    // 1. **700 字符的窗口**：从每个 `SnackBar(` 往后看这么多字符。
    //    `SnackBarAction` 若出现在更靠后的位置就看不见了。
    //    实际的提示块都在两百字符以内，留了三倍余量 —— 但这是个
    //    **拍出来的数**，不是分析出来的边界。
    // 2. **`split('SnackBar(')` 会在 `showSnackBar(` 上也切一刀**
    //    （子串命中）。于是切出来的块比真正的构造点**多**。
    //    方向是偏向多报而非漏报 —— 安全的那一侧，
    //    但下一个人调这个窗口时该知道自己在调什么。
    //
    // 两条都是「够不着的写法是有的」那一类，同 `endDate` lint 里
    // 那段名字启发式的说明。写在这儿是为了让边界可见，
    // 不是为了让人以为它管全了。
    final violations = <String>[];
    var scanned = 0;
    for (final file in libFiles) {
      final rel = _relToLib(file.path);
      if (rel == null) continue;
      final text = file.readAsStringSync();
      if (!text.contains('SnackBarAction')) continue;
      scanned++;
      // 一个文件里可能有好几条提示，逐个 `SnackBar(` 块看。
      for (final chunk in text.split('SnackBar(').skip(1)) {
        final head = chunk.length > 700 ? chunk.substring(0, 700) : chunk;
        if (head.contains('SnackBarAction') &&
            !head.contains('persist: false')) {
          violations.add('  - lib/$rel');
        }
      }
    }

    expect(scanned, greaterThan(0), reason: '一个带 SnackBarAction 的文件都没扫到');
    expect(
      violations,
      isEmpty,
      reason:
          '这几处的提示会永远挂在屏幕底部，并把后面的提示堵在队列里：\n'
          '${violations.join('\n')}',
    );
  });

  test('lib/ 下有可供扫描的源码（守卫不能对着空目录报绿）', () {
    expect(libFiles, isNotEmpty, reason: '守卫扫描到 0 个文件时，它的「通过」没有任何信息量');
  });

  test('lib/ 下每个文件都必须被分类到某一层（否则守卫对它静默失效）', () {
    final unclassified = <String>[];
    for (final file in libFiles) {
      final rel = _relToLib(file.path);
      if (rel == null || _isGeneratedPath(rel)) continue;
      if (!rel.contains('/') && _unlayeredAllowList.contains(rel)) continue;
      if (_classify(rel) == null) unclassified.add(rel);
    }
    expect(
      unclassified,
      isEmpty,
      reason:
          '以下 ${unclassified.length} 个文件不属于任何一层，所有分层规则对它们静默失效：\n'
          '${unclassified.map((f) => '  - lib/$f').join('\n')}\n'
          '要么放进 module-map §1 的目录结构，要么在 _unlayeredAllowList 显式豁免并说明理由。',
    );
  });

  test('NFR-MAINT-01 分层依赖与跨 feature 规则（module-map §3）', () {
    final violations = <String>[];
    for (final file in libFiles) {
      final rel = _relToLib(file.path);
      if (rel == null) continue;
      for (final imp in _importUris(file.readAsStringSync())) {
        for (final rule in checkImport(rel, imp.uri, isExport: imp.isExport)) {
          violations.add(
            '  - lib/$rel:${imp.lineNo}\n      ${imp.raw}\n      违反: $rule',
          );
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: '发现 ${violations.length} 处违规：\n${violations.join('\n')}',
    );
  });

  test('领域层与应用层不得直接读环境时钟（cross-cutting §1.2）', () {
    final patterns = <RegExp, String>{
      RegExp(r'\bDateTime\s*\.\s*now\s*\('): 'DateTime.now()',
      RegExp(r'\bDateTime\s*\.\s*timestamp\s*\('): 'DateTime.timestamp()',
      RegExp(r'\bDateTime\s*\.\s*now\b(?!\s*\()'): 'DateTime.now 的 tear-off',
    };
    final violations = <String>[];
    for (final file in libFiles) {
      final rel = _relToLib(file.path);
      if (rel == null) continue;
      final layer = _classify(rel)?.layer;
      if (!clockRestrictedLayers.contains(layer)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trim().startsWith('//')) continue;
        for (final e in patterns.entries) {
          if (e.key.hasMatch(lines[i])) {
            violations.add(
              '  - lib/$rel:${i + 1}\n      ${lines[i].trim()}\n'
              '      违反: ${e.value} 直接读环境时钟；必须经注入的 Clock',
            );
          }
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: '发现 ${violations.length} 处直接读环境时钟：\n${violations.join('\n')}',
    );
  });

  test('测试代码不得使用真实时钟（testing-strategy §4）', () {
    // 白名单锚定确切文件名，不做子串匹配。每条都有理由：白名单是守卫的盲区。
    const allowedFileNames = {
      'id_generator_test.dart', // 验证的正是 v7 时间戳与真实时刻相符
      'rrule_library_contract_test.dart', // 验证外部库既有行为
      'layer_dependency_test.dart', // 守卫自身，源码含要搜的字面量
    };
    final violations = <String>[];
    for (final file in testFiles) {
      if (allowedFileNames.contains(_norm(file.path).split('/').last)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trim().startsWith('//')) continue;
        // 去掉字符串字面量再匹配。
        //
        // 不去的话，测试**标题**里提一句 DateTime.now() 就会被判违规 ——
        // 实测踩到过：clock_and_result_test.dart 里那条
        // 「SystemClock 返回 UTC —— 全项目唯一允许 ... 的地方」被误报，
        // 而它实际调用的是 SystemClock().nowUtc()。
        //
        // 守卫误报的代价不只是烦：它会训练人改测试标题去迁就守卫，
        // 或者干脆把文件加进白名单 —— 后者是真正的损失。
        if (RegExp(r'\bDateTime\s*\.\s*(now|timestamp)\s*\(')
            .hasMatch(_stripStringLiterals(lines[i]))) {
          violations.add(
            '  - ${_norm(file.path)}:${i + 1}\n      ${lines[i].trim()}\n'
            '      违反: 测试必须注入 FixedClock 或用 fake_async',
          );
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: '发现 ${violations.length} 处测试使用真实时钟：\n${violations.join('\n')}',
    );
  });

  test('领域层与数据层不得用 assert 表达不变量（cross-cutting §3.1）', () {
    final violations = <String>[];
    for (final file in libFiles) {
      final rel = _relToLib(file.path);
      if (rel == null) continue;
      final layer = _classify(rel)?.layer;
      if (!assertRestrictedLayers.contains(layer)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('//')) continue;
        if (RegExp(r'\bassert\s*\(').hasMatch(line)) {
          violations.add(
            '  - lib/$rel:${i + 1}\n      $line\n'
            '      违反: assert 在 release 构建中被剥离；不变量必须显式 throw',
          );
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason:
          '发现 ${violations.length} 处用 assert 表达的不变量：\n${violations.join('\n')}',
    );
  });

  test('NFR-MAINT-02 纯 Dart 验收测试不得沾 Flutter（overview §6，V2 那一格）', () {
    // V2 的桌面小组件跑在后台 isolate、甚至另一个进程，那里没有 binding。
    // 「读取路径不依赖 Widget」这句话必须由**可执行的东西**守住，
    // 否则某次重构顺手 import 了 flutter/foundation，谁也不会注意到。
    //
    // 这条守的是文件自身的 import；传递依赖由 CI 里的 `dart test` 一步守 ——
    // 那一步整条链路上任何一处引入 dart:ui 都会直接编译失败。
    const pureDartTests = ['test/domain/today_digest_pure_dart_test.dart'];

    final violations = <String>[];
    for (final rel in pureDartTests) {
      // 测试从仓库根目录运行，直接用相对路径。
      final file = File(rel);
      expect(file.existsSync(), isTrue, reason: '$rel 不存在 —— 验收用例被删了？');

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        final isImport =
            line.startsWith('import ') || line.startsWith('export ');
        if (!isImport) continue;
        if (RegExp("['\"]package:flutter(_test)?/").hasMatch(line)) {
          violations.add(
            '  - $rel:${i + 1}\n      $line\n'
            '      违反: 该文件必须能在没有 Flutter binding 的环境跑通',
          );
        }
      }
      // 反向确认：它确实用了 package:test，而不是悄悄换回了 flutter_test。
      expect(
        lines.any((l) => l.contains("import 'package:test/test.dart';")),
        isTrue,
        reason: '$rel 必须用 package:test —— 换成 flutter_test 就失去了验收意义',
      );
    }

    expect(
      violations,
      isEmpty,
      reason: '纯 Dart 验收测试沾了 Flutter：\n${violations.join('\n')}',
    );
  });

  test('写操作必须经由命令管道（overview §4、§6 V4 那一格）', () {
    // 「所有数据变更走同一条 TaskCommand 管道」是 V3 云同步与 V4 Agent 的前提。
    // 这句话只写在文档里的话，第一个赶时间的人就会绕过去 ——
    // 而绕过的写不留 change_log 行，要到很久以后的回放测试才暴露。
    //
    // 这条守两件事：
    //  1. Repository 的写方法只能由 dispatcher 与实现自身调用；
    //  2. DAO 的写方法（upsert / softDelete）不得在 data/ 之外出现。
    const repoWriteMethods = [
      'saveTask',
      'saveTaskWithStages',
      'softDeleteTask',
      'restoreTask',
    ];
    const daoWriteMethods = ['upsert', 'softDelete'];

    // 允许调用写方法的文件（相对 lib/）。
    //
    // **白名单要短且每条有理由**。长白名单等于没有白名单 ——
    // 加一行比想清楚容易，于是它会一直长下去。
    const allowedRepoWriters = {
      // 管道本身。
      'domain/commands/command_dispatcher.dart',
      // Repository 实现内部互相调用（如 softDeleteTask 复用 saveTask）。
      'data/repositories/task_repository_impl.dart',
    };
    const allowedDaoWriters = {
      // DAO 基类与各表 DAO 自身。
      'data/database/dao/synced_dao.dart',
      'data/database/dao/table_daos.dart',
      // 导入导出与回放走裸 SQL，不经 DAO —— 它们是「恢复」不是「操作」，
      // 不该再写一遍 outbox。见各自文件的头部注释。
      'data/dto/export_bundle.dart',
      'data/outbox/change_log_replayer.dart',
    };

    /// **Repository 实现是 DAO 的唯一上层调用方** —— 这是一条结构规则，
    /// 按目录判，不按文件名列举。
    ///
    /// 初版把 `data/repositories/task_repository_impl.dart` 写进了上面的
    /// 名单。加第二个仓库（分类）时它当场变红，而那次「违规」是合法的：
    /// 一个仓库实现调它自己的 DAO，正是这一层该干的事。
    ///
    /// 照名单走的话，以后每加一个仓库就机械地补一行 —— 而补一行比想清楚
    /// 容易，于是名单会一直长下去。上面那句「长白名单等于没有白名单」
    /// 说的就是这个，所以这里换成按目录判。
    ///
    /// 范围没有变松：`data/repositories/` 下本来就只放仓库实现，
    /// 而**谁能调仓库的写方法**由 `allowedRepoWriters` 另外管着 ——
    /// FR-AI-01 那条「UI 必须经命令」靠的是那一张表，不是这一张。
    bool isRepositoryImpl(String rel) => rel.startsWith('data/repositories/');

    final violations = <String>[];
    for (final file in _dartFiles('lib')) {
      final rel = _relToLib(file.path);
      if (rel == null) continue;
      final lines = file.readAsLinesSync();

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('//') || line.startsWith('///')) continue;

        for (final m in repoWriteMethods) {
          final calls = RegExp(
            '[._]$m'
            r'\s*\(',
          ).hasMatch(line);
          if (!calls || allowedRepoWriters.contains(rel)) continue;
          violations.add(
            '  - lib/$rel:${i + 1}\n      $line\n'
            '      违反: 仓储写方法 $m 只能经 CommandDispatcher 调用',
          );
        }
        for (final m in daoWriteMethods) {
          final calls = RegExp(
            r'\.'
            '$m'
            r'\s*\(',
          ).hasMatch(line);
          if (!calls ||
              allowedDaoWriters.contains(rel) ||
              isRepositoryImpl(rel)) {
            continue;
          }
          violations.add(
            '  - lib/$rel:${i + 1}\n      $line\n'
            '      违反: DAO 写方法 $m 不得在 data/ 之外直接调用',
          );
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: '发现 ${violations.length} 处绕过命令管道的写：\n${violations.join('\n')}',
    );
  });

  test('上面那条白名单里的文件确实存在 —— 防止白名单变成僵尸', () {
    // 白名单条目对应的文件被删或改名后，那一条就永远匹配不上，
    // 于是守卫在那个位置**静默失效**。这是守卫本身最常见的烂法。
    const whitelisted = [
      'lib/domain/commands/command_dispatcher.dart',
      'lib/data/repositories/task_repository_impl.dart',
      'lib/data/database/dao/synced_dao.dart',
      'lib/data/database/dao/table_daos.dart',
      'lib/data/dto/export_bundle.dart',
      'lib/data/outbox/change_log_replayer.dart',
    ];
    final missing = [
      for (final f in whitelisted)
        if (!File(f).existsSync()) f,
    ];
    expect(missing, isEmpty, reason: '白名单指向已不存在的文件：$missing');
  });
}

/// 去掉一行里的字符串字面量，只留代码部分。
///
/// 粗糙但够用：守卫要判的是「这行代码有没有调用某个 API」，
/// 而字面量里出现同名文本从来不是调用。
/// 不处理跨行的三引号串 —— 目前没有这种用法，出现了再说，
/// 而不是先写一套用不上的完整词法分析。
String _stripStringLiterals(String line) {
  final buffer = StringBuffer();
  String? quote;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (quote == null) {
      if (c == "'" || c == '"') {
        quote = c;
      } else {
        buffer.write(c);
      }
    } else if (c == r'\') {
      i++; // 跳过转义字符，避免 \' 被当成收尾引号
    } else if (c == quote) {
      quote = null;
    }
  }
  return buffer.toString();
}

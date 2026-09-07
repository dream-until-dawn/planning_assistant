/// 分层依赖守卫。
///
/// 强制 docs/01-architecture/module-map.md §3 的依赖规则，以及
/// docs/05-engineering/testing-strategy.md §6 的额外守卫。
///
/// **本文件被变异演练打回过两轮**，两轮的失效方式一次比一次沉默：
///  1. 漏了三条规则 + 一处假阳性 —— 注入违规就能发现。
///  2. 三层 feature 路径（`features/views/gantt/presentation/`）完全不被分类，
///     该目录下**六条规则全部静默失效**，而守卫报绿 —— 注入违规也发现不了，
///     因为违规文件根本没被扫。
///
/// 第 2 类只能靠**结构性断言**兜底，因此有了「每个文件都必须被分类」这条守卫：
/// 它把「未分类 → 静默放行」变成「未分类 → 变红」。
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _packageName = 'planning_assistant';

/// `features/<路径>/<层>/` 中合法的层段。
const _layerSegments = {'presentation', 'application', 'domain'};

/// 不属于任何一层、但允许存在于 `lib/` 下的文件。
/// **这是守卫的豁免名单，每一条都要有理由。**
const _unlayeredAllowList = {
  'main.dart', // 入口，只调 bootstrap
  'app.dart', // MaterialApp 装配
  'bootstrap.dart', // 初始化编排
};

/// 生成目录，不参与分层检查。
bool _isGeneratedPath(String relToLib) =>
    relToLib.startsWith('l10n/generated/');

class Violation {
  Violation(this.file, this.line, this.lineNo, this.rule);

  final String file;
  final String line;
  final int lineNo;
  final String rule;

  @override
  String toString() =>
      '$file:$lineNo\n'
      '      $line\n'
      '      违反: $rule';
}

String _norm(String path) => path.replaceAll(r'\', '/');

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

/// `lib/` 之下的相对路径，如 `features/views/gantt/presentation/x.dart`。
String? _relToLib(String path) {
  final p = _norm(path);
  final i = p.indexOf('lib/');
  return i < 0 ? null : p.substring(i + 4);
}

/// 该文件所属的层与 feature。
///
/// feature 名是**层段之前的完整路径**，因此支持 module-map §1 规定的三层结构
/// （`features/views/gantt/presentation/` 的 feature 是 `views/gantt`）。
/// 第一版固定取第 2 段，导致三层结构一律落进「未分类」而被静默跳过。
({String layer, String? feature})? _classify(String relToLib) {
  const topLevel = {'core', 'domain', 'data', 'platform', 'design'};
  final segs = relToLib.split('/');
  if (segs.length < 2) return null; // lib 根下的文件

  if (topLevel.contains(segs.first)) {
    return (layer: segs.first, feature: null);
  }

  if (segs.first == 'features') {
    // 取**第一个**层段（从下标 2 起，下标 1 至少是 feature 名的一部分）
    for (var i = 2; i < segs.length - 1; i++) {
      if (_layerSegments.contains(segs[i])) {
        return (
          layer: 'feature_${segs[i]}',
          feature: segs.sublist(1, i).join('/'),
        );
      }
    }
  }
  return null;
}

/// 把一条 import 目标归一成「lib 相对路径」。
///
/// 三处匹配（层规则、barrel、跨 feature）共用这一套归一化，
/// 而不是各自对原始字符串做子串匹配 —— 后者会被相对路径绕过：
/// `import '../../settings/presentation/x.dart'` 里根本没有 `features/` 字样。
///
/// 外部包（`package:flutter/…`、`dart:…`）原样返回，供 `package:flutter/` 之类的模式匹配。
String _resolveImport(String target, String fromFileRelToLib) {
  const selfPrefix = 'package:$_packageName/';
  if (target.startsWith(selfPrefix)) {
    return target.substring(selfPrefix.length);
  }
  if (target.startsWith('package:') || target.startsWith('dart:')) {
    return target;
  }

  final fromDir = fromFileRelToLib.split('/')..removeLast();
  final out = <String>[...fromDir];
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

/// 用于模式匹配的形态：lib 相对路径前加 `/`，外部包保持原样。
String _matchable(String resolved) =>
    resolved.startsWith('package:') || resolved.startsWith('dart:')
    ? resolved
    : '/$resolved';

final _importRe = RegExp('''^(?:import|export)\\s+['"]([^'"]+)['"]''');

/// 该文件的全部 import/export，已归一。
List<({int lineNo, String raw, String resolved})> _imports(
  File file,
  String relToLib,
) {
  final out = <({int lineNo, String raw, String resolved})>[];
  final lines = file.readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    final m = _importRe.firstMatch(lines[i].trim());
    if (m == null) continue;
    out.add((
      lineNo: i + 1,
      raw: lines[i].trim(),
      resolved: _resolveImport(m.group(1)!, relToLib),
    ));
  }
  return out;
}

List<String> _withBarrel(String dirPattern) {
  final trimmed = dirPattern.substring(0, dirPattern.length - 1);
  return [dirPattern, '$trimmed.dart'];
}

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
  'feature_presentation': [
    ('/data/', 'presentation 不得依赖 data'),
    (
      '/domain/repositories/',
      'presentation 不得持有 Repository（写路径必须经 TaskCommand，FR-AI-01）',
    ),
  ],
};

final Map<String, List<(String, String)>> _forbidden = {
  for (final entry in _forbiddenRaw.entries)
    entry.key: [
      for (final (pattern, rule) in entry.value)
        if (pattern.startsWith('/') && pattern.endsWith('/'))
          ...(_withBarrel(pattern).map((p) => (p, rule)))
        else
          (pattern, rule),
    ],
};

void main() {
  final libFiles = _dartFiles('lib');
  final testFiles = _dartFiles('test');

  test('lib/ 下有可供扫描的源码（守卫不能对着空目录报绿）', () {
    expect(libFiles, isNotEmpty, reason: '守卫扫描到 0 个文件时，它的「通过」没有任何信息量');
  });

  test('lib/ 下每个文件都必须被分类到某一层（否则守卫对它静默失效）', () {
    // 这条是 B3 的治本措施。前面那条只保证「有文件被扫」，
    // 它保证「每个文件都被扫」—— 未分类的文件不会触发任何 _forbidden 规则，
    // 而那种失效是沉默的：不被扫描的文件报绿，和干净的文件报绿，观测上无法区分。
    final unclassified = <String>[];
    for (final file in libFiles) {
      final rel = _relToLib(file.path);
      if (rel == null) continue;
      if (_isGeneratedPath(rel)) continue;
      if (!rel.contains('/') && _unlayeredAllowList.contains(rel)) continue;
      if (_classify(rel) == null) unclassified.add(rel);
    }

    expect(
      unclassified,
      isEmpty,
      reason:
          '以下 ${unclassified.length} 个文件不属于任何一层，所有分层规则对它们静默失效：\n'
          '${unclassified.map((f) => '  - lib/$f').join('\n')}\n'
          '要么把它放进 module-map §1 规定的目录结构，'
          '要么在 _unlayeredAllowList 里显式豁免并说明理由。',
    );
  });

  test('分层依赖方向正确（module-map §3）', () {
    final violations = <Violation>[];
    for (final file in libFiles) {
      final rel = _relToLib(file.path);
      if (rel == null) continue;
      final c = _classify(rel);
      final rules = _forbidden[c?.layer];
      if (rules == null) continue;

      for (final imp in _imports(file, rel)) {
        final matchable = _matchable(imp.resolved);
        for (final (pattern, rule) in rules) {
          if (matchable.contains(pattern)) {
            violations.add(
              Violation(_norm(file.path), imp.raw, imp.lineNo, rule),
            );
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          '发现 ${violations.length} 处分层违规：\n'
          '${violations.map((v) => '  - $v').join('\n')}',
    );
  });

  test('feature 之间不得跨 presentation 引用（module-map §3 末行）', () {
    final violations = <Violation>[];
    for (final file in libFiles) {
      final rel = _relToLib(file.path);
      if (rel == null) continue;
      final c = _classify(rel);
      if (c?.layer != 'feature_presentation' || c?.feature == null) continue;

      for (final imp in _imports(file, rel)) {
        // 归一后的路径一定是 features/<feature 路径>/presentation/... 形态，
        // 因此相对 import 与 package: import 走同一条判定。
        final target = _classify(imp.resolved);
        if (target?.layer != 'feature_presentation') continue;
        if (target!.feature == c!.feature) continue;
        violations.add(
          Violation(
            _norm(file.path),
            imp.raw,
            imp.lineNo,
            'feature「${c.feature}」的 presentation 不得引用 feature「${target.feature}」的 '
            'presentation；跨 feature 只能经 application 层的 Provider 通信',
          ),
        );
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          '发现 ${violations.length} 处跨 feature presentation 引用：\n'
          '${violations.map((v) => '  - $v').join('\n')}',
    );
  });

  test('领域层与应用层不得直接读环境时钟（cross-cutting §1.2）', () {
    // 要强制的是规则的**意图**（时间必须可注入），不是它最初被写成的那个字面量。
    // 第一版只匹配 `DateTime.now()`，被 `DateTime.timestamp()` 绕过。
    final patterns = <RegExp, String>{
      RegExp(r'\bDateTime\s*\.\s*now\s*\('): 'DateTime.now()',
      RegExp(r'\bDateTime\s*\.\s*timestamp\s*\('): 'DateTime.timestamp()',
      RegExp(r'\bDateTime\s*\.\s*now\b(?!\s*\()'): 'DateTime.now 的 tear-off',
    };

    final violations = <Violation>[];
    for (final file in libFiles) {
      final rel = _relToLib(file.path);
      if (rel == null) continue;
      final layer = _classify(rel)?.layer;
      if (layer != 'domain' && layer != 'feature_application') continue;

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trim().startsWith('//')) continue;
        for (final entry in patterns.entries) {
          if (entry.key.hasMatch(line)) {
            violations.add(
              Violation(
                _norm(file.path),
                line.trim(),
                i + 1,
                '${entry.value} 直接读环境时钟；必须经注入的 Clock，否则时间相关逻辑无法测试',
              ),
            );
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          '发现 ${violations.length} 处直接读环境时钟：\n'
          '${violations.map((v) => '  - $v').join('\n')}',
    );
  });

  test('测试代码不得使用真实时钟（testing-strategy §4）', () {
    // 白名单锚定到确切文件名，不做子串匹配 ——
    // 否则将来的 task_id_generator_test.dart 之类会被静默豁免。
    // 每一条都必须有理由：白名单是守卫的盲区。
    const allowedFileNames = {
      // 验证的正是「v7 的时间戳与真实时刻相符」，必须用真实时钟
      'id_generator_test.dart',
      // 验证外部库的既有行为，不涉及我们的时间逻辑
      'rrule_library_contract_test.dart',
      // 守卫自身：源码里必然包含要搜的那些字面量
      'layer_dependency_test.dart',
    };

    final violations = <Violation>[];
    for (final file in testFiles) {
      final name = _norm(file.path).split('/').last;
      if (allowedFileNames.contains(name)) continue;

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trim().startsWith('//')) continue;
        if (RegExp(r'\bDateTime\s*\.\s*(now|timestamp)\s*\(').hasMatch(line)) {
          violations.add(
            Violation(
              _norm(file.path),
              line.trim(),
              i + 1,
              '测试必须注入 FixedClock 或用 fake_async，'
              '依赖真实时钟的测试会在特定时刻莫名其妙地红或绿',
            ),
          );
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          '发现 ${violations.length} 处测试使用真实时钟：\n'
          '${violations.map((v) => '  - $v').join('\n')}',
    );
  });

  test('领域层与数据层不得用 assert 表达不变量（cross-cutting §3.1）', () {
    final violations = <Violation>[];
    for (final file in libFiles) {
      final rel = _relToLib(file.path);
      if (rel == null) continue;
      final layer = _classify(rel)?.layer;
      if (layer != 'domain' && layer != 'data') continue;

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('//')) continue;
        if (RegExp(r'\bassert\s*\(').hasMatch(line)) {
          violations.add(
            Violation(
              _norm(file.path),
              line,
              i + 1,
              'assert 在 release 构建中被剥离；不变量必须显式 throw',
            ),
          );
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          '发现 ${violations.length} 处用 assert 表达的不变量：\n'
          '${violations.map((v) => '  - $v').join('\n')}',
    );
  });
}

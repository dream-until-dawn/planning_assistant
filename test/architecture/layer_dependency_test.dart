/// 分层依赖守卫。
///
/// 强制 docs/01-architecture/module-map.md §3 的依赖规则，以及
/// docs/05-engineering/testing-strategy.md §6 的额外守卫。
///
/// 这不是「写着好看」的测试。任何守卫机制建立时都必须当场证明它能失败
/// （testing-strategy §1.4 第 ② 条），且**每次实质性改动后都要重跑变异演练** ——
/// 本文件的第一版就漏掉了三条规则、并产生了一处假阳性，
/// 全部是评审方做变异演练时发现的。演示输出留档在 docs/05-engineering/m0-record.md。
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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

/// `lib/` 之下的相对路径，如 `domain/policies/foo.dart`。
String? _relToLib(String path) {
  final p = _norm(path);
  final i = p.indexOf('lib/');
  return i < 0 ? null : p.substring(i + 4);
}

/// 该文件属于哪一层。
///
/// **按路径前缀判定，不能用任意位置的子串。**
/// 第一版用了子串匹配，导致 `lib/data/repositories/core/x.dart` 因为路径里含
/// `/core/` 被判成 core 层，进而把「data 依赖 domain」这个**正常的依赖倒置方向**
/// 误报为违规。假阳性比漏报更伤守卫 —— 它会训练人去绕开守卫。
String? _layerOf(String path) {
  final rel = _relToLib(path);
  if (rel == null) return null;

  if (rel.startsWith('core/')) return 'core';
  if (rel.startsWith('domain/')) return 'domain';
  if (rel.startsWith('data/')) return 'data';
  if (rel.startsWith('platform/')) return 'platform';
  if (rel.startsWith('design/')) return 'design';

  final m = RegExp(r'^features/([^/]+)/([^/]+)/').firstMatch(rel);
  if (m != null) {
    return switch (m.group(2)) {
      'presentation' => 'feature_presentation',
      'application' => 'feature_application',
      'domain' => 'feature_domain',
      _ => null,
    };
  }
  return null; // lib 根下的 main/app/bootstrap 不属于任何一层
}

/// 该文件属于哪个 feature（非 feature 文件返回 null）。
String? _featureOf(String path) {
  final rel = _relToLib(path);
  if (rel == null) return null;
  return RegExp(r'^features/([^/]+)/').firstMatch(rel)?.group(1);
}

/// 目录模式同时匹配它的 barrel 文件。
///
/// `/domain/repositories/` 只能挡住目录形式的 import；
/// 一旦出现 `lib/domain/repositories.dart` 这样的 barrel 导出文件，
/// `import '.../domain/repositories.dart'` 就绕过去了。
List<String> _withBarrel(String dirPattern) {
  final trimmed = dirPattern.substring(0, dirPattern.length - 1); // 去尾斜杠
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

/// 把 barrel 变体展开进来。
final Map<String, List<(String, String)>> _forbidden = {
  for (final entry in _forbiddenRaw.entries)
    entry.key: [
      for (final (pattern, rule) in entry.value)
        if (pattern.endsWith('/') && pattern != 'package:flutter/')
          ...(_withBarrel(pattern).map((p) => (p, rule)))
        else
          (pattern, rule),
    ],
};

bool _isImportLine(String line) =>
    line.startsWith('import ') || line.startsWith('export ');

void main() {
  final libFiles = _dartFiles('lib');
  final testFiles = _dartFiles('test');

  test('lib/ 下有可供扫描的源码（守卫不能对着空目录报绿）', () {
    expect(libFiles, isNotEmpty, reason: '守卫扫描到 0 个文件时，它的「通过」没有任何信息量');
  });

  test('分层依赖方向正确（module-map §3）', () {
    final violations = <Violation>[];
    for (final file in libFiles) {
      final layer = _layerOf(file.path);
      final rules = _forbidden[layer];
      if (rules == null) continue;

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (!_isImportLine(line)) continue;
        for (final (pattern, rule) in rules) {
          if (line.contains(pattern)) {
            violations.add(Violation(_norm(file.path), line, i + 1, rule));
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
    // 第一版逐格转写 module-map §3 的表格时漏了这一行。
    // 跨 feature 通信只能经 application 层的 Provider。
    final violations = <Violation>[];
    for (final file in libFiles) {
      if (_layerOf(file.path) != 'feature_presentation') continue;
      final own = _featureOf(file.path);
      if (own == null) continue;

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (!_isImportLine(line)) continue;
        final m = RegExp(r'features/([^/]+)/presentation').firstMatch(line);
        if (m != null && m.group(1) != own) {
          violations.add(
            Violation(
              _norm(file.path),
              line,
              i + 1,
              'feature「$own」的 presentation 不得引用 feature「${m.group(1)}」的 '
              'presentation；跨 feature 只能经 application 层的 Provider 通信',
            ),
          );
        }
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
    // 第一版只匹配字面量 `DateTime.now()`，被 `DateTime.timestamp()` 绕过 ——
    // 后者是 dart:core 自 3.0 起的正式 API，同样读环境时钟，
    // 完全落在「时间必须经注入的 Clock 取得」这条规则的意图内。
    // 规则的**意图**才是要强制的东西，不是它最初被写成的那个字面量。
    final patterns = <RegExp, String>{
      RegExp(r'\bDateTime\s*\.\s*now\s*\('): 'DateTime.now()',
      RegExp(r'\bDateTime\s*\.\s*timestamp\s*\('): 'DateTime.timestamp()',
      // tear-off 写法：把函数本身传出去，同样绕过注入
      RegExp(r'\bDateTime\s*\.\s*now\b(?!\s*\()'): 'DateTime.now 的 tear-off',
    };

    final violations = <Violation>[];
    for (final file in libFiles) {
      final layer = _layerOf(file.path);
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
                '${entry.value} 直接读环境时钟；必须经注入的 Clock，'
                '否则时间相关逻辑无法测试',
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
    // 文档里写了这条守卫，此前只写在文档里没有实现 ——
    // 「文档写着有、实际没有的守卫」比没写更危险，它会让人以为已经被拦截了。
    final violations = <Violation>[];
    // 白名单，每一条都必须说明理由 —— 白名单是守卫的盲区，不能随手加：
    //  · id_generator_test         验证的正是「v7 的时间戳与真实时刻相符」，必须用真实时钟
    //  · rrule_library_contract_test 验证外部库的既有行为，不涉及我们的时间逻辑
    //  · layer_dependency_test     守卫自身：它的源码里必然包含要搜的那些字面量，
    //                              否则会把自己的规则定义行报成违规（第一版就是这样）
    final allowed = RegExp(
      r'(id_generator_test|rrule_library_contract_test|layer_dependency_test)',
    );
    for (final file in testFiles) {
      if (allowed.hasMatch(_norm(file.path))) continue;

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
    // Dart 的 assert 在 AOT release 构建中被整条剥离，
    // 用它表达的不变量在正式包里等于不存在。
    final violations = <Violation>[];
    for (final file in libFiles) {
      final layer = _layerOf(file.path);
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

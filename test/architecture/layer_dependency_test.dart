/// 分层依赖守卫。
///
/// 强制 docs/01-architecture/module-map.md §3 的依赖规则，以及
/// docs/05-engineering/testing-strategy.md §6 的三条额外守卫。
///
/// 这不是「写着好看」的测试。M0 的验收标准之一就是**故意写一个违规 import，
/// 确认它变红** —— 任何守卫机制建立时都必须当场证明它能失败，否则它就是
/// 又一个「永远绿的测试」。演示输出留档在 docs/05-engineering/m0-record.md。
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 一条违规记录。
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

/// 源码根目录。测试的工作目录是项目根。
final Directory _libDir = Directory('lib');

/// 收集 lib/ 下所有 .dart 文件（跳过生成产物）。
List<File> _dartFiles() {
  if (!_libDir.existsSync()) {
    return const [];
  }
  return _libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.endsWith('.g.dart'))
      .where((f) => !f.path.endsWith('.freezed.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

String _norm(String path) => path.replaceAll(r'\', '/');

/// 该文件属于哪一层。
String? _layerOf(String path) {
  final p = _norm(path);
  if (p.contains('/core/')) return 'core';
  if (p.contains('/domain/')) return 'domain';
  if (p.contains('/data/')) return 'data';
  if (p.contains('/platform/')) return 'platform';
  if (p.contains('/design/')) return 'design';
  if (RegExp(r'/features/[^/]+/presentation/').hasMatch(p)) {
    return 'feature_presentation';
  }
  if (RegExp(r'/features/[^/]+/application/').hasMatch(p)) {
    return 'feature_application';
  }
  if (RegExp(r'/features/[^/]+/domain/').hasMatch(p)) return 'feature_domain';
  return null;
}

/// 每一层禁止 import 的模式，以及给人看的规则说明。
/// 依据 module-map.md §3 的表格，逐格转写。
const Map<String, List<(String pattern, String rule)>> _forbidden = {
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

void main() {
  final files = _dartFiles();

  test('lib/ 下有可供扫描的源码（守卫不能对着空目录报绿）', () {
    expect(files, isNotEmpty, reason: '守卫扫描到 0 个文件时，它的「通过」没有任何信息量');
  });

  test('分层依赖方向正确（module-map §3）', () {
    final violations = <Violation>[];
    for (final file in files) {
      final layer = _layerOf(file.path);
      if (layer == null) continue;
      final rules = _forbidden[layer];
      if (rules == null) continue;

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (!line.startsWith('import ') && !line.startsWith('export ')) {
          continue;
        }
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

  test('领域层与应用层不得直接调用 DateTime.now()（cross-cutting §1.2）', () {
    final violations = <Violation>[];
    for (final file in files) {
      final layer = _layerOf(file.path);
      if (layer != 'domain' && layer != 'feature_application') continue;

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('DateTime.now()')) {
          violations.add(
            Violation(
              _norm(file.path),
              lines[i].trim(),
              i + 1,
              '时间必须经注入的 Clock 取得，否则时间相关逻辑无法测试',
            ),
          );
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          '发现 ${violations.length} 处直接调用 DateTime.now()：\n'
          '${violations.map((v) => '  - $v').join('\n')}',
    );
  });

  test('领域层与数据层不得用 assert 表达不变量（cross-cutting §3.1）', () {
    // Dart 的 assert 在 AOT release 构建中被整条剥离，
    // 用它表达的不变量在正式包里等于不存在。
    final violations = <Violation>[];
    for (final file in files) {
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

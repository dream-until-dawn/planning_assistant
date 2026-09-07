#!/usr/bin/env dart

// 这是命令行脚本，stdout 就是它的产品，print 是正当输出方式。
// 应用代码里的 avoid_print 仍然生效（走 core/logging 门面）。
// ignore_for_file: avoid_print

/// 坏测试扫描器。
///
/// 实现 docs/05-engineering/testing-strategy.md §3.4：
/// 自动拦截那些**结构上就不可能失败**的测试。
///
/// 它管不了「测试写得好不好」（那靠 §3.1 的变异演练与 code review），
/// 只管一件事：**这条测试有没有可能变红。**
///
/// 与本项目的其它守卫一样，它自带 --self-test：
/// 用已知的坏样本证明自己能正确失败，且不误报好样本。
/// 期望值全部手写，不由被测函数产生（§1.4 第 3 条）。
///
/// 用法：
///   dart tool/lint_tests.dart              扫描 test/ 与 integration_test/
///   dart tool/lint_tests.dart --self-test  先自检，再扫描（CI 用这个）
library;

import 'dart:io';

class Finding {
  Finding(this.file, this.lineNo, this.line, this.rule);
  final String file;
  final int lineNo;
  final String line;
  final String rule;

  @override
  String toString() => '  $rule\n    $file:$lineNo\n      $line';
}

String _norm(String p) => p.replaceAll(r'\', '/');

/// 一个 `test(...)`/`testWidgets(...)` 块的粗略切分。
///
/// 刻意不引入 analyzer 包做完整 AST 解析：这个脚本要在 CI 上快速跑完，
/// 而它要抓的几类问题都是词法层面可见的。代价是对极端排版可能漏判 ——
/// 这一点写在这里，而不是假装它是完备的。
class TestBlock {
  TestBlock(this.startLine, this.name);
  final int startLine;
  final String name;
  final List<String> body = [];
}

List<TestBlock> _splitTests(List<String> lines) {
  final blocks = <TestBlock>[];
  final open = RegExp(r"""^\s*(test|testWidgets)\s*\(\s*['"](.*?)['"]""");
  TestBlock? current;
  var depth = 0;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final m = open.firstMatch(line);
    if (m != null && current == null) {
      current = TestBlock(i + 1, m.group(2) ?? '');
      depth = 0;
    }
    if (current != null) {
      current.body.add(line);
      depth += '('.allMatches(line).length - ')'.allMatches(line).length;
      if (depth <= 0 && current.body.length > 1) {
        blocks.add(current);
        current = null;
      }
    }
  }
  if (current != null) blocks.add(current);
  return blocks;
}

final _assertion = RegExp(r'\b(expect|expectLater|expectSync)\s*\(');
final _commentedAssertion = RegExp(r'^\s*//\s*(expect|expectLater)\s*\(');
final _platformSkip = RegExp(r'if\s*\(\s*(Platform\.|kIsWeb)');
final _bareSkip = RegExp(r'skip\s*:\s*(true|[^,)]*\))');

List<Finding> scan(List<File> files) {
  final findings = <Finding>[];

  for (final file in files) {
    final path = _norm(file.path);
    final lines = file.readAsLinesSync();

    // 1) 被注释掉的断言
    for (var i = 0; i < lines.length; i++) {
      if (_commentedAssertion.hasMatch(lines[i])) {
        findings.add(
          Finding(path, i + 1, lines[i].trim(), '被注释掉的断言 —— 要么删掉整条测试，要么修好它'),
        );
      }
    }

    // 2) 条件跳过：永远绿的经典手法
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().startsWith('//')) continue;
      if (_platformSkip.hasMatch(line) && line.contains('return')) {
        findings.add(
          Finding(
            path,
            i + 1,
            line.trim(),
            '按平台静默跳过 —— 应改用 @TestOn 或 skip: 并附理由',
          ),
        );
      }
    }

    // 3) skip: 未附说明
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().startsWith('//')) continue;
      final m = _bareSkip.firstMatch(line);
      if (m != null && !line.contains("skip: '") && !line.contains('skip: "')) {
        findings.add(
          Finding(
            path,
            i + 1,
            line.trim(),
            'skip 必须附说明字符串（skip: \'原因\'），否则没人知道它为什么被跳过',
          ),
        );
      }
    }

    // 4) 无断言的测试块
    for (final block in _splitTests(lines)) {
      final hasAssertion = block.body.any(
        (l) => !l.trim().startsWith('//') && _assertion.hasMatch(l),
      );
      if (!hasAssertion) {
        findings.add(
          Finding(
            path,
            block.startLine,
            "test('${block.name}')",
            '测试块内没有任何断言 —— 它只能发现崩溃，发现不了错误',
          ),
        );
      }
    }
  }

  return findings;
}

/// 手写的样本与期望。**不得由 scan() 自己产生**（§1.4 第 3 条）。
const _selfTestSource = '''
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('好测试：有断言', () {
    expect(1 + 1, 2);
  });

  test('坏1：没有任何断言', () {
    final x = compute();
    print(x);
  });

  test('坏2：断言被注释掉了', () {
    // expect(1, 2);
    doSomething();
  });

  test('坏3：按平台静默跳过', () {
    if (Platform.isWindows) return;
    expect(1, 1);
  });

  test('坏4：skip 未附理由', () {
    expect(1, 1);
  }, skip: true);
}
''';

bool selfTest() {
  print('--- 自检：坏测试扫描器能否正确失败 ---');
  final dir = Directory.systemTemp.createTempSync('lint_tests_selfcheck');
  try {
    final f = File('${dir.path}/sample_test.dart')
      ..writeAsStringSync(_selfTestSource);
    final findings = scan([f]);

    // 期望：恰好命中 4 类，且不误报第一条好测试
    const expectedRules = ['被注释掉的断言', '按平台静默跳过', 'skip 必须附说明字符串', '测试块内没有任何断言'];
    final hit = {
      for (final r in expectedRules) r: findings.any((f) => f.rule.contains(r)),
    };
    final falsePositive = findings.any((f) => f.line.contains('好测试：有断言'));

    for (final e in hit.entries) {
      print('  ${e.value ? "命中" : "漏报"}: ${e.key}');
    }
    print('  误报好样本: ${falsePositive ? "是" : "否"}');

    final ok = hit.values.every((v) => v) && !falsePositive;
    print(
      ok
          ? '  结果: PASS —— 四类坏测试都能让它变红，好测试不误报'
          : '  结果: FAIL —— 扫描器本身有问题，其对 test/ 的结论一律不可信',
    );
    return ok;
  } finally {
    dir.deleteSync(recursive: true);
  }
}

List<File> _testFiles() {
  final out = <File>[];
  for (final dirName in ['test', 'integration_test']) {
    final d = Directory(dirName);
    if (!d.existsSync()) continue;
    out.addAll(
      d
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('_test.dart')),
    );
  }
  out.sort((a, b) => a.path.compareTo(b.path));
  return out;
}

void main(List<String> args) {
  if (args.contains('--self-test')) {
    if (!selfTest()) exit(2);
    print('');
  }

  final files = _testFiles();
  if (files.isEmpty) {
    stderr.writeln('未找到任何 *_test.dart —— 扫描器对着空集合报绿没有意义');
    exit(2);
  }

  final findings = scan(files);
  print('扫描 ${files.length} 个测试文件');
  if (findings.isEmpty) {
    print('未发现结构上不可能失败的测试。');
    return;
  }
  print('发现 ${findings.length} 处问题：');
  for (final f in findings) {
    print(f);
  }
  exit(1);
}

#!/usr/bin/env dart

// 这是命令行脚本，stdout 就是它的产品，print 是正当输出方式。
// ignore_for_file: avoid_print

/// **门禁自己不得 shell 出去。**
///
/// ## 守的是一条现成的性质，不是一串缺点
///
/// 这个仓库现在有一条**已经成立、且会有人依赖**的性质：
///
/// > 门禁只依赖工作树 —— 拿到一份源码 zip，八道全跑得完。
///
/// 它今天是**碰巧成立**的（扫过：`lib/` `test/` `tool/` 下
/// `Process.run` / `Process.start` / `subprocess` / `os.system` /
/// `shell=True` 五种写法全是 0）。写下来并守住，它才是**刻意保持**的。
///
/// 破坏它的成本不落在那条越界的门禁身上，落在**所有以后指望「拿到源码
/// 就能跑门禁」的人**身上：浅克隆、导出的归档、没有 git 的构建环境里，
/// 一条 shell 出去问 git 的门禁会直接失效，而失效的样子是「报绿」。
///
/// ## 域：`ci.yml` 点名的文件 ∪ 整个 `test/`
///
/// 前半是「谁是门禁」的**单一出处** —— `ci.yml` 的 `run:` 行里写着，
/// 不用在这儿再抄一份。
///
/// 后半是第一版**漏掉的**：`ci.yml` 里那句 `flutter test --coverage`
/// 跑的是**整个 `test/`**，所以 `test/` 下任何一个用例 shell 出去，
/// 「拿到 zip 跑得完」在那道门上就已经破了 —— 与门禁脚本越界是同一个
///后果。现成的例子是两条同样扫工作树的守卫
/// （`component_assertions_test` 与 `clock_and_result_test`），
/// 它们靠大排面的 `flutter test` 跑，`ci.yml` 并不点它们的名。
///
/// **`tool/` 里没被点名的不在域里**（将来的编排脚本），这个收窄是有意的：
/// 一个跑 `flutter test` 的编排脚本本来就该 shell 出去，它不违反上面
/// 那条性质。域划成整个 `tool/` 的话，第一个写编排脚本的人会撞红，
/// 然后去加一条豁免 —— 而那条豁免恰好属于「随守卫同批进来、最可疑」的
/// 那一类。
///
/// **`ci.yml` 自己不在域里**，也不该在：它第 115 行起那段
/// 「守卫有效性」本来就是 shell（注入违规、看守卫红不红）。
/// 域是「它点名的那些文件」，不是「它自己」。
///
/// ## 这个脚本自己也在域里
///
/// `ci.yml` 点了它的名，所以它扫得到自己。于是每一条模式都写成
/// **自己的源文本不构成一个匹配**的形状（见 [kShellPatterns]），
/// 而不是写完再给自己开一条豁免 —— 一条上线第一天就必须存在的豁免，
/// 本身就是「被守的规则」与「现有实现」没对齐的信号。
///
/// 自检里有一条专门盯这件事：**断言这个文件确实在域里、且是绿的。**
/// 少了它，哪天有人把域改窄、守卫悄悄不再扫自己，没有任何信号。
///
/// 用法：
///   dart tool/lint_no_shell.dart              扫描
///   dart tool/lint_no_shell.dart --self-test  先自检，再扫描（CI 用这个）
library;

import 'dart:io';

/// 走出工作树的几种写法。
///
/// **每一条的源文本都不构成它自己的一个匹配** —— 这个文件在自己的域里
/// （见头注）。`Process\s*\.\s*` 中间隔着转义，`sub` 与 `process` 是两个
/// 相邻字面量拼起来的：源码里没有 `Process.run`、也没有那个 python 模块名
/// 的连写形态，而真实调用一律命中。
final List<RegExp> kShellPatterns = [
  RegExp(r'Process\s*\.\s*(run|start)'), // dart:io
  RegExp(
    r'sub'
    r'process',
  ), // python
  RegExp(r'os\s*\.\s*(system|popen)'), // python
  RegExp(r'shell\s*=\s*True'), // python
];

class Finding {
  Finding(this.file, this.lineNo, this.line);

  final String file;
  final int lineNo;
  final String line;

  @override
  String toString() =>
      '  门禁走出了工作树\n'
      '    $file:$lineNo\n'
      '      ${line.trim()}';
}

String norm(String p) => p.replaceAll(r'\', '/');

/// `ci.yml` 的 `run:` 行里点名的项目文件。
///
/// 从文件本身算出来，不在这儿抄一份名单 —— 抄的那份会过期，
/// 而过期的名单**看起来仍然像一份名单**。
Set<String> gatesNamedInCi(String ciYaml) {
  final named = RegExp(
    r'(?:tool|test|integration_test)/[A-Za-z0-9_/.]+\.(?:py|dart)',
  );
  return {for (final m in named.allMatches(ciYaml)) m.group(0)!};
}

/// 域 = `ci.yml` 点名的 ∪ 整个 `test/`。见头注。
List<String> domain({required String ciYaml, required Directory repoRoot}) {
  final out = <String>{...gatesNamedInCi(ciYaml)};
  final testDir = Directory('${repoRoot.path}/test');
  if (testDir.existsSync()) {
    for (final f in testDir.listSync(recursive: true).whereType<File>()) {
      final rel = norm(f.path).split('${norm(repoRoot.path)}/').last;
      if (rel.endsWith('.dart') || rel.endsWith('.py')) out.add(rel);
    }
  }
  final list = out.toList()..sort();
  return list;
}

List<Finding> scanSource(String path, String src) {
  final out = <Finding>[];
  final lines = src.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    // 注释里提到名字不算 —— 这一族的说明文字里必然会提到它们。
    final code = line.replaceAll(RegExp(r'(//|#).*$'), '');
    if (kShellPatterns.any((p) => p.hasMatch(code))) {
      out.add(Finding(path, i + 1, line));
    }
  }
  return out;
}

/// 自检。期望值全部手写。
bool selfTest(List<String> realDomain, Map<String, String> realSources) {
  print('--- 自检：门禁越界扫描器能否正确失败 ---');
  var ok = true;

  // ① 四种写法都要命中。
  //
  // **四个样本都得拼出来，一个都不能少。** 头一版只拼了前两个，
  // 后两个照着直觉写成了字面量 —— 自检当场报「扫自己不是绿的」，
  // 指着这两行。这个文件在自己的域里，所以**任何一处**写成连写形态
  // 都会让它自己变成一处违规，然后逼人去开一条豁免。
  // 那正是这条守卫存在的理由的反面。
  const p = 'Process';
  const s = 'sub';
  const os = 'os.';
  const sh = 'shell=';
  final samples = <String, String>{
    'dart': "final r = await $p.run('git', []);",
    'python-mod': 'import ${s}process',
    'python-os': '${os}system("git rev-parse HEAD")',
    'python-shell': 'check_output(cmd, ${sh}True)',
  };
  for (final e in samples.entries) {
    final hit = scanSource('sample.dart', e.value).isNotEmpty;
    print('  命中 ${e.key}: ${hit ? "是" : "漏报"}');
    if (!hit) ok = false;
  }

  // ② 注释里提到名字不该命中。
  final falsePositive = scanSource(
    'sample.dart',
    '// 这里说明为什么不用 $p.run\n#  也不用 ${s}process\n',
  );
  print('  误报注释: ${falsePositive.isEmpty ? "否" : "是"}');
  if (falsePositive.isNotEmpty) ok = false;

  // ③ **这个脚本自己必须在域里，而且是绿的。**
  //    少了这一条，哪天域被改窄、守卫悄悄不再扫自己，没有任何信号。
  const me = 'tool/lint_no_shell.dart';
  final inDomain = realDomain.contains(me);
  print('  自己在域里: ${inDomain ? "是" : "否 —— 域被改窄了？"}');
  if (!inDomain) ok = false;
  if (inDomain) {
    final onMe = scanSource(me, realSources[me] ?? '');
    print('  扫自己是绿的: ${onMe.isEmpty ? "是" : "否 → $onMe"}');
    if (onMe.isNotEmpty) ok = false;
  }

  // ④ ci.yml 自己不该在域里 —— 它那段「守卫有效性」本来就是 shell。
  final ciInDomain = realDomain.any((p) => p.endsWith('ci.yml'));
  print('  ci.yml 不在域里: ${ciInDomain ? "否 —— 会误报" : "是"}');
  if (ciInDomain) ok = false;

  print(
    ok
        ? '  结果: PASS —— 四种越界写法会红，注释不误报，且它确实在扫自己'
        : '  结果: FAIL —— 扫描器本身有问题，它对门禁的结论一律不可信',
  );
  return ok;
}

void main(List<String> args) {
  final root = Directory.current;
  final ci = File('${root.path}/.github/workflows/ci.yml');
  if (!ci.existsSync()) {
    stderr.writeln('找不到 .github/workflows/ci.yml —— 域是从它算出来的');
    exit(2);
  }

  final files = domain(ciYaml: ci.readAsStringSync(), repoRoot: root);
  final sources = <String, String>{};
  for (final rel in files) {
    final f = File('${root.path}/$rel');
    if (f.existsSync()) sources[rel] = f.readAsStringSync();
  }

  if (args.contains('--self-test')) {
    if (!selfTest(files, sources)) exit(2);
    print('');
  }

  if (sources.isEmpty) {
    stderr.writeln('域是空的 —— 扫描器对着空集合报绿没有意义');
    exit(2);
  }

  final findings = <Finding>[];
  sources.forEach((rel, src) => findings.addAll(scanSource(rel, src)));

  print('扫描 ${sources.length} 个门禁路径上的文件（ci.yml 点名的 ∪ test/）');
  if (findings.isEmpty) {
    print('门禁没有走出工作树 —— 拿到一份源码 zip 仍然跑得完。');
    return;
  }
  print('发现 ${findings.length} 处：');
  for (final f in findings) {
    print(f);
  }
  print('');
  print('这条性质在 docs/05-engineering/testing-strategy.md §3.6。');
  print('真需要工作树以外的信息，那件事就不该由门禁来做。');
  exit(1);
}

#!/usr/bin/env dart

// 这是命令行脚本，stdout 就是它的产品，print 是正当输出方式。
// ignore_for_file: avoid_print

/// 非 raw 字符串字面量里的**可疑反斜杠**扫描器。
///
/// ## 它防的是哪一族
///
/// Dart 的普通字符串会**吃掉**反斜杠，而且一声不吭：
///
/// ```dart
/// '\b'   →  退格符 0x08      // 不是正则的单词边界
/// '\s'   →  's'              // 反斜杠被静默丢掉
/// '\d'   →  'd'
/// ```
///
/// 写正则时把 `r'...'` 忘掉，得到的是一个**匹配不到任何东西**的正则，
/// 而编译期、运行期都不报错。这个项目里已经发生过**六次**，
/// 六次全部只能靠事后「注入一次看它红」才发现 ——
/// 语言在这里不给任何信号，纪律没有可依附的东西（testing-strategy §3.5）。
///
/// ## 判据是白名单，不是「禁止裸反斜杠」
///
/// 立这条规矩时记下的判据是「非 raw 字面量里不得出现裸反斜杠
/// （`\'` `\"` `\\` 除外）」。**那是没量过人口就写下的**：
/// 真去扫一遍，仓库里 92 处反斜杠里有 77 处是 `\n` —— 一条正当到不能再
/// 正当的换行。按那条判据，这个守卫上线第一天就要报 77 处误伤，
/// 而按 M0 那条「守卫的假阳性比漏报更伤」，它上线就是净损失。
///
/// 所以改成**允许清单**：只放行那些**除了当文本别无解释**的转义。
///
/// | 放行 | 因为 |
/// |---|---|
/// | `\n` `\r` `\t` `\f` `\v` | 空白字符，写在文案里天经地义 |
/// | `\'` `\"` | 引号本身，与字符串定界符冲突时必须转义 |
/// | `\$` | 挡住插值 |
/// | `\\` | 反斜杠本身（`replaceAll('\\', '/')` 这一类）|
/// | `\x..` `\u....` | 明写的码点，不会被误当成正则 |
///
/// **`\b` 不在放行清单里，虽然它是合法的 Dart 转义。**
///
/// 一度写的理由是「退格符出现在这个项目的任何字符串里都不可能是有意的」
/// —— 那是一个**不可证的全称**，正是这个项目栽过的那一类。
/// 换成一句局部的、可证伪的（评审给的）：
///
/// > 不是「不存在正当用法」，是**每一种正当用法都有一个已经放行的写法**：
/// > 真要一个退格符，写 `\x08` 或 `\u0008` —— 两个都在清单里，
/// > 而且比 `\b` **更说明意图**。
///
/// 谁能举出一个「`\x08` 比 `\b` 更糟」的场合，这条就该改。
/// 那个出口也写进了失败输出里，不用他来问。
///
/// 「语法上合法」与「这里想要的」是两件事，而这一族的全部危害
/// 正来自前者掩盖了后者。
///
/// ## 域
///
/// `lib/` `test/` `tool/` 下所有 `.dart` —— **包括这个文件自己**。
/// 所以它的自检样本不能作为字面量写在这儿（那会打到自己），
/// 而是用字符码拼出来、写进临时目录再扫。见 [selfTest]。
///
/// ## 行尾：这一条天生安全，但理由要写出来
///
/// 它**不靠正则剥注释**，而是逐字符走词法（`nonRawLiterals`），
/// 遇到 `//` 就一直吃到换行 —— 回车符落在注释里被一并吃掉。
/// 所以 CRLF 的源文件对它没有影响（评审在全新克隆上验过）。
///
/// 同一批里那两个**用正则剥注释**的扫描器都栽了：Dart 的 `.` 不匹配
/// 回车符，`//.*` 加行尾锚在 CRLF 上一个字符都换不掉。
/// 判据见 testing-strategy §1.19.1 —— **自己剥注释的，夹具里必须有
/// 一个 CRLF 样本**。这里安全是因为写法不同，不是因为运气好。
///
/// ## 不完备的地方，写出来而不假装没有
///
/// 刻意不引入 analyzer 做完整 AST：这个脚本要在 CI 上几秒钟跑完，
/// 而它要抓的东西是**词法层面**可见的。代价是插值 `${...}` 里嵌套的
/// 字符串会被当成外层字面量的一部分 —— 那种写法真出现时可能多报一次。
/// 仓库现状里没有（扫过）。
///
/// 用法：
///   dart tool/lint_dart_escapes.dart              扫描
///   dart tool/lint_dart_escapes.dart --self-test  先自检，再扫描（CI 用这个）
library;

import 'dart:io';

/// 反斜杠后面允许出现的字符。见头注那张表。
const Set<String> kAllowedAfterBackslash = {
  'n', 'r', 't', 'f', 'v', // 空白
  "'", '"', // 引号
  r'$', // 挡插值
  r'\', // 反斜杠自己
  'x', 'u', // 码点
};

class Finding {
  Finding(this.file, this.lineNo, this.escape, this.excerpt);

  final String file;
  final int lineNo;
  final String escape;
  final String excerpt;

  @override
  String toString() =>
      '  非 raw 字面量里的 \\$escape —— 反斜杠会被静默处理掉\n'
      '    $file:$lineNo\n'
      '      $excerpt';
}

/// 一段非 raw 字面量：**转义原样保留**（`\n` 是两个字符）。
class StringLiteral {
  StringLiteral(this.body, this.line);

  final String body;
  final int line;
}

const String _bs = r'\';

/// 把源码里的非 raw 字符串字面量切出来。
///
/// 注释先于字符串判断，所以 `// don't` 里那个撇号不会开一个串；
/// 而 `'https://x'` 里的 `//` 落在串内，也不会开一段注释。
List<StringLiteral> nonRawLiterals(String src) {
  final out = <StringLiteral>[];
  var i = 0;
  var line = 1;
  final n = src.length;

  while (i < n) {
    final c = src[i];
    if (c == '\n') {
      line++;
      i++;
      continue;
    }
    if (c == '/' && i + 1 < n && src[i + 1] == '/') {
      while (i < n && src[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && i + 1 < n && src[i + 1] == '*') {
      i += 2;
      while (i + 1 < n && !(src[i] == '*' && src[i + 1] == '/')) {
        if (src[i] == '\n') line++;
        i++;
      }
      i += 2;
      continue;
    }

    var raw = false;
    var j = i;
    if (c == 'r' && i + 1 < n && (src[i + 1] == "'" || src[i + 1] == '"')) {
      raw = true;
      j = i + 1;
    }
    if (j < n && (src[j] == "'" || src[j] == '"')) {
      final q = src[j];
      final triple = j + 3 <= n && src.substring(j, j + 3) == q * 3;
      final delim = triple ? q * 3 : q;
      final startLine = line;
      var k = j + delim.length;
      final body = StringBuffer();

      while (k < n) {
        if (!raw && src[k] == _bs && k + 1 < n) {
          body.write(src[k]);
          body.write(src[k + 1]);
          if (src[k + 1] == '\n') line++;
          k += 2;
          continue;
        }
        if (k + delim.length <= n &&
            src.substring(k, k + delim.length) == delim) {
          k += delim.length;
          break;
        }
        if (src[k] == '\n') {
          line++;
          // 单引号串不跨行；跨了说明前面解析错位了，就地收住，
          // 免得把半个文件当成一个字面量。
          if (!triple) break;
        }
        body.write(src[k]);
        k++;
      }

      if (!raw) out.add(StringLiteral(body.toString(), startLine));
      i = k;
      continue;
    }
    i++;
  }
  return out;
}

List<Finding> scanSource(String path, String src) {
  final out = <Finding>[];
  for (final lit in nonRawLiterals(src)) {
    final b = lit.body;
    for (var k = 0; k < b.length - 1; k++) {
      if (b[k] != _bs) continue;
      final next = b[k + 1];
      if (!kAllowedAfterBackslash.contains(next)) {
        final from = (k - 12).clamp(0, b.length);
        final to = (k + 14).clamp(0, b.length);
        out.add(Finding(path, lit.line, next, '…${b.substring(from, to)}…'));
      }
      k++; // 跳过被转义的那个字符
    }
  }
  return out;
}

String _norm(String p) => p.replaceAll(_bs, '/');

/// 自检。
///
/// **样本用字符码拼出来，不写成字面量** —— 这个扫描器的域包含
/// `tool/`，也就包含它自己。把 `'\s'` 作为常量写在这儿的话，
/// 它上线第一天就得给自己开一条豁免，而那种豁免恰恰是最可疑的一类
/// （守卫与被守的规则一开始就没对齐）。
///
/// 期望值全部手写，不由被扫函数产生。
bool selfTest() {
  print('--- 自检：可疑转义扫描器能否正确失败 ---');
  final dir = Directory.systemTemp.createTempSync('lint_escapes_selfcheck');
  try {
    // 坏样本：非 raw 串里的 \s 与 \b。
    const bad =
        "final a = RegExp('$_bs${'s'}+');\n"
        "final b = RegExp('$_bs${'b'}word');\n";
    // 好样本：raw 串里的 \s、文案里的 \n、转义引号、以及反斜杠自己。
    const good =
        "final c = RegExp(r'$_bs${'s'}+');\n"
        "final d = '第一行$_bs${'n'}第二行';\n"
        "final e = 'it$_bs${"'"}s';\n"
        "final f = path.replaceAll('$_bs$_bs', '/');\n"
        "// 注释里的 $_bs${'s'} 不算\n";

    final badFindings = scanSource('bad.dart', bad);
    final goodFindings = scanSource('good.dart', good);

    final caught = {for (final f in badFindings) f.escape};
    final missS = !caught.contains('s');
    final missB = !caught.contains('b');

    print('  命中 \\s: ${missS ? "漏报" : "是"}');
    print('  命中 \\b: ${missB ? "漏报" : "是"}');
    print('  误报好样本: ${goodFindings.isEmpty ? "否" : "是 → $goodFindings"}');

    final ok = !missS && !missB && goodFindings.isEmpty;
    print(
      ok
          ? '  结果: PASS —— 吃得掉的转义会红，正当转义与 raw 串不误报'
          : '  结果: FAIL —— 扫描器本身有问题，它对仓库的结论一律不可信',
    );
    return ok;
  } finally {
    dir.deleteSync(recursive: true);
  }
}

List<File> _sources() {
  final out = <File>[];
  for (final dirName in ['lib', 'test', 'tool', 'integration_test']) {
    final d = Directory(dirName);
    if (!d.existsSync()) continue;
    out.addAll(
      d
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
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

  final files = _sources();
  if (files.isEmpty) {
    stderr.writeln('一个 .dart 都没扫到 —— 扫描器对着空集合报绿没有意义');
    exit(2);
  }

  final findings = <Finding>[];
  for (final f in files) {
    findings.addAll(scanSource(_norm(f.path), f.readAsStringSync()));
  }

  print('扫描 ${files.length} 个 dart 文件');
  if (findings.isEmpty) {
    print('非 raw 字面量里没有会被静默吃掉的转义。');
    return;
  }
  print('发现 ${findings.length} 处：');
  for (final f in findings) {
    print(f);
  }
  print('');
  print('改法（按你实际想要的那个选）：');
  print('  · 想写正则   → 把字面量写成 raw 串：r\'…\'');
  print('  · 想要那个字符 → 用明写的码点：\\x08 / \\u0008 —— 两个都放行，');
  print('    而且比 \\b 更说明意图。');
  print('出口写在这儿，是因为「真想要一个退格符」的人，照前一条改不出他要的');
  print('东西，只会去加一条豁免 —— 而这一族本来就不需要任何豁免。');
  exit(1);
}

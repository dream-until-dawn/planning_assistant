/// **`await` 之后再用 `ref`，必须先确认这一页还在树上**（testing-strategy §3.9）。
///
/// ## 为什么现成的 lint 盖不住这一半
///
/// `analysis_options.yaml` 引的 `flutter_lints` 里有
/// `use_build_context_synchronously` —— 它盯的是 **`BuildContext`**，
/// 不盯 `ref`。而两者的失效后果一模一样：它们绑在**同一个 Element** 上，
/// 那个 Element 没了，两者一起失效。
///
/// 后果不是理论上的。M4 收尾时 `backup_page.dart` 的 `_backupNow` 里
/// 写着这么一句注释：
///
/// > messenger 先取：await 之后 context 可能已经不在树上了。
///
/// —— 作者**知道**这条原理，为 `context` 做了规避，然后在**同一个函数里**
/// 对 `ref` 犯了同一个错（`ref.invalidate` 在 await 之后、无守卫）。
/// 三处漏的都只碰 `ref`，唯一带守卫的那处恰好碰了 `context`。
///
/// **知道原理并不能覆盖到工具没照到的那一半。** 这条守卫补的就是那一半：
///
/// > `use_build_context_synchronously` 的域是 `context`，
/// > 而这个项目真实的危险面是 `context` ∪ `ref`。
///
/// ## 判据与它的近似
///
/// 在同一个块里，`await` 之后出现 `ref.`，而中间没有任何 `mounted` 检查
/// —— 就报。判据按**块深度**收尾：离开那个块，警戒解除。
///
/// 三条**必须**分辨清楚的形状（每一条都是踩出来的，各自有夹具）：
///
/// | 写法 | 判 | 因为 |
/// |---|---|---|
/// | `await ref.read(x).f()`（本块第一次挂起） | 不报 | `EXPR` 先求值再挂起 |
/// | `await a(); await ref.read(b).f();` | **报** | 上一次挂起已经发生了 |
/// | `if (await c()) ref.x;` | **报** | `await` 在一对先于它打开的括号里，括号闭合之后就是挂起之后 |
///
/// 另外两条：`case` 标签另起执行路径（Dart 的 switch 不贯穿），
/// 以及**源文件是 CRLF**（`.` 不匹配回车符，不先归一化的话注释剥不掉）。
///
/// 刻意不引入 analyzer 做完整 AST（同 `lint_tests.dart` 的取舍）。
/// 剩下的代价写在这儿而不是假装没有：`await` 在嵌套闭包里、
/// `ref` 在闭包外，可能**多报**。
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 一处可疑的 `ref` 使用。
typedef RefUse = ({String file, int line, String text});

final _awaitAt = RegExp(r'\bawait\s');
final _refUse = RegExp(
  r'\bref\s*\.\s*(read|watch|invalidate|listen|refresh)\b',
);
final _mountedCheck = RegExp(r'\bmounted\b');

/// 扫一段源码。见头注的判据与近似。
List<RefUse> scanSource(String path, String src) {
  final out = <RefUse>[];
  // **先把 \r 去掉。** 这个仓库的工作树是 CRLF，而 Dart 的 `.`
  // **不匹配 `\r`** —— 于是 `//.*$` 永远够不到行尾，`replaceAll` 一个字符
  // 都不换：**注释从来没被剥掉过**。
  //
  // 它藏得住，是因为自检样本是写在 dart 源码里的字符串，只有 `\n`。
  // **夹具与真实文件的行尾不一样，于是自检看不见真实文件上的失效。**
  // 症状是三处误报，而它们的共同点是「上面的文档注释里有 await 两个字」。
  final lines = src.replaceAll('\r', '').split('\n');
  var depth = 0;
  int? armedAt; // 在哪个深度上「await 过了」

  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final code = raw.replaceAll(RegExp(r'//.*$'), '');

    // 出现 mounted 检查 → 警戒解除。
    if (_mountedCheck.hasMatch(code)) armedAt = null;

    // 警戒已拉响时，这一行上的任何 `ref` 使用都要报。
    //
    // ## 这里一度有一条豁免，它是错的（评审 R-1）
    //
    // 曾经写着「同一行里 `await` 排在 `ref` 前面的一律安全」，理由是
    // 「那一下的 `ref` 发生在这次挂起之前」。**那句话本身没错，但它答的
    // 不是安全性要问的问题。**
    //
    // 安全性问的是：这个 `ref` 是不是排在**此前每一次**挂起之前。
    // 而 `armedAt != null` 的意思就是「早先已经挂起过了」——
    // **同一行的 await 对更早的那次挂起一个字都没说。**
    //
    // 那条豁免于是放走了真缺陷：`reminder_status_card` 里两处
    // 「等系统权限弹窗 / 跳去系统设置页回来之后再 `ref.read`」，
    // 挂起窗口是这个应用里最宽的一个。
    //
    // 删掉它不会伤到任何真安全的写法：真安全的那种（本行的 `await ref`
    // 是**本块第一次**挂起）本来就因为 `armedAt == null` 而不会被报。

    // `case` / `default` 标签**另起一条执行路径**：Dart 的 switch 不贯穿，
    // 所以上一个 case 里的挂起对这一个 case 一个字都没说。
    // 只在**同层**的标签上解除（`depth <= armedAt`）—— 挂起发生在 switch
    // **之前**时，armedAt 更小，那些标签就不该解除它。
    final branchLabel = RegExp(r'^\s*(case\b|default\s*:)').hasMatch(code);
    if (branchLabel && armedAt != null && depth <= armedAt) armedAt = null;

    if (armedAt != null && _refUse.hasMatch(code)) {
      out.add((file: path, line: i + 1, text: raw.trim()));
      armedAt = null; // 一个块里报一次就够，不刷屏
    } else {
      // **本行自己的 await 之后再用 ref，同样要报。**
      //
      // 「先判使用再上警戒」对 `await ref.read(x)` 是对的（那个 ref 在挂起
      // 之前），但它顺带让**整整一族**永远不报：
      //
      //     if (await cond()) ref.invalidate(p);      // 单行 if
      //     while (await next()) ref.read(p);
      //
      // 这两种在本仓库合法且常见（`lib/` 里现有 300 多处无花括号的单行
      // 流程语句），而 `ref` 明明排在挂起之后。评审点名的 A/F 两个样本。
      // **靠括号深度分辨，不能只比位置。**
      //
      // `await EXPR` 是先把 EXPR 求值、再挂起，所以
      // `await ref.read(x).run()` 里那个 ref 在挂起之前 —— 安全，
      // 尽管它在 `await` 后面。
      //
      // 而 `if (await c()) ref.x;` 里，`await` 被包在一对**先于它打开**的
      // 括号里；那对括号一闭合，后面的东西就在挂起之后了。
      // 判据于是是：**await 所在的括号闭合之后，还有没有 ref。**
      final aw = _awaitAt.firstMatch(code);
      if (aw != null) {
        var paren = 0;
        for (var k = 0; k < aw.start; k++) {
          if (code[k] == '(') paren++;
          if (code[k] == ')') paren--;
        }
        if (paren > 0) {
          // 找那对括号的闭合处。
          var k = aw.start;
          var d = paren;
          for (; k < code.length; k++) {
            if (code[k] == '(') d++;
            if (code[k] == ')') {
              d--;
              if (d < paren) break;
            }
          }
          final after = k < code.length ? code.substring(k) : '';
          if (_refUse.hasMatch(after)) {
            out.add((file: path, line: i + 1, text: raw.trim()));
          }
        }
      }
    }

    if (_awaitAt.hasMatch(code)) armedAt = armedAt ?? depth;

    for (final c in code.split('')) {
      if (c == '{') depth++;
      if (c == '}') depth--;
    }
    if (armedAt != null && depth < armedAt) armedAt = null;
  }
  return out;
}

List<File> _libSources() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
        .toList();

void main() {
  test('前提：扫得到文件（守卫不对着空集合报绿）', () {
    expect(_libSources().length, greaterThan(100), reason: '扫少了，多半路径错了');
  });

  test('NFR-REL-01 lib/ 里没有「await 之后不判 mounted 就用 ref」', () {
    final findings = <RefUse>[];
    for (final f in _libSources()) {
      findings.addAll(
        scanSource(f.path.replaceAll(r'\', '/'), f.readAsStringSync()),
      );
    }
    expect(
      findings,
      isEmpty,
      reason:
          'await 之后 `ref` 可能已经失效（页面被退掉了），读它会抛：\n'
          '${findings.map((f) => '  ${f.file}:${f.line}  ${f.text}').join('\n')}\n'
          '在它前面加一句 `if (!mounted) return;`（或 `context.mounted`）。',
    );
  });

  group('守卫自身能失败（§1.4）', () {
    test('await 之后直接用 ref → 报', () {
      const bad = '''
Future<void> f() async {
  await doThing();
  ref.invalidate(listProvider);
}
''';
      expect(scanSource('bad.dart', bad), hasLength(1));
    });

    test('中间有 mounted 检查 → 不报', () {
      const good = '''
Future<void> f() async {
  await doThing();
  if (!mounted) return;
  ref.invalidate(listProvider);
}
''';
      expect(scanSource('good.dart', good), isEmpty);
    });

    test('`context.mounted` 也算 → 不报', () {
      const good = '''
Future<void> f() async {
  await doThing();
  if (!context.mounted) return;
  ref.invalidate(listProvider);
}
''';
      expect(scanSource('good.dart', good), isEmpty);
    });

    test('同一行里 await 在 ref 后面 → 不报', () {
      // 那一下的 `ref` 发生在挂起之前，是安全的。这一条是**反误报**的判据：
      // 少了它，几乎每个 `await ref.read(x).f()` 都会被冤枉。
      const good = '''
Future<void> f() async {
  final r = await ref.read(serviceProvider).run();
  print(r);
}
''';
      expect(scanSource('good.dart', good), isEmpty);
    });

    test('**挂起过之后，哪怕这一行自己也带 await，照样要报**', () {
      // 这一条曾经被我写成「不报」，是评审 R-1 打掉的那条豁免。
      //
      // 前一句折了行（拉警戒的那一行上没有 `ref` 这个词），
      // 后一句自己带着 await —— 我当时据此判它安全。**错在**：
      // 它自己那个 await 只说明「这个 ref 在**本次**挂起之前」，
      // 对**上一次**挂起一个字都没说。而上一次挂起已经发生了。
      //
      // 仓库里的实例：等系统权限弹窗回来之后再 `ref.read` —— 那期间
      // 用户完全可能已经退出这一页。
      const bad = '''
Future<void> f() async {
  await ref
      .read(platformProvider)
      .requestPermission();
  await ref.read(syncProvider.notifier).resyncNow();
}
''';
      expect(scanSource('bad.dart', bad), hasLength(1));
    });

    test('本块第一次挂起就是 await ref.read → 不报', () {
      // 删掉那条豁免之后，这一条仍然绿 —— 因为它压根没拉过警戒。
      // **这就是那条豁免不必要的证据**：它保护的情形本来就不会被报。
      const good = '''
Future<void> f() async {
  final r = await ref.read(serviceProvider).run();
  print(r);
}
''';
      expect(scanSource('good.dart', good), isEmpty);
    });

    test('单行 if：`if (await c()) ref.x;` → 报（评审 A）', () {
      // 这一族一度**永远不报** —— 「先判使用再上警戒」让本行自己的挂起
      // 管不到本行的 ref。而 `lib/` 里现有 300 多处无花括号的单行流程语句，
      // 两半都在，只差凑到一起。
      const bad = '''
Future<void> f() async {
  if (await cond()) ref.invalidate(p);
}
''';
      expect(scanSource('bad.dart', bad), hasLength(1));
    });

    test('单行 while：`while (await n()) ref.read(p);` → 报（评审 F）', () {
      const bad = '''
Future<void> f() async {
  while (await next()) ref.read(p);
}
''';
      expect(scanSource('bad.dart', bad), hasLength(1));
    });

    test('switch 的两个 case 互斥 → 后一个不因前一个的 await 而被报', () {
      // Dart 的 switch 不贯穿，所以上一个 case 里的挂起对这一个一个字都没说。
      // 这是 `swipe_row.dart` 那处误报的形状。
      const good = '''
Future<void> f() async {
  switch (action) {
    case A.one:
      final a = await ref.read(oneProvider).call();
      tell(a);
    case A.two:
      final b = await ref.read(twoProvider).call();
      tell(b);
  }
}
''';
      expect(scanSource('good.dart', good), isEmpty);
    });

    test('CRLF 的源文件里，注释照样剥得掉', () {
      // **这一条是真实文件与夹具行尾不一致栽出来的。**
      // Dart 的 `.` 不匹配回车符，于是 `//.*` 加行尾锚在 CRLF 文件上
      // 一个字符都换不掉 —— **注释从来没被剥过**。
      //
      // 夹具全是 LF，所以自检看不见：症状是真实仓库上三处误报，
      // 而它们的共同点是「上面的文档注释里有 await 两个字」。
      // **夹具的行尾与真实文件不一致，自检就照不到真实文件上的失效。**
      final crlf = [
        '/// 在 await 之前把 messenger 取好',
        'Future<void> f() async {',
        '  ref.invalidate(p);',
        '}',
      ].join('\r\n');
      expect(scanSource('good.dart', crlf), isEmpty);
    });

    test('离开那个块之后，警戒解除 → 不报', () {
      const good = '''
Future<void> f() async {
  await doThing();
}

void g() {
  ref.invalidate(listProvider);
}
''';
      expect(scanSource('good.dart', good), isEmpty);
    });

    test('注释里的 ref 不算', () {
      const good = '''
Future<void> f() async {
  await doThing();
  // 这里本来想 ref.invalidate(x)，但没有必要
}
''';
      expect(scanSource('good.dart', good), isEmpty);
    });
  });
}

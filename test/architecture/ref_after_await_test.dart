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
/// 刻意不引入 analyzer 做完整 AST（同 `lint_tests.dart` 的取舍）。
/// 代价写在这儿而不是假装没有：
///
/// - `await` 在嵌套闭包里、`ref` 在闭包外，可能**多报**；
/// - 同一行里 `await` 在 `ref` 后面（`await ref.read(x).f()`）**不报** ——
///   那一下的 `ref` 发生在挂起之前，是安全的。
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
  final lines = src.split('\n');
  var depth = 0;
  int? armedAt; // 在哪个深度上「await 过了」

  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    final code = raw.replaceAll(RegExp(r'//.*$'), '');

    // 出现 mounted 检查 → 警戒解除。
    if (_mountedCheck.hasMatch(code)) armedAt = null;

    // 先判使用，再判 await。
    //
    // **同一行里 `await` 排在 `ref` 前面的，一律安全** —— 那一下的 `ref`
    // 发生在这次挂起**之前**。头一版只是「先判使用再判 await」，
    // 对单行的 `await ref.read(x)` 够用，但对**折行**的写法不够：
    //
    //     await ref
    //         .read(platformProvider)     ← 这一行没有 `ref` 这个词
    //         .requestPermission();
    //     await ref.read(syncProvider).resyncNow();   ← 于是这一行被冤枉
    //
    // 上面那句 `await ref` 拉响了警戒，而下面那句其实自己就带着 await。
    // 仓库里五处命中全是这个形状 —— **全是误报**，一处真缺陷都没有。
    final refAt = _refUse.firstMatch(code);
    final awaitAt = _awaitAt.firstMatch(code);
    final awaitFirst =
        refAt != null && awaitAt != null && awaitAt.start < refAt.start;
    if (armedAt != null && refAt != null && !awaitFirst) {
      out.add((file: path, line: i + 1, text: raw.trim()));
      armedAt = null; // 一个块里报一次就够，不刷屏
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

    test('折行的 await ref 之后，另一句 await ref.read → 不报', () {
      // 这是仓库里那五处误报的形状，钉下来。
      // 前一句折了行，「拉警戒」的那一行上没有 `ref` 这个词；
      // 后一句自己带着 await，那一下的 ref 在挂起之前。
      const good = '''
Future<void> f() async {
  await ref
      .read(platformProvider)
      .requestPermission();
  await ref.read(syncProvider.notifier).resyncNow();
}
''';
      expect(scanSource('good.dart', good), isEmpty);
    });

    test('但折行的 await 之后，**不带 await** 的 ref 仍然要报', () {
      // 上一条的对照组。少了它，「await 在前就放行」这条会把真缺陷
      // 一起放走 —— 而真缺陷恰恰长这样（`ref.invalidate` 没有 await）。
      const bad = '''
Future<void> f() async {
  await ref
      .read(platformProvider)
      .requestPermission();
  ref.invalidate(listProvider);
}
''';
      expect(scanSource('bad.dart', bad), hasLength(1));
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

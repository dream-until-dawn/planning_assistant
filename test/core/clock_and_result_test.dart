/// `core/time/clock.dart` 与 `core/result/result.dart` 的契约。
///
/// ## 这两个文件为什么直到现在才有测试
///
/// 它们是 M0 骨架期建的，M1 全程**一行生产代码都没用过** ——
/// 而覆盖率门禁完全没报出来：`flutter test --coverage` 只对被至少一个测试
/// **加载过**的文件插桩，谁都不 import 的文件既不在分子也不在分母，
/// 于是四层全部「达标」。
///
/// 补上「从磁盘枚举源文件、lcov 里缺席的按 0 计入」之后才暴露出来，
/// 顺带发现这两个文件里各藏着一份与领域层**重名且不兼容**的类型
/// （`DomainInvariantViolation` / `IllegalTransitionException` /
/// `TimeZoneResolver`）—— 两份并存时 `catch` 到哪一份取决于调用方
/// import 了谁，**不匹配时会静默漏掉**。已删除骨架那份。
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/result/result.dart';
import 'package:planning_assistant/core/time/clock.dart';

void main() {
  group('Clock', () {
    test('SystemClock 返回 UTC —— 全项目唯一允许 DateTime.now() 的地方', () {
      // 不转 UTC 的话，同一份数据在不同设备上算出的 Instant 会差好几小时。
      final now = const SystemClock().nowUtc();
      expect(now.isUtc, isTrue);
    });

    test('SystemClock 的两次读取单调不减', () {
      const clock = SystemClock();
      final a = clock.nowUtc();
      final b = clock.nowUtc();
      expect(b.isBefore(a), isFalse);
    });

    test('FixedClock 返回固定值，且把输入转成 UTC', () {
      // 传本地时间进来时若不转 UTC，测试里的期望值会随运行机器的时区变 ——
      // 那正是「在我机器上是绿的」的经典成因。
      final local = DateTime(2026, 3, 8, 12);
      final clock = FixedClock(local);

      expect(clock.nowUtc().isUtc, isTrue);
      expect(clock.nowUtc(), local.toUtc());
      expect(clock.nowUtc(), clock.nowUtc(), reason: '固定时钟必须每次都一样');
    });

    test('FixedClock 可推进，用于验证 updatedAt 确实被刷新', () {
      final clock = FixedClock(DateTime.utc(2026, 3, 8, 12));
      final before = clock.nowUtc();

      clock.now = DateTime.utc(2026, 3, 8, 15);

      expect(clock.nowUtc(), DateTime.utc(2026, 3, 8, 15));
      expect(clock.nowUtc().isAfter(before), isTrue);
    });

    test('setter 同样做 UTC 归一', () {
      final clock = FixedClock(DateTime.utc(2026));
      clock.now = DateTime(2026, 6, 1, 8);
      expect(clock.nowUtc().isUtc, isTrue);
      expect(clock.nowUtc(), DateTime(2026, 6, 1, 8).toUtc());
    });

    test('Clock 是接口，可被任意实现替换', () {
      // 生产代码收的是 Clock 而不是裸 `DateTime Function()`：
      // 后者在生产里传个 `DateTime.now` 就绕过了整条禁令，且守卫扫不到。
      final custom = _CountingClock();
      expect(custom.nowUtc(), DateTime.utc(2000));
      expect(custom.calls, 1);
    });
  });

  group('Result / DomainFailure（cross-cutting §3）', () {
    test('DomainFailure 带稳定的机器可读 code', () {
      // code 用来查本地化文案，改它等于改 UI 契约。
      const f = DomainFailure('time.invalid');
      expect(f.code, 'time.invalid');
      expect(f.detail, isNull);
      expect(f.toString(), contains('time.invalid'));
    });

    test('detail 只给日志看，不得含用户内容（NFR-PRIV-01）', () {
      // 这条断的是格式，「不含用户内容」得靠 review —— 但至少把
      // detail 会进日志这件事钉在测试里，改动时能看见。
      const f = DomainFailure('db.write', detail: 'table=tasks');
      expect(f.toString(), contains('db.write'));
      expect(f.toString(), contains('table=tasks'));
    });

    test('Success 携带值，Failure 携带失败原因', () {
      const ok = Result<int>.success(42);
      const bad = Result<int>.failure(DomainFailure('nope'));

      expect(ok, isA<Success<int>>());
      expect(bad, isA<Failure<int>>());
      expect((ok as Success<int>).value, 42);
      expect((bad as Failure<int>).failure.code, 'nope');
    });

    test('sealed 让 switch 能穷尽 —— 新增分支时调用处会编译报错', () {
      // 这正是选 sealed 的理由：不是运行时走进 default 什么都不做。
      String describe(Result<int> r) => switch (r) {
        Success(:final value) => '成功 $value',
        Failure(:final failure) => '失败 ${failure.code}',
      };

      expect(describe(const Result<int>.success(1)), '成功 1');
      expect(describe(const Result<int>.failure(DomainFailure('x'))), '失败 x');
    });
  });

  group('骨架期的重名类型已彻底移除', () {
    test('core/result 不再导出领域异常', () {
      // 这条是**结构守卫**，不是行为断言：
      // 只要 result.dart 里再出现同名类型，本文件就会因为
      // 「导入了两份同名符号」而编译失败 —— 那比运行时静默漏 catch 好得多。
      //
      // 直接断源码，因为「类型不存在」在 Dart 里没法用运行时断言表达。
      final source = _read('lib/core/result/result.dart');
      expect(source, isNot(contains('class DomainInvariantViolation')));
      expect(source, isNot(contains('class IllegalTransitionException')));
    });

    test('core/time/clock.dart 不再定义第二份 TimeZoneResolver', () {
      // 骨架那份的签名是 `toInstant(DateTime, String)`，
      // 真实那份是 `toInstant(LocalWallTime)` —— 完全不兼容。
      final source = _read('lib/core/time/clock.dart');
      expect(
        source,
        isNot(contains('abstract interface class TimeZoneResolver')),
      );
    });

    test('全仓库每个领域异常只有一处定义', () {
      // 泛化成对整个 lib/ 的扫描：将来任何地方再复制一份都会红。
      for (final name in const [
        'DomainInvariantViolation',
        'IllegalTransitionException',
        'TimeZoneResolver',
      ]) {
        final hits = _grepClassDefinitions(name);
        expect(hits.length, 1, reason: '$name 有 ${hits.length} 处定义：$hits');
      }
    });
  });
}

class _CountingClock implements Clock {
  int calls = 0;

  @override
  DateTime nowUtc() {
    calls++;
    return DateTime.utc(2000);
  }
}

String _read(String relativePath) => File(relativePath).readAsStringSync();

List<String> _grepClassDefinitions(String typeName) {
  final pattern = RegExp(
    r'^\s*(abstract\s+)?(interface\s+|final\s+|sealed\s+|base\s+)*class\s+'
    '$typeName'
    r'\b',
    multiLine: true,
  );
  final hits = <String>[];
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('.g.dart')) continue;
    if (pattern.hasMatch(entity.readAsStringSync())) {
      hits.add(entity.path.replaceAll(r'\', '/'));
    }
  }
  return hits;
}

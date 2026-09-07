/// `encodeRrule` 的编码契约与数据不变量。
///
/// 对应 docs/02-domain/recurrence-engine.md §2.3。
///
/// **四条断言管的是两件不同的事**：
///  · C1/C2/C3 → 编解码器**本身**对不对
///  · 数据不变量 → 这条数据**有没有真的走过**编解码器
/// 某条写入路径漏了规范化时，只有最后一条会红。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/domain/value_objects/recurrence.dart';

/// 样本集**按格式分支**选取，不是「多加几条」。
/// 判据是覆盖了哪几条分支（testing-strategy §1.2）。
const _samples = <String, String>{
  '无 UNTIL': 'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=TU,TH',
  'COUNT': 'RRULE:FREQ=DAILY;COUNT=5',
  '单部件 + UNTIL': 'RRULE:FREQ=DAILY;UNTIL=20260930T235959Z',
  '多部件 + UNTIL': 'RRULE:FREQ=MONTHLY;BYMONTHDAY=-1;UNTIL=20261231T155959Z',
  '负序号 BYDAY': 'RRULE:FREQ=MONTHLY;BYDAY=-1FR;COUNT=10',
  '多 BYDAY + INTERVAL + UNTIL':
      'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR;UNTIL=20261231T155959Z',
  'YEARLY 多部件': 'RRULE:FREQ=YEARLY;BYMONTH=5;BYMONTHDAY=20',
};

void main() {
  group('C1 合规性：含 UNTIL 的输出必须带 Z', () {
    // 默认 toString() 会丢掉 Z（isTimeUtc 默认 false）。丢掉之后的串按 RFC 5545
    // 是「浮动本地时间」，而 DTSTART 带 TZID 时该值 MUST 为真 UTC ——
    // 也就是我们自己的导出会不合规。而 rrule 解析无 Z 的串仍得等值规则，
    // 所以只做语义往返断言的测试恒绿，只有外部消费者会错。
    for (final e in _samples.entries) {
      if (!e.value.contains('UNTIL=')) continue;
      test(e.key, () {
        expect(
          encodeRrule(decodeRrule(e.value)),
          matches(RegExp(r'UNTIL=\d{8}T\d{6}Z')),
        );
      });
    }

    test('对照：默认编码确实会丢 Z（记录既有行为，防止有人「简化」封装）', () {
      const src = 'RRULE:FREQ=DAILY;UNTIL=20260930T235959Z';
      // ignore: avoid_redundant_argument_values
      final naive = decodeRrule(src).toString();
      expect(naive, isNot(contains('Z')), reason: '这正是必须封装的理由');
      expect(encodeRrule(decodeRrule(src)), contains('Z'));
    });
  });

  group('C2 语义往返：decode(encode(x)) == x', () {
    for (final e in _samples.entries) {
      test(e.key, () {
        final rule = decodeRrule(e.value);
        expect(decodeRrule(encodeRrule(rule)), rule);
      });
    }
  });

  group('C3 规范形幂等：encode(decode(encode(x))) == encode(x)', () {
    for (final e in _samples.entries) {
      test(e.key, () {
        final once = encodeRrule(decodeRrule(e.value));
        expect(encodeRrule(decodeRrule(once)), once);
      });
    }
  });

  group('刻意不断言字节等价', () {
    test('编码器会重排部件，且那是合法的（RFC 部件无序）', () {
      const src = 'RRULE:FREQ=MONTHLY;BYMONTHDAY=-1;UNTIL=20261231T155959Z';
      final encoded = encodeRrule(decodeRrule(src));
      expect(encoded, isNot(equals(src)), reason: '记录既有行为：部件确实被重排');
      expect(encoded, contains('UNTIL=20261231T155959Z'));
      expect(encoded, contains('BYMONTHDAY=-1'));
    });

    test('断言字节等价会对多部件规则产生假失败', () {
      // 量化「假失败」的规模，说明为什么不能用它当断言。
      var byteEqual = 0;
      for (final src in _samples.values) {
        if (encodeRrule(decodeRrule(src)) == src) byteEqual++;
      }
      expect(
        byteEqual,
        lessThan(_samples.length),
        reason: '若全部字节等价，说明样本集没覆盖到会被重排的形态',
      );
    });
  });

  group('数据不变量：库中的规则串必须已是规范形', () {
    // 它由 C3 可推出，因此在编解码器正确的前提下**恒真** ——
    // 唯一能让它变红的是「某条写入路径没调 encodeRrule()」。
    // 这是 C1/C2/C3 都抓不到的东西：它们只考察编解码器，不考察调用方有没有用它。

    test('Recurrence.parse 的产物一律满足 isCanonicalRrule', () {
      for (final src in _samples.values) {
        expect(
          isCanonicalRrule(Recurrence.parse(src).canonical),
          isTrue,
          reason: src,
        );
      }
    });

    test('非规范形的外部串被识别出来', () {
      // 部件顺序不同 → 非规范形
      expect(
        isCanonicalRrule(
          'RRULE:FREQ=MONTHLY;BYMONTHDAY=-1;UNTIL=20261231T155959Z',
        ),
        isFalse,
        reason: '外部串的部件顺序与我们的规范形不同',
      );
      // 缺 Z → 非规范形
      expect(
        isCanonicalRrule('RRULE:FREQ=DAILY;UNTIL=20260930T235959'),
        isFalse,
        reason: '缺 Z 的串必须被识别为非规范形，否则不合规的数据会入库',
      );
    });

    test('Recurrence.parse 把非规范形归一（入库路径的唯一入口）', () {
      const external =
          'RRULE:FREQ=MONTHLY;BYMONTHDAY=-1;UNTIL=20261231T155959Z';
      expect(isCanonicalRrule(external), isFalse);
      final normalized = Recurrence.parse(external);
      expect(isCanonicalRrule(normalized.canonical), isTrue);
      // 归一不得改变语义
      expect(decodeRrule(normalized.canonical), decodeRrule(external));
    });

    test('非法串不会被误判为规范形，且不会让调用方崩溃', () {
      // 库里可能出现脏数据（手工改库、导入损坏的备份、旧版本残留）。
      // 这条要求它被识别成「读不出来」，而不是抛出一个调用方接不住的异常。
      for (final bad in [
        '',
        'FREQ=DAILY',
        'RRULE:',
        'not a rule',
        'RRULE:FREQ=',
      ]) {
        expect(isCanonicalRrule(bad), isFalse, reason: '「$bad」');
      }
    });

    test('decodeRrule 把库的内部异常统一成 FormatException', () {
      // 实测 rrule 对畸形输入抛的是 TypeError 而非 FormatException。
      // 不包一层的话，调用方没法用 on FormatException 处理，
      // 而且一条脏数据会让应用崩溃而不是报「这条规则读不出来」。
      for (final bad in ['not a rule', 'RRULE:', 'RRULE:FREQ=']) {
        expect(
          () => decodeRrule(bad),
          throwsFormatException,
          reason: '「$bad」应抛 FormatException，而不是库的内部异常',
        );
      }
    });

    test('Recurrence.parse 对非法输入同样抛 FormatException', () {
      expect(() => Recurrence.parse('not a rule'), throwsFormatException);
    });

    test('值相等按规范形判定，与外部书写顺序无关', () {
      final a = Recurrence.parse(
        'RRULE:FREQ=MONTHLY;BYMONTHDAY=-1;UNTIL=20261231T155959Z',
      );
      final b = Recurrence.parse(
        'RRULE:FREQ=MONTHLY;UNTIL=20261231T155959Z;BYMONTHDAY=-1',
      );
      expect(a, b, reason: '同一规则的两种书写必须被判为同一个值');
      expect(a.hashCode, b.hashCode);
    });
  });

  group('Recurrence 的元信息', () {
    test('untilUtc 是真 UTC，不是墙钟', () {
      final r = Recurrence.parse('RRULE:FREQ=DAILY;UNTIL=20260930T095959Z');
      expect(r.untilUtc, DateTime.utc(2026, 9, 30, 9, 59, 59));
      expect(r.untilUtc!.isUtc, isTrue);
    });

    test('hasEnd 区分三种结束条件', () {
      expect(Recurrence.parse('RRULE:FREQ=DAILY').hasEnd, isFalse);
      expect(Recurrence.parse('RRULE:FREQ=DAILY;COUNT=3').hasEnd, isTrue);
      expect(
        Recurrence.parse('RRULE:FREQ=DAILY;UNTIL=20260930T095959Z').hasEnd,
        isTrue,
      );
    });
  });
}

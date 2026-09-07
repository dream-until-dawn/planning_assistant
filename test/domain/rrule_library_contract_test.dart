/// 我们对 `rrule` 包所依赖的行为契约。
///
/// 这不是在测第三方库，而是**把我们依赖的那些性质固定下来**：
/// 一旦升级 rrule 后行为变了，这里会红，而不是等到用户发现日程少了一次。
///
/// **期望值全部来自 RFC 5545，不是「跑一遍看输出」**
/// （docs/05-engineering/testing-strategy.md §1.1 明令禁止后者）。
/// 每条用例都注明依据。对应 docs/02-domain/recurrence-engine.md §7 的探针表。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rrule/rrule.dart';

/// 展开并格式化为 `yyyy-MM-dd`，便于与手算期望比对。
List<String> days(String rule, DateTime start, {int take = 6}) =>
    RecurrenceRule.fromString(rule)
        .getInstances(start: start)
        .take(take)
        .map((d) => d.toIso8601String().substring(0, 10))
        .toList();

void main() {
  group('P-1 BYMONTHDAY 指定的日期在该月不存在时', () {
    // RFC 5545 §3.3.10: "Recurrence instances falling on invalid dates
    // ... are ignored." —— 跳过，而不是顺延到月末。
    test('FREQ=MONTHLY;BYMONTHDAY=31 跳过没有 31 号的月份', () {
      expect(
        days('RRULE:FREQ=MONTHLY;BYMONTHDAY=31', DateTime.utc(2026, 1, 31)),
        [
          '2026-01-31',
          '2026-03-31',
          '2026-05-31',
          '2026-07-31',
          '2026-08-31',
          '2026-10-31',
        ],
        reason:
            '2/4/6/9 月无 31 号，必须缺席而非顺延。'
            'UI 需据此在用户选「每月 31 号」时提示，并提供「每月最后一天」替代',
      );
    });

    test('FREQ=MONTHLY;BYMONTHDAY=-1 才是「每月最后一天」', () {
      // 手算：2026 非闰年，2 月 28 天
      expect(
        days('RRULE:FREQ=MONTHLY;BYMONTHDAY=-1', DateTime.utc(2026, 1, 31)),
        [
          '2026-01-31',
          '2026-02-28',
          '2026-03-31',
          '2026-04-30',
          '2026-05-31',
          '2026-06-30',
        ],
      );
    });
  });

  group('P-3 UNTIL 是闭区间', () {
    // RFC 5545 §3.3.10 原文（已回原始 RFC 全文逐字核对，第 2255-2256 行）:
    // "The UNTIL rule part defines a DATE or DATE-TIME value that bounds
    //  the recurrence rule in an inclusive manner."
    test('UNTIL 恰为某实例时刻时，该实例被包含', () {
      expect(
        days(
          'RRULE:FREQ=DAILY;UNTIL=20260910T000000Z',
          DateTime.utc(2026, 9, 7),
        ),
        ['2026-09-07', '2026-09-08', '2026-09-09', '2026-09-10'],
      );
    });

    test('UNTIL 早于实例 1 秒时排除该实例', () {
      expect(
        days(
          'RRULE:FREQ=DAILY;UNTIL=20260909T235959Z',
          DateTime.utc(2026, 9, 7),
        ),
        ['2026-09-07', '2026-09-08', '2026-09-09'],
      );
    });

    test('UNTIL 不做任何时区换算，只做朴素比较', () {
      // 这正是 recurrence-engine.md §2.2 存在的理由：
      // 存储是真 UTC、展开在墙钟域，两者之间必须由 core/time 显式换算。
      final start = DateTime.utc(2026, 9, 28, 23);
      expect(
        RecurrenceRule.fromString('RRULE:FREQ=DAILY;UNTIL=20260930T095959Z')
            .getInstances(start: start)
            .length,
        2,
        reason: '墙钟 09-30T23:00 > 裸值 09-30T09:59:59，被丢弃',
      );
      expect(
        RecurrenceRule.fromString('RRULE:FREQ=DAILY;UNTIL=20260930T235959Z')
            .getInstances(start: start)
            .length,
        3,
      );
    });
  });

  group('P-4 BYDAY 的序号前缀', () {
    // RFC 5545 §3.3.10: BYDAY 可带正/负序号，用于 MONTHLY 或 YEARLY。
    // 负数表示从月末倒数。手算 2026 年（1/1 为周四）：
    //   1 月周五: 2, 9, 16, 23, 30      2 月(1 日周日)周五: 6, 13, 20, 27
    //   3 月(1 日周日)周五: 6,13,20,27  4 月(1 日周三)周五: 3, 10, 17, 24
    test('BYDAY=-1FR 取每月最后一个周五', () {
      expect(
        days(
          'RRULE:FREQ=MONTHLY;BYDAY=-1FR',
          DateTime.utc(2026, 1, 30),
          take: 4,
        ),
        ['2026-01-30', '2026-02-27', '2026-03-27', '2026-04-24'],
      );
    });

    test('BYDAY=2FR 取每月第二个周五', () {
      expect(
        days('RRULE:FREQ=MONTHLY;BYDAY=2FR', DateTime.utc(2026, 1, 9), take: 4),
        ['2026-01-09', '2026-02-13', '2026-03-13', '2026-04-10'],
      );
    });

    test('无序号的 BYDAY 表示该月所有该星期几', () {
      expect(
        days('RRULE:FREQ=MONTHLY;BYDAY=FR', DateTime.utc(2026, 1, 2), take: 5),
        ['2026-01-02', '2026-01-09', '2026-01-16', '2026-01-23', '2026-01-30'],
      );
    });
  });

  group('闰年边界', () {
    test('FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=29 只在闰年出现', () {
      // 手算：2024 闰、2028 闰、2032 闰；2025-2027、2029-2031 非闰
      expect(
        days(
          'RRULE:FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=29',
          DateTime.utc(2024, 2, 29),
          take: 3,
        ),
        ['2024-02-29', '2028-02-29', '2032-02-29'],
      );
    });
  });

  group('P-2 编码契约', () {
    const canonical = RecurrenceRuleStringCodec(
      toStringOptions: RecurrenceRuleToStringOptions(isTimeUtc: true),
    );

    // 覆盖各个格式分支，而不是「多加一条样本」。
    // 见 testing-strategy.md §1.2：判据是样本集覆盖了哪几条分支。
    const samples = [
      'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=TU,TH', // 无 UNTIL
      'RRULE:FREQ=DAILY;COUNT=5', // COUNT
      'RRULE:FREQ=DAILY;UNTIL=20260930T235959Z', // 单部件 + UNTIL
      'RRULE:FREQ=MONTHLY;BYMONTHDAY=-1;UNTIL=20261231T155959Z', // 多部件 + UNTIL
      'RRULE:FREQ=MONTHLY;BYDAY=-1FR;COUNT=10', // 负序号
    ];

    test('C1 合规性：含 UNTIL 的输出必须带 Z', () {
      // 默认 toString() 会丢掉 Z（isTimeUtc 默认 false），
      // 产出的串按 RFC 是浮动本地时间 —— 本地解析不出问题，
      // 只有服务端与 .ics 互通会错。见 recurrence-engine.md §2.3。
      for (final src in samples.where((s) => s.contains('UNTIL='))) {
        final encoded = canonical.encode(RecurrenceRule.fromString(src));
        expect(
          encoded,
          matches(RegExp(r'UNTIL=\d{8}T\d{6}Z')),
          reason: '$src 编码后 UNTIL 丢失了 Z',
        );
      }
    });

    test('C2 语义往返：decode(encode(x)) == x', () {
      for (final src in samples) {
        final rule = RecurrenceRule.fromString(src);
        expect(
          RecurrenceRule.fromString(canonical.encode(rule)),
          rule,
          reason: src,
        );
      }
    });

    test('C3 规范形幂等：encode(decode(encode(x))) == encode(x)', () {
      for (final src in samples) {
        final once = canonical.encode(RecurrenceRule.fromString(src));
        final twice = canonical.encode(RecurrenceRule.fromString(once));
        expect(twice, once, reason: src);
      }
    });

    test('刻意不断言字节等价 —— 编码器会重排部件，且那是合法的', () {
      // RFC 5545 的 RRULE 部件无序，重排不改变语义。
      // 断言字节等价会对多部件规则产生假失败（6 个样本中 4 个）。
      const src = 'RRULE:FREQ=MONTHLY;BYMONTHDAY=-1;UNTIL=20261231T155959Z';
      final encoded = canonical.encode(RecurrenceRule.fromString(src));
      expect(encoded, isNot(equals(src)), reason: '此处记录既有行为：部件确实被重排');
      expect(encoded, contains('UNTIL=20261231T155959Z'));
      expect(encoded, contains('BYMONTHDAY=-1'));
    });
  });

  group('P-5 大范围展开性能（NFR-PERF-04）', () {
    test('展开 1 年的每日规则 <= 50ms', () {
      final sw = Stopwatch()..start();
      final n = RecurrenceRule.fromString('RRULE:FREQ=DAILY')
          .getInstances(start: DateTime.utc(2026))
          .takeWhile((d) => d.year == 2026)
          .length;
      sw.stop();

      expect(n, 365, reason: '2026 非闰年');
      expect(
        sw.elapsedMilliseconds,
        lessThanOrEqualTo(50),
        reason:
            '实测 ${sw.elapsedMilliseconds}ms。超限说明必须引入'
            'recurrence-engine.md §5 的窗口化与记忆化，而不是放宽阈值',
      );
    });

    test('展开 10 年的每日规则不爆内存且线性可控', () {
      final sw = Stopwatch()..start();
      final n = RecurrenceRule.fromString('RRULE:FREQ=DAILY')
          .getInstances(start: DateTime.utc(2026))
          .takeWhile((d) => d.year < 2036)
          .length;
      sw.stop();

      // 手算：2026..2035 共 10 年 × 365 = 3650，其中 2028/2032 为闰年 +2 = 3652。
      // （初稿此处写成 3653，是我的算术错误，被这条测试抓住了 ——
      //  期望值来自独立来源时，它抓的既可能是实现的错，也可能是作者的错，两者都算数。）
      expect(n, 3652, reason: '10 年 × 365 + 2 个闰日');
      expect(
        sw.elapsedMilliseconds,
        lessThanOrEqualTo(500),
        reason: '实测 ${sw.elapsedMilliseconds}ms',
      );
    });
  });
}

// 我方复核探针：字节等价并不是正确的往返性质。
// RFC 5545 的 RRULE 各部件是无序的，因此编码器重排部件仍然合规。
// 正确的性质应当是：
//   (C1) 合规性  —— 含 UNTIL 时必须带 Z
//   (C2) 语义往返 —— decode(encode(x)) == x
//   (C3) 规范形稳定 —— encode(decode(encode(x))) == encode(x)   ← 幂等
// 本探针检验 C1/C2/C3 在多部件规则下是否成立。

import 'package:rrule/rrule.dart';

const canonical = RecurrenceRuleStringCodec(
  toStringOptions: RecurrenceRuleToStringOptions(isTimeUtc: true),
);

String encode(RecurrenceRule r) => canonical.encode(r);

final samples = <String>[
  'RRULE:FREQ=DAILY;UNTIL=20260930T235959Z',
  'RRULE:FREQ=MONTHLY;BYMONTHDAY=-1;UNTIL=20261231T155959Z',
  'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=TU,TH;UNTIL=20261231T155959Z',
  'RRULE:FREQ=YEARLY;BYMONTH=5;BYMONTHDAY=20;UNTIL=20301231T155959Z',
  'RRULE:FREQ=MONTHLY;BYDAY=-1FR;COUNT=10',
  'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=TU,TH',
];

void main() {
  print('规范形稳定性探针 · rrule 0.2.18\n');
  var c1Fail = 0, c2Fail = 0, c3Fail = 0, byteFail = 0;

  for (final src in samples) {
    final rule = RecurrenceRule.fromString(src);
    final once = encode(rule);
    final twice = encode(RecurrenceRule.fromString(once));

    final hasUntil = src.contains('UNTIL=');
    final c1 = !hasUntil || RegExp(r'UNTIL=\d{8}T\d{6}Z').hasMatch(once);
    final c2 = RecurrenceRule.fromString(once) == rule;
    final c3 = twice == once;
    final byteEq = once == src;

    if (!c1) c1Fail++;
    if (!c2) c2Fail++;
    if (!c3) c3Fail++;
    if (!byteEq) byteFail++;

    print('src   : $src');
    print('enc   : $once');
    print('  C1 合规(UNTIL 带 Z)     : ${c1 ? "PASS" : "FAIL"}');
    print('  C2 语义往返             : ${c2 ? "PASS" : "FAIL"}');
    print('  C3 规范形稳定(幂等)      : ${c3 ? "PASS" : "FAIL"}');
    print('  -- 字节等价于原串        : ${byteEq ? "是" : "否（部件被重排）"}');
    print('');
  }

  print('汇总: C1 失败=$c1Fail  C2 失败=$c2Fail  C3 失败=$c3Fail  '
      '字节不等价=$byteFail / ${samples.length}');
  print('');
  print('结论：字节等价会因部件重排而失败，且这种失败是无害的（RFC 部件无序）。');
  print('      应当断言 C1+C2+C3，而不是字节等价于任意外来输入串。');
}

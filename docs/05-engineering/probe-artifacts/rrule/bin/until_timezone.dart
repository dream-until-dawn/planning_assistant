// 探针 P-UNTIL：验证 recurrence-engine.md §4「假 UTC 墙钟展开」与 §2.1
// 「UNTIL=yyyyMMddTHHmmssZ（真 UTC）」是否可以同时成立。
//
// 设计文档的前提：
//   · §4 —— 展开全程在墙钟域进行，喂给 rrule 的 DateTime 携带的是墙钟值（仅 isUtc=true 作占位）
//   · §2.1 —— 结束条件写成 UNTIL=yyyyMMddTHHmmssZ
//   · RFC 5545 §3.3.10 —— DTSTART 为「local time + TZID」时，UNTIL MUST 为真 UTC
//
// 若两者可同时成立，则「按 RFC 写的 UNTIL」与「按墙钟写的 UNTIL」展开结果应当一致。
// 本探针检验这一点。

import 'package:rrule/rrule.dart';

String fmt(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}T'
    '${d.hour.toString().padLeft(2, '0')}:'
    '${d.minute.toString().padLeft(2, '0')}';

String stamp(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}'
    '${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}T'
    '${d.hour.toString().padLeft(2, '0')}'
    '${d.minute.toString().padLeft(2, '0')}'
    '${d.second.toString().padLeft(2, '0')}Z';

/// 在墙钟域展开（§4 的做法）：dtstartWall 携带墙钟值，isUtc 仅为占位。
List<DateTime> expand(DateTime dtstartWall, DateTime untilValue) {
  final rule = RecurrenceRule.fromString(
    'RRULE:FREQ=DAILY;UNTIL=${stamp(untilValue)}',
  );
  return rule.getInstances(start: dtstartWall).toList();
}

void scenario({
  required String name,
  required String zone,
  required int offsetHours,
  required DateTime dtstartWall, // 墙钟起点
  required DateTime lastLocalDayEnd, // 用户意图：「到这一天为止」的当地日终
}) {
  // (A) 按 RFC 5545 写：UNTIL 是真 UTC 瞬时 = 当地日终 - 时区偏移
  final untilRfc = lastLocalDayEnd.subtract(Duration(hours: offsetHours));
  // (B) 按墙钟写：UNTIL 直接就是当地日终的墙钟值，加个 Z 后缀
  final untilWall = lastLocalDayEnd;

  final a = expand(dtstartWall, untilRfc);
  final b = expand(dtstartWall, untilWall);

  print('── $name  ($zone, UTC${offsetHours >= 0 ? '+' : ''}$offsetHours)');
  print('   DTSTART(墙钟)        : ${fmt(dtstartWall)}');
  print('   用户意图             : 重复到 ${fmt(lastLocalDayEnd).substring(0, 10)} 当天为止（含）');
  print('   (A) RFC 真 UTC UNTIL : ${stamp(untilRfc)}  → ${a.length} 次，末次 ${a.isEmpty ? "无" : fmt(a.last)}');
  print('   (B) 墙钟   UNTIL     : ${stamp(untilWall)}  → ${b.length} 次，末次 ${b.isEmpty ? "无" : fmt(b.last)}');
  final diff = a.length - b.length;
  if (diff == 0) {
    print('   结果                 : 一致');
  } else {
    print('   结果                 : ⚠ 相差 ${diff.abs()} 次'
        '（RFC 形态${diff < 0 ? "少了" : "多了"}）');
  }
  print('');
}

void main() {
  print('探针 P-UNTIL · rrule 0.2.18');
  print('检验：「假 UTC 墙钟展开」与「RFC 要求的真 UTC UNTIL」能否同时成立\n');

  // 场景 1：UTC+14，深夜任务 —— RFC 形态会丢掉最后一次
  scenario(
    name: '场景 1 · 深夜任务，东侧极端时区',
    zone: 'Pacific/Kiritimati',
    offsetHours: 14,
    dtstartWall: DateTime.utc(2026, 9, 25, 23, 0),
    lastLocalDayEnd: DateTime.utc(2026, 9, 30, 23, 59, 59),
  );

  // 场景 2：UTC-4，凌晨任务 —— RFC 形态会多出一次
  scenario(
    name: '场景 2 · 凌晨任务，西侧时区',
    zone: 'America/New_York',
    offsetHours: -4,
    dtstartWall: DateTime.utc(2026, 9, 25, 1, 0),
    lastLocalDayEnd: DateTime.utc(2026, 9, 30, 23, 59, 59),
  );

  // 场景 3：对照组 —— UTC+0 时两种写法必然重合，所以本机/单时区自测发现不了
  scenario(
    name: '场景 3 · 对照组，零偏移',
    zone: 'UTC',
    offsetHours: 0,
    dtstartWall: DateTime.utc(2026, 9, 25, 23, 0),
    lastLocalDayEnd: DateTime.utc(2026, 9, 30, 23, 59, 59),
  );

  // 场景 4：文档 R-05 用例原样照抄
  print('── 场景 4 · 文档 recurrence-engine.md §6 R-05 原样');
  final r05 = RecurrenceRule.fromString(
    'RRULE:FREQ=DAILY;UNTIL=20260910T000000Z',
  );
  final withMorning = r05
      .getInstances(start: DateTime.utc(2026, 9, 7, 7, 0))
      .toList();
  final withMidnight = r05
      .getInstances(start: DateTime.utc(2026, 9, 7, 0, 0))
      .toList();
  print('   规则                 : FREQ=DAILY;UNTIL=20260910T000000Z');
  print('   DTSTART 07:00        : ${withMorning.length} 次，末次 '
      '${withMorning.isEmpty ? "无" : fmt(withMorning.last)}');
  print('   DTSTART 00:00        : ${withMidnight.length} 次，末次 '
      '${withMidnight.isEmpty ? "无" : fmt(withMidnight.last)}');
  print('   → R-05 期望值「含 9/10 与否」取决于 DTSTART 的时刻，'
      '不是一个可以留空的问题');
  print('');

  // 闭区间验证：UNTIL 恰好等于某次发生时刻
  final exact = RecurrenceRule.fromString(
    'RRULE:FREQ=DAILY;UNTIL=20260910T070000Z',
  ).getInstances(start: DateTime.utc(2026, 9, 7, 7, 0)).toList();
  print('── 闭/开区间');
  print('   UNTIL 恰等于末次时刻 (20260910T070000Z, DTSTART 07:00)');
  print('   → ${exact.length} 次，末次 ${fmt(exact.last)}'
      '  ⇒ ${exact.last == DateTime.utc(2026, 9, 10, 7, 0) ? "闭区间（含）" : "开区间（不含）"}');
}

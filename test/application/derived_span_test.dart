/// 阶段事项的起止由阶段推出（FR-TASK-02、用户 2026-09-10 定）。
///
/// 这是那条改动里**唯一有判断的一段**，所以判断全在这儿验：
/// 取最早、取最晚、把偏移重新表达成「相对最早那个」、
/// 以及「一个都没填时间时什么也别推」。
///
/// 编辑器那边只剩「显示/隐藏哪几个区」，由 `editor_shape_fields_test` 验。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/date_and_minute.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/features/task/application/derived_span.dart';

final _anchor = DateAndMinute(
  const PlanDate(2026, 9, 10),
  MinuteOfDay.of(9, 0),
);

StageTiming _s(int? start, [int? duration]) =>
    (startOffsetMinutes: start, durationMinutes: duration);

void main() {
  group('FR-TASK-02 起止取阶段里最早的开始与最晚的结束', () {
    test('两个阶段：起 = 早的那个，止 = 晚的那个的结束', () {
      final out = deriveSpanFromStages(_anchor, [_s(0, 60), _s(120, 30)])!;

      expect(out.start.date, const PlanDate(2026, 9, 10));
      expect(out.start.minute, MinuteOfDay.of(9, 0));
      // 第二个阶段 9:00+120 开始、再 30 分钟结束 = 11:30。
      expect(out.end.minute, MinuteOfDay.of(11, 30));
    });

    test('**阶段乱序时也对** —— 取的是最早，不是第一个', () {
      // 少了这条，一个「拿 stages.first」的实现在顺序恰好正确时全绿。
      final out = deriveSpanFromStages(_anchor, [_s(120, 30), _s(0, 60)])!;
      expect(out.start.minute, MinuteOfDay.of(9, 0));
    });

    test('**阶段交叠时取最晚的结束** —— 不是最后一个的结束', () {
      // 第二个开始得晚，却结束得早。取「最后一个的结束」会得到 10:00，
      // 而真正的最晚是第一个的 12:00。
      final out = deriveSpanFromStages(_anchor, [_s(0, 180), _s(30, 30)])!;
      expect(out.end.minute, MinuteOfDay.of(12, 0));
    });

    test('跨天：偏移超过一天时日期跟着走', () {
      final out = deriveSpanFromStages(_anchor, [
        _s(0, 60),
        _s(1440 + 120, 60),
      ])!;
      expect(out.end.date, const PlanDate(2026, 9, 11));
      expect(out.end.minute, MinuteOfDay.of(12, 0));
    });

    test('阶段在锚点之前（负偏移）→ 任务开始跟着往前挪', () {
      final out = deriveSpanFromStages(_anchor, [_s(0, 60), _s(-120, 30)])!;
      expect(out.start.minute, MinuteOfDay.of(7, 0));
      expect(out.end.minute, MinuteOfDay.of(10, 0));
    });

    test('没给时长的阶段按零长算，仍然参与推导', () {
      final out = deriveSpanFromStages(_anchor, [_s(60)])!;
      expect(out.start.minute, MinuteOfDay.of(10, 0));
      expect(out.end.minute, MinuteOfDay.of(10, 0));
    });
  });

  group('偏移要重新表达成「相对最早那个阶段」', () {
    test('最早那个的偏移变成 0，其余整体前移', () {
      // **两件事必须一起做**：任务开始挪到了最早那个阶段身上，
      // 偏移若不跟着改，阶段就整体漂移了一段。
      final out = deriveSpanFromStages(_anchor, [_s(120, 30), _s(60, 60)])!;
      expect(out.stages.map((s) => s.startOffsetMinutes), [60, 0]);
      expect(out.start.minute, MinuteOfDay.of(10, 0), reason: '9:00 + 60');
    });

    test('时长原样不动', () {
      final out = deriveSpanFromStages(_anchor, [_s(120, 30), _s(60, 60)])!;
      expect(out.stages.map((s) => s.durationMinutes), [30, 60]);
    });

    test('推导是幂等的 —— 再推一次不动', () {
      // 每次改阶段时间都会重推一遍，所以它必须是幂等的：
      // 不幂等的话，什么都不改地保存两次，任务会一次次往前挪。
      final once = deriveSpanFromStages(_anchor, [_s(120, 30), _s(60, 60)])!;
      final twice = deriveSpanFromStages(once.start, once.stages.toList())!;
      expect(twice.start, once.start);
      expect(twice.end, once.end);
      expect(
        twice.stages.map((s) => s.startOffsetMinutes),
        once.stages.map((s) => s.startOffsetMinutes),
      );
    });
  });

  group('推不出来时不要瞎推', () {
    test('一个带时间的阶段都没有 → null', () {
      // **null 不等于「推出来是空的」**：调用方要保持原样，
      // 而不是把任务的起止清掉。
      expect(deriveSpanFromStages(_anchor, [_s(null), _s(null)]), isNull);
    });

    test('一个阶段都没有 → null', () {
      expect(deriveSpanFromStages(_anchor, const []), isNull);
    });

    test('只有一部分填了时间 → 按填了的推，没填的原样留着', () {
      // 没填的那些由 `blockedReason` 去催，不在这里被悄悄丢掉 ——
      // 丢掉的话用户会看到阶段数变少，而他并没有删过。
      final out = deriveSpanFromStages(_anchor, [_s(null), _s(60, 30)])!;
      expect(out.stages, hasLength(2));
      expect(out.stages.first.startOffsetMinutes, isNull);
      expect(out.stages.last.startOffsetMinutes, 0);
      expect(out.start.minute, MinuteOfDay.of(10, 0));
    });
  });
}

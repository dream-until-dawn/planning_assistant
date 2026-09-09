/// **FR-TASK-03 点名的五种重复，逐条造得出来。**
///
/// ## 为什么要一条锚在需求上的守卫
///
/// 「每月 15 号」「每月最后一个周五」这两种，在这个提交之前是这样的：
///
///  · 引擎**完全支持** —— `recurrence-engine.md` 的 R-10…R-13 就是它们，
///    四条黄金用例一直是绿的，R-10 当初还专门跑过探针才写下期望值；
///  · 编辑器**造不出来** —— 重复区没有对应控件，
///    `RecurrenceDraft` 里连字段都没有；
///  · 已有的可达性守卫（`recurrence_reachability_test.dart`）**看不见**：
///    它扫的是「草稿的每个字段都有控件」，
///    而这两种能力从来没变成过字段。
///
/// 三层都「对」，需求却没落地。问题出在每条守卫的**全集**上：
/// 引擎的守卫问「引擎会不会算」，可达性的守卫问「已有的旋钮够不够得着」，
/// 没有一条问过「**需求点名的东西在不在**」。
///
/// 所以这条测试的全集来自需求原文，不来自代码：
/// requirements.md 的 FR-TASK-03 验收栏列了五种，这里就是那五种。
/// 少一种、或者哪天某种变得造不出来，这里红。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/local_wall_time.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/core/time/time_zone_resolver.dart';
import 'package:planning_assistant/core/time/weekday.dart';
import 'package:planning_assistant/domain/recurrence/recurrence_engine.dart';
import 'package:planning_assistant/domain/value_objects/recurrence.dart';
import 'package:planning_assistant/features/task/application/recurrence_draft.dart';
import 'package:timezone/data/latest.dart' as tzdata;

const _engine = RecurrenceEngine(TzTimeZoneResolver());

/// 把草稿当成一条从 [start] 起的任务展开，取日期串。
///
/// **不止验编码。** 只比 RRULE 串的话，一条串错了但两边一起错的实现
/// 照样绿；而且「每年 5 月 20 日」那条根本不在串里 ——
/// 它是 DTSTART 的性质。落到日子上才是用户看得见的东西。
List<String> _days(RecurrenceDraft draft, PlanDate start, DateRange window) {
  final raw = draft.toRrule();
  expect(raw, isNotNull, reason: '这条草稿编不出规则：${draft.blockedReason}');
  return _engine
      .expand(
        context: RecurrenceContext(
          taskId: 't1',
          dtStart: LocalWallTime(
            date: start,
            minuteOfDay: MinuteOfDay.of(9, 0),
            timeZoneId: 'Asia/Shanghai',
          ),
          isAllDay: false,
          recurrence: Recurrence.parse(raw!),
        ),
        window: window,
      )
      .map((o) => o.start.date.toString())
      .toList();
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('FR-TASK-03 验收栏点名的五种', () {
    test('「每 N 天」', () {
      const draft = RecurrenceDraft(enabled: true, interval: 3);
      expect(draft.toRrule(), 'RRULE:FREQ=DAILY;INTERVAL=3');
      expect(
        _days(
          draft,
          const PlanDate(2026, 1, 1),
          const DateRange(PlanDate(2026, 1, 1), PlanDate(2026, 1, 10)),
        ),
        ['2026-01-01', '2026-01-04', '2026-01-07', '2026-01-10'],
      );
    });

    test('「每周一三五」', () {
      const draft = RecurrenceDraft(
        enabled: true,
        frequency: RecurrenceFrequency.weekly,
        weekdays: {Weekday.monday, Weekday.wednesday, Weekday.friday},
      );
      expect(draft.toRrule(), 'RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR');
      expect(
        // 2026-01-05 是周一。
        _days(
          draft,
          const PlanDate(2026, 1, 5),
          const DateRange(PlanDate(2026, 1, 5), PlanDate(2026, 1, 11)),
        ),
        ['2026-01-05', '2026-01-07', '2026-01-09'],
      );
    });

    test('「每月 15 号」', () {
      const draft = RecurrenceDraft(
        enabled: true,
        frequency: RecurrenceFrequency.monthly,
        monthlyMode: MonthlyMode.onDate,
        monthDay: 15,
      );
      expect(draft.toRrule(), 'RRULE:FREQ=MONTHLY;BYMONTHDAY=15');
      expect(
        // **起始日不是 15 号**：这正是它与「跟开始日期同一天」的差别，
        // 也是这一档非做不可的理由 —— 房租每月 1 号交，
        // 与「我今天建这条任务」无关。
        _days(
          draft,
          const PlanDate(2026, 1, 3),
          const DateRange(PlanDate(2026, 1, 1), PlanDate(2026, 3, 31)),
        ),
        ['2026-01-15', '2026-02-15', '2026-03-15'],
      );
    });

    test('「每月最后一个周五」', () {
      const draft = RecurrenceDraft(
        enabled: true,
        frequency: RecurrenceFrequency.monthly,
        monthlyMode: MonthlyMode.onWeekday,
        monthOrdinal: lastDayOfMonth,
        monthWeekday: Weekday.friday,
      );
      expect(draft.toRrule(), 'RRULE:FREQ=MONTHLY;BYDAY=-1FR');
      expect(
        // 手算 2026：1 月 1 日是周四 → 周五落在 2/9/16/23/30，末个 1-30；
        // 2 月 1 日周日 → 6/13/20/27，末个 2-27；3 月 1 日周日 → 3-27。
        _days(
          draft,
          const PlanDate(2026, 1, 1),
          const DateRange(PlanDate(2026, 1, 1), PlanDate(2026, 3, 31)),
        ),
        ['2026-01-30', '2026-02-27', '2026-03-27'],
      );
    });

    test('「每年 5 月 20 日」', () {
      // 这一种**不在规则串里**：FREQ=YEARLY 按 DTSTART 的月日重复。
      // 所以它验的是「从 5/20 起的每年规则真的落在 5/20」，
      // 而不是某个 BY 部件 —— 拿 BYMONTH 去凑反而多此一举。
      const draft = RecurrenceDraft(
        enabled: true,
        frequency: RecurrenceFrequency.yearly,
      );
      expect(draft.toRrule(), 'RRULE:FREQ=YEARLY');
      expect(
        _days(
          draft,
          const PlanDate(2026, 5, 20),
          const DateRange(PlanDate(2026, 1, 1), PlanDate(2028, 12, 31)),
        ),
        ['2026-05-20', '2027-05-20', '2028-05-20'],
      );
    });
  });

  group('顺带把「月末」这一档钉住', () {
    test('「每月最后一天」不是「31 号」—— 31 号会漏掉 5 个月', () {
      // 这两档看着像一回事，差别是 5 次错过的提醒。
      const lastDay = RecurrenceDraft(
        enabled: true,
        frequency: RecurrenceFrequency.monthly,
        monthlyMode: MonthlyMode.onDate,
        monthDay: lastDayOfMonth,
      );
      const day31 = RecurrenceDraft(
        enabled: true,
        frequency: RecurrenceFrequency.monthly,
        monthlyMode: MonthlyMode.onDate,
        monthDay: 31,
      );
      const year = DateRange(PlanDate(2026, 1, 1), PlanDate(2026, 12, 31));

      expect(_days(lastDay, const PlanDate(2026, 1, 1), year), hasLength(12));
      expect(
        _days(day31, const PlanDate(2026, 1, 1), year),
        hasLength(7),
        reason: 'RFC 5545：无效日期是跳过，不是夹到月末',
      );
    });
  });
}

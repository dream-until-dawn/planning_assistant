/// `RecurrenceDraft.fromRrule` —— **只为显示**的反解。
///
/// 它存在的理由是一次真缺陷：卡片副信息用
/// `rule.contains('FREQ=WEEKLY')` 挑关键字拼句子，于是
/// `RRULE:FREQ=WEEKLY;INTERVAL=3;BYDAY=MO,WE,FR` 在卡片上显示成
/// **「每周」**。挑着认的部件拼出来的句子，缺的那部分不是「没说」，
/// 是「说错了」。
///
/// 所以这里验两件事，缺一不可：
///
///  1. **认得的规则要还原准** —— 用「编码 → 反解」的往返来验，
///     而不是手写一堆期望值：手写的话，编码器与反解器可以一起错。
///  2. **认不得的规则必须返回 null** —— 一个字都不许猜。
///     这一半更要紧：漏掉一种部件，带它的规则就会被显示成一条
///     不含它的规则，而那句话是错的，界面上看不出任何异常。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/core/time/weekday.dart';
import 'package:planning_assistant/domain/value_objects/recurrence.dart';
import 'package:planning_assistant/features/task/application/recurrence_draft.dart';

/// 编码再反解，拿回来的草稿。
RecurrenceDraft? _roundTrip(RecurrenceDraft draft) {
  final raw = draft.toRrule();
  if (raw == null) return null;
  return RecurrenceDraft.fromRrule(Recurrence.parse(raw));
}

void main() {
  group('界面造得出来的规则，反解回得来', () {
    final cases = <String, RecurrenceDraft>{
      '每天': const RecurrenceDraft(enabled: true),
      '每 3 天': const RecurrenceDraft(enabled: true, interval: 3),
      '每周一三五': const RecurrenceDraft(
        enabled: true,
        frequency: RecurrenceFrequency.weekly,
        weekdays: {Weekday.monday, Weekday.wednesday, Weekday.friday},
      ),
      '每 2 周的周二': const RecurrenceDraft(
        enabled: true,
        frequency: RecurrenceFrequency.weekly,
        interval: 2,
        weekdays: {Weekday.tuesday},
      ),
      '每月共 5 次': const RecurrenceDraft(
        enabled: true,
        frequency: RecurrenceFrequency.monthly,
        endMode: RecurrenceEndMode.count,
        count: 5,
      ),
      '每年到某日': const RecurrenceDraft(
        enabled: true,
        frequency: RecurrenceFrequency.yearly,
        endMode: RecurrenceEndMode.until,
        until: PlanDate(2027, 5, 20),
      ),
      // FR-TASK-03 点名的那两种，界面补上之后进了这张表 ——
      // 它们此前在下面「表达不了」那一组里。
      '每月 15 号': const RecurrenceDraft(
        enabled: true,
        frequency: RecurrenceFrequency.monthly,
        monthlyMode: MonthlyMode.onDate,
        monthDay: 15,
      ),
      '每月最后一天': const RecurrenceDraft(
        enabled: true,
        frequency: RecurrenceFrequency.monthly,
        monthlyMode: MonthlyMode.onDate,
        monthDay: lastDayOfMonth,
      ),
      '每月最后一个周五': const RecurrenceDraft(
        enabled: true,
        frequency: RecurrenceFrequency.monthly,
        monthlyMode: MonthlyMode.onWeekday,
        monthOrdinal: lastDayOfMonth,
        monthWeekday: Weekday.friday,
      ),
      '每 2 月的第二个周二': const RecurrenceDraft(
        enabled: true,
        frequency: RecurrenceFrequency.monthly,
        interval: 2,
        monthlyMode: MonthlyMode.onWeekday,
        monthOrdinal: 2,
        monthWeekday: Weekday.tuesday,
      ),
    };

    cases.forEach((name, original) {
      test(name, () {
        final back = _roundTrip(original);
        expect(back, isNotNull, reason: '这条是界面造出来的，不该认不出来');

        // 逐字段比，而不是比 `describe()` —— 两个不同的草稿可能说出
        // 同一句话（省略结束条件时尤其），那样比等于没比。
        expect(back!.frequency, original.frequency);
        expect(back.interval, original.interval);
        expect(back.weekdays, original.weekdays);
        expect(back.monthlyMode, original.monthlyMode);
        if (original.monthlyMode == MonthlyMode.onDate) {
          expect(back.monthDay, original.monthDay);
        }
        if (original.monthlyMode == MonthlyMode.onWeekday) {
          expect(back.monthOrdinal, original.monthOrdinal);
          expect(back.monthWeekday, original.monthWeekday);
        }
        expect(back.endMode, original.endMode);
        if (original.endMode == RecurrenceEndMode.count) {
          expect(back.count, original.count);
        }
        if (original.endMode == RecurrenceEndMode.until) {
          expect(back.until, original.until);
        }
        // 再编码一次必须得到同一个串 —— 这一条兜住「两边一起错」：
        // 反解丢了什么，重新编码就补不回来。
        expect(back.toRrule(), original.toRrule());
      });
    });
  });

  group('界面表达不了的规则，一个字都不猜', () {
    // 每一条都是**能被 rrule 包正常解析**的合法规则 ——
    // 验的是「我们认得出自己认不得它」，不是「解析会抛异常」。
    final unsupported = <String, String>{
      '每年第 100 天（BYYEARDAY）': 'RRULE:FREQ=YEARLY;BYYEARDAY=100',
      // 「每月」下的 BYMONTHDAY / 序号 BYDAY 现在认得了，
      // 但**只认界面真造得出来的那些形状**：
      '一个月里两天（BYMONTHDAY=15,20）': 'RRULE:FREQ=MONTHLY;BYMONTHDAY=15,20',
      '倒数第二天（界面只有「最后一天」）': 'RRULE:FREQ=MONTHLY;BYMONTHDAY=-2',
      '第五个周一（多数月份不存在，界面不给选）': 'RRULE:FREQ=MONTHLY;BYDAY=5MO',
      '倒数第二个周五': 'RRULE:FREQ=MONTHLY;BYDAY=-2FR',
      '一个月里两个序号（BYDAY=1MO,3MO）': 'RRULE:FREQ=MONTHLY;BYDAY=1MO,3MO',
      '号数与序号同时给（界面是二选一）': 'RRULE:FREQ=MONTHLY;BYMONTHDAY=15;BYDAY=1MO',
      // 不能拿 `FREQ=WEEKLY;BYMONTHDAY=15` 当例子：RFC 5545 直接禁了那个组合，
      // 库在解析时就抛 —— 这一组验的是「合法但我们表达不了」，不是「解析失败」。
      '每天里的 15 号（频率对不上）': 'RRULE:FREQ=DAILY;BYMONTHDAY=15',
      '每年下的序号 BYDAY（频率对不上）': 'RRULE:FREQ=YEARLY;BYDAY=-1FR',
      '每年 5 月（BYMONTH）': 'RRULE:FREQ=YEARLY;BYMONTH=5',
      '每天 9 点与 18 点（BYHOUR）': 'RRULE:FREQ=DAILY;BYHOUR=9,18',
      '每月工作日里的最后一个（BYSETPOS）':
          'RRULE:FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1',
      '每小时（界面没有的频率）': 'RRULE:FREQ=HOURLY',
      '每月的周一（BYDAY 配非周频率）': 'RRULE:FREQ=MONTHLY;BYDAY=MO',
    };

    unsupported.forEach((name, raw) {
      test(name, () {
        // 前置：这条串本身是合法的，否则这个用例什么也没验证。
        final recurrence = Recurrence.parse(raw);
        expect(recurrence.canonical, isNotEmpty);

        expect(
          RecurrenceDraft.fromRrule(recurrence),
          isNull,
          reason: '$raw 界面表达不了，必须返回 null 让调用方说「重复」',
        );
      });
    });

    test('对照组：认得的那条同样走这个入口，不是全都返回 null', () {
      // 少了这条，一个 `=> null` 的实现能让上面八条全绿。
      expect(
        RecurrenceDraft.fromRrule(Recurrence.parse('RRULE:FREQ=WEEKLY')),
        isNotNull,
      );
    });
  });

  group('说人话时省略结束条件（卡片副信息用）', () {
    const draft = RecurrenceDraft(
      enabled: true,
      frequency: RecurrenceFrequency.weekly,
      interval: 3,
      weekdays: {Weekday.monday, Weekday.wednesday, Weekday.friday},
      endMode: RecurrenceEndMode.until,
      until: PlanDate(2026, 10, 31),
    );

    test('省略的那一截确实省掉了', () {
      expect(draft.describe(withEnd: false), '每 3 周的一、三、五');
    });

    test('省略不等于说错：留下的部分与完整版逐字一致', () {
      // 「每 3 周」被砍成「每周」就是这条会红的情形。
      expect(draft.describe(), startsWith(draft.describe(withEnd: false)));
      expect(draft.describe(), contains('2026-10-31'));
    });
  });
}

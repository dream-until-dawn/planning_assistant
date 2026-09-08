/// 窗口展开：时间轴与日历问「这段时间里都发生什么」（view-specs §0.2）。
///
/// 与列表的 [expandForList] 刻意分开 —— 那边是一套 UX 策略
/// （逾期全留、未来只留下一次），这边由日期决定，不掺取舍。
///
/// ## 这一份是补出来的
///
/// `expandInWindow` 上一个提交就进来了，却**一条测试都没有** ——
/// 当时那批测试全是 `overlap_layout` 的。看着像「新功能带了测试」，
/// 实际上新函数裸奔。下面那条「每一次都带结束时刻」正是它掩护过的东西。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/core/time/time_zone_resolver.dart';
import 'package:planning_assistant/domain/entities/occurrence_override.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/recurrence/recurrence_engine.dart';
import 'package:planning_assistant/domain/value_objects/occurrence_key.dart';
import 'package:planning_assistant/domain/value_objects/recurrence.dart';
import 'package:planning_assistant/features/views/shared/application/occurrence_expansion.dart';
import 'package:planning_assistant/features/views/shared/application/task_occurrence.dart';
import 'package:planning_assistant/features/views/timeline/application/timeline_blocks.dart';
import 'package:timezone/data/latest.dart' as tzdata;

const _today = PlanDate(2026, 9, 8);
const _engine = RecurrenceEngine(TzTimeZoneResolver());

Task _task(
  String id, {
  PlanDate? date = _today,
  int? start,
  PlanDate? endDate,
  int? end,
  String? rrule,
  bool isAllDay = false,
}) => Task(
  id: id,
  title: id,
  kind: TaskKind.single,
  timeZoneId: 'Asia/Shanghai',
  planDate: date,
  startMinute: start == null ? null : MinuteOfDay(start),
  endDate: endDate,
  endMinute: end == null ? null : MinuteOfDay(end),
  isAllDay: isAllDay,
  recurrence: rrule == null ? null : Recurrence.parse(rrule),
);

List<TaskOccurrence> _window(List<Task> tasks, PlanDate from, PlanDate to) =>
    expandInWindow(
      tasks: tasks,
      overrides: const [],
      window: DateRange(from, to),
      engine: _engine,
    );

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('窗口内一次不落', () {
    test('每日规则在七天窗口里就是七行', () {
      // 列表会把它折成「下一次」一行（§0.2.2）。这里**不折** ——
      // 日历少了几天不该是一道要读策略分支才答得上的题。
      final rows = _window(
        [_task('晨会', start: 9 * 60, rrule: 'RRULE:FREQ=DAILY')],
        _today,
        _today.addDays(6),
      );
      expect(rows, hasLength(7));
      expect(rows.map((r) => r.planDate).toSet(), hasLength(7));
    });

    test('逾期又没做的那些也照样在，不做取舍', () {
      final rows = _window(
        [
          _task(
            '晨会',
            date: _today.addDays(-3),
            start: 9 * 60,
            rrule: 'RRULE:FREQ=DAILY',
          ),
        ],
        _today.addDays(-3),
        _today,
      );
      expect(rows, hasLength(4));
    });

    test('不重复的按窗口筛', () {
      final tasks = [_task('体检', date: _today.addDays(5), start: 60)];
      expect(_window(tasks, _today, _today.addDays(9)), hasLength(1));
      expect(_window(tasks, _today, _today.addDays(2)), isEmpty);
    });

    test('没有日期的不进来 —— 它不落在任何一天上', () {
      // 列表另有「无日期」分组管它（§2.1）；时间轴上没有它的位置。
      expect(_window([_task('总有一天', date: null)], _today, _today), isEmpty);
    });
  });

  group('每一次都要带上结束时刻', () {
    // ## 由来
    //
    // `RecurrenceContext.durationMinutes` 声明了、引擎也读它，
    // 但**从来没有人写过它** —— 于是每一次发生的 end 恒为 null。
    // 列表只显示开始时刻，所以整个 M2 都看不出来。
    // 时间轴是第一个要用结束时刻的视图，一接上就是
    // 「每条重复任务都是零长块」。

    test('9:00–10:00 的每日任务，每一次都是 9:00–10:00', () {
      final rows = _window(
        [
          _task(
            '晨会',
            start: 9 * 60,
            endDate: _today,
            end: 10 * 60,
            rrule: 'RRULE:FREQ=DAILY',
          ),
        ],
        _today,
        _today.addDays(2),
      );
      expect(rows, hasLength(3));
      for (final r in rows) {
        expect(r.endDate, r.planDate, reason: '当天结束');
        expect(r.endMinute?.value, 600);
      }
    });

    test('对照组：任务本来就没写结束的，还是没有结束', () {
      // 少了这条，一个「一律补一小时」的实现也能让上面绿 ——
      // 而那等于替用户假设时长（§1.2 明确不做）。
      final rows = _window(
        [_task('打卡', start: 9 * 60, rrule: 'RRULE:FREQ=DAILY')],
        _today,
        _today,
      );
      expect(rows.single.endMinute, isNull);
      expect(rows.single.endDate, isNull);
    });

    test('跨天的重复任务，每一次都跨到第二天', () {
      final rows = _window(
        [
          _task(
            '值夜',
            start: 22 * 60,
            endDate: _today.addDays(1),
            end: 6 * 60,
            rrule: 'RRULE:FREQ=DAILY',
          ),
        ],
        _today,
        _today.addDays(1),
      );
      expect(rows, hasLength(2));
      for (final r in rows) {
        expect(r.endDate, r.planDate!.addDays(1));
        expect(r.endMinute?.value, 360);
      }
    });

    test('挪走某一次，结束时刻跟着一起挪', () {
      // 时长是**规则的**属性，不是某一天的。挪了开始而结束留在原处的话，
      // 被挪走的那一次会画出一个负长度、或者一个从 14:00 回到 10:00 的块。
      final rows = expandInWindow(
        tasks: [
          _task(
            '晨会',
            start: 9 * 60,
            endDate: _today,
            end: 10 * 60,
            rrule: 'RRULE:FREQ=DAILY',
          ),
        ],
        overrides: [
          OccurrenceOverride(
            taskId: '晨会',
            key: OccurrenceKey.timed(_today, MinuteOfDay(9 * 60)),
            action: OverrideAction.modify,
            startMinuteOverride: MinuteOfDay(14 * 60),
          ),
        ],
        window: const DateRange(_today, _today),
        engine: _engine,
      );
      expect(rows.single.startMinute?.value, 840);
      expect(rows.single.endMinute?.value, 900, reason: '还是一小时，只是整块挪了');
    });
  });

  group('全天任务的结束只能是整天', () {
    test('三天的全天休假，每一次都覆盖三天', () {
      // 不给 end 的话它在日历与甘特上只剩第一天 ——
      // 那看起来像「只存了一天」，不像「刻意不表示时刻」。
      final rows = _window(
        [
          _task(
            '休假',
            endDate: _today.addDays(2),
            isAllDay: true,
            rrule: 'RRULE:FREQ=MONTHLY',
          ),
        ],
        _today,
        _today,
      );
      expect(rows.single.endDate, _today.addDays(2));
      expect(rows.single.endMinute, isNull, reason: '全天没有结束时刻');
      expect(rows.single.startMinute, isNull);
    });

    test('单天的全天任务没有跨到第二天', () {
      final rows = _window(
        [
          _task(
            '纪念日',
            endDate: _today,
            isAllDay: true,
            rrule: 'RRULE:FREQ=YEARLY',
          ),
        ],
        _today,
        _today,
      );
      expect(rows.single.endDate, _today);
    });
  });

  group('两条路径必须读出同一个块', () {
    // 同一形态的任务，不重复的直接读 task.endDate/endMinute，
    // 重复的先被折成 durationMinutes 再由引擎还原成 end。
    // 两处读法一旦分叉，表现是「同一件事设成重复之后块变了」——
    // 没人会把它当 bug 报，但它是两套语义的证据。

    void sameBlock(String name, Task plain, Task repeating, PlanDate on) {
      test(name, () {
        final a = timelineDayFor(_window([plain], on, on), on);
        final b = timelineDayFor(_window([repeating], on, on), on);
        expect(
          b.blocks.map((x) => (x.startMinute, x.endMinute, x.continuesAfter)),
          a.blocks.map((x) => (x.startMinute, x.endMinute, x.continuesAfter)),
          reason: '$on 这一天两条路径画出来不一样',
        );
        expect(b.allDay.length, a.allDay.length, reason: '$on 这一天「随时」区的条数不一样');
      });
    }

    sameBlock(
      '有头有尾的',
      _task('a', start: 9 * 60, endDate: _today, end: 10 * 60),
      _task(
        'b',
        start: 9 * 60,
        endDate: _today,
        end: 10 * 60,
        rrule: 'RRULE:FREQ=DAILY',
      ),
      _today,
    );

    sameBlock(
      '有结束日期没有结束时刻的 —— 三处都得按 23:59 读',
      _task('a', start: 14 * 60, endDate: _today),
      _task('b', start: 14 * 60, endDate: _today, rrule: 'RRULE:FREQ=DAILY'),
      _today,
    );

    sameBlock(
      '跨天的，看后一天那半截',
      _task('a', start: 22 * 60, endDate: _today.addDays(1), end: 60),
      _task(
        'b',
        start: 22 * 60,
        endDate: _today.addDays(1),
        end: 60,
        rrule: 'RRULE:FREQ=WEEKLY',
      ),
      _today,
    );

    sameBlock(
      '跨多天的全天任务',
      _task('a', endDate: _today.addDays(2), isAllDay: true),
      _task(
        'b',
        endDate: _today.addDays(2),
        isAllDay: true,
        rrule: 'RRULE:FREQ=MONTHLY',
      ),
      _today,
    );
  });
}

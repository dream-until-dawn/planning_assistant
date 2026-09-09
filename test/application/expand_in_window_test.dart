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
import 'package:planning_assistant/core/time/date_and_minute.dart';
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

  group('按覆盖区间收，不按开始日期', () {
    // 「9/1 到 9/30 的项目」在 9/15 那天的时间轴上必须在。
    // 按开始日期筛的话它只在 9/1 出现一次，中间二十九天空空如也 ——
    // 那看起来像「这个任务不见了」，不像「窗口没框住它」。

    test('跨月的项目，中间任何一天都在', () {
      final tasks = [
        _task(
          '项目',
          date: _today.addDays(-7),
          endDate: _today.addDays(7),
          isAllDay: true,
        ),
      ];
      expect(_window(tasks, _today, _today), hasLength(1));
      expect(
        _window(tasks, _today.addDays(7), _today.addDays(7)),
        hasLength(1),
      );
      expect(_window(tasks, _today.addDays(8), _today.addDays(8)), isEmpty);
      expect(
        _window(tasks, _today.addDays(-8), _today.addDays(-8)),
        isEmpty,
        reason: '开始之前也不该有',
      );
    });

    test('昨晚的值夜，今天上午这一段也要在', () {
      // 22:00 干到明早 6:00。只看开始日期的话，今天的时间轴上
      // 从零点到六点是空的 —— 而人正睡在那儿。
      final rows = _window(
        [
          _task(
            '值夜',
            date: _today.addDays(-1),
            start: 22 * 60,
            endDate: _today,
            end: 6 * 60,
          ),
        ],
        _today,
        _today,
      );
      expect(rows, hasLength(1));
    });

    test('重复的值夜也一样 —— 引擎按开始日期筛，得往前多展开', () {
      final rows = _window(
        [
          _task(
            '值夜',
            date: _today.addDays(-30),
            start: 22 * 60,
            endDate: _today.addDays(-29),
            end: 6 * 60,
            rrule: 'RRULE:FREQ=DAILY',
          ),
        ],
        _today,
        _today,
      );
      // 今天开始的那一次，加上昨晚延续过来的那一次。
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.planDate).toSet(), {_today, _today.addDays(-1)});
    });

    test('跨三天的重复排班，落在中间那天也要在', () {
      // 往前多展开的天数如果写死成 1，这条就红：这一次的开始在两天前，
      // 引擎在「窗口前一天」里根本生成不出它。
      //
      // 上面那条值夜只跨一天，写死 1 也能过 —— 单靠它，
      // 「按任务自己的时长往前展」与「一律往前一天」区分不开。
      final rows = _window(
        [
          _task(
            '排班',
            date: _today.addDays(-2),
            start: 8 * 60,
            endDate: _today.addDays(1),
            end: 8 * 60,
            rrule: 'RRULE:FREQ=WEEKLY',
          ),
        ],
        _today,
        _today,
      );
      expect(rows, hasLength(1));
      expect(rows.single.planDate, _today.addDays(-2));
      expect(rows.single.endDate, _today.addDays(1));
    });

    group('往前展开有个上界，而这个上界必须两头都钉住', () {
      // ## 由来：一次只钉住了一头的变异演练
      //
      // 上界原本只有一句注释：「跨度超过它的重复任务，中间那些天不会
      // 出现在窗口里」。往小改（62 → 1）有测试红，往大改（62 → 400）
      // **全绿** —— 也就是那句注释描述的后果，一条测试都没有。
      //
      // 按 §7.1.1：带着「必须这样写」注释的代码，若没有任何测试会因为
      // 换成另一种写法而变红，那句注释迟早被人合理地删掉。改的人会
      // 认为自己没破坏任何东西 —— 而他实际改掉的是每条重复规则的
      // 展开成本。
      //
      // ## 为什么下面的天数是**写死的字面量**
      //
      // 跟着 `_maxSpanDays` 走的话，改常量时测试的夹具也跟着改，
      // 两头一起挪，什么都锁不住 —— 与「守卫比的是两张都过时的表」
      // 是同一种毛病。所以这里的 62 / 70 是手写的，改常量就得改这里，
      // 那正是它该起的作用。

      /// 一条每年一次、每次持续 [spanDays] 天的全天任务，从 [startsAgo] 天前开始。
      List<Task> spanning({required int startsAgo, required int spanDays}) => [
        _task(
          '长任务',
          date: _today.addDays(-startsAgo),
          endDate: _today.addDays(-startsAgo + spanDays),
          isAllDay: true,
          rrule: 'RRULE:FREQ=YEARLY',
        ),
      ];

      test('界内：正好跨 62 天，第 62 天上它还在', () {
        // 开始在 62 天前，往前多展开 62 天正好够到它。
        // 上界调小（比如 61 或 1）这条就红。
        expect(
          _window(spanning(startsAgo: 62, spanDays: 62), _today, _today),
          hasLength(1),
        );
      });

      test('越界：刚过界一天（第 63 天）就缺席', () {
        // 这是那句注释说的「已知限制」，现在它是一条**行为**。
        //
        // **刻意只过界一天**：写成「第 70 天」的话，62 改成 63..69
        // 里的任何一个都不会红 —— 上界就只是被夹在一个区间里，
        // 而不是被钉在 62 上。第一版正是这么写的，62 → 63 全绿。
        expect(
          _window(spanning(startsAgo: 63, spanDays: 80), _today, _today),
          isEmpty,
          reason: '超过上界的那部分刻意不展开，不是漏了',
        );
      });

      test('对照组：同一段日子，**不重复**的照样在', () {
        // 与上面那条只差「重不重复」：上界只管重复任务的展开成本，
        // 一次性的长任务走的是区间求交，不受它影响。
        //
        // 少了这条，上面那条「缺席」看起来会像「长任务会消失」——
        // 一个吓人得多、而且是错的结论。
        final rows = _window(
          [
            _task(
              '项目',
              date: _today.addDays(-63),
              endDate: _today.addDays(17),
              isAllDay: true,
            ),
          ],
          _today,
          _today,
        );
        expect(rows, hasLength(1));
      });
    });

    test('对照组：多展开出来的那些，没碰到窗口就得扔掉', () {
      // 少了这条，一个「多展开了就全都留下」的实现也能让上面绿 ——
      // 而那会让每天的时间轴上都多出一条昨天的、早就结束了的事。
      final rows = _window(
        [
          _task(
            '晨会',
            date: _today.addDays(-30),
            start: 9 * 60,
            endDate: _today.addDays(-30),
            end: 10 * 60,
            rrule: 'RRULE:FREQ=DAILY',
          ),
        ],
        _today,
        _today,
      );
      expect(rows, hasLength(1));
      expect(rows.single.planDate, _today);
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

  group('两条路径必须读出同一个跨度', () {
    // 同一形态的任务，不重复的直接读 task.endDate/endMinute，
    // 重复的先被折成 durationMinutes 再由引擎还原成 end。
    // 两处读法一旦分叉，表现是「同一件事设成重复之后跨度变了」——
    // 没人会把它当 bug 报，但它是两套语义的证据。
    //
    // ## 量的是 `EffectiveSpan`，不再是时间轴的块
    //
    // 这一组原本拿 `timelineDayFor` 当量具 —— 时间轴改成跨天议程之后
    // 那个函数没了。换成直接量 `TaskOccurrence.span`：**四个视图的
    // 跨度都由它给**（data-model §4.7），所以它才是这条不变量的落点，
    // 而当初那个块只是碰巧读了它。

    ({int start, int end, bool allDay}) shapeOf(TaskOccurrence row) {
      final span = row.span!;
      return (
        start:
            span.start.date.differenceInDays(row.planDate!) * minutesPerDay +
            span.start.minute.value,
        end:
            span.end.date.differenceInDays(row.planDate!) * minutesPerDay +
            span.end.minute.value,
        allDay: row.isAllDay,
      );
    }

    void sameBlock(String name, Task plain, Task repeating, PlanDate on) {
      test(name, () {
        final a = _window([plain], on, on);
        final b = _window([repeating], on, on);
        expect(b.map(shapeOf), a.map(shapeOf), reason: '$on 这天两条路径不一样');
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

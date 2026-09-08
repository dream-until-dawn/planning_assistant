/// 时间轴上一天的排布（view-specs §1.2）。
///
/// ## 为什么这一层要单独测
///
/// 「跨天任务在当天从几点画到几点」如果只在 widget 里算，验它就得靠
/// 量像素：块的顶边在 y=180 还是 y=182，看不出是「00:00 开始」还是
/// 「昨晚延续过来」。抽成纯函数之后，这些都是可以直接断言的整数。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/local_wall_time.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/domain/entities/occurrence.dart';
import 'package:planning_assistant/domain/entities/stage.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/value_objects/occurrence_key.dart';
import 'package:planning_assistant/features/views/shared/application/task_occurrence.dart';
import 'package:planning_assistant/features/views/timeline/application/timeline_blocks.dart';

const _today = PlanDate(2026, 9, 8);
const _yesterday = PlanDate(2026, 9, 7);
const _tomorrow = PlanDate(2026, 9, 9);

TaskOccurrence _row(
  String id, {
  PlanDate? date = _today,
  int? start,
  PlanDate? endDate,
  int? end,
  bool isAllDay = false,
}) => TaskOccurrence(
  task: Task(
    id: id,
    title: id,
    kind: TaskKind.single,
    timeZoneId: 'Asia/Shanghai',
    planDate: date,
    startMinute: start == null ? null : MinuteOfDay(start),
    endDate: endDate,
    endMinute: end == null ? null : MinuteOfDay(end),
    isAllDay: isAllDay,
  ),
);

/// 找出某一行对应的块。找不到就是「没画在这一天上」。
TimelineBlock? _blockOf(TimelineDay day, String id) {
  for (final b in day.blocks) {
    if (b.row.id == id) return b;
  }
  return null;
}

void main() {
  group('当天之内', () {
    test('起止就是它自己，两头都不续', () {
      final day = timelineDayFor([
        _row('午饭', start: 12 * 60, endDate: _today, end: 13 * 60),
      ], _today);
      final b = day.blocks.single;
      expect(b.startMinute, 720);
      expect(b.endMinute, 780);
      expect(b.durationMinutes, 60);
      expect(b.continuesBefore, isFalse);
      expect(b.continuesAfter, isFalse);
    });

    test('别的日子的不进来', () {
      final day = timelineDayFor([
        _row('明天的', date: _tomorrow, start: 9 * 60),
      ], _today);
      expect(day.blocks, isEmpty);
      expect(day.isEmpty, isTrue);
    });
  });

  group('跨天：同一件事在三天里各画一截', () {
    // 9/7 22:00 → 9/9 01:00。
    List<TaskOccurrence> rows() => [
      _row('通宵', date: _yesterday, start: 22 * 60, endDate: _tomorrow, end: 60),
    ];

    test('第一天画到当天末尾，只标「续到后面」', () {
      final b = timelineDayFor(rows(), _yesterday).blocks.single;
      expect(b.startMinute, 22 * 60);
      expect(b.endMinute, minutesPerDay, reason: '当天末尾，不是 1439');
      expect(b.continuesBefore, isFalse);
      expect(b.continuesAfter, isTrue);
    });

    test('中间那天占满，两头都续', () {
      final b = timelineDayFor(rows(), _today).blocks.single;
      expect((b.startMinute, b.endMinute), (0, minutesPerDay));
      expect(b.continuesBefore, isTrue);
      expect(b.continuesAfter, isTrue);
    });

    test('最后一天从零点画到结束，只标「从前面续来」', () {
      final b = timelineDayFor(rows(), _tomorrow).blocks.single;
      expect((b.startMinute, b.endMinute), (0, 60));
      expect(b.continuesBefore, isTrue);
      expect(b.continuesAfter, isFalse);
    });

    test('再往后一天就没有了', () {
      expect(timelineDayFor(rows(), _tomorrow.addDays(1)).blocks, isEmpty);
    });

    test('对照组：不跨天的不会被标成「续」', () {
      // 少了这条，一个「continuesAfter 恒为 true」的实现也能让上面全绿。
      final b = timelineDayFor([
        _row('短会', start: 60, endDate: _today, end: 120),
      ], _today).blocks.single;
      expect(b.continuesBefore, isFalse);
      expect(b.continuesAfter, isFalse);
    });
  });

  group('日界线上的那一分钟', () {
    test('正好在零点结束的，属于前一天，不属于今天', () {
      // 左闭右开：否则每一件「干到半夜」的事都会在第二天顶上多一条
      // 零高的横杠。
      final rows = [
        _row('赶工', date: _yesterday, start: 23 * 60, endDate: _today, end: 0),
      ];
      expect(timelineDayFor(rows, _yesterday).blocks, hasLength(1));
      expect(timelineDayFor(rows, _today).blocks, isEmpty);
    });

    test('零点开始、没有时长的，要留在今天', () {
      // 它的 end 也是 0 —— 跟上面那条「正好在零点结束」的数字一模一样。
      // 按「end <= 0 就丢掉」写的话，这条会连同上面一起被丢，
      // 而表现是「零点的待办凭空消失」，不是「排布不好看」。
      final day = timelineDayFor([_row('打卡', start: 0)], _today);
      expect(day.blocks, hasLength(1));
      expect(day.blocks.single.durationMinutes, 0);
    });

    test('23:59 开始、没有时长的，不算续到明天', () {
      final rows = [_row('临睡', start: 23 * 60 + 59)];
      expect(
        timelineDayFor(rows, _today).blocks.single.continuesAfter,
        isFalse,
      );
      expect(timelineDayFor(rows, _tomorrow).blocks, isEmpty);
    });
  });

  group('没写结束的那些', () {
    test('连结束日期都没有 → 零长，不替用户假设时长', () {
      final b = timelineDayFor([
        _row('取快递', start: 10 * 60),
      ], _today).blocks.single;
      expect(b.startMinute, 600);
      expect(b.endMinute, 600);
      expect(b.durationMinutes, 0);
    });

    test('有结束日期、没有结束时刻 → 到那一天的 23:59', () {
      // 编辑器允许只选结束日不选结束时刻。按零长画的话，
      // 「从今天 14:00 忙到明天」在时间轴上会缩成今天下午的一个点，
      // 明天什么都没有。
      final rows = [_row('出差', start: 14 * 60, endDate: _tomorrow)];
      final first = timelineDayFor(rows, _today).blocks.single;
      expect((first.startMinute, first.endMinute), (840, minutesPerDay));
      expect(first.continuesAfter, isTrue);

      final last = timelineDayFor(rows, _tomorrow).blocks.single;
      expect((last.startMinute, last.endMinute), (0, minutesPerDay - 1));
      expect(last.continuesBefore, isTrue);
      expect(last.continuesAfter, isFalse, reason: '结束日之后没有了');
    });
  });

  group('阶段能把块撑长（data-model §4.7、甘特 G-05）', () {
    /// 一条 9:00 开始、存储的结束是 10:00、但阶段排到 12:00 的任务。
    TaskOccurrence staged() => TaskOccurrence(
      task: Task(
        id: '搬家',
        title: '搬家',
        kind: TaskKind.staged,
        timeZoneId: 'Asia/Shanghai',
        planDate: _today,
        startMinute: MinuteOfDay.of(9, 0),
        endDate: _today,
        endMinute: MinuteOfDay.of(10, 0),
      ),
      stages: const [
        Stage(
          id: 's1',
          taskId: '搬家',
          title: '搬运',
          orderIndex: 0,
          startOffsetMinutes: 0,
          durationMinutes: 180,
        ),
      ],
    );

    test('块画到阶段结束，不是存储的结束', () {
      // 用 `row.endMinute` 的话这里是 540..600 —— 而甘特会画到 720，
      // 同一条任务在两个视图里一长一短。§4.7 那条规则防的就是这个。
      final b = timelineDayFor([staged()], _today).blocks.single;
      expect((b.startMinute, b.endMinute), (540, 720));
    });

    test('阶段跨到第二天时，第二天也有它', () {
      // **这条盯的是「日期」那一侧**。上面那条只跨到当天 12:00，
      // 有效结束与存储结束**是同一天**，于是把 `effectiveEndDate`
      // 换回 `endDate` 照样绿 —— 变异演练里它活了下来。
      // 要区分开，阶段得越过午夜。
      final row = TaskOccurrence(
        task: Task(
          id: '搬家',
          title: '搬家',
          kind: TaskKind.staged,
          timeZoneId: 'Asia/Shanghai',
          planDate: _today,
          startMinute: MinuteOfDay.of(9, 0),
          endDate: _today,
          endMinute: MinuteOfDay.of(10, 0),
        ),
        stages: const [
          Stage(
            id: 's1',
            taskId: '搬家',
            title: '搬运',
            orderIndex: 0,
            startOffsetMinutes: 0,
            // 9:00 + 29 小时 = 第二天 14:00。
            durationMinutes: 29 * 60,
          ),
        ],
      );

      final first = timelineDayFor([row], _today).blocks.single;
      expect(first.continuesAfter, isTrue);

      final second = timelineDayFor([row], _tomorrow).blocks.single;
      expect((second.startMinute, second.endMinute), (0, 14 * 60));
      expect(second.continuesBefore, isTrue);
    });

    test('对照组：没有阶段时还是存储的那一段', () {
      // 少了这条，一个「一律加两小时」的实现也能让上面绿。
      final b = timelineDayFor([
        _row('搬家', start: 9 * 60, endDate: _today, end: 10 * 60),
      ], _today).blocks.single;
      expect((b.startMinute, b.endMinute), (540, 600));
    });
  });

  group('「随时」区', () {
    test('全天任务不占时间轴', () {
      final day = timelineDayFor([_row('纪念日', isAllDay: true)], _today);
      expect(day.blocks, isEmpty, reason: '全天不能被当成 00:00 的块');
      expect(day.allDay.single.id, '纪念日');
      expect(day.isEmpty, isFalse);
    });

    test('只有日期没有时刻的也归这里', () {
      final day = timelineDayFor([_row('看牙')], _today);
      expect(day.blocks, isEmpty);
      expect(day.allDay, hasLength(1));
    });

    test('跨多天的全天任务，中间每一天都在', () {
      final rows = [
        _row('休假', date: _yesterday, endDate: _tomorrow, isAllDay: true),
      ];
      for (final d in [_yesterday, _today, _tomorrow]) {
        expect(timelineDayFor(rows, d).allDay, hasLength(1), reason: '$d');
      }
      expect(timelineDayFor(rows, _tomorrow.addDays(1)).allDay, isEmpty);
      expect(timelineDayFor(rows, _yesterday.addDays(-1)).allDay, isEmpty);
    });

    test('没有日期的既不进轴也不进「随时」', () {
      // 它不落在任何一天上。列表另有「无日期」分组管它（§2.1）。
      final day = timelineDayFor([_row('总有一天', date: null)], _today);
      expect(day.isEmpty, isTrue);
    });
  });

  group('顺序是稳定的', () {
    test('块按开始时刻排', () {
      final day = timelineDayFor([
        _row('c', start: 15 * 60),
        _row('a', start: 8 * 60),
        _row('b', start: 12 * 60),
      ], _today);
      expect(day.blocks.map((b) => b.row.id), ['a', 'b', 'c']);
    });

    test('同一时刻开始的按 id 兜底 —— 换个输入顺序结果一样', () {
      // 不兜底的话，同一天进两次可能得到不同的左右排布：
      // 看着像「卡片自己跳了一下」，不像排序不稳。
      List<String> ids(List<TaskOccurrence> rows) =>
          timelineDayFor(rows, _today).blocks.map((b) => b.row.id).toList();
      final x = _row('x', start: 540);
      final y = _row('y', start: 540);
      expect(ids([x, y]), ids([y, x]));
      expect(ids([y, x]), ['x', 'y']);
    });

    test('「随时」区也按 id 排 —— 也就是大致按创建顺序', () {
      // 真实 id 是 UUID v7，字典序 ≈ 生成时序（同 task_grouping 里的
      // `byId`）。所以「按 id」在界面上读起来是「先建的在上面」，
      // 不是随机顺序。
      final day = timelineDayFor([_row('t2'), _row('t1')], _today);
      expect(day.allDay.map((r) => r.id), ['t1', 't2']);
    });

    test('跨天块排在当天开头 —— 它是从 00:00 起画的', () {
      final day = timelineDayFor([
        _row('早八', start: 8 * 60),
        _row('通宵', date: _yesterday, start: 22 * 60, endDate: _today, end: 60),
      ], _today);
      expect(day.blocks.first.row.id, '通宵');
    });
  });

  group('重复任务的某一次', () {
    TaskOccurrence occurrence({required int startMinute, int? endMinute}) {
      const date = _today;
      return TaskOccurrence(
        task: Task(
          id: '晨会',
          title: '晨会',
          kind: TaskKind.single,
          timeZoneId: 'Asia/Shanghai',
          planDate: date,
          startMinute: MinuteOfDay(startMinute),
        ),
        occurrence: Occurrence(
          taskId: '晨会',
          key: OccurrenceKey.timed(date, MinuteOfDay(startMinute)),
          start: LocalWallTime(
            date: date,
            minuteOfDay: MinuteOfDay(startMinute),
            timeZoneId: 'Asia/Shanghai',
          ),
          end: endMinute == null
              ? null
              : LocalWallTime(
                  date: date,
                  minuteOfDay: MinuteOfDay(endMinute),
                  timeZoneId: 'Asia/Shanghai',
                ),
          isAllDay: false,
        ),
      );
    }

    test('用的是这一次的生效时刻，块的行标识带上 key', () {
      final day = timelineDayFor([
        occurrence(startMinute: 9 * 60, endMinute: 10 * 60),
      ], _today);
      final b = day.blocks.single;
      expect((b.startMinute, b.endMinute), (540, 600));
      expect(b.row.id, '晨会#2026-09-08T09:00');
    });

    test('这一次没写结束 → 零长，不去拿任务上的结束', () {
      expect(
        timelineDayFor([
          occurrence(startMinute: 9 * 60),
        ], _today).blocks.single.durationMinutes,
        0,
      );
    });
  });

  test('无论怎么跨，起止都在 0..1440 之内且不倒挂', () {
    // 这条是给下游兜底的：widget 直接拿这两个数算 y 坐标，
    // 越界会画到别人的格子里，倒挂会得到负高度然后抛。
    final rows = [
      _row('跨三天', date: _yesterday, start: 23 * 60, endDate: _tomorrow, end: 1),
      _row('当天', start: 0, endDate: _today, end: minutesPerDay - 1),
      _row('零长', start: 720),
    ];
    for (final d in [_yesterday, _today, _tomorrow]) {
      for (final b in timelineDayFor(rows, d).blocks) {
        expect(b.startMinute, inInclusiveRange(0, minutesPerDay));
        expect(b.endMinute, inInclusiveRange(0, minutesPerDay));
        expect(b.durationMinutes, greaterThanOrEqualTo(0));
      }
    }
    expect(_blockOf(timelineDayFor(rows, _today), '跨三天'), isNotNull);
  });
}

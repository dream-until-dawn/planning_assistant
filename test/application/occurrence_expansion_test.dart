/// 把任务展开成「一行一次发生」（view-specs §0.2、FR-TASK-05）。
///
/// 展开之前，一条「每天」的任务在列表里只占**一行** —— 用户看不到
/// 明天那次、也勾不了昨天那次。而勾今天那次会直接抛
/// `DomainInvariantViolation`（`tasks.status` 恒为 pending）。
///
/// 这里验的是展开这条纯函数：给一批任务与例外，出来的行是确定的。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/core/time/time_zone_resolver.dart';
import 'package:planning_assistant/domain/entities/occurrence.dart';
import 'package:planning_assistant/domain/entities/occurrence_override.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/recurrence/recurrence_engine.dart';
import 'package:planning_assistant/domain/value_objects/occurrence_key.dart';
import 'package:planning_assistant/domain/value_objects/recurrence.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';
import 'package:planning_assistant/features/views/shared/application/occurrence_expansion.dart';
import 'package:planning_assistant/features/views/shared/application/task_occurrence.dart';
import 'package:timezone/data/latest.dart' as tzdata;

const _today = PlanDate(2026, 9, 8);
const _engine = RecurrenceEngine(TzTimeZoneResolver());

Task _task(
  String id, {
  PlanDate? date,
  MinuteOfDay? minute,
  String? rrule,
  bool isAllDay = false,
}) => Task(
  id: id,
  title: id,
  kind: TaskKind.single,
  timeZoneId: 'Asia/Shanghai',
  planDate: date,
  startMinute: minute,
  isAllDay: isAllDay,
  recurrence: rrule == null ? null : Recurrence.parse(rrule),
);

List<TaskOccurrence> _expand(
  List<Task> tasks, {
  List<OccurrenceOverride> overrides = const [],
}) => expandForList(
  tasks: tasks,
  overrides: overrides,
  today: _today,
  engine: _engine,
);

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('不重复的任务：一行，就是任务本身', () {
    test('有日期的', () {
      final rows = _expand([_task('a', date: _today)]);
      expect(rows, hasLength(1));
      expect(rows.single.isOccurrence, isFalse);
      expect(rows.single.id, 'a', reason: '不重复的行 id 就是 taskId');
    });

    test('**没有日期的也要在**', () {
      // 「无日期」是合法且常见的状态（FR-TASK-01：仅填标题即可保存），
      // 而列表里专门有这一组（§2.1）。展开时把它漏掉的话，
      // 用户填了标题就存的那些任务会从列表里消失。
      final rows = _expand([_task('没日期')]);
      expect(rows, hasLength(1));
      expect(rows.single.planDate, isNull);
    });

    test('**窗口之外的也要在**', () {
      // 窗口只管重复任务。一次性的「明年那件事」只有一次，
      // 不存在展不完的问题 —— 从列表里消失会让人以为它丢了。
      final far = _today.addDays(ListHorizon.futureDays + 100);
      final rows = _expand([_task('明年', date: far)]);
      expect(rows, hasLength(1));
      expect(rows.single.planDate, far);
    });
  });

  group('重复的任务：窗口内每一次一行', () {
    test('每天 → 窗口有多少天就有多少行', () {
      final rows = _expand([
        _task('晨会', date: _today, rrule: 'RRULE:FREQ=DAILY', isAllDay: true),
      ]);
      // 窗口是 [今天-14, 今天+60]，但规则从**今天**起算，
      // 所以往前那 14 天没有发生。
      expect(rows, hasLength(ListHorizon.futureDays + 1));
      expect(rows.first.planDate, _today);
      expect(rows.last.planDate, _today.addDays(ListHorizon.futureDays));
    });

    test('每行有自己的 id', () {
      // 拿 taskId 当行标识的话，三十行共用一个 key ——
      // Flutter 的列表复用会认错行，勾一行动的是另一行。
      final rows = _expand([
        _task('晨会', date: _today, rrule: 'RRULE:FREQ=WEEKLY', isAllDay: true),
      ]);
      expect(rows.map((r) => r.id).toSet(), hasLength(rows.length));
      expect(rows.first.id, startsWith('晨会#'));
    });

    test('窗口之外的那些次不产出', () {
      // 「每天」是无限的，没有窗口就展不完。
      final rows = _expand([
        _task('晨会', date: _today, rrule: 'RRULE:FREQ=DAILY', isAllDay: true),
      ]);
      expect(
        rows.every(
          (r) => !r.planDate!.isAfter(_today.addDays(ListHorizon.futureDays)),
        ),
        isTrue,
      );
    });

    test('开始日期在过去时，往前也展开到窗口下界', () {
      // 逾期组要看得见漏掉的那几次。
      final start = _today.addDays(-30);
      final rows = _expand([
        _task('晨会', date: start, rrule: 'RRULE:FREQ=DAILY', isAllDay: true),
      ]);
      expect(
        rows.first.planDate,
        _today.addDays(-ListHorizon.pastDays),
        reason: '窗口下界之前的不展开 —— 否则搁置三个月会堆出九十行逾期',
      );
    });
  });

  group('例外作用在对应的那一次上（FR-TASK-05）', () {
    Task daily() =>
        _task('晨会', date: _today, rrule: 'RRULE:FREQ=DAILY', isAllDay: true);

    OccurrenceKey keyOn(PlanDate d) => OccurrenceKey.allDay(d);

    test('标记完成只影响那一次', () {
      final rows = _expand(
        [daily()],
        overrides: [
          OccurrenceOverride(
            taskId: '晨会',
            key: keyOn(_today),
            action: OverrideAction.modify,
            status: OccurrenceStatus.done,
          ),
        ],
      );

      final todayRow = rows.firstWhere((r) => r.planDate == _today);
      final tomorrowRow = rows.firstWhere(
        (r) => r.planDate == _today.addDays(1),
      );
      expect(todayRow.status, TaskStatus.done);
      expect(
        tomorrowRow.status,
        TaskStatus.pending,
        reason: '只该影响被标记的那一次 —— 影响全部的话，勾一次等于把整条规则做完了',
      );
    });

    test('跳过某一次 → 那一行不出现', () {
      final rows = _expand(
        [daily()],
        overrides: [OccurrenceOverride.skip(taskId: '晨会', key: keyOn(_today))],
      );
      expect(rows.any((r) => r.planDate == _today), isFalse);
      expect(rows.any((r) => r.planDate == _today.addDays(1)), isTrue);
    });

    test('改某一次的标题，只有那一行变', () {
      final rows = _expand(
        [daily()],
        overrides: [
          OccurrenceOverride(
            taskId: '晨会',
            key: keyOn(_today),
            action: OverrideAction.modify,
            titleOverride: '今天改成站会',
          ),
        ],
      );
      expect(rows.firstWhere((r) => r.planDate == _today).title, '今天改成站会');
      expect(
        rows.firstWhere((r) => r.planDate == _today.addDays(1)).title,
        '晨会',
      );
    });

    test('别的任务的例外不会串到这条上', () {
      // 例外是一次取全部再按 taskId 索引的（避免 N+1）——
      // 索引错了的话，一条任务的完成状态会显示到另一条上。
      final rows = _expand(
        [daily(), _task('别的', date: _today)],
        overrides: [
          OccurrenceOverride(
            taskId: '别的',
            key: keyOn(_today),
            action: OverrideAction.modify,
            status: OccurrenceStatus.done,
          ),
        ],
      );
      expect(
        rows.firstWhere((r) => r.taskId == '晨会' && r.planDate == _today).status,
        TaskStatus.pending,
      );
    });
  });

  group('对照组', () {
    test('没有任何任务时是空表，不是抛', () {
      expect(_expand(const []), isEmpty);
    });

    test('重复任务展开出的行数确实多于一行', () {
      // 少了这条，一个「重复任务也只产一行」的实现能让上面
      // 好几条（id 唯一、窗口内）都绿。
      final one = _expand([_task('a', date: _today)]);
      final many = _expand([
        _task('b', date: _today, rrule: 'RRULE:FREQ=DAILY', isAllDay: true),
      ]);
      expect(one, hasLength(1));
      expect(many.length, greaterThan(1));
    });
  });
}

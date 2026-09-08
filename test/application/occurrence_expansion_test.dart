/// 把任务展开成列表的行（view-specs §0.2、FR-TASK-05）。
///
/// ## 规则：逾期的全留，未来只留「下一次」
///
/// 一度是「窗口内每次一行」—— 一条「每天」在列表里六十行，逾期组还会堆。
/// 那不是一份计划，是一份日历的转录。现在：
///
/// | 那一次 | 显示吗 |
/// |---|---|
/// | 没做完，日期在今天之前 | 留着（逾期）—— 漏交一次房租不该无声消失 |
/// | 没做完，今天或以后 | 只留最早的一条 |
/// | 已完成，今天或以后 | 留着，给撤销留时间（§8.1） |
/// | 已完成，且已是过去 | 不留，除非筛「已完成」 |
/// | 已跳过 | 不留，除非筛「已跳过」 |
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

/// 一条从 [startDaysAgo] 天前开始的每日任务。
///
/// **默认从过去开始**：从今天开始的话「下一次」正好是第一次，
/// 而「第一次」在好几条规则里是特例，用它当夹具会把特例当成常态。
Task _daily({int startDaysAgo = 0}) => _task(
  '晨会',
  date: _today.addDays(-startDaysAgo),
  rrule: 'RRULE:FREQ=DAILY',
  isAllDay: true,
);

List<TaskOccurrence> _expand(
  List<Task> tasks, {
  List<OccurrenceOverride> overrides = const [],
  bool includeSkipped = false,
  bool includeCompleted = false,
}) => expandForList(
  tasks: tasks,
  overrides: overrides,
  today: _today,
  engine: _engine,
  includeSkipped: includeSkipped,
  includeCompleted: includeCompleted,
);

OccurrenceOverride _override(
  PlanDate date, {
  OccurrenceStatus? status,
  String? title,
}) => OccurrenceOverride(
  taskId: '晨会',
  key: OccurrenceKey.allDay(date),
  action: OverrideAction.modify,
  status: status,
  titleOverride: title,
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

  group('重复任务：未来只留「下一次」', () {
    test('从今天开始的每日任务只有一行', () {
      // 全展开的话这里是六十一行。
      final rows = _expand([_daily()]);
      expect(rows, hasLength(1));
      expect(rows.single.planDate, _today);
    });

    test('「下一次」是**最早的没做完的那一次**', () {
      // 今天的做完了 → 明天那次当场出现（今天那条划掉的还留着，见下）。
      final rows = _expand(
        [_daily()],
        overrides: [_override(_today, status: OccurrenceStatus.done)],
      );
      expect(rows.map((r) => r.planDate), [_today, _today.addDays(1)]);
      expect(rows.first.status, TaskStatus.done);
      expect(rows.last.status, TaskStatus.pending);
    });

    test('刚勾掉的那一次不立刻消失（§8.1：给撤销留时间）', () {
      // 「完成即消失」在误触时最伤：那条任务去哪了、怎么找回来，
      // 用户完全没有线索。
      final rows = _expand(
        [_daily()],
        overrides: [_override(_today, status: OccurrenceStatus.done)],
      );
      expect(rows.any((r) => r.planDate == _today), isTrue);
    });
  });

  group('重复任务：逾期的全留', () {
    test('三天前开始、一次没做 → 逾期三条 + 下一次一条', () {
      // 漏掉的不能无声消失：漏交一次房租得看得见。
      final rows = _expand([_daily(startDaysAgo: 3)]);
      expect(rows.map((r) => r.planDate), [
        _today.addDays(-3),
        _today.addDays(-2),
        _today.addDays(-1),
        _today,
      ]);
    });

    test('逾期那些里做完过的不留（否则天天堆划掉的行）', () {
      final rows = _expand(
        [_daily(startDaysAgo: 2)],
        overrides: [
          _override(_today.addDays(-2), status: OccurrenceStatus.done),
        ],
      );
      expect(rows.map((r) => r.planDate), [_today.addDays(-1), _today]);
    });

    test('筛「已完成」时，过去做完的那些回来', () {
      // **这是它们唯一的入口。** 没有的话，做完的那些次就再也找不回来 ——
      // 与「到某天为止」那条死路是同一种毛病。
      final rows = _expand(
        [_daily(startDaysAgo: 2)],
        overrides: [
          _override(_today.addDays(-2), status: OccurrenceStatus.done),
        ],
        includeCompleted: true,
      );
      expect(rows.map((r) => r.planDate), [
        _today.addDays(-2),
        _today.addDays(-1),
        _today,
      ]);
    });

    test('逾期不会翻过窗口下界', () {
      // 搁置三个月的每日任务若全留，逾期组会堆出九十行 ——
      // 那不是提醒，是噪声。
      final rows = _expand([_daily(startDaysAgo: 90)]);
      expect(
        rows.first.planDate,
        _today.addDays(-ListHorizon.pastDays),
        reason: '最早只回溯到 ListHorizon.pastDays',
      );
    });
  });

  group('稀疏规则：「下一次」要能翻出常规窗口', () {
    test('每年一次，下一次在八个月后 —— 不能整条消失', () {
      // 只看 60 天窗口的话，这条任务一行都没有，用户会以为它丢了。
      final rows = _expand([
        _task(
          '年检',
          date: const PlanDate(2026, 5, 20),
          rrule: 'RRULE:FREQ=YEARLY',
          isAllDay: true,
        ),
      ]);
      expect(rows, hasLength(1));
      expect(rows.single.planDate, const PlanDate(2027, 5, 20));
    });

    test('对照组：常规窗口里有的话就不走兜底', () {
      // 少了这条，一个「永远走兜底窗口」的实现也能让上面绿，
      // 而那会把每条每日任务都展开两年。
      final rows = _expand([_daily()]);
      expect(rows, hasLength(1));
      expect(rows.single.planDate, _today);
    });

    test('规则已经到期（UNTIL 在过去）→ 没有下一次，也不报错', () {
      final rows = _expand([
        _task(
          '已结束',
          date: _today.addDays(-30),
          rrule: 'RRULE:FREQ=DAILY;UNTIL=20260901T235959Z',
          isAllDay: true,
        ),
      ]);
      // 只剩窗口内那几次逾期的，没有「下一次」。
      expect(rows.every((r) => r.planDate!.isBefore(_today)), isTrue);
    });
  });

  group('例外作用在对应的那一次上（FR-TASK-05）', () {
    test('标记完成只影响那一次', () {
      final rows = _expand(
        [_daily()],
        overrides: [_override(_today, status: OccurrenceStatus.done)],
      );
      expect(
        rows.firstWhere((r) => r.planDate == _today).status,
        TaskStatus.done,
      );
      expect(
        rows.firstWhere((r) => r.planDate == _today.addDays(1)).status,
        TaskStatus.pending,
        reason: '只该影响被标记的那一次 —— 影响全部的话，勾一次等于把整条规则做完了',
      );
    });

    test('跳过某一次 → 那一行不出现，下一次顶上来', () {
      final rows = _expand(
        [_daily()],
        overrides: [
          OccurrenceOverride.skip(
            taskId: '晨会',
            key: OccurrenceKey.allDay(_today),
          ),
        ],
      );
      expect(rows, hasLength(1));
      expect(rows.single.planDate, _today.addDays(1));
    });

    test('筛「已跳过」时那一次现身', () {
      final rows = _expand(
        [_daily()],
        overrides: [
          OccurrenceOverride.skip(
            taskId: '晨会',
            key: OccurrenceKey.allDay(_today),
          ),
        ],
        includeSkipped: true,
      );
      expect(rows.any((r) => r.planDate == _today), isTrue);
      expect(
        rows.firstWhere((r) => r.planDate == _today).status,
        TaskStatus.skipped,
      );
    });

    test('改某一次的标题，只有那一行变', () {
      final rows = _expand(
        [_daily()],
        overrides: [
          _override(_today, title: '今天改成站会'),
          // 让明天那次也露出来，好做对照。
          _override(_today, status: null, title: '今天改成站会'),
        ],
      );
      expect(rows.single.title, '今天改成站会');

      // 做完今天的，明天那条应当还是原标题。
      final more = _expand(
        [_daily()],
        overrides: [
          _override(_today, status: OccurrenceStatus.done, title: '今天改成站会'),
        ],
      );
      expect(
        more.firstWhere((r) => r.planDate == _today.addDays(1)).title,
        '晨会',
      );
    });

    test('别的任务的例外不会串到这条上', () {
      // 例外是一次取全部再按 taskId 索引的（避免 N+1）——
      // 索引错了的话，一条任务的完成状态会显示到另一条上。
      final rows = _expand(
        [_daily(), _task('别的', date: _today)],
        overrides: [
          OccurrenceOverride(
            taskId: '别的',
            key: OccurrenceKey.allDay(_today),
            action: OverrideAction.modify,
            status: OccurrenceStatus.done,
          ),
        ],
      );
      expect(
        rows.firstWhere((r) => r.taskId == '晨会').status,
        TaskStatus.pending,
      );
    });
  });

  group('对照组', () {
    test('没有任何任务时是空表，不是抛', () {
      expect(_expand(const []), isEmpty);
    });

    test('每一行仍然有自己的 id', () {
      // 拿 taskId 当行标识的话，逾期那几行会共用一个 key ——
      // Flutter 的列表复用会认错行，勾一行动的是另一行。
      final rows = _expand([_daily(startDaysAgo: 3)]);
      expect(rows.map((r) => r.id).toSet(), hasLength(rows.length));
      expect(rows.first.id, startsWith('晨会#'));
    });
  });
}

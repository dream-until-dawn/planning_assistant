/// 实体与值对象的相等性、排序与派生属性。
///
/// 这些看着像样板，但**每一条都有具体后果**：
///  · `==` / `hashCode` 写错 → 集合去重失效、`Set` 里出现重复的同一次发生；
///  · `compareTo` 写错 → 视图里的条目顺序在刷新之间跳来跳去；
///  · `copyWith` 漏字段 → 改一处丢一处，且只在特定路径上显形。
///
/// 覆盖率门禁把这些行摆出来之前，它们确实一条测试都没有 ——
/// 门禁的价值不在数字本身，在于逼着人看一眼「哪些代码没人验过」。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/local_wall_time.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/domain/entities/occurrence.dart';
import 'package:planning_assistant/domain/entities/occurrence_override.dart';
import 'package:planning_assistant/domain/entities/stage.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/value_objects/occurrence_key.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';

LocalWallTime wall(int h, int m, {int day = 8}) => LocalWallTime(
  date: PlanDate(2026, 3, day),
  minuteOfDay: MinuteOfDay.of(h, m),
  timeZoneId: 'Asia/Shanghai',
);

Occurrence occ({
  String taskId = 't1',
  OccurrenceKey? key,
  LocalWallTime? start,
  LocalWallTime? end,
  bool isAllDay = false,
  OccurrenceStatus status = OccurrenceStatus.pending,
  String? titleOverride,
  bool isModified = false,
}) {
  final s = start ?? wall(9, 0);
  return Occurrence(
    taskId: taskId,
    key: key ?? OccurrenceKey.fromWallTime(s, isAllDay: isAllDay),
    start: s,
    end: end,
    isAllDay: isAllDay,
    status: status,
    titleOverride: titleOverride,
    isModified: isModified,
  );
}

void main() {
  group('Occurrence 的相等性', () {
    test('同一次发生的两个实例相等且哈希一致', () {
      // 不相等的话，`Set<Occurrence>` 去重失效 ——
      // 同一次发生会在视图里出现两遍。
      expect(occ(), occ());
      expect(occ().hashCode, occ().hashCode);
      expect({occ(), occ()}.length, 1);
    });

    test('每个字段的差异都会让两者不等', () {
      // 逐字段验，不抽查：漏掉的那个字段就是将来去重出问题的那个。
      final base = occ();
      final variants = <String, Occurrence>{
        'taskId': occ(taskId: 't2'),
        'start': occ(start: wall(10, 0)),
        'end': occ(end: wall(11, 0)),
        'status': occ(status: OccurrenceStatus.done),
        'titleOverride': occ(titleOverride: '改过的'),
        'isModified': occ(isModified: true),
      };
      variants.forEach((field, variant) {
        expect(variant, isNot(base), reason: '$field 不同却判为相等');
      });
    });

    test('与非 Occurrence 对象不等', () {
      expect(occ() == Object(), isFalse);
    });

    test('copyWith 只改指定字段', () {
      final base = occ();
      final changed = base.copyWith(status: OccurrenceStatus.done);
      expect(changed.status, OccurrenceStatus.done);
      expect(changed.taskId, base.taskId);
      expect(changed.key, base.key);
      expect(changed.start, base.start);
      expect(base.status, OccurrenceStatus.pending, reason: '原对象不可变');
    });

    test('copyWith 不传任何参数时等于原值', () {
      expect(occ().copyWith(), occ());
    });

    test('toString 带上关键信息，便于失败时定位', () {
      // 断言失败时打印的就是它 —— 只有 Instance of 'Occurrence' 的话，
      // 排查得多花十分钟。
      final s = occ(status: OccurrenceStatus.done).toString();
      expect(s, contains('t1'));
      expect(s, contains('done'));
    });
  });

  group('OccurrenceKey', () {
    test('全天与定时的形态不同（data-model §4.6）', () {
      const date = PlanDate(2026, 3, 8);
      expect(OccurrenceKey.allDay(date).value, '2026-03-08');
      expect(
        OccurrenceKey.timed(date, MinuteOfDay.of(9, 30)).value,
        '2026-03-08T09:30',
      );
    });

    test('parse 与 value 严格互逆', () {
      for (final raw in [
        '2026-03-08',
        '2026-03-08T00:00',
        '2026-12-31T23:59',
      ]) {
        expect(OccurrenceKey.parse(raw).value, raw, reason: raw);
      }
    });

    test('全天的 key 是纯日期，不带 T00:00', () {
      // 两者若都表示全天，同一次发生会产生两个不同的 key，
      // override 就再也匹配不上了。
      final allDay = OccurrenceKey.allDay(const PlanDate(2026, 3, 8));
      final midnight = OccurrenceKey.timed(
        const PlanDate(2026, 3, 8),
        MinuteOfDay.midnight,
      );
      expect(allDay.isAllDay, isTrue);
      expect(midnight.isAllDay, isFalse);
      expect(allDay, isNot(midnight));
    });

    test('时间部分格式不对时抛 FormatException', () {
      for (final bad in [
        '2026-03-08T9:30',
        '2026-03-08T09:30:00',
        '2026-03-08T',
      ]) {
        expect(
          () => OccurrenceKey.parse(bad),
          throwsA(isA<FormatException>()),
          reason: bad,
        );
      }
    });

    test('排序：先按日期，同日全天排在定时之前', () {
      // 全天用 -1 参与比较，所以它在同一天的所有定时项之前。
      final keys = [
        OccurrenceKey.timed(const PlanDate(2026, 3, 8), MinuteOfDay.of(23, 0)),
        OccurrenceKey.allDay(const PlanDate(2026, 3, 9)),
        OccurrenceKey.timed(const PlanDate(2026, 3, 8), MinuteOfDay.of(9, 0)),
        OccurrenceKey.allDay(const PlanDate(2026, 3, 8)),
      ]..sort();

      expect(keys.map((k) => k.value), [
        '2026-03-08',
        '2026-03-08T09:00',
        '2026-03-08T23:00',
        '2026-03-09',
      ]);
    });

    test('相等性基于 value，可用作 Map 的键', () {
      // 引擎用 `Map<OccurrenceKey, ...>` 索引 override，
      // 相等性写错的话 override 会全部失配。
      final a = OccurrenceKey.parse('2026-03-08T09:00');
      final b = OccurrenceKey.timed(
        const PlanDate(2026, 3, 8),
        MinuteOfDay.of(9, 0),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect({a: 1}[b], 1);
      expect(a == Object(), isFalse);
      expect(a.toString(), '2026-03-08T09:00');
    });
  });

  group('Task 的派生属性与不变量分支', () {
    Task task({
      PlanDate? planDate,
      MinuteOfDay? startMinute,
      bool isAllDay = false,
    }) => Task(
      id: 't1',
      title: '任务',
      kind: TaskKind.single,
      timeZoneId: 'Asia/Shanghai',
      planDate: planDate,
      startMinute: startMinute,
      isAllDay: isAllDay,
    );

    test('无日期时 startWallTime 为 null', () {
      expect(task().startWallTime, isNull);
    });

    test('有日期无时刻时按当日零点', () {
      final w = task(planDate: const PlanDate(2026, 3, 8)).startWallTime!;
      expect(w.date, const PlanDate(2026, 3, 8));
      expect(w.minuteOfDay, MinuteOfDay.midnight);
      expect(w.timeZoneId, 'Asia/Shanghai');
    });

    test('有日期有时刻时按给定时刻', () {
      final w = task(
        planDate: const PlanDate(2026, 3, 8),
        startMinute: MinuteOfDay.of(9, 30),
      ).startWallTime!;
      expect(w.minuteOfDay, MinuteOfDay.of(9, 30));
    });

    test('全天任务带 startMinute 会被不变量拦下', () {
      // 两者同时存在时，UI 该显示「全天」还是「09:30」没有答案。
      final bad = task(
        planDate: const PlanDate(2026, 3, 8),
        startMinute: MinuteOfDay.of(9, 30),
        isAllDay: true,
      );
      expect(bad.checkInvariants, throwsA(isA<DomainInvariantViolation>()));
    });

    test('toString 标出重复/归档/删除，便于失败时定位', () {
      final base = task();
      expect(base.toString(), contains('t1'));
      expect(base.toString(), isNot(contains('archived')));

      final archived = base.copyWith(
        archivedAt: DateTime.utc(2026),
        statusBeforeArchive: TaskStatus.pending,
      );
      expect(archived.toString(), contains('archived'));

      expect(
        base.copyWith(deletedAt: DateTime.utc(2026)).toString(),
        contains('deleted'),
      );
    });
  });

  group('Stage 的派生属性', () {
    Stage stage({int? start, int? duration}) => Stage(
      id: 's1',
      taskId: 't1',
      title: '阶段',
      orderIndex: 0,
      startOffsetMinutes: start,
      durationMinutes: duration,
    );

    test('无起始偏移时结束偏移也是 null', () {
      expect(stage().endOffsetMinutes, isNull);
      expect(stage(duration: 60).endOffsetMinutes, isNull);
    });

    test('有起始无时长时视为零长（与起始重合）', () {
      // 不是 null 也不是「到任务结束」—— 甘特图要画出一个点而不是一段。
      expect(stage(start: 120).endOffsetMinutes, 120);
    });

    test('起始 + 时长', () {
      expect(stage(start: 120, duration: 45).endOffsetMinutes, 165);
    });

    test('copyWith 的哨兵：不传不改，传 null 清空', () {
      final s = stage(start: 120, duration: 45);
      expect(s.copyWith(title: '新').durationMinutes, 45);
      expect(s.copyWith(durationMinutes: null).durationMinutes, isNull);
      expect(
        s.copyWith(durationMinutes: null).startOffsetMinutes,
        120,
        reason: '清一个不该影响另一个',
      );
    });

    test('toString 带序号与状态', () {
      final s = stage().copyWith(
        status: TaskStatus.done,
        completedAt: DateTime.utc(2026),
      );
      expect(s.toString(), contains('#0'));
      expect(s.toString(), contains('done'));
    });
  });

  group('异常类型的可读性', () {
    test('IllegalTransitionException 说清从哪到哪', () {
      // 异常信息只有进了日志/崩溃报告才有用，格式塌了等于没记。
      const e = IllegalTransitionException(TaskStatus.done, TaskStatus.skipped);
      expect(e.toString(), contains('done'));
      expect(e.toString(), contains('skipped'));

      const withReason = IllegalTransitionException(
        TaskStatus.done,
        TaskStatus.skipped,
        '任务已归档',
      );
      expect(withReason.toString(), contains('任务已归档'));
    });

    test('DomainInvariantViolation 带上原始信息', () {
      const e = DomainInvariantViolation('重复任务必须保持 pending');
      expect(e.toString(), contains('重复任务必须保持 pending'));
    });

    test('TaskStatus 的存储串往返，未知值抛异常', () {
      for (final s in TaskStatus.values) {
        expect(TaskStatus.fromWireName(s.wireName), s);
      }
      // 静默回落会把「数据坏了」变成「任务莫名变回待办」。
      expect(
        () => TaskStatus.fromWireName('exploded'),
        throwsA(isA<FormatException>()),
      );
    });

    test('TaskKind / TaskPriority 同样往返且拒绝未知值', () {
      for (final k in TaskKind.values) {
        expect(TaskKind.fromWireName(k.wireName), k);
      }
      for (final p in TaskPriority.values) {
        expect(TaskPriority.fromValue(p.value), p);
      }
      expect(() => TaskKind.fromWireName('x'), throwsA(isA<FormatException>()));
      expect(() => TaskPriority.fromValue(99), throwsA(isA<FormatException>()));
    });
  });

  group('OccurrenceOverride', () {
    test('toString 带上 key 与动作，便于定位是哪一次', () {
      final o = OccurrenceOverride(
        taskId: 't1',
        key: OccurrenceKey.parse('2026-03-08T09:00'),
        action: OverrideAction.skip,
      );
      expect(o.toString(), contains('2026-03-08T09:00'));
      expect(o.toString(), contains('skip'));
    });
  });
}

/// 全天 ⇄ 定时的 key 迁移（R-27、data-model §4.6）。
///
/// ## 为什么这件事有专门一条命令
///
/// §4.6 特意**没让全天补成 `T00:00`**：用纯日期表达「这一天」语义上更
/// 诚实。代价落在切换上 —— 已有例外的 key 必须跟着迁移，
/// 否则它们全部失联：行还在库里，界面上再也挂不上任何一次发生，
/// **而且不报任何错**。
///
/// 这里验的是那条纯函数：算出新任务 + 每一行的新旧 key。
/// 落盘的原子性在 `test/data/convert_all_day_test.dart`。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/domain/entities/occurrence_override.dart';
import 'package:planning_assistant/domain/entities/stage_occurrence_state.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/services/all_day_conversion.dart';
import 'package:planning_assistant/domain/value_objects/occurrence_key.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';

Task _task({required bool isAllDay, MinuteOfDay? startMinute}) => Task(
  id: 't1',
  title: '晨会',
  kind: TaskKind.single,
  timeZoneId: 'Asia/Shanghai',
  planDate: const PlanDate(2026, 9, 8),
  startMinute: startMinute,
  isAllDay: isAllDay,
);

OccurrenceOverride _skip(OccurrenceKey key) =>
    OccurrenceOverride.skip(taskId: 't1', key: key);

StageOccurrenceState _state(String stageId, OccurrenceKey key) =>
    StageOccurrenceState(
      id: StageOccurrenceState.idFor(stageId, key),
      taskId: 't1',
      stageId: stageId,
      occurrenceKey: key,
      status: TaskStatus.done,
    );

void main() {
  group('R-27 全天 → 定时：key 从 yyyy-MM-dd 变成 yyyy-MM-ddTHH:mm', () {
    test('例外跟着迁移，不失联', () {
      final r = convertAllDayMode(
        _task(isAllDay: true),
        toAllDay: false,
        startMinute: MinuteOfDay.of(9, 0),
        overrides: [
          _skip(OccurrenceKey.allDay(const PlanDate(2026, 9, 8))),
          _skip(OccurrenceKey.allDay(const PlanDate(2026, 9, 15))),
        ],
        stageStates: const [],
      );

      expect(r.task.isAllDay, isFalse);
      expect(r.task.startMinute, MinuteOfDay.of(9, 0));
      expect(
        [for (final m in r.movedOverrides) (m.from.value, m.to.key.value)],
        [
          ('2026-09-08', '2026-09-08T09:00'),
          ('2026-09-15', '2026-09-15T09:00'),
        ],
      );
    });

    test('例外的内容原样带过去 —— 迁的是 key，不是重建一条空的', () {
      final r = convertAllDayMode(
        _task(isAllDay: true),
        toAllDay: false,
        startMinute: MinuteOfDay.of(9, 0),
        overrides: [
          OccurrenceOverride(
            taskId: 't1',
            key: OccurrenceKey.allDay(const PlanDate(2026, 9, 8)),
            action: OverrideAction.modify,
            titleOverride: '临时改的标题',
          ),
        ],
        stageStates: const [],
      );

      expect(r.movedOverrides.single.to.titleOverride, '临时改的标题');
      expect(r.movedOverrides.single.to.action, OverrideAction.modify);
    });

    test('阶段状态也一起迁，而且行 id 跟着重算', () {
      // id 是 `stageId#occurrenceKey` 派生的 —— 不重算的话，
      // 新行会顶着旧 id，与它自己的 key 对不上。
      final r = convertAllDayMode(
        _task(isAllDay: true),
        toAllDay: false,
        startMinute: MinuteOfDay.of(9, 0),
        overrides: const [],
        stageStates: [
          _state('s1', OccurrenceKey.allDay(const PlanDate(2026, 9, 8))),
        ],
      );

      final moved = r.movedStageStates.single;
      expect(moved.from.value, '2026-09-08');
      expect(moved.to.occurrenceKey.value, '2026-09-08T09:00');
      expect(moved.to.id, 's1#2026-09-08T09:00');
      expect(moved.to.status, TaskStatus.done, reason: '状态被迁丢了');
    });
  });

  group('R-27 定时 → 全天', () {
    test('时刻部分被去掉，任务的 startMinute 一并清空', () {
      final r = convertAllDayMode(
        _task(isAllDay: false, startMinute: MinuteOfDay.of(9, 0)),
        toAllDay: true,
        startMinute: null,
        overrides: [
          _skip(
            OccurrenceKey.timed(
              const PlanDate(2026, 9, 8),
              MinuteOfDay.of(9, 0),
            ),
          ),
        ],
        stageStates: const [],
      );

      expect(r.task.isAllDay, isTrue);
      expect(r.task.startMinute, isNull);
      expect(r.task.planDate, const PlanDate(2026, 9, 8), reason: '日期不该被一起清掉');
      expect(r.movedOverrides.single.to.key.value, '2026-09-08');
    });

    test('**同一天两条例外会撞车 —— 抛异常，不悄悄丢一条**', () {
      // 9:00 与 14:00 两次都会压成 `2026-09-08`。
      // 丢一条的话，用户跳过的那一次会复活、或者改过的标题不见了 ——
      // 而他只是拨了一个开关。
      expect(
        () => convertAllDayMode(
          _task(isAllDay: false, startMinute: MinuteOfDay.of(9, 0)),
          toAllDay: true,
          startMinute: null,
          overrides: [
            _skip(
              OccurrenceKey.timed(
                const PlanDate(2026, 9, 8),
                MinuteOfDay.of(9, 0),
              ),
            ),
            _skip(
              OccurrenceKey.timed(
                const PlanDate(2026, 9, 8),
                MinuteOfDay.of(14, 0),
              ),
            ),
          ],
          stageStates: const [],
        ),
        throwsA(isA<DomainInvariantViolation>()),
      );
    });

    test('不同天的两条不算撞车', () {
      // 对照组：少了它，一个「一律抛异常」的实现能让上面那条绿。
      final r = convertAllDayMode(
        _task(isAllDay: false, startMinute: MinuteOfDay.of(9, 0)),
        toAllDay: true,
        startMinute: null,
        overrides: [
          _skip(
            OccurrenceKey.timed(
              const PlanDate(2026, 9, 8),
              MinuteOfDay.of(9, 0),
            ),
          ),
          _skip(
            OccurrenceKey.timed(
              const PlanDate(2026, 9, 9),
              MinuteOfDay.of(14, 0),
            ),
          ),
        ],
        stageStates: const [],
      );
      expect(r.movedOverrides, hasLength(2));
    });

    test('撞车只在同一个阶段内部算', () {
      // 两个阶段各有一条 9/8 的状态，迁完 key 相同但 **stageId 不同**，
      // 行 id 是 `stageId#key`，本来就不冲突。
      // 一把梭检查全表的话，这个正常情形会被误判成撞车。
      final r = convertAllDayMode(
        _task(isAllDay: false, startMinute: MinuteOfDay.of(9, 0)),
        toAllDay: true,
        startMinute: null,
        overrides: const [],
        stageStates: [
          _state(
            's1',
            OccurrenceKey.timed(
              const PlanDate(2026, 9, 8),
              MinuteOfDay.of(9, 0),
            ),
          ),
          _state(
            's2',
            OccurrenceKey.timed(
              const PlanDate(2026, 9, 8),
              MinuteOfDay.of(9, 0),
            ),
          ),
        ],
      );
      expect(r.movedStageStates, hasLength(2));
    });
  });

  group('入参自相矛盾时直接拒绝', () {
    test('转全天却带了时刻', () {
      expect(
        () => convertAllDayMode(
          _task(isAllDay: false, startMinute: MinuteOfDay.of(9, 0)),
          toAllDay: true,
          startMinute: MinuteOfDay.of(9, 0),
          overrides: const [],
          stageStates: const [],
        ),
        throwsA(isA<DomainInvariantViolation>()),
      );
    });

    test('转定时却没给时刻', () {
      expect(
        () => convertAllDayMode(
          _task(isAllDay: true),
          toAllDay: false,
          startMinute: null,
          overrides: const [],
          stageStates: const [],
        ),
        throwsA(isA<DomainInvariantViolation>()),
      );
    });
  });
}

/// 每个发生实例独立的阶段完成状态（FR-TASK-07、recurrence-engine R-50/R-51）。
///
/// ## 这条链路此前断在数据层
///
/// 表 `stage_occurrence_states` 与它的 DAO 从 M1 就在，导出也带着它 ——
/// 而**领域层以上一片空白**：没有实体、没有仓库方法、没有命令、没有界面。
/// 阶段状态只有 `Stage.status` 一份，于是一条「每周三·健身」
/// 拆成热身/主训/拉伸，这周勾掉热身，**每一周的热身都成了已完成**。
///
/// M1 的遗留清单里记着它，到期写的是「M3 阶段编辑」。
/// 这份清单没人对着跑，所以它就一直躺在那儿 ——
/// 直到需求可追溯性门禁（`tool/check_traceability.py`）把
/// 「FR-TASK-07 没有任何测试点名」摆出来。
///
/// ## 判据只有一处
///
/// 「这一次的这一步做完没有」由 `stageStatusFor` 一个函数回答。
/// 视图、进度、甘特各写一遍 `if (task.isRecurring)` 的话，
/// 迟早出现「列表说做完了、甘特说没有」。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/domain/entities/stage.dart';
import 'package:planning_assistant/domain/entities/stage_occurrence_state.dart';
import 'package:planning_assistant/domain/services/stage_occurrence_status.dart';
import 'package:planning_assistant/domain/value_objects/occurrence_key.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';

/// 三个阶段：热身 / 主训 / 拉伸。
final _stages = [
  const Stage(id: 's1', taskId: 't1', title: '热身', orderIndex: 0),
  const Stage(id: 's2', taskId: 't1', title: '主训', orderIndex: 1),
  const Stage(id: 's3', taskId: 't1', title: '拉伸', orderIndex: 2),
];

OccurrenceKey _week(int day) =>
    OccurrenceKey.timed(PlanDate(2026, 9, day), MinuteOfDay.of(19, 0));

StageOccurrenceState _done(String stageId, OccurrenceKey key) =>
    StageOccurrenceState(
      id: StageOccurrenceState.idFor(stageId, key),
      taskId: 't1',
      stageId: stageId,
      occurrenceKey: key,
      status: TaskStatus.done,
      completedAt: DateTime.utc(2026, 9, 9),
    );

void main() {
  group('R-50 / R-51 一次的完成不影响另一次', () {
    // 本周三 9/9，下周三 9/16。
    final thisWeek = _week(9);
    final nextWeek = _week(16);
    final byOccurrence = groupByOccurrence([_done('s2', thisWeek)]);

    test('R-50 完成本周第 2 阶段 → 只有本周第 2 阶段变完成', () {
      final states = byOccurrence[thisWeek];
      expect(
        [for (final s in _stages) stageStatusFor(s, occurrenceStates: states)],
        [TaskStatus.pending, TaskStatus.done, TaskStatus.pending],
      );
    });

    test('R-51 下周同一阶段仍为 pending', () {
      // 这一条是整件事的要害。回落到 `Stage.status` 的实现在这里会红 ——
      // 而那正是修之前的行为。
      final states = byOccurrence[nextWeek];
      expect([
        for (final s in _stages) stageStatusFor(s, occurrenceStates: states),
      ], everyElement(TaskStatus.pending));
    });

    test('**阶段自己是 done，也不该让某一次显示成 done**', () {
      // 重复任务的阶段状态若在编辑器里被标过完成（旧数据、或将来
      // 某条路径漏改），回落到 `stage.status` 会让**每一次**都变完成。
      // 所以回落的是 pending，不是阶段自己。
      final dirty = [
        _stages[0].copyWith(status: TaskStatus.done),
        ..._stages.skip(1),
      ];
      expect(
        stageStatusFor(dirty.first, occurrenceStates: const {}),
        TaskStatus.pending,
        reason: '重复任务里，阶段自己的状态不该参与判断',
      );
    });
  });

  group('不重复的任务看阶段自己', () {
    test('传 null 就是「这条任务没有某一次」', () {
      // 单项任务只有一次发生，为它另开一张表是多余的间接层。
      final done = _stages[0].copyWith(status: TaskStatus.done);
      expect(stageStatusFor(done, occurrenceStates: null), TaskStatus.done);
      expect(
        stageStatusFor(_stages[1], occurrenceStates: null),
        TaskStatus.pending,
      );
    });
  });

  group('进度', () {
    test('按这一次算，不按整条任务算', () {
      final key = _week(9);
      final states = groupByOccurrence([
        _done('s1', key),
        _done('s2', key),
      ])[key];

      expect(stageProgressFor(_stages, occurrenceStates: states), (
        done: 2,
        total: 3,
      ));
      expect(stageProgressFor(_stages, occurrenceStates: const {}), (
        done: 0,
        total: 3,
      ), reason: '另一次还一步没做');
    });

    test('没有阶段返回 null —— 与「一个都没做」不是一回事', () {
      // view-specs §4.3.1：前者压根不画，后者画一条空的进度。
      expect(stageProgressFor(const [], occurrenceStates: null), isNull);
      expect(stageProgressFor(_stages, occurrenceStates: const {}), isNotNull);
    });
  });

  group('分桶与身份', () {
    test('行 id 由 (阶段, 那一次) 派生 —— 同一次只会有一行', () {
      // 随机 id 的话，连点两下会攒出两行互相矛盾的状态，
      // 而读的时候谁在前谁说了算。
      final key = _week(9);
      expect(
        StageOccurrenceState.idFor('s1', key),
        StageOccurrenceState.idFor('s1', key),
      );
      expect(
        StageOccurrenceState.idFor('s1', key),
        isNot(StageOccurrenceState.idFor('s1', _week(16))),
      );
      expect(
        StageOccurrenceState.idFor('s1', key),
        isNot(StageOccurrenceState.idFor('s2', key)),
      );
    });

    test('墓碑不参与分桶', () {
      // 软删除的状态行还在库里（同步要用），但它不该再影响显示。
      final key = _week(9);
      final tombstone = StageOccurrenceState(
        id: StageOccurrenceState.idFor('s1', key),
        taskId: 't1',
        stageId: 's1',
        occurrenceKey: key,
        status: TaskStatus.done,
        deletedAt: DateTime.utc(2026, 9, 10),
      );
      expect(groupByOccurrence([tombstone]), isEmpty);
    });
  });
}

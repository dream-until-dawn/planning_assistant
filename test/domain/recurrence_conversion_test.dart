/// 单项 ⇄ 重复切换时，阶段进度不会从界面上消失（FR-TASK-07）。
///
/// ## 起因是评审提的一条
///
/// `Stage.status` 对重复任务是**死数据** —— 读路径不看它。
/// 我原本给的两个选项是「写它就抛」或「归一化成 pending」，
/// 评审指出两者共享一个错误前提：**把「单项→重复」当成一次普通的
/// 字段更新**。而 R-27 已经示范了另一条路 —— 身份变了就显式迁移。
///
/// 同一个答案：`recurrenceRule` 从 null 变成非 null 的那一刻，
/// 把 `Stage.status` 迁进**第一次发生**的状态里。
/// 用户的完成记录没丢，读路径仍然唯一，而且迁完之后
/// 「重复任务的 `Stage.status` 恒为 pending」这条才真的成立。
///
/// ## 不迁会怎样
///
/// 数据一条都不会丢（行还在库里），但用户看到的是
/// **「我做完的东西没了」** —— 读路径改看另一张空表而已。
/// 这一类「没丢但看不见」比真丢更难查：没有任何报错。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/domain/entities/occurrence.dart';
import 'package:planning_assistant/domain/entities/stage.dart';
import 'package:planning_assistant/domain/entities/stage_occurrence_state.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/services/recurrence_conversion.dart';
import 'package:planning_assistant/domain/value_objects/occurrence_key.dart';
import 'package:planning_assistant/domain/value_objects/recurrence.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';

const _date = PlanDate(2026, 9, 8);
final _at9 = MinuteOfDay.of(9, 0);
final _first = OccurrenceKey.timed(_date, _at9);
final _done = DateTime.utc(2026, 9, 8, 3);

Task _task({required bool recurring}) => Task(
  id: 't1',
  title: '健身',
  kind: TaskKind.staged,
  timeZoneId: 'Asia/Shanghai',
  planDate: _date,
  startMinute: _at9,
  isAllDay: false,
  recurrence: recurring ? Recurrence.parse('RRULE:FREQ=DAILY') : null,
);

final _stages = [
  const Stage(id: 's1', taskId: 't1', title: '热身', orderIndex: 0),
  const Stage(id: 's2', taskId: 't1', title: '主训', orderIndex: 1),
];

void main() {
  group('单项 → 重复：完成记录搬到第一次发生上', () {
    test('搬过去的状态与完成时刻都在', () {
      final r = convertRecurrenceMode(
        _task(recurring: true),
        was: false,
        stages: [
          _stages[0].copyWith(status: TaskStatus.done, completedAt: _done),
          _stages[1],
        ],
        states: const [],
      )!;

      expect(r.states, hasLength(1));
      final moved = r.states.single;
      expect(moved.stageId, 's1');
      expect(moved.occurrenceKey.value, _first.value);
      expect(moved.status, TaskStatus.done);
      expect(moved.completedAt, _done, reason: '完成时刻被丢了');
    });

    test('阶段自己归零 —— 迁完那一列才真的没人读', () {
      final r = convertRecurrenceMode(
        _task(recurring: true),
        was: false,
        stages: [
          _stages[0].copyWith(status: TaskStatus.done, completedAt: _done),
          _stages[1],
        ],
        states: const [],
      )!;

      expect(
        [for (final s in r.stages) s.status],
        [TaskStatus.pending, TaskStatus.pending],
      );
      expect(r.stages.first.completedAt, isNull, reason: '状态归零了，完成时刻还留着');
    });

    test('**没动过的阶段不落行**', () {
      // data-model §3.5：只有被交互过的 (阶段, 发生) 才落行。
      // 给每个阶段都造一行 pending，等于把「还没动过」也写成数据。
      //
      // **必须混一个动过的**：全 pending 时整个迁移是空的，
      // 断言「一行都没有」就永远成立 —— 那时它验的是「没迁移」，
      // 不是「没动过的不落行」。
      final r = convertRecurrenceMode(
        _task(recurring: true),
        was: false,
        stages: [
          _stages[0].copyWith(status: TaskStatus.done, completedAt: _done),
          _stages[1],
        ],
        states: const [],
      )!;
      expect([for (final st in r.states) st.stageId], ['s1']);
    });

    test('**任务自己的状态也搬**：做了一半的任务改得成重复', () {
      // 重复任务的 `tasks.status` 恒为 pending（data-model §4.3）。
      // 不搬的话 `checkInvariants` 当场拦下 —— 一条做了一半的任务
      // 根本改不成重复，而用户看到的只是「保存没反应」。
      final r = convertRecurrenceMode(
        _task(recurring: true).copyWith(status: TaskStatus.inProgress),
        was: false,
        stages: _stages,
        states: const [],
      )!;

      expect(r.task.status, TaskStatus.pending);
      expect(r.overrides, hasLength(1));
      expect(r.overrides.single.key.value, _first.value);
      expect(r.overrides.single.status, OccurrenceStatus.inProgress);
      expect(
        () => r.task.checkInvariants(),
        returnsNormally,
        reason: '搬完之后必须过得了不变量，否则这条任务存不下去',
      );
    });

    test('已完成的任务改成重复：完成落到第一次上', () {
      final r = convertRecurrenceMode(
        _task(recurring: true)
            .copyWith(status: TaskStatus.done, completedAt: _done),
        was: false,
        stages: const [],
        states: const [],
      )!;

      expect(r.task.status, TaskStatus.pending);
      expect(r.task.completedAt, isNull, reason: 'completedAt 与 status 同进同退');
      expect(r.overrides.single.status, OccurrenceStatus.done);
    });
  });

  group('重复 → 单项：**不迁**，而且是想清楚之后不迁', () {
    // 两个理由（见 `recurrence_conversion.dart` 文件头）：
    //  一、语义上没有唯一答案 —— 用户可能在五次发生上各完成了不同的
    //     阶段，挑「第一次」是替他做决定；
    //  二、这个位置也做不成 —— 一次保存里 `ReplaceStagesCommand`
    //     会把 `UpdateTaskFieldsCommand` 写好的阶段状态原样盖掉。
    //
    // 这一条钉住「不迁」是刻意的：没有它的话，
    // 下一个人会以为这里漏了一半，顺手补上一个会被盖掉的实现。
    test('不产生任何迁移', () {
      final states = [
        StageOccurrenceState(
          id: StageOccurrenceState.idFor('s2', _first),
          taskId: 't1',
          stageId: 's2',
          occurrenceKey: _first,
          status: TaskStatus.done,
          completedAt: _done,
        ),
      ];
      expect(
        convertRecurrenceMode(
          _task(recurring: false),
          was: true,
          stages: _stages,
          states: states,
        ),
        isNull,
      );
    });
  });

  group('什么时候不迁', () {
    test('重复规则没变就不迁', () {
      // 每次保存都迁一遍的话，`Stage.status` 会被反复归零。
      expect(
        convertRecurrenceMode(
          _task(recurring: true),
          was: true,
          stages: _stages,
          states: const [],
        ),
        isNull,
      );
      expect(
        convertRecurrenceMode(
          _task(recurring: false),
          was: false,
          stages: _stages,
          states: const [],
        ),
        isNull,
      );
    });

    test('没有阶段、状态也没动过，就没什么可迁', () {
      // 判据是「结果里有没有东西」，不是「有没有阶段」——
      // 上面那条「已完成的任务改成重复」没有阶段，照样要迁。
      expect(
        convertRecurrenceMode(
          _task(recurring: true),
          was: false,
          stages: const [],
          states: const [],
        ),
        isNull,
      );
    });

    test('阶段全没动过、状态也是 pending → 同样不迁', () {
      expect(
        convertRecurrenceMode(
          _task(recurring: true),
          was: false,
          stages: _stages,
          states: const [],
        ),
        isNull,
      );
    });

    test('没有开始时刻时不迁 —— 没有「第一次」可指', () {
      // 界面拦住了（重复必须有日期），但导入与同步走得到这条路。
      const noDate = Task(
        id: 't1',
        title: '健身',
        kind: TaskKind.staged,
        timeZoneId: 'Asia/Shanghai',
      );
      expect(
        convertRecurrenceMode(
          noDate,
          was: false,
          stages: _stages,
          states: const [],
        ),
        isNull,
      );
    });
  });
}

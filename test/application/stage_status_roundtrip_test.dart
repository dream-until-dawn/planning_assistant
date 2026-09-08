/// 阶段的完成状态在编辑器里走一圈之后还在不在。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/domain/entities/stage.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';
import 'package:planning_assistant/features/task/application/task_editor_controller.dart';

void main() {
  test('draftFromTask 带上阶段的完成状态', () {
    const task = Task(
      id: 't',
      title: 't',
      kind: TaskKind.staged,
      timeZoneId: 'Asia/Shanghai',
      planDate: PlanDate(2026, 9, 8),
      isAllDay: true,
    );
    final stages = [
      Stage(
        id: 's1',
        taskId: 't',
        title: '第一步',
        orderIndex: 0,
        status: TaskStatus.done,
        completedAt: DateTime.utc(2026, 9, 8),
      ),
      const Stage(id: 's2', taskId: 't', title: '第二步', orderIndex: 1),
    ];
    final draft = draftFromTask(task, stages);
    expect(draft.stages.map((s) => s.status).toList(), [
      TaskStatus.done,
      TaskStatus.pending,
    ], reason: '草稿把完成状态丢了 —— 存回去时会被清成 pending');
  });
}

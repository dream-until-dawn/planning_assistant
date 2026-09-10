/// **必填项**：每种形态各自缺什么就不能存（用户 2026-09-10）。
///
/// > 加强必填项校验，比如现在单项任务可以不填结束时间，
/// > 还有阶段事项下阶段没选时间也能新建成功等等
///
/// ## 缺陷的形状：两张清单，各说各话
///
/// 那时 `blockedReason` 已经写着「要先选结束日期」，而 `canSave` 是
/// **另一张清单**，压根没问过这一条 —— 于是红字在下面显示着，
/// 保存键同时亮着，按下去就真的存了一条没有结束时间的单事项。
///
/// 两张清单不是「其中一张写漏了」，是**结构上必然会分叉**：
/// 加一条新规则时得记得写两遍，而没有任何东西会在只写了一遍时喊。
///
/// 所以这一份先守那个结构（[canSave] ⟺ [blockedReason] == null），
/// 再按形态逐条守内容。**顺序是有意的**：结构那条在，
/// 内容漏一条只会漏在一处；结构那条不在，内容写得再全也会再分叉一次。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/features/task/application/recurrence_draft.dart';
import 'package:planning_assistant/features/task/application/task_editor_controller.dart';
import 'package:planning_assistant/features/task/application/task_shape.dart';

const _d1 = PlanDate(2026, 9, 7);
const _d2 = PlanDate(2026, 9, 9);
final _m9 = MinuteOfDay.of(9, 0);
final _m18 = MinuteOfDay.of(18, 0);

StageDraft _stage(String id, {int? offset}) =>
    StageDraft(id: id, title: id, startOffsetMinutes: offset);

/// 一条**填全了**的草稿，按形态给。每条用例从它出发，只拿掉一样东西 ——
/// 「拿掉这一个就不能存」比「凭空拼一个不能存的」说得清得多。
TaskDraft _complete(TaskShape shape) => switch (shape) {
  TaskShape.scratch => const TaskDraft(shape: TaskShape.scratch, title: '随手记'),
  TaskShape.staged || TaskShape.recurringStaged => TaskDraft(
    shape: shape,
    title: '搬家',
    planDate: _d1,
    endDate: _d2,
    isAllDay: false,
    startMinute: _m9,
    endMinute: _m18,
    stages: [_stage('a', offset: 0), _stage('b', offset: 60)],
    recurrence: RecurrenceDraft(enabled: shape.isRecurring),
  ),
  TaskShape.single || TaskShape.recurringSingle => TaskDraft(
    shape: shape,
    title: '开会',
    planDate: _d1,
    endDate: _d1,
    recurrence: RecurrenceDraft(enabled: shape.isRecurring),
  ),
};

/// 「拿掉一样」的那些手法。名字就是用例名。
typedef _Removal = (String, TaskDraft Function(TaskDraft));

const Map<TaskShape, List<_Removal>> _mustHave = {
  TaskShape.single: [
    ('开始日期', _dropPlanDate),
    ('结束日期', _dropEndDate),
    ('开始时刻（非全天时）', _dropStartMinute),
    ('结束时刻（非全天时）', _dropEndMinute),
  ],
  TaskShape.recurringSingle: [('开始日期', _dropPlanDate), ('结束日期', _dropEndDate)],
  TaskShape.staged: [
    ('至少两个阶段', _dropOneStage),
    ('每个阶段都要有时间', _dropOneStageTime),
  ],
  TaskShape.recurringStaged: [
    ('至少两个阶段', _dropOneStage),
    ('每个阶段都要有时间', _dropOneStageTime),
  ],
  // 临时事项**故意一条都没有** —— 「仅填标题即可保存」是它的定义
  // （FR-TASK-01 的验收 2026-09-09 落到了这一档上）。
  TaskShape.scratch: [],
};

TaskDraft _dropPlanDate(TaskDraft d) => d.copyWith(planDate: null);
TaskDraft _dropEndDate(TaskDraft d) => d.copyWith(endDate: null);
TaskDraft _dropStartMinute(TaskDraft d) =>
    d.copyWith(isAllDay: false, startMinute: null, endMinute: _m18);
TaskDraft _dropEndMinute(TaskDraft d) =>
    d.copyWith(isAllDay: false, startMinute: _m9, endMinute: null);
TaskDraft _dropOneStage(TaskDraft d) => d.copyWith(stages: [d.stages.first]);
TaskDraft _dropOneStageTime(TaskDraft d) =>
    d.copyWith(stages: [d.stages.first, _stage('b')]);

void main() {
  group('结构：「能不能存」只有一个判据', () {
    /// 一把长得五花八门的草稿。**不求穷举** —— 求的是每一条必填规则
    /// 至少有一条草稿踩在它上面，以及一批正常的草稿踩不到任何一条。
    List<TaskDraft> allDrafts() => [
      const TaskDraft(),
      const TaskDraft(title: '  '),
      for (final shape in TaskShape.values) ...[
        _complete(shape),
        _complete(shape).copyWith(title: ''),
        for (final (_, drop) in _mustHave[shape]!) drop(_complete(shape)),
      ],
      // 跨字段的那几条也要在场，否则「结构一致」只在必填那一半成立。
      _complete(TaskShape.single).copyWith(endDate: const PlanDate(2026, 9, 1)),
      _complete(TaskShape.recurringSingle).copyWith(
        recurrence: const RecurrenceDraft(
          enabled: true,
          endMode: RecurrenceEndMode.until,
          until: PlanDate(2026, 9, 1),
        ),
      ),
    ];

    test('canSave 与 blockedReason 不可能各说各话', () {
      // 这就是那个缺陷本身：`blockedReason` 说不行，`canSave` 说行。
      final blocked = allDrafts()
          .where((d) => d.blockedReason != null)
          .toList();
      expect(blocked, isNotEmpty, reason: '一条被挡的都没有 —— 这把样本本身就不对');
      for (final d in blocked) {
        expect(d.canSave, isFalse, reason: '红字说「${d.blockedReason}」，保存键却是亮的');
      }
    });

    test('反过来也成立：说不出理由就得能存（标题为空除外）', () {
      // 少了这一条，一个「永远返回 false」的 canSave 也能让上面那条绿，
      // 而那时整个表单再也存不下去任何东西。
      //
      // ## 为什么这个方向**在合并之后**才变得要紧（评审 2026-09-10）
      //
      // 合并之前，`blockedReason` 多算一条（过严）只是**文案冤枉了人**，
      // 任务照样存得下去 —— 因为 `canSave` 是另一张清单，不看它。
      // 合并之后，同一个错误变成**死路**：说得出理由 = 存不下去。
      //
      // 一条过严的规则从「文案问题」升级成了「用户存不下一条本该合法的
      // 任务」，而那种错在测试里长得像「用例没写」，不像「代码坏了」。
      // 所以这个方向不是对称性洁癖，是那次合并**新造出来的**风险。
      final savable = allDrafts()
          .where((d) => d.title.trim().isNotEmpty && d.blockedReason == null)
          .toList();
      expect(savable, isNotEmpty, reason: '没有一条草稿是能存的 —— 这把样本本身就不对');
      for (final d in savable) {
        expect(d.canSave, isTrue, reason: '说不出为什么不能存，按钮却灰着');
      }
    });

    test('标题为空时不说理由 —— 按钮本来就灰着', () {
      // 这是唯一一处「不能存却没有理由」，写在这儿免得下一个人
      // 把它当成上面那条的反例去「修」。
      const d = TaskDraft(title: '');
      expect(d.canSave, isFalse);
      expect(d.blockedReason, isNull);
    });
  });

  group('内容：每种形态各自的必填项', () {
    test('前提：这张表把五种形态都写全了', () {
      expect(_mustHave.keys.toSet(), TaskShape.values.toSet());
    });

    for (final entry in _mustHave.entries) {
      final shape = entry.key;

      test('${shape.label}：填全了就能存', () {
        final d = _complete(shape);
        expect(d.blockedReason, isNull, reason: d.blockedReason);
        expect(d.canSave, isTrue);
      });

      for (final (name, drop) in entry.value) {
        test('${shape.label}：缺「$name」就不能存', () {
          final d = drop(_complete(shape));
          expect(
            d.blockedReason,
            isNotNull,
            reason: '缺了「$name」却一句话都不说 —— 用户只会看见按钮亮着',
          );
          expect(d.canSave, isFalse);
        });
      }
    }
  });

  group('阶段事项：那句话要说得出「缺的是阶段时间」', () {
    // 提示语说错的代价很具体：用户按「至少要两个阶段」去加第三个阶段，
    // 而真正缺的是时间 —— 他会一直加下去。
    test('两个阶段都没时间时，说的是时间不是数量', () {
      final d = _complete(TaskShape.staged)
          .copyWith(stages: [_stage('a'), _stage('b')]);
      expect(d.blockedReason, contains('时间'));
      expect(d.blockedReason, isNot(contains('至少')));
    });

    test('只有一个阶段时，说的才是数量', () {
      final d = _complete(TaskShape.staged)
          .copyWith(stages: [_stage('a', offset: 0)]);
      expect(d.blockedReason, contains('至少'));
    });

    test('空白行不算一个阶段 —— 它不会顶替「至少两个」里的一个', () {
      // 保存时空白行会被丢掉（`filledStages`），所以校验也得按丢掉之后算。
      // 不然「一个真阶段 + 一个空行」看起来够两个，存下去只剩一个，
      // 而领域层会直接拒绝那条命令。
      final d = _complete(TaskShape.staged).copyWith(
        stages: [
          _stage('a', offset: 0),
          const StageDraft(id: 'blank', title: '   ', startOffsetMinutes: 0),
        ],
      );
      expect(d.blockedReason, contains('至少'));
    });
  });
}

/// 新建时选的那五样（FR-TASK-01/02/03）。
///
/// ## 它不是第五个 `TaskKind`
///
/// 库里表达一条任务用三个正交的东西：`kind`（单/阶段）、有没有
/// `recurrence`、有没有 `planDate`。五个选项是这三个的**组合**，
/// 不是一个新的枚举值：
///
/// | 选项 | `kind` | 重复 | 日期 |
/// |---|---|---|---|
/// | 单事项 | `single` | 无 | **必填** |
/// | 阶段事项 | `staged` | 无 | 必填 |
/// | 重复单事项 | `single` | 有 | 必填 |
/// | 重复阶段事项 | `staged` | 有 | 必填 |
/// | 临时事项 | `single` | 无 | **无** |
///
/// 把它做成第五个 `TaskKind` 的话，`wireName`、导出格式、同步信封、
/// 回放全都要跟着多一个取值 —— 而库里根本不需要多这一个：
/// 「临时」就是 `planDate == null`，那个状态本来就存在（列表的「无日期」
/// 分组、时间轴不收它，都是照着它做的）。
///
/// 所以它活在**编辑这一层**：决定编辑器显示哪些区块、必填哪些、
/// 默认值从哪来。存下去之后它就化进那三个字段里，读回来时
/// 由 [TaskShape.of] 反推。
library;

import '../../../domain/entities/task.dart';

enum TaskShape {
  /// 一件普通的事，有明确的起止。
  single('单事项'),

  /// 一件事分几步走，每步各有起止（≥2 步）。
  staged('阶段事项'),

  /// [single] 加上重复规则。
  recurringSingle('重复单事项'),

  /// [staged] 加上重复规则。
  recurringStaged('重复阶段事项'),

  /// **不排时间**的事。「哪天做都行」那一类。
  ///
  /// 它是「仅填标题即可保存」现在的落脚点 —— 别的四样都要求起止
  /// （FR-TASK-01 的验收 2026-09-09 改成这样，用户定的）。
  scratch('临时事项');

  const TaskShape(this.label);

  /// 面板上写的字。
  final String label;

  /// 存进库里是哪一种 `kind`。
  TaskKind get kind =>
      this == TaskShape.staged || this == TaskShape.recurringStaged
      ? TaskKind.staged
      : TaskKind.single;

  bool get isRecurring =>
      this == TaskShape.recurringSingle || this == TaskShape.recurringStaged;

  bool get hasStages => kind == TaskKind.staged;

  /// 要不要填日期。**只有临时事项不要。**
  bool get needsSchedule => this != TaskShape.scratch;

  /// 面板上的顺序：先按「单/阶段」，再按「一次/重复」，临时的垫底。
  ///
  /// **别随手调** —— 用户会形成肌肉记忆（同 `ViewKind` 那条）。
  static const List<TaskShape> menu = [
    TaskShape.single,
    TaskShape.staged,
    TaskShape.recurringSingle,
    TaskShape.recurringStaged,
    TaskShape.scratch,
  ];

  /// 从一条已经存下来的任务反推它是哪一样。
  ///
  /// 编辑已有任务时要用它来决定显示哪些区块。**注意它不是双射**：
  /// 「有日期、没重复、单项」既可能是用户选的「单事项」，也可能是
  /// 旧数据（那时候单事项不要求日期）。反推只看当前字段，
  /// 不去猜当初是怎么建的 —— 猜错的话，编辑器会拿一套不匹配的
  /// 必填规则去卡一条本来合法的旧任务。
  static TaskShape of(Task task) {
    if (task.kind == TaskKind.staged) {
      return task.isRecurring ? TaskShape.recurringStaged : TaskShape.staged;
    }
    if (task.isRecurring) return TaskShape.recurringSingle;
    return task.planDate == null ? TaskShape.scratch : TaskShape.single;
  }
}

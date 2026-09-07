/// 任务状态与合法迁移（task-lifecycle §1、§2）。
library;

/// 任务状态。**归档与删除不在其中** —— 它们用时间戳列表达（§1.1）。
///
/// 归档若是一个状态值，重复任务（`status` 恒为 `pending`）就永远无法归档，
/// 「是否已归档」对两类任务会分叉成两套判定，所有视图的过滤条件都要跟着分叉。
enum TaskStatus {
  pending,
  inProgress,
  done,
  skipped;

  /// 存进数据库与导出格式的串。
  ///
  /// **不存枚举序号**：序号随枚举重排而变，会静默改写全部历史数据。
  String get wireName => name;

  /// 从存储串还原。未知值**抛异常而不是回落到 pending** ——
  /// 静默回落会把「数据坏了」变成「用户的任务莫名变回待办」。
  static TaskStatus fromWireName(String value) {
    for (final s in TaskStatus.values) {
      if (s.name == value) return s;
    }
    throw FormatException('未知的任务状态', value);
  }
}

/// 非法状态迁移。
///
/// **显式异常，不是 `assert`**（task-lifecycle §3.1）：`assert` 在 AOT release
/// 构建里被整条移除，正式包零保护，且会让对应测试在 debug 下绿、release 下失效。
final class IllegalTransitionException implements Exception {
  const IllegalTransitionException(this.from, this.to, [this.reason]);

  final TaskStatus from;
  final TaskStatus to;
  final String? reason;

  @override
  String toString() =>
      'IllegalTransitionException: 不允许 ${from.name} → ${to.name}'
      '${reason == null ? '' : '（$reason）'}';
}

/// 领域不变量被破坏。同样是显式异常，理由同上。
final class DomainInvariantViolation implements Exception {
  const DomainInvariantViolation(this.message);
  final String message;

  @override
  String toString() => 'DomainInvariantViolation: $message';
}

/// 合法迁移表（task-lifecycle §2.1）。
///
/// 写成数据而不是一串 `if`：一是能被测试逐格枚举，二是与文档的表格逐格对照。
const Map<TaskStatus, Set<TaskStatus>> kAllowedTransitions = {
  TaskStatus.pending: {
    TaskStatus.inProgress,
    TaskStatus.done,
    TaskStatus.skipped,
  },
  TaskStatus.inProgress: {
    TaskStatus.pending,
    TaskStatus.done,
    TaskStatus.skipped,
  },
  // done → skipped 被禁止是刻意的：已完成的事再标「跳过」没有语义，
  // 多半是误操作。UI 应先取消完成。
  TaskStatus.done: {TaskStatus.pending, TaskStatus.inProgress},
  // skipped 只能回到 pending：跳过的事要重新处理，得先「捡回来」。
  TaskStatus.skipped: {TaskStatus.pending},
};

/// 该迁移是否合法。同状态到同状态视为合法（幂等）。
bool isTransitionAllowed(TaskStatus from, TaskStatus to) =>
    from == to || (kAllowedTransitions[from]?.contains(to) ?? false);

/// 校验迁移，非法则抛 [IllegalTransitionException]。
void requireTransitionAllowed(TaskStatus from, TaskStatus to) {
  if (!isTransitionAllowed(from, to)) {
    throw IllegalTransitionException(from, to);
  }
}

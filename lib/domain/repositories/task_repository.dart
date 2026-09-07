/// 任务仓储的**抽象接口**（module-map：`domain/repositories/` 只有接口）。
///
/// 领域层依赖这个接口，实现落在 `data/repositories/`。这个方向不能反 ——
/// 反过来的话领域层就绑死在 Drift 上，将来换存储要改的不是一层而是全部。
///
/// 方法签名里**不出现任何 Drift 类型**，架构守卫会检查这一点。
library;

import '../entities/stage.dart';
import '../entities/task.dart';

/// 查询任务时的可见性范围（task-lifecycle §1.1 的三个谓词）。
///
/// 做成枚举而不是让调用方各传各的过滤条件 —— 三个谓词必须是同一套定义，
/// 否则「回收站里混进归档任务」这类分叉迟早出现。
enum TaskScope {
  /// 未删除且未归档。
  active,

  /// 未删除且已归档。
  archived,

  /// 已删除（回收站）。
  trashed,

  /// 全部，含墓碑。**仅供导出与同步**。
  all,
}

/// 任务与其从属结构的读写。
abstract interface class TaskRepository {
  /// 按范围取任务。
  Future<List<Task>> findTasks({TaskScope scope = TaskScope.active});

  /// 按 ID 取单个任务；不存在（或已被墓碑遮蔽）时返回 null。
  Future<Task?> findTaskById(String id, {TaskScope scope = TaskScope.active});

  /// 某任务的阶段，按 `orderIndex` 升序。
  Future<List<Stage>> findStagesOfTask(
    String taskId, {
    TaskScope scope = TaskScope.active,
  });

  /// 监听某范围的任务变化。UI 靠它自动刷新。
  Stream<List<Task>> watchTasks({TaskScope scope = TaskScope.active});

  /// 写入任务。**会校验领域不变量**，违反时抛异常而不是写进库。
  Future<void> saveTask(Task task);

  /// 写入任务及其阶段（同一事务）。
  ///
  /// 分两次调用的话，中途失败会留下「任务改了但阶段没改」的半截状态 ——
  /// 而阶段状态推导父任务状态，半截状态会让两者永久不一致。
  Future<void> saveTaskWithStages(Task task, List<Stage> stages);

  /// 软删除任务，子实体一并打墓碑（task-lifecycle §6）。
  Future<void> softDeleteTask(String id);

  /// 从回收站恢复。
  Future<void> restoreTask(String id);
}

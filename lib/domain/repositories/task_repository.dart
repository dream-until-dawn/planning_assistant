/// 任务仓储的**抽象接口**（module-map：`domain/repositories/` 只有接口）。
///
/// 领域层依赖这个接口，实现落在 `data/repositories/`。这个方向不能反 ——
/// 反过来的话领域层就绑死在 Drift 上，将来换存储要改的不是一层而是全部。
///
/// 方法签名里**不出现任何 Drift 类型**，架构守卫会检查这一点。
library;

import '../entities/checklist_item.dart';
import '../entities/occurrence_override.dart';
import '../entities/reminder.dart';
import '../entities/stage.dart';
import '../entities/stage_occurrence_state.dart';
import '../entities/task.dart';
import '../services/all_day_conversion.dart';
import '../services/recurrence_conversion.dart';
import '../value_objects/occurrence_key.dart';

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

  /// **全部**未删除的阶段，持续推送。
  ///
  /// 不按 taskId 分别订阅：列表一屏可能有十几条阶段事项，那就是十几个流。
  /// 一次取全、在展示层按 taskId 索引，对 V1 的数据量
  /// （本地库、几百条任务）远够用。
  Stream<List<Stage>> watchAllStages();

  /// 写入任务。**会校验领域不变量**，违反时抛异常而不是写进库。
  Future<void> saveTask(Task task);

  /// **物理删除**一条已打墓碑的任务及其子实体（task-lifecycle §6、L-09）。
  ///
  /// 只用于超期清理。**不接受活着的任务** —— 判「该不该清」是领域策略
  /// （`isPurgeable`）的事，仓库这一侧只负责「只删墓碑」这条硬约束：
  /// 调用方算错了，最坏也只是清早了，不会把活数据抹掉。
  ///
  /// 返回真正删掉了几条任务（子实体不计）。
  Future<int> purgeDeleted(Iterable<String> taskIds);

  /// 全部提醒，持续推送（FR-NOTI-01）。
  ///
  /// **一次取全部，不按任务分**：排期一轮要看窗口内所有任务的提醒，
  /// 逐条查库就是 N+1；而提醒总量与任务同量级，很小。
  /// 同 [watchAllOverrides] 那条理由。
  Stream<List<Reminder>> watchAllReminders();

  /// 全部单次例外，持续推送。
  ///
  /// **一次取全部，不按任务分**：列表要一次展开几十条重复任务，
  /// 逐条查库就是 N+1；而例外总量很小（只有被交互过的那几次才落行）。
  Stream<List<OccurrenceOverride>> watchAllOverrides();

  Future<List<OccurrenceOverride>> findOverridesOfTask(String taskId);

  /// 写一条例外。
  ///
  /// **按 `(taskId, key)` 覆盖**，不是每次插一行 —— 一次发生只该有一条
  /// 例外（data-model §4.3.1）。
  ///
  /// 完成时刻在 `override.completedAt` 上，**不再单独作参数传** ——
  /// 单独传的那阵子，读路径没把它取回实体，凡是「在已有例外上叠加」
  /// 的调用点都会把它悄悄丢掉。
  Future<void> saveOverride(OccurrenceOverride override);

  /// 清掉一条例外，让那一次回到「跟随规则」。
  ///
  /// 取消完成时用它，而不是写一条 `status = pending` 的例外 ——
  /// 后者会让「从没动过」与「动过又撤回」在库里长得不一样，
  /// 而它们对用户是同一件事。
  Future<void> removeOverride(String taskId, OccurrenceKey key);

  /// 全部的阶段-发生状态（FR-TASK-07）。
  ///
  /// **一次取全再索引**，与 [watchAllStages] 同一个理由：
  /// 视图一屏会显示好几条任务的好几次发生，逐条订阅等于一屏 N 次往返。
  /// 这张表只在用户**真的勾过**某一次的某一步时才长出行来，
  /// 上界远小于任务表本身。
  Stream<List<StageOccurrenceState>> watchAllStageStates();

  /// 写一条阶段状态。同一个 (stageId, occurrenceKey) 覆盖写。
  Future<void> saveStageState(StageOccurrenceState state);

  /// 全部清单项（FR-TASK-09）。与 [watchAllStages] 同一个理由：
  /// 一次取全再索引，不按 taskId 逐条订阅。
  Stream<List<ChecklistItem>> watchAllChecklistItems();

  /// 一条任务的清单项。[scope] 决定要不要带上墓碑 ——
  /// 整表替换时必须看得见墓碑，否则会把已删的又「新建」回来。
  Future<List<ChecklistItem>> findChecklistOfTask(
    String taskId, {
    TaskScope scope = TaskScope.active,
  });

  /// 整表写回一条任务的清单项（含墓碑）。
  Future<void> saveChecklist(String taskId, List<ChecklistItem> items);

  /// 一条任务全部发生的阶段状态（R-27 迁移 key 时要取全，含墓碑与否由
  /// 调用方无关 —— 这里只给活着的，墓碑不需要迁移）。
  Future<List<StageOccurrenceState>> findStageStatesOfTask(String taskId);

  /// 全天 ⇄ 定时切换的落盘（R-27）。
  ///
  /// **必须原子**：任务改了而例外的 key 没迁，那些例外就永久失联了 ——
  /// 库里还在、界面上再也挂不上任何一次发生。
  ///
  /// [movedOverrides] / [movedStageStates] 的 `from` 是旧 key：
  /// 旧行打墓碑，新行另起（主键是从 key 派生的，见 `all_day_conversion`）。
  Future<void> applyAllDayConversion(AllDayConversion conversion);

  /// 单项 ⇄ 重复切换的落盘（FR-TASK-07）。
  ///
  /// **必须原子**：任务改了而阶段状态没迁，那段时间里用户看到的是
  /// 「我做完的东西没了」——数据其实还在，只是读路径改看另一张表。
  Future<void> applyRecurrenceConversion(RecurrenceConversion conversion);

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

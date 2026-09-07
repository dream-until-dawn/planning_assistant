/// 写路径的唯一入口（architecture/overview §4）。
///
/// **所有数据变更都必须表达成一个 `TaskCommand`**，没有例外。这不是为了
/// 好看，是三个后续期次的前提：
///
///  · V1：撤销/重做只需实现每个命令的逆操作；变更日志天然产生，
///    不必在每个仓储方法里手写埋点；
///  · V3：云端下发的变更与本地操作走**完全相同**的校验路径；
///  · V4：AI Agent 只需输出 JSON 形态的命令，不必理解 UI。
///
/// 后两条要求命令**可 JSON 往返**，这是 M1 的验收项之一，
/// 由 `test/domain/task_command_test.dart` 逐个命令验证。
library;

import '../../core/patch/unset.dart';
import '../../core/time/minute_of_day.dart';
import '../../core/time/plan_date.dart';
import '../entities/task.dart';
import '../value_objects/task_status.dart';

/// 命令解析失败。
///
/// 未知命令类型必须**抛出**而不是忽略：V3 云端下发一个本端不认识的命令时，
/// 静默跳过会造成两端状态永久分歧，且没有任何迹象。
final class UnknownCommandException implements Exception {
  const UnknownCommandException(this.type);
  final String type;

  @override
  String toString() => 'UnknownCommandException: 未知的命令类型「$type」';
}

/// 所有任务命令的基类。
///
/// `sealed` 让 `switch` 能穷尽检查 —— 新增命令时所有分发点会编译报错，
/// 而不是在运行时悄悄走进 default 分支。
sealed class TaskCommand {
  const TaskCommand();

  /// JSON 里的类型判别串。**改它等于改协议**，V3 的云端载荷依赖它。
  String get type;

  Map<String, Object?> toJson();

  /// 从 JSON 还原。
  static TaskCommand fromJson(Map<String, Object?> json) {
    final type = json['type'];
    if (type is! String) {
      throw const UnknownCommandException('(缺少 type 字段)');
    }
    return switch (type) {
      CreateTaskCommand.kType => CreateTaskCommand.fromJson(json),
      UpdateTaskFieldsCommand.kType => UpdateTaskFieldsCommand.fromJson(json),
      ChangeTaskStatusCommand.kType => ChangeTaskStatusCommand.fromJson(json),
      ArchiveTaskCommand.kType => ArchiveTaskCommand.fromJson(json),
      UnarchiveTaskCommand.kType => UnarchiveTaskCommand.fromJson(json),
      DeleteTaskCommand.kType => DeleteTaskCommand.fromJson(json),
      RestoreTaskCommand.kType => RestoreTaskCommand.fromJson(json),
      ReplaceStagesCommand.kType => ReplaceStagesCommand.fromJson(json),
      CompleteTaskWithStagesCommand.kType =>
        CompleteTaskWithStagesCommand.fromJson(json),
      _ => throw UnknownCommandException(type),
    };
  }

  /// 全部命令类型串，供守卫测试核对「每个命令都能往返」。
  static const List<String> allTypes = [
    CreateTaskCommand.kType,
    UpdateTaskFieldsCommand.kType,
    ChangeTaskStatusCommand.kType,
    ArchiveTaskCommand.kType,
    UnarchiveTaskCommand.kType,
    DeleteTaskCommand.kType,
    RestoreTaskCommand.kType,
    ReplaceStagesCommand.kType,
    CompleteTaskWithStagesCommand.kType,
  ];
}

/// 建任务。
final class CreateTaskCommand extends TaskCommand {
  const CreateTaskCommand({
    required this.taskId,
    required this.title,
    required this.kind,
    required this.timeZoneId,
    this.note,
    this.categoryId,
    this.priority = TaskPriority.normal,
    this.isAllDay = false,
    this.planDate,
    this.startMinute,
    this.endDate,
    this.endMinute,
    this.recurrenceRule,
    this.colorArgb,
    this.icon,
    this.sortOrder = 0,
  });

  static const kType = 'createTask';

  /// **由调用方生成**（UUID v7），不由 dispatcher 现场生成。
  ///
  /// 否则同一个命令重放两次会建出两条任务 —— 而 V3 的重试、
  /// V1 的 outbox 回放都会重放命令。ID 在命令里 = 天然幂等。
  final String taskId;
  final String title;
  final TaskKind kind;
  final String timeZoneId;
  final String? note;
  final String? categoryId;
  final TaskPriority priority;
  final bool isAllDay;
  final PlanDate? planDate;
  final MinuteOfDay? startMinute;
  final PlanDate? endDate;
  final MinuteOfDay? endMinute;
  final String? recurrenceRule;
  final int? colorArgb;
  final String? icon;
  final double sortOrder;

  @override
  String get type => kType;

  @override
  Map<String, Object?> toJson() => {
    'type': kType,
    'taskId': taskId,
    'title': title,
    'kind': kind.wireName,
    'timeZoneId': timeZoneId,
    'note': note,
    'categoryId': categoryId,
    'priority': priority.value,
    'isAllDay': isAllDay,
    'planDate': planDate?.toString(),
    'startMinute': startMinute?.value,
    'endDate': endDate?.toString(),
    'endMinute': endMinute?.value,
    'recurrenceRule': recurrenceRule,
    'colorArgb': colorArgb,
    'icon': icon,
    'sortOrder': sortOrder,
  };

  static CreateTaskCommand fromJson(Map<String, Object?> json) =>
      CreateTaskCommand(
        taskId: json['taskId']! as String,
        title: json['title']! as String,
        kind: TaskKind.fromWireName(json['kind']! as String),
        timeZoneId: json['timeZoneId']! as String,
        note: json['note'] as String?,
        categoryId: json['categoryId'] as String?,
        priority: TaskPriority.fromValue(json['priority']! as int),
        isAllDay: json['isAllDay']! as bool,
        planDate: _parseDate(json['planDate']),
        startMinute: _parseMinute(json['startMinute']),
        endDate: _parseDate(json['endDate']),
        endMinute: _parseMinute(json['endMinute']),
        recurrenceRule: json['recurrenceRule'] as String?,
        colorArgb: json['colorArgb'] as int?,
        icon: json['icon'] as String?,
        sortOrder: (json['sortOrder']! as num).toDouble(),
      );
}

/// 改任务的**非状态**字段。
///
/// 状态另有专门命令：状态迁移要过状态机，字段编辑不用 ——
/// 混在一起会让「改个标题」也被迁移表拦下。
final class UpdateTaskFieldsCommand extends TaskCommand {
  const UpdateTaskFieldsCommand({
    required this.taskId,
    this.title,
    this.note = unset,
    this.categoryId = unset,
    this.priority,
    this.planDate = unset,
    this.startMinute = unset,
    this.endDate = unset,
    this.endMinute = unset,
    this.recurrenceRule = unset,
    this.colorArgb = unset,
    this.icon = unset,
    this.sortOrder,
  });

  static const kType = 'updateTaskFields';

  /// JSON 里用「键不存在」表示不改、`null` 表示清空 —— 两者必须可区分，
  /// 否则「清空备注」和「不动备注」在协议上是同一个东西。
  ///
  /// 哨兵用 `core/patch` 的共享 [unset]，与 `copyWith` 同一个实例，
  /// 于是命令的补丁语义可以**原样**传给实体，不必在中间翻译一道。
  final String taskId;
  final String? title;
  final Object? note;
  final Object? categoryId;
  final TaskPriority? priority;
  final Object? planDate;
  final Object? startMinute;
  final Object? endDate;
  final Object? endMinute;
  final Object? recurrenceRule;
  final Object? colorArgb;
  final Object? icon;
  final double? sortOrder;

  bool _isKeep(Object? v) => identical(v, unset);

  @override
  String get type => kType;

  @override
  Map<String, Object?> toJson() => {
    'type': kType,
    'taskId': taskId,
    if (title != null) 'title': title,
    if (!_isKeep(note)) 'note': note,
    if (!_isKeep(categoryId)) 'categoryId': categoryId,
    if (priority != null) 'priority': priority!.value,
    if (!_isKeep(planDate)) 'planDate': (planDate as PlanDate?)?.toString(),
    if (!_isKeep(startMinute))
      'startMinute': (startMinute as MinuteOfDay?)?.value,
    if (!_isKeep(endDate)) 'endDate': (endDate as PlanDate?)?.toString(),
    if (!_isKeep(endMinute)) 'endMinute': (endMinute as MinuteOfDay?)?.value,
    if (!_isKeep(recurrenceRule)) 'recurrenceRule': recurrenceRule,
    if (!_isKeep(colorArgb)) 'colorArgb': colorArgb,
    if (!_isKeep(icon)) 'icon': icon,
    if (sortOrder != null) 'sortOrder': sortOrder,
  };

  static UpdateTaskFieldsCommand fromJson(Map<String, Object?> json) =>
      UpdateTaskFieldsCommand(
        taskId: json['taskId']! as String,
        title: json['title'] as String?,
        note: json.containsKey('note') ? json['note'] : unset,
        categoryId: json.containsKey('categoryId') ? json['categoryId'] : unset,
        priority: json.containsKey('priority')
            ? TaskPriority.fromValue(json['priority']! as int)
            : null,
        planDate: json.containsKey('planDate')
            ? _parseDate(json['planDate'])
            : unset,
        startMinute: json.containsKey('startMinute')
            ? _parseMinute(json['startMinute'])
            : unset,
        endDate: json.containsKey('endDate')
            ? _parseDate(json['endDate'])
            : unset,
        endMinute: json.containsKey('endMinute')
            ? _parseMinute(json['endMinute'])
            : unset,
        recurrenceRule: json.containsKey('recurrenceRule')
            ? json['recurrenceRule']
            : unset,
        colorArgb: json.containsKey('colorArgb') ? json['colorArgb'] : unset,
        icon: json.containsKey('icon') ? json['icon'] : unset,
        sortOrder: (json['sortOrder'] as num?)?.toDouble(),
      );
}

/// 改任务状态。走状态机。
final class ChangeTaskStatusCommand extends TaskCommand {
  const ChangeTaskStatusCommand({required this.taskId, required this.status});

  static const kType = 'changeTaskStatus';

  final String taskId;
  final TaskStatus status;

  @override
  String get type => kType;

  @override
  Map<String, Object?> toJson() => {
    'type': kType,
    'taskId': taskId,
    'status': status.wireName,
  };

  static ChangeTaskStatusCommand fromJson(Map<String, Object?> json) =>
      ChangeTaskStatusCommand(
        taskId: json['taskId']! as String,
        status: TaskStatus.fromWireName(json['status']! as String),
      );
}

/// 只带 ID 的命令共用的形状。
///
/// `sealed` 而非 `abstract base`：只有 sealed 才让 dispatcher 的 `switch`
/// 通过穷尽检查 —— 否则新增一个只带 ID 的命令时，分发处不会编译报错，
/// 而是运行时静默地什么都不做。
sealed class _TaskIdOnlyCommand extends TaskCommand {
  const _TaskIdOnlyCommand(this.taskId);
  final String taskId;

  @override
  Map<String, Object?> toJson() => {'type': type, 'taskId': taskId};
}

final class ArchiveTaskCommand extends _TaskIdOnlyCommand {
  const ArchiveTaskCommand(super.taskId);
  static const kType = 'archiveTask';

  @override
  String get type => kType;

  static ArchiveTaskCommand fromJson(Map<String, Object?> json) =>
      ArchiveTaskCommand(json['taskId']! as String);
}

final class UnarchiveTaskCommand extends _TaskIdOnlyCommand {
  const UnarchiveTaskCommand(super.taskId);
  static const kType = 'unarchiveTask';

  @override
  String get type => kType;

  static UnarchiveTaskCommand fromJson(Map<String, Object?> json) =>
      UnarchiveTaskCommand(json['taskId']! as String);
}

final class DeleteTaskCommand extends _TaskIdOnlyCommand {
  const DeleteTaskCommand(super.taskId);
  static const kType = 'deleteTask';

  @override
  String get type => kType;

  static DeleteTaskCommand fromJson(Map<String, Object?> json) =>
      DeleteTaskCommand(json['taskId']! as String);
}

final class RestoreTaskCommand extends _TaskIdOnlyCommand {
  const RestoreTaskCommand(super.taskId);
  static const kType = 'restoreTask';

  @override
  String get type => kType;

  static RestoreTaskCommand fromJson(Map<String, Object?> json) =>
      RestoreTaskCommand(json['taskId']! as String);
}

/// 阶段的整体替换。
///
/// **不做「加一个阶段」「删一个阶段」的细粒度命令**：阶段有 `orderIndex`
/// 必须从 0 连续这条不变量，增删都要重排后续项。细粒度命令会让每次增删
/// 都附带一串「顺带改了别的阶段」的隐式变更，回放时极难对账。
/// 整体替换的载荷更大，但语义是自洽的。
final class ReplaceStagesCommand extends TaskCommand {
  const ReplaceStagesCommand({required this.taskId, required this.stages});

  static const kType = 'replaceStages';

  final String taskId;
  final List<StageSpec> stages;

  @override
  String get type => kType;

  @override
  Map<String, Object?> toJson() => {
    'type': kType,
    'taskId': taskId,
    'stages': [for (final s in stages) s.toJson()],
  };

  static ReplaceStagesCommand fromJson(Map<String, Object?> json) =>
      ReplaceStagesCommand(
        taskId: json['taskId']! as String,
        stages: [
          for (final s in json['stages']! as List)
            StageSpec.fromJson(s as Map<String, Object?>),
        ],
      );
}

/// 命令载荷里的阶段描述。
///
/// 与 `Stage` 实体分开：实体带 `deletedAt` 等持久化痕迹，
/// 命令载荷只该有「用户想要什么」。
final class StageSpec {
  const StageSpec({
    required this.id,
    required this.title,
    required this.orderIndex,
    this.startOffsetMinutes,
    this.durationMinutes,
    this.colorArgb,
    this.status = TaskStatus.pending,
  });

  final String id;
  final String title;
  final int orderIndex;
  final int? startOffsetMinutes;
  final int? durationMinutes;
  final int? colorArgb;
  final TaskStatus status;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'orderIndex': orderIndex,
    'startOffsetMinutes': startOffsetMinutes,
    'durationMinutes': durationMinutes,
    'colorArgb': colorArgb,
    'status': status.wireName,
  };

  static StageSpec fromJson(Map<String, Object?> json) => StageSpec(
    id: json['id']! as String,
    title: json['title']! as String,
    orderIndex: json['orderIndex']! as int,
    startOffsetMinutes: json['startOffsetMinutes'] as int?,
    durationMinutes: json['durationMinutes'] as int?,
    colorArgb: json['colorArgb'] as int?,
    status: TaskStatus.fromWireName(json['status']! as String),
  );
}

/// 把父任务标完成，并把所有未完成阶段一并标完成（task-lifecycle §4.2）。
///
/// 单独成一个命令而不是让 UI 先后发两条：这两步必须原子，
/// 中途失败会留下「父任务完成但阶段没完成」的不一致。
final class CompleteTaskWithStagesCommand extends _TaskIdOnlyCommand {
  const CompleteTaskWithStagesCommand(super.taskId);
  static const kType = 'completeTaskWithStages';

  @override
  String get type => kType;

  static CompleteTaskWithStagesCommand fromJson(Map<String, Object?> json) =>
      CompleteTaskWithStagesCommand(json['taskId']! as String);
}

PlanDate? _parseDate(Object? raw) =>
    raw == null ? null : PlanDate.parse(raw as String);

MinuteOfDay? _parseMinute(Object? raw) =>
    raw == null ? null : MinuteOfDay(raw as int);

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
import '../entities/occurrence.dart';
import '../entities/task.dart';
import '../value_objects/occurrence_key.dart';
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
      SetOccurrenceStatusCommand.kType => SetOccurrenceStatusCommand.fromJson(
        json,
      ),
      SkipOccurrenceCommand.kType => SkipOccurrenceCommand.fromJson(json),
      SplitRecurringTaskCommand.kType => SplitRecurringTaskCommand.fromJson(
        json,
      ),
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
    this.splitFromTaskId,
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

  /// 「本次及以后」分裂出来的新任务，指回原任务（data-model §4.4）。
  /// 用于将来「合并回去」与同步溯源。
  final String? splitFromTaskId;

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
    'splitFromTaskId': splitFromTaskId,
  };

  /// 换一个 taskId 的同一份内容。
  ///
  /// 「本次及以后」在分割点正好是第一次时用它：那时不分裂，
  /// 把新内容直接落到**原任务**上。
  CreateTaskCommand copyWithId(String id) => CreateTaskCommand(
    taskId: id,
    title: title,
    kind: kind,
    timeZoneId: timeZoneId,
    note: note,
    categoryId: categoryId,
    priority: priority,
    isAllDay: isAllDay,
    planDate: planDate,
    startMinute: startMinute,
    endDate: endDate,
    endMinute: endMinute,
    recurrenceRule: recurrenceRule,
    colorArgb: colorArgb,
    icon: icon,
    sortOrder: sortOrder,
    splitFromTaskId: splitFromTaskId,
  );

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
        splitFromTaskId: json['splitFromTaskId'] as String?,
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

/// 改**某一次发生**的状态（FR-TASK-05）。
///
/// ## 为什么不是 [ChangeTaskStatusCommand]
///
/// 重复任务的 `tasks.status` **恒为 pending**，真实状态在
/// `occurrence_overrides`（data-model §4.3，领域不变量强制）。
/// 拿 `ChangeTaskStatusCommand` 去改一条重复任务，落库前会被不变量
/// 直接拒掉 —— 那正是补这条命令之前的真实行为：**在列表里勾一条
/// 重复任务，抛 `DomainInvariantViolation`**。
///
/// ## `status` 为 null 的含义
///
/// 「回到跟随规则」，实现上是删掉那条例外，而不是写一条
/// `status = pending` 的例外。后者会让「从没动过」与「动过又撤回」
/// 在库里长得不一样，而它们对用户是同一件事 —— 于是导出、同步、
/// 「这一次改过没有」的判断全都要多分一支。
final class SetOccurrenceStatusCommand extends TaskCommand {
  const SetOccurrenceStatusCommand({
    required this.taskId,
    required this.occurrenceKey,
    required this.status,
  });

  static const kType = 'setOccurrenceStatus';

  final String taskId;

  /// **原始**发生时刻的标识（§4.2）——
  /// 这一次即使被挪到别的日期，它仍然是同一次。
  final OccurrenceKey occurrenceKey;

  /// null = 清掉例外，回到跟随规则。
  final OccurrenceStatus? status;

  @override
  String get type => kType;

  @override
  Map<String, Object?> toJson() => {
    'type': kType,
    'taskId': taskId,
    'occurrenceKey': occurrenceKey.value,
    'status': status?.wireName,
  };

  static SetOccurrenceStatusCommand fromJson(Map<String, Object?> json) =>
      SetOccurrenceStatusCommand(
        taskId: json['taskId']! as String,
        occurrenceKey: OccurrenceKey.parse(json['occurrenceKey']! as String),
        status: json['status'] == null
            ? null
            : OccurrenceStatus.fromWireName(json['status']! as String),
      );
}

/// 跳过某一次发生（FR-TASK-05）。
///
/// ## 跳过与「标记为已跳过」不是一回事
///
/// | | 落库 | 效果 |
/// |---|---|---|
/// | 跳过（本命令） | `action = skip` | 那一次**从视图里消失**（验收原话） |
/// | 状态改成 skipped | `status = skipped` | 行还在，进「已跳过」组 |
///
/// 前者是「这一次不发生」，后者是「这一次我没做」。
/// 混用的话，「跳过的次数不出现在任何视图」这条验收就落空了。
///
/// 撤回用 [SetOccurrenceStatusCommand] 传 `status: null` —— 那会把整条
/// 例外删掉，包括 `action`。所以不需要一条单独的「取消跳过」命令。
final class SkipOccurrenceCommand extends TaskCommand {
  const SkipOccurrenceCommand({
    required this.taskId,
    required this.occurrenceKey,
  });

  static const kType = 'skipOccurrence';

  final String taskId;
  final OccurrenceKey occurrenceKey;

  @override
  String get type => kType;

  @override
  Map<String, Object?> toJson() => {
    'type': kType,
    'taskId': taskId,
    'occurrenceKey': occurrenceKey.value,
  };

  static SkipOccurrenceCommand fromJson(Map<String, Object?> json) =>
      SkipOccurrenceCommand(
        taskId: json['taskId']! as String,
        occurrenceKey: OccurrenceKey.parse(json['occurrenceKey']! as String),
      );
}

/// 「本次及以后」修改（FR-TASK-06）。
///
/// ## 不改历史，而是分裂（data-model §4.4）
///
/// 1. 原任务的 RRULE 追加 `UNTIL=<分割点前一天>`；
/// 2. 新建一条任务，规则从分割点起生效，`planDate` 就是分割点；
/// 3. 新任务记 [CreateTaskCommand.splitFromTaskId] 溯源。
///
/// 好处是**历史发生的完成记录原样保留**，而且云端合并时不需要理解
/// 「部分修改」这种复杂语义 —— 它看到的只是「一条任务改了 UNTIL」
/// 加「新建了一条任务」。
///
/// ## 为什么是一条命令，不是两条
///
/// 拆成「改原任务」+「建新任务」两条的话，回放时可以只应用前一条 ——
/// 结果是用户的重复任务**在分割点静默终止**，后面那半截凭空消失。
/// 一条命令才谈得上原子。
///
/// ## 分割点正好是第一次时
///
/// 那样截断出来的原任务一次都不发生，留下一条死任务。这时正确的
/// realization 是**直接改整条**，不分裂 —— 由 dispatcher 判，
/// 而不是让调用方各自记得。
final class SplitRecurringTaskCommand extends TaskCommand {
  const SplitRecurringTaskCommand({
    required this.taskId,
    required this.splitAt,
    required this.newTask,
    this.stages = const [],
  });

  static const kType = 'splitRecurringTask';

  /// 被分裂的原任务。
  final String taskId;

  /// 从**这一次**起（含）用新规则。
  final OccurrenceKey splitAt;

  /// 分割点之后那一半长什么样。它自带新任务的 ID。
  final CreateTaskCommand newTask;

  /// 新那一半的阶段。
  ///
  /// **跟着一起来，不是另发一条 `ReplaceStagesCommand`。**
  /// 分割点正好是第一次时不分裂（见上），那时阶段该落到**原任务**上 ——
  /// 而「落到哪条」这个判断在 dispatcher 里。让调用方另发一条的话，
  /// 它得把同一个判断再写一遍，两处迟早分叉。
  final List<StageSpec> stages;

  @override
  String get type => kType;

  @override
  Map<String, Object?> toJson() => {
    'type': kType,
    'taskId': taskId,
    'splitAt': splitAt.value,
    'newTask': newTask.toJson(),
    'stages': [for (final s in stages) s.toJson()],
  };

  static SplitRecurringTaskCommand fromJson(Map<String, Object?> json) =>
      SplitRecurringTaskCommand(
        taskId: json['taskId']! as String,
        splitAt: OccurrenceKey.parse(json['splitAt']! as String),
        newTask: CreateTaskCommand.fromJson(
          json['newTask']! as Map<String, Object?>,
        ),
        stages: [
          for (final s in (json['stages'] as List? ?? const []))
            StageSpec.fromJson(s as Map<String, Object?>),
        ],
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

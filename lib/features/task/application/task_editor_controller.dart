/// 任务编辑器的表单状态与保存（FR-TASK-01）。
///
/// **写路径只有一条：构造命令 → `CommandDispatcher`。**
/// 这里拿不到仓库，也不该拿 —— 分层守卫盯着这条
/// （module-map §3：presentation 不得持有 Repository）。
/// 理由是 FR-AI-01：V4 的语音/Agent 要能构造同一批命令走同一条路，
/// UI 绕过命令直接写库的话，那条路就绕过了全部不变量与 outbox。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../../app_providers.dart';
import '../../../core/patch/unset.dart';
import '../../../core/time/date_and_minute.dart';
import '../../../core/time/local_wall_time.dart';
import '../../../core/time/minute_of_day.dart';
import '../../../core/time/plan_date.dart';
import '../../../domain/commands/task_command.dart';
import '../../../domain/entities/checklist_item.dart';
import '../../../domain/entities/reminder.dart';
import '../../../domain/entities/stage.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/value_objects/occurrence_key.dart';
import '../../../domain/value_objects/recurrence.dart';
import '../../../domain/value_objects/task_status.dart';
import '../../reminder/application/reminder_providers.dart';
import '../../settings/application/registry.dart';
import '../../settings/application/settings_providers.dart';
import '../../views/shared/application/category_providers.dart';
import '../../views/shared/application/task_providers.dart';
import 'derived_span.dart';
import 'recurrence_draft.dart';
import 'task_shape.dart';

/// 表单里的一个阶段（FR-TASK-02）。
///
/// 与 `StageSpec` 分开：那个是**命令载荷**，要求 `orderIndex` 从 0 起连续；
/// 这个是**编辑中的行**，用户增删拖拽时顺序是临时乱的，
/// 到保存那一刻才按列表位置重排成连续的。
///
/// 混用一个类型的话，每次增删都得立刻重排一遍 orderIndex，
/// 而中间任何一步出错都会写出不连续的序号 —— 那是领域层会直接拒绝的。
@immutable
/// 编辑器里的一条清单项（FR-TASK-09）。
///
/// **比 [StageDraft] 少的东西就是它的定义**：没有时间偏移、没有时长。
/// 清单项「不参与时间排布」（术语表），少这两个字段不是省略，
/// 是它跟阶段的分界线 —— 哪天有人给它加上 `startOffsetMinutes`，
/// 它就变成了第二种阶段。
final class ChecklistDraft {
  const ChecklistDraft({
    required this.id,
    this.title = '',
    this.isDone = false,
  });

  final String id;
  final String title;
  final bool isDone;

  ChecklistDraft copyWith({String? title, bool? isDone}) => ChecklistDraft(
    id: id,
    title: title ?? this.title,
    isDone: isDone ?? this.isDone,
  );
}

/// 表单里的一条提醒（FR-NOTI-01）。
///
/// **只做相对开始的那一种**。三种 kind 里，`relativeToEnd` 与 `absolute`
/// 领域层都支持、排期也算得对，但界面上先只给最常用的这一档 ——
/// 多给两档要多两个控件（选基准点、选绝对日期时刻），
/// 而「提前多久」覆盖了绝大多数场景。
///
/// 这不是「领域层做多了」：另外两种是**导入与将来的 Agent** 构造得出来的
/// （FR-AI-01），排期照样处理。界面够不着不等于它们不存在。
final class ReminderDraft {
  const ReminderDraft({
    required this.id,
    required this.offsetMinutes,
    this.isEnabled = true,
  });

  final String id;

  /// 负数 = 提前，与 `Reminder.offsetMinutes` 同一套约定。
  final int offsetMinutes;
  final bool isEnabled;

  ReminderDraft copyWith({int? offsetMinutes, bool? isEnabled}) =>
      ReminderDraft(
        id: id,
        offsetMinutes: offsetMinutes ?? this.offsetMinutes,
        isEnabled: isEnabled ?? this.isEnabled,
      );
}

final class StageDraft {
  const StageDraft({
    required this.id,
    this.title = '',
    this.startOffsetMinutes,
    this.durationMinutes,
    this.status = TaskStatus.pending,
  });

  final String id;
  final String title;

  /// 相对**任务开始**的分钟偏移，与 `Stage` 存的是同一个东西
  /// （data-model §4.1）。null = 这个阶段没定时间。
  ///
  /// 草稿里存偏移而不是绝对时刻，是为了跟存储同语义：
  /// 把任务整体挪到下一周，阶段跟着挪 —— 存绝对时刻的话，
  /// 编辑器里的表现会与存下去之后的表现不一样。
  /// 界面上显示的绝对时刻由 `stage_time.dart` 现算（§4.1：看绝对、存偏移）。
  final int? startOffsetMinutes;

  /// 时长。null = 只有一个开始点，没有跨度。
  final int? durationMinutes;

  /// 这个阶段做完了没有。
  ///
  /// **草稿必须带上它。** 一度没带 —— 于是编辑一条有已完成阶段的任务、
  /// 什么都不改直接保存，`ReplaceStagesCommand` 会把整表换成
  /// 默认的 `pending`，**用户的进度被静默清空**。
  /// 而界面上看不出任何异常：保存成功，回到列表，卡片上的
  /// 「阶段 1/3」变成「阶段 0/3」。
  final TaskStatus status;

  bool get isDone => status == TaskStatus.done;

  bool get hasTime => startOffsetMinutes != null;

  StageDraft copyWith({
    String? title,
    Object? startOffsetMinutes = unset,
    Object? durationMinutes = unset,
    TaskStatus? status,
  }) => StageDraft(
    id: id,
    title: title ?? this.title,
    // 两个都要能清掉（「这个阶段其实不用定时间」），所以走哨兵。
    startOffsetMinutes: patch(startOffsetMinutes, this.startOffsetMinutes),
    durationMinutes: patch(durationMinutes, this.durationMinutes),
    status: status ?? this.status,
  );
}

/// 编辑器里那张表单。
///
/// 与 [Task] 刻意**不是**同一个类型：表单里「标题还没填」是合法中间态，
/// 而领域实体不允许标题为空。把两者混成一个类型的话，
/// 要么实体的不变量被放宽，要么表单没法表达「填一半」。
final class TaskDraft {
  const TaskDraft({
    this.shape = TaskShape.single,
    this.editingTaskId,
    this.splitAt,
    this.unsupportedRecurrence,
    this.title = '',
    this.note = '',
    this.isAllDay = true,
    this.planDate,
    this.startMinute,
    this.endDate,
    this.endMinute,
    this.categoryId,
    this.priority = TaskPriority.normal,
    this.stages = const [],
    this.checklist = const [],
    this.reminders = const [],
    this.recurrence = const RecurrenceDraft(),
    this.initialIsAllDay,
  });

  /// 用户新建时选的那一样，或从已有任务反推出来的那一样
  /// （[TaskShape.of]）。
  ///
  /// 它决定**表单长什么样、必填什么**：临时事项不显示日期区，
  /// 单事项不显示阶段与重复区，等等。存下去之后它化进
  /// `kind` / `recurrence` / `planDate` 三个字段里 —— 库里没有这个概念。
  final TaskShape shape;

  /// 正在编辑哪条任务。**null = 新建**。
  ///
  /// 保存时靠它分岔：新建走 `CreateTaskCommand`，编辑走
  /// `UpdateTaskFieldsCommand`。
  final String? editingTaskId;

  /// 这条任务的重复规则**这个界面表达不了**（`RecurrenceDraft.fromRrule`
  /// 认不出来），原样存着。
  ///
  /// 没有它的话，打开一条 `BYDAY=-1FR`（每月最后一个周五）的任务，
  /// 重复区会显示成「不重复」—— 用户什么都没动，一按保存，
  /// **规则就被悄悄抹掉了**。这是「反解只为显示」那条注释里
  /// 早就点名的危险，真做编辑时才会撞上。
  ///
  /// 非 null 时：重复区变成一行只读说明，保存时把原串原样传回去。
  final String? unsupportedRecurrence;

  bool get isEditing => editingTaskId != null;

  /// 「本次及以后」：从这一次起用新内容（FR-TASK-06）。
  ///
  /// 非 null 时保存走 `SplitRecurringTaskCommand`：原规则截断在这一次之前，
  /// 新内容变成一条从这一次起的新任务。
  final OccurrenceKey? splitAt;

  bool get isSplitting => splitAt != null;

  final String title;
  final String note;

  /// 默认全天。**大多数事情没有精确到分钟的时刻**，
  /// 让用户先说「哪天」，要不要具体到几点是可选的加法。
  final bool isAllDay;

  final PlanDate? planDate;
  final MinuteOfDay? startMinute;

  /// 结束（FR-TASK-01 的「可选计划时间段」）。
  ///
  /// **全可选**：绝大多数任务只有一个「哪天」，没有跨度。
  /// 有结束时刻就必须有结束日期，有结束日期就必须有开始日期 ——
  /// 与开始侧同一套规矩，由 `Task.checkInvariants` 兜底。
  final PlanDate? endDate;
  final MinuteOfDay? endMinute;

  /// 分类。**null 就是「未分类」**（settings-spec §3.0），
  /// 不是「还没选」—— 库里没有「未分类」那一行，选它就是写 null。
  final String? categoryId;

  /// 优先级（FR-TASK-01）。默认「普通」——
  /// 与 `CreateTaskCommand` 的默认值一致，两处分叉的话
  /// 「不选就是普通」这句话会在某条路径上不成立。
  final TaskPriority priority;

  /// 阶段。空 = 单项任务（FR-TASK-01）；≥2 = 阶段事项（FR-TASK-02）。
  ///
  /// **1 个是非法的**，领域层会拒绝 —— 一个只有一个阶段的阶段事项
  /// 与单项任务毫无区别。界面上由 [canSave] 挡住。
  final List<StageDraft> stages;

  /// 清单项（FR-TASK-09）。
  final List<ChecklistDraft> checklist;

  /// 提醒（FR-NOTI-01）。空 = 这条任务不提醒。
  final List<ReminderDraft> reminders;

  /// 打开这张表单时任务是不是全天的。**新建时为 null。**
  ///
  /// 保存时用它判断要不要发 `ConvertTaskAllDayModeCommand`（R-27）——
  /// 那条命令会把已有例外的 key 全部迁一遍，只在**真的换了形态**时发。
  /// 拿 `isEditing` 当条件的话，每次保存都迁一遍，白白造一批墓碑。
  final bool? initialIsAllDay;

  /// 这次保存有没有换形态。
  bool get allDayModeChanged =>
      initialIsAllDay != null && initialIsAllDay != isAllDay;

  /// 有效清单项：标题非空的那些。同 [filledStages] ——
  /// 点了「加一项」还没打字的空行不该落库。
  List<ChecklistDraft> get filledChecklist => [
    for (final i in checklist)
      if (i.title.trim().isNotEmpty) i,
  ];

  /// 有效阶段：标题非空的那些。
  ///
  /// 空白行不算 —— 用户点了「加阶段」还没来得及打字，那不该算一个阶段。
  List<StageDraft> get filledStages => [
    for (final s in stages)
      if (s.title.trim().isNotEmpty) s,
  ];

  bool get isStaged => filledStages.length >= 2;

  /// 重复规则（FR-TASK-03/04）。
  final RecurrenceDraft recurrence;

  /// 这条任务重不重复。
  ///
  /// **界面表达不了的规则也算重复**（`unsupportedRecurrence`）——
  /// 那条规则确实在，只是这个编辑器改不了它。
  /// 漏掉它的话，一条 `BYSETPOS` 的重复任务会被当成不重复，
  /// 于是又显示出那个对它没有意义的阶段勾选框。
  bool get isRecurring => recurrence.enabled || unsupportedRecurrence != null;

  /// 重复任务**必须有日期**：RRULE 的展开以 DTSTART 为锚点，
  /// 没有起点就无从展开。与「非全天必须有日期」是同一类约束。
  bool get needsDateForRecurrence => recurrence.enabled && planDate == null;

  /// 能不能保存。
  ///
  /// 标题非空是底线（FR-TASK-01：仅填标题即可保存）。
  /// 用 `trim()`：一串空格不是标题 —— 不 trim 的话用户能存出一条
  /// 看起来空白、却怎么也搜不到的任务。
  /// 另外**动过阶段就得填够两个**：加了一行却只填一个，保存下去会得到
  /// 一个领域层直接拒绝的命令 —— 与其让它在保存时炸，不如当场禁用按钮。
  bool get canSave {
    if (title.trim().isEmpty) return false;
    // 一个阶段都没添 = 单项任务，随便存。
    if (!recurrence.isValid) return false;
    if (_recurrenceEndsBeforeStart) return false;
    if (_taskEndsBeforeStart) return false;
    if (stages.isEmpty) return true;
    // 添了就得够两个（0 也行，那是把加出来的空行全删了）。
    final filled = filledStages.length;
    return filled == 0 || filled >= 2;
  }

  /// 重复的结束日期早于开始日期。
  ///
  /// **这条只有在这里判得了** —— [RecurrenceDraft] 不知道任务是哪天开始的。
  /// 日期选择器已经把下界卡在开始日期上了，但那只挡住「先定开始、再选结束」；
  /// 反过来先选结束再把开始日期往后挪，就绕过去了。
  /// 绕过去的结果是一条**一次都展不出来的规则**，而它长得完全正常。
  bool get _recurrenceEndsBeforeStart {
    final until = recurrence.until;
    final start = planDate;
    if (!recurrence.enabled ||
        recurrence.endMode != RecurrenceEndMode.until ||
        until == null ||
        start == null) {
      return false;
    }
    return until.isBefore(start);
  }

  /// 任务自身的结束早于开始。
  ///
  /// 与 [_recurrenceEndsBeforeStart] 是两件事：那个说的是「这条规则重复到
  /// 哪天为止」，这个说的是「这一次要做多久」。文案也要分开 ——
  /// 合成一句「结束早于开始」的话，用户不知道该去改哪一个。
  ///
  /// 先比日期，同一天才比分钟；缺失的结束时刻按当天最后一分钟算，
  /// 与 `Task._endsBeforeItStarts` 同一套规矩（那边是最后一道防线，
  /// 这边是当场就告诉用户）。
  bool get _taskEndsBeforeStart {
    final start = planDate;
    final end = endDate;
    if (start == null || end == null) return false;
    if (end.isBefore(start)) return true;
    if (end != start) return false;
    return (endMinute?.value ?? 1439) < (startMinute?.value ?? 0);
  }

  /// 为什么不能存 —— 给界面显示用。null 表示能存。
  String? get blockedReason {
    if (title.trim().isEmpty) return null; // 标题为空时按钮本来就灰着，不用再说
    if (stages.isNotEmpty && filledStages.length == 1) {
      return '阶段事项至少要两个阶段';
    }
    // 起止必填 —— **临时事项除外**（FR-TASK-01，2026-09-09 用户改的验收）。
    //
    // 「仅填标题即可保存」现在是临时事项那一档的性质，不再是所有单项的。
    // 只卡**新建**：库里已有起止为空的旧任务，编辑它们时再要求补齐，
    // 等于拿新规矩去堵一条本来合法的旧数据（用户明确说「只管新建」）。
    if (!isEditing && shape.needsSchedule) {
      if (planDate == null) return '要先选开始日期';
      if (endDate == null) return '要先选结束日期';
      if (!isAllDay && (startMinute == null || endMinute == null)) {
        return '要填开始与结束时刻，或者打开「全天」';
      }
    }
    if (_taskEndsBeforeStart) return '结束时间早于开始时间';
    if (_recurrenceEndsBeforeStart) return '重复的结束日期早于开始日期';
    return recurrence.blockedReason;
  }

  TaskDraft copyWith({
    TaskShape? shape,
    String? title,
    String? note,
    bool? isAllDay,
    Object? planDate = unset,
    Object? startMinute = unset,
    Object? endDate = unset,
    Object? endMinute = unset,
    Object? categoryId = unset,
    TaskPriority? priority,
    List<StageDraft>? stages,
    List<ChecklistDraft>? checklist,
    List<ReminderDraft>? reminders,
    bool? initialIsAllDay,
    RecurrenceDraft? recurrence,
  }) => TaskDraft(
    shape: shape ?? this.shape,
    editingTaskId: editingTaskId,
    splitAt: splitAt,
    unsupportedRecurrence: unsupportedRecurrence,
    title: title ?? this.title,
    note: note ?? this.note,
    isAllDay: isAllDay ?? this.isAllDay,
    // 日期与时刻都**要能被清掉**（「其实不用定在哪天」是常见操作），
    // 所以用 core/patch 的哨兵，不用 `?? this.x` —— 后者把 null
    // 解释成「不改」，于是清空这个功能实现不出来。
    //
    // 初版只给 startMinute 用了哨兵，planDate 漏了 —— 同一个坑
    // 在同一个类里补了两处、漏了第三处，是测试抓出来的。
    planDate: patch(planDate, this.planDate),
    startMinute: patch(startMinute, this.startMinute),
    endDate: patch(endDate, this.endDate),
    endMinute: patch(endMinute, this.endMinute),
    categoryId: patch(categoryId, this.categoryId),
    priority: priority ?? this.priority,
    stages: stages ?? this.stages,
    checklist: checklist ?? this.checklist,
    reminders: reminders ?? this.reminders,
    initialIsAllDay: initialIsAllDay ?? this.initialIsAllDay,
    recurrence: recurrence ?? this.recurrence,
  );
}

/// 从一条已有任务还原出草稿（编辑模式的初值）。
///
/// **重复规则可能还原不出来**：`RecurrenceDraft.fromRrule` 只认这个界面
/// 造得出来的那几种。认不出时把原串塞进 [TaskDraft.unsupportedRecurrence]
/// 原样带着 —— 显示成「不重复」再让用户一按保存把规则抹掉，
/// 是最糟的一种「什么都没做却坏了东西」。
TaskDraft draftFromTask(
  Task task,
  List<Stage> stages, {
  List<ChecklistItem> checklist = const [],
  List<Reminder> reminders = const [],
  OccurrenceKey? splitAt,
}) {
  final recurrence = task.recurrence;
  final restored = recurrence == null
      ? null
      : RecurrenceDraft.fromRrule(recurrence);

  return TaskDraft(
    // 从已有任务反推是哪一样。**不是双射**，理由见 `TaskShape.of` ——
    // 反推只看当前字段，不猜当初是怎么建的。
    shape: TaskShape.of(task),
    editingTaskId: task.id,
    splitAt: splitAt,
    unsupportedRecurrence: recurrence != null && restored == null
        ? recurrence.canonical
        : null,
    title: task.title,
    note: task.note ?? '',
    isAllDay: task.isAllDay,
    // 「本次及以后」时，新任务从**分割点那天**开始 —— 不是原任务的
    // 开始日期。写成后者的话，新规则会从很久以前重新展开一遍。
    planDate: splitAt?.date ?? task.planDate,
    startMinute: task.startMinute,
    endDate: task.endDate,
    endMinute: task.endMinute,
    categoryId: task.categoryId,
    priority: task.priority,
    stages: [
      for (final s in stages)
        StageDraft(
          id: s.id,
          title: s.title,
          startOffsetMinutes: s.startOffsetMinutes,
          durationMinutes: s.durationMinutes,
          status: s.status,
        ),
    ],
    reminders: [
      for (final r in reminders)
        // **只把界面表达得了的那些读进草稿**（见 [ReminderDraft]）。
        // 别的 kind 读进来会在保存时被整表替换掉 —— 那等于用户点开
        // 编辑页看一眼，导入进来的绝对提醒就没了。
        if (r.kind == ReminderKind.relativeToStart)
          ReminderDraft(
            id: r.id,
            offsetMinutes: r.offsetMinutes ?? 0,
            isEnabled: r.isEnabled,
          ),
    ],
    checklist: [
      for (final i in checklist)
        ChecklistDraft(id: i.id, title: i.title, isDone: i.isDone),
    ],
    recurrence: restored ?? const RecurrenceDraft(),
    initialIsAllDay: task.isAllDay,
  );
}

/// 正在编辑哪条任务。**null = 新建**。
///
/// 由组合根在编辑路由上用一层 `ProviderScope` 覆盖注入 ——
/// 编辑器自己不认识路由，参数从上面来（同外壳的 `onOpenSettings`）。
///
/// 为什么不用 `NotifierProvider.family`：那要靠 `ref.$arg` 取参数，
/// 是个带 `$` 前缀的内部 API。覆盖一个普通 Provider 只用公开接口，
/// 而且「作用域内这一份是哪条任务」读起来就是那个意思。
final editingTaskIdProvider = Provider<String?>((ref) => null);

/// 「本次及以后」的分割点；null = 改整条（FR-TASK-06）。
/// 同 [editingTaskIdProvider]，由组合根在路由上覆盖注入。
final editingSplitAtProvider = Provider<OccurrenceKey?>((ref) => null);

/// 新建表单的初值：在哪一天、哪一刻（FR-VIEW-07）。
///
/// 同上，由组合根在 `/task/new` 那条路由上按查询参数覆盖。
/// **走路由而不是构造参数**：视图只喊「在这儿新建」，
/// 由组合根决定那句话变成什么路由 —— 视图不认识路由表（§7.2）。
/// 顺带这条路由可以直接被外部唤起（将来的小组件、语音入口）。
final newTaskSeedProvider = Provider<NewTaskSeed?>((ref) => null);

/// 见 [newTaskSeedProvider]。两个分量都可缺。
typedef NewTaskSeed = ({PlanDate? date, MinuteOfDay? minute, TaskShape? shape});

/// 表单控制器。
final class TaskEditorController extends Notifier<TaskDraft> {
  /// 初值。**分类取配置里的默认**（settings-spec §2.4
  /// `behavior.defaultCategoryId`、§3「设为默认」）。
  ///
  /// 用 `read` 不用 `watch`：watch 的话，用户填到一半时分类表推来一帧
  /// 新数据，这个 Notifier 会重建 —— 填的东西全没了。
  /// 初值就该只在开表单那一刻取一次。
  ///
  /// `defaultCategoryIdProvider` 已经对着当前分类表校过了：
  /// 配置里指着一个被删掉的分类时回落成未分类，而不是造出一条
  /// 指向死分类的任务。
  /// 新建表单的初值，按选的那一样给。
  ///
  /// ## 时间怎么来
  ///
  /// | | 日期 | 起止时刻 |
  /// |---|---|---|
  /// | 临时事项 | **不给** | 不给 |
  /// | 其余四样 | 入口带的，否则今天 | 入口带的，否则**下一个整点** |
  ///
  /// 「下一个整点」是用户定的（2026-09-09）：新建时给一个当场就能用的
  /// 起点，比给「此刻 14:37」这种数好 —— 没有人把事情排在 14:37。
  /// 结束由配置项 `behavior.defaultDuration` 决定（默认 +24 小时）。
  TaskDraft _newDraft(TaskShape shape, NewTaskSeed? seed) {
    final categoryId = ref.read(defaultCategoryIdProvider);
    if (!shape.needsSchedule) {
      // 临时事项：不排时间，连日期都不给 —— 给了它就不是临时的了。
      return TaskDraft(shape: shape, categoryId: categoryId);
    }

    final today = ref.read(todayProvider);
    final date = seed?.date ?? today;
    final duration = settingOf(ref, defaultTaskDuration);

    // ## 只给了日期 = 那一天的**全天**任务
    //
    // 从日历翻到某天点加号，用户说的是「这一天」，不是「这一天的某点」。
    // 补一个时刻的话它会跑到时间轴最顶上去（FR-VIEW-07 的验收里
    // 专门有一条钉这个）。
    //
    // 反过来，面板上直接选「单事项」时没有任何日期语境 ——
    // 那时按用户定的规矩给**下一个整点**，因为单事项要求具体起止。
    final allDay = seed?.date != null && seed?.minute == null;
    if (allDay) {
      return TaskDraft(
        shape: shape,
        categoryId: categoryId,
        planDate: date,
        endDate: duration.endDateFrom(date),
        recurrence: _seedRecurrence(shape),
      );
    }

    // 入口带了时刻（时间轴/甘特上长按某一刻）就用它，否则下一个整点。
    final start = seed?.minute ?? _nextWholeHour();
    final end = duration.endFrom(DateAndMinute(date, start));

    return TaskDraft(
      shape: shape,
      categoryId: categoryId,
      planDate: date,
      isAllDay: false,
      startMinute: start,
      endDate: end.date,
      endMinute: end.minute,
      recurrence: _seedRecurrence(shape),
    );
  }

  /// 阶段形态**不预置空阶段**。
  ///
  /// 一度给了两个空的（想让「至少两个」这条要求在表单上自己说出来）。
  /// 代价比收益大：用户按「加一个阶段」时，新的一行加在那两个空行**后面**，
  /// 于是表单上是「两个空的 + 他填的那些」，而空的在保存时被丢掉 ——
  /// 界面上的顺序与存下去的顺序对不上。
  ///
  /// 阶段区本身已经由形态显示出来了（那是选「阶段事项」的可见结果），
  /// 「至少两个」由保存时的 `blockedReason` 说明。
  /// 重复形态开局就**打开**重复开关。
  ///
  /// 不打开的话，「重复单事项」存下去是一条不重复的任务 ——
  /// 用户在面板上说的那句话被丢掉了。默认「每天」是 `RecurrenceDraft`
  /// 自己的默认频率，这里只把开关拨到 on。
  RecurrenceDraft _seedRecurrence(TaskShape shape) => shape.isRecurring
      ? const RecurrenceDraft(enabled: true)
      : const RecurrenceDraft();

  /// 此刻之后的下一个整点。23 点之后是次日 00:00 —— 由 `shiftFrom` 处理，
  /// 这里只算分钟数，跨天交给调用方那次 `endFrom`。
  MinuteOfDay _nextWholeHour() {
    final resolver = ref.read(timeZoneResolverProvider);
    final now = resolver.toWallTime(
      ref.read(clockProvider).nowUtc(),
      resolver.currentZoneId(),
    );
    final hour = now.minuteOfDay.value ~/ 60;
    // 23:xx 的下一个整点是次日 00:00 —— 落回 0 点，日期那一半
    // 由结束时间的偏移去处理（开始留在今天是对的：用户还在今天）。
    return MinuteOfDay(hour >= 23 ? 0 : (hour + 1) * 60);
  }

  @override
  TaskDraft build() {
    final editingId = ref.read(editingTaskIdProvider);
    if (editingId == null) {
      final seed = ref.read(newTaskSeedProvider);
      // ## 没指定形态时按「临时事项」，不是「单事项」
      //
      // 界面上没有「不选」这条路（加号弹出的面板五选一），所以走到这里
      // 的只有**不带形态的直接唤起**：手敲 `/task/new`、将来的小组件、
      // 语音入口。
      //
      // 那时候正确的默认是**最不承诺的那一样**：临时事项什么都不必填，
      // 而单事项要求起止 —— 拿一个我们并不知道用户想要的日期去预填，
      // 再要求他必须填完才能存，是替他做了两次决定。
      // 「随手记一件事」本来就是这类入口最常见的意图。
      //
      // **但入口带了日期/时刻就不一样**：甘特上长按 14:00、日历翻到
      // 9/20 再点加号 —— 用户已经说出了「什么时候」，那就是一条单事项。
      // 一律当临时事项的话，那句话会被直接丢掉（FR-VIEW-07 的验收
      // 就是在说这件事）。
      final shape =
          seed?.shape ??
          (seed?.date != null || seed?.minute != null
              ? TaskShape.single
              : TaskShape.scratch);
      return _newDraft(shape, seed);
    }
    // **全程用 read，不用 watch。** watch 的话，库里任何一次推送
    // （别的任务变了、分类流来了一帧）都会重建 Notifier，
    // 把用户填到一半的东西冲掉。初值就该只在开表单那一刻取一次。
    final task = ref.read(taskByIdProvider(editingId));
    if (task == null) {
      // 取不到就退回一张新建表单。**不该发生** —— 编辑入口都是从
      // 列表里点出来的，那条任务必然在内存里。真发生了的话，
      // 页面那一层会先显示「这条任务不在了」，走不到这里。
      return const TaskDraft();
    }
    return draftFromTask(
      task,
      ref.read(stagesByTaskProvider)[task.id] ?? const [],
      checklist: ref.read(checklistByTaskProvider)[task.id] ?? const [],
      reminders: ref.read(remindersByTaskProvider)[task.id] ?? const [],
      splitAt: ref.read(editingSplitAtProvider),
    );
  }

  void setTitle(String value) => state = state.copyWith(title: value);

  void setNote(String value) => state = state.copyWith(note: value);

  void setPlanDate(PlanDate? date) => state = state.copyWith(planDate: date);

  /// 选分类。**传 null 即「未分类」**，不是「不改」。
  void setCategory(String? categoryId) =>
      state = state.copyWith(categoryId: categoryId);

  void setPriority(TaskPriority priority) =>
      state = state.copyWith(priority: priority);

  /// 本地墙钟的今天。由 [todayProvider] 统一给出，
  /// **不用 `DateTime.now()`**（cross-cutting §1）。
  PlanDate _today() => ref.read(todayProvider);

  /// 切全天。
  ///
  /// 关掉「全天」时**不自动塞一个时刻** —— 由 UI 让用户挑。
  /// 打开「全天」时必须**清掉**已选时刻，否则会存下一条
  /// 「全天但有 09:30」的任务，两个字段互相矛盾。
  ///
  /// 关掉「全天」时**必须有日期**：「12:32，但不知道哪天」不是一个有意义
  /// 的状态。真机上就撞见过一条这样的数据 —— 卡片上挂着一个指向不了任何
  /// 一天的时刻。没有日期时补上今天，而且**补得看得见**（日期栏会显示出来），
  /// 用户不同意可以当场改。
  ///
  /// 为什么不是「不让存」：那会把一个能自动答对的问题推给用户，
  /// 而 FR-TASK-01 的基调是「填得越少越好」。
  void setAllDay(bool value) => state = value
      // **两个时刻都要清**。只清 startMinute 的话会留下一条
      // 「全天但 18:00 结束」的任务 —— 领域不变量直接拒绝，
      // 而用户看到的只是保存时炸了一下。
      ? state.copyWith(isAllDay: true, startMinute: null, endMinute: null)
      : state.copyWith(isAllDay: false, planDate: state.planDate ?? _today());

  void setStartMinute(MinuteOfDay? minute) => state = minute == null
      ? state.copyWith(startMinute: null)
      : state.copyWith(
          startMinute: minute,
          isAllDay: false,
          planDate: state.planDate ?? _today(),
        );

  /// 选结束日期。传 null 即清空，**同时把结束时刻一起清掉** ——
  /// 留着的话就是「有几点、没有哪天」，与开始侧栽过的是同一个坑。
  void setEndDate(PlanDate? date) => state = date == null
      ? state.copyWith(endDate: null, endMinute: null)
      // 结束日期要求先有开始日期，没有就补今天（与关全天、开重复同理）。
      : state.copyWith(endDate: date, planDate: state.planDate ?? _today());

  /// 选结束时刻。
  ///
  /// 有时刻就必须有日期：没选过结束日期时**补上开始那天**，
  /// 而不是今天 —— 「今天 9 点开始，18 点结束」里的 18 点显然是同一天，
  /// 而任务的开始日期未必是今天。
  void setEndMinute(MinuteOfDay? minute) {
    if (minute == null) {
      state = state.copyWith(endMinute: null);
      return;
    }
    final start = state.planDate ?? _today();
    state = state.copyWith(
      endMinute: minute,
      isAllDay: false,
      planDate: start,
      endDate: state.endDate ?? start,
    );
  }

  void setRecurrence(RecurrenceDraft value) {
    // 打开重复时**没有日期就补今天** —— RRULE 的展开以 DTSTART 为锚点，
    // 没有起点就无从展开。与「关掉全天补今天」是同一条道理，
    // 而且补得看得见，用户不同意可以当场改。
    final needsDate = value.enabled && state.planDate == null;
    // **关掉重复时，把第一次发生的阶段进度搬回草稿**（FR-TASK-07）。
    //
    // 阶段状态有两个存储位置：不重复看 `Stage.status`，重复看那张表。
    // 关掉重复之后读路径改看前者，而草稿里那一份对重复任务恒为 pending
    // （界面上根本不给勾）—— 不搬的话，用户在这条任务上勾过的进度
    // **当场从界面上消失**，一保存就真的没了。
    //
    // **在草稿这一层搬，不在命令里搬。** 命令那条路走不通：一次保存里
    // `ReplaceStagesCommand` 排在后面，会把写好的状态原样盖掉
    // （`recurrence_conversion.dart` 里记着那次尝试）。
    // 搬进草稿反而更好 —— 勾选框当场就带着正确的状态出现，
    // 用户在保存**之前**就看见了。
    // 只在**从重复切到不重复**那一下搬，而且**整个编辑会话只搬一次**。
    //
    // 「只搬一次」是 task-lifecycle §4.2「**用户显式操作优先于推导**」
    // 在这个位置上的实例：搬过来之后用户手动取消了那一勾，
    // 再来一次转换不能把它改回去 —— §4.2 那句「破坏用户已记录的
    // 阶段进度比留下不一致更糟」说的就是这件事。
    //
    // **我一度把这条判断错了。** 变异演练里「一律搬」没变红，
    // 我把场景表述成「关掉→取消→再打开→再关掉，该不该重新搬」，
    // 觉得没有明显正确答案，于是删掉了自己写的那条测试，
    // 并在这里写「这是精确性不是正确性」。
    // 换个表述答案就有了：**再次转换能不能覆盖用户刚做出的取消**——
    // 而那条规格早就写过了，只是我没认出来。
    final leavingRecurring =
        state.isRecurring && !value.enabled && !_inheritedStagesOnce;
    state = state.copyWith(
      recurrence: value,
      planDate: needsDate ? _today() : state.planDate,
      stages: leavingRecurring ? _stagesFromFirstOccurrence() : null,
    );
    if (leavingRecurring) _inheritedStagesOnce = true;
  }

  /// 这次编辑里已经搬过一回进度了。见 [setRecurrence] 里那段。
  ///
  /// 放私有字段而不是放进 [TaskDraft]：它不是表单的内容，
  /// 是这次会话的簿记 —— 进了 draft 就会被 `copyWith` 到处传，
  /// 而且它对「保存下去是什么」毫无影响。
  bool _inheritedStagesOnce = false;

  /// 把第一次发生的阶段状态读进草稿的阶段行。
  ///
  /// **「第一次」不是随便挑的**：关掉重复之后这条任务只剩一次发生，
  /// 而那一次就是它自己的开始时刻 —— 与 `convertRecurrenceMode` 正方向
  /// 迁到「第一次」是同一个身份。
  List<StageDraft> _stagesFromFirstOccurrence() {
    final taskId = state.editingTaskId;
    final date = state.planDate;
    if (taskId == null || date == null) return state.stages;

    final key = OccurrenceKey.fromWallTime(
      LocalWallTime(
        date: date,
        minuteOfDay: state.startMinute ?? MinuteOfDay.midnight,
        timeZoneId: ref.read(timeZoneResolverProvider).currentZoneId(),
      ),
      isAllDay: state.isAllDay,
    );
    final states = ref.read(stageStatesByTaskProvider)[taskId]?[key];
    if (states == null) return state.stages;

    return [
      for (final s in state.stages)
        if (states[s.id] case final st?) s.copyWith(status: st.status) else s,
    ];
  }

  /// 加一个空阶段行。
  /// 加一条提醒（FR-NOTI-01）。
  ///
  /// 默认提前量取配置项 `reminder.defaultOffsetMinutes` ——
  /// 写死 15 分钟的话，那条配置就成了「设了没人读」。
  void addReminder() => state = state.copyWith(
    reminders: [
      ...state.reminders,
      ReminderDraft(
        id: ref.read(idGeneratorProvider).newId(),
        offsetMinutes: settingOf(ref, defaultReminderOffset),
      ),
    ],
  );

  void setReminderOffset(String id, int offsetMinutes) =>
      state = state.copyWith(
        reminders: [
          for (final r in state.reminders)
            if (r.id == id) r.copyWith(offsetMinutes: offsetMinutes) else r,
        ],
      );

  void setReminderEnabled(String id, bool isEnabled) => state = state.copyWith(
    reminders: [
      for (final r in state.reminders)
        if (r.id == id) r.copyWith(isEnabled: isEnabled) else r,
    ],
  );

  /// 删掉一条提醒。**整条移出草稿**，不是把它标成关掉 ——
  /// 「关掉」是另一个动作，用户可能只是这阵子不想被吵。
  void removeReminder(String id) => state = state.copyWith(
    reminders: [
      for (final r in state.reminders)
        if (r.id != id) r,
    ],
  );

  /// 加一条清单项（FR-TASK-09）。
  void addChecklistItem() => state = state.copyWith(
    checklist: [
      ...state.checklist,
      ChecklistDraft(id: ref.read(idGeneratorProvider).newId()),
    ],
  );

  void setChecklistTitle(String id, String title) => state = state.copyWith(
    checklist: [
      for (final i in state.checklist)
        if (i.id == id) i.copyWith(title: title) else i,
    ],
  );

  void setChecklistDone(String id, bool done) => state = state.copyWith(
    checklist: [
      for (final i in state.checklist)
        if (i.id == id) i.copyWith(isDone: done) else i,
    ],
  );

  void removeChecklistItem(String id) => state = state.copyWith(
    checklist: [
      for (final i in state.checklist)
        if (i.id != id) i,
    ],
  );

  void addStage() => state = state.copyWith(
    stages: [
      ...state.stages,
      StageDraft(id: ref.read(idGeneratorProvider).newId()),
    ],
  );

  /// 勾/取消勾一个阶段。
  ///
  /// **只改草稿，保存时才落库** —— 与标题、时间同一条路径。
  /// 就地写库的话，用户改了几个阶段又点返回，那几笔已经生效了。
  void setStageDone(String stageId, bool done) => state = state.copyWith(
    stages: [
      for (final s in state.stages)
        if (s.id == stageId)
          s.copyWith(status: done ? TaskStatus.done : TaskStatus.pending)
        else
          s,
    ],
  );

  void setStageTitle(String id, String title) => state = state.copyWith(
    stages: [
      for (final s in state.stages)
        if (s.id == id) s.copyWith(title: title) else s,
    ],
  );

  /// 设一个阶段的时间段（FR-TASK-02：每阶段有独立时间段）。
  ///
  /// 传的是**偏移**，不是绝对时刻 —— 界面负责把用户选的绝对时刻
  /// 折算成偏移（`stage_time.dart`），这一层只管存。
  /// 两个都传 null 就是「这个阶段不定时间」。
  ///
  /// 顺带**保证任务有开始日期**：偏移是相对任务开始算的，
  /// 没有起点的偏移指向不了任何时刻。与关全天、开重复同一条道理。
  void setStageTime(
    String id, {
    required int? startOffsetMinutes,
    required int? durationMinutes,
  }) {
    state = state.copyWith(
      planDate: startOffsetMinutes == null
          ? state.planDate
          : (state.planDate ?? _today()),
      stages: [
        for (final s in state.stages)
          if (s.id == id)
            s.copyWith(
              startOffsetMinutes: startOffsetMinutes,
              // 没有开始就不该留着时长 —— 那是一段悬空的长度。
              durationMinutes: startOffsetMinutes == null
                  ? null
                  : durationMinutes,
            )
          else
            s,
      ],
    );
    _rederiveSpanIfStaged();
  }

  /// 阶段事项的起止**由阶段推出**（用户 2026-09-10 定）。
  ///
  /// 每次阶段的时间变了就重推一遍，而不是等到保存 —— 编辑器上那一行
  /// 「由阶段决定：…」要当场跟着变，否则用户改完看不出改到了哪儿。
  ///
  /// 推导本身是纯函数（`derived_span.dart`），这里只负责**什么时候推**
  /// 与**推完写回哪儿**。它是幂等的，所以多推几次无害。
  ///
  /// **只对有阶段的形态推**：单事项挂着阶段是旧数据里才有的形状
  /// （早期版本没这条约束），对它们推等于拿新规矩改一条本来合法的旧数据。
  void _rederiveSpanIfStaged() {
    if (!state.shape.hasStages) return;
    final anchor = DateAndMinute(
      state.planDate ?? _today(),
      state.startMinute ?? MinuteOfDay(0),
    );
    final derived = deriveSpanFromStages(anchor, [
      for (final s in state.stages)
        (
          startOffsetMinutes: s.startOffsetMinutes,
          durationMinutes: s.durationMinutes,
        ),
    ]);
    // 推不出来（一个阶段都没填时间）就**保持原样** ——
    // 把起止清掉的话，用户填第一个阶段之前那条任务会先失去日期。
    if (derived == null) return;

    state = state.copyWith(
      // **推出来的起止带时刻，所以它一定不是全天的。**
      //
      // 不一起改的话，一条旧的「全天阶段任务」在填了阶段时间之后会变成
      // 「全天却带 startMinute」—— `checkInvariants` 当场拒，
      // 而用户看到的只是保存时炸了一下。
      // （R-52 那批用例撞出来的：它们原本靠「关掉全天」给阶段任务加时刻，
      // 而那条路现在没有了 —— 时刻只能从阶段来。）
      isAllDay: false,
      planDate: derived.start.date,
      startMinute: derived.start.minute,
      endDate: derived.end.date,
      endMinute: derived.end.minute,
      stages: [
        for (final (i, s) in state.stages.indexed)
          s.copyWith(
            startOffsetMinutes: derived.stages[i].startOffsetMinutes,
            durationMinutes: derived.stages[i].durationMinutes,
          ),
      ],
    );
  }

  void removeStage(String id) => state = state.copyWith(
    stages: [
      for (final s in state.stages)
        if (s.id != id) s,
    ],
  );

  /// 上移一个阶段。**顺序就是列表位置**，保存时才转成连续的 orderIndex。
  void moveStageUp(String id) {
    final list = [...state.stages];
    final i = list.indexWhere((s) => s.id == id);
    if (i <= 0) return;
    final tmp = list[i - 1];
    list[i - 1] = list[i];
    list[i] = tmp;
    state = state.copyWith(stages: list);
  }

  /// 拖拽重排（FR-TASK-02 验收里那句「可拖拽重排」）。
  ///
  /// [newIndex] 是**最终落点**，不需要再减一 —— 界面那侧用的是
  /// `onReorderItem`，它已经替调用方调过了。
  /// 老的 `onReorder` 给的是「移除之前的插入位置」（往下拖时大 1），
  /// 两者混用的表现是「往下拖一格没反应」，看着像手势没识别。
  void reorderStages(int oldIndex, int newIndex) {
    final list = [...state.stages];
    if (oldIndex < 0 || oldIndex >= list.length) return;
    if (newIndex == oldIndex) return;
    list.insert(newIndex.clamp(0, list.length - 1), list.removeAt(oldIndex));
    state = state.copyWith(stages: list);
  }

  void moveStageDown(String id) {
    final list = [...state.stages];
    final i = list.indexWhere((s) => s.id == id);
    if (i < 0 || i >= list.length - 1) return;
    final tmp = list[i + 1];
    list[i + 1] = list[i];
    list[i] = tmp;
    state = state.copyWith(stages: list);
  }

  /// 建任务命令的载荷。新建与「本次及以后」的新任务共用一份 ——
  /// 抄两遍的话，加一个字段总有一处会漏，而漏的那一半只在分裂时出现。
  CreateTaskCommand _createCommandFor(
    String id,
    TaskDraft draft,
    PlanDate? planDate,
    String timeZoneId, {
    String? splitFromTaskId,
  }) => CreateTaskCommand(
    taskId: id,
    title: draft.title.trim(),
    // 有两个及以上阶段就是阶段事项（FR-TASK-02）。
    kind: draft.isStaged ? TaskKind.staged : TaskKind.single,
    // 记**用户所在的时区**，不是 UTC（ADR-0005）：
    // 「每天 07:00 起床」飞到伦敦后仍应是当地 07:00。
    timeZoneId: timeZoneId,
    note: draft.note.trim().isEmpty ? null : draft.note.trim(),
    // null 即「未分类」（settings-spec §3.0）—— 库里没有那一行，
    // 所以这里原样传，不做任何「空则填默认分类」的转换。
    categoryId: draft.categoryId,
    priority: draft.priority,
    // 存**规范形**：拼出来的串不保证是规范形，而 data-model
    // 要求库里存的是规范形（否则同一条规则可能有两种写法，
    // 往返与同步都会分叉）。
    recurrenceRule: _canonicalRule(draft),
    isAllDay: draft.isAllDay,
    planDate: planDate,
    startMinute: draft.isAllDay ? null : draft.startMinute,
    // **兜底同样要做到结束侧**：全天不带时刻，没有结束日期
    // 就连结束时刻一起丢掉。少任何一条都会造出一个
    // 领域层直接拒绝的命令 —— 那时用户看到的只是保存炸了。
    endDate: draft.endDate,
    endMinute: draft.endDate == null || draft.isAllDay ? null : draft.endMinute,
    splitFromTaskId: splitFromTaskId,
  );

  /// 草稿里的阶段 → 命令载荷。
  ///
  /// **这里才把列表位置转成连续的 orderIndex。** 编辑期间用户增删拖拽，
  /// 序号一直是乱的；领域层要求从 0 起连续，所以在边界上一次转好。
  List<StageSpec> _stageSpecs(TaskDraft draft) => [
    for (final (i, s)
        in (draft.isStaged ? draft.filledStages : const <StageDraft>[]).indexed)
      StageSpec(
        id: s.id,
        title: s.title.trim(),
        orderIndex: i,
        startOffsetMinutes: s.startOffsetMinutes,
        durationMinutes: s.durationMinutes,
        status: s.status,
      ),
  ];

  /// 把阶段整表写回。
  ///
  /// **编辑时也要发**，而且草稿里没有阶段时要发一条空的 —— 用户把阶段
  /// 全删了，不发这条的话库里那些阶段原地不动，界面显示没有、库里还有。
  Future<void> _replaceStages(String taskId, TaskDraft draft) {
    if (!draft.isEditing && !draft.isStaged) {
      // 新建且没有阶段：连发都不用发。
      return Future<void>.value();
    }
    return ref
        .read(taskCommandDispatcherProvider)
        .dispatch(
          ReplaceStagesCommand(taskId: taskId, stages: _stageSpecs(draft)),
        );
  }

  /// 全天 ⇄ 定时的切换（R-27）。
  ///
  /// **形态变没变由 dispatcher 判，这里不判。**
  /// 一度在这儿加了一道 `if (!draft.allDayModeChanged) return`，
  /// 变异演练里去掉它测试全绿 —— 查下去发现它是**重复的判断**：
  /// dispatcher 里那道 `task.isAllDay == c.toAllDay` 已经挡住了，
  /// 而且它比这一道**更对**：它比的是库里当前的状态，
  /// 这一道比的是打开表单那一刻的快照。
  /// 两处判同一件事，迟早改了一处忘了另一处。
  ///
  /// （`draft.allDayModeChanged` 留着 —— 界面用它显示那句提示。）
  ///
  /// 时刻传 `draft.startMinute`，可能是 null —— 那时 dispatcher 回落到
  /// 00:00，与 `Task.startWallTime` 里那条 `?? midnight` 是同一条规则。
  Future<void> _convertAllDayMode(String taskId, TaskDraft draft) {
    return ref
        .read(taskCommandDispatcherProvider)
        .dispatch(
          ConvertTaskAllDayModeCommand(
            taskId: taskId,
            toAllDay: draft.isAllDay,
            startMinute: draft.isAllDay ? null : draft.startMinute,
          ),
        );
  }

  /// 把提醒整表写回（FR-NOTI-01）。
  ///
  /// 与清单同一个形状，包括「编辑时没有提醒也要发一条空的」——
  /// 不发的话，用户把提醒全删了，库里那些原地不动，
  /// 而排期照着库读 —— 表现是**删掉的提醒照样响**。
  Future<void> _replaceReminders(String taskId, TaskDraft draft) {
    if (!draft.isEditing && draft.reminders.isEmpty) {
      return Future<void>.value();
    }
    return ref
        .read(taskCommandDispatcherProvider)
        .dispatch(
          ReplaceRemindersCommand(
            taskId: taskId,
            reminders: [
              for (final r in draft.reminders)
                ReminderSpec(
                  id: r.id,
                  kind: ReminderKind.relativeToStart,
                  offsetMinutes: r.offsetMinutes,
                  isEnabled: r.isEnabled,
                ),
            ],
          ),
        );
  }

  /// 把清单整表写回（FR-TASK-09）。
  ///
  /// **编辑时也要发，而且没有项时要发一条空的** —— 与阶段同一个理由：
  /// 用户把清单全删了，不发这条的话库里那些原地不动，
  /// 界面显示没有、库里还有。
  Future<void> _replaceChecklist(String taskId, TaskDraft draft) {
    final items = draft.filledChecklist;
    if (!draft.isEditing && items.isEmpty) {
      return Future<void>.value();
    }
    return ref
        .read(taskCommandDispatcherProvider)
        .dispatch(
          ReplaceChecklistCommand(
            taskId: taskId,
            items: [
              for (final (i, item) in items.indexed)
                ChecklistItemSpec(
                  id: item.id,
                  title: item.title.trim(),
                  orderIndex: i,
                  isDone: item.isDone,
                ),
            ],
          ),
        );
  }

  /// 草稿里的重复规则 → 库里存的规范形串。
  ///
  /// **这个界面表达不了的规则原样带回去**：编辑一条
  /// `BYDAY=-1FR`（每月最后一个周五）的任务时，重复区是只读的，
  /// 草稿里那个 `RecurrenceDraft` 一直是「不重复」——
  /// 照它编码的话，用户改个标题就把规则抹掉了。
  String? _canonicalRule(TaskDraft draft) {
    final unsupported = draft.unsupportedRecurrence;
    if (unsupported != null) return unsupported;
    final raw = draft.recurrence.toRrule();
    return raw == null ? null : Recurrence.parse(raw).canonical;
  }

  /// 保存。返回新任务的 ID。
  ///
  /// 调用方应先看 [TaskDraft.canSave]；这里再挡一道，
  /// 因为「按钮禁用」是界面约定，不是不变量。
  Future<String> save() async {
    final draft = state;
    if (!draft.canSave) {
      throw StateError('标题为空，不能保存');
    }

    final resolver = ref.read(timeZoneResolverProvider);
    // 编辑时沿用原来的 ID，新建才生成。
    final id = draft.editingTaskId ?? ref.read(idGeneratorProvider).newId();

    // **不变量兜底**：非全天必须有日期。上面几个 setter 已经保证了，
    // 但那是界面路径的保证 —— 将来多一个入口（语音、导入、Agent）
    // 就多一条绕过去的路。这里是最后一道。
    final planDate = draft.isAllDay
        ? draft.planDate
        : (draft.planDate ?? _today());

    // 编辑走**改字段**，不是重新建一条。
    //
    // `isAllDay` 不在 `UpdateTaskFieldsCommand` 里，是**故意的**：
    // 全天 ⇄ 定时切换会改变 occurrenceKey 的形态，已有的例外要在
    // 同一事务里迁移 key（data-model §4.6、R-27）。那需要一条专门的
    // `ConvertTaskAllDayMode` 命令，roadmap 排在 M3。
    // 在那之前编辑模式里那个开关是禁用的 —— 让它能拨却存不下去，
    // 就是又一个「改了没反应」的开关。
    // 「本次及以后」：分裂（FR-TASK-06、data-model §4.4）。
    // **一条命令**，不是「改原任务」+「建新任务」两条 —— 回放时只应用
    // 前一条的话，用户的重复任务会在分割点静默终止。
    final splitAt = draft.splitAt;
    if (splitAt != null) {
      final newId = ref.read(idGeneratorProvider).newId();
      await ref
          .read(taskCommandDispatcherProvider)
          .dispatch(
            SplitRecurringTaskCommand(
              taskId: draft.editingTaskId!,
              splitAt: splitAt,
              newTask: _createCommandFor(
                newId,
                draft,
                planDate,
                resolver.currentZoneId(),
                splitFromTaskId: draft.editingTaskId,
              ),
              // 阶段随命令一起去 —— 「落到哪条任务上」由 dispatcher 判
              // （分割点是第一次时不分裂），这里不重复那个判断。
              stages: _stageSpecs(draft),
            ),
          );
      return newId;
    }

    if (draft.isEditing) {
      // **形态切换必须排在改字段之前**（R-27）。
      //
      // 两个理由，第二个是撞出来的：
      //
      //  1. 迁移 key 要按任务**当前**的形态去读旧例外。改字段先跑的话，
      //     任务已经是新形态，而例外还挂着旧 key。
      //  2. `UpdateTaskFieldsCommand` 会带上 `startMinute`，而库里那条
      //     还是全天 —— 于是 `checkInvariants` 当场抛
      //     「是全天任务却带 startMinute」。也就是说：**关掉「全天」、
      //     选个时刻、保存**，这条最普通不过的编辑会直接崩。
      //
      // 第 2 条是 R-52 的用例撞出来的。R-27 自己那批测试没覆盖它：
      // 它们要么只验开关能拨（没保存），要么直接发命令（没走编辑器
      // 这条「改形态 + 改字段」同时发生的路）。
      await _convertAllDayMode(id, draft);
      await ref
          .read(taskCommandDispatcherProvider)
          .dispatch(
            UpdateTaskFieldsCommand(
              taskId: id,
              title: draft.title.trim(),
              note: draft.note.trim().isEmpty ? null : draft.note.trim(),
              categoryId: draft.categoryId,
              priority: draft.priority,
              recurrenceRule: _canonicalRule(draft),
              planDate: planDate,
              startMinute: draft.isAllDay ? null : draft.startMinute,
              endDate: draft.endDate,
              endMinute: draft.endDate == null || draft.isAllDay
                  ? null
                  : draft.endMinute,
            ),
          );
      await _replaceStages(id, draft);
      await _replaceChecklist(id, draft);
      await _replaceReminders(id, draft);
      return id;
    }

    await ref
        .read(taskCommandDispatcherProvider)
        .dispatch(
          _createCommandFor(id, draft, planDate, resolver.currentZoneId()),
        );
    // 阶段是**第二条命令** —— 任务得先存在才能给它挂阶段。
    //
    // 两条命令而不是一条大的：命令要可重放（FR-AI-01），
    // 而「建任务」与「设阶段」本来就是两件可以分别发生的事
    // （改已有任务的阶段时只发后一条）。
    await _replaceStages(id, draft);
    await _replaceChecklist(id, draft);
    await _replaceReminders(id, draft);

    return id;
  }
}

/// **autoDispose 是必需的，不是优化**：不自动销毁的话，
/// 保存完再点「新建」，表单里还留着上一条的标题。
///
/// Riverpod 3 把 autoDispose 从 Notifier 基类挪到了 provider 上
/// （`AutoDisposeNotifier` 已删除）—— 类照常 extends [Notifier]。
/// **`dependencies` 是必需的，不是文档摆设。**
///
/// 编辑路由用一层 `ProviderScope` 覆盖 [editingTaskIdProvider]。
/// 不声明依赖的话，这个 provider 仍然在**根作用域**解析 —— 那里的
/// editingTaskId 永远是 null，于是编辑页打开的是一张新建表单，
/// 标题写着「新建任务」，改完还会多出一条任务。
/// 而且它不报错：一切照常运行，只是作用域没生效。
///
/// [newTaskSeedProvider] 后来也进了这张表，症状一模一样：
/// 长按 14:00 新建，表单打开、能保存，日期却是空的 ——
/// 覆盖写在了子作用域，而这个 provider 还在根作用域解析。
final taskEditorProvider =
    NotifierProvider.autoDispose<TaskEditorController, TaskDraft>(
      TaskEditorController.new,
      dependencies: [editingTaskIdProvider, newTaskSeedProvider],
    );

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
import '../../../core/time/minute_of_day.dart';
import '../../../core/time/plan_date.dart';
import '../../../domain/commands/task_command.dart';
import '../../../domain/entities/checklist_item.dart';
import '../../../domain/entities/stage.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/value_objects/occurrence_key.dart';
import '../../../domain/value_objects/recurrence.dart';
import '../../../domain/value_objects/task_status.dart';
import '../../views/shared/application/category_providers.dart';
import '../../views/shared/application/task_providers.dart';
import 'recurrence_draft.dart';

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
    this.recurrence = const RecurrenceDraft(),
    this.initialIsAllDay,
  });

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
    if (_taskEndsBeforeStart) return '结束时间早于开始时间';
    if (_recurrenceEndsBeforeStart) return '重复的结束日期早于开始日期';
    return recurrence.blockedReason;
  }

  TaskDraft copyWith({
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
    bool? initialIsAllDay,
    RecurrenceDraft? recurrence,
  }) => TaskDraft(
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
  OccurrenceKey? splitAt,
}) {
  final recurrence = task.recurrence;
  final restored = recurrence == null
      ? null
      : RecurrenceDraft.fromRrule(recurrence);

  return TaskDraft(
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
typedef NewTaskSeed = ({PlanDate? date, MinuteOfDay? minute});

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
  @override
  TaskDraft build() {
    final editingId = ref.read(editingTaskIdProvider);
    if (editingId == null) {
      final seed = ref.read(newTaskSeedProvider);
      return TaskDraft(
        categoryId: ref.read(defaultCategoryIdProvider),
        planDate: seed?.date,
        // 给了时刻就是一条定时任务；只给日期的仍是全天
        // （默认值 true）—— 从日历翻到某天点加号，用户表达的是
        // 「这一天」，不是「这一天的 00:00」。
        isAllDay: seed?.minute == null,
        startMinute: seed?.minute,
      );
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
    state = state.copyWith(
      recurrence: value,
      planDate: needsDate ? _today() : state.planDate,
    );
  }

  /// 加一个空阶段行。
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

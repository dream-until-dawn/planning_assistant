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
import '../../../domain/entities/task.dart';
import '../../../domain/value_objects/recurrence.dart';
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
final class StageDraft {
  const StageDraft({required this.id, this.title = ''});

  final String id;
  final String title;

  StageDraft copyWith({String? title}) =>
      StageDraft(id: id, title: title ?? this.title);
}

/// 编辑器里那张表单。
///
/// 与 [Task] 刻意**不是**同一个类型：表单里「标题还没填」是合法中间态，
/// 而领域实体不允许标题为空。把两者混成一个类型的话，
/// 要么实体的不变量被放宽，要么表单没法表达「填一半」。
final class TaskDraft {
  const TaskDraft({
    this.title = '',
    this.note = '',
    this.isAllDay = true,
    this.planDate,
    this.startMinute,
    this.endDate,
    this.endMinute,
    this.categoryId,
    this.stages = const [],
    this.recurrence = const RecurrenceDraft(),
  });

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

  /// 阶段。空 = 单项任务（FR-TASK-01）；≥2 = 阶段事项（FR-TASK-02）。
  ///
  /// **1 个是非法的**，领域层会拒绝 —— 一个只有一个阶段的阶段事项
  /// 与单项任务毫无区别。界面上由 [canSave] 挡住。
  final List<StageDraft> stages;

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
    List<StageDraft>? stages,
    RecurrenceDraft? recurrence,
  }) => TaskDraft(
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
    stages: stages ?? this.stages,
    recurrence: recurrence ?? this.recurrence,
  );
}

/// 表单控制器。
final class TaskEditorController extends Notifier<TaskDraft> {
  @override
  TaskDraft build() => const TaskDraft();

  void setTitle(String value) => state = state.copyWith(title: value);

  void setNote(String value) => state = state.copyWith(note: value);

  void setPlanDate(PlanDate? date) => state = state.copyWith(planDate: date);

  /// 选分类。**传 null 即「未分类」**，不是「不改」。
  void setCategory(String? categoryId) =>
      state = state.copyWith(categoryId: categoryId);

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
  void addStage() => state = state.copyWith(
    stages: [
      ...state.stages,
      StageDraft(id: ref.read(idGeneratorProvider).newId()),
    ],
  );

  void setStageTitle(String id, String title) => state = state.copyWith(
    stages: [
      for (final s in state.stages)
        if (s.id == id) s.copyWith(title: title) else s,
    ],
  );

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

  /// 草稿里的重复规则 → 库里存的规范形串。
  String? _canonicalRule(TaskDraft draft) {
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
    final id = ref.read(idGeneratorProvider).newId();

    // **不变量兜底**：非全天必须有日期。上面几个 setter 已经保证了，
    // 但那是界面路径的保证 —— 将来多一个入口（语音、导入、Agent）
    // 就多一条绕过去的路。这里是最后一道。
    final planDate = draft.isAllDay
        ? draft.planDate
        : (draft.planDate ?? _today());

    await ref
        .read(taskCommandDispatcherProvider)
        .dispatch(
          CreateTaskCommand(
            taskId: id,
            title: draft.title.trim(),
            // 有两个及以上阶段就是阶段事项（FR-TASK-02）。
            kind: draft.isStaged ? TaskKind.staged : TaskKind.single,
            // 记**用户所在的时区**，不是 UTC（ADR-0005）：
            // 「每天 07:00 起床」飞到伦敦后仍应是当地 07:00。
            timeZoneId: resolver.currentZoneId(),
            note: draft.note.trim().isEmpty ? null : draft.note.trim(),
            // null 即「未分类」（settings-spec §3.0）—— 库里没有那一行，
            // 所以这里原样传，不做任何「空则填默认分类」的转换。
            categoryId: draft.categoryId,
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
            endMinute: draft.endDate == null || draft.isAllDay
                ? null
                : draft.endMinute,
          ),
        );
    // 阶段是**第二条命令** —— 任务得先存在才能给它挂阶段。
    //
    // 两条命令而不是一条大的：命令要可重放（FR-AI-01），
    // 而「建任务」与「设阶段」本来就是两件可以分别发生的事
    // （改已有任务的阶段时只发后一条）。
    if (draft.isStaged) {
      final filled = draft.filledStages;
      await ref
          .read(taskCommandDispatcherProvider)
          .dispatch(
            ReplaceStagesCommand(
              taskId: id,
              stages: [
                // **这里才把列表位置转成连续的 orderIndex。**
                // 编辑期间用户增删拖拽，序号一直是乱的；
                // 领域层要求从 0 起连续，所以在边界上一次转好。
                for (final (i, s) in filled.indexed)
                  StageSpec(id: s.id, title: s.title.trim(), orderIndex: i),
              ],
            ),
          );
    }

    return id;
  }
}

/// **autoDispose 是必需的，不是优化**：不自动销毁的话，
/// 保存完再点「新建」，表单里还留着上一条的标题。
///
/// Riverpod 3 把 autoDispose 从 Notifier 基类挪到了 provider 上
/// （`AutoDisposeNotifier` 已删除）—— 类照常 extends [Notifier]。
final taskEditorProvider =
    NotifierProvider.autoDispose<TaskEditorController, TaskDraft>(
      TaskEditorController.new,
    );

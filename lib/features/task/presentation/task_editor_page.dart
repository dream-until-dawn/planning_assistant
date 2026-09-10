/// 新建任务（FR-TASK-01）。
///
/// **仅填标题即可保存** —— 这是验收标准，也是整个界面的组织原则：
/// 标题输入框自动聚焦，保存按钮就在拇指够得到的地方，其余全是可选的加法。
/// M2 验收还有一条「从点开 App 到任务落库 ≤ 3 次点击」：
/// 悬浮加号 → 打字 → 保存，正好三下。
///
/// 三种形态都在这里：单项（FR-TASK-01）、阶段（FR-TASK-02）、
/// 重复（FR-TASK-03/04）。后两者默认收着 —— 大多数任务是单项的，
/// 一进来摊开全部选项，是把少数情形的成本摊给所有人。
///
/// **单次例外与「本次及以后」（FR-TASK-05/06）还没做**：
/// 那需要写 `OccurrenceOverride`，而重复任务在列表里还没有展开成
/// 多次发生 —— 没有「某一次」可指的时候，「改某一次」无从谈起。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../core/time/minute_of_day.dart';
import '../../../core/time/plan_date.dart';
import '../../../core/time/weekday.dart';
import '../../../design/components/app_button.dart';
import '../../../design/components/app_chip.dart';
import '../../../design/components/undo_snackbar.dart';
import '../../../design/theme/app_theme.dart';
import '../../../design/tokens/dimensions.dart';
import '../../../domain/entities/task.dart';
import '../../archive/application/archive_providers.dart';
import '../../trash/application/trash_providers.dart';
import '../../views/shared/application/category_providers.dart';
import '../../views/shared/application/task_providers.dart';
import '../application/recurrence_draft.dart';
import '../application/stage_time.dart';
import '../application/task_editor_controller.dart';

class TaskEditorPage extends ConsumerStatefulWidget {
  const TaskEditorPage({
    this.onSaved,
    this.onDeleted,
    this.onArchived,
    super.key,
  });

  /// 保存成功后调用，参数是新任务的 ID。由组合根接上返回上一页。
  final void Function(String taskId)? onSaved;

  /// 删除之后调用。为 null 时不显示删除入口 ——
  /// 一个点了没反应的删除按钮比没有更糟。
  final VoidCallback? onDeleted;

  /// 归档之后调用。同上，为 null 时那个入口不出现。
  final VoidCallback? onArchived;

  static const Key titleFieldKey = ValueKey('editor-title');
  static const Key noteFieldKey = ValueKey('editor-note');
  static const Key saveButtonKey = ValueKey('editor-save');

  /// 删除（FR-TASK-08）。**只在编辑已有任务时出现** ——
  /// 新建页上删什么都没有。
  ///
  /// 这个入口是补出来的：`DeleteTaskCommand` 在领域层一直都在、也测过，
  /// 而界面上**没有任何地方能删一条任务**。
  static const Key deleteButtonKey = ValueKey('editor-delete');

  /// 归档（FR-TASK-08 的另一半）。同样只在编辑已有任务时出现。
  ///
  /// 与删除并排放：两者都是「从列表里拿走」，用户在做决定时
  /// 正需要看见另一个选项 —— 只给删除的话，想留着的人只能删。
  static const Key archiveButtonKey = ValueKey('editor-archive');
  static const Key allDaySwitchKey = ValueKey('editor-all-day');
  static const Key dateFieldKey = ValueKey('editor-date');
  static const Key timeFieldKey = ValueKey('editor-time');

  /// 结束侧（FR-TASK-01 的「可选计划时间段」）。
  ///
  /// 收在一个开关后面：绝大多数任务只有一个「哪天」，没有跨度，
  /// 默认摊开两行日期两行时刻是把少数情形的成本摊给所有人。
  static const Key endSwitchKey = ValueKey('editor-has-end');
  static const Key endDateFieldKey = ValueKey('editor-end-date');
  static const Key endTimeFieldKey = ValueKey('editor-end-time');

  /// 分类选择区。每个选项的 Key 见 [categoryChipKey]。
  static const Key categoryPickerKey = ValueKey('editor-category');

  /// 优先级选择区。每个选项的 Key 见 [priorityChipKey]。
  ///
  /// **这一区是补出来的。** `priority` 在模型、命令、筛选里都有，
  /// 唯独界面上没有 —— 于是所有任务恒为「普通」，
  /// 而筛选条那一维筛出来的永远只有那一档。
  /// 又是一次「模型上有旋钮，界面上够不着」（testing-strategy §1.6）。
  static const Key priorityPickerKey = ValueKey('editor-priority');

  /// 阶段区。
  static const Key stageSectionKey = ValueKey('editor-stages');
  static const Key addStageKey = ValueKey('editor-add-stage');

  /// 清单区（FR-TASK-09）。
  static const Key reminderSectionKey = ValueKey('editor-reminders');
  static const Key addReminderKey = ValueKey('editor-add-reminder');
  static Key reminderOffsetKey(String id) => ValueKey('editor-reminder-$id');
  static Key reminderRemoveKey(String id) =>
      ValueKey('editor-reminder-remove-$id');
  static Key reminderEnabledKey(String id) =>
      ValueKey('editor-reminder-enabled-$id');

  static const Key checklistSectionKey = ValueKey('editor-checklist');
  static const Key addChecklistKey = ValueKey('editor-add-checklist');

  static Key checklistFieldKey(String id) => ValueKey('editor-check-$id');
  static Key checklistDoneKey(String id) => ValueKey('editor-check-done-$id');
  static Key checklistRemoveKey(String id) => ValueKey('editor-check-del-$id');

  /// 「为什么不能存」那句提示。
  static const Key blockedReasonKey = ValueKey('editor-blocked');

  /// 重复区。
  static const Key recurrenceSwitchKey = ValueKey('editor-repeat');

  /// 规则这个界面表达不了时的那一行只读说明。
  static const Key unsupportedRecurrenceKey = ValueKey(
    'editor-repeat-readonly',
  );
  static const Key recurrenceSummaryKey = ValueKey('editor-repeat-summary');

  static Key frequencyKey(RecurrenceFrequency f) =>
      ValueKey('editor-repeat-freq-${f.name}');
  static Key weekdayKey(Weekday d) => ValueKey('editor-repeat-day-${d.name}');
  static Key endModeKey(RecurrenceEndMode m) =>
      ValueKey('editor-repeat-end-${m.name}');

  /// 「每月」那三个档位与它们各自的输入（FR-TASK-03 的
  /// 「每月 15 号」「每月最后一个周五」）。
  static Key monthlyModeKey(MonthlyMode m) =>
      ValueKey('editor-repeat-monthly-${m.name}');
  static Key monthOrdinalKey(int ordinal) =>
      ValueKey('editor-repeat-ordinal-$ordinal');

  /// **与 [weekdayKey] 分开。** 两处选的不是一件事（一个是集合、一个是单选），
  /// 共用 Key 的话测试里「点周二」会指向两个不同的语义。
  static Key monthWeekdayKey(Weekday d) =>
      ValueKey('editor-repeat-monthday-${d.name}');
  static const Key lastDayOfMonthKey = ValueKey('editor-repeat-lastday');

  /// 「29/30/31 号的月份会跳过」那句提醒。
  static const Key monthSkipHintKey = ValueKey('editor-repeat-skip-hint');
  static const String monthDayStepper = 'editor-repeat-monthday';

  /// 间隔（每 N 天/周/…）与次数的加减器，以及「到某天为止」的日期。
  ///
  /// 这三个一度**只存在于模型里，界面上够不着** —— `interval` 恒为 1、
  /// `count` 恒为默认值 10，而 `until` 永远是 null，
  /// 于是选了「到某天为止」就再也存不下去。见 §重复区的注释。
  static const String intervalStepper = 'editor-repeat-interval';
  static const String countStepper = 'editor-repeat-count';
  static const Key untilFieldKey = ValueKey('editor-repeat-until');

  /// 加减器上的三个部件。[name] 取 [intervalStepper] / [countStepper]。
  static Key stepperValueKey(String name) => ValueKey(name);
  static Key stepperDecKey(String name) => ValueKey('$name-dec');
  static Key stepperIncKey(String name) => ValueKey('$name-inc');

  static Key stageFieldKey(String stageId) => ValueKey('editor-stage-$stageId');
  static Key stageRemoveKey(String stageId) =>
      ValueKey('editor-stage-remove-$stageId');
  static Key stageUpKey(String stageId) => ValueKey('editor-stage-up-$stageId');

  /// 拖拽把手（FR-TASK-02「可拖拽重排」）。
  static Key stageDragKey(String stageId) =>
      ValueKey('editor-stage-drag-$stageId');

  /// 阶段的完成勾选。
  ///
  /// **这个也是补出来的。** `Stage.status` 与 `StageSpec.status` 一直都在，
  /// 甘特图还按它画进度 —— 而界面上**没有任何地方能勾**。
  /// 与优先级是同一族（testing-strategy §1.6）。
  static Key stageDoneKey(String stageId) =>
      ValueKey('editor-stage-done-$stageId');

  /// 某个阶段的时间段按钮（FR-TASK-02：每阶段有独立时间段）。
  static Key stageTimeKey(String stageId) =>
      ValueKey('editor-stage-time-$stageId');

  /// 阶段时间对话框里的四个选择器与两个按钮。
  static const Key stageTimeStartDateKey = ValueKey('stage-time-start-date');
  static const Key stageTimeStartTimeKey = ValueKey('stage-time-start-time');
  static const Key stageTimeEndDateKey = ValueKey('stage-time-end-date');
  static const Key stageTimeEndTimeKey = ValueKey('stage-time-end-time');
  static const Key stageTimeConfirmKey = ValueKey('stage-time-confirm');
  static const Key stageTimeClearKey = ValueKey('stage-time-clear');

  /// 某个分类选项的 Key。`null` 是「未分类」那一项。
  static Key priorityChipKey(TaskPriority p) =>
      ValueKey('editor-priority-${p.name}');

  static Key categoryChipKey(String? categoryId) =>
      ValueKey('editor-category-${categoryId ?? 'none'}');

  @override
  ConsumerState<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends ConsumerState<TaskEditorPage> {
  /// 保存中。**用它挡住重复提交** —— 连点两下保存会建出两条任务，
  /// 而命令自带 ID 只保证同一条命令重放幂等，不保证两条不同命令去重。
  bool _saving = false;

  /// 标题与备注的控制器。
  ///
  /// **编辑模式必须有**：`TextField` 不带 controller 时永远从空串开始，
  /// 于是打开一条已有任务，标题栏是空的 —— 看起来像内容全丢了。
  ///
  /// 在 `initState` 里**取一次**草稿来填初值，之后不再跟着草稿走：
  /// 每帧回填的话，光标会在用户打字时被弹回开头。
  late final TextEditingController _title;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(taskEditorProvider);
    _title = TextEditingController(text: draft.title);
    _note = TextEditingController(text: draft.note);
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final id = await ref.read(taskEditorProvider.notifier).save();
      widget.onSaved?.call(id);
    } finally {
      // 页面可能已经被 onSaved 弹掉了，setState 会抛。
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 删掉这条任务（FR-TASK-08）。
  ///
  /// **软删除 + 一条撤销** —— 删除是最需要反悔的操作，
  /// 而「再点一次删除」不是撤销。撤销闭包由动作本身给出
  /// （同列表那几个滑动动作），界面层不自己算怎么恢复。
  ///
  /// 不弹「确定要删吗」的二次确认：有撤销就不需要拦一道，
  /// 拦一道反而让日常操作多一次点击。
  Future<void> _delete(TaskDraft draft) async {
    final id = draft.editingTaskId;
    if (id == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final undo = await ref.read(trashActionsProvider).delete(id);
    widget.onDeleted?.call();
    showUndoSnackBar(messenger, '已移到回收站', onUndo: undo);
  }

  /// 归档这条任务（FR-TASK-08）。
  ///
  /// 与删除同一个做法：动作给撤销闭包，界面不自己算怎么还原 ——
  /// 取消归档要把归档前的 `status` 还原回来，而那个快照只有领域层知道。
  Future<void> _archive(TaskDraft draft) async {
    final id = draft.editingTaskId;
    if (id == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final undo = await ref.read(archiveActionsProvider).archive(id);
    widget.onArchived?.call();
    showUndoSnackBar(messenger, '已归档', onUndo: undo);
  }

  /// 「今天」经时钟 + 时区换算器拿，**不用 `DateTime.now()`**。
  ///
  /// 分层守卫只扫 domain 与 feature application，presentation 不在射程内，
  /// 所以这里写 `DateTime.now()` 不会变红 —— 但 cross-cutting §1 那条
  /// 禁令针对的是「业务代码」，日期选择器默认落在哪天正是业务。
  /// 更实际的理由：直接用系统时钟的话，「默认日期是今天」这件事没法测。
  PlanDate _today() {
    final resolver = ref.read(timeZoneResolverProvider);
    return resolver
        .toWallTime(ref.read(clockProvider).nowUtc(), resolver.currentZoneId())
        .date;
  }

  @override
  Widget build(BuildContext context) {
    // **必须先等清单流吐一次值，再让控制器建草稿。**
    //
    // 控制器的 `build()` 用 `read` 取初值（那是对的 —— 用 `watch`
    // 的话，库里任何一次推送都会把用户填到一半的东西冲掉）。
    // 而 `read` 一个还没人订阅过的 `StreamProvider` 拿到的是
    // AsyncLoading，回落是**空清单** —— 于是编辑一条有清单的任务，
    // 清单区是空的，一保存就把它整表清掉了。
    //
    // 阶段没这个毛病纯属**巧合**：列表上的卡片要算进度，
    // 一直 watch 着 `allStagesProvider`，进编辑器时它早就热了。
    // 清单不上任何视图（FR-TASK-09），没人替它保温。
    //
    // 本地库首帧通常一帧内就来，所以这里不转圈，与回收站同一个做法。
    if (ref.watch(allChecklistItemsProvider).isLoading) {
      return const SizedBox.shrink();
    }

    final draft = ref.watch(taskEditorProvider);
    final controller = ref.read(taskEditorProvider.notifier);
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(draft.isEditing ? '编辑任务' : '新建任务'),
        actions: [
          if (draft.isEditing && widget.onArchived != null)
            IconButton(
              key: TaskEditorPage.archiveButtonKey,
              icon: const Icon(Icons.inventory_2_outlined),
              tooltip: '归档',
              onPressed: () => _archive(draft),
            ),
          if (draft.isEditing && widget.onDeleted != null)
            IconButton(
              key: TaskEditorPage.deleteButtonKey,
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除',
              onPressed: () => _delete(draft),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.pageHorizontal),
          children: [
            TextField(
              key: TaskEditorPage.titleFieldKey,
              controller: _title,
              // 一进来就能打字，省掉一次点击（≤3 次点击那条验收）。
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '要做什么',
                hintText: '比如：买菜',
              ),
              onChanged: controller.setTitle,
            ),
            const SizedBox(height: Spacing.xl),
            TextField(
              key: TaskEditorPage.noteFieldKey,
              controller: _note,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(labelText: '备注（可选）'),
              onChanged: controller.setNote,
            ),
            const SizedBox(height: Spacing.xl),
            _CategoryPicker(
              selectedId: draft.categoryId,
              onSelected: controller.setCategory,
            ),
            const SizedBox(height: Spacing.xl),
            _PriorityPicker(
              selected: draft.priority,
              onSelected: controller.setPriority,
            ),
            const SizedBox(height: Spacing.xl),
            // ── 时间区 ──────────────────────────────────────────
            //
            // **按形态收起**（用户 2026-09-10 定）：阶段事项的起止由阶段
            // 推出、临时事项压根不排时间 —— 两者都不该出现这几个控件。
            // 填了也会被推导盖掉，而一个填了没用的输入框比没有更糟。
            //
            // **但「当前有数据」时照样显示。** 旧数据里有形态与内容对不上
            // 的行（早期版本没有这些约束），藏起来的话它们在界面上就再也
            // 够不着了 —— 这条逃生口原本写在阶段区那儿，现在是全表通用的
            // 判据（见 `_showsSpanFields`）。
            // 阶段事项那一行**独立于输入控件**：控件藏了，这一行才更要在 ——
            // 它同时回答了「起止是多少」和「日期栏为什么不见了」。
            if (draft.shape.spanDerivedFromStages)
              _DerivedSpanLine(draft: draft),
            if (_showsSpanFields(draft)) ...[
              _DateRow(
                key: TaskEditorPage.dateFieldKey,
                date: draft.planDate,
                today: _today(),
                // 非全天时**不许清空日期**：清了就又回到「有时刻没哪天」。
                // save() 那道兜底会把它补回来，但表单上不该出现那个瞬间 ——
                // 用户看到的是「日期空着也能存」，而存下去却有日期。
                clearable: draft.isAllDay,
                onPick: controller.setPlanDate,
              ),
              SwitchListTile(
                key: TaskEditorPage.allDaySwitchKey,
                contentPadding: EdgeInsets.zero,
                title: const Text('全天'),
                // **编辑时一度是禁用的**：全天 ⇄ 定时会改变 occurrenceKey
                // 的形态，已有的单次例外要在同一事务里迁移 key
                // （data-model §4.6、R-27）。没有那条命令之前，
                // 让它能拨却存不下去就是又一个「改了没反应」的开关。
                // `ConvertTaskAllDayModeCommand` 做出来了，于是放开。
                subtitle: draft.allDayModeChanged
                    ? Text('保存时会把这条任务的单次例外一并迁移', style: text.bodySmall)
                    : null,
                value: draft.isAllDay,
                onChanged: controller.setAllDay,
              ),
              if (!draft.isAllDay)
                _TimeRow(
                  key: TaskEditorPage.timeFieldKey,
                  minute: draft.startMinute,
                  onPick: controller.setStartMinute,
                ),
              SwitchListTile(
                key: TaskEditorPage.endSwitchKey,
                contentPadding: EdgeInsets.zero,
                title: const Text('有结束时间'),
                subtitle: Text(
                  draft.endDate == null ? '不设结束' : '到 ${_endText(draft)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                value: draft.endDate != null,
                // 打开时**先给一个看得见的默认**（与开始同一天），
                // 而不是打开后留一行「选个日期」等着用户再点一次。
                onChanged: (on) => controller.setEndDate(
                  on ? (draft.planDate ?? _today()) : null,
                ),
              ),
              if (draft.endDate != null) ...[
                _DateRow(
                  key: TaskEditorPage.endDateFieldKey,
                  date: draft.endDate,
                  today: _today(),
                  // 结束日期不在这里清 —— 关上面那个开关才是「不设结束」。
                  // 留一个清除按钮的话，清完还剩一个「有结束时间」开着的
                  // 空行，那是个没有意义的中间态。
                  clearable: false,
                  label: '结束日期',
                  // 结束不能早于开始。选择器就把下界卡在这儿，
                  // 顺手挡掉一半的错法；另一半（先选结束再改开始）
                  // 由 `TaskDraft.blockedReason` 兜。
                  firstDate: draft.planDate,
                  onPick: controller.setEndDate,
                ),
                if (!draft.isAllDay)
                  _TimeRow(
                    key: TaskEditorPage.endTimeFieldKey,
                    minute: draft.endMinute,
                    label: '结束时间',
                    onPick: controller.setEndMinute,
                  ),
              ],
            ],
            // ## 按形态显示区块（FR-TASK-01/02/03）
            //
            // 新建时用户已经在面板上选过了「是哪一样」，表单再把
            // 五样的全部控件都摆出来，那次选择就白选了 ——
            // 建一条临时事项时不必看见重复规则，建单事项时不必看见阶段。
            //
            // **认不出来的重复规则要例外**（`unsupportedRecurrence`）：
            // 那时形态反推成「不重复」，而任务身上确实挂着一条规则。
            // 不显示的话，用户打开它、保存，规则就被悄悄抹掉了 ——
            // 那正是 `unsupportedRecurrence` 这个字段当初存在的理由。
            //
            // **只在新建时收窄。** 编辑一条已有任务时两个区块都留着 ——
            // 「给这条任务加上重复」「把它拆成几个阶段」是正当的编辑，
            // 而按形态藏起来的话那两条路就断了（形态是从当前字段
            // 反推的，`TaskShape.of` 只看它现在是什么样）。
            if (draft.isEditing ||
                draft.shape.isRecurring ||
                draft.unsupportedRecurrence != null) ...[
              const SizedBox(height: Spacing.xl),
              _RecurrenceSection(
                draft: draft.recurrence,
                unsupported: draft.unsupportedRecurrence,
                // 打开重复时控制器会补上日期，所以这里几乎总是非空；
                // 兜底用今天，与 `setRecurrence` 补的是同一天。
                anchor: draft.planDate ?? _today(),
                controller: controller,
              ),
            ],
            // 阶段区同理。**已有阶段时也显示** —— 旧数据里可能有
            // 「单项任务却挂着阶段」的行（早期版本没有这条约束），
            // 藏起来的话那些阶段在界面上就再也够不着了。
            if (draft.isEditing ||
                draft.shape.hasStages ||
                draft.stages.isNotEmpty) ...[
              const SizedBox(height: Spacing.xl),
              _StageSection(
                draft: draft,
                today: _today(),
                controller: controller,
              ),
            ],
            // 提醒排在清单之前：它跟时间有关，紧接着上面那几段时间设置；
            // 清单是「顺手记几件小事」，与时间无关，放最后。
            // 临时事项不排时间，所以提醒也无从谈起 —— 编辑器里那句话
            // 本来就写着「没有日期的任务不会提醒」。留一个设了不会响的区，
            // 正是这个项目一直在防的「点了没反应」。
            // 同上：**已经设过提醒时照样显示**，否则那些提醒够不着了。
            if (draft.shape.canRemind || draft.reminders.isNotEmpty) ...[
              const SizedBox(height: Spacing.xl),
              _ReminderSection(draft: draft, controller: controller),
            ],
            const SizedBox(height: Spacing.xl),
            _ChecklistSection(draft: draft, controller: controller),
            const SizedBox(height: Spacing.xxxl),
          ],
        ),
      ),
      // **保存固定在底部，不跟着表单滚。**
      //
      // 一度放在表单末尾。加上重复与阶段两区之后表单超过一屏，
      // 按钮被埋进滚动区外 —— `ListView` 甚至不会构建它
      // （测试里表现为「找不到 editor-save」）。
      //
      // 更要紧的是 M2 那条「≤3 次点击落库」：主操作要先滚动才够得着，
      // 那条验收就不成立了。
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.pageHorizontal),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (draft.blockedReason != null) ...[
                Text(
                  draft.blockedReason!,
                  key: TaskEditorPage.blockedReasonKey,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.dangerText),
                ),
                const SizedBox(height: Spacing.sm),
              ],
              AppButton(
                key: TaskEditorPage.saveButtonKey,
                label: _saving ? '保存中…' : '保存',
                expand: true,
                // 标题为空时禁用，而不是让用户点了再弹错 ——
                // 「能不能存」是当场看得见的事，不该等到点下去才说。
                onPressed: draft.canSave && !_saving ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 阶段偏移的锚点：任务的开始。
///
/// 没有日期时用一个占位日 —— `setStageTime` 会把今天补进草稿，
/// 所以用户一旦真的设了时间，显示的和存下去的就是同一天。
DateAndMinute _stageAnchor(TaskDraft draft, PlanDate today) => DateAndMinute(
  draft.planDate ?? today,
  draft.startMinute ?? MinuteOfDay.midnight,
);

/// 「几点」。
String _hhmm(MinuteOfDay m) =>
    '${(m.value ~/ 60).toString().padLeft(2, '0')}:'
    '${(m.value % 60).toString().padLeft(2, '0')}';

/// 「哪天几点」。全天任务只说到哪天。
String _formatMoment(DateAndMinute m, {required bool withTime}) =>
    withTime ? '${m.date} ${_hhmm(m.minute)}' : '${m.date}';

/// 一个阶段的时间段按钮（FR-TASK-02：每阶段有独立时间段）。
///
/// **显示绝对时刻，存相对偏移**（data-model §4.1）——
/// 「+90 分钟」谁也读不出是哪天几点；而绝对日期在重复的阶段事项上
/// 根本写不出来（该写哪一周的？）。换算在 `stage_time.dart`。
class _StageTimeButton extends StatelessWidget {
  const _StageTimeButton({
    required this.stage,
    required this.anchor,
    required this.isAllDay,
    required this.onChanged,
  });

  final StageDraft stage;

  /// 任务开始 —— 偏移相对它算。
  final DateAndMinute anchor;

  final bool isAllDay;

  /// `(开始偏移, 时长)`，两个都为 null 即清空。
  final void Function(int?, int?) onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final offset = stage.startOffsetMinutes;

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: TaskEditorPage.stageTimeKey(stage.id),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
          // 可点即需 48dp（design-system §5）。
          minimumSize: const Size(0, Spacing.minTouchTarget),
        ),
        icon: const Icon(Icons.schedule_outlined, size: TypeScale.captionSize),
        label: Text(
          offset == null ? '加时间' : _rangeLabel(offset, stage.durationMinutes),
          style: text.bodySmall,
        ),
        onPressed: () async {
          final result = await showDialog<_StageTimeResult>(
            context: context,
            builder: (_) => _StageTimeDialog(
              anchor: anchor,
              isAllDay: isAllDay,
              startOffsetMinutes: offset,
              durationMinutes: stage.durationMinutes,
            ),
          );
          if (result != null) onChanged(result.startOffset, result.duration);
        },
      ),
    );
  }

  String _rangeLabel(int offset, int? duration) {
    final start = shiftFrom(anchor, offset);
    final startText = _formatMoment(start, withTime: !isAllDay);
    if (duration == null) return startText;
    final end = shiftFrom(anchor, offset + duration);
    // 同一天就不重复写日期 ——「2026-09-08 09:00 — 2026-09-08 10:30」
    // 里有一半是噪声，而按钮只有一行。
    final endText = (end.date == start.date && !isAllDay)
        ? _hhmm(end.minute)
        : _formatMoment(end, withTime: !isAllDay);
    return '$startText — $endText';
  }
}

/// 对话框返回的东西。
///
/// `null`（没返回）与 `_StageTimeResult(null, null)` 是两回事：
/// 前者是「取消」，后者是「清掉这个阶段的时间」。
/// 用同一个值表示会让「不定时间」变成一个按不动的按钮。
@immutable
class _StageTimeResult {
  const _StageTimeResult(this.startOffset, this.duration);
  final int? startOffset;
  final int? duration;
}

/// 选一个阶段的开始与结束。
class _StageTimeDialog extends StatefulWidget {
  const _StageTimeDialog({
    required this.anchor,
    required this.isAllDay,
    required this.startOffsetMinutes,
    required this.durationMinutes,
  });

  final DateAndMinute anchor;
  final bool isAllDay;
  final int? startOffsetMinutes;
  final int? durationMinutes;

  @override
  State<_StageTimeDialog> createState() => _StageTimeDialogState();
}

class _StageTimeDialogState extends State<_StageTimeDialog> {
  late DateAndMinute _start;
  late DateAndMinute _end;

  @override
  void initState() {
    super.initState();
    // 没设过就从任务开始那一刻起、默认一小时 —— 给一个能直接「确定」的
    // 完整值，而不是让用户对着四个空栏位从头填。
    final offset = widget.startOffsetMinutes ?? 0;
    _start = shiftFrom(widget.anchor, offset);
    _end = shiftFrom(widget.anchor, offset + (widget.durationMinutes ?? 60));
  }

  /// 结束早于开始、或阶段早于任务开始，都不给确定。
  ///
  /// **当场挡住**，而不是让它算出一个负数存下去：负时长在甘特图上
  /// 是一根往回长的条，负偏移则让阶段跑到任务前面 —— 两者都能落库，
  /// 而且落库之后没有任何界面会提示不对。
  String? get _blockedReason {
    if (offsetFrom(widget.anchor, _start) < 0) return '阶段不能早于任务开始';
    if (offsetFrom(_start, _end) < 0) return '结束不能早于开始';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final blocked = _blockedReason;

    return AlertDialog(
      title: const Text('这个阶段的时间'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '任务从 '
            '${_formatMoment(widget.anchor, withTime: !widget.isAllDay)} 开始',
            style: text.bodySmall,
          ),
          const SizedBox(height: Spacing.sm),
          _MomentRow(
            dateKey: TaskEditorPage.stageTimeStartDateKey,
            timeKey: TaskEditorPage.stageTimeStartTimeKey,
            label: '开始',
            moment: _start,
            withTime: !widget.isAllDay,
            onChanged: (m) => setState(() => _start = m),
          ),
          _MomentRow(
            dateKey: TaskEditorPage.stageTimeEndDateKey,
            timeKey: TaskEditorPage.stageTimeEndTimeKey,
            label: '结束',
            moment: _end,
            withTime: !widget.isAllDay,
            onChanged: (m) => setState(() => _end = m),
          ),
          if (blocked != null)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.xs),
              child: Text(
                blocked,
                style: text.bodySmall?.copyWith(
                  color: context.appColors.dangerText,
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          key: TaskEditorPage.stageTimeClearKey,
          onPressed: () =>
              Navigator.of(context).pop(const _StageTimeResult(null, null)),
          child: const Text('不定时间'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          key: TaskEditorPage.stageTimeConfirmKey,
          onPressed: blocked != null
              ? null
              : () => Navigator.of(context).pop(
                  _StageTimeResult(
                    offsetFrom(widget.anchor, _start),
                    offsetFrom(_start, _end),
                  ),
                ),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

/// 对话框里的一行：日期 +（非全天时）时刻。
class _MomentRow extends StatelessWidget {
  const _MomentRow({
    required this.dateKey,
    required this.timeKey,
    required this.label,
    required this.moment,
    required this.withTime,
    required this.onChanged,
  });

  final Key dateKey;
  final Key timeKey;
  final String label;
  final DateAndMinute moment;
  final bool withTime;
  final ValueChanged<DateAndMinute> onChanged;

  @override
  Widget build(BuildContext context) {
    final d = moment.date;
    return Row(
      children: [
        SizedBox(
          width: Spacing.xxxl,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        TextButton(
          key: dateKey,
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime(d.year, d.month, d.day),
              firstDate: DateTime(d.year - 5),
              lastDate: DateTime(d.year + 10),
            );
            if (picked != null) {
              onChanged(
                DateAndMinute(
                  PlanDate(picked.year, picked.month, picked.day),
                  moment.minute,
                ),
              );
            }
          },
          child: Text('$d'),
        ),
        if (withTime)
          TextButton(
            key: timeKey,
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: moment.minute.value ~/ 60,
                  minute: moment.minute.value % 60,
                ),
              );
              if (picked != null) {
                onChanged(
                  DateAndMinute(
                    moment.date,
                    MinuteOfDay.of(picked.hour, picked.minute),
                  ),
                );
              }
            },
            child: Text(_hhmm(moment.minute)),
          ),
      ],
    );
  }
}

/// 结束那一截给人看的说法：「9-10」或「9-10 18:00」。
String _endText(TaskDraft draft) {
  final date = draft.endDate;
  if (date == null) return '';
  final m = draft.endMinute;
  if (m == null || draft.isAllDay) return '$date';
  return '$date '
      '${m.hour.toString().padLeft(2, '0')}:'
      '${m.minute.toString().padLeft(2, '0')}';
}

/// 时间那几个控件要不要出现。
///
/// **两条并起来**：
///
///  1. 这个形态本来就该填时间（`needsSchedule`，且起止不是推出来的）；
///  2. **或者**当前已经有数据 —— 逃生口。
///
/// 第 2 条不是兜底，是必须的：旧数据里有形态与内容对不上的行
/// （早期版本没有这些约束）。只按形态藏的话，一条「临时事项却带着日期」
/// 的旧任务，用户在界面上再也改不到那个日期 ——
/// **界面够不着的数据，与不存在的数据在用户看来一样，
/// 但它还在影响列表怎么排。**
bool _showsSpanFields(TaskDraft draft) {
  // ① 阶段事项：起止是**推出来的**，这几个控件不出现 ——
  //    填了也会被下一次推导盖掉，而一个填了没用的输入框比没有更糟。
  if (draft.shape.spanDerivedFromStages) {
    // 唯一的例外：**编辑**一条 `kind=staged` 却一个阶段都没有的旧数据
    // （早期版本允许这种行）。那时没有东西能推，藏起来等于把它锁死。
    //
    // **只在编辑时**。新建的阶段事项本来就是从零个阶段起步的，
    // 把这个例外写成「没有阶段就显示」的话，它每一次新建都会命中 ——
    // 那正是这条守卫头一次跑就抓到的。
    return draft.isEditing && draft.stages.isEmpty;
  }

  // ② **编辑已有任务时始终显示。**
  //
  // 「给这条临时事项加上时间」是正当的编辑，而形态是从**当前字段**反推的
  // （`TaskShape.of` 只看它现在是什么样）—— 藏起来的话那条路就断了：
  // 想加时间要先变成单事项，而想变成单事项又得先加时间。
  // 与重复区、阶段区那两处「只在新建时收窄」是同一条理由。
  if (draft.isEditing) return true;

  // ③ 新建：按形态。临时事项不排时间，所以不出现。
  return draft.shape.needsSchedule;
}

/// 阶段事项那一行只读的「由阶段决定：…」。
///
/// **推出来的东西也要给人看见。** 起止决定这条任务落在日历与甘特图的
/// 哪一段 —— 不显示的话，用户改完阶段时间不知道任务挪到了哪儿，
/// 而那恰恰是他改阶段时间想控制的东西。
///
/// 一个阶段都还没填时间时不画：那时没有可报的事实，
/// 而「由阶段决定：（空）」只会让人以为坏了。
class _DerivedSpanLine extends StatelessWidget {
  const _DerivedSpanLine({required this.draft});

  final TaskDraft draft;

  static const Key spanKey = ValueKey('editor-derived-span');

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // 还没有任何阶段带时间时**照样画**，只是换一句话 ——
    // 那时它回答的是「日期栏哪儿去了」。不画的话，用户会以为表单坏了。
    final hasSpan = draft.stages.any((s) => s.hasTime);
    return Padding(
      key: spanKey,
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Text(
        hasSpan ? '由阶段决定：${_spanText(draft)}' : '起止由阶段的时间决定',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: colors.disabledText),
      ),
    );
  }
}

String _spanText(TaskDraft draft) {
  String at(PlanDate? d, MinuteOfDay? m) =>
      d == null ? '—' : '$d${m == null ? '' : ' $m'}';
  final start = at(draft.planDate, draft.startMinute);
  final end = at(draft.endDate, draft.endMinute);
  return start == end ? start : '$start → $end';
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.date,
    required this.today,
    required this.clearable,
    required this.onPick,
    this.label,
    this.firstDate,
    super.key,
  });

  final PlanDate? date;

  /// 行首的说明。开始那一行不写（它就是「日期」），
  /// 结束那一行必须写 —— 两行长得一模一样时分不出哪行是哪个。
  final String? label;

  /// 可选范围的下界。null 时用 [today] 往前五年（见下）。
  final PlanDate? firstDate;

  /// 本地墙钟的今天。选择器的默认与可选范围都以它为基准。
  final PlanDate today;

  /// 能不能清空。非全天任务必须有日期，所以那时不给清。
  final bool clearable;

  final ValueChanged<PlanDate?> onPick;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      // **不在这里带 key**：key 由调用方给到 widget 上。
      // 两处都带的话同一个 key 会被 find 到两个（widget 一个、
      // ListTile 一个），报错是「is too many」，离原因隔着一层。
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_outlined),
      title: Text(
        date == null ? '选个日期（可选）' : '${label == null ? '' : '$label '}$date',
      ),
      trailing: (date == null || !clearable)
          ? null
          : IconButton(
              onPressed: () => onPick(null),
              icon: const Icon(Icons.close),
              tooltip: '清除日期',
            ),
      onTap: () async {
        // 没选过时停在下界（结束行 = 开始那天），否则停在今天。
        final anchor = date ?? firstDate ?? today;
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime(anchor.year, anchor.month, anchor.day),
          // 往前留五年（补记旧事），往后十年。范围以**今天**为基准，
          // 不以已选日期为基准 —— 否则选了一个很远的日期之后，
          // 可选范围会跟着漂走。
          // 结束日期传了下界就用它（结束不能早于开始）；
          // 开始日期往前留五年（补记旧事）。
          firstDate: firstDate == null
              ? DateTime(today.year - 5)
              : DateTime(firstDate!.year, firstDate!.month, firstDate!.day),
          lastDate: DateTime(today.year + 10),
        );
        if (picked != null) {
          onPick(PlanDate(picked.year, picked.month, picked.day));
        }
      },
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.minute,
    required this.onPick,
    this.label,
    super.key,
  });

  final MinuteOfDay? minute;

  /// 见 [_DateRow.label]。
  final String? label;

  final ValueChanged<MinuteOfDay?> onPick;

  @override
  Widget build(BuildContext context) {
    final m = minute;
    return ListTile(
      // 见 [_DateRow]：key 由调用方给到 widget 上。
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.schedule_outlined),
      title: Text(
        m == null
            ? (label == null ? '选个时间' : '选个$label')
            : '${label == null ? '' : '$label '}'
                  '${m.hour.toString().padLeft(2, '0')}:'
                  '${m.minute.toString().padLeft(2, '0')}',
      ),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: m == null
              ? const TimeOfDay(hour: 9, minute: 0)
              : TimeOfDay(hour: m.hour, minute: m.minute),
        );
        if (picked != null) {
          onPick(MinuteOfDay.of(picked.hour, picked.minute));
        }
      },
    );
  }
}

/// 分类选择（FR-TASK-01：分类是可选字段）。
///
/// 「未分类」**永远是第一项**，而且它不是从仓库来的 ——
/// 库里没有那一行，`categoryId IS NULL` 就是它（settings-spec §3.0）。
///
/// 用一排 Chip 而不是下拉：分类通常只有四五个，摊开一眼看全，
/// 少一次「点开-再点」的往返（M2 那条 ≤3 次点击也吃这个便宜）。
class _CategoryPicker extends ConsumerWidget {
  const _CategoryPicker({required this.selectedId, required this.onSelected});

  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryListProvider);
    final text = Theme.of(context).textTheme;

    return Column(
      key: TaskEditorPage.categoryPickerKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('分类', style: text.bodySmall),
        const SizedBox(height: Spacing.xs),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.xs,
          children: [
            _chip(null, Uncategorized.name),
            for (final c in categories) _chip(c.id, c.name),
          ],
        ),
      ],
    );
  }

  Widget _chip(String? id, String label) => SelectableChip(
    key: TaskEditorPage.categoryChipKey(id),
    label: label,
    selected: id == selectedId,
    onSelected: (_) => onSelected(id),
  );
}

/// 优先级选择区（FR-TASK-01）。
///
/// 顺序按 [TaskPriority.byImportance]（紧急 → … → 无），
/// 与列表的「按优先级」分组、筛选条用的是**同一份顺序** ——
/// 各写一遍的话，三处的次序迟早对不上。
class _PriorityPicker extends StatelessWidget {
  const _PriorityPicker({required this.selected, required this.onSelected});

  final TaskPriority selected;
  final ValueChanged<TaskPriority> onSelected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      key: TaskEditorPage.priorityPickerKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('优先级', style: text.bodySmall),
        const SizedBox(height: Spacing.xs),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.xs,
          children: [
            for (final p in TaskPriority.byImportance)
              SelectableChip(
                key: TaskEditorPage.priorityChipKey(p),
                label: p.label,
                selected: p == selected,
                onSelected: (_) => onSelected(p),
              ),
          ],
        ),
      ],
    );
  }
}

/// 阶段区（FR-TASK-02）。
///
/// **默认不出现任何阶段行** —— 大多数任务是单项的（FR-TASK-01 的基调），
/// 一进来就摆两个空行会把「填得越少越好」变成「先删两行」。
///
/// ## 重排：拖拽 + 箭头，两条路都留着
///
/// FR-TASK-02 的验收原话是「阶段可增删改、**可拖拽重排**」。
/// 一度只有上下箭头 —— 能用，但那不是验收要的东西。
///
/// **箭头没有被拖拽取代，是并存的**：拖拽对读屏用户不可用
/// （NFR-A11Y-03 那一族），而「把第三个移到第一个」用箭头点两下就行。
/// 只留拖拽等于把这个功能从一部分人手里拿走。
///
/// 几个实现上的选择，都是被这张表单的形状逼出来的：
///
/// - `buildDefaultDragHandles: false` + 显式把手。默认的把手在移动端是
///   **长按整行**，而每一行里有个输入框 —— 长按那儿是选词，不是拖动；
/// - `shrinkWrap` + `NeverScrollableScrollPhysics`：这一段活在编辑器
///   那个 `ListView` 里面，自己再滚一层的话，两层滚动会互相抢手势。
class _StageSection extends StatelessWidget {
  const _StageSection({
    required this.draft,
    required this.today,
    required this.controller,
  });

  final TaskDraft draft;

  /// 本地墙钟的今天。任务还没定日期时，阶段时间以它为锚 ——
  /// 与 `setStageTime` 补进草稿的是同一天。
  final PlanDate today;

  final TaskEditorController controller;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      key: TaskEditorPage.stageSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // **形态决定它是不是可选的。** 阶段事项里阶段是必填的
        // （`blockedReason` 那句「至少要两个阶段」说的就是这件事），
        // 标成「可选」与它下面那句红字直接打架 ——
        // 用户 2026-09-10 那条要求里「各自的必填项和非填写」说的正是这个。
        //
        // 别的形态上这一区只在**编辑旧数据**时出现（单事项挂着阶段那种），
        // 那时它确实是可选的。
        Text(
          draft.shape.hasStages ? '阶段（至少两个，每个都要有时间）' : '阶段（可选）',
          style: text.bodySmall,
        ),
        const SizedBox(height: Spacing.xs),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          // **用 `onReorderItem` 而不是 `onReorder`。**
          // 后者已废弃，而两者的 `newIndex` 语义不同：
          // 旧的给的是「移除之前的插入位置」（往下拖时大 1），
          // 新的**已经替你调好了**。
          // 混用的表现是「往下拖一格没反应」，看着像手势没识别。
          onReorderItem: controller.reorderStages,
          children: [
            for (final (i, stage) in draft.stages.indexed)
              Padding(
                // **Key 必须在这一层**（`ReorderableListView` 的直接
                // 孩子上），而且要跟着阶段走而不是跟着下标 ——
                // 用下标的话，拖完之后 Flutter 认为「还是那几个位置」，
                // 输入框的内容会串行。
                key: ValueKey(stage.id),
                padding: const EdgeInsets.only(bottom: Spacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // 勾完成。序号让位给它 —— 序号在时间按钮那一行
                        // 也能看出来（第几个），而「做完没有」没有别处可看。
                        //
                        // **重复任务这里不给勾**（FR-TASK-07）：编辑器编的是
                        // 整条任务，而重复任务的阶段状态是**按每一次**存的。
                        // 在这儿勾写进的是 `Stage.status`，那一列对重复任务
                        // 没人读 —— 勾了没反应，比没有这个框更糟。
                        // 它的正确位置是单次动作弹层（view-specs §4.3）。
                        if (draft.isRecurring)
                          SizedBox(
                            width: 48,
                            child: Center(
                              child: Text('${i + 1}', style: text.bodySmall),
                            ),
                          )
                        else
                          Semantics(
                            label: '第 ${i + 1} 个阶段完成',
                            child: Checkbox(
                              key: TaskEditorPage.stageDoneKey(stage.id),
                              value: stage.isDone,
                              onChanged: (v) =>
                                  controller.setStageDone(stage.id, v ?? false),
                            ),
                          ),
                        Expanded(
                          child: TextField(
                            key: TaskEditorPage.stageFieldKey(stage.id),
                            decoration: const InputDecoration(
                              hintText: '这一步做什么',
                            ),
                            // **编辑模式必须有 controller。**
                            //
                            // 页面开头那段注释早就写明了这件事（标题与备注
                            // 因此各有一个 controller），而阶段这一行漏了 ——
                            // 于是打开一条已有的阶段事项，几行阶段全是空的，
                            // 看起来像内容丢了。存下去倒是不丢（草稿里还在），
                            // 但用户看到的是一张空表单。
                            //
                            // 一直没被发现，是因为没有任何一条用例断言过
                            // 「重新打开时阶段标题显示出来」—— 勾选、排序、
                            // 时间那几条都只按 Key 找控件，不看里面的字。
                            controller: TextEditingController(text: stage.title)
                              ..selection = TextSelection.collapsed(
                                offset: stage.title.length,
                              ),
                            // 划掉是**辅助**，不是唯一标记 —— 勾选框自己
                            // 就带着状态（§8.1 那条原则）。
                            // 重复任务不显示划掉 —— 那个 `isDone` 对它
                            // 没有意义（状态按每一次存）。
                            style: !draft.isRecurring && stage.isDone
                                ? TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: context.appColors.disabledText,
                                  )
                                : null,
                            onChanged: (v) =>
                                controller.setStageTitle(stage.id, v),
                          ),
                        ),
                        // 拖拽把手。**读屏用户用不了拖拽**，所以旁边那个
                        // 上移箭头留着 —— 两条路并存，不是过渡方案。
                        ReorderableDragStartListener(
                          index: i,
                          child: Semantics(
                            label: '拖动调整第 ${i + 1} 个阶段的顺序',
                            child: IconButton(
                              key: TaskEditorPage.stageDragKey(stage.id),
                              // 把手自己不响应点击 —— 它只是个抓取点。
                              // 给它一个 onPressed 会让点一下有反馈却什么
                              // 也不发生，那比没有反馈更让人以为坏了。
                              onPressed: null,
                              icon: const Icon(Icons.drag_handle),
                              tooltip: '拖动排序',
                            ),
                          ),
                        ),
                        IconButton(
                          key: TaskEditorPage.stageUpKey(stage.id),
                          onPressed: i == 0
                              ? null
                              : () => controller.moveStageUp(stage.id),
                          icon: const Icon(Icons.arrow_upward),
                          tooltip: '上移',
                        ),
                        IconButton(
                          key: TaskEditorPage.stageRemoveKey(stage.id),
                          onPressed: () => controller.removeStage(stage.id),
                          icon: const Icon(Icons.close),
                          tooltip: '删除这个阶段',
                        ),
                      ],
                    ),
                    // 时间收在标题下面一行的小按钮里：大多数阶段只是
                    // 「先做这个、再做那个」，没有具体时刻。
                    Padding(
                      padding: const EdgeInsets.only(left: Spacing.xxl),
                      child: _StageTimeButton(
                        stage: stage,
                        anchor: _stageAnchor(draft, today),
                        isAllDay: draft.isAllDay,
                        onChanged: (start, duration) => controller.setStageTime(
                          stage.id,
                          startOffsetMinutes: start,
                          durationMinutes: duration,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        AppButton(
          key: TaskEditorPage.addStageKey,
          label: draft.stages.isEmpty ? '分成几个阶段' : '再加一个阶段',
          variant: AppButtonVariant.secondary,
          onPressed: controller.addStage,
        ),
      ],
    );
  }
}

/// 重复区（FR-TASK-03/04）。
///
/// 关着的时候只有一个开关 —— 大多数任务不重复，一进来摊开一屏选项
/// 是把少数情形的成本摊给所有人。
/// 重复区（FR-TASK-03/04）。
///
/// **每个能改 RRULE 的字段都要在这里有一个控件。** 第一版漏了三个 ——
/// 间隔、次数、结束日期 —— 而单元测试把这三个都测透了：
/// 测的是 `RecurrenceDraft`，不是「用户能不能造出那个 draft」。
/// 最难看的是「到某天为止」：选了它就必然非法，页面上却没有任何地方
/// 能选那个日期，保存按钮永久灰着 —— **一条走进去出不来的路**。
/// 而当时那条测试恰好断言了「拦住了」，就停在那儿，没有往下问
/// 「拦住之后有没有路走」。守卫见 `recurrence_reachability_test.dart`。
class _RecurrenceSection extends StatelessWidget {
  const _RecurrenceSection({
    required this.draft,
    required this.anchor,
    required this.unsupported,
    required this.controller,
  });

  /// 这条任务的规则这个界面表达不了时，是那条原串（否则 null）。
  /// 见 [TaskDraft.unsupportedRecurrence]。
  final String? unsupported;

  final RecurrenceDraft draft;

  /// 这条规则从哪天开始算 —— 任务的计划日期，没有就用今天。
  /// 「到某天为止」的可选范围以它为下界：结束早于开始的规则一次都展不出来。
  final PlanDate anchor;

  final TaskEditorController controller;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;

    // 界面表达不了的规则：**只读一行，不给动**。
    //
    // 显示成「不重复」再让用户一按保存把规则抹掉，是最糟的一种
    // 「什么都没做却坏了东西」。说清楚它还在、只是这里改不了。
    if (unsupported != null) {
      return Column(
        key: TaskEditorPage.unsupportedRecurrenceKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('重复', style: text.bodyLarge),
          const SizedBox(height: Spacing.xxs),
          Text('这条规则这里改不了，保存不会动它。', style: text.bodySmall),
          const SizedBox(height: Spacing.xxs),
          Text(unsupported!, style: text.bodySmall),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: TaskEditorPage.recurrenceSwitchKey,
          contentPadding: EdgeInsets.zero,
          title: const Text('重复'),
          // 关着时也显示一句「不重复」，而不是留空 —— 留空的话
          // 用户分不清「不重复」与「这个功能还没做」。
          subtitle: Text(
            draft.describe(),
            key: TaskEditorPage.recurrenceSummaryKey,
            style: text.bodySmall,
          ),
          value: draft.enabled,
          onChanged: (v) =>
              controller.setRecurrence(draft.copyWith(enabled: v)),
        ),
        if (draft.enabled) ...[
          const SizedBox(height: Spacing.sm),
          _ChipRow(
            options: [
              for (final f in RecurrenceFrequency.values)
                (
                  TaskEditorPage.frequencyKey(f),
                  f.label,
                  draft.frequency == f,
                  () => controller.setRecurrence(draft.copyWith(frequency: f)),
                ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          _Stepper(
            name: TaskEditorPage.intervalStepper,
            label: '间隔',
            // 「每 2 周」而不是干巴巴一个 2 —— 单位跟着频率变，
            // 否则用户得自己把上面那排 Chip 和这个数字对起来读。
            display: '每 ${draft.interval} ${draft.frequency.unitLabel}',
            value: draft.interval,
            onChanged: (v) =>
                controller.setRecurrence(draft.copyWith(interval: v)),
          ),
          if (draft.frequency == RecurrenceFrequency.monthly) ...[
            const SizedBox(height: Spacing.sm),
            Text('每月哪一天', style: text.bodySmall),
            const SizedBox(height: Spacing.xs),
            _ChipRow(
              options: [
                for (final m in MonthlyMode.values)
                  (
                    TaskEditorPage.monthlyModeKey(m),
                    m.label,
                    draft.monthlyMode == m,
                    () => controller.setRecurrence(
                      draft.copyWith(monthlyMode: m),
                    ),
                  ),
              ],
            ),
            // 与结束条件同一个做法：选中哪档就只给哪档的输入。
            if (draft.monthlyMode == MonthlyMode.onDate) ...[
              const SizedBox(height: Spacing.xs),
              _ChipRow(
                options: [
                  (
                    TaskEditorPage.lastDayOfMonthKey,
                    '最后一天',
                    draft.monthDay == lastDayOfMonth,
                    () => controller.setRecurrence(
                      draft.copyWith(
                        // 再点一次回到 1 号 —— 不给「取消选中但没有号数」
                        // 这种状态，那会让保存按钮灰着而看不出原因。
                        monthDay: draft.monthDay == lastDayOfMonth
                            ? 1
                            : lastDayOfMonth,
                      ),
                    ),
                  ),
                ],
              ),
              if (draft.monthDay != lastDayOfMonth)
                _Stepper(
                  name: TaskEditorPage.monthDayStepper,
                  label: '几号',
                  display: monthDayLabel(draft.monthDay),
                  value: draft.monthDay,
                  max: 31,
                  onChanged: (v) =>
                      controller.setRecurrence(draft.copyWith(monthDay: v)),
                ),
              // 29/30/31 号在短月份是**跳过**，不是夹到月末（RFC 5545）。
              // 不说的话，选了 31 号的人要到三月才发现二月没提醒。
              if (draft.monthDay >= 29)
                Padding(
                  key: TaskEditorPage.monthSkipHintKey,
                  padding: const EdgeInsets.only(top: Spacing.xs),
                  child: Text(
                    '没有 ${draft.monthDay} 号的月份会跳过。想每月月末，选「最后一天」。',
                    style: text.bodySmall?.copyWith(color: colors.dangerText),
                  ),
                ),
            ],
            if (draft.monthlyMode == MonthlyMode.onWeekday) ...[
              const SizedBox(height: Spacing.xs),
              _ChipRow(
                options: [
                  for (final o in monthOrdinals)
                    (
                      TaskEditorPage.monthOrdinalKey(o),
                      monthOrdinalLabel(o),
                      draft.monthOrdinal == o,
                      () => controller.setRecurrence(
                        draft.copyWith(monthOrdinal: o),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Spacing.xs),
              _ChipRow(
                options: [
                  for (final d in Weekday.values)
                    (
                      TaskEditorPage.monthWeekdayKey(d),
                      '周${d.label}',
                      draft.monthWeekday == d,
                      () => controller.setRecurrence(
                        draft.copyWith(monthWeekday: d),
                      ),
                    ),
                ],
              ),
            ],
          ],
          if (draft.frequency == RecurrenceFrequency.weekly) ...[
            const SizedBox(height: Spacing.sm),
            Text('周几（不选＝跟开始日期同一天）', style: text.bodySmall),
            const SizedBox(height: Spacing.xs),
            _ChipRow(
              options: [
                for (final d in Weekday.values)
                  (
                    TaskEditorPage.weekdayKey(d),
                    d.label,
                    draft.weekdays.contains(d),
                    () => controller.setRecurrence(draft.toggleWeekday(d)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: Spacing.sm),
          Text('结束条件', style: text.bodySmall),
          const SizedBox(height: Spacing.xs),
          _ChipRow(
            options: [
              for (final m in RecurrenceEndMode.values)
                (
                  TaskEditorPage.endModeKey(m),
                  m.label,
                  draft.endMode == m,
                  () => controller.setRecurrence(draft.copyWith(endMode: m)),
                ),
            ],
          ),
          // 选中哪种结束条件，就只给哪种的输入 ——
          // 三个都摆出来的话，用户改的那个未必是生效的那个。
          if (draft.endMode == RecurrenceEndMode.count)
            _Stepper(
              name: TaskEditorPage.countStepper,
              label: '次数（含第一次）',
              display: '${draft.count} 次',
              value: draft.count,
              onChanged: (v) =>
                  controller.setRecurrence(draft.copyWith(count: v)),
            ),
          if (draft.endMode == RecurrenceEndMode.until)
            _UntilRow(
              until: draft.until,
              anchor: anchor,
              onPick: (d) => controller.setRecurrence(draft.copyWith(until: d)),
            ),
        ],
      ],
    );
  }
}

/// 「到某天为止」的日期（FR-TASK-04）。
///
/// **不给清空。** 清了就回到那条走不出去的路上：结束条件还是「到某天为止」，
/// 却没有那一天，保存永久灰着。要取消就去上面改结束条件。
class _UntilRow extends StatelessWidget {
  const _UntilRow({
    required this.until,
    required this.anchor,
    required this.onPick,
  });

  final PlanDate? until;
  final PlanDate anchor;
  final ValueChanged<PlanDate> onPick;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: TaskEditorPage.untilFieldKey,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_available_outlined),
      title: Text(until == null ? '选一个结束日期' : '到 $until 为止'),
      onTap: () async {
        final current = until;
        // 没选过时默认一个月后 —— 拿开始那天当默认值的话，
        // 用户一路点「确定」会得到一条只发生一次的重复规则。
        //
        // **已选的日期还得夹一道**：选完之后把任务日期往后改，
        // 已选的结束日期就跑到下界前面去了，那时 `showDatePicker`
        // 会直接断言失败崩掉 —— 一条改日期顺序不同就触发的路。
        final initial = (current == null || current.isBefore(anchor))
            ? anchor.addDays(30)
            : current;
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime(initial.year, initial.month, initial.day),
          // **下界是开始日期**：结束早于开始的规则一次都展不出来，
          // 而它长得和一条正常规则一模一样。
          firstDate: DateTime(anchor.year, anchor.month, anchor.day),
          lastDate: DateTime(anchor.year + 10),
        );
        if (picked != null) {
          onPick(PlanDate(picked.year, picked.month, picked.day));
        }
      },
    );
  }
}

/// 一个数字加减器。
///
/// 用加减而不是输入框：这两个数几乎总是个位数，而输入框要处理空串、
/// 非数字、粘进来的负号 —— 那些 [RecurrenceDraft.blockedReason] 里都有兜底，
/// 但让用户先打错再看红字，不如根本打不错。
///
/// 上界 [max] 是**控件的**限制，不是模型的：RRULE 的 COUNT 可以很大，
/// 同步下来一条 `COUNT=500` 照样正常展开。真要重复很多次的场景
/// （「今年每天」），「到某天为止」才是顺手的控件。
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.name,
    required this.label,
    required this.display,
    required this.value,
    required this.onChanged,
    this.max = 99,
  });

  static const int _min = 1;

  /// 上界跟着用途走：间隔与次数是 99，而「几号」是 31。
  /// 一律 99 的话，加号能一路点到 45 号 —— 一条编得出来、
  /// 但一次都不会发生的规则。
  final int max;

  /// Key 前缀，见 [TaskEditorPage.stepperValueKey]。
  final String name;

  final String label;

  /// 数字旁边那句话，如「每 2 周」。
  final String display;

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // 到头了就禁用按钮，而不是点了没反应 —— 后者与「界面卡住了」
    // 在用户看来一模一样。
    final canDec = value > _min;
    final canInc = value < max;

    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.bodySmall),
          Row(
            children: [
              IconButton(
                key: TaskEditorPage.stepperDecKey(name),
                onPressed: canDec ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove),
                tooltip: '减少',
              ),
              // 固定宽度，免得数字从个位变两位时两个按钮跟着抖。
              SizedBox(
                width: 96,
                child: Text(
                  display,
                  key: TaskEditorPage.stepperValueKey(name),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                key: TaskEditorPage.stepperIncKey(name),
                onPressed: canInc ? () => onChanged(value + 1) : null,
                icon: const Icon(Icons.add),
                tooltip: '增加',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 一排可选中的 Chip。`(key, 文案, 是否选中, 点击)`。
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.options});

  final List<(Key, String, bool, VoidCallback)> options;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Spacing.sm,
    runSpacing: Spacing.xs,
    children: [
      for (final (key, label, selected, onTap) in options)
        SelectableChip(
          key: key,
          label: label,
          selected: selected,
          onSelected: (_) => onTap(),
        ),
    ],
  );
}

/// 清单区（FR-TASK-09）。
///
/// ## 与阶段区并排放，靠内容自己区分
///
/// 两者在编辑器里长得像 —— 都是一列可增删的行。区别写在标题下那句话上，
/// 也写在**控件本身**：清单项没有「加时间」那个按钮。
/// 术语表把清单定义成「不参与时间排布」，给它一个时间入口
/// 就等于把它变成第二种阶段。
///
/// 顺序用的是列表顺序（保存时按下标写 `orderIndex`），
/// 没做上下移 —— 阶段有上下移是因为阶段的先后是**语义**（第一步第二步），
/// 而清单是一把待办，顺序只是录入顺序。要排序的话那是另一件事。
/// 提醒（FR-NOTI-01）。
///
/// **只给「提前多久」这一档**，理由写在 `ReminderDraft` 上。
///
/// 每条给一个开关而不是只给删除：「这阵子别吵我」与「以后都不要」
/// 是两件事，而后者会连用户调过的提前量一起丢掉。
class _ReminderSection extends StatelessWidget {
  const _ReminderSection({required this.draft, required this.controller});

  final TaskDraft draft;
  final TaskEditorController controller;

  /// 可选的提前量。**给档位不给任意分钟数**，同配置项那条理由 ——
  /// 能填任意值的框，第一件事就是让人填出 0 分钟之外的怪值。
  static const List<(int, String)> _options = [
    (0, '准时'),
    (-5, '提前 5 分钟'),
    (-15, '提前 15 分钟'),
    (-30, '提前 30 分钟'),
    (-60, '提前 1 小时'),
    (-1440, '提前 1 天'),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      key: TaskEditorPage.reminderSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('提醒（可选）', style: text.bodySmall),
        const SizedBox(height: Spacing.xs),
        // 「没有日期就不会提醒」那句话现在只对**编辑旧数据**说得着 ——
        // 新建时不排时间的那一样（临时事项）已经不显示这个区了。
        // 阶段事项有日期（推出来的），所以对它讲那句话是误导。
        Text(draft.shape.needsSchedule ? '到点前提醒你。' : '到点前提醒你。这条任务没有日期，所以不会提醒。'),
        const SizedBox(height: Spacing.sm),
        for (final r in draft.reminders)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.xs),
            child: Row(
              children: [
                Semantics(
                  label: '这条提醒开着',
                  child: Switch(
                    key: TaskEditorPage.reminderEnabledKey(r.id),
                    value: r.isEnabled,
                    onChanged: (v) => controller.setReminderEnabled(r.id, v),
                  ),
                ),
                const SizedBox(width: Spacing.iconToText),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: TaskEditorPage.reminderOffsetKey(r.id),
                    initialValue: r.offsetMinutes,
                    items: [
                      for (final (value, label) in _options)
                        DropdownMenuItem(value: value, child: Text(label)),
                    ],
                    onChanged: (v) => v == null
                        ? null
                        : controller.setReminderOffset(r.id, v),
                  ),
                ),
                IconButton(
                  key: TaskEditorPage.reminderRemoveKey(r.id),
                  icon: const Icon(Icons.close),
                  tooltip: '删掉这条提醒',
                  onPressed: () => controller.removeReminder(r.id),
                ),
              ],
            ),
          ),
        AppButton(
          key: TaskEditorPage.addReminderKey,
          label: draft.reminders.isEmpty ? '加个提醒' : '再加一条',
          variant: AppButtonVariant.secondary,
          onPressed: controller.addReminder,
        ),
      ],
    );
  }
}

class _ChecklistSection extends StatelessWidget {
  const _ChecklistSection({required this.draft, required this.controller});

  final TaskDraft draft;
  final TaskEditorController controller;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;

    return Column(
      key: TaskEditorPage.checklistSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('清单（可选）', style: text.bodySmall),
        const SizedBox(height: Spacing.xs),
        // 说清它跟阶段的差别。不说的话，两个长得差不多的区摆在一起，
        // 用户只能靠试出来。
        // **不套 `disabledText`。** 那个色是唯一豁免对比度门槛的
        // （app_theme 里写着「只许出现在禁用态」），拿它写说明文字
        // 等于让一句要读的话低于 4.5:1。
        const Text('随手记几件要做的小事。不排时间，也不上时间轴和甘特。'),
        const SizedBox(height: Spacing.sm),
        for (final item in draft.checklist)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.xs),
            child: Row(
              children: [
                Semantics(
                  label: '清单项完成',
                  child: Checkbox(
                    key: TaskEditorPage.checklistDoneKey(item.id),
                    value: item.isDone,
                    onChanged: (v) =>
                        controller.setChecklistDone(item.id, v ?? false),
                  ),
                ),
                Expanded(
                  child: TextField(
                    key: TaskEditorPage.checklistFieldKey(item.id),
                    decoration: const InputDecoration(hintText: '要做的小事'),
                    // 划掉是**辅助**，勾选框自己带着状态（§8.1）。
                    style: item.isDone
                        ? TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: colors.disabledText,
                          )
                        : null,
                    controller: TextEditingController(text: item.title)
                      ..selection = TextSelection.collapsed(
                        offset: item.title.length,
                      ),
                    onChanged: (v) => controller.setChecklistTitle(item.id, v),
                  ),
                ),
                IconButton(
                  key: TaskEditorPage.checklistRemoveKey(item.id),
                  icon: const Icon(Icons.close),
                  tooltip: '删掉这一项',
                  onPressed: () => controller.removeChecklistItem(item.id),
                ),
              ],
            ),
          ),
        AppButton(
          key: TaskEditorPage.addChecklistKey,
          label: draft.checklist.isEmpty ? '加个清单' : '再加一项',
          variant: AppButtonVariant.secondary,
          onPressed: controller.addChecklistItem,
        ),
      ],
    );
  }
}

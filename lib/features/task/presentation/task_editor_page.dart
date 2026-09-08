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
import '../../../design/components/app_button.dart';
import '../../../design/components/app_chip.dart';
import '../../../design/theme/app_theme.dart';
import '../../../design/tokens/dimensions.dart';
import '../../views/shared/application/category_providers.dart';
import '../application/recurrence_draft.dart';
import '../application/task_editor_controller.dart';

class TaskEditorPage extends ConsumerStatefulWidget {
  const TaskEditorPage({this.onSaved, super.key});

  /// 保存成功后调用，参数是新任务的 ID。由组合根接上返回上一页。
  final void Function(String taskId)? onSaved;

  static const Key titleFieldKey = ValueKey('editor-title');
  static const Key noteFieldKey = ValueKey('editor-note');
  static const Key saveButtonKey = ValueKey('editor-save');
  static const Key allDaySwitchKey = ValueKey('editor-all-day');
  static const Key dateFieldKey = ValueKey('editor-date');
  static const Key timeFieldKey = ValueKey('editor-time');

  /// 分类选择区。每个选项的 Key 见 [categoryChipKey]。
  static const Key categoryPickerKey = ValueKey('editor-category');

  /// 阶段区。
  static const Key stageSectionKey = ValueKey('editor-stages');
  static const Key addStageKey = ValueKey('editor-add-stage');

  /// 「为什么不能存」那句提示。
  static const Key blockedReasonKey = ValueKey('editor-blocked');

  /// 重复区。
  static const Key recurrenceSwitchKey = ValueKey('editor-repeat');
  static const Key recurrenceSummaryKey = ValueKey('editor-repeat-summary');

  static Key frequencyKey(RecurrenceFrequency f) =>
      ValueKey('editor-repeat-freq-${f.name}');
  static Key weekdayKey(Weekday d) => ValueKey('editor-repeat-day-${d.name}');
  static Key endModeKey(RecurrenceEndMode m) =>
      ValueKey('editor-repeat-end-${m.name}');

  static Key stageFieldKey(String stageId) => ValueKey('editor-stage-$stageId');
  static Key stageRemoveKey(String stageId) =>
      ValueKey('editor-stage-remove-$stageId');
  static Key stageUpKey(String stageId) => ValueKey('editor-stage-up-$stageId');

  /// 某个分类选项的 Key。`null` 是「未分类」那一项。
  static Key categoryChipKey(String? categoryId) =>
      ValueKey('editor-category-${categoryId ?? 'none'}');

  @override
  ConsumerState<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends ConsumerState<TaskEditorPage> {
  /// 保存中。**用它挡住重复提交** —— 连点两下保存会建出两条任务，
  /// 而命令自带 ID 只保证同一条命令重放幂等，不保证两条不同命令去重。
  bool _saving = false;

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
    final draft = ref.watch(taskEditorProvider);
    final controller = ref.read(taskEditorProvider.notifier);
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('新建任务'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.pageHorizontal),
          children: [
            TextField(
              key: TaskEditorPage.titleFieldKey,
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
            _DateRow(
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
              value: draft.isAllDay,
              onChanged: controller.setAllDay,
            ),
            if (!draft.isAllDay)
              _TimeRow(
                minute: draft.startMinute,
                onPick: controller.setStartMinute,
              ),
            const SizedBox(height: Spacing.xl),
            _RecurrenceSection(draft: draft.recurrence, controller: controller),
            const SizedBox(height: Spacing.xl),
            _StageSection(draft: draft, controller: controller),
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

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.date,
    required this.today,
    required this.clearable,
    required this.onPick,
  });

  final PlanDate? date;

  /// 本地墙钟的今天。选择器的默认与可选范围都以它为基准。
  final PlanDate today;

  /// 能不能清空。非全天任务必须有日期，所以那时不给清。
  final bool clearable;

  final ValueChanged<PlanDate?> onPick;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: TaskEditorPage.dateFieldKey,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_outlined),
      title: Text(date == null ? '选个日期（可选）' : '$date'),
      trailing: (date == null || !clearable)
          ? null
          : IconButton(
              onPressed: () => onPick(null),
              icon: const Icon(Icons.close),
              tooltip: '清除日期',
            ),
      onTap: () async {
        final anchor = date ?? today;
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime(anchor.year, anchor.month, anchor.day),
          // 往前留五年（补记旧事），往后十年。范围以**今天**为基准，
          // 不以已选日期为基准 —— 否则选了一个很远的日期之后，
          // 可选范围会跟着漂走。
          firstDate: DateTime(today.year - 5),
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
  const _TimeRow({required this.minute, required this.onPick});

  final MinuteOfDay? minute;
  final ValueChanged<MinuteOfDay?> onPick;

  @override
  Widget build(BuildContext context) {
    final m = minute;
    return ListTile(
      key: TaskEditorPage.timeFieldKey,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.schedule_outlined),
      title: Text(
        m == null
            ? '选个时间'
            : '${m.hour.toString().padLeft(2, '0')}:'
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

/// 阶段区（FR-TASK-02）。
///
/// **默认不出现任何阶段行** —— 大多数任务是单项的（FR-TASK-01 的基调），
/// 一进来就摆两个空行会把「填得越少越好」变成「先删两行」。
///
/// 拖拽重排（§FR-TASK-02 的验收里提到）先用上下箭头代替：
/// 拖拽在两三个阶段时收益很小，而它要处理滚动冲突与无障碍替代操作。
/// TODO(M3): 换成 ReorderableListView，并保留箭头作为读屏用户的替代路径。
class _StageSection extends StatelessWidget {
  const _StageSection({required this.draft, required this.controller});

  final TaskDraft draft;
  final TaskEditorController controller;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      key: TaskEditorPage.stageSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('阶段（可选）', style: text.bodySmall),
        const SizedBox(height: Spacing.xs),
        for (final (i, stage) in draft.stages.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.xs),
            child: Row(
              children: [
                // 序号跟着**列表位置**走，不是 orderIndex —— 编辑期间
                // 后者还没算出来（保存时才转成连续的）。
                SizedBox(
                  width: Spacing.xxl,
                  child: Text('${i + 1}.', style: text.bodySmall),
                ),
                Expanded(
                  child: TextField(
                    key: TaskEditorPage.stageFieldKey(stage.id),
                    decoration: const InputDecoration(hintText: '这一步做什么'),
                    onChanged: (v) => controller.setStageTitle(stage.id, v),
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
class _RecurrenceSection extends StatelessWidget {
  const _RecurrenceSection({required this.draft, required this.controller});

  final RecurrenceDraft draft;
  final TaskEditorController controller;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

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
        ],
      ],
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

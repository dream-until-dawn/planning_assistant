/// 新建任务（FR-TASK-01）。
///
/// **仅填标题即可保存** —— 这是验收标准，也是整个界面的组织原则：
/// 标题输入框自动聚焦，保存按钮就在拇指够得到的地方，其余全是可选的加法。
/// M2 验收还有一条「从点开 App 到任务落库 ≤ 3 次点击」：
/// 悬浮加号 → 打字 → 保存，正好三下。
///
/// 阶段与重复两种形态（FR-TASK-02/03）还没做，
/// 这里也**不放入口占位** —— 点了没反应的开关比没有更糟。
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
            const SizedBox(height: Spacing.xxxl),
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
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.date,
    required this.today,
    required this.onPick,
  });

  final PlanDate? date;

  /// 本地墙钟的今天。选择器的默认与可选范围都以它为基准。
  final PlanDate today;

  final ValueChanged<PlanDate?> onPick;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: TaskEditorPage.dateFieldKey,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_outlined),
      title: Text(date == null ? '选个日期（可选）' : '$date'),
      trailing: date == null
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

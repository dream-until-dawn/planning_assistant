/// 分类管理（FR-CFG-03、settings-spec §3）。
///
/// 设置页的二级页 —— 分类是**实体不是配置项**（存 `categories` 表），
/// 但管理入口在设置里（§3 开头那句）。
///
/// ## 「未分类」不在这张表里
///
/// `categoryId == null` 就是未分类（§3.0），库里没有那一行，
/// 所以这里既列不出它，也没有可删的东西。编辑器里它照常作为第一个
/// 选项出现，那是**渲染时的常量**。
///
/// 界面上留了一句话说明这件事 —— 不说的话，用户会以为「未分类」被漏掉了，
/// 或者去找它想改个颜色。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/app_button.dart';
import '../../../design/components/empty_illustration.dart';
import '../../../design/components/empty_state.dart';
import '../../../design/theme/app_theme.dart';
import '../../../design/tokens/colors.dart';
import '../../../design/tokens/dimensions.dart';
import '../../../domain/entities/category.dart';
import '../../views/shared/application/category_actions.dart';
import '../../views/shared/application/category_providers.dart';

class CategoryManagerPage extends ConsumerWidget {
  const CategoryManagerPage({super.key});

  static const Key pageKey = ValueKey('category-manager');
  static const Key addButtonKey = ValueKey('category-add');
  static const Key emptyKey = ValueKey('category-empty');

  /// 新建/改名对话框里的输入框与确定。
  static const Key nameFieldKey = ValueKey('category-name-field');
  static const Key nameConfirmKey = ValueKey('category-name-confirm');

  /// 删除确认对话框里的那个「删除」。
  static const Key deleteConfirmKey = ValueKey('category-delete-confirm');

  static Key rowKey(String id) => ValueKey('category-row-$id');
  static Key renameKey(String id) => ValueKey('category-rename-$id');
  static Key deleteKey(String id) => ValueKey('category-delete-$id');
  static Key colorKey(String id) => ValueKey('category-color-$id');
  static Key defaultKey(String id) => ValueKey('category-default-$id');
  static Key colorOptionKey(int argb) =>
      ValueKey('category-color-option-$argb');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    final categories = ref.watch(categoryListProvider);
    final actions = ref.read(categoryActionsProvider);

    return Scaffold(
      key: pageKey,
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('分类管理'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: categories.isEmpty
                  ? const EmptyState(
                      key: emptyKey,
                      illustration: EmptyIllustration(motif: EmptyMotif.box),
                      // 全删光是合法状态（§3.1）：那时所有任务都是未分类。
                      // 所以这里不催促，只说明。
                      message: '还没有分类。\n没有也行 —— 那时任务都是「未分类」。',
                    )
                  : ReorderableListView.builder(
                      // **整行不可拖**，只认那个把手。
                      // 默认在移动端是「长按整行就拖」，而这一行上还有
                      // 改名和删除两个按钮 —— 想点却按久了一点，
                      // 就会把一行拖走。
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.all(Spacing.pageHorizontal),
                      itemCount: categories.length,
                      onReorderItem: actions.reorder,
                      itemBuilder: (context, i) => _CategoryRow(
                        key: rowKey(categories[i].id),
                        category: categories[i],
                        index: i,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(Spacing.pageHorizontal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 「未分类」为什么不在列表里 —— 不说的话，用户会以为它
                  // 被漏了，或者去找它想改颜色。
                  Text('「未分类」不是一个分类，是「没选分类」，所以不在这里。', style: text.bodySmall),
                  const SizedBox(height: Spacing.sm),
                  AppButton(
                    key: addButtonKey,
                    label: '新建分类',
                    expand: true,
                    onPressed: () async {
                      final name = await _askName(context, title: '新建分类');
                      if (name != null) await actions.create(name);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 问一个名字。返回 null 表示取消；**返回值一定非空且已 trim**。
///
/// 空名字不给确定 —— 存下去会得到一个在编辑器里点不中、
/// 在卡片上什么也不显示的分类。
Future<String?> _askName(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => _NameDialog(title: title, controller: controller),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.controller});

  final String title;
  final TextEditingController controller;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text.trim();
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: CategoryManagerPage.nameFieldKey,
        controller: widget.controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: '名称', hintText: '比如：阅读'),
        onChanged: (_) => setState(() {}),
        onSubmitted: value.isEmpty
            ? null
            : (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          key: CategoryManagerPage.nameConfirmKey,
          // 空名字禁用而不是存了再报错 —— 能不能存是当场看得见的事。
          onPressed: value.isEmpty
              ? null
              : () => Navigator.of(context).pop(value),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

class _CategoryRow extends ConsumerWidget {
  const _CategoryRow({required this.category, required this.index, super.key});

  final Category category;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(categoryActionsProvider);
    final text = Theme.of(context).textTheme;
    final isDefault = ref.watch(defaultCategoryIdProvider) == category.id;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      // 色点只是辅助：分类名同时以文字出现（design-system §8.1）——
      // 调色板对两种表面只有 1.36–1.88，靠颜色分辨是分辨不出来的。
      leading: InkWell(
        key: CategoryManagerPage.colorKey(category.id),
        onTap: () async {
          final picked = await _pickColor(context, category.colorArgb);
          if (picked != null) {
            await actions.update(category, colorArgb: picked);
          }
        },
        borderRadius: BorderRadius.circular(Radii.full),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.sm),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Color(category.colorArgb),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
      // 默认那一条**同时用文字说出来**：星标是图标，而图标不单独承载
      // 信息（design-system §8.1）。读屏用户只听得到「星形按钮」，
      // 听不出这一行就是默认的。
      title: Text(
        isDefault ? '${category.name}（默认）' : category.name,
        style: text.bodyLarge,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 设为默认（settings-spec §3）。**用一个填实/描边的星标**，
          // 不是只给默认那一行加个角标 —— 后者没有「怎么改」的入口。
          IconButton(
            key: CategoryManagerPage.defaultKey(category.id),
            tooltip: isDefault ? '取消默认' : '设为新任务的默认分类',
            icon: Icon(isDefault ? Icons.star : Icons.star_border),
            onPressed: () => actions.setDefault(isDefault ? null : category.id),
          ),
          IconButton(
            key: CategoryManagerPage.renameKey(category.id),
            tooltip: '改名',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final name = await _askName(
                context,
                title: '改名',
                initial: category.name,
              );
              if (name != null) await actions.update(category, name: name);
            },
          ),
          IconButton(
            key: CategoryManagerPage.deleteKey(category.id),
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await _confirmDelete(context, category.name);
              if (ok) await actions.remove(category.id);
            },
          ),
          // 拖拽把手。**留着它，不靠整行拖** —— 整行可拖的话，
          // 想点改名却按久了就会拖走一行。
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: Spacing.xs),
              child: Icon(Icons.drag_handle),
            ),
          ),
        ],
      ),
    );
  }
}

/// 删除前问一句。
///
/// **要问**：删分类会动到它下面的任务（变成未分类），而那批任务
/// 不在当前屏幕上 —— 看不见的后果尤其要先说。
Future<bool> _confirmDelete(BuildContext context, String name) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('删除「$name」？'),
      content: const Text('它下面的任务不会被删，会变成「未分类」。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          key: CategoryManagerPage.deleteConfirmKey,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// 画在调色板色点之上的前景色。
///
/// 调色板全是浅色（对白底只有 1.36–1.88），所以用正文色，
/// 不用 `onBrand` —— 那个是配主色填充的。
Color _onPalette(BuildContext context) =>
    Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF3A3742);

/// 从 §2.5 的调色板里挑一个。
Future<int?> _pickColor(BuildContext context, int current) => showDialog<int>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('分类颜色'),
    content: Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (final argb in CategoryPalette.values)
          InkWell(
            key: CategoryManagerPage.colorOptionKey(argb),
            onTap: () => Navigator.of(context).pop(argb),
            borderRadius: BorderRadius.circular(Radii.full),
            child: Container(
              width: Spacing.minTouchTarget,
              height: Spacing.minTouchTarget,
              decoration: BoxDecoration(
                color: Color(argb),
                shape: BoxShape.circle,
                // 当前选中的那个加一圈描边。**不只靠颜色区分**：
                // 八个色点里哪个是当前的，光看颜色看不出来。
                // 当前那个不只靠颜色区分（八个色点里看不出来），
                // 加描边**和**对勾两重。
                border: argb == current
                    ? Border.all(color: _onPalette(context), width: 2)
                    : null,
              ),
              child: argb == current
                  ? Icon(Icons.check, color: _onPalette(context))
                  : null,
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
    ],
  ),
);

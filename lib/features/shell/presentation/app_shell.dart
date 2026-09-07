/// 应用外壳（view-specs §7）。
///
/// ## 它**不知道**有哪些视图
///
/// 外壳收一个 `viewBuilder` 回调，渲染它给的东西。具体有哪些视图、
/// 各自长什么样，由组合根（`lib/app.dart`）决定。
///
/// 两个理由：
///
/// 1. **分层**：`features/shell/presentation` 不得 import
///    `features/views/*/presentation`（module-map §3，跨 feature 只能经
///    application 层通信）。外壳要是直接认识视图页面，这条就破了。
/// 2. **加视图不动外壳**：view-specs §7.3 承诺「新增一个视图 =
///    枚举加一项 + 注册一个构建器」。外壳里只要出现一次
///    `switch (kind)`，这个承诺就作废了。
///
/// 于是「只有一个视图」和「有四个视图」对外壳来说是同一件事 ——
/// M2 只有列表，而外壳不需要为 M3 改一行。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/theme/app_theme.dart';
import '../../../design/tokens/dimensions.dart';
import '../../views/shared/application/view_kind.dart';

/// 外壳。
class AppShell extends ConsumerWidget {
  const AppShell({
    required this.currentView,
    required this.availableViews,
    required this.viewBuilder,
    required this.onViewSelected,
    this.onCreateTask,
    this.onOpenSettings,
    super.key,
  });

  final ViewKind currentView;

  /// 当前版本**实装了的**视图。
  ///
  /// 不是 `ViewKind.values` —— M2 只有列表。切换器照这个渲染，
  /// 于是不会出现一个点了没反应的按钮。
  final List<ViewKind> availableViews;

  final Widget Function(BuildContext, ViewKind) viewBuilder;
  final ValueChanged<ViewKind> onViewSelected;
  final VoidCallback? onCreateTask;
  final VoidCallback? onOpenSettings;

  static const Key fabKey = ValueKey('shell-create-task');
  static const Key settingsKey = ValueKey('shell-open-settings');

  /// 视图切换器上每个选项的 Key 前缀。
  static Key viewTabKey(ViewKind kind) => ValueKey('shell-view-${kind.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: _ViewSwitcher(
          current: currentView,
          available: availableViews,
          onSelected: onViewSelected,
        ),
        actions: [
          IconButton(
            key: settingsKey,
            onPressed: onOpenSettings,
            icon: const Icon(Icons.tune),
            tooltip: '设置',
          ),
          const SizedBox(width: Spacing.xs),
        ],
      ),
      body: SafeArea(child: viewBuilder(context, currentView)),
      // 没有新建动作时**整个不画** —— 一个点不动的悬浮按钮
      // 比没有按钮更让人困惑。
      floatingActionButton: onCreateTask == null
          ? null
          : FloatingActionButton(
              key: fabKey,
              onPressed: onCreateTask,
              backgroundColor: colors.brandFill,
              foregroundColor: colors.onBrand,
              tooltip: '新建任务',
              child: const Icon(Icons.add),
            ),
    );
  }
}

/// 视图切换器。
///
/// 只有一个视图时**整个隐藏** —— 一个选项的切换器是纯噪音，
/// 而且会让 M2 的界面显得像是坏了。
class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({
    required this.current,
    required this.available,
    required this.onSelected,
  });

  final ViewKind current;
  final List<ViewKind> available;
  final ValueChanged<ViewKind> onSelected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    if (available.length <= 1) {
      return Text(current.label, style: text.titleMedium);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final kind in available) ...[
            _ViewTab(
              kind: kind,
              selected: kind == current,
              onTap: () => onSelected(kind),
            ),
            const SizedBox(width: Spacing.xs),
          ],
        ],
      ),
    );
  }
}

class _ViewTab extends StatelessWidget {
  const _ViewTab({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final ViewKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      label: kind.label,
      child: InkWell(
        key: AppShell.viewTabKey(kind),
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.full),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Spacing.minTouchTarget),
          child: Center(
            widthFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.xs,
              ),
              child: Text(
                kind.label,
                style: text.titleMedium?.copyWith(
                  // 选中态**不只靠颜色**：同时改字重（§8.1 的原则）。
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  // 未选中**不是禁用**。用次级文字色（达标），
                  // 不用 disabledText —— 那个 2.34:1 只有失效控件才豁免，
                  // 而未选中的标签是能点的。
                  color: selected ? null : text.bodySmall?.color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

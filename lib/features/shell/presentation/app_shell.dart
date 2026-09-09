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
    this.header,
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

  /// 视图上方的常驻条（筛选条）。由组合根提供，外壳不认识它。
  final Widget? header;

  /// 点加号。**参数是加号自己的 context** —— 组合根要拿它当锚点，
  /// 把新建面板从这个按钮上长出来（`showCreateTaskMenu`）。
  ///
  /// 传 context 而不是让外壳自己弹面板：面板上那五样是 task feature
  /// 的概念，外壳不该认识它们（module-map §3，同 `viewBuilder`
  /// 与筛选条的处理）。
  final void Function(BuildContext fabContext)? onCreateTask;
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
      body: SafeArea(
        child: Column(
          children: [
            // 筛选条在外壳上、在视图**之上** —— view-specs §0.3：
            // 「顶部筛选条：同一个组件，同一份状态」。
            // 放进视图的话，四个视图会各挂一份，切过去会重建。
            //
            // 但外壳**不认识**它：那个组件属于 views 这个 feature，
            // 而 module-map §3 禁止跨 feature 引用 presentation。
            // 所以由组合根传进来 —— 与 viewBuilder 同一个道理。
            ?header,
            Expanded(child: viewBuilder(context, currentView)),
          ],
        ),
      ),
      // 没有新建动作时**整个不画** —— 一个点不动的悬浮按钮
      // 比没有按钮更让人困惑。
      floatingActionButton: onCreateTask == null
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: colors.cardShadow,
              ),
              child: Builder(
                // 单独包一层 `Builder`：`onCreateTask` 要的是**按钮自己**
                // 的 context（用来定位面板），而不是整个 Scaffold 的。
                builder: (fabContext) => FloatingActionButton(
                  key: fabKey,
                  onPressed: () => onCreateTask!(fabContext),
                  backgroundColor: colors.brandFill,
                  foregroundColor: colors.onBrand,
                  // Material 默认的 elevation 6 会在药丸边上压出一圈很硬的
                  // 深阴影，与 §6「不用锐利深阴影」的基调打架 ——
                  // golden 里那圈黑边一眼就能看见。
                  // 阴影统一由 token 画（cardShadow），这里关掉 Material 的。
                  elevation: 0,
                  highlightElevation: 0,
                  focusElevation: 0,
                  hoverElevation: 0,
                  // 正圆，不用 M3 默认的圆角方形 —— 后者偏硬，
                  // 与 §1「可爱清新」的基调不合。用 Radii.full 而不是写死
                  // `CircleBorder()`，是为了让它跟着圆角档位那套走
                  // （full 按 CornerStyle 的约定不参与缩放，永远是药丸/正圆）。
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      context.appShape.radius(Radii.full),
                    ),
                  ),
                  tooltip: '新建任务',
                  child: const Icon(Icons.add),
                ),
              ),
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

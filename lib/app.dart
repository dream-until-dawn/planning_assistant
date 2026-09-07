/// 应用根 + **组合根**：路由表、视图注册表、主题装配。
///
/// ## 为什么路由表在这里，而不在 `features/shell/`
///
/// module-map §1 把「导航、路由表」写在 `features/shell/` 名下，
/// 但 §3 同时禁止 `features/*/presentation` 引用**别的 feature 的**
/// `presentation`。而路由表按定义就要认识各个 feature 的页面 ——
/// 两条规矩放在一起，路由表不可能待在任何一个 feature 里。
///
/// 解法是把两件事拆开：
///
/// | | 在哪 | 认识什么 |
/// |---|---|---|
/// | 外壳**外观**（切换器 / FAB / 设置入口） | `features/shell/presentation` | 只认识 `ViewKind` 这个名字 |
/// | 路由表与**视图注册表** | 这里（组合根） | 认识所有页面 |
///
/// 组合根不在 `features/` 下，不属于任何 feature，因此可以同时依赖它们 ——
/// 这正是组合根该干的事。§3 那条规矩一个字没破。
///
/// 经过与结论记在 module-map §1。
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'design/theme/app_theme.dart';
import 'features/shell/presentation/app_shell.dart';
import 'features/task/presentation/task_editor_page.dart';
import 'features/views/shared/application/view_kind.dart';
import 'features/views/task_list/presentation/task_list_page.dart';

/// **视图注册表**（view-specs §7.3）。
///
/// 加一个视图 = 枚举加一项 + 这里加一行。外壳、路由表都不用动。
///
/// 键是当前版本**实装了的**视图，不是 `ViewKind.values` ——
/// 未实装的项由 `test/architecture/view_registry_test.dart` 盯着：
/// 要么在这里，要么在那份「已知未实现」名单里，
/// 不允许**两处都没有**（那会是一个点了没反应的按钮）。
final Map<ViewKind, Widget Function(BuildContext, VoidCallback?)> viewRegistry =
    {
      ViewKind.list: (context, onCreateTask) =>
          TaskListPage(onCreateTask: onCreateTask),
    };

/// 尚未实装的视图，M3 逐个搬进 [viewRegistry]。
///
/// 显式列出来，而不是让守卫去猜 —— 「没实现」和「忘了注册」
/// 在代码里长得一模一样，只有写下来才分得开。
const Set<ViewKind> unimplementedViews = {
  ViewKind.timeline,
  ViewKind.calendar,
  ViewKind.gantt,
};

/// 路由表（view-specs §7.2）。
///
/// `/task/:id/edit`、`/settings` 等做出来再加 ——
/// **不预先注册指向占位页的路由**：那种路由跳过去是一个假页面，
/// 比 404 更难查。
abstract final class AppRoutes {
  static const String shell = '/';
  static const String newTask = '/task/new';
}

GoRouter buildAppRouter() => GoRouter(
  routes: [
    GoRoute(
      path: AppRoutes.shell,
      builder: (context, state) => const _ShellRoute(),
      routes: [
        GoRoute(
          path: 'task/new',
          builder: (context, state) => TaskEditorPage(
            // 存完就回列表。**用 pop 而不是 go('/')**：
            // go 会把编辑器从栈上换掉，返回手势会直接退出应用；
            // pop 保留「从哪来回哪去」。
            onSaved: (_) => context.pop(),
          ),
        ),
      ],
    ),
  ],
);

class PlanningAssistantApp extends StatelessWidget {
  PlanningAssistantApp({super.key, GoRouter? router})
    : _router = router ?? buildAppRouter();

  /// 可注入，供测试从任意路由起步。
  final GoRouter _router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '计划助手',
      debugShowCheckedModeBanner: false,
      // 明暗双主题由 design/theme 装配。刻意不用 ColorScheme.fromSeed ——
      // 它会把低饱和色算成高饱和，破坏「可爱清新」基调（design-system §9）。
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: _router,
    );
  }
}

/// `/` 上的外壳。
///
/// 视图切换**不产生路由**（view-specs §7.2）：当前视图是这里的一个
/// 局部状态，改它不碰 `GoRouter`。共享的筛选、聚焦日期活在
/// `viewSharedStateProvider` 里，同样不随路由销毁。
class _ShellRoute extends StatefulWidget {
  const _ShellRoute();

  @override
  State<_ShellRoute> createState() => _ShellRouteState();
}

void _openEditor(BuildContext context) => context.go(AppRoutes.newTask);

class _ShellRouteState extends State<_ShellRoute> {
  // TODO(M2-设置): 初值改读配置项 `view.defaultView`
  //  （ViewKind.fromStorageKey 已经把「认不出的值」处理成回落，见 §7.4）
  ViewKind _current = ViewKind.fallback;

  @override
  Widget build(BuildContext context) {
    final available = viewRegistry.keys.toList();

    return AppShell(
      currentView: _current,
      availableViews: available,
      onViewSelected: (kind) => setState(() => _current = kind),
      viewBuilder: (context, kind) {
        final builder = viewRegistry[kind];
        // 注册表里没有 = 只可能是新加了枚举却忘了注册。
        // 架构守卫在测试期就会判失败，这里再兜一层，
        // 免得万一漏网时用户看到的是一片白。
        if (builder == null) {
          return Center(child: Text('「${kind.label}」还没做好'));
        }
        return builder(context, () => _openEditor(context));
      },
      onCreateTask: () => _openEditor(context),
      // TODO(M2-设置): 接上 /settings
      onOpenSettings: null,
    );
  }
}

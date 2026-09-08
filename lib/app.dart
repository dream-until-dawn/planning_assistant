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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'design/theme/app_theme.dart';
import 'domain/value_objects/occurrence_key.dart';
import 'features/settings/application/registry.dart';
import 'features/settings/application/settings_providers.dart';
import 'features/settings/presentation/category_manager_page.dart';
import 'features/settings/presentation/settings_page.dart';
import 'features/shell/presentation/app_shell.dart';
import 'features/task/application/task_editor_controller.dart';
import 'features/task/presentation/task_editor_page.dart';
import 'features/views/shared/application/view_kind.dart';
import 'features/views/shared/presentation/filter_bar.dart';
import 'features/views/task_list/presentation/task_list_page.dart';
import 'features/views/timeline/presentation/timeline_page.dart';

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
      ViewKind.list: (context, onCreateTask) => TaskListPage(
        onCreateTask: onCreateTask,
        // 路由由组合根接上 —— 视图自己不认识路由表。
        onEditTask: (id, {from}) =>
            context.go(AppRoutes.editTask(id, from: from)),
      ),
      ViewKind.timeline: (context, onCreateTask) => TimelinePage(
        onCreateTask: onCreateTask,
        onEditTask: (id, {from}) =>
            context.go(AppRoutes.editTask(id, from: from)),
      ),
    };

/// 尚未实装的视图，M3 逐个搬进 [viewRegistry]。
///
/// **由 `ViewKind.implemented` 推导，不再手写一份。** 手写两份的话，
/// 「哪些视图能用」就有了两个事实来源：注册表、这张名单、
/// 以及设置页的选项 —— 三处迟早分叉，而分叉的表现是
/// 「设置页能选，切过去白屏」。
final Set<ViewKind> unimplementedViews = ViewKind.values.toSet().difference(
  ViewKind.implemented,
);

/// 路由表（view-specs §7.2）。
///
/// `/task/:id/edit`、`/settings` 等做出来再加 ——
/// **不预先注册指向占位页的路由**：那种路由跳过去是一个假页面，
/// 比 404 更难查。
abstract final class AppRoutes {
  static const String shell = '/';
  static const String newTask = '/task/new';
  static const String settings = '/settings';

  /// 分类管理（FR-CFG-03）。设置页的**二级页**，所以挂在它下面 ——
  /// 返回手势该回到设置，不是回到列表。
  static const String categories = '/settings/categories';

  /// 编辑一条已有任务。
  ///
  /// [from] 非空时是「本次及以后」的分割点（FR-TASK-06）——
  /// 用查询参数而不是再开一条路由：它改的是**同一个页面的语义**，
  /// 不是另一个页面。
  static String editTask(String id, {String? from}) =>
      from == null ? '/task/$id/edit' : '/task/$id/edit?from=$from';
}

GoRouter buildAppRouter() => GoRouter(
  routes: [
    GoRoute(
      path: AppRoutes.shell,
      builder: (context, state) => const _ShellRoute(),
      routes: [
        GoRoute(
          path: 'settings',
          builder: (context, state) => SettingsPage(
            onOpenCategories: () => context.go(AppRoutes.categories),
          ),
          routes: [
            GoRoute(
              path: 'categories',
              builder: (context, state) => const CategoryManagerPage(),
            ),
          ],
        ),
        GoRoute(
          path: 'task/:id/edit',
          // **参数用一层 ProviderScope 注入**，不是传构造参数。
          //
          // 编辑器的初值在 Notifier 的 `build()` 里取（那样才只取一次，
          // 不会被后续的库推送冲掉填到一半的表单），而 `build()` 手上
          // 只有 ref —— 于是「正在编辑哪条」得是个 provider。
          //
          // 覆盖它是组合根的活：页面自己不认识路由（同外壳的
          // onOpenSettings、设置页的 onOpenCategories）。
          builder: (context, state) {
            final from = state.uri.queryParameters['from'];
            return ProviderScope(
              overrides: [
                editingTaskIdProvider.overrideWithValue(
                  state.pathParameters['id'],
                ),
                editingSplitAtProvider.overrideWithValue(
                  from == null ? null : OccurrenceKey.parse(from),
                ),
              ],
              child: TaskEditorPage(onSaved: (_) => context.pop()),
            );
          },
        ),
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

class PlanningAssistantApp extends ConsumerWidget {
  PlanningAssistantApp({super.key, GoRouter? router})
    : _router = router ?? buildAppRouter();

  /// 可注入，供测试从任意路由起步。
  final GoRouter _router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 明暗与圆角档位都是配置项 —— 根必须监听它们，
    // 否则在设置页改完要重启才生效。
    final corners = ref.setting(cornerStyle);
    final mode = ref.setting(themeMode);

    return MaterialApp.router(
      title: '计划助手',
      debugShowCheckedModeBanner: false,
      // **框架自带的界面也得说中文**（NFR-A11Y-04）。
      //
      // 不接这几行的话，日期选择器会弹出 `Select date` / `Cancel` / `OK`
      // 与英文月份名 —— 真机上就是这样，一个满屏中文的应用里突然一个
      // 英文对话框。`flutter_localizations` 早就在 pubspec 里，
      // 只是没接上代理。
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('zh'), Locale('en')],
      // **暂时钉死中文。** V1 首发只有中文文案（NFR-A11Y-04：
      // 文案全部走本地化资源是后话），此刻跟随系统语言的话，
      // 英文系统上会得到「中文正文 + 英文控件」的夹生界面 ——
      // 比全英文更难读。
      //
      // TODO(M4): 接上 l10n 资源后删掉这一行，改为跟随系统。
      locale: const Locale('zh'),
      // 明暗双主题由 design/theme 装配。刻意不用 ColorScheme.fromSeed ——
      // 它会把低饱和色算成高饱和，破坏「可爱清新」基调（design-system §9）。
      theme: AppTheme.light(corners: corners),
      darkTheme: AppTheme.dark(corners: corners),
      themeMode: switch (mode) {
        ThemeModeSetting.system => ThemeMode.system,
        ThemeModeSetting.light => ThemeMode.light,
        ThemeModeSetting.dark => ThemeMode.dark,
      },
      routerConfig: _router,
    );
  }
}

/// `/` 上的外壳。
///
/// 视图切换**不产生路由**（view-specs §7.2）：当前视图是这里的一个
/// 局部状态，改它不碰 `GoRouter`。共享的筛选、聚焦日期活在
/// `viewSharedStateProvider` 里，同样不随路由销毁。
class _ShellRoute extends ConsumerStatefulWidget {
  const _ShellRoute();

  @override
  ConsumerState<_ShellRoute> createState() => _ShellRouteState();
}

void _openEditor(BuildContext context) => context.go(AppRoutes.newTask);

class _ShellRouteState extends ConsumerState<_ShellRoute> {
  /// 用户在本次会话里手动切过的视图。
  ///
  /// **null 表示「还没切过」**，此时跟随配置项 `view.defaultView`。
  /// 一进来就把配置值抄进本地状态的话，用户在设置页改了默认视图，
  /// 已经开着的这一屏不会跟着变 —— 而他刚改完正等着看效果。
  ViewKind? _picked;

  @override
  Widget build(BuildContext context) {
    final available = viewRegistry.keys.toList();
    final configured = ref.setting(defaultView);
    // 配置的默认视图可能还没实装（M3 才有另外三个）——
    // 那时回落到实装了的第一个，而不是白屏。
    final current =
        _picked ??
        (available.contains(configured) ? configured : ViewKind.fallback);

    return AppShell(
      currentView: current,
      availableViews: available,
      onViewSelected: (kind) => setState(() => _picked = kind),
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
      // 筛选条由组合根提供 —— 它属于 views feature，外壳不该认识它
      // （module-map §3）。同 viewBuilder。
      header: const FilterBar(),
      onCreateTask: () => _openEditor(context),
      onOpenSettings: () => context.go(AppRoutes.settings),
    );
  }
}

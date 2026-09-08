/// 外壳整屏的视觉回归（测试策略 §7.1，快照型）。
///
/// 这是应用**第一个真正的界面**：冷启动看到的那一屏。
/// 断言在 `app_shell_test.dart`，这里只拍图。
///
/// 关于中文渲染成方框、以及这些图能证明什么不能证明什么，
/// 见 `design/task_card_golden_test.dart` 顶部那段。
@Tags(['golden'])
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/design/theme/app_theme.dart';
import 'package:planning_assistant/design/tokens/dimensions.dart';
import 'package:planning_assistant/domain/entities/category.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/views/shared/application/category_providers.dart';
import 'package:planning_assistant/features/views/shared/application/view_kind.dart';
import 'package:planning_assistant/features/views/task_list/application/task_list_providers.dart';
import 'package:planning_assistant/features/views/task_list/presentation/task_list_page.dart';

/// M2 的真实形态：只有列表一个视图，切换器因此不出现。
Widget _current(Brightness brightness, double scale) => _wrap(
  brightness,
  scale,
  AppShell(
    currentView: ViewKind.list,
    availableViews: const [ViewKind.list],
    onViewSelected: (_) {},
    onCreateTask: () {},
    onOpenSettings: () {},
    viewBuilder: (context, kind) => TaskListPage(onCreateTask: () {}),
  ),
);

/// M3 的形态：四个视图，切换器出现。
///
/// **提前拍这一张**，是因为切换器只在多视图时才渲染 ——
/// 只拍 M2 的样子，等 M3 加视图时才会第一次看见它长什么样。
Widget _withSwitcher(Brightness brightness, double scale) => _wrap(
  brightness,
  scale,
  AppShell(
    currentView: ViewKind.list,
    availableViews: ViewKind.values,
    onViewSelected: (_) {},
    onCreateTask: () {},
    onOpenSettings: () {},
    viewBuilder: (context, kind) => TaskListPage(onCreateTask: () {}),
  ),
);

/// golden 里的「今天」。2026-09-08 是周二 —— 让「本周」两侧都有东西。
const _today = PlanDate(2026, 9, 8);

/// golden 用的分类，与 `kDefaultCategories` 的固定 ID 对齐。
const _categories = [
  Category(
    id: 'cat-default-briefcase',
    name: '工作',
    colorArgb: 0xFF7FD1C1,
    icon: 'briefcase',
    orderIndex: 0,
  ),
  Category(
    id: 'cat-default-book',
    name: '学习',
    colorArgb: 0xFFA8C8F0,
    icon: 'book',
    orderIndex: 1,
  ),
  Category(
    id: 'cat-default-home',
    name: '生活',
    colorArgb: 0xFFFFB7C5,
    icon: 'home',
    orderIndex: 2,
  ),
];

/// 密集列表 + 超长文本（roadmap M2 验收要求 golden 覆盖这两种）。
///
/// 空态那张图好看是好看，但它**验不到列表本身** —— 卡片间距、
/// 时间标签的位置、超长标题截断、已完成的划线，一条都没进过图。
List<Task> _denseTasks() => [
  const Task(
    id: 't1',
    title: '买菜',
    kind: TaskKind.single,
    timeZoneId: 'Asia/Shanghai',
    isAllDay: true,
    // 挂真实分类，否则这张图里色条永远是「未分类」的中性灰 ——
    // 那样 §2.5 那套分类调色板一次都没进过 golden。
    categoryId: 'cat-default-home',
    planDate: _today,
  ),
  Task(
    id: 't2',
    title: '写季度总结',
    kind: TaskKind.single,
    timeZoneId: 'Asia/Shanghai',
    categoryId: 'cat-default-briefcase',
    startMinute: MinuteOfDay.of(9, 30),
    planDate: _today,
  ),
  Task(
    id: 't3',
    title: '交水电费',
    kind: TaskKind.single,
    timeZoneId: 'Asia/Shanghai',
    status: TaskStatus.done,
    startMinute: MinuteOfDay.of(10, 0),
    planDate: _today,
  ),
  Task(
    id: 't4',
    title: '把这个季度所有还没有归档的项目文档整理一遍并逐个确认负责人与截止日期',
    kind: TaskKind.single,
    timeZoneId: 'Asia/Shanghai',
    startMinute: MinuteOfDay.of(23, 59),
    // 逾期一条 —— 那个组默认折叠，图里要能看见「折叠 + 计数」长什么样。
    planDate: const PlanDate(2026, 9, 1),
  ),
  const Task(
    id: 't5',
    title: '读完这本书',
    kind: TaskKind.single,
    timeZoneId: 'Asia/Shanghai',
    categoryId: 'cat-default-book',
    isAllDay: true,
    planDate: PlanDate(2026, 9, 9),
  ),
];

/// 有任务的列表。
Widget _dense(Brightness brightness, double scale) => _wrap(
  brightness,
  scale,
  AppShell(
    currentView: ViewKind.list,
    availableViews: const [ViewKind.list],
    onViewSelected: (_) {},
    onCreateTask: () {},
    onOpenSettings: () {},
    viewBuilder: (context, kind) => TaskListPage(onCreateTask: () {}),
  ),
  tasks: _denseTasks(),
);

Widget _wrap(
  Brightness brightness,
  double scale,
  Widget child, {
  List<Task> tasks = const [],
}) => ProviderScope(
  // **直接覆盖列表数据源，不接真库。**
  //
  // 不给任何覆盖的话，列表读不到仓库，拍到的是「读库失败」那一屏 ——
  // 而 golden 会照常「通过」，只是拍错了东西。
  //
  // 而接真的内存库对 golden 来说是**多余的耦合**：这里要的只是
  // 一份确定的数据，仓库怎么过滤墓碑、怎么排序与这张图无关。
  // 真库还会带来 drift 取消订阅时那个零延时 timer，
  // 让测试末尾报「Pending timers」。仓库的真实行为由
  // `application/` 与集成测试去验，那才是它该被验的地方。
  overrides: [
    visibleTasksProvider.overrideWith((ref) => Stream.value(tasks)),
    // 分类同样直接覆盖 —— 理由同上：这张图要的是一份确定的数据，
    // 仓库怎么排序、怎么过滤墓碑与它无关。
    categoriesProvider.overrideWith((ref) => Stream.value(_categories)),
    // **「今天」必须钉死。** 不钉的话日期分组的标题会随着跑测试的日子变，
    // 今天拍的图明天就红 —— 而那种红看不出是代码变了还是日历翻页了。
    todayProvider.overrideWithValue(_today),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: child,
    ),
  ),
);

void main() {
  final cases = <String, Widget Function(Brightness, double)>{
    'shell': _current,
    'shell_switcher': _withSwitcher,
    'shell_dense': _dense,
  };

  for (final entry in cases.entries) {
    for (final brightness in Brightness.values) {
      for (final scale in FontScale.goldenScales) {
        final name =
            '${entry.key}_${brightness.name}_x${scale.toStringAsFixed(1)}';

        testWidgets(name, (tester) async {
          // 整屏用真实手机比例，不像组件那样按内容放大画布 ——
          // 要看的正是「内容在一屏里放不放得下」。
          await tester.binding.setSurfaceSize(const Size(390, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(entry.value(brightness, scale));
          await tester.pumpAndSettle();

          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/$name.png'),
          );
        });
      }
    }
  }
}

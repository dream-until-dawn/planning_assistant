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
import 'package:planning_assistant/app_providers.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/core/time/time_zone_resolver.dart';
import 'package:planning_assistant/design/theme/app_theme.dart';
import 'package:planning_assistant/design/tokens/dimensions.dart';
import 'package:planning_assistant/domain/entities/category.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/value_objects/recurrence.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/views/shared/application/category_providers.dart';
import 'package:planning_assistant/features/views/shared/application/task_providers.dart';
import 'package:planning_assistant/features/views/shared/application/view_kind.dart';
import 'package:planning_assistant/features/views/shared/presentation/filter_bar.dart';
import 'package:planning_assistant/features/views/task_list/presentation/task_list_page.dart';
import 'package:timezone/data/latest.dart' as tzdata;

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
    // 筛选条是外壳的一部分（组合根传进来的）—— 不传的话，
    // 拍到的是一个线上不存在的配置。
    header: const FilterBar(),
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
    // 筛选条是外壳的一部分（组合根传进来的）—— 不传的话，
    // 拍到的是一个线上不存在的配置。
    header: const FilterBar(),
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

/// **每一个字段都长**的一屏（roadmap M2 验收的「超长文本」那一档）。
///
/// 密集那张图里只有标题是长的，其余照常 —— 而按 §1.5 的教训，
/// 参数化一个维度、钉死另一个维度证明不了什么：卡片会不会挤爆，
/// 取决于标题、分类名、重复说明、时间标签**同时**变长。
///
/// 这里让它们一起长：
///
///  · 标题：两行都装不下，要看省略号截在哪；
///  · 分类名：副信息那一行只有一行且会截断；
///  · 重复说明：分类名后面还要接「每 3 周的一、二、…」；
///  · 时间标签：长到必须下沉（`_timeCrowdsTitle`）。
List<Task> _longTextTasks() => [
  Task(
    id: 'l1',
    title:
        '把这个季度所有还没有归档的项目文档整理一遍并且逐个确认负责人'
        '与截止日期然后同步给团队里的每一个人确保没有遗漏',
    kind: TaskKind.single,
    timeZoneId: 'Asia/Shanghai',
    categoryId: 'cat-long',
    startMinute: MinuteOfDay.of(23, 59),
    planDate: _today,
    recurrence: Recurrence.parse(
      'RRULE:FREQ=WEEKLY;INTERVAL=3;BYDAY=MO,TU,WE,TH,FR,SA,SU',
    ),
  ),
  Task(
    id: 'l2',
    title: '一个很长很长很长很长很长很长很长很长很长很长很长的已完成任务标题',
    kind: TaskKind.single,
    timeZoneId: 'Asia/Shanghai',
    categoryId: 'cat-long',
    status: TaskStatus.done,
    completedAt: DateTime.utc(2026, 9, 8),
    startMinute: MinuteOfDay.of(9, 0),
    planDate: _today,
  ),
  const Task(
    id: 'l3',
    title: 'ThisIsOneVeryLongUnbrokenLatinWordThatCannotWrapAnywhereAtAll',
    kind: TaskKind.single,
    timeZoneId: 'Asia/Shanghai',
    categoryId: 'cat-long',
    isAllDay: true,
    // 逾期一条：那一组默认折叠，图里要能看见「折叠 + 计数」。
    planDate: PlanDate(2026, 9, 1),
  ),
];

/// 分类名也长 —— 副信息那一行是「分类 · 重复说明 · 阶段」拼出来的。
const _longCategory = Category(
  id: 'cat-long',
  name: '一个名字特别长的分类比如说家里那些琐碎的事情',
  colorArgb: 0xFFC3B5F0,
  icon: 'home',
  orderIndex: 9,
);

Widget _longText(Brightness brightness, double scale) => _wrap(
  brightness,
  scale,
  AppShell(
    currentView: ViewKind.list,
    availableViews: const [ViewKind.list],
    onViewSelected: (_) {},
    onCreateTask: () {},
    onOpenSettings: () {},
    header: const FilterBar(),
    viewBuilder: (context, kind) => TaskListPage(onCreateTask: () {}),
  ),
  tasks: _longTextTasks(),
  categories: [..._categories, _longCategory],
);

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
    // 筛选条是外壳的一部分（组合根传进来的）—— 不传的话，
    // 拍到的是一个线上不存在的配置。
    header: const FilterBar(),
    viewBuilder: (context, kind) => TaskListPage(onCreateTask: () {}),
  ),
  tasks: _denseTasks(),
);

Widget _wrap(
  Brightness brightness,
  double scale,
  Widget child, {
  List<Task> tasks = const [],
  List<Category> categories = _categories,
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
    categoriesProvider.overrideWith((ref) => Stream.value(categories)),
    // 展开重复任务要用到时区换算器；这些夹具都不重复，但那一步照读。
    timeZoneResolverProvider.overrideWithValue(
      const TzTimeZoneResolver(fixedCurrentZoneId: 'Asia/Shanghai'),
    ),
    allOverridesProvider.overrideWith((ref) => Stream.value(const [])),
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
  // 长文本那一屏里有条重复任务（副信息要长，得靠规则说明撑）——
  // 展开它要按墙钟算，没有时区库会抛 UnknownTimeZoneException，
  // 而那个异常发生在 build 里，表现是「读库失败」那一屏被拍下来。
  setUpAll(tzdata.initializeTimeZones);

  final cases = <String, Widget Function(Brightness, double)>{
    'shell': _current,
    'shell_switcher': _withSwitcher,
    'shell_dense': _dense,
    'shell_longtext': _longText,
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

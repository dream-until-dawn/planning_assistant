/// Widget 测试用的应用装配。
///
/// **用真的仓库 + 内存 SQLite，不写假仓库。**
///
/// 假仓库要手写十来个方法，而且它的行为是我们**以为**的行为 ——
/// 真实现里 `watchTasks` 会过滤墓碑、按什么排序、写入后多久推新值，
/// 假的一概不知道。这些恰恰是「建任务 → 列表可见」要验的东西。
/// 内存库跑在同一个进程里，快到可以每个用例开一个。
library;

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:planning_assistant/app_providers.dart';
import 'package:planning_assistant/core/id/id_generator.dart';
import 'package:planning_assistant/core/time/clock.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/core/time/time_zone_resolver.dart';
import 'package:planning_assistant/data/database/app_database.dart';
import 'package:planning_assistant/data/database/dao/synced_dao.dart';
import 'package:planning_assistant/data/repositories/category_repository_impl.dart';
import 'package:planning_assistant/data/repositories/settings_repository_impl.dart';
import 'package:planning_assistant/data/repositories/task_repository_impl.dart';
import 'package:planning_assistant/domain/commands/command_dispatcher.dart';
import 'package:planning_assistant/domain/entities/category.dart';
import 'package:planning_assistant/domain/entities/stage.dart';
import 'package:planning_assistant/domain/entities/stage_occurrence_state.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/features/settings/application/settings_providers.dart';
import 'package:planning_assistant/features/views/shared/application/category_providers.dart';
import 'package:planning_assistant/features/views/shared/application/task_providers.dart';
import 'package:planning_assistant/features/views/shared/presentation/filter_bar.dart';
import 'package:planning_assistant/features/views/shared/presentation/filter_sheet.dart';
import 'package:planning_assistant/features/views/timeline/application/timeline_providers.dart';
import 'package:timezone/data/latest.dart' as tzdata;

/// 一套装好的依赖，供 `ProviderScope(overrides: ...)` 使用。
typedef Harness = ({List<Override> overrides, AppDatabase db});

/// 装一套跑在内存库上的依赖。
///
/// [now] 与 [zone] 固定住，于是「今天是哪天」在测试里是确定的 ——
/// 用系统时钟的话，跨零点跑 CI 会得到不同结果。
Harness appHarness({
  DateTime? now,
  String zone = 'Asia/Shanghai',
  IdGenerator? idGenerator,
  bool advancingClock = false,
}) {
  // 时区数据库是**全局**的，且 TzTimeZoneResolver 没有它会抛
  // UnknownTimeZoneException —— 而那个异常发生在 build 里，
  // 表现是「页面构建失败」，离真正的原因隔了好几层。
  // 幂等，重复调用无害。
  tzdata.initializeTimeZones();

  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);

  // **默认钉死时钟**，于是「今天是哪天」在测试里是确定的。
  //
  // 但钉死的时钟量不了「时间有没有往前走」这一类事 —— 比如
  // 「已完成阶段的完成时刻不该随每次保存漂移」：把 `completedAt` 一律
  // 盖成 `now()` 的实现，在钉死的时钟下与正确实现**给出同一个值**，
  // 那条测试于是永远绿。撞见过一次，所以留这个口子。
  //
  // 每次读往前走一秒：足够区分两次写入，又不会跨过零点把「今天」改掉。
  final base = now ?? DateTime.utc(2026, 9, 7, 3);
  final clock = advancingClock ? _AdvancingClock(base) : FixedClock(base);
  final repository = DriftTaskRepository(
    db,
    const FixedWriterIdentity('test-device'),
    clock,
  );

  return (
    db: db,
    overrides: [
      clockProvider.overrideWithValue(clock),
      timeZoneResolverProvider.overrideWithValue(
        TzTimeZoneResolver(fixedCurrentZoneId: zone),
      ),
      // 确定性 ID：断言里能直接写出期望值，也让失败信息可读。
      idGeneratorProvider.overrideWithValue(
        idGenerator ?? SequentialIdGenerator(prefix: 'task'),
      ),
      taskRepositoryProvider.overrideWithValue(repository),
      taskCommandDispatcherProvider.overrideWithValue(
        CommandDispatcher(repository, clock),
      ),
      categoryRepositoryProvider.overrideWithValue(
        DriftCategoryRepository(
          db,
          const FixedWriterIdentity('test-device'),
          clock,
        ),
      ),
      settingsRepositoryProvider.overrideWithValue(
        DriftSettingsRepository(
          db,
          const FixedWriterIdentity('test-device'),
          clock,
        ),
      ),
    ],
  );
}

/// 每读一次就往前走一秒的时钟。见 [appHarness] 的 `advancingClock`。
final class _AdvancingClock implements Clock {
  _AdvancingClock(this._at);

  DateTime _at;

  @override
  DateTime nowUtc() {
    final value = _at;
    _at = _at.add(const Duration(seconds: 1));
    return value;
  }
}

/// 拆掉 widget 树，并把 drift 取消订阅时排的那个零延时 timer 跑掉。
///
/// 不做这一步，用真仓库的 widget 测试会在末尾报
/// **「Pending timers」**：`ProviderScope` 销毁时取消 drift 的查询流，
/// `StreamQueryStore.markAsClosed` 会排一个 `Timer(Duration.zero)`，
/// 而那时已经没有 pump 让它跑完了。
///
/// 这不是「测试框架太挑剔」——它挑的是对的：一个还没跑完的 timer
/// 意味着有异步工作没收尾，放着不管迟早变成用例之间互相污染。
Future<void> disposeTree(WidgetTester tester) async {
  // 拆树 —— ProviderScope 在这一帧销毁，drift 的流被取消。
  await tester.pumpWidget(const SizedBox.shrink());
  // 取消是在一个异步续体里完成的，那个 Timer(Duration.zero) 排在
  // **下一次**微任务清空之后 —— 所以一次 pump 够不着，要再走两帧。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
}

/// 跑一条用真库的 widget 用例，**无论成败都拆树**。
///
/// ## 为什么不是在用例末尾手写 [disposeTree]
///
/// 手写的那一句**失败时不会执行** —— 断言一抛，后面的代码就不跑了。
/// 树留在那儿带着 drift 的订阅和一个待触发的 timer，于是下一条用例
/// 撞上 `!inTest` 断言，再下一条「did not complete」，整个文件
/// 卡到十分钟超时才收场。后果不是慢，是**报错指错了地方**：
/// 一次真实的回归表现成「后面五条莫名其妙全红」，真正坏的是第一条。
/// 变异演练里撞见过一次，六分半。
///
/// ## 为什么不是 `addTearDown`
///
/// 试过，不行。`AutomatedTestWidgetsFlutterBinding` 的 `!timersPending`
/// 断言在**用例体一结束**就跑，排在 tearDown **前面** ——
/// 登记成 tearDown 等于永远迟一步，每条用例都会报
/// 「A Timer is still pending even after the widget tree was disposed」。
/// 所以收尾必须发生在用例体**之内**，也就是这里的 `finally`。
@isTest
void testAppWidgets(
  String description,
  Future<void> Function(WidgetTester) body,
) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      try {
        await disposeTree(tester);
      } catch (_) {
        // 收尾自己炸了不该盖掉用例真正的失败原因（`finally` 里抛出的异常
        // 会顶替掉原来那个）。真漏了 timer 的话，binding 自己那条
        // `!timersPending` 断言照样会报，这里吞掉不会少报什么。
      }
    }
  });
}

/// 视图流水线要的一整套 override，**喂固定数据、不开库**。
///
/// 三处测试原本各自手写一份（外壳、列表页、外壳 golden）。
/// 展开重复任务那次给流水线加了两个新依赖（时区换算器、例外流），
/// **三处一起红**，而报错是「provider 处于错误状态」——
/// 离「少了个 override」隔着两层。
///
/// 集中在这里：以后流水线再多一个依赖，只改这一处。
///
/// 名字里一度写着「列表」。时间轴接上来之后用的是同一套 ——
/// 那不是复用了列表的东西，是它们本来就共享同一个数据源
/// （view-specs §0.2）。
List<Override> viewPipelineOverrides({
  List<Task> tasks = const [],
  List<Category> categories = const [],
  List<Stage> stages = const [],

  /// 「这一次的这一步做完没有」（FR-TASK-07）。
  List<StageOccurrenceState> stageStates = const [],
  Map<String, Object?> settings = const {},
  // 下面两个是**替换**用的口子，不是另加一条 override ——
  // 同一个 provider 在一个容器里只许覆盖一次，追加会撞上
  // 「Tried to override a provider twice」，而那条报错指的是
  // `_FocusInheritedScope`，跟真正的原因隔着整棵树。
  Stream<List<Task>>? tasksStream,
  Stream<void> tick = const Stream<void>.empty(),
  required PlanDate today,
}) {
  // 这里发的是 `TzTimeZoneResolver`，而它没有时区库就抛
  // `UnknownTimeZoneException`。同 `appHarness()` 里那段 ——
  // 放在**发放解析器的地方**，而不是让每个测试文件自己记得 setUpAll：
  // 忘了的表现是「当前时刻线没画出来」，隔着三层才追得到时区上。
  tzdata.initializeTimeZones();
  return [
    // **配置也要给。** 不给的话 `settingsRepositoryProvider` 抛
    // 「必须在 overrides 中提供」，而配置的解析层对错误是**回落到默认值**
    // 的（`_resolve` 的 `_ => const {}`）—— 于是界面看着完全正常，
    // 每条 widget 测试却都在跑错误分支，还各留一个 Riverpod 的重试定时器。
    // 撞见它是因为一个用显式容器的用例报了「Pending timers」，
    // 而那与被测的行为毫无关系。
    rawSettingsProvider.overrideWith((ref) => Stream.value(settings)),
    visibleTasksProvider.overrideWith(
      (ref) => tasksStream ?? Stream.value(tasks),
    ),
    categoriesProvider.overrideWith((ref) => Stream.value(categories)),
    allOverridesProvider.overrideWith((ref) => Stream.value(const [])),
    allStagesProvider.overrideWith((ref) => Stream.value(stages)),
    allStageStatesProvider.overrideWith((ref) => Stream.value(stageStates)),
    // **心跳掐掉。** 真的那个每分钟响一次，而它在用例结束时
    // 还剩着一个最多 60 秒的定时器 —— binding 判「树都拆了还有定时器在」，
    // 报的是「Pending timers」，与被测的行为毫无关系。
    //
    // 要验当前时刻线**会动**的用例自己覆盖成一个受控的流。
    minuteTickProvider.overrideWithValue(tick),
    // 展开按墙钟进行，要时区换算器。夹具里的任务多数不重复，
    // 但展开那一步照样会读它。
    timeZoneResolverProvider.overrideWithValue(
      const TzTimeZoneResolver(fixedCurrentZoneId: 'Asia/Shanghai'),
    ),
    // **「今天」必须钉死**，否则日期分组会随跑测试的日子变 ——
    // 今天绿明天红，而那种红看不出是代码变了还是日历翻页了。
    todayProvider.overrideWithValue(today),
  ];
}

/// 把视图流水线的几条流**等到有值**再往下走。
///
/// ## 为什么需要它
///
/// 流水线的输入全是 `StreamProvider`（任务、例外、阶段、分类、配置）。
/// 在 `ProviderContainer` 建好之后**同步**读下游，读到的是
/// `AsyncLoading` 那一支 —— 而每一处的 loading 回落都是刻意设计成
/// 「看起来正常」的：任务给空表、配置给默认值。
///
/// 于是断言会失败在一个完全无关的地方（「一周从周日起，却从周一起了」），
/// 真正的原因是那一帧配置还没到。这与之前 `settingsRepositoryProvider`
/// 没覆盖时是同一种错觉：**错误/未就绪分支被设计得跟正常态一模一样。**
///
/// widget 测试里 `pumpAndSettle` 顺手解决了这件事，所以只有纯
/// container 测试会撞上。
/// **必须先挂上监听再等。** `container.read(p.future)` 单用不行：
/// `read` 不持有订阅，元素在 loading 状态下当场被回收，那个 future
/// 于是永远不完成 —— 表现是用例卡到 30 秒超时，报
/// 「disposed during loading state」，与被测的东西毫无关系。
Future<void> settleViewPipeline(ProviderContainer container) async {
  void keep<T>(ProviderListenable<T> provider) =>
      container.listen<T>(provider, (_, _) {});

  keep(visibleTasksProvider);
  keep(allOverridesProvider);
  keep(allStagesProvider);
  keep(allStageStatesProvider);
  keep(categoriesProvider);
  keep(rawSettingsProvider);
  await pumpEventQueue();
}

/// 设定测试里的「屏幕」。**两处都要设。**
///
/// `setSurfaceSize` 只改渲染视口，改不到 `tester.view` ——
/// 而 `MediaQuery` 是从 `tester.view` 来的。只设前者的话，
/// 应用**按 390×844 布局**，`MediaQuery` 却报测试默认的
/// 2400×1800@3.0 = **800×600 横屏**。
///
/// 于是任何按 `MediaQuery` 的尺寸或朝向分支的东西都走错分支，
/// 而且**布局本身看不出异常**（没有溢出、没有报错）。
/// 撞见的形态：Material 的时间选择器选了**横屏版式**，「确定」落在
/// x≈424，屏幕却只有 390 宽 —— 点不着；而失败信息说的是
/// 「保存之后页面还在」，隔着三层。
///
/// 顺带把 dpr 设成 1，让逻辑像素与传进来的数一致 ——
/// 否则「390」到底是逻辑还是物理，每次都要重新想一遍。
/// **要 await**：`setSurfaceSize` 是受保护的异步 API，
/// 不等它就 `pumpWidget` 会撞上「Guarded function conflict」。
Future<void> setScreenSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    return tester.binding.setSurfaceSize(null);
  });
}

/// 点一个控件，**先把它滚进可视区**。
///
/// `ListView` 的 cacheExtent 会在视口外先把控件建出来，于是
/// `find.byKey` 找得到、而 `tap` 算出的坐标落在视口外 ——
/// 那一下点在了底部固定的保存按钮上：任务直接存了、页面弹回列表，
/// 随后的断言报的却是「找不到某个控件」。看起来完全不像「控件在屏幕外」。
///
/// 这个坑犯过两次：第二次是表单里多加了一行「有结束时间」，
/// 把重复区往下挤了 56 像素，两条与结束时间毫无关系的用例一起红了。
/// 所以放进 support，别再各文件自己写一遍。
Future<void> tapVisible(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  if (finder.evaluate().isEmpty) {
    // **还没被建出来**，`ensureVisible` 救不了 —— 它要先拿到 element，
    // 而离屏太远的项在 `ListView` 里压根没建，报的是「Bad state: No
    // element」。这时得先滚过去把它建出来。
    //
    // 撞见过一次：设置页加了两个配置项之后，「分类管理」那一行被挤出
    // cacheExtent，**七条与设置毫无关系的用例一起红**。
    // **必须指定滚哪个** —— 不指定时它要求全树只有一个 `Scrollable`，
    // 而每个 `TextField` 自己带一个（`EditableText` 里的）。
    // 表单里有输入框时就会炸成「Bad state: Too many elements」，
    // 而那句话跟「控件在屏幕外」一点关系都没有。
    //
    // 取 `.first`：`find.byType` 是深度优先，表单的 `ListView` 是那些
    // 输入框的祖先，所以它排在前面。
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// 在筛选条上勾/取消某一项，然后把弹层收起来。
///
/// 筛选从「一排 Chip」改成「每维一个按钮 + 多选弹层」之后，勾一项
/// 变成了三步（开、点、关）。**把这三步收成一个函数**，而不是让
/// 每个用例各写一遍 —— 它们关心的是「筛了这一项之后列表变成什么样」，
/// 不是弹层怎么开。
///
/// 弹层**不会点一下就关**（多选的意义就在于连着选几项），
/// 所以这里显式按「完成」。
Future<void> toggleFilter(
  WidgetTester tester,
  FilterDimension dimension,
  Key option,
) async {
  await tapVisible(tester, FilterBar.dimensionKey(dimension));
  await tapVisible(tester, option);
  await tester.tap(find.byKey(FilterSheet.doneKey(dimension)));
  await tester.pumpAndSettle();
}

/// 写入默认分类。
///
/// **`appHarness()` 不自动做** —— 它是同步的，而播种要落库。
/// 更要紧的是：有没有分类是个**测试要显式表态**的事。
/// 自动播种的话，「空库时列表怎么显示」这类用例会莫名其妙有四个分类，
/// 而作者不会注意到。
Future<void> seedCategories(Harness harness) => DriftCategoryRepository(
  harness.db,
  const FixedWriterIdentity('test-device'),
  FixedClock(DateTime.utc(2026, 9, 7, 3)),
).seedDefaultsIfEmpty();

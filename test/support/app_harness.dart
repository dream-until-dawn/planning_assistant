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
import 'package:flutter/material.dart';
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
import 'package:planning_assistant/data/dto/export_bundle.dart';
import 'package:planning_assistant/data/repositories/category_repository_impl.dart';
import 'package:planning_assistant/data/repositories/settings_repository_impl.dart';
import 'package:planning_assistant/data/repositories/task_repository_impl.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/domain/commands/command_dispatcher.dart';
import 'package:planning_assistant/domain/entities/category.dart';
import 'package:planning_assistant/domain/entities/stage.dart';
import 'package:planning_assistant/domain/entities/stage_occurrence_state.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/features/data_transfer/application/backup_providers.dart';
import 'package:planning_assistant/features/reminder/application/reminder_providers.dart';
import 'package:planning_assistant/features/settings/application/settings_providers.dart';
import 'package:planning_assistant/features/settings/domain/setting_spec.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/task/application/task_shape.dart';
import 'package:planning_assistant/features/task/presentation/create_task_menu.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';
import 'package:planning_assistant/features/views/shared/application/category_providers.dart';
import 'package:planning_assistant/features/views/shared/application/task_providers.dart';
import 'package:planning_assistant/features/views/shared/presentation/filter_bar.dart';
import 'package:planning_assistant/features/views/shared/presentation/filter_sheet.dart';
import 'package:planning_assistant/features/views/task_list/presentation/occurrence_actions_sheet.dart';
import 'package:planning_assistant/features/views/timeline/application/timeline_providers.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import 'fake_backup.dart';
import 'fake_notifications.dart';

/// 一套装好的依赖，供 `ProviderScope(overrides: ...)` 使用。
typedef Harness = ({
  List<Override> overrides,
  AppDatabase db,

  /// 假的通知平台。**排期到底有没有真的发生**问它 ——
  /// 那是这块功能最容易悄悄断掉的地方（见 `reminder_providers.dart` 的头注）。
  FakeNotificationPlatform notifications,

  /// 内存里的备份目录。备份/恢复/保留策略有没有真的发生，问它。
  InMemoryBackupStore backups,
});

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

  final notifications = FakeNotificationPlatform();
  // 落盘换成内存，**导出不换** —— 换掉导出的话，
  // 「备份 → 恢复 → 数据还在」验的就是假实现的往返了。
  final backups = InMemoryBackupStore(now: base);

  return (
    db: db,
    notifications: notifications,
    backups: backups,
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
      // 提醒这一块：平台与排期存储都换成记账式的假实现。
      //
      // **必须在这儿给**，不是「顺手加的」：`ReminderSyncScope` 挂在
      // `MaterialApp.builder` 上，于是**每一个** widget 测试都会走一轮续排。
      // 不给的话它们会齐刷刷地撞上组合根那条 `mustOverride`。
      notificationPlatformProvider.overrideWithValue(notifications),
      scheduledNotificationStoreProvider.overrideWithValue(
        InMemoryScheduledNotificationStore(),
      ),
      // 备份这一块。**同上一条，必须在这儿给**：`AutoBackupScope`
      // 也挂在 `MaterialApp.builder` 上，于是每一个 widget 测试都会
      // 走一轮「该不该自动备份」。不给的话它们会齐刷刷撞上
      // 组合根那条 `mustOverride`。
      exportPortProvider.overrideWithValue(
        JsonExportAdapter(ExportService(db)),
      ),
      backupStoreProvider.overrideWithValue(backups),
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

  /// 时钟。**从这儿传，不要在外面再加一条 override** ——
  /// 同一个 provider 在一个容器里只许覆盖一次，追加会撞上
  /// 「Tried to override a provider twice」，而那条报错指的是
  /// `_FocusInheritedScope`，跟真正的原因隔着整棵树（同上面那两条口子）。
  Clock? clock,
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
    // 提醒的续排挂在 `MaterialApp.builder` 上，所以**用这套 override
    // 装起来的树也会走一轮**。它要读时钟与那两个协作者 ——
    // 不给的话报的是「clockProvider 必须在 overrides 中提供」，
    // 而那句话离「你少给了通知的假实现」隔着两层。
    clockProvider.overrideWithValue(
      clock ?? FixedClock(DateTime.utc(2026, 9, 7, 3)),
    ),
    notificationPlatformProvider.overrideWithValue(FakeNotificationPlatform()),
    scheduledNotificationStoreProvider.overrideWithValue(
      InMemoryScheduledNotificationStore(),
    ),
    // 自动备份同样挂在 `MaterialApp.builder` 上。这套夹具**没有真库**
    // （喂的是固定数据），所以导出也只能是假的 —— 备份自己的用例走
    // `appHarness`，那里发的是真的 `JsonExportAdapter`。
    exportPortProvider.overrideWithValue(FakeExportPort()),
    backupStoreProvider.overrideWithValue(InMemoryBackupStore()),
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

/// 点一行卡片，再从动作抽屉里进编辑页。
///
/// 点一下直接进编辑那条路没有了（用户第①条：两种任务同一套动作），
/// 所以「打开编辑」变成了两步。收成一个夹具 ——
/// 用例关心的是「编辑页里是什么」，不是抽屉怎么开。
///
/// 不重复的任务走「编辑」，某一次走「编辑整条重复任务」。
Future<void> openEditorFromCard(WidgetTester tester, {Finder? card}) async {
  await tester.tap(card ?? find.byType(TaskCard).first);
  await tester.pumpAndSettle();
  final single = find.byKey(OccurrenceSheetKeys.edit);
  await tapVisible(
    tester,
    single.evaluate().isEmpty
        ? OccurrenceSheetKeys.editSeries
        : OccurrenceSheetKeys.edit,
  );
}

/// 往库里写一条配置，然后等一帧让它流回界面。
///
/// 全应用的夹具（[appHarness]）里配置存在库里，没有 `settings:` 那种
/// 直接注入的口子 —— 那个口子在 `viewPipelineOverrides` 上，
/// 而那套夹具没有真的写路径。
///
/// **在 `pumpWidget` 之后调**：容器要先建起来才拿得到仓库。
Future<void> seedSetting<T>(
  WidgetTester tester,
  SettingSpec<T> spec,
  T value,
) async {
  // 锚在 `Navigator` 上：它一定在 `ProviderScope` **下面**。
  // 锚在 scope 自己身上的话 `containerOf` 会往上找、然后报
  // 「No ProviderScope found」。
  final container = ProviderScope.containerOf(
    tester.element(find.byType(Navigator).first),
  );
  await container.read(settingsWriterProvider).set(spec, value);
  await tester.pumpAndSettle();
}

/// 退回上一页。
///
/// **不用 `tester.pageBack()`** —— 它找的是 `tooltip == 'Back'` 的按钮，
/// 而这个应用钉死了中文（`app.dart` 的 `locale: Locale('zh')`），
/// AppBar 自动加的那个返回键 tooltip 是「返回」。于是 `pageBack()` 报
/// 「Could not find a suitable back button」，而那句话听起来像
/// 「这一页没有返回键」—— 它明明有。
///
/// 取 `.first`：一个二级页的树里可能同时有上一层的返回键。
Future<void> tapBack(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton).first);
  await tester.pumpAndSettle();
}

/// 绕开 [SettingSpec] 往库里写一个**原始值**。
///
/// [seedSettingBeforeApp] 走的是声明，写不进类型不对的值 ——
/// 而「手改过的配置文件」正是要写那种值（settings-spec §5 允许
/// 用户改配置文件，也就允许他改错）。
Future<void> seedRawSetting(Harness harness, String key, Object? value) =>
    DriftSettingsRepository(
      harness.db,
      const FixedWriterIdentity('test-device'),
      FixedClock(DateTime.utc(2026, 9, 7, 3)),
    ).put(key, value, scope: 'global');

/// 把当前那条 Snackbar 等到消失。
///
/// **Snackbar 是排队的**：前一条还在，后一条就不会出现。而
/// `pumpAndSettle` **等不掉它** —— 显示中的 Snackbar 靠一个定时器收尾，
/// 期间并没有一直在排帧，于是 settle 当场就返回了。
///
/// 症状是「按了第二个按钮却看不到它的提示」，而真正杵在那儿的是
/// 第一条提示。备份页那两条（备份 → 恢复）撞见过一次。
Future<void> waitOutSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

/// 在**树建起来之前**往库里写一项配置。
///
/// ## 为什么不能用 [seedSetting]
///
/// 那一个要先有容器（它从 `Navigator` 上取），也就是说应用已经启动过了。
/// 而有些行为只发生在**启动那一刻**：自动备份就是 —— 「关掉之后启动
/// 不该备份」这条用例，配置必须在第一帧之前就在库里，
/// 否则摆不出前提，那条用例会验成「备了一份之后把开关关掉」。
///
/// **在 `pumpWidget` 之前调**。
Future<void> seedSettingBeforeApp<T>(
  Harness harness,
  SettingSpec<T> spec,
  T value,
) => DriftSettingsRepository(
  harness.db,
  const FixedWriterIdentity('test-device'),
  FixedClock(DateTime.utc(2026, 9, 7, 3)),
).put(spec.key, spec.encode(value), scope: spec.scope.wireName);

/// 点加号、在面板上选一样，落到新建表单上。
///
/// 加号改成「先选形态再进表单」之后（FR-TASK-01/02/03），
/// 「点加号就到表单」这一步没有了 —— 全项目 67 处 `tap(fabKey)`
/// 都要多走一步。收成一个夹具，而不是每处各写两行。
///
/// 默认选**临时事项**：它什么都不必填，与改动之前那张空白表单等价，
/// 所以「只是想建一条任务」的用例换过来之后行为不变。
/// 用例的主题**就是**某一种形态时，显式传那一样。
Future<void> tapCreate(
  WidgetTester tester, [
  TaskShape shape = TaskShape.scratch,
]) async {
  await tester.tap(find.byKey(AppShell.fabKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(createShapeKey(shape)));
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

/// 在打开的编辑器里加一个阶段：填标题，并**给它一个时间**。
///
/// ## 为什么时间要一起给
///
/// 用户 2026-09-10「加强必填项校验」之后，**阶段事项的每个阶段都必须有
/// 时间** —— 任务的起止就是从它们推出来的，一个没有时间的阶段等于
/// 一段推不出来的跨度。不给时间的话保存键是灰的。
///
/// 而这一族用例里的绝大多数**不关心时间本身**（它们验的是进度、级联、
/// 拖拽重排、提醒续排）。让每个文件各自去点那个对话框，等于把一条
/// 与它们无关的必填规则抄十遍 —— 下次规则再变，又是十处。
///
/// 时间取对话框的默认值（相对任务开始 +0，时长 60），于是**几个阶段
/// 完全重叠**。
///
/// ⚠️ **这一点的影响面比「取最早/最晚那一族」大**（评审 S-4）：
/// 任何断言依赖**阶段之间位置关系**的用例都会在这种输入上退化 ——
/// 甘特分段就是一个不在那一族里、却同样被抹平的例子（三段全塌在
/// 同一个小时上，「有三段」和「进度三分之一」照旧全绿）。
///
/// 而它现在**九个文件共用**：一个夹具默认值成了许多用例灵敏度的单点。
/// 要位置关系的用例请用 [setStageDay] 拆开，并把「拆开了」钉成前提。
///
/// [withTime] 传 false 是给**专门验「没时间就不能存」**的用例用的。
Future<void> addStage(
  WidgetTester tester,
  String title, {
  bool withTime = true,
}) async {
  await tapVisible(tester, TaskEditorPage.addStageKey);
  final fields = find.descendant(
    of: find.byKey(TaskEditorPage.stageSectionKey),
    matching: find.byType(TextField),
  );
  await tester.enterText(fields.last, title);
  await tester.pumpAndSettle();
  if (!withTime) return;

  // 阶段 id 是运行时生成的，只能从行的 key 上取回来。
  final key =
      (tester.widget(fields.last) as TextField).key! as ValueKey<String>;
  final id = key.value.replaceFirst('editor-stage-', '');
  await tapVisible(tester, TaskEditorPage.stageTimeKey(id));
  await tester.tap(find.byKey(TaskEditorPage.stageTimeConfirmKey));
  await tester.pumpAndSettle();
}

/// 把某个阶段挪到 9 月 [day] 号（当月内，夹具时钟钉在 2026-09-07）。
///
/// **先挪结束、再挪开始**：反过来中间会经过「开始晚于结束」，而对话框的
/// 「确定」在那个状态下是灰的 —— 那道拦截是对的，夹具该绕开它，
/// 不该去改它。
///
/// ## 为什么要有它：`addStage` 给的默认时间会让几个阶段**完全重叠**
///
/// 对话框的默认是「相对任务开始 +0、一小时」，于是 `addStage` 建出来的
/// 几个阶段占的是同一个小时。任何断言依赖**阶段之间位置关系**的用例
/// （取最早/最晚、甘特分段、跨度推导）在那种输入上会退化成恒真 ——
/// **夹具替用例挑了输入，而它挑的恰好是最不敏感的那个。**
///
/// 用它拆开重叠之后，**记得把「拆开了」钉成一条前提断言** ——
/// 否则哪天默认值又变了，退化会静悄悄地发生。
Future<void> setStageDay(WidgetTester tester, String stageId, int day) async {
  Future<void> pick(Key field) async {
    await tester.tap(find.byKey(field));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('$day'),
      ),
    );
    await tester.pumpAndSettle();
    // **限定在日期选择器里找「确定」**：它底下压着阶段时间对话框，
    // 那个也有一颗「确定」，不限定会报「too many elements」。
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('确定'),
      ),
    );
    await tester.pumpAndSettle();
  }

  await tapVisible(tester, TaskEditorPage.stageTimeKey(stageId));
  await pick(TaskEditorPage.stageTimeEndDateKey);
  await pick(TaskEditorPage.stageTimeStartDateKey);
  await tester.tap(find.byKey(TaskEditorPage.stageTimeConfirmKey));
  await tester.pumpAndSettle();
}

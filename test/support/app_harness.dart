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
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app_providers.dart';
import 'package:planning_assistant/core/id/id_generator.dart';
import 'package:planning_assistant/core/time/clock.dart';
import 'package:planning_assistant/core/time/time_zone_resolver.dart';
import 'package:planning_assistant/data/database/app_database.dart';
import 'package:planning_assistant/data/database/dao/synced_dao.dart';
import 'package:planning_assistant/data/repositories/task_repository_impl.dart';
import 'package:planning_assistant/domain/commands/command_dispatcher.dart';
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
}) {
  // 时区数据库是**全局**的，且 TzTimeZoneResolver 没有它会抛
  // UnknownTimeZoneException —— 而那个异常发生在 build 里，
  // 表现是「页面构建失败」，离真正的原因隔了好几层。
  // 幂等，重复调用无害。
  tzdata.initializeTimeZones();

  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);

  final clock = FixedClock(now ?? DateTime.utc(2026, 9, 7, 3));
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
    ],
  );
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

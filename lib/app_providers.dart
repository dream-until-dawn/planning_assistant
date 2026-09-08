/// **应用级 Provider**（module-map §1）。
///
/// 绝大部分是**声明**，没有实现 —— 每一个都在 `bootstrap.dart` 里被覆盖，
/// 没覆盖就抛，不给默认值。末尾的 [todayProvider] 是个例外：
/// 它由上面两个派生，放在一起是为了让「今天是哪天」**只有一处定义**。
///
/// ## 为什么单独一个文件，而不是塞进 `core/` 或某个 feature
///
/// - **不能放 `core/`**：那样 `core/` 就得 import `flutter_riverpod`，
///   而 `domain/` 合法地 import `core/` 且**禁止任何 Flutter 依赖**
///   （NFR-MAINT-02）。两条边各自合法，复合起来领域层就静默地
///   拖进了 Flutter，而分层守卫只看直接 import，抓不到 ——
///   与 `layer_dependency_test` 里 B6 记的是同一个形状。
/// - **不能放某个 feature**：时钟、数据库这些是全应用的，
///   放进哪个 feature 都会让别的 feature 反向依赖它。
///
/// 所以放在组合根：feature 依赖的是**声明**，实现在 `bootstrap` 注入。
///
/// ## 为什么不给默认值
///
/// `Provider((ref) => const SystemClock())` 看着方便，代价是
/// **忘记覆盖时不会报错**，测试里会静默用上真实时钟 ——
/// 于是「测试依赖真实时间」这种缺陷要等到某天半夜跑 CI 才暴露。
/// 抛异常让「忘了注入」在第一次读取时就炸。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/id/id_generator.dart';
import 'core/time/clock.dart';
import 'core/time/plan_date.dart';
import 'core/time/time_zone_bootstrap.dart';
import 'core/time/time_zone_resolver.dart';
import 'domain/commands/command_dispatcher.dart';
import 'domain/repositories/category_repository.dart';
import 'domain/repositories/task_repository.dart';

Never _mustOverride(String what) =>
    throw StateError('$what 必须在 ProviderScope 的 overrides 中提供');

/// 全应用唯一的时钟。**任何地方都不许直接 `DateTime.now()`**
/// —— 那条由架构守卫盯着。
final clockProvider = Provider<Clock>((ref) => _mustOverride('clockProvider'));

/// 时区初始化的结果，供 UI 在降级时提示用户。
///
/// 用 Provider 暴露而不是全局变量，是为了让 Widget 测试能覆盖它。
final timeZoneSetupProvider = Provider<TimeZoneSetupResult>(
  (ref) => _mustOverride('timeZoneSetupProvider'),
);

/// 时区换算器。**墙钟与绝对时刻之间的换算只能经它**（ADR-0005）——
/// 自己拿 `DateTime` 加减时区偏移在 DST 边界上一定是错的。
final timeZoneResolverProvider = Provider<TimeZoneResolver>(
  (ref) => _mustOverride('timeZoneResolverProvider'),
);

/// ID 生成器（UUID v7）。
///
/// **命令自带 ID**，不由 dispatcher 现场生成 —— 否则同一条命令重放两次
/// 会建出两条任务，而 outbox 回放与 V3 重试都会重放命令
/// （见 `CreateTaskCommand.taskId` 的注释）。所以 ID 在这一层产生。
final idGeneratorProvider = Provider<IdGenerator>(
  (ref) => _mustOverride('idGeneratorProvider'),
);

/// 任务仓库。**presentation 层不得直接持有它**（FR-AI-01，分层守卫盯着）
/// —— 写路径一律经 [taskCommandDispatcherProvider]。
final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => _mustOverride('taskRepositoryProvider'),
);

/// 命令分发器。**所有写操作的唯一入口。**
///
/// 之所以不让 UI 直接调仓库：命令是可序列化、可重放、可审计的，
/// 而 V4 的语音/Agent 要能构造同一批命令走同一条路（FR-AI-01）。
/// UI 直接写仓库的话，那条路就绕过了全部不变量与 outbox。
final taskCommandDispatcherProvider = Provider<CommandDispatcher>(
  (ref) => _mustOverride('taskCommandDispatcherProvider'),
);

/// 分类仓库。
///
/// 分类是**实体不是配置项**（settings-spec §3），所以走仓库而不是配置中心。
/// 读路径可以直接用它；写路径将来同样要收进命令（FR-AI-01），
/// 目前分类还没有编辑界面，暂时没有写入方。
final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => _mustOverride('categoryRepositoryProvider'),
);

/// 「今天」——**本地墙钟的今天**，不是 UTC 的（ADR-0005）。
///
/// 东八区早上八点前 UTC 还停在昨天：直接截 `nowUtc` 的话，
/// 用户一早打开应用，今天的事全被算成「明天」。
///
/// **只此一处。** 一度有三个地方各自算过（列表分组、编辑器补日期、
/// 共享状态的初始聚焦日），三份各自正确但迟早分叉 —— 而且测试里要
/// 覆盖三处才能钉住「今天」，漏一处就有测试随日历翻页而变。
final todayProvider = Provider<PlanDate>((ref) {
  final resolver = ref.watch(timeZoneResolverProvider);
  return resolver
      .toWallTime(ref.watch(clockProvider).nowUtc(), resolver.currentZoneId())
      .date;
});

/// 应用初始化编排。
///
/// `main.dart` 只负责调用它；这里也不写业务，只做启动期的装配顺序编排。
/// 依据 docs/01-architecture/module-map.md §1。
library;

import 'dart:async';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:uuid/uuid.dart';

import 'app_providers.dart';
import 'core/id/id_generator.dart';
import 'core/time/clock.dart';
import 'core/time/time_zone_bootstrap.dart';
import 'core/time/time_zone_resolver.dart';
import 'data/database/app_database.dart';
import 'data/database/dao/synced_dao.dart';
import 'data/repositories/category_repository_impl.dart';
import 'data/repositories/settings_repository_impl.dart';
import 'data/repositories/task_repository_impl.dart';
import 'domain/commands/command_dispatcher.dart';
import 'platform/timezone/platform_time_zone.dart';

/// 启动应用。
///
/// [appBuilder] 由调用方提供，便于集成测试替换根 Widget。
/// [timeZoneSource] 可注入，便于测试与桌面端。
Future<void> bootstrap(
  Widget Function() appBuilder, {
  PlatformTimeZoneSource timeZoneSource = const MethodChannelTimeZoneSource(),
  Clock clock = const SystemClock(),
  IdGenerator idGenerator = const UuidV7Generator(Uuid()),

  /// 可注入，供集成测试用内存库。
  AppDatabase? database,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 顶层错误兜底（NFR-REL-01）：任何未捕获异常都必须落日志，绝不静默吞掉。
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kReleaseMode) {
      // TODO(M4): 落本地滚动日志文件，不外发（NFR-PRIV-01）
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('未捕获的异步异常: $error');
    return true;
  };

  // ── 时区：两步都必须做 ────────────────────────────────────────
  // initializeTimeZones() 只加载数据库，**不设置 tz.local**。
  // 少了第二步，tz.local.name 恒为 Etc/UTC，于是每条任务的 timeZoneId
  // 都被记成 UTC —— 北京设的「每天 07:00」变成当地 15:00，且完全静默。
  tzdata.initializeTimeZones();
  final tzResult = await setUpLocalTimeZone(timeZoneSource.currentZoneId);
  if (tzResult.fellBack) {
    // 降级必须可见：此后创建的任务时区是错的。
    debugPrint('时区初始化降级: $tzResult');
    // TODO(M2): 在设置页展示提示，引导用户手动选择时区
  }

  // ── 数据层装配 ────────────────────────────────────────────────
  // 组合根是**唯一**知道具体实现的地方：feature 只看得见抽象
  // （module-map §3：application 层不得依赖 data 的具体实现）。
  final db = database ?? AppDatabase(driftDatabase(name: 'planning_assistant'));

  // 设备 ID 是同步信封里的 lastWriterId，V3 才真正用得上；
  // V1 先固定一个值，但**字段从第一天就写**，否则老数据没有出处，
  // 到 V3 无法参与冲突解决（ADR 里那条「同步信封从 V1 起就存」）。
  // TODO(V3): 换成持久化的、每台设备唯一的 ID
  const writer = FixedWriterIdentity('local-device');

  final repository = DriftTaskRepository(db, writer, clock);
  final dispatcher = CommandDispatcher(repository, clock);
  final categories = DriftCategoryRepository(db, writer, clock);
  final settings = DriftSettingsRepository(db, writer, clock);

  // 首次启动写入默认分类（settings-spec §3.1）。**幂等**：
  // 已经有过分类就什么都不做，否则用户删掉的分类每次启动都会长回来。
  await categories.seedDefaultsIfEmpty();

  // TODO(M4): 通知渠道创建 → 提醒对账

  runApp(
    ProviderScope(
      // 组合根：`app_providers.dart` 里的声明在这里、且只在这里拿到实现。
      overrides: [
        clockProvider.overrideWithValue(clock),
        timeZoneResolverProvider.overrideWithValue(const TzTimeZoneResolver()),
        idGeneratorProvider.overrideWithValue(idGenerator),
        taskRepositoryProvider.overrideWithValue(repository),
        taskCommandDispatcherProvider.overrideWithValue(dispatcher),
        categoryRepositoryProvider.overrideWithValue(categories),
        settingsRepositoryProvider.overrideWithValue(settings),
        timeZoneSetupProvider.overrideWithValue(tzResult),
      ],
      child: appBuilder(),
    ),
  );
}

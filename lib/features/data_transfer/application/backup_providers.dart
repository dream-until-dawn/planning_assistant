/// 备份这一块的接线（roadmap M4「导入导出 UI + 自动备份」）。
///
/// 与提醒那边同一条纪律：**每一个 provider 都要有一条用例从真的入口
/// 走到真的调用** —— 备份最容易变成「设置页里有个按钮，点了没反应」。
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../domain/repositories/export_port.dart';
import '../../../platform/storage/backup_store.dart';
import '../../settings/application/registry.dart';
import '../../settings/application/settings_providers.dart';
import 'backup_service.dart';

/// 整库导出/导入。**在组合根注入** —— 它的实现在 `data/`，
/// 而这一层够不着那儿（module-map §3）。
final exportPortProvider = Provider<ExportPort>(
  (ref) =>
      throw StateError('exportPortProvider 必须在 ProviderScope 的 overrides 中提供'),
);

/// 备份文件放哪。同上，实现在 `platform/`，由组合根接上。
final backupStoreProvider = Provider<BackupStore>(
  (ref) =>
      throw StateError('backupStoreProvider 必须在 ProviderScope 的 overrides 中提供'),
);

/// 写进导出包头部的两个串。
///
/// **不在服务里现取**：现取的话导出结果不可复现，往返测试也无从断言
/// （`ExportService` 头上写着同一条）。
final backupIdentityProvider = Provider<({String appVersion, String deviceId})>(
  (ref) => (appVersion: '1.0.0', deviceId: 'local-device'),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    ref.watch(exportPortProvider),
    ref.watch(backupStoreProvider),
    ref.watch(clockProvider),
    ref.watch(backupIdentityProvider),
  ),
);

/// 当前有哪些备份。备份/恢复/删除之后要 `invalidate` 它。
final backupListProvider = FutureProvider<List<BackupFile>>(
  (ref) => ref.watch(backupServiceProvider).list(),
);

/// 启动时按配置自动备份一次。
///
/// **挂成一个 widget 而不是在 `bootstrap` 里跑**：bootstrap 那一刻
/// 容器还没建好，而且备份要读配置（`data.autoBackup*`）——
/// 那几条配置本身就活在容器里。
///
/// 只在启动跑一次，不挂生命周期：备份是**天级**的事（默认 7 天一次），
/// 而进前台是分钟级的。挂上去只会让 `autoBackupIfDue` 被问上几百遍，
/// 每次都答「还不到时候」。
class AutoBackupScope extends ConsumerStatefulWidget {
  const AutoBackupScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AutoBackupScope> createState() => _AutoBackupScopeState();
}

class _AutoBackupScopeState extends ConsumerState<AutoBackupScope> {
  var _fired = false;

  @override
  Widget build(BuildContext context) {
    // **等配置真的读出来再决定备不备。**
    //
    // 配置是流式读的，而解析层对「还没读出来」的回落是**默认值**
    // （`settings_providers` 的 `_resolve`）—— 默认值是「开着、7 天、
    // 留 5 份」。在首帧就问一次的话，一个**关掉了自动备份的用户**
    // 照样会被备一份，而且看不出哪里不对：备份成功、文件也在。
    //
    // 于是判据不是「第几帧」而是「有没有值」：`hasValue` 为真那一刻
    // 读到的才是库里的配置。这与续排那边推迟一个微任务是同一件事的
    // 两种形态 —— 那边等的是派生 provider 重算，这边等的是流的首值。
    final loaded = ref.watch(rawSettingsProvider).hasValue;
    if (loaded && !_fired) {
      _fired = true;
      // 三个值在 build 里读完再带走：`_run` 是异步的，那时用
      // `ref.watch` 会撞上「不在 build 里」的断言。
      final enabled = ref.setting(autoBackupEnabled);
      final intervalDays = ref.setting(autoBackupIntervalDays);
      final keepCount = ref.setting(autoBackupKeepCount);
      // 推到帧后：build 里发起会在构建期间改动 provider。
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(
          _run(
            enabled: enabled,
            intervalDays: intervalDays,
            keepCount: keepCount,
          ),
        ),
      );
    }
    return widget.child;
  }

  Future<void> _run({
    required bool enabled,
    required int intervalDays,
    required int keepCount,
  }) async {
    if (!mounted) return;
    final outcome = await ref
        .read(backupServiceProvider)
        .autoBackupIfDue(
          enabled: enabled,
          intervalDays: intervalDays,
          keepCount: keepCount,
        );
    // 备了才刷新列表页的数据源。**失败不弹提示** ——
    // 自动备份是背景里的事，没有用户在等这个结果，
    // 冷启动时弹一条红条只会吓人一跳（同回收站清理那条）。
    if (outcome != null && mounted) ref.invalidate(backupListProvider);
  }
}

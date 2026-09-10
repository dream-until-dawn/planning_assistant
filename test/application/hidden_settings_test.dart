/// 隐藏配置项（FR-CFG-08、settings-spec §1.1 / §5）。
///
/// > 未开放给用户的配置项以默认值静默生效，且**可通过导入的配置文件覆盖**；
/// > 隐藏配置项在导出 JSON 中可见。
///
/// ## 为什么到现在才验得了
///
/// 这条要求的后半句需要一条**真的导入路径**：没有导入，「可通过导入
/// 的配置文件覆盖」只是一句话。M4 把备份/恢复接上之后（`BackupService`
/// → `ExportPort` → `ExportService`），这条路第一次走得通，
/// 于是它从可追溯性的豁免表里去掉了。
///
/// ## 三句话分三条验
///
/// 它们会分开坏：
///
///  · 默认值静默生效 —— 坏了的表现是全新安装时某处读到 null；
///  · 导出里看得见 —— 坏了的表现是导出时按 `exposure` 过滤了一道，
///    于是高级用户根本发现不了这些项；
///  · 导入能覆盖 —— 坏了的表现是导入时把它们跳过，
///    用户改了配置文件却没有任何效果，而且没有任何报错。
@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app_providers.dart';
import 'package:planning_assistant/core/time/clock.dart';
import 'package:planning_assistant/data/database/app_database.dart';
import 'package:planning_assistant/data/database/dao/synced_dao.dart';
import 'package:planning_assistant/data/dto/export_bundle.dart';
import 'package:planning_assistant/data/repositories/settings_repository_impl.dart';
import 'package:planning_assistant/features/settings/application/registry.dart';
import 'package:planning_assistant/features/settings/application/settings_providers.dart';
import 'package:planning_assistant/features/settings/domain/setting_spec.dart';

final _clock = FixedClock(DateTime.utc(2026, 9, 10, 4, 30));

/// 拿来当样本的隐藏项。**从注册表里选一条真的**，不另造一条 ——
/// 另造的话，验的是「假如有这么一项会怎样」。
final SettingSpec<int> _hidden = autoBackupKeepCount;

/// 读那一项的探针。`settingOf` 要的是 `Ref`，容器里读不到。
final _probe = Provider<int>((ref) => settingOf(ref, _hidden));

({AppDatabase db, ProviderContainer container}) _open() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final container = ProviderContainer(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(
        DriftSettingsRepository(
          db,
          const FixedWriterIdentity('device-A'),
          _clock,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return (db: db, container: container);
}

/// 把配置流等到有值 —— 不挂监听直接读，读到的是 `AsyncLoading`
/// 那一支，而它的回落**恰好就是默认值**：于是「导入覆盖了没有」
/// 这条会验成一条恒真的话。
Future<int> _read(ProviderContainer container) async {
  container.listen<int>(_probe, (_, _) {});
  container.listen(rawSettingsProvider, (_, _) {});
  await pumpEventQueue();
  return container.read(_probe);
}

void main() {
  test('FR-CFG-08 没写过的隐藏项读到默认值，而且库里没有它那一行', () async {
    final (:db, :container) = _open();

    expect(await _read(container), _hidden.defaultValue);
    // **后半句才是「静默生效」的证据**：一个「启动时把默认值写进库」
    // 的实现在上一行完全通得过，但它把零配置变成了「自动配置一遍」。
    expect(await db.select(db.settings).get(), isEmpty);
  });

  test('FR-CFG-08 存过值的隐藏项出现在导出里 —— 导出不按 exposure 过滤', () async {
    final (:db, :container) = _open();
    await container.read(settingsWriterProvider).set(_hidden, 9);

    final bundle = await ExportService(db).export(
      appVersion: '1.0.0',
      deviceId: 'device-A',
      exportedAt: _clock.nowUtc(),
    );

    final rows = (bundle['data']! as Map<String, Object?>)['settings']! as List;
    expect(
      rows.map((r) => (r as Map<String, Object?>)['key']),
      contains(_hidden.key),
      reason: '隐藏项被过滤掉了 —— 高级用户在导出文件里根本发现不了它',
    );
  });

  test('FR-CFG-08 导入一份改过隐藏项的文件之后，读到的是文件里的值', () async {
    // 造包的办法是**在另一个库里改好再导出**，而不是手写一行 JSON：
    // 手写的话，列名或编码将来一变，这条用例会绿着骗人。
    final source = _open();
    await source.container.read(settingsWriterProvider).set(_hidden, 9);
    final text = encodeExportBundle(
      await ExportService(source.db).export(
        appVersion: '1.0.0',
        deviceId: 'device-A',
        exportedAt: _clock.nowUtc(),
      ),
    );

    final target = _open();
    expect(
      await _read(target.container),
      _hidden.defaultValue,
      reason: '前提没摆好：目标库本该还是默认值',
    );

    await ExportService(target.db).import(decodeExportBundle(text));

    expect(
      await _read(target.container),
      9,
      reason: '导入没盖上 —— 用户改了配置文件却什么也没发生，且没有任何报错',
    );
  });
}

/// 备份与恢复（FR-DATA-04/05、roadmap M4「导入导出 UI + 自动备份」）。
///
/// 三件事，判断全在这儿，落盘与整库读写各自在端口后面：
///
///  · **立刻备份**：导出 → 编码 → 写一个带时间戳的文件 → 按保留数删旧的；
///  · **恢复**：读文件 → 解码 → 导入（导入方**先清库再写**，见 `ExportService`）；
///  · **自动备份**：距上一份超过间隔就备一次。
library;

import '../../../core/time/clock.dart';
import '../../../domain/repositories/export_port.dart';
import '../../../platform/storage/backup_store.dart';

/// 备份文件名的前缀。列目录时只按后缀过滤，所以前缀纯粹是给人看的。
const String kBackupPrefix = 'backup-';

/// 一次备份/恢复的结果。**失败不抛给界面**，而是带回一句能显示的话 ——
/// 恢复失败时用户最需要知道的是「库有没有被动过」，而异常栈答不了这个。
typedef BackupOutcome = ({bool ok, String message, BackupFile? file});

final class BackupService {
  /// 位置参数，同 `CommandDispatcher(repo, clock)` 那一套 ——
  /// 具名的话字段名要公开（Dart 不允许 `this._x` 当具名参数），
  /// 而这几个协作者不该从外面读得到。
  const BackupService(this._exporter, this._store, this._clock, this._identity);

  final ExportPort _exporter;
  final BackupStore _store;
  final Clock _clock;

  /// 写进导出包头部的两个串。**装在一个记录里而不是两个位置参数** ——
  /// 两个都是 `String`，摆成位置参数迟早有人传反，而传反了不会报错：
  /// 导出的包照样能用，只是 `deviceId` 那一栏写着版本号。
  final ({String appVersion, String deviceId}) _identity;

  /// 立刻备份一份，并把超出 [keepCount] 的旧备份删掉。
  Future<BackupOutcome> backupNow({required int keepCount}) async {
    try {
      final at = _clock.nowUtc();
      final json = await _exporter.exportJson(
        appVersion: _identity.appVersion,
        deviceId: _identity.deviceId,
        exportedAt: at,
      );
      final file = await _store.write(backupNameFor(at), json);
      await _prune(keepCount: keepCount);
      return (ok: true, message: '已备份', file: file);
    } on Object catch (e) {
      // **备份失败不该让应用崩**：它多半是磁盘满或权限问题，
      // 而那时用户还在用这个应用做别的事。
      return (ok: false, message: '备份失败：$e', file: null);
    }
  }

  /// 从一份备份恢复。
  ///
  /// **整库替换，不是合并**（`ExportService.import` 的语义）。
  /// 坏包会在导入侧被拒，且**拒的时候库没被动过** ——
  /// 那条性质有专门的测试盯着（`export_import_test` 的「坏包不写进库」）。
  Future<BackupOutcome> restore(String name) async {
    try {
      await _exporter.importJson(await _store.read(name));
      return (ok: true, message: '已恢复', file: null);
    } on Object catch (e) {
      return (ok: false, message: '恢复失败：$e', file: null);
    }
  }

  /// 该自动备份就备一份。
  ///
  /// 判据是**距最近一份多久**，不是「上次备份的时间戳存在哪」——
  /// 存一个时间戳就多一份可能与文件对不上的状态（用户删掉备份之后，
  /// 那个时间戳还说「刚备过」，于是再也不自动备份）。文件本身就是记录。
  Future<BackupOutcome?> autoBackupIfDue({
    required bool enabled,
    required int intervalDays,
    required int keepCount,
  }) async {
    if (!enabled) return null;
    final existing = await _store.list();
    if (existing.isNotEmpty) {
      final age = _clock.nowUtc().difference(existing.first.createdAt);
      if (age < Duration(days: intervalDays)) return null;
    }
    return backupNow(keepCount: keepCount);
  }

  Future<void> _prune({required int keepCount}) async {
    if (keepCount < 1) return;
    final files = await _store.list();
    // list() 保证倒序，所以要删的就是下标 keepCount 起的那些。
    for (final f in files.skip(keepCount)) {
      await _store.delete(f.name);
    }
  }

  Future<List<BackupFile>> list() => _store.list();

  Future<void> delete(String name) => _store.delete(name);
}

/// 由时刻生成文件名。
///
/// **用 UTC 的 ISO 串并把冒号换掉**：冒号在部分文件系统上非法，
/// 而排序要靠字典序与时间序一致 —— ISO 正好满足。
String backupNameFor(DateTime at) {
  final iso = at.toUtc().toIso8601String().split('.').first;
  return '$kBackupPrefix${iso.replaceAll(':', '-')}.json';
}

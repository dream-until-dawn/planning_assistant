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
///
/// [file]：备份时是刚写出的那一份；**恢复时是「恢复前的那一份」** ——
/// 也就是万一恢复错了、用来退回去的那一份。
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
      final file = await _store.write(await _freeNameFor(at), json);
      await _prune(keepCount: keepCount);
      return (ok: true, message: '已备份', file: file);
    } on Object catch (e) {
      // **备份失败不该让应用崩**：它多半是磁盘满或权限问题，
      // 而那时用户还在用这个应用做别的事。
      return (ok: false, message: '备份失败：$e', file: null);
    }
  }

  /// 从一份备份恢复。**恢复之前先把现在的状态存一份。**
  ///
  /// **整库替换，不是合并**（`ExportService.import` 的语义）。
  /// 坏包会在导入侧被拒，且**拒的时候库没被动过** ——
  /// 那条性质有专门的测试盯着（`export_import_test` 的「坏包不写进库」）。
  ///
  /// ## 为什么一定要先留一份（评审 M4-B3）
  ///
  /// 「整库、不可逆、替换」这三条一起出现时先留副本，**这个项目已经
  /// 写下过这条原则**：NFR-REL-02 与 data-model §7 要求迁移前把库文件
  /// 复制成 `pre-migration-v{n}.db`。恢复是同一类操作，而且比迁移更该留：
  ///
  /// | | 迁移 | 恢复 |
  /// |---|---|---|
  /// | 谁发起 | 自动 | **用户手点** |
  /// | 会不会挑错 | 没有选择 | **可能点错一份** |
  /// | 出错后能回去吗 | 有副本 | 从前**没有** |
  ///
  /// 自动备份默认 7 天一次，所以点错一份的代价最坏是**一周的数据**，
  /// 而且没有任何找回路径。一个确认框拦不住「我以为这是昨天那份」。
  ///
  /// ## 三处顺序是有讲究的
  ///
  ///  1. **先读**要恢复的那一份：名字不对就当场失败，不必白存一份；
  ///  2. **再存**当前状态：存不下来（磁盘满）就**放弃恢复** ——
  ///     宁可不恢复，也不要在没有退路的情况下把库换掉；
  ///  3. 最后才导入。
  ///
  /// 存这一份**不做保留数清理**：清理会按「最旧的先删」动手，而
  /// 待恢复的那一份和刚存下的这一份恰恰都可能落在被删的一侧。
  /// 它们会在下一次正常备份时正常老化掉。
  Future<BackupOutcome> restore(String name) async {
    try {
      final payload = await _store.read(name);
      final safety = await _snapshotNow();
      await _exporter.importJson(payload);
      return (ok: true, message: '已恢复。恢复前的数据存成了一份备份', file: safety);
    } on Object catch (e) {
      return (ok: false, message: '恢复失败：$e', file: null);
    }
  }

  /// 把当前状态原样存一份，**不清理、不吞异常**。
  ///
  /// 不吞是要紧的：它是 [restore] 的前置条件，存不下来就不该往下走。
  Future<BackupFile> _snapshotNow() async {
    final at = _clock.nowUtc();
    return _store.write(
      await _freeNameFor(at),
      await _exporter.exportJson(
        appVersion: _identity.appVersion,
        deviceId: _identity.deviceId,
        exportedAt: at,
      ),
    );
  }

  /// 这一刻还没被占用的文件名。
  ///
  /// ## 为什么要问一遍，而不是直接用时刻当名字
  ///
  /// 名字精确到秒，所以**同一秒里的两次备份会互相覆盖** ——
  /// 从前这只意味着「少一份内容几乎相同的备份」，可以不管。
  /// 加了「恢复前先存一份」之后不行了：被覆盖掉的那一份**可能正是
  /// 某一次恢复的退路**（连着恢复两次就会撞上）。
  /// 只改恢复不改这里，等于给保险丝换了根铁丝（评审的原话）。
  ///
  /// 循环一定终止：`taken` 是有限集，`taken.length + 1` 个候选里
  /// 必有一个不在其中。
  Future<String> _freeNameFor(DateTime at) async {
    final taken = {for (final f in await _store.list()) f.name};
    for (var ordinal = 0; ordinal <= taken.length; ordinal++) {
      final name = backupNameFor(at, ordinal: ordinal);
      if (!taken.contains(name)) return name;
    }
    // 到不了这儿，见上面那句。
    throw StateError('同一秒里已经有 ${taken.length} 份备份了');
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
///
/// [ordinal] 大于 0 时在后面缀一个序号，给**同一秒里的第二份**用
/// （见 `BackupService._freeNameFor`）。同一秒之内谁在前谁在后，
/// 字典序说了不算 —— 但列表是按文件时间排的，不按名字排，
/// 所以这一点不影响任何人。
String backupNameFor(DateTime at, {int ordinal = 0}) {
  final iso = at.toUtc().toIso8601String().split('.').first;
  final suffix = ordinal == 0 ? '' : '-$ordinal';
  return '$kBackupPrefix${iso.replaceAll(':', '-')}$suffix.json';
}

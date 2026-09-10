/// 备份那两个端口的假实现，给 widget 测试用。
///
/// 同 `fake_notifications.dart`：**不是不做事的空壳**，每一次调用都记账 ——
/// 「按了立即备份到底有没有写出文件」在测试里问得出来。
library;

import 'package:planning_assistant/domain/repositories/export_port.dart';
import 'package:planning_assistant/platform/storage/backup_store.dart';

/// 内存里的备份目录。
///
/// [now] 决定写进去的文件记成什么时刻。**默认不是系统时钟**：
/// 用系统时钟的话「距上一份多久」在测试里不确定，
/// 而那正是自动备份的判据。
final class InMemoryBackupStore implements BackupStore {
  InMemoryBackupStore({DateTime? now})
    : _next = now ?? DateTime.utc(2026, 9, 7, 3);

  /// **每写一份往前走一秒。**
  ///
  /// 钉死的话，同一次测试里写出的两份备份 `createdAt` 相同 ——
  /// 于是「最新的排在最前」在列表里是**未定义**的，那条断言会随
  /// Map 的迭代顺序时绿时红。真实文件系统不会给出这种并列。
  DateTime _next;
  final Map<String, ({String contents, DateTime at})> _files = {};

  /// 删过哪些。保留策略有没有真的删，问它。
  final List<String> deleted = [];

  /// 现在有几份。
  int get count => _files.length;

  /// 某一份的内容。恢复走的是不是这一份，问它。
  String contentsOf(String name) => _files[name]!.contents;

  /// 直接塞一份进去，跳过服务 —— 「已经有一份旧备份」这类前提用它摆。
  void seed(String name, {required DateTime at, String contents = '{}'}) =>
      _files[name] = (contents: contents, at: at);

  @override
  Future<List<BackupFile>> list() async {
    final out = [
      for (final e in _files.entries)
        (
          name: e.key,
          createdAt: e.value.at,
          sizeBytes: e.value.contents.length,
        ),
    ];
    // **真实现保证倒序，假的也必须**，否则「删最旧的几份」在测试里
    // 验的是一个真实现不会出现的顺序。
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  @override
  Future<BackupFile> write(String name, String contents) async {
    final at = _next;
    _next = _next.add(const Duration(seconds: 1));
    _files[name] = (contents: contents, at: at);
    return (name: name, createdAt: at, sizeBytes: contents.length);
  }

  @override
  Future<String> read(String name) async {
    final f = _files[name];
    if (f == null) throw StateError('没有这份备份：$name');
    return f.contents;
  }

  @override
  Future<void> delete(String name) async {
    deleted.add(name);
    _files.remove(name);
  }
}

/// 不碰库的导出端口。
///
/// **给那些跟备份无关的用例用** —— 它们的树里没有真库
/// （`viewPipelineOverrides` 喂的是固定数据），真的导出无从谈起。
/// 备份自己的用例用真的 `JsonExportAdapter`（`appHarness` 里发的就是它），
/// 否则「导出 → 恢复 → 数据还在」验的是这个假的往返。
final class FakeExportPort implements ExportPort {
  final List<String> imported = [];
  var exportCount = 0;

  @override
  Future<String> exportJson({
    required String appVersion,
    required String deviceId,
    required DateTime exportedAt,
  }) async {
    exportCount++;
    return '{"formatVersion":1}';
  }

  @override
  Future<void> importJson(String json) async => imported.add(json);
}

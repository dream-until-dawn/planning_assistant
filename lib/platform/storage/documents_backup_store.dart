/// [BackupStore] 的实现：写在应用文档目录下的 `backups/`。
///
/// 这一层**不做任何判断** —— 叫什么名字、留几份、什么时候备份，
/// 全在 `BackupService` 里。这里只负责落盘。
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'backup_store.dart';

/// 备份文件的后缀。列目录时靠它把别的文件排除掉 ——
/// 文档目录不是我们独占的，drift 的库文件也可能在旁边。
const String kBackupExtension = '.json';

/// 备份都放在这个子目录里，不跟数据库文件混在一起。
const String kBackupDirName = 'backups';

final class DocumentsBackupStore implements BackupStore {
  const DocumentsBackupStore();

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$kBackupDirName');
    // 首次备份时目录还不存在。`recursive` 让父目录一并建出来。
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<List<BackupFile>> list() async {
    final dir = await _dir();
    final files = <BackupFile>[];
    for (final entity in dir.listSync()) {
      if (entity is! File || !entity.path.endsWith(kBackupExtension)) continue;
      final stat = entity.statSync();
      files.add((
        name: entity.uri.pathSegments.last,
        createdAt: stat.modified,
        sizeBytes: stat.size,
      ));
    }
    // **倒序在这里排一次**，见接口上的注释。
    files.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return files;
  }

  @override
  Future<BackupFile> write(String name, String contents) async {
    final dir = await _dir();
    final file = File('${dir.path}/$name');
    await file.writeAsString(contents, flush: true);
    final stat = file.statSync();
    return (name: name, createdAt: stat.modified, sizeBytes: stat.size);
  }

  @override
  Future<String> read(String name) async {
    final dir = await _dir();
    return File('${dir.path}/$name').readAsString();
  }

  @override
  Future<void> delete(String name) async {
    final dir = await _dir();
    final file = File('${dir.path}/$name');
    if (file.existsSync()) await file.delete();
  }
}

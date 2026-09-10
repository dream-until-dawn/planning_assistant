/// 备份落盘（FR-DATA-05）。
///
/// ## 为什么这一层也要测
///
/// 它「只是读写文件」，但里面藏着三个真的决定：**目录不存在时自己建**、
/// **只认 `.json`**、**按修改时间倒序**。三个都是写错了不会报错的东西 ——
/// 首次备份直接失败、把 drift 的库文件当成备份列出来、
/// 或者「删最旧的几份」删掉最新的那几份。
///
/// 而 `BackupService` 那一层是拿假实现测的：假的**按接口约定**排好了序，
/// 真实现有没有排，只有这一份问得出来。
///
/// ## 怎么测
///
/// 打 `path_provider` 的方法通道，把文档目录指到一个真的临时目录 ——
/// 于是文件是真写的、`listSync` 是真列的（同
/// `local_notification_platform_test` 打插件通道那一套）。
/// 把 `dart:io` 也换成假的话，被替换掉的恰好就是要验的那三件事。
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/platform/storage/documents_backup_store.dart';

const _channel = MethodChannel('plugins.flutter.io/path_provider');

late Directory _docs;

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    _docs = Directory.systemTemp.createTempSync('pa-backup-test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _channel,
          (call) async => call.method == 'getApplicationDocumentsDirectory'
              ? _docs.path
              : null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    if (_docs.existsSync()) _docs.deleteSync(recursive: true);
  });

  Directory backupsDir() => Directory('${_docs.path}/$kBackupDirName');

  const store = DocumentsBackupStore();

  group('FR-DATA-05 写与读', () {
    test('目录还不存在时自己建出来 —— 首次备份不该失败', () async {
      expect(backupsDir().existsSync(), isFalse, reason: '前提没摆好');

      await store.write('backup-a$kBackupExtension', '{"formatVersion":1}');

      expect(backupsDir().existsSync(), isTrue);
    });

    test('写出去的内容原样读得回来', () async {
      await store.write('backup-a$kBackupExtension', '{"x":1}');
      expect(await store.read('backup-a$kBackupExtension'), '{"x":1}');
    });

    test('write 回的大小与磁盘上一致', () async {
      // 大小是列表上显示给用户的那一栏。随手回一个 0 也「能跑」。
      final file = await store.write('backup-a$kBackupExtension', '12345');
      expect(file.sizeBytes, 5);
    });

    test('读一份不存在的备份会抛 —— 服务那层要接得住', () async {
      // 静默返回空串的话，恢复会用一个空包把整库清掉。
      expect(
        () => store.read('backup-nope$kBackupExtension'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('FR-DATA-05 列目录', () {
    test('**只列 .json** —— 文档目录不是我们独占的', () async {
      // drift 的库文件就在旁边。把它当成一份备份列出来，
      // 用户点「恢复」会拿一个 SQLite 文件去做 JSON 解析。
      await store.write('backup-a$kBackupExtension', '{}');
      File('${backupsDir().path}/planning_assistant.db').writeAsStringSync('x');
      File('${backupsDir().path}/notes.txt').writeAsStringSync('x');

      final names = (await store.list()).map((f) => f.name).toList();
      expect(names, ['backup-a$kBackupExtension']);
    });

    test('按创建时间**倒序**，新的在前', () async {
      // 顺序是接口上写死的约定：保留策略靠它删「最旧的几份」，
      // 排反了就是把最新的几份删掉。
      for (final name in ['old', 'mid', 'new']) {
        await store.write('backup-$name$kBackupExtension', '{}');
      }
      // 三份是同一瞬间写的，靠 mtime 分不开 —— 显式拉开。
      final at = {
        'old': DateTime.utc(2026, 9, 1),
        'mid': DateTime.utc(2026, 9, 5),
        'new': DateTime.utc(2026, 9, 9),
      };
      at.forEach((name, when) {
        File('${backupsDir().path}/backup-$name$kBackupExtension')
            .setLastModifiedSync(when);
      });

      final names = (await store.list()).map((f) => f.name).toList();
      expect(names, [
        'backup-new$kBackupExtension',
        'backup-mid$kBackupExtension',
        'backup-old$kBackupExtension',
      ]);
    });

    test('一份都没有时是空表，不是抛', () async {
      expect(await store.list(), isEmpty);
    });
  });

  group('FR-DATA-05 删除', () {
    test('删掉之后列表里没有了', () async {
      await store.write('backup-a$kBackupExtension', '{}');
      await store.delete('backup-a$kBackupExtension');
      expect(await store.list(), isEmpty);
    });

    test('删一份不存在的不炸 —— 两处同时删是可能的', () async {
      expect(
        () => store.delete('backup-nope$kBackupExtension'),
        returnsNormally,
      );
    });
  });
}

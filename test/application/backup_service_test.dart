/// 备份与恢复的判断（FR-DATA-04/05）。
///
/// 落盘与整库读写都在端口后面，所以这一份验的是**这个服务自己剩下的
/// 那几条判断**：文件名怎么起、留几份、什么时候该自动备份、失败怎么报。
///
/// 端口用假实现 —— 被替换掉的两样（写文件、清库重写）里没有任何判断，
/// 它们各自另有测试（`export_import_test` 验往返与坏包）。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/clock.dart';
import 'package:planning_assistant/domain/repositories/export_port.dart';
import 'package:planning_assistant/features/data_transfer/application/backup_service.dart';
import 'package:planning_assistant/platform/storage/backup_store.dart';

final _now = DateTime.utc(2026, 9, 10, 4, 30);

/// 记账式的假端口。
///
/// **它是有状态的**：`exportJson` 交出当前的 [payload]，`importJson`
/// 把 [payload] 换掉。一个「导入了就忘」的假端口表达不出
/// 「恢复真的把库换了」——而这一份里最要紧的那条
/// （恢复前存的那一份能不能救回来）问的正是这个。
///
/// 有状态**不等于有判断**：它没有任何分支，替换掉的仍然只是「读写整库」。
final class _FakeExporter implements ExportPort {
  final List<String> imported = [];
  var exportCount = 0;
  Object? exportThrows;
  Object? importThrows;
  String payload = '{"formatVersion":1}';

  @override
  Future<String> exportJson({
    required String appVersion,
    required String deviceId,
    required DateTime exportedAt,
  }) async {
    exportCount++;
    if (exportThrows case final e?) throw e;
    return payload;
  }

  @override
  Future<void> importJson(String json) async {
    if (importThrows case final e?) throw e;
    imported.add(json);
    payload = json;
  }
}

final class _FakeStore implements BackupStore {
  _FakeStore([Map<String, DateTime>? seed]) {
    seed?.forEach((name, at) => _files[name] = (contents: '{}', at: at));
  }

  final Map<String, ({String contents, DateTime at})> _files = {};
  final List<String> deleted = [];

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
    // 真实现保证倒序，假的也必须 —— 否则「删最旧的几份」在测试里
    // 验的是一个真实现不会出现的顺序。
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  @override
  Future<BackupFile> write(String name, String contents) async {
    _files[name] = (contents: contents, at: _now);
    return (name: name, createdAt: _now, sizeBytes: contents.length);
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

  String contentsOf(String name) => _files[name]!.contents;
}

BackupService _service(_FakeExporter exporter, _FakeStore store) =>
    BackupService(exporter, store, FixedClock(_now), (
      appVersion: '1.0.0',
      deviceId: 'device-A',
    ));

void main() {
  group('立刻备份', () {
    test('写出一份，文件名带时间戳且字典序 = 时间序', () async {
      final store = _FakeStore();
      final out = await _service(
        _FakeExporter(),
        store,
      ).backupNow(keepCount: 5);

      expect(out.ok, isTrue);
      expect(out.file!.name, 'backup-2026-09-10T04-30-00.json');
      // 冒号在部分文件系统上非法，所以换成了 `-`；
      // 而 ISO 的其余部分保证字典序与时间序一致。
      expect(out.file!.name, isNot(contains(':')));
      expect(
        backupNameFor(DateTime.utc(2026, 9, 9)).compareTo(out.file!.name),
        lessThan(0),
        reason: '早一天的名字该排在前面',
      );
    });

    test('超出保留数时删最旧的几份', () async {
      final store = _FakeStore({
        'backup-a.json': DateTime.utc(2026, 9, 1),
        'backup-b.json': DateTime.utc(2026, 9, 2),
        'backup-c.json': DateTime.utc(2026, 9, 3),
      });
      await _service(_FakeExporter(), store).backupNow(keepCount: 2);

      // 新写的那份 + 最新的一份旧的 = 2；剩下两份最旧的被删。
      expect(store.deleted..sort(), ['backup-a.json', 'backup-b.json']);
      expect((await store.list()).length, 2);
    });

    test('保留数够时一份都不删', () async {
      // 对照组。少了它，一个「每次都删到只剩一份」的实现在上面那条里
      // 也能过 —— 那条只断言了「a 和 b 被删」。
      final store = _FakeStore({'backup-a.json': DateTime.utc(2026, 9, 1)});
      await _service(_FakeExporter(), store).backupNow(keepCount: 5);
      expect(store.deleted, isEmpty);
      expect((await store.list()).length, 2);
    });

    test('导出抛异常 → 返回失败，不往上抛', () async {
      // 备份多半是磁盘满或权限问题，而那时用户还在用这个应用做别的事。
      final exporter = _FakeExporter()..exportThrows = StateError('磁盘满');
      final out = await _service(
        exporter,
        _FakeStore(),
      ).backupNow(keepCount: 5);

      expect(out.ok, isFalse);
      expect(out.message, contains('磁盘满'));
      expect(out.file, isNull);
    });
  });

  group('恢复', () {
    test('把那份文件的内容原样交给导入侧', () async {
      final store = _FakeStore();
      final exporter = _FakeExporter()..payload = '{"formatVersion":1,"x":1}';
      final service = _service(exporter, store);
      final made = await service.backupNow(keepCount: 5);

      final out = await service.restore(made.file!.name);

      expect(out.ok, isTrue);
      expect(exporter.imported.single, '{"formatVersion":1,"x":1}');
    });

    test('导入抛异常 → 返回失败，不往上抛', () async {
      final store = _FakeStore();
      final exporter = _FakeExporter();
      final service = _service(exporter, store);
      final made = await service.backupNow(keepCount: 5);
      exporter.importThrows = const FormatException('格式版本不匹配');

      final out = await service.restore(made.file!.name);
      expect(out.ok, isFalse);
      expect(out.message, contains('格式版本不匹配'));
    });

    test('恢复一份不存在的备份 → 失败而不是崩', () async {
      final out = await _service(
        _FakeExporter(),
        _FakeStore(),
      ).restore('没有这个.json');
      expect(out.ok, isFalse);
    });
  });

  group('FR-DATA-04 恢复之前先留一份退路（评审 M4-B3）', () {
    test('**恢复错了能退回去** —— 恢复前那一份列得出来，也恢复得回来', () async {
      // 这一条才是整条要求的意义所在。只断言「多了一个文件」是不够的：
      // 一个把当前状态存成空壳的实现照样能让文件数 +1，
      // 而用户点进去发现救不回来 —— 那时他连原来的数据都没有了。
      final store = _FakeStore();
      final exporter = _FakeExporter()..payload = '{"state":"昨天"}';
      final service = _service(exporter, store);
      final yesterday = await service.backupNow(keepCount: 5);

      // 今天干了一天活。
      exporter.payload = '{"state":"今天"}';

      // 手滑，恢复到了昨天。
      final undone = await service.restore(yesterday.file!.name);
      expect(exporter.payload, '{"state":"昨天"}', reason: '前提：确实退回去了');
      expect(undone.file, isNotNull, reason: '没留下退路');

      // 退路必须**列得出来** —— 列不出来的文件对用户等于不存在。
      final names = (await store.list()).map((f) => f.name);
      expect(names, contains(undone.file!.name));

      // 而且**恢复得回来**。
      final rescued = await service.restore(undone.file!.name);
      expect(rescued.ok, isTrue);
      expect(exporter.payload, '{"state":"今天"}', reason: '退路救不回来');
    });

    test('存不下退路时**放弃恢复**，库一个字都不动', () async {
      // 宁可不恢复，也不要在没有退路的情况下把整库换掉。
      final store = _FakeStore();
      final exporter = _FakeExporter()..payload = '{"state":"今天"}';
      final service = _service(exporter, store);
      final made = await service.backupNow(keepCount: 5);
      exporter.payload = '{"state":"改过了"}';
      exporter.exportThrows = StateError('磁盘满');

      final out = await service.restore(made.file!.name);

      expect(out.ok, isFalse);
      expect(out.message, contains('磁盘满'));
      expect(exporter.imported, isEmpty, reason: '存不下退路却还是导入了');
      expect(exporter.payload, '{"state":"改过了"}');
    });

    test('名字不对时不白存一份 —— 先读再存', () async {
      final store = _FakeStore();
      final exporter = _FakeExporter();
      final out = await _service(exporter, store).restore('没有这个.json');

      expect(out.ok, isFalse);
      expect(await store.list(), isEmpty, reason: '恢复没成，却留下一份垃圾');
      expect(exporter.exportCount, 0);
    });

    test('留下的那一份**不触发保留数清理**', () async {
      // 清理按「最旧的先删」动手，而待恢复的那一份与刚存下的这一份
      // 恰恰都可能落在被删的一侧 —— 恢复到一半把要恢复的文件删了。
      final store = _FakeStore();
      final exporter = _FakeExporter();
      final service = _service(exporter, store);
      final made = await service.backupNow(keepCount: 1);

      await service.restore(made.file!.name);

      final names = (await store.list()).map((f) => f.name);
      expect(names, contains(made.file!.name), reason: '把正在恢复的那一份删了');
      expect(names.length, 2);
    });
  });

  group('FR-DATA-05 同一秒里的两次备份互不覆盖', () {
    test('两份都在，名字不同', () async {
      // 时钟是钉死的，所以两次 `backupNow` 拿到的是同一个时刻 ——
      // 这正是真机上「自动备份刚跑完、用户马上按立即备份」的形状。
      //
      // 从前这只意味着少一份内容几乎相同的备份，可以不管；
      // 加了「恢复前先存一份」之后不行了：被覆盖掉的那一份可能正是
      // 某一次恢复的退路。
      final store = _FakeStore();
      final service = _service(_FakeExporter(), store);

      final a = await service.backupNow(keepCount: 5);
      final b = await service.backupNow(keepCount: 5);

      expect(a.file!.name, isNot(b.file!.name));
      expect((await store.list()).length, 2);
    });

    test('恢复前存的那一份，不会盖掉正要恢复的那一份', () async {
      // 同一秒里恢复一份刚刚存下的备份 —— 两个名字会撞。
      final store = _FakeStore();
      final exporter = _FakeExporter()..payload = '{"state":"A"}';
      final service = _service(exporter, store);
      final made = await service.backupNow(keepCount: 5);
      exporter.payload = '{"state":"B"}';

      final out = await service.restore(made.file!.name);

      expect(out.ok, isTrue);
      expect(out.file!.name, isNot(made.file!.name));
      expect(store.contentsOf(made.file!.name), '{"state":"A"}');
      expect(store.contentsOf(out.file!.name), '{"state":"B"}');
    });
  });

  group('自动备份', () {
    Future<BackupOutcome?> run(
      _FakeStore store, {
      bool enabled = true,
      int intervalDays = 7,
    }) => _service(_FakeExporter(), store).autoBackupIfDue(
      enabled: enabled,
      intervalDays: intervalDays,
      keepCount: 5,
    );

    test('关掉时什么也不做', () async {
      final store = _FakeStore();
      expect(await run(store, enabled: false), isNull);
      expect(await store.list(), isEmpty);
    });

    test('一份都没有时立刻备一份', () async {
      final store = _FakeStore();
      expect((await run(store))?.ok, isTrue);
      expect((await store.list()).length, 1);
    });

    test('最近一份还不到间隔 → 不备', () async {
      final store = _FakeStore({
        'backup-recent.json': _now.subtract(const Duration(days: 6)),
      });
      expect(await run(store), isNull);
      expect((await store.list()).length, 1);
    });

    test('最近一份超过间隔 → 备一份', () async {
      final store = _FakeStore({
        'backup-old.json': _now.subtract(const Duration(days: 8)),
      });
      expect((await run(store))?.ok, isTrue);
      expect((await store.list()).length, 2);
    });

    test('**判据是最近那一份的时间，不是某个存下来的时间戳**', () async {
      // 存时间戳的话，用户把备份删光之后那个戳还说「刚备过」，
      // 于是再也不自动备份。文件本身就是记录。
      final store = _FakeStore({
        'backup-recent.json': _now.subtract(const Duration(days: 1)),
      });
      expect(await run(store), isNull, reason: '前提：刚备过，不该再备');

      await store.delete('backup-recent.json');
      expect(
        (await run(store))?.ok,
        isTrue,
        reason: '备份被删光了却还不肯备 —— 那说明判据不是看文件',
      );
    });
  });
}

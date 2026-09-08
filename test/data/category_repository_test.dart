/// 分类仓储与映射（FR-CFG-03、settings-spec §3）。
@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/clock.dart';
import 'package:planning_assistant/data/database/app_database.dart';
import 'package:planning_assistant/data/database/dao/synced_dao.dart';
import 'package:planning_assistant/data/mappers/category_mapper.dart';
import 'package:planning_assistant/data/repositories/category_repository_impl.dart';
import 'package:planning_assistant/domain/entities/category.dart';

void main() {
  late AppDatabase db;
  late DriftCategoryRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftCategoryRepository(
      db,
      const FixedWriterIdentity('test'),
      FixedClock(DateTime.utc(2026, 9, 8)),
    );
  });
  tearDown(() => db.close());

  group('映射：逐列断言，不只验往返', () {
    // 往返测试对「两个同类型字段搬反了」是**瞎的** —— 两个方向反得一致，
    // 转回来还是原值。这里有两对互为陷阱：name/icon 都是 String，
    // colorArgb/orderIndex 都是 int。
    test('每一列都落在自己的位置上', () {
      const category = Category(
        id: 'c1',
        name: '工作',
        colorArgb: 0xFF7FD1C1,
        icon: 'briefcase',
        orderIndex: 3,
      );
      final companion = categoryToCompanion(category);

      expect(companion.id.value, 'c1');
      expect(companion.name.value, '工作');
      expect(companion.colorArgb.value, 0xFF7FD1C1);
      expect(companion.icon.value, 'briefcase');
      expect(companion.orderIndex.value, 3);
    });

    test('回来的方向也逐列对', () async {
      const category = Category(
        id: 'c1',
        name: '工作',
        colorArgb: 0xFF7FD1C1,
        icon: 'briefcase',
        orderIndex: 3,
      );
      await repo.saveCategory(category);

      final row = (await db.select(db.categories).get()).single;
      final back = categoryFromRow(row);

      expect(back.id, 'c1');
      expect(back.name, '工作');
      expect(back.colorArgb, 0xFF7FD1C1);
      expect(back.icon, 'briefcase');
      expect(back.orderIndex, 3);
    });

    test('对照组：名字与图标**不同值**时才验得出有没有搬反', () {
      // 如果夹具写成 name:'x', icon:'x'，搬反了也看不出来。
      const category = Category(
        id: 'c1',
        name: '工作',
        colorArgb: 1,
        icon: 'briefcase',
        orderIndex: 2,
      );
      expect(category.name, isNot(category.icon));
      expect(category.colorArgb, isNot(category.orderIndex));
    });
  });

  group('首次启动播种（settings-spec §3.1）', () {
    test('空库时写入四个默认分类', () async {
      await repo.seedDefaultsIfEmpty();
      final names = (await repo.findCategories()).map((c) => c.name).toList();
      expect(names, ['工作', '学习', '生活', '健康']);
    });

    test('**不含「未分类」** —— 它是 NULL 不是一行（§3.0）', () async {
      await repo.seedDefaultsIfEmpty();
      final names = (await repo.findCategories()).map((c) => c.name);
      expect(names, isNot(contains('未分类')));
    });

    test('幂等：再跑一次不重复写', () async {
      await repo.seedDefaultsIfEmpty();
      await repo.seedDefaultsIfEmpty();
      expect(await repo.findCategories(), hasLength(4));
    });

    test('用户改了名字，再启动不会被覆盖回去', () async {
      await repo.seedDefaultsIfEmpty();
      final work = (await repo.findCategories()).first;
      await repo.saveCategory(work.copyWith(name: '搬砖'));

      await repo.seedDefaultsIfEmpty();

      final names = (await repo.findCategories()).map((c) => c.name).toList();
      expect(names, contains('搬砖'));
      expect(names, isNot(contains('工作')));
    });

    test('用户删光了分类，再启动**不会**长回来', () async {
      // 「幂等」如果实现成「某个特定分类不存在就补」，删光后会重新播种 ——
      // 删掉的东西自己长回来，是会让人怀疑数据有没有存住的那种 bug。
      await repo.seedDefaultsIfEmpty();
      for (final c in await repo.findCategories()) {
        await repo.deleteCategory(c.id);
      }
      expect(await repo.findCategories(), isEmpty);

      await repo.seedDefaultsIfEmpty();
      expect(await repo.findCategories(), isEmpty, reason: '删掉的分类不该复活');
    });

    test('默认分类用固定 ID，不是随机 UUID', () async {
      // 导入导出与 V3 同步时，两台设备上的「工作」应当是同一条，
      // 而不是两条同名的。
      await repo.seedDefaultsIfEmpty();
      final ids = (await repo.findCategories()).map((c) => c.id).toList();
      expect(ids, everyElement(startsWith('cat-default-')));

      // 再建一个库，ID 必须一样。
      final db2 = AppDatabase(NativeDatabase.memory());
      addTearDown(db2.close);
      final repo2 = DriftCategoryRepository(
        db2,
        const FixedWriterIdentity('other-device'),
        FixedClock(DateTime.utc(2026, 9, 8)),
      );
      await repo2.seedDefaultsIfEmpty();
      expect((await repo2.findCategories()).map((c) => c.id), ids);
    });
  });

  group('排序', () {
    test('按 orderIndex 升序', () async {
      for (final (i, name) in ['丙', '甲', '乙'].indexed) {
        await repo.saveCategory(
          Category(
            id: 'c$i',
            name: name,
            colorArgb: 1,
            icon: 'x',
            orderIndex: [2, 0, 1][i],
          ),
        );
      }
      expect((await repo.findCategories()).map((c) => c.name), ['甲', '乙', '丙']);
    });

    test('同序号时按 id 兜底 —— 顺序必须是确定的', () async {
      // 不兜底的话同序号的两条每次查询顺序可能不同：列表莫名跳动，
      // golden 随机变红。同序号是会出现的（拖拽写入之间、导入的数据）。
      for (final id in ['c3', 'c1', 'c2']) {
        await repo.saveCategory(
          Category(id: id, name: id, colorArgb: 1, icon: 'x', orderIndex: 0),
        );
      }
      final first = (await repo.findCategories()).map((c) => c.id).toList();
      final second = (await repo.findCategories()).map((c) => c.id).toList();
      expect(first, ['c1', 'c2', 'c3']);
      expect(second, first);
    });
  });

  group('删除分类不级联删任务（FR-CFG-03）', () {
    test('软删后查不到', () async {
      await repo.saveCategory(
        const Category(
          id: 'c1',
          name: '工作',
          colorArgb: 1,
          icon: 'x',
          orderIndex: 0,
        ),
      );
      await repo.deleteCategory('c1');
      expect(await repo.findCategories(), isEmpty);
      expect(await repo.findCategoryById('c1'), isNull);
    });
  });

  group('watch', () {
    test('新增会推给订阅者', () async {
      final seen = <int>[];
      final sub = repo.watchCategories().listen((l) => seen.add(l.length));
      addTearDown(sub.cancel);

      await pumpEventQueue();
      await repo.saveCategory(
        const Category(
          id: 'c1',
          name: '工作',
          colorArgb: 1,
          icon: 'x',
          orderIndex: 0,
        ),
      );
      await pumpEventQueue();

      expect(seen.last, 1, reason: '写入后订阅者应当收到新值');
    });
  });
}

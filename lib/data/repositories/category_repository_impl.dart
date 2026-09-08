/// 分类仓储的 Drift 实现。
library;

import 'package:drift/drift.dart';

import '../../core/time/clock.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../database/app_database.dart';
import '../database/dao/synced_dao.dart';
import '../database/dao/table_daos.dart';
import '../mappers/category_mapper.dart';

/// 首次启动写入的默认分类（settings-spec §3.1）。
///
/// **「未分类」不在这里** —— 它是 `categoryId IS NULL`，不是一行（§3.0）。
/// 往这里加一条「未分类」就等于把被去掉的第二种编码请回来。
///
/// 颜色取自 design-system §2.5 的默认调色板。
const List<({String name, int colorArgb, String icon})> kDefaultCategories = [
  (name: '工作', colorArgb: 0xFF7FD1C1, icon: 'briefcase'),
  (name: '学习', colorArgb: 0xFFA8C8F0, icon: 'book'),
  (name: '生活', colorArgb: 0xFFFFB7C5, icon: 'home'),
  (name: '健康', colorArgb: 0xFFA8D8B9, icon: 'heart'),
];

// 这四个颜色必须来自 §2.5 的调色板 —— 由 category_palette_test 对表，
// 不在这里 import design/：data 层不依赖 design 层（分层守卫盯着）。

final class DriftCategoryRepository implements CategoryRepository {
  DriftCategoryRepository(AppDatabase db, WriterIdentity writer, Clock clock)
    : _db = db,
      _dao = CategoryDao(db, writer, clock),
      _tasks = TaskDao(db, writer, clock);

  final AppDatabase _db;
  final CategoryDao _dao;

  /// 删分类要把它下面的任务摘成未分类，见 [deleteCategory]。
  final TaskDao _tasks;

  /// 排序只按 `orderIndex`，**并以 `id` 兜底**。
  ///
  /// 光按 orderIndex 的话，两条同序号的分类每次查询顺序可能不同 ——
  /// 列表会莫名跳动，而 golden 会随机变红。同序号是可能出现的：
  /// 拖拽排序写入之间、或导入的数据。
  List<Category> _sorted(List<CategoryRow> rows) {
    final list = rows.map(categoryFromRow).toList()
      ..sort((a, b) {
        final byOrder = a.orderIndex.compareTo(b.orderIndex);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });
    return list;
  }

  @override
  Future<List<Category>> findCategories() async => _sorted(await _dao.getAll());

  @override
  Stream<List<Category>> watchCategories() => _dao.watchAll().map(_sorted);

  @override
  Future<Category?> findCategoryById(String id) async {
    final rows = await _dao.getAll();
    for (final row in rows) {
      if (row.id == id) return categoryFromRow(row);
    }
    return null;
  }

  @override
  Future<void> saveCategory(Category category) =>
      _dao.upsert(categoryToCompanion(category));

  @override
  Future<void> deleteCategory(String id) async {
    // **先把任务摘出来，再打墓碑，一个事务。**
    //
    // 表上确实写着 `ON DELETE SET NULL`，接口注释一度也这么说 ——
    // 但删分类走的是**软删**（留墓碑，V3 同步要靠它），行还在，
    // 于是那条外键**永远不会触发**。实测：任务的 categoryId 仍是被删的
    // 那个 id，而分类行只是多了个 deletedAt。
    //
    // 后果不是显示错。卡片查不到分类会回落成「未分类」，看着正常；
    // 而筛选按的是 `categoryId == null`，那些任务一条都筛不出来 ——
    // **卡片上写着「未分类」，按「未分类」筛却找不到它**。
    // 这正是 settings-spec §3.0 要避免的「同一个可见状态两种编码」，
    // 只是这次是从墓碑那一侧绕进来的。
    //
    // 半截状态会留下一批指向死分类的任务，所以必须同一个事务。
    await _db.transaction(() async {
      await _detachTasksOf(id);
      await _dao.softDelete(id);
    });
  }

  /// 把指向 [categoryId] 的任务改成未分类。
  ///
  /// **逐条走 `TaskDao.upsert`，不用一条 UPDATE 扫全表。**
  /// 一条 SQL 快得多，但它不写 change_log —— 而「清库后按 seq 回放
  /// 应还原等价状态」是发现「写操作绕过管道」的主要手段
  /// （data-model §3 那张表）。少了这些行，回放出来的库里那些任务
  /// 还挂在死分类上，两边分叉。
  Future<void> _detachTasksOf(String categoryId) async {
    final rows = await (_db.select(
      _db.tasks,
    )..where((t) => t.categoryId.equals(categoryId))).get();
    for (final row in rows) {
      await _tasks.upsert(
        row.toCompanion(true).copyWith(categoryId: const Value(null)),
      );
    }
  }

  @override
  Future<void> seedDefaultsIfEmpty() async {
    // **幂等靠「已有任何分类就退出」**，不是靠「某个特定分类不存在」。
    //
    // 后者会在用户删光默认分类后又把它们种回来 —— 用户删掉「健康」，
    // 下次启动它自己长回来，这是个会让人怀疑数据有没有存住的 bug。
    //
    // 连墓碑一起算：删掉的分类留有 deletedAt 行，那也算「用过了」。
    // 只看未删除的话，删光之后同样会重新播种。
    final existing = await _dao.getAllIncludingDeleted();
    if (existing.isNotEmpty) return;

    for (var i = 0; i < kDefaultCategories.length; i++) {
      final spec = kDefaultCategories[i];
      await _dao.upsert(
        categoryToCompanion(
          Category(
            // 默认分类用**固定 ID**，不用随机 UUID：
            // 导入导出与 V3 同步时，两台设备上的「工作」应当是同一条，
            // 而不是两条同名的。
            id: 'cat-default-${spec.icon}',
            name: spec.name,
            colorArgb: spec.colorArgb,
            icon: spec.icon,
            orderIndex: i,
          ),
        ),
      );
    }
  }
}

/// 分类仓储的**抽象接口**（module-map：`domain/repositories/` 只有接口）。
///
/// 方法签名里不出现任何 Drift 类型，架构守卫会检查这一点。
library;

import '../entities/category.dart';

abstract interface class CategoryRepository {
  /// 按 `orderIndex` 升序取全部分类。
  ///
  /// **不含「未分类」** —— 它是 `categoryId IS NULL`，不是一行
  /// （settings-spec §3.0）。界面要展示它，由展示层加上。
  Future<List<Category>> findCategories();

  /// 同上，但持续推送。
  Stream<List<Category>> watchCategories();

  Future<Category?> findCategoryById(String id);

  Future<void> saveCategory(Category category);

  /// 删除一个分类。
  ///
  /// **其下任务不跟着删**（FR-CFG-03），而是变成「未分类」——
  /// 实现必须**显式把它们的 categoryId 置空**，与打墓碑同一个事务。
  ///
  /// 这里一度写着「外键是 `ON DELETE SET NULL`，于是那些任务自动变成
  /// 未分类」。表上确实那么定义，但删分类走的是**软删**（留墓碑，
  /// V3 同步要靠它）—— 行还在，外键永远不触发。实测过：任务的
  /// categoryId 仍指着被删的那个 id。
  ///
  /// 而那不只是「数据不好看」：卡片查不到分类会回落显示成「未分类」，
  /// 筛选却按 `categoryId == null` 判 —— **卡片上写着「未分类」，
  /// 按「未分类」筛却一条都找不到**。
  Future<void> deleteCategory(String id);

  /// 首次启动写入默认分类（settings-spec §3.1）。
  ///
  /// **幂等**：已经有任何分类时什么都不做。
  /// 不幂等的话，每次启动都会再写一遍，用户改过的名字被覆盖、
  /// 删掉的分类自己长回来。
  Future<void> seedDefaultsIfEmpty();
}

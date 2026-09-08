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
  /// **其下任务不跟着删**（FR-CFG-03）：外键是 `ON DELETE SET NULL`，
  /// 于是那些任务自动变成「未分类」。这正是 §3.0 决定用 NULL 表示
  /// 未分类的原因之一 —— 删除产生的就是 NULL，躲不掉。
  Future<void> deleteCategory(String id);

  /// 首次启动写入默认分类（settings-spec §3.1）。
  ///
  /// **幂等**：已经有任何分类时什么都不做。
  /// 不幂等的话，每次启动都会再写一遍，用户改过的名字被覆盖、
  /// 删掉的分类自己长回来。
  Future<void> seedDefaultsIfEmpty();
}

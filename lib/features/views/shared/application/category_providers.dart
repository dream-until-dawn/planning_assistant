/// 分类的读取（跨 feature 共用：编辑器要选它，列表要显示它）。
///
/// 放 `views/shared/application/` 而不是某个 feature 里 ——
/// 编辑器（`task`）和列表（`views`）是两个 feature，跨 feature
/// 只能经 application 层的 Provider 通信（module-map §3）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app_providers.dart';
import '../../../../domain/entities/category.dart';
import '../../../settings/application/registry.dart';
import '../../../settings/application/settings_providers.dart';

/// 全部分类，按 `orderIndex` 升序。**不含「未分类」**
/// —— 那是 `categoryId IS NULL`，不是一行（settings-spec §3.0）。
final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchCategories(),
);

/// 已就绪的分类列表；**还没读出来时是空表，不抛**。
///
/// 首帧任务列表可能先于分类到达，那时每张卡片按「未分类」渲染，
/// 下一帧分类到了自动补上。抛的话首帧直接变成错误页，
/// 而它其实只是还没读完 —— 那是把「慢」误报成「坏」。
final categoryListProvider = Provider<List<Category>>((ref) {
  final categories = ref.watch(categoriesProvider);
  return switch (categories) {
    AsyncData(:final value) => value,
    _ => const [],
  };
});

/// 新任务默认落在哪个分类（settings-spec §2.4 `behavior.defaultCategoryId`、
/// §3「设为默认」）。**null 就是未分类**。
///
/// ## 为什么不能直接把配置里那个字符串拿去用
///
/// 配置里存的是一个分类 id，而分类是**可以被删的**。删掉之后配置里
/// 留着一个死 id —— 拿它去建任务，会得到一条 `categoryId` 指向不存在
/// 分类的任务：卡片回落显示成「未分类」，按「未分类」筛却找不到它。
/// 这正是删分类那条路上刚修过的缺陷，只是入口换成了配置。
///
/// 所以这里**对着当前的分类表校一次**，认不出就当未分类。
/// 不顺手把配置改回去 —— 分类可能是被误删、随后从回收站恢复的，
/// 静默改写用户设过的东西比暂时回落更糟。
final defaultCategoryIdProvider = Provider<String?>((ref) {
  final stored = settingOf(ref, defaultCategoryId);
  if (stored == kUncategorizedSettingValue) return null;
  final exists = ref.watch(categoryListProvider).any((c) => c.id == stored);
  return exists ? stored : null;
});

/// id → 分类的索引，供列表逐条渲染时查名字与颜色。
///
/// 每张卡片自己去列表里线性找的话，一屏 20 条就是 20 次遍历；
/// 而且那样每张卡片都得拿到整个列表，耦合更重。
final categoryByIdProvider = Provider<Map<String, Category>>(
  (ref) => {for (final c in ref.watch(categoryListProvider)) c.id: c},
);

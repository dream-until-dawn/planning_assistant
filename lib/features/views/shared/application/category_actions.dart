/// 分类的增删改排（FR-CFG-03、settings-spec §3）。
///
/// 与 `category_providers.dart` 一样放 `views/shared/application/`：
/// 管理入口在设置页、读取方在编辑器与列表，三个 feature 都要够得着，
/// 而跨 feature 只能经 application 层（module-map §3）。
///
/// ## 为什么不是 TaskCommand
///
/// 命令管道（overview §4）管的是**任务**的写：它要可序列化、可重放，
/// 因为 V3 云端拉取与 V4 Agent 都要构造同一批命令。分类的写没有这个
/// 需求 —— 它不进任务的 outbox 语义，而 `CategoryDao` 继承 `SyncedDao`，
/// change_log 照样在同一事务里写，同步与回放并不缺东西。
///
/// 但 overview §4 那条「**Presentation 不得持有 Repository 引用**」是通用的
/// （NFR-MAINT-01、FR-AI-01，守卫测试盯着）。所以有这一层：
/// 界面调它，它持有仓库。形状与 `SettingsWriter` 一致。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app_providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../domain/entities/category.dart';
import 'category_providers.dart';

/// 新建分类时的默认图标。
///
/// 用一个中性的标签而不是随机挑 —— 图标选择器还没做（见 TODO），
/// 那之前所有新分类长一样，好过每个长得都不一样却都不是用户选的。
// TODO(M3): 图标选择器（settings-spec §3「编辑：名称、颜色、图标」）
const String kDefaultCategoryIcon = 'label';

final class CategoryActions {
  const CategoryActions(this._ref);

  final Ref _ref;

  /// 新建一个分类。返回它的 id。
  ///
  /// 颜色**按现有个数从调色板顺序取**（settings-spec §3）：
  /// 用户连建三个，得到三个不同的颜色，不用自己挑。
  /// 超过八个就回绕（`CategoryPalette.forIndex`）。
  ///
  /// `orderIndex` 排在最后 —— 新建的东西出现在末尾是最不意外的位置。
  Future<String> create(String name) async {
    final existing = _ref.read(categoryListProvider);
    final id = _ref.read(idGeneratorProvider).newId();
    await _ref
        .read(categoryRepositoryProvider)
        .saveCategory(
          Category(
            id: id,
            name: name.trim(),
            colorArgb: CategoryPalette.forIndex(existing.length),
            icon: kDefaultCategoryIcon,
            orderIndex: existing.isEmpty
                ? 0
                // 按**最大值 + 1**，不是按个数：中间删过分类的话，
                // 个数会与既有的 orderIndex 撞上，两条并列同一个序号。
                : existing.map((c) => c.orderIndex).reduce(_max) + 1,
          ),
        );
    return id;
  }

  /// 改名 / 改色 / 改图标。传 null 表示这一项不改。
  Future<void> update(
    Category category, {
    String? name,
    int? colorArgb,
    String? icon,
  }) => _ref
      .read(categoryRepositoryProvider)
      .saveCategory(
        category.copyWith(name: name?.trim(), colorArgb: colorArgb, icon: icon),
      );

  /// 删除。**其下任务变成未分类，任务本身不删**（FR-CFG-03）——
  /// 那一步在仓库里，与打墓碑同一个事务。
  Future<void> remove(String id) =>
      _ref.read(categoryRepositoryProvider).deleteCategory(id);

  /// 拖拽重排：把第 [from] 项移到第 [to] 位。
  ///
  /// **[to] 是移走之后的最终下标**，不是「插到第几个之前」。
  /// 这两种约定差一个 1，而差错的表现是「往下拖一格等于没动」——
  /// 看起来像拖拽没生效，而不像算错。
  ///
  /// 对接 `ReorderableListView` 的 **`onReorderItem`**（不是已废弃的
  /// `onReorder`）：前者给的下标已经替移走的那一项调整过了。
  /// 由 widget 测试真拖一次来锁这个语义 —— 光看文档容易接反。
  ///
  /// **整表重写成 0..n-1 连续序号**，不是只改动过的那两条。
  /// 只改两条的话，序号会随着来回拖拽长出空洞与重复，
  /// 而「按 orderIndex 升序」在重复值上的顺序是未定义的 ——
  /// 表现为「排好的顺序过一会儿自己变了」。
  Future<void> reorder(int from, int to) async {
    final list = [..._ref.read(categoryListProvider)];
    if (from < 0 || from >= list.length) return;
    var target = to;
    if (target < 0) target = 0;
    if (target >= list.length) target = list.length - 1;
    if (target == from) return;

    final moved = list.removeAt(from);
    list.insert(target, moved);

    final repository = _ref.read(categoryRepositoryProvider);
    for (final (i, c) in list.indexed) {
      if (c.orderIndex == i) continue; // 没变的不写，少一堆同步噪声
      await repository.saveCategory(c.copyWith(orderIndex: i));
    }
  }
}

int _max(int a, int b) => a > b ? a : b;

final categoryActionsProvider = Provider<CategoryActions>(CategoryActions.new);

/// 分类（FR-CFG-03、data-model §3.6）。
///
/// ## 「未分类」不是这里的一个实例
///
/// `Task.categoryId == null` 就是未分类（settings-spec §3.0）。
/// 这个类**只表示用户真正建出来的分类**，永远不会有一个 name 为
/// 「未分类」的 [Category]。
///
/// 那条决定的由来：`tasks.categoryId` 是 nullable + `ON DELETE SET NULL`，
/// 删分类必然产出 NULL —— 如果「未分类」同时还是一行，同一个用户可见状态
/// 就有了两种编码，每个查询都要处理两遍，漏一处就出现「有两个未分类」。
library;

import 'package:meta/meta.dart';

@immutable
final class Category {
  const Category({
    required this.id,
    required this.name,
    required this.colorArgb,
    required this.icon,
    required this.orderIndex,
  });

  final String id;
  final String name;

  /// 分类色。
  ///
  /// **只用来画 3px 色条与小色点**（design-system §2.5）：
  /// 默认调色板对两种表面实测只有 1.32–1.88，远低于图形所需的 3:1，
  /// 因此绝不能承载文字，也绝不能是唯一的信息载体 —— 分类名必须同时
  /// 以文字出现（§8.1）。
  final int colorArgb;

  /// 图标**标识串**，不存二进制 —— 图标资源随版本走，
  /// 存进库会让换图标变成一次数据迁移。
  final String icon;

  /// 显示顺序。用户拖拽排序时改它。
  final int orderIndex;

  Category copyWith({
    String? name,
    int? colorArgb,
    String? icon,
    int? orderIndex,
  }) => Category(
    id: id,
    name: name ?? this.name,
    colorArgb: colorArgb ?? this.colorArgb,
    icon: icon ?? this.icon,
    orderIndex: orderIndex ?? this.orderIndex,
  );

  @override
  bool operator ==(Object other) =>
      other is Category &&
      id == other.id &&
      name == other.name &&
      colorArgb == other.colorArgb &&
      icon == other.icon &&
      orderIndex == other.orderIndex;

  @override
  int get hashCode => Object.hash(id, name, colorArgb, icon, orderIndex);

  @override
  String toString() => 'Category($id, $name, order=$orderIndex)';
}

/// Drift 行 ⇄ 分类实体（module-map `data/mappers/`）。
///
/// 同 `task_mapper.dart`：这一层只有逐字段搬运，也正因如此最容易出现
/// 「两个同类型字段搬反了」—— 搬反了编译通过、往返测试也通过
/// （两个方向反得一致），只有逐列断言才抓得到。
///
/// 这里有**两对**同类型字段互为陷阱：
/// `name`/`icon` 都是 String，`colorArgb`/`orderIndex` 都是 int。
library;

import 'package:drift/drift.dart';

import '../../domain/entities/category.dart';
import '../database/app_database.dart';

Category categoryFromRow(CategoryRow row) => Category(
  id: row.id,
  name: row.name,
  colorArgb: row.colorArgb,
  icon: row.icon,
  orderIndex: row.orderIndex,
);

CategoriesCompanion categoryToCompanion(Category category) =>
    CategoriesCompanion(
      id: Value(category.id),
      name: Value(category.name),
      colorArgb: Value(category.colorArgb),
      icon: Value(category.icon),
      orderIndex: Value(category.orderIndex),
    );

/// 列表视图的数据源（view-specs §2）。
///
/// **视图不自己查库**（view-specs §0.2）—— 经仓库的 `watchTasks` 流，
/// 于是新建任务落库后列表自动刷新，不需要任何手工「刷新」调用。
/// 这条在 J-01「建任务 → 列表可见」里是关键：如果靠手工刷新，
/// 那条集成测试会因为时序偶尔变绿，而那比红更糟。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app_providers.dart';
import '../../../../domain/entities/task.dart';

/// 当前可见的任务。
///
/// M2 只做「未完成的活动任务」这一档。分组、排序、筛选（§2.1–§2.3）
/// 还没做 —— **这里不预先塞一个假的排序**：假排序会让后面真正实现
/// §2.2 时分不清「改对了」还是「本来就那样」。
final visibleTasksProvider = StreamProvider<List<Task>>(
  (ref) => ref.watch(taskRepositoryProvider).watchTasks(),
);

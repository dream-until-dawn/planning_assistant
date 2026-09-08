/// 筛选的执行（view-specs §2.3）。
///
/// **纯函数**：不碰 Flutter、不查库、不读时钟。放 `views/shared/` 是因为
/// 四个视图共用同一份筛选状态（FR-VIEW-05），执行也该只有一份 ——
/// 各视图各写一遍的话，「在列表设的筛选切到甘特仍生效」就成了
/// 「两处碰巧实现得一样」。
library;

import '../../../../domain/entities/task.dart';
import 'view_shared_state.dart';

/// 按 [filter] 筛出任务。
///
/// 维度之间取交集，维度之内取并集；**空集合表示不筛这个维度**
/// （理由见 [FilterSpec] 的注释）。
List<Task> applyFilter(List<Task> tasks, FilterSpec filter) {
  if (filter.isEmpty) return tasks;
  return tasks.where((t) => _matches(t, filter)).toList();
}

bool _matches(Task task, FilterSpec filter) {
  if (filter.categoryIds.isNotEmpty &&
      !filter.categoryIds.contains(task.categoryId)) {
    return false;
  }
  if (filter.priorities.isNotEmpty &&
      !filter.priorities.contains(task.priority)) {
    return false;
  }
  if (filter.statuses.isNotEmpty && !filter.statuses.contains(task.status)) {
    return false;
  }
  if (!_matchesKeyword(task, filter.keyword)) return false;
  if (!_matchesDateRange(task, filter)) return false;
  return true;
}

/// 关键词匹配标题**与备注**，大小写不敏感。
///
/// 只匹配标题的话，「那件事我写在备注里了」就搜不出来 —— 而备注正是
/// 用来放细节的地方，细节恰恰是想搜的东西。
///
/// 两端 `trim`：用户从别处粘贴常带空格，而带空格的关键词一条都匹配不上，
/// 表现是「搜什么都没有」。
bool _matchesKeyword(Task task, String? keyword) {
  final needle = keyword?.trim().toLowerCase();
  if (needle == null || needle.isEmpty) return true;

  if (task.title.toLowerCase().contains(needle)) return true;
  final note = task.note;
  return note != null && note.toLowerCase().contains(needle);
}

/// 日期范围。两端都可选，只给一端就是开区间。
///
/// **没有日期的任务在有日期范围时被排除。** 它不落在任何区间里 ——
/// 「9 月的事」不该包含一件没定哪天的事。
/// 反过来（无日期永远保留）会让日期范围形同虚设。
bool _matchesDateRange(Task task, FilterSpec filter) {
  final from = filter.dateFrom;
  final to = filter.dateTo;
  if (from == null && to == null) return true;

  final date = task.planDate;
  if (date == null) return false;

  if (from != null && date.isBefore(from)) return false;
  if (to != null && date.isAfter(to)) return false;
  return true;
}

/// 列表的分组与组内排序（view-specs §2.1、§2.2）。
///
/// **纯函数，不碰 Flutter、不碰仓库、不读时钟。** 「今天是哪天」由调用方传进来
/// —— 这一层只做「给定今天，这堆任务怎么排」，于是每一条分组规则
/// 都能用一个固定的日期去验，不需要造时间。
library;

import 'package:meta/meta.dart';

import '../../../../core/time/plan_date.dart';
import '../../../../domain/entities/category.dart';
import '../../../../domain/entities/task.dart';
import '../../../../domain/value_objects/task_status.dart';
import '../../shared/application/task_occurrence.dart';

/// 分组维度（配置项 `view.listGroupBy`）。
enum ListGroupBy {
  date('date'),
  category('category'),
  priority('priority'),
  status('status');

  const ListGroupBy(this.storageKey);

  /// 存进配置的串。**与枚举名解耦**，改 Dart 端的名字不该让用户配置失效。
  final String storageKey;

  static const ListGroupBy fallback = ListGroupBy.date;

  /// 认不出来就回落到默认，不抛 —— 同 `ViewKind.fromStorageKey` 的理由。
  static ListGroupBy fromStorageKey(String? key) {
    for (final v in ListGroupBy.values) {
      if (v.storageKey == key) return v;
    }
    return fallback;
  }
}

/// 组内排序（配置项 `view.listSortBy`）。
enum ListSortBy {
  time('time'),
  priority('priority'),
  created('created'),
  manual('manual');

  const ListSortBy(this.storageKey);

  final String storageKey;

  static const ListSortBy fallback = ListSortBy.time;

  static ListSortBy fromStorageKey(String? key) {
    for (final v in ListSortBy.values) {
      if (v.storageKey == key) return v;
    }
    return fallback;
  }
}

/// 一个分组。
@immutable
final class TaskGroup {
  const TaskGroup({
    required this.key,
    required this.title,
    required this.tasks,
    this.collapsedByDefault = false,
  });

  /// 稳定标识，供「展开/折叠」这类状态挂靠。
  ///
  /// **不能拿 [title] 当键**：改名、改语言、两个同名分类，都会让状态错位。
  final String key;

  final String title;
  final List<TaskOccurrence> tasks;

  /// 默认折叠。目前只有「逾期」是（§2.4）——
  /// 展开是用户的主动选择，避免一打开就被一堆红字压住。
  final bool collapsedByDefault;

  @override
  String toString() => 'TaskGroup($key, ${tasks.length} 条)';
}

/// 按日期分组时的组键。顺序即显示顺序（§2.1）。
enum DateBucket {
  overdue('overdue', '逾期'),
  today('today', '今天'),
  tomorrow('tomorrow', '明天'),
  thisWeek('this-week', '本周'),
  later('later', '更远'),
  noDate('no-date', '无日期');

  const DateBucket(this.key, this.title);

  final String key;
  final String title;
}

/// 把一条任务归到哪个日期桶。
///
/// 「本周」= 今天之后、且在**今天所在自然周的周日**之前（含）。
/// 用自然周而不是「往后七天」：用户说「本周」指的是日历上的这一周，
/// 周五看到的「本周」不该包含下周三。
///
/// **已完成的逾期任务不算逾期**：它做完了，只是做晚了。
/// 把它塞进逾期组会让那个计数一直下不去，而计数正是用户判断
/// 「还欠多少」的依据。
DateBucket bucketOf(TaskOccurrence task, PlanDate today) {
  final date = task.planDate;
  if (date == null) return DateBucket.noDate;

  if (date.isBefore(today)) {
    return task.status == TaskStatus.done
        ? DateBucket.today
        : DateBucket.overdue;
  }
  if (date == today) return DateBucket.today;
  if (date == today.addDays(1)) return DateBucket.tomorrow;

  // 今天所在自然周的最后一天（周日）。DateTime.weekday: 周一=1…周日=7。
  final weekday = DateTime.utc(today.year, today.month, today.day).weekday;
  final endOfWeek = today.addDays(7 - weekday);
  if (!date.isAfter(endOfWeek)) return DateBucket.thisWeek;

  return DateBucket.later;
}

/// 分组 + 组内排序。
///
/// [categories] 用于「按分类」分组时取名字与顺序；其余维度用不到。
List<TaskGroup> groupTasks(
  List<TaskOccurrence> tasks, {
  required ListGroupBy groupBy,
  required ListSortBy sortBy,
  required PlanDate today,
  List<Category> categories = const [],
  String uncategorizedTitle = '未分类',
}) {
  final groups = switch (groupBy) {
    ListGroupBy.date => _byDate(tasks, today),
    ListGroupBy.category => _byCategory(tasks, categories, uncategorizedTitle),
    ListGroupBy.priority => _byPriority(tasks),
    ListGroupBy.status => _byStatus(tasks),
  };

  return [
    for (final g in groups)
      if (g.tasks.isNotEmpty)
        TaskGroup(
          key: g.key,
          title: g.title,
          collapsedByDefault: g.collapsedByDefault,
          tasks: _sorted(g.tasks, sortBy, today),
        ),
  ];
}

List<TaskGroup> _byDate(List<TaskOccurrence> tasks, PlanDate today) {
  final buckets = <DateBucket, List<TaskOccurrence>>{
    for (final b in DateBucket.values) b: <TaskOccurrence>[],
  };
  for (final task in tasks) {
    buckets[bucketOf(task, today)]!.add(task);
  }
  return [
    for (final b in DateBucket.values)
      TaskGroup(
        key: b.key,
        title: b.title,
        tasks: buckets[b]!,
        collapsedByDefault: b == DateBucket.overdue,
      ),
  ];
}

List<TaskGroup> _byCategory(
  List<TaskOccurrence> tasks,
  List<Category> categories,
  String uncategorizedTitle,
) {
  final byId = <String, List<TaskOccurrence>>{
    for (final c in categories) c.id: <TaskOccurrence>[],
  };
  final uncategorized = <TaskOccurrence>[];

  for (final task in tasks) {
    final id = task.categoryId;
    // 分类被删了的任务归到「未分类」，不是凭空消失 ——
    // 与卡片渲染的处理保持一致。
    if (id == null || !byId.containsKey(id)) {
      uncategorized.add(task);
    } else {
      byId[id]!.add(task);
    }
  }

  return [
    // 分类按它们自己的 orderIndex（调用方已排好序）。
    for (final c in categories)
      TaskGroup(key: 'category:${c.id}', title: c.name, tasks: byId[c.id]!),
    // 「未分类」**放最后** —— 它不是一个分类，是「还没归类」，
    // 排在真分类前面会让它显得比它们重要。
    TaskGroup(
      key: 'category:none',
      title: uncategorizedTitle,
      tasks: uncategorized,
    ),
  ];
}

List<TaskGroup> _byPriority(List<TaskOccurrence> tasks) {
  // 紧急 → 高 → 普通 → 低 → 无（§2.1），即 value 降序。
  const order = [
    TaskPriority.urgent,
    TaskPriority.high,
    TaskPriority.normal,
    TaskPriority.low,
    TaskPriority.none,
  ];
  const titles = {
    TaskPriority.urgent: '紧急',
    TaskPriority.high: '高',
    TaskPriority.normal: '普通',
    TaskPriority.low: '低',
    TaskPriority.none: '无',
  };
  return [
    for (final p in order)
      TaskGroup(
        key: 'priority:${p.name}',
        title: titles[p]!,
        tasks: tasks.where((t) => t.priority == p).toList(),
      ),
  ];
}

List<TaskGroup> _byStatus(List<TaskOccurrence> tasks) {
  // 进行中 → 待办 → 已完成（§2.1）。
  const order = [
    (TaskStatus.inProgress, '进行中'),
    (TaskStatus.pending, '待办'),
    (TaskStatus.done, '已完成'),
  ];
  return [
    for (final (status, title) in order)
      TaskGroup(
        key: 'status:${status.name}',
        title: title,
        tasks: tasks.where((t) => t.status == status).toList(),
      ),
    // `skipped` 不在 §2.1 的顺序里，但任务确实可能是这个状态 ——
    // 不给它一个组的话，那些任务会**从列表里消失**。
    // 宁可多一个组，也不要静默吞掉数据。
    TaskGroup(
      key: 'status:skipped',
      title: '已跳过',
      tasks: tasks.where((t) => t.status == TaskStatus.skipped).toList(),
    ),
  ];
}

/// 组内排序。
///
/// **每种排序都以 `id` 收尾**，让顺序完全确定：主键相等时不兜底的话，
/// 同一份数据两次渲染可能不同序 —— 列表跳动，golden 随机变红。
List<TaskOccurrence> _sorted(
  List<TaskOccurrence> tasks,
  ListSortBy sortBy,
  PlanDate today,
) {
  final list = [...tasks];
  int byId(TaskOccurrence a, TaskOccurrence b) => a.id.compareTo(b.id);

  switch (sortBy) {
    case ListSortBy.time:
      list.sort((a, b) {
        final byDate = _compareNullableDate(a.planDate, b.planDate);
        if (byDate != 0) return byDate;
        final byMinute = _compareNullableInt(
          a.startMinute?.value,
          b.startMinute?.value,
        );
        return byMinute != 0 ? byMinute : byId(a, b);
      });
    case ListSortBy.priority:
      list.sort((a, b) {
        // 降序：紧急在前。
        final byPriority = b.priority.value.compareTo(a.priority.value);
        return byPriority != 0 ? byPriority : byId(a, b);
      });
    case ListSortBy.created:
      // **按 id 就是按创建时间**：任务 ID 是 UUID v7，前 48 bit 是毫秒
      // 时间戳，字典序 ≈ 生成时序（见 `UuidV7Generator` 的注释）。
      //
      // 同毫秒创建的两条之间顺序是随机的 —— 对「按创建时间看一眼」
      // 这个用途足够。真要精确到条，得把信封里的 createdAt 带进实体，
      // 那是另一笔账（当前领域实体刻意不带信封字段）。
      list.sort(byId);
    case ListSortBy.manual:
      list.sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : byId(a, b);
      });
  }
  return list;
}

/// 无日期的排在有日期的**后面**。
///
/// 反过来的话，一堆「哪天做都行」的事会顶在最上面，
/// 把真正有时限的压下去。
int _compareNullableDate(PlanDate? a, PlanDate? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

/// 无时刻（全天）的排在有时刻的**前面**。
///
/// 全天任务是「这一天里随时」，把它放在当天最上面符合「先看今天有什么」
/// 的读法；放到最后会让它被具体时刻的事挤到看不见。
int _compareNullableInt(int? a, int? b) {
  if (a == null && b == null) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  return a.compareTo(b);
}

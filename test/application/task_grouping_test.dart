/// 列表分组与组内排序（view-specs §2.1、§2.2）。
///
/// 纯逻辑，不建 widget、不开库。「今天」由参数传入，
/// 于是每条规则都能钉在一个固定日期上验。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/domain/entities/category.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';
import 'package:planning_assistant/features/views/task_list/application/task_grouping.dart';

/// 2026-09-08 是**周二** —— 挑它是为了让「本周」有前有后：
/// 周日（9/13）之前还有五天，之后就是「更远」。
/// 挑周日的话「本周」是空的，那条规则等于没验。
const _today = PlanDate(2026, 9, 8);

Task _task(
  String id, {
  PlanDate? date,
  MinuteOfDay? minute,
  TaskStatus status = TaskStatus.pending,
  TaskPriority priority = TaskPriority.normal,
  String? categoryId,
  double sortOrder = 0,
  bool isAllDay = false,
}) => Task(
  id: id,
  title: id,
  kind: TaskKind.single,
  timeZoneId: 'Asia/Shanghai',
  planDate: date,
  startMinute: minute,
  status: status,
  priority: priority,
  categoryId: categoryId,
  sortOrder: sortOrder,
  isAllDay: isAllDay,
);

List<String> _keys(List<TaskGroup> groups) => groups.map((g) => g.key).toList();

List<String> _idsIn(List<TaskGroup> groups, String key) =>
    groups.firstWhere((g) => g.key == key).tasks.map((t) => t.id).toList();

List<TaskGroup> _group(
  List<Task> tasks, {
  ListGroupBy groupBy = ListGroupBy.date,
  ListSortBy sortBy = ListSortBy.time,
  List<Category> categories = const [],
}) => groupTasks(
  tasks,
  groupBy: groupBy,
  sortBy: sortBy,
  today: _today,
  categories: categories,
);

void main() {
  group('按日期分组（§2.1）', () {
    test('六个桶各归各的', () {
      final groups = _group([
        _task('过期', date: const PlanDate(2026, 9, 1)),
        _task('今天', date: _today),
        _task('明天', date: const PlanDate(2026, 9, 9)),
        _task('本周', date: const PlanDate(2026, 9, 12)),
        _task('更远', date: const PlanDate(2026, 10, 1)),
        _task('无期'),
      ]);

      expect(_keys(groups), [
        'overdue',
        'today',
        'tomorrow',
        'this-week',
        'later',
        'no-date',
      ]);
      expect(_idsIn(groups, 'overdue'), ['过期']);
      expect(_idsIn(groups, 'no-date'), ['无期']);
    });

    test('空组不出现 —— 不给用户一排空标题', () {
      final groups = _group([_task('只有今天', date: _today)]);
      expect(_keys(groups), ['today']);
    });

    test('「本周」是自然周，不是往后七天', () {
      // 今天周二 9/8，本周到周日 9/13。9/14 是下周一。
      // 若实现成「今天+7」，9/14 会被算进本周。
      final groups = _group([
        _task('周日', date: const PlanDate(2026, 9, 13)),
        _task('下周一', date: const PlanDate(2026, 9, 14)),
      ]);
      expect(_idsIn(groups, 'this-week'), ['周日']);
      expect(_idsIn(groups, 'later'), ['下周一']);
    });

    test('已完成的逾期任务**不算逾期**', () {
      // 它做完了，只是做晚了。留在逾期组会让那个计数一直下不去，
      // 而计数正是用户判断「还欠多少」的依据。
      final groups = _group([
        _task('做完了', date: const PlanDate(2026, 9, 1), status: TaskStatus.done),
      ]);
      expect(_keys(groups), isNot(contains('overdue')));
    });

    test('对照组：没完成的逾期任务确实进逾期组', () {
      // 否则「一律不算逾期」也能让上面那条绿，而那样逾期分组就废了。
      final groups = _group([_task('没做', date: const PlanDate(2026, 9, 1))]);
      expect(_idsIn(groups, 'overdue'), ['没做']);
    });

    test('逾期组默认折叠，其余不折叠（§2.4）', () {
      final groups = _group([
        _task('逾期', date: const PlanDate(2026, 9, 1)),
        _task('今天', date: _today),
      ]);
      expect(
        groups.firstWhere((g) => g.key == 'overdue').collapsedByDefault,
        isTrue,
      );
      expect(
        groups.firstWhere((g) => g.key == 'today').collapsedByDefault,
        isFalse,
        reason: '只有逾期组默认折叠；全都折叠等于列表打开是空的',
      );
    });
  });

  group('按分类分组（§2.1）', () {
    const work = Category(
      id: 'c-work',
      name: '工作',
      colorArgb: 1,
      icon: 'briefcase',
      orderIndex: 0,
    );
    const life = Category(
      id: 'c-life',
      name: '生活',
      colorArgb: 2,
      icon: 'home',
      orderIndex: 1,
    );

    test('按分类自己的顺序，「未分类」在最后', () {
      final groups = _group(
        [
          _task('a', categoryId: 'c-life'),
          _task('b', categoryId: 'c-work'),
          _task('c'),
        ],
        groupBy: ListGroupBy.category,
        categories: const [work, life],
      );
      expect(_keys(groups), [
        'category:c-work',
        'category:c-life',
        'category:none',
      ]);
    });

    test('分类被删了的任务归到未分类，不是消失', () {
      // 卡片渲染也是这么处理的，两处必须一致 ——
      // 不一致的表现是「卡片显示未分类，但它不在未分类组里」。
      final groups = _group(
        [_task('孤儿', categoryId: 'c-已删除')],
        groupBy: ListGroupBy.category,
        categories: const [work],
      );
      expect(_idsIn(groups, 'category:none'), ['孤儿']);
    });

    test('组键用分类 id 而不是名字', () {
      // 两个同名分类、或用户改名，用名字当键会让折叠状态错位。
      final groups = _group(
        [_task('a', categoryId: 'c-work')],
        groupBy: ListGroupBy.category,
        categories: const [work],
      );
      expect(groups.single.key, contains('c-work'));
      expect(groups.single.title, '工作');
    });
  });

  group('按优先级 / 状态分组（§2.1）', () {
    test('优先级：紧急 → 高 → 普通 → 低 → 无', () {
      final groups = _group([
        _task('低', priority: TaskPriority.low),
        _task('急', priority: TaskPriority.urgent),
        _task('普', priority: TaskPriority.normal),
      ], groupBy: ListGroupBy.priority);
      expect(_keys(groups), [
        'priority:urgent',
        'priority:normal',
        'priority:low',
      ]);
    });

    test('状态：进行中 → 待办 → 已完成', () {
      final groups = _group([
        _task('完', status: TaskStatus.done),
        _task('待', status: TaskStatus.pending),
        _task('中', status: TaskStatus.inProgress),
      ], groupBy: ListGroupBy.status);
      expect(_keys(groups), [
        'status:inProgress',
        'status:pending',
        'status:done',
      ]);
    });

    test('skipped 也有组 —— 不静默吞掉数据', () {
      // §2.1 的顺序里没写 skipped，但任务确实可能是这个状态。
      // 不给组的话那些任务会从列表里消失，而「消失」是最难查的 bug。
      final groups = _group([
        _task('跳过了', status: TaskStatus.skipped),
      ], groupBy: ListGroupBy.status);
      expect(_idsIn(groups, 'status:skipped'), ['跳过了']);
    });

    test('任何分组维度下，任务总数都不变', () {
      // 这条是对上面所有分组的兜底：分组只是重新排列，不该多也不该少。
      final tasks = [
        _task('a', date: const PlanDate(2026, 9, 1)),
        _task('b', date: _today, status: TaskStatus.done),
        _task('c', priority: TaskPriority.urgent, categoryId: 'x'),
        _task('d', status: TaskStatus.skipped),
        _task('e'),
      ];
      for (final by in ListGroupBy.values) {
        final groups = _group(tasks, groupBy: by);
        final total = groups.fold(0, (n, g) => n + g.tasks.length);
        expect(total, tasks.length, reason: '$by 分组后数量对不上');
      }
    });
  });

  group('组内排序（§2.2）', () {
    test('时间升序：先按日期，再按时刻', () {
      final groups = _group([
        _task('晚', date: _today, minute: MinuteOfDay.of(18, 0)),
        _task('早', date: _today, minute: MinuteOfDay.of(9, 0)),
      ]);
      expect(_idsIn(groups, 'today'), ['早', '晚']);
    });

    test('全天排在有时刻的前面', () {
      // 全天是「这一天里随时」，放最上面符合「先看今天有什么」的读法；
      // 放最后会被具体时刻的事挤到看不见。
      final groups = _group([
        _task('九点', date: _today, minute: MinuteOfDay.of(9, 0)),
        _task('全天', date: _today, isAllDay: true),
      ]);
      expect(_idsIn(groups, 'today'), ['全天', '九点']);
    });

    test('优先级降序', () {
      final groups = _group([
        _task('低', date: _today, priority: TaskPriority.low),
        _task('急', date: _today, priority: TaskPriority.urgent),
      ], sortBy: ListSortBy.priority);
      expect(_idsIn(groups, 'today'), ['急', '低']);
    });

    test('手动排序按 sortOrder', () {
      final groups = _group([
        _task('b', date: _today, sortOrder: 2),
        _task('a', date: _today, sortOrder: 1),
      ], sortBy: ListSortBy.manual);
      expect(_idsIn(groups, 'today'), ['a', 'b']);
    });

    test('创建时间用 id 排 —— UUID v7 字典序 ≈ 生成时序', () {
      final groups = _group([
        _task('019a0002', date: _today),
        _task('019a0001', date: _today),
      ], sortBy: ListSortBy.created);
      expect(_idsIn(groups, 'today'), ['019a0001', '019a0002']);
    });

    test('主键相等时用 id 兜底 —— 顺序必须完全确定', () {
      // 不兜底的话同一份数据两次渲染可能不同序：列表跳动，golden 随机变红。
      final tasks = [
        _task('c', date: _today, minute: MinuteOfDay.of(9, 0)),
        _task('a', date: _today, minute: MinuteOfDay.of(9, 0)),
        _task('b', date: _today, minute: MinuteOfDay.of(9, 0)),
      ];
      for (final by in ListSortBy.values) {
        final first = _idsIn(_group(tasks, sortBy: by), 'today');
        final second = _idsIn(
          _group(tasks.reversed.toList(), sortBy: by),
          'today',
        );
        expect(first, second, reason: '$by 排序不稳定：输入顺序变了结果就变');
        expect(first, ['a', 'b', 'c'], reason: '$by 没有按 id 兜底');
      }
    });

    test('无日期的排在有日期的后面', () {
      // 反过来的话，一堆「哪天做都行」的事会顶在最上面。
      // 这条要在同一个组里验，所以按分类分组。
      final groups = _group([
        _task('无期'),
        _task('有期', date: const PlanDate(2026, 10, 1)),
      ], groupBy: ListGroupBy.category);
      expect(_idsIn(groups, 'category:none'), ['有期', '无期']);
    });
  });

  group('配置串往返（§2.1/§2.2 的两个配置项）', () {
    test('分组维度', () {
      for (final v in ListGroupBy.values) {
        expect(ListGroupBy.fromStorageKey(v.storageKey), v);
      }
      expect(ListGroupBy.fromStorageKey('kanban'), ListGroupBy.fallback);
      expect(ListGroupBy.fromStorageKey(null), ListGroupBy.date);
    });

    test('排序维度', () {
      for (final v in ListSortBy.values) {
        expect(ListSortBy.fromStorageKey(v.storageKey), v);
      }
      expect(ListSortBy.fromStorageKey('random'), ListSortBy.fallback);
      expect(ListSortBy.fromStorageKey(null), ListSortBy.time);
    });

    test('存储串互不相同', () {
      expect(
        ListGroupBy.values.map((v) => v.storageKey).toSet(),
        hasLength(ListGroupBy.values.length),
      );
      expect(
        ListSortBy.values.map((v) => v.storageKey).toSet(),
        hasLength(ListSortBy.values.length),
      );
    });
  });
}

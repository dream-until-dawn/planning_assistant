/// 筛选的执行（view-specs §2.3）。纯函数，不建 widget、不开库。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';
import 'package:planning_assistant/features/views/shared/application/task_filter.dart';
import 'package:planning_assistant/features/views/shared/application/view_shared_state.dart';

Task _task(
  String id, {
  String? title,
  String? note,
  String? categoryId,
  TaskStatus status = TaskStatus.pending,
  TaskPriority priority = TaskPriority.normal,
  PlanDate? date,
}) => Task(
  id: id,
  title: title ?? id,
  note: note,
  kind: TaskKind.single,
  timeZoneId: 'Asia/Shanghai',
  categoryId: categoryId,
  status: status,
  priority: priority,
  planDate: date,
);

List<String> _ids(List<Task> tasks) => tasks.map((t) => t.id).toList();

void main() {
  group('空筛选不筛', () {
    test('FilterSpec.none 原样返回', () {
      final tasks = [_task('a'), _task('b')];
      expect(_ids(applyFilter(tasks, FilterSpec.none)), ['a', 'b']);
    });

    test('每个维度的空集合都表示「不筛这个维度」', () {
      // **不是「一个都不匹配」。** 用户取消最后一个勾选时期待回到全部，
      // 反过来实现的话，取消最后一项会让人以为任务丢了。
      final tasks = [_task('a', categoryId: 'c1'), _task('b')];
      const filter = FilterSpec(categoryIds: {}, priorities: {}, statuses: {});
      expect(_ids(applyFilter(tasks, filter)), ['a', 'b']);
    });
  });

  group('分类', () {
    test('只留选中的分类', () {
      final tasks = [
        _task('工作的', categoryId: 'c-work'),
        _task('生活的', categoryId: 'c-life'),
      ];
      expect(
        _ids(applyFilter(tasks, const FilterSpec(categoryIds: {'c-work'}))),
        ['工作的'],
      );
    });

    test('多选取并集', () {
      final tasks = [
        _task('工作的', categoryId: 'c-work'),
        _task('生活的', categoryId: 'c-life'),
        _task('学习的', categoryId: 'c-study'),
      ];
      expect(
        _ids(
          applyFilter(
            tasks,
            const FilterSpec(categoryIds: {'c-work', 'c-life'}),
          ),
        ),
        ['工作的', '生活的'],
      );
    });

    test('`null` 这一项筛的是「未分类」（settings-spec §3.0）', () {
      // 未分类是 categoryId IS NULL，不是某一行 —— 所以它就是这个维度里的
      // 一个取值。用一个单独的 bool 表达的话，这个维度会有两套开关。
      final tasks = [
        _task('没分类', categoryId: null),
        _task('有分类', categoryId: 'c-work'),
      ];
      expect(_ids(applyFilter(tasks, const FilterSpec(categoryIds: {null}))), [
        '没分类',
      ]);
    });

    test('未分类可以和真分类一起选', () {
      final tasks = [
        _task('没分类'),
        _task('工作的', categoryId: 'c-work'),
        _task('生活的', categoryId: 'c-life'),
      ];
      expect(
        _ids(
          applyFilter(tasks, const FilterSpec(categoryIds: {null, 'c-work'})),
        ),
        ['没分类', '工作的'],
      );
    });
  });

  group('状态与优先级', () {
    test('按状态筛', () {
      final tasks = [_task('待办的'), _task('完成的', status: TaskStatus.done)];
      expect(
        _ids(applyFilter(tasks, const FilterSpec(statuses: {TaskStatus.done}))),
        ['完成的'],
      );
    });

    test('按优先级筛', () {
      final tasks = [_task('急的', priority: TaskPriority.urgent), _task('普通的')];
      expect(
        _ids(
          applyFilter(
            tasks,
            const FilterSpec(priorities: {TaskPriority.urgent}),
          ),
        ),
        ['急的'],
      );
    });
  });

  group('关键词', () {
    test('匹配标题', () {
      final tasks = [_task('a', title: '预约体检'), _task('b', title: '买菜')];
      expect(_ids(applyFilter(tasks, const FilterSpec(keyword: '体检'))), ['a']);
    });

    test('也匹配备注 —— 细节写在备注里，而细节正是想搜的', () {
      final tasks = [
        _task('a', title: '看医生', note: '记得带体检报告'),
        _task('b', title: '买菜'),
      ];
      expect(_ids(applyFilter(tasks, const FilterSpec(keyword: '体检'))), ['a']);
    });

    test('大小写不敏感', () {
      final tasks = [_task('a', title: 'Standup Meeting')];
      expect(_ids(applyFilter(tasks, const FilterSpec(keyword: 'standup'))), [
        'a',
      ]);
    });

    test('两端空白被忽略', () {
      // 从别处粘贴常带空格，而带空格的关键词一条都匹配不上，
      // 表现是「搜什么都没有」。
      final tasks = [_task('a', title: '预约体检')];
      expect(_ids(applyFilter(tasks, const FilterSpec(keyword: '  体检 '))), [
        'a',
      ]);
    });

    test('只有空白等于没搜', () {
      final tasks = [_task('a'), _task('b')];
      expect(_ids(applyFilter(tasks, const FilterSpec(keyword: '   '))), [
        'a',
        'b',
      ]);
    });
  });

  group('日期范围', () {
    final tasks = [
      _task('早', date: const PlanDate(2026, 8, 20)),
      _task('中', date: const PlanDate(2026, 9, 10)),
      _task('晚', date: const PlanDate(2026, 10, 5)),
      _task('无期'),
    ];

    test('两端都给：闭区间', () {
      expect(
        _ids(
          applyFilter(
            tasks,
            const FilterSpec(
              dateFrom: PlanDate(2026, 9, 1),
              dateTo: PlanDate(2026, 9, 30),
            ),
          ),
        ),
        ['中'],
      );
    });

    test('端点本身包含在内', () {
      expect(
        _ids(
          applyFilter(
            tasks,
            const FilterSpec(
              dateFrom: PlanDate(2026, 9, 10),
              dateTo: PlanDate(2026, 9, 10),
            ),
          ),
        ),
        ['中'],
      );
    });

    test('只给起点：开区间', () {
      expect(
        _ids(
          applyFilter(tasks, const FilterSpec(dateFrom: PlanDate(2026, 9, 1))),
        ),
        ['中', '晚'],
      );
    });

    test('无日期的任务在有日期范围时被排除', () {
      // 它不落在任何区间里 ——「9 月的事」不该包含一件没定哪天的事。
      // 反过来（无日期永远保留）会让日期范围形同虚设。
      expect(
        _ids(
          applyFilter(tasks, const FilterSpec(dateTo: PlanDate(2026, 12, 31))),
        ),
        ['早', '中', '晚'],
      );
    });
  });

  group('条件可叠加（§2.3）：维度之间取交集', () {
    test('分类 且 状态', () {
      final tasks = [
        _task('工作待办', categoryId: 'c-work'),
        _task('工作已完成', categoryId: 'c-work', status: TaskStatus.done),
        _task('生活待办', categoryId: 'c-life'),
      ];
      expect(
        _ids(
          applyFilter(
            tasks,
            const FilterSpec(
              categoryIds: {'c-work'},
              statuses: {TaskStatus.pending},
            ),
          ),
        ),
        ['工作待办'],
      );
    });

    test('叠加只会更少，不会更多', () {
      // 这条是对上面所有维度的兜底：多一个条件不该多筛出东西来。
      final tasks = [
        _task('a', categoryId: 'c1', title: '预约体检'),
        _task('b', categoryId: 'c2', status: TaskStatus.done),
        _task('c'),
      ];
      const one = FilterSpec(categoryIds: {'c1', 'c2'});
      final two = one.copyWith(keyword: '体检');
      expect(
        applyFilter(tasks, two).length,
        lessThanOrEqualTo(applyFilter(tasks, one).length),
      );
    });
  });

  group('切换', () {
    test('toggleCategory 来回切', () {
      var f = FilterSpec.none.toggleCategory('c1');
      expect(f.categoryIds, {'c1'});
      f = f.toggleCategory('c1');
      expect(f.categoryIds, isEmpty);
      expect(f.isEmpty, isTrue, reason: '切回去应当就是没筛');
    });

    test('toggleCategory 认得 null 这一项', () {
      final f = FilterSpec.none.toggleCategory(null);
      expect(f.categoryIds, {null});
      expect(f.toggleCategory(null).categoryIds, isEmpty);
    });

    test('toggleStatus 来回切', () {
      var f = FilterSpec.none.toggleStatus(TaskStatus.done);
      expect(f.statuses, {TaskStatus.done});
      f = f.toggleStatus(TaskStatus.done);
      expect(f.statuses, isEmpty);
    });

    test('切一个维度不碰别的维度', () {
      const f = FilterSpec(categoryIds: {'c1'}, keyword: '体检');
      final after = f.toggleStatus(TaskStatus.done);
      expect(after.categoryIds, {'c1'});
      expect(after.keyword, '体检');
    });
  });
}

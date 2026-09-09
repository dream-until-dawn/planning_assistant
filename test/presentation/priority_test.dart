/// 优先级（FR-TASK-01）—— 模型里一直有，界面上一直够不着。
///
/// ## 这一族债的第五次
///
/// `priority` 在 `Task`、`CreateTaskCommand`、`FilterSpec`、`applyFilter`
/// 里都有，唯独**没有任何界面产出它**：
///
/// - 编辑器没有优先级控件 → 所有任务恒为「普通」；
/// - 筛选条没有优先级维度 → `FilterSpec.priorities` 永远是空集。
///
/// 于是「按优先级筛」这个功能看起来是做好的（有字段、有筛选函数、
/// 有测试），实际上筛出来的永远是全部。
/// 又是 testing-strategy §1.6 那一族。
///
/// 这个文件验的是**那条链路现在通了**：界面拨得到 → 落库 → 筛得出来 →
/// 卡片上看得见。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';
import 'package:planning_assistant/features/views/shared/presentation/filter_bar.dart';

import '../support/app_harness.dart';

const _today = PlanDate(2026, 9, 8);

Task _task(String id, TaskPriority priority) => Task(
  id: id,
  title: id,
  kind: TaskKind.single,
  timeZoneId: 'Asia/Shanghai',
  planDate: _today,
  isAllDay: true,
  priority: priority,
);

Future<void> _pumpWith(WidgetTester tester, List<Task> tasks) async {
  await setScreenSize(tester, const Size(390, 844));
  await tester.pumpWidget(
    ProviderScope(
      overrides: viewPipelineOverrides(tasks: tasks, today: _today),
      child: PlanningAssistantApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('筛选条上这一维筛得动', () {
    testAppWidgets('点「紧急」之后只剩紧急的那条', (tester) async {
      await _pumpWith(tester, [
        _task('急事', TaskPriority.urgent),
        _task('平常事', TaskPriority.normal),
      ]);
      expect(find.text('急事'), findsOneWidget);
      expect(find.text('平常事'), findsOneWidget);

      await tester.tap(find.byKey(FilterBar.priorityKey(TaskPriority.urgent)));
      await tester.pumpAndSettle();

      expect(find.text('急事'), findsOneWidget);
      expect(
        find.text('平常事'),
        findsNothing,
        reason: '优先级这一维没起作用 —— 它一度筛出来的永远是全部',
      );
    });

    testAppWidgets('再点一次取消，回到全部', (tester) async {
      // 取消不了的话，这一维就是一条走进去出不来的路
      // （同 M2 那条「到某天为止」）。
      await _pumpWith(tester, [
        _task('急事', TaskPriority.urgent),
        _task('平常事', TaskPriority.normal),
      ]);
      final chip = find.byKey(FilterBar.priorityKey(TaskPriority.urgent));
      await tester.tap(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(find.text('平常事'), findsOneWidget);
    });

    testAppWidgets('五档都在，顺序是紧急 → 无', (tester) async {
      // 顺序与列表的「按优先级」分组、编辑器里的选择区共用同一份
      // （`TaskPriority.byImportance`）。三处各写一遍的话迟早对不上。
      await _pumpWith(tester, [_task('随便', TaskPriority.normal)]);
      for (final p in TaskPriority.values) {
        expect(
          find.byKey(FilterBar.priorityKey(p)),
          findsOneWidget,
          reason: '${p.label} 这一档筛选条上没有',
        );
      }
      final xs = [
        for (final p in TaskPriority.byImportance)
          tester.getRect(find.byKey(FilterBar.priorityKey(p))).left,
      ];
      expect(
        xs,
        orderedEquals(<double>[...xs]..sort()),
        reason: '筛选条上的顺序不是「紧急 → 无」',
      );
    });
  });

  group('卡片上看得见', () {
    testAppWidgets('非普通的显示出来', (tester) async {
      await _pumpWith(tester, [_task('急事', TaskPriority.urgent)]);
      final card = tester.widget<TaskCard>(find.byType(TaskCard));
      expect(card.data.priorityLabel, '紧急');
      expect(find.textContaining('紧急'), findsWidgets);
    });

    testAppWidgets('「普通」不显示 —— 每张卡都挂一个「普通」等于什么也没说', (tester) async {
      await _pumpWith(tester, [_task('平常事', TaskPriority.normal)]);
      final card = tester.widget<TaskCard>(find.byType(TaskCard));
      expect(card.data.priorityLabel, isNull);
    });
  });

  group('编辑器里拨得到（与写路径台账互补）', () {
    testAppWidgets('新建时默认「普通」，改成「高」之后卡片跟着变', (tester) async {
      // 台账那条验的是**落库**；这条验的是**改完之后看得见**。
      await setScreenSize(tester, const Size(390, 844));
      final harness = appHarness();
      await tester.pumpWidget(
        ProviderScope(
          overrides: harness.overrides,
          child: PlanningAssistantApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(AppShell.fabKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '交方案');
      await tester.pump();
      await tapVisible(
        tester,
        TaskEditorPage.priorityChipKey(TaskPriority.high),
      );
      await tapVisible(tester, TaskEditorPage.saveButtonKey);

      final card = tester.widget<TaskCard>(find.byType(TaskCard));
      expect(card.data.priorityLabel, '高');
    });
  });
}

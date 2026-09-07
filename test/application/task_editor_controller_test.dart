/// 编辑器表单的行为（FR-TASK-01）。
///
/// 纯 provider 层，不建 widget —— 这些是**状态规则**，
/// 和界面长什么样无关。J-01 那条旅程验的是链路，这里验的是规则。
@TestOn('vm')
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app_providers.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/features/task/application/task_editor_controller.dart';

import '../support/app_harness.dart';

ProviderContainer _container() {
  final container = ProviderContainer(overrides: appHarness().overrides);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('能不能保存', () {
    test('空标题不能存', () {
      expect(const TaskDraft().canSave, isFalse);
    });

    test('只有空格也不能存', () {
      // 不 trim 的话能存出一条看着空白、却怎么也搜不到的任务。
      expect(const TaskDraft(title: '   ').canSave, isFalse);
      expect(const TaskDraft(title: '\n\t ').canSave, isFalse);
    });

    test('有字就能存 —— 其余字段全空也行（FR-TASK-01 验收）', () {
      expect(const TaskDraft(title: '买菜').canSave, isTrue);
    });

    test('存的时候标题两端的空白被去掉', () async {
      final c = _container();
      c.read(taskEditorProvider.notifier).setTitle('  买菜  ');
      await c.read(taskEditorProvider.notifier).save();

      final tasks = await c.read(taskRepositoryProvider).findTasks();
      expect(tasks.single.title, '买菜');
    });

    test('挡不住的话至少要抛，而不是存一条空标题进去', () {
      // 「按钮禁用」是界面约定，不是不变量 —— 直接调 save 也得挡住。
      final c = _container();
      expect(c.read(taskEditorProvider.notifier).save, throwsStateError);
    });
  });

  group('全天与时刻是互斥的', () {
    test('打开全天会清掉已选时刻', () {
      // 否则会存下「全天，但有 09:30」——两个字段互相矛盾，
      // 而下游（列表的时间标签、提醒排期）各自会读出不同的结论。
      final c = _container();
      final n = c.read(taskEditorProvider.notifier)
        ..setStartMinute(MinuteOfDay.of(9, 30))
        ..setAllDay(true);

      final draft = c.read(taskEditorProvider);
      expect(draft.isAllDay, isTrue);
      expect(draft.startMinute, isNull);
      expect(n, isNotNull);
    });

    test('选一个时刻会自动关掉全天', () {
      final c = _container();
      c.read(taskEditorProvider.notifier).setStartMinute(MinuteOfDay.of(9, 30));

      final draft = c.read(taskEditorProvider);
      expect(draft.isAllDay, isFalse);
      expect(draft.startMinute, MinuteOfDay.of(9, 30));
    });

    test('关掉全天**不**自动塞一个时刻', () {
      // 对照组：自动塞一个「09:00」能让上面两条都绿，
      // 但那是替用户做决定 —— 由界面让他挑。
      final c = _container();
      c.read(taskEditorProvider.notifier).setAllDay(false);

      final draft = c.read(taskEditorProvider);
      expect(draft.isAllDay, isFalse);
      expect(draft.startMinute, isNull);
    });

    test('全天任务存下去时不带时刻', () async {
      final c = _container();
      final n = c.read(taskEditorProvider.notifier)
        ..setTitle('读完这本书')
        ..setStartMinute(MinuteOfDay.of(9, 30))
        ..setAllDay(true);
      await n.save();

      final task = (await c.read(taskRepositoryProvider).findTasks()).single;
      expect(task.isAllDay, isTrue);
      expect(task.startMinute, isNull);
    });
  });

  group('存下去的时区是用户所在时区（ADR-0005）', () {
    test('不是 UTC', () async {
      // 存 UTC 的话，「每天 07:00 起床」飞到伦敦后会变成当地时间的别的点。
      final c = ProviderContainer(
        overrides: appHarness(zone: 'Asia/Shanghai').overrides,
      );
      addTearDown(c.dispose);

      final n = c.read(taskEditorProvider.notifier)..setTitle('起床');
      await n.save();

      final task = (await c.read(taskRepositoryProvider).findTasks()).single;
      expect(task.timeZoneId, 'Asia/Shanghai');
    });

    test('换个时区就存另一个 —— 不是写死的常量', () async {
      final c = ProviderContainer(
        overrides: appHarness(zone: 'America/New_York').overrides,
      );
      addTearDown(c.dispose);

      final n = c.read(taskEditorProvider.notifier)..setTitle('起床');
      await n.save();

      final task = (await c.read(taskRepositoryProvider).findTasks()).single;
      expect(task.timeZoneId, 'America/New_York');
    });
  });

  group('日期', () {
    test('可以设，也可以清掉', () {
      final c = _container();
      final n = c.read(taskEditorProvider.notifier)
        ..setPlanDate(const PlanDate(2026, 9, 20));
      expect(c.read(taskEditorProvider).planDate, const PlanDate(2026, 9, 20));

      n.setPlanDate(null);
      expect(c.read(taskEditorProvider).planDate, isNull);
    });
  });
}

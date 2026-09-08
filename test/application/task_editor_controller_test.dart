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
import 'package:planning_assistant/domain/entities/task.dart';
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

  group('时刻不能脱离日期', () {
    // 真机上撞见过一条「12:32，但不知道哪天」的数据 ——
    // 卡片上挂着一个指向不了任何一天的时刻。
    test('关掉全天时，没有日期就补上今天', () {
      final c = _container();
      c.read(taskEditorProvider.notifier).setAllDay(false);

      final draft = c.read(taskEditorProvider);
      expect(draft.isAllDay, isFalse);
      // 夹具的时钟是 2026-09-07 03:00 UTC，东八区即 09-07 11:00。
      expect(draft.planDate, const PlanDate(2026, 9, 7));
    });

    test('选时刻时，没有日期也补上今天', () {
      final c = _container();
      c
          .read(taskEditorProvider.notifier)
          .setStartMinute(MinuteOfDay.of(12, 32));
      expect(c.read(taskEditorProvider).planDate, const PlanDate(2026, 9, 7));
    });

    test('对照组：已经选了日期就不覆盖', () {
      // 「一律填今天」也能让上面两条绿，但那会把用户选的日期冲掉。
      final c = _container();
      final n = c.read(taskEditorProvider.notifier)
        ..setPlanDate(const PlanDate(2026, 12, 25))
        ..setAllDay(false);
      expect(c.read(taskEditorProvider).planDate, const PlanDate(2026, 12, 25));
      expect(n, isNotNull);
    });

    test('对照组：全天任务不会被塞一个日期', () {
      // 全天 + 无日期是合法的（「哪天做都行」），不该被自动填。
      final c = _container();
      c.read(taskEditorProvider.notifier).setAllDay(true);
      expect(c.read(taskEditorProvider).planDate, isNull);
    });

    test('补的日期是**本地墙钟**的今天，不是 UTC 的', () {
      // 东八区 07:00，UTC 还在前一天 23:00。截 UTC 的话会补错一天。
      final c = ProviderContainer(
        overrides: appHarness(
          now: DateTime.utc(2026, 9, 7, 23),
          zone: 'Asia/Shanghai',
        ).overrides,
      );
      addTearDown(c.dispose);
      c.read(taskEditorProvider.notifier).setAllDay(false);
      expect(c.read(taskEditorProvider).planDate, const PlanDate(2026, 9, 8));
    });

    test('落库的任务里，非全天必定有日期', () async {
      // setter 的保证是界面路径的保证；save() 再兜一道，
      // 因为将来多一个入口（语音、导入、Agent）就多一条绕过去的路。
      final c = _container();
      final n = c.read(taskEditorProvider.notifier)
        ..setTitle('开会')
        ..setStartMinute(MinuteOfDay.of(12, 32));
      await n.save();

      final task = (await c.read(taskRepositoryProvider).findTasks()).single;
      expect(task.isAllDay, isFalse);
      expect(task.startMinute, MinuteOfDay.of(12, 32));
      expect(task.planDate, isNotNull, reason: '有时刻就必须有日期');
    });
  });

  group('阶段的时间段（FR-TASK-02）', () {
    /// 建一个带两个阶段的草稿，返回容器与两个阶段 id。
    (ProviderContainer, List<String>) withTwoStages() {
      final c = _container();
      final n = c.read(taskEditorProvider.notifier);
      n.setTitle('写周报');
      n.addStage();
      n.addStage();
      final ids = [for (final s in c.read(taskEditorProvider).stages) s.id];
      n.setStageTitle(ids[0], '收集素材');
      n.setStageTitle(ids[1], '整理成稿');
      return (c, ids);
    }

    test('设了时间就存偏移与时长', () {
      final (c, ids) = withTwoStages();
      c
          .read(taskEditorProvider.notifier)
          .setStageTime(ids[1], startOffsetMinutes: 120, durationMinutes: 45);

      final stage = c
          .read(taskEditorProvider)
          .stages
          .firstWhere((s) => s.id == ids[1]);
      expect(stage.startOffsetMinutes, 120);
      expect(stage.durationMinutes, 45);
    });

    test('只动一个阶段，别的不受影响', () {
      // 「给所有阶段都写上」也能让上面那条绿。
      final (c, ids) = withTwoStages();
      c
          .read(taskEditorProvider.notifier)
          .setStageTime(ids[1], startOffsetMinutes: 120, durationMinutes: 45);

      final other = c
          .read(taskEditorProvider)
          .stages
          .firstWhere((s) => s.id == ids[0]);
      expect(other.startOffsetMinutes, isNull);
      expect(other.durationMinutes, isNull);
    });

    test('清掉开始时，时长也必须跟着没', () {
      // **这条界面自己走不到** —— 对话框的「不定时间」两个都传 null。
      // 但 FR-AI-01 说了会有别的入口（语音、导入、Agent）构造同一批调用，
      // 那时「只清开始、留着时长」就是一段悬空的长度：
      // 领域侧会得到一个 durationMinutes 非空而 startOffsetMinutes 为空的
      // 阶段，甘特图上无处安放。
      //
      // 一度只有旅程测试盯这里，而那条路上两个参数**总是同时为 null** ——
      // 于是把这个分支改成直接透传，一条测试都不会红。
      final (c, ids) = withTwoStages();
      final n = c.read(taskEditorProvider.notifier);
      n.setStageTime(ids[0], startOffsetMinutes: 30, durationMinutes: 60);
      n.setStageTime(ids[0], startOffsetMinutes: null, durationMinutes: 60);

      final stage = c
          .read(taskEditorProvider)
          .stages
          .firstWhere((s) => s.id == ids[0]);
      expect(stage.startOffsetMinutes, isNull);
      expect(stage.durationMinutes, isNull, reason: '没有开始就不该留着时长');
    });

    test('设阶段时间会补上任务的开始日期', () {
      // 偏移是相对任务开始算的，没有起点的偏移指向不了任何时刻。
      final (c, ids) = withTwoStages();
      expect(c.read(taskEditorProvider).planDate, isNull, reason: '前提：本来没有日期');

      c
          .read(taskEditorProvider.notifier)
          .setStageTime(ids[0], startOffsetMinutes: 0, durationMinutes: 60);
      expect(c.read(taskEditorProvider).planDate, isNotNull);
    });

    test('对照组：清时间时不该顺手补日期', () {
      final (c, ids) = withTwoStages();
      c
          .read(taskEditorProvider.notifier)
          .setStageTime(
            ids[0],
            startOffsetMinutes: null,
            durationMinutes: null,
          );
      expect(c.read(taskEditorProvider).planDate, isNull);
    });
  });

  group('阶段（FR-TASK-02）', () {
    test('默认没有阶段 —— 大多数任务是单项的', () {
      expect(const TaskDraft().stages, isEmpty);
      expect(const TaskDraft().isStaged, isFalse);
    });

    test('加两个填上标题就是阶段事项', () {
      final c = _container();
      final n = c.read(taskEditorProvider.notifier)
        ..addStage()
        ..addStage();
      final ids = c.read(taskEditorProvider).stages.map((s) => s.id).toList();
      n
        ..setStageTitle(ids[0], '打草稿')
        ..setStageTitle(ids[1], '定稿');

      expect(c.read(taskEditorProvider).isStaged, isTrue);
    });

    test('空白行不算阶段', () {
      // 点了「加阶段」还没来得及打字，那不该算一个阶段。
      final c = _container();
      final n = c.read(taskEditorProvider.notifier)
        ..addStage()
        ..addStage()
        ..addStage();
      final ids = c.read(taskEditorProvider).stages.map((s) => s.id).toList();
      n
        ..setStageTitle(ids[0], '打草稿')
        ..setStageTitle(ids[1], '   ');

      expect(c.read(taskEditorProvider).filledStages, hasLength(1));
      expect(c.read(taskEditorProvider).isStaged, isFalse);
    });

    test('只填一个阶段时**不能保存**', () {
      // 存下去会得到一个领域层直接拒绝的命令。与其在保存时炸，
      // 不如当场禁用按钮并说明原因。
      final c = _container();
      final n = c.read(taskEditorProvider.notifier)
        ..setTitle('写季度总结')
        ..addStage();
      final id = c.read(taskEditorProvider).stages.single.id;
      n.setStageTitle(id, '只有这一步');

      final draft = c.read(taskEditorProvider);
      expect(draft.canSave, isFalse);
      expect(draft.blockedReason, isNotNull);
    });

    test('对照组：把那一个删掉就又能存了（回到单项）', () {
      final c = _container();
      final n = c.read(taskEditorProvider.notifier)
        ..setTitle('写季度总结')
        ..addStage();
      final id = c.read(taskEditorProvider).stages.single.id;
      n.setStageTitle(id, '只有这一步');
      expect(c.read(taskEditorProvider).canSave, isFalse);

      n.removeStage(id);
      expect(c.read(taskEditorProvider).canSave, isTrue);
    });

    test('上移下移换的是位置', () {
      final c = _container();
      final n = c.read(taskEditorProvider.notifier)
        ..addStage()
        ..addStage();
      final ids = c.read(taskEditorProvider).stages.map((s) => s.id).toList();
      n
        ..setStageTitle(ids[0], '一')
        ..setStageTitle(ids[1], '二')
        ..moveStageUp(ids[1]);

      expect(c.read(taskEditorProvider).stages.map((s) => s.title), ['二', '一']);
    });

    test('第一个上移、最后一个下移都是空操作', () {
      // 不挡的话会越界，或者把列表转成环。
      final c = _container();
      final n = c.read(taskEditorProvider.notifier)
        ..addStage()
        ..addStage();
      final ids = c.read(taskEditorProvider).stages.map((s) => s.id).toList();
      n
        ..moveStageUp(ids[0])
        ..moveStageDown(ids[1]);

      expect(c.read(taskEditorProvider).stages.map((s) => s.id), ids);
    });

    test('存下去：kind 是 staged，阶段按列表位置连续编号', () async {
      // 编辑期间 orderIndex 一直不存在；领域层要求从 0 起连续，
      // 转换只发生在保存这一刻。转错的话领域层会拒绝 —— 那正是要验的。
      final c = _container();
      final n = c.read(taskEditorProvider.notifier)
        ..setTitle('写季度总结')
        ..addStage()
        ..addStage()
        ..addStage();
      final ids = c.read(taskEditorProvider).stages.map((s) => s.id).toList();
      n
        ..setStageTitle(ids[0], '一')
        ..setStageTitle(ids[1], '二')
        ..setStageTitle(ids[2], '三')
        // 中间那个删掉 —— 剩下的位置是 0 和 2，若直接拿位置当序号就不连续了。
        ..removeStage(ids[1]);
      await n.save();

      final repo = c.read(taskRepositoryProvider);
      final task = (await repo.findTasks()).single;
      expect(task.kind, TaskKind.staged);

      final stages = await repo.findStagesOfTask(task.id);
      expect(stages.map((s) => s.title), ['一', '三']);
      expect(stages.map((s) => s.orderIndex), [0, 1], reason: '必须从 0 起连续');
    });

    test('没有阶段时 kind 是 single，也不发第二条命令', () async {
      final c = _container();
      final n = c.read(taskEditorProvider.notifier)..setTitle('买菜');
      await n.save();

      final repo = c.read(taskRepositoryProvider);
      final task = (await repo.findTasks()).single;
      expect(task.kind, TaskKind.single);
      expect(await repo.findStagesOfTask(task.id), isEmpty);
    });
  });
}

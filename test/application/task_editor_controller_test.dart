/// 编辑器表单的行为（FR-TASK-01）。
///
/// 纯 provider 层，不建 widget —— 这些是**状态规则**，
/// 和界面长什么样无关。J-01 那条旅程验的是链路，这里验的是规则。
@TestOn('vm')
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app_providers.dart';
import 'package:planning_assistant/core/time/date_and_minute.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/features/task/application/task_editor_controller.dart';
import 'package:planning_assistant/features/task/application/task_shape.dart';

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

    test('有字就能存 —— 但那是**临时事项**那一档（FR-TASK-01 验收）', () {
      // 「仅填标题即可保存」2026-09-09 起是临时事项的性质，
      // 不再是所有单项的：别的四样都要求起止（`TaskShape.needsSchedule`）。
      expect(
        const TaskDraft(shape: TaskShape.scratch, title: '买菜').canSave,
        isTrue,
      );
    });

    test('对照组：单事项光有标题**不能**存 —— 起止是必填的', () {
      // 这一条是用户 2026-09-10 报的那个缺陷的最小复现：
      // 「时间四件你没有检查必填」。当时 `blockedReason` 已经说了
      // 「要先选结束日期」，而 `canSave` 是另一张清单，仍然返回 true ——
      // 红字在，保存键也亮着，按下去就真存进去了。
      const draft = TaskDraft(title: '买菜');
      expect(draft.blockedReason, isNotNull);
      expect(draft.canSave, isFalse);
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
        ..setStartMoment(
          DateAndMinute(const PlanDate(2026, 9, 7), MinuteOfDay.of(9, 30)),
        )
        ..setAllDay(true);

      final draft = c.read(taskEditorProvider);
      expect(draft.isAllDay, isTrue);
      expect(draft.startMinute, isNull);
      expect(draft.endMinute, isNull, reason: '两个时刻都要清');
      expect(n, isNotNull);
    });

    test('选一个时刻会自动关掉全天', () {
      final c = _container();
      c
          .read(taskEditorProvider.notifier)
          .setStartMoment(
            DateAndMinute(const PlanDate(2026, 9, 7), MinuteOfDay.of(9, 30)),
          );

      final draft = c.read(taskEditorProvider);
      expect(draft.isAllDay, isFalse);
      expect(draft.startMinute, MinuteOfDay.of(9, 30));
    });

    test('关掉全天会补一对**完整**的起止时刻', () {
      // ## 这一条 2026-09-10 反过来了
      //
      // 原来写的是「关掉全天**不**自动塞时刻 —— 由界面让他挑」。
      // 那在「起止可选」的年代成立；现在起止是必填的
      // （用户：「加强必填项校验」），不塞的结果是拨一下开关表单就
      // 变成不能存的，而保存键为什么灰要滚到最底下才看得见。
      //
      // 补的值都看得见（两栏当场显示出来），用户不同意可以当场改 ——
      // 这跟「替他做决定」的区别就在这儿。
      final c = _container();
      c.read(taskEditorProvider.notifier).setAllDay(false);

      final draft = c.read(taskEditorProvider);
      expect(draft.isAllDay, isFalse);
      expect(draft.startMinute, isNotNull);
      expect(draft.endDate, isNotNull);
      expect(draft.endMinute, isNotNull);
      expect(draft.blockedReason, isNull, reason: '补完就该是能存的');
    });

    test('补的是「下一个整点」，不是把用户拨过的时刻留在那儿', () {
      // 对照组，钉住上一条补的**是什么**。夹具时钟是东八区 09-07 11:00，
      // 下一个整点即 12:00；默认时长 24 小时 → 次日 12:00。
      //
      // 只断言 isNotNull 的话，一个「补 00:00」的实现也能通过，
      // 而那条任务在时间轴上会贴到最顶上。
      final c = _container();
      c.read(taskEditorProvider.notifier).setAllDay(false);

      final draft = c.read(taskEditorProvider);
      expect(draft.startMinute, MinuteOfDay.of(12, 0));
      expect(draft.endDate, const PlanDate(2026, 9, 8));
      expect(draft.endMinute, MinuteOfDay.of(12, 0));
    });

    test('全天任务存下去时不带时刻', () async {
      final c = _container();
      final n = c.read(taskEditorProvider.notifier)
        ..setTitle('读完这本书')
        ..setStartMoment(
          DateAndMinute(const PlanDate(2026, 9, 7), MinuteOfDay.of(9, 30)),
        )
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
    test('全天时，结束日期跟着开始走', () {
      // 全天只有一天，表单上也只给一个日期栏（用户 2026-09-10）。
      // 不跟着走的话，会留下一个界面上既显示不出、也改不到的结束日期。
      final c = _container();
      c
          .read(taskEditorProvider.notifier)
          .setPlanDate(const PlanDate(2026, 9, 20));

      final draft = c.read(taskEditorProvider);
      expect(draft.planDate, const PlanDate(2026, 9, 20));
      expect(draft.endDate, const PlanDate(2026, 9, 20));
    });

    test('对照组：非全天时改开始日期，结束**平移**而不是被拉到同一天', () {
      // 拉到同一天的话，一条跨三天的任务改一下开始就被压成一天，
      // 而用户只是想把它整体挪一挪。
      final c = _container();
      final n = c.read(taskEditorProvider.notifier)
        ..setStartMoment(
          DateAndMinute(const PlanDate(2026, 9, 7), MinuteOfDay.of(9, 0)),
        )
        ..setEndMoment(
          DateAndMinute(const PlanDate(2026, 9, 9), MinuteOfDay.of(18, 0)),
        )
        ..setStartMoment(
          DateAndMinute(const PlanDate(2026, 9, 10), MinuteOfDay.of(9, 0)),
        );

      final draft = c.read(taskEditorProvider);
      expect(draft.endDate, const PlanDate(2026, 9, 12));
      expect(draft.endMinute, MinuteOfDay.of(18, 0));
      expect(n, isNotNull);
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

    test('打开全天时，没有日期也补上今天', () {
      // 2026-09-10 反过来了：全天不再是「哪天做都行」——
      // 那一档现在叫临时事项，而它压根不显示这几个控件。
      // 全天任务必须落在某一天，否则日历上没有它的位置。
      final c = _container();
      c.read(taskEditorProvider.notifier).setAllDay(true);

      final draft = c.read(taskEditorProvider);
      expect(draft.planDate, const PlanDate(2026, 9, 7));
      expect(draft.endDate, const PlanDate(2026, 9, 7));
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
        ..setStartMoment(
          DateAndMinute(const PlanDate(2026, 9, 7), MinuteOfDay.of(12, 32)),
        );
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

    /// 建一个**三阶段**的阶段事项草稿，三个阶段各差一天（0 / 1440 / 2880）。
    (ProviderContainer, List<String>) withThreeTimedStages() {
      final c = ProviderContainer(
        overrides: [
          ...appHarness().overrides,
          newTaskSeedProvider.overrideWithValue((
            date: null,
            minute: null,
            shape: TaskShape.staged,
          )),
        ],
      );
      addTearDown(c.dispose);
      final n = c.read(taskEditorProvider.notifier)..setTitle('搬家');
      for (var i = 0; i < 3; i++) {
        n.addStage();
      }
      final ids = [for (final s in c.read(taskEditorProvider).stages) s.id];
      for (final (i, id) in ids.indexed) {
        n
          ..setStageTitle(id, '第 ${i + 1} 步')
          ..setStageTime(
            id,
            startOffsetMinutes: i * minutesPerDay,
            durationMinutes: 60,
          );
      }
      return (c, ids);
    }

    test('**删掉最早那个阶段之后，起止要重推**（评审 R-3）', () {
      // ## 重推挂在「某一个 setter」上，而它该挂在「阶段集合变了」上
      //
      // `_rederiveSpanIfStaged` 只有 `setStageTime` 调。删掉最早那个阶段
      // 之后，任务的开始**停在被删掉的那个阶段的时刻**上，而
      // `derived_span.dart` 头注写的那条不变量（最早那个阶段的偏移恒为 0、
      // 任务开始就是它）在草稿里当场不成立。
      //
      // **而它存得下去**：三个删成两个不会被 `blockedReason` 挡
      // （挡的是「少于两个」），于是那条起止会被写进库。
      //
      // 别的几个改阶段的入口今天没事，但**理由各不相同**：加阶段靠
      // 「新行没时间会被挡住」、重排靠「不动时间」、改标题勾完成靠
      // 「不碰时间」—— 四条各不相同的论证，正是「机制锚在判据的一种
      // 写法上」的形状。
      final (c, ids) = withThreeTimedStages();
      final before = c.read(taskEditorProvider);
      expect(before.stages.map((s) => s.startOffsetMinutes), [
        0,
        minutesPerDay,
        2 * minutesPerDay,
      ], reason: '前提：三个阶段各差一天');

      c.read(taskEditorProvider.notifier).removeStage(ids.first);
      final after = c.read(taskEditorProvider);

      expect(after.stages.map((s) => s.startOffsetMinutes), [
        0,
        minutesPerDay,
      ], reason: '最早那个阶段的偏移不是 0 了 —— 起止没跟着重推');
      expect(
        after.planDate,
        before.planDate!.addDays(1),
        reason: '任务的开始停在被删掉的那个阶段上',
      );
      expect(after.canSave, isTrue, reason: '删到两个是合法的，它会被存进库');
    });

    test('对照组：删掉**最晚**那个，结束跟着往前收', () {
      // 少了它，一个「删阶段时把起止整个清掉」的实现也能让上面绿。
      final (c, ids) = withThreeTimedStages();
      final before = c.read(taskEditorProvider);

      c.read(taskEditorProvider.notifier).removeStage(ids.last);
      final after = c.read(taskEditorProvider);

      expect(after.planDate, before.planDate, reason: '开始不该动 —— 最早那个还在');
      expect(
        after.endDate,
        before.endDate!.addDays(-1),
        reason: '结束没跟着最晚那个阶段收回来',
      );
      expect(after.stages.map((s) => s.startOffsetMinutes), [0, minutesPerDay]);
    });

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

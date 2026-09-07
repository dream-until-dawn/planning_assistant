/// **overview §6 里 V2 那一格的验收项**：
/// 「写一个纯 Dart 测试，不启动 Flutter binding 就能取到今日概览」。
///
/// ## 这个文件为什么用 `package:test` 而不是 `flutter_test`
///
/// V2 的桌面小组件跑在后台 isolate、甚至另一个进程里，那里**没有 Flutter
/// binding**。等到 V2 才发现查询长在 Provider 与 BuildContext 上，就拆不动了。
///
/// 只靠「读一遍 import 列表确认没有 flutter」是不够的 —— 传递依赖看不见。
/// 真正的证明是：**用 `dart test`（不是 `flutter test`）跑通这个文件**。
/// 整条链路上任何一处引入 `dart:ui`，那一步会直接编译失败。
/// CI 里有独立的一步这么跑（见 `.github/workflows/ci.yml`）。
///
/// 所以本文件**不得** import `package:flutter_test/*` 或任何 `package:flutter/*`，
/// 由 `test/architecture/layer_dependency_test.dart` 的守卫盯着。
@TestOn('vm')
library;

import 'package:drift/native.dart';
import 'package:planning_assistant/core/time/clock.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/core/time/time_zone_resolver.dart';
import 'package:planning_assistant/data/database/app_database.dart';
import 'package:planning_assistant/data/database/dao/synced_dao.dart';
import 'package:planning_assistant/data/queries/today_digest_service.dart';
import 'package:planning_assistant/data/repositories/task_repository_impl.dart';
import 'package:planning_assistant/domain/commands/command_dispatcher.dart';
import 'package:planning_assistant/domain/commands/task_command.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/queries/today_digest.dart';
import 'package:planning_assistant/domain/recurrence/recurrence_engine.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tzdata;

const _writer = FixedWriterIdentity('device-A');
final _now = DateTime.utc(2026, 3, 10, 12);
final _clock = FixedClock(_now);

const _today = PlanDate(2026, 3, 10);

void main() {
  setUpAll(tzdata.initializeTimeZones);

  late AppDatabase db;
  late CommandDispatcher dispatcher;
  late TodayDigestService digest;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final repo = DriftTaskRepository(db, _writer, _clock);
    dispatcher = CommandDispatcher(repo, _clock);
    digest = TodayDigestService(
      repo,
      const RecurrenceEngine(TzTimeZoneResolver()),
    );
  });
  tearDown(() => db.close());

  group('V2 验收：不启动 Flutter binding 也能取到今日概览', () {
    test('空库时概览为空，文案是「今天没有安排」', () async {
      final d = await digest.forDate(_today);
      expect(d.isEmpty, isTrue);
      expect(d.date, '2026-03-10');
      expect(buildDigestText(d), '今天没有安排');
    });

    test('取到当天的不重复任务', () async {
      await dispatcher.dispatchAll([
        CreateTaskCommand(
          taskId: 't-today',
          title: '今天的事',
          kind: TaskKind.single,
          timeZoneId: 'Asia/Shanghai',
          planDate: _today,
          startMinute: MinuteOfDay.of(9, 0),
        ),
        const CreateTaskCommand(
          taskId: 't-tomorrow',
          title: '明天的事',
          kind: TaskKind.single,
          timeZoneId: 'Asia/Shanghai',
          planDate: PlanDate(2026, 3, 11),
        ),
      ]);

      final d = await digest.forDate(_today);
      expect(d.items.map((i) => i.taskId), ['t-today']);
      expect(d.totalCount, 1);
    });

    test('重复任务在当天有发生时也算进来', () async {
      // 漏掉这一类的话，「每天 09:00 跑步」永远不出现在概览里 ——
      // 而它恰恰是最需要被提醒的那种。
      await dispatcher.dispatch(
        CreateTaskCommand(
          taskId: 't-daily',
          title: '每天跑步',
          kind: TaskKind.single,
          timeZoneId: 'Asia/Shanghai',
          planDate: const PlanDate(2026, 3, 1),
          startMinute: MinuteOfDay.of(7, 0),
          recurrenceRule: 'RRULE:FREQ=DAILY',
        ),
      );

      final d = await digest.forDate(_today);
      expect(d.items.map((i) => i.taskId), ['t-daily']);
      expect(d.items.single.startMinute, 420);
    });

    test('重复任务在当天没有发生时不算', () async {
      // 每周一重复；2026-03-10 是周二。
      await dispatcher.dispatch(
        CreateTaskCommand(
          taskId: 't-monday',
          title: '每周一例会',
          kind: TaskKind.single,
          timeZoneId: 'Asia/Shanghai',
          planDate: const PlanDate(2026, 3, 2),
          startMinute: MinuteOfDay.of(10, 0),
          recurrenceRule: 'RRULE:FREQ=WEEKLY;BYDAY=MO',
        ),
      );
      expect(_today.weekday, 2, reason: '前提：2026-03-10 是周二');

      final d = await digest.forDate(_today);
      expect(d.isEmpty, isTrue);
    });

    test('归档与回收站里的任务不出现在概览里', () async {
      await dispatcher.dispatchAll([
        const CreateTaskCommand(
          taskId: 't-archived',
          title: '归档的',
          kind: TaskKind.single,
          timeZoneId: 'Etc/UTC',
          planDate: _today,
        ),
        const CreateTaskCommand(
          taskId: 't-deleted',
          title: '删除的',
          kind: TaskKind.single,
          timeZoneId: 'Etc/UTC',
          planDate: _today,
        ),
        const CreateTaskCommand(
          taskId: 't-active',
          title: '活跃的',
          kind: TaskKind.single,
          timeZoneId: 'Etc/UTC',
          planDate: _today,
        ),
        const ArchiveTaskCommand('t-archived'),
        const DeleteTaskCommand('t-deleted'),
      ]);

      final d = await digest.forDate(_today);
      expect(d.items.map((i) => i.taskId), ['t-active']);
    });

    test('阶段进度被算出来（概览要显示 2/5）', () async {
      await dispatcher.dispatchAll([
        const CreateTaskCommand(
          taskId: 't-staged',
          title: '阶段任务',
          kind: TaskKind.staged,
          timeZoneId: 'Etc/UTC',
          planDate: _today,
        ),
        const ReplaceStagesCommand(
          taskId: 't-staged',
          stages: [
            StageSpec(
              id: 's0',
              title: 'a',
              orderIndex: 0,
              status: TaskStatus.done,
            ),
            StageSpec(
              id: 's1',
              title: 'b',
              orderIndex: 1,
              status: TaskStatus.done,
            ),
            StageSpec(id: 's2', title: 'c', orderIndex: 2),
            StageSpec(id: 's3', title: 'd', orderIndex: 3),
            StageSpec(id: 's4', title: 'e', orderIndex: 4),
          ],
        ),
      ]);

      final d = await digest.forDate(_today);
      expect(d.items.single.stageProgress, (2, 5));
    });
  });

  group('概览的排序必须确定', () {
    test('全天在前，其余按时刻升序，同刻按标题', () async {
      // 不确定的顺序会让小组件每次刷新条目乱跳，用户会以为数据变了。
      await dispatcher.dispatchAll([
        CreateTaskCommand(
          taskId: 'c',
          title: '乙',
          kind: TaskKind.single,
          timeZoneId: 'Etc/UTC',
          planDate: _today,
          startMinute: MinuteOfDay.of(9, 0),
        ),
        CreateTaskCommand(
          taskId: 'b',
          title: '甲',
          kind: TaskKind.single,
          timeZoneId: 'Etc/UTC',
          planDate: _today,
          startMinute: MinuteOfDay.of(9, 0),
        ),
        CreateTaskCommand(
          taskId: 'a',
          title: '早的',
          kind: TaskKind.single,
          timeZoneId: 'Etc/UTC',
          planDate: _today,
          startMinute: MinuteOfDay.of(8, 0),
        ),
        const CreateTaskCommand(
          taskId: 'z',
          title: '全天的',
          kind: TaskKind.single,
          timeZoneId: 'Etc/UTC',
          planDate: _today,
          isAllDay: true,
        ),
      ]);

      final d = await digest.forDate(_today);
      // 同刻按标题：'乙' U+4E59 < '甲' U+7532，所以 c 在 b 前。
      // 第一版这里写的是 ['z','a','b','c'] —— 想当然按「甲乙丙」的顺序，
      // 而 String.compareTo 比的是**码点**，不是语言习惯的排序。
      expect(d.items.map((i) => i.taskId), ['z', 'a', 'c', 'b']);
    });

    test('中文标题按码点序，不是拼音序 —— 这是已知取舍', () {
      // 记下来免得被当成 bug：V1 只要求顺序**确定**（不确定的话小组件
      // 每次刷新条目乱跳）。按拼音/笔画排序是 M2 的 UI 关注点，
      // 需要 locale-aware collation，不该由这个跨进程的纯函数背。
      expect('乙'.compareTo('甲') < 0, isTrue, reason: '码点序：乙 U+4E59 < 甲 U+7532');
      expect('甲'.compareTo('乙') > 0, isTrue);
    });
  });

  group('buildDigestText 是纯函数，可脱离数据库单测', () {
    DigestItem item(
      String title, {
      int? minute,
      TaskStatus status = TaskStatus.pending,
    }) => DigestItem(
      taskId: title,
      title: title,
      status: status,
      startMinute: minute,
    );

    TodayDigest make(List<DigestItem> items) => TodayDigest(
      date: '2026-03-10',
      items: items,
      totalCount: items.length,
      doneCount: items.where((i) => i.isDone).length,
    );

    test('空 → 今天没有安排', () {
      expect(buildDigestText(make([])), '今天没有安排');
    });

    test('全部完成 → 报完成数，而不是「还剩 0 项」', () {
      final d = make([
        item('a', minute: 540, status: TaskStatus.done),
        item('b', minute: 600, status: TaskStatus.done),
      ]);
      expect(buildDigestText(d), '今天的 2 项都完成了');
    });

    test('部分完成 → 报剩余与下一项', () {
      final d = make([
        item('晨会', minute: 540, status: TaskStatus.done),
        item('写文档', minute: 630),
        item('复盘', minute: 1080),
      ]);
      expect(buildDigestText(d), '还剩 2/3 项 · 下一项 10:30 写文档');
    });

    test('下一项是全天任务时显示「全天」', () {
      final d = make([item('读书')]);
      expect(buildDigestText(d), '还剩 1/1 项 · 下一项 全天 读书');
    });

    test('时刻补零到 HH:mm', () {
      expect(buildDigestText(make([item('早起', minute: 5)])), contains('00:05'));
      expect(
        buildDigestText(make([item('午饭', minute: 720)])),
        contains('12:00'),
      );
      expect(
        buildDigestText(make([item('临睡', minute: 1439)])),
        contains('23:59'),
      );
    });

    test('已完成的项不会被当成「下一项」', () {
      // 排序后第一条是已完成的，得跳过它。
      final d = make([
        item('已完成的', minute: 480, status: TaskStatus.done),
        item('待办的', minute: 540),
      ]);
      expect(buildDigestText(d), contains('待办的'));
      expect(buildDigestText(d), isNot(contains('已完成的')));
    });
  });
}

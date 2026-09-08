/// 任务状态机与生命周期 —— task-lifecycle §7 的必测用例 L-01..L-14 全表。
///
/// 期望值全部来自文档的迁移表与推导表，**不是「跑一遍看输出」**。
/// 每条注明对应的用例编号，评审时可逐条对照。
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/domain/entities/stage.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/policies/task_lifecycle.dart';
import 'package:planning_assistant/domain/value_objects/recurrence.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';

final _now = DateTime.utc(2026, 3, 8, 12);
final _later = DateTime.utc(2026, 3, 8, 15);

Task task({
  TaskStatus status = TaskStatus.pending,
  TaskStatus? statusBeforeArchive,
  DateTime? archivedAt,
  DateTime? deletedAt,
  DateTime? completedAt,
  String? rrule,
  TaskKind kind = TaskKind.single,
}) => Task(
  id: 't1',
  title: '任务',
  kind: kind,
  timeZoneId: 'Asia/Shanghai',
  status: status,
  statusBeforeArchive: statusBeforeArchive,
  archivedAt: archivedAt,
  deletedAt: deletedAt,
  completedAt: completedAt ?? (status == TaskStatus.done ? _now : null),
  recurrence: rrule == null ? null : Recurrence.parse(rrule),
);

Stage stage(int i, TaskStatus status) => Stage(
  id: 's$i',
  taskId: 't1',
  title: '阶段 $i',
  orderIndex: i,
  status: status,
  completedAt: status == TaskStatus.done ? _now : null,
);

void main() {
  group('L-01 非法迁移逐对抛异常且状态不变', () {
    // 文档 §2.1 的表格里三个 ❌ 格子。
    const illegal = <(TaskStatus, TaskStatus)>[
      (TaskStatus.done, TaskStatus.skipped),
      (TaskStatus.skipped, TaskStatus.inProgress),
      (TaskStatus.skipped, TaskStatus.done),
    ];

    for (final (from, to) in illegal) {
      test('${from.name} → ${to.name} 抛 IllegalTransitionException', () {
        final t = task(status: from);
        expect(
          () => applyStatusChange(t, to, now: _later),
          throwsA(isA<IllegalTransitionException>()),
        );
        // 实体不可变，原对象必须没被动过。
        expect(t.status, from);
      });
    }

    test('迁移表与文档 §2.1 的表格逐格一致', () {
      // 逐格枚举，而不是抽查几对 —— 表格有 16 格，抽查过不了的那几格
      // 恰恰是最容易写错的。
      const expected = <TaskStatus, Set<TaskStatus>>{
        TaskStatus.pending: {
          TaskStatus.inProgress,
          TaskStatus.done,
          TaskStatus.skipped,
        },
        TaskStatus.inProgress: {
          TaskStatus.pending,
          TaskStatus.done,
          TaskStatus.skipped,
        },
        TaskStatus.done: {TaskStatus.pending, TaskStatus.inProgress},
        TaskStatus.skipped: {TaskStatus.pending},
      };
      for (final from in TaskStatus.values) {
        for (final to in TaskStatus.values) {
          final allowed = from == to || expected[from]!.contains(to);
          expect(
            isTransitionAllowed(from, to),
            allowed,
            reason: '${from.name} → ${to.name}',
          );
        }
      }
    });

    test('合法迁移确实通过（否则上面那条可能因「全禁止」而假绿）', () {
      // 一张「全 false」的表也能让 L-01 的三条通过。必须反向也断。
      expect(
        applyStatusChange(task(), TaskStatus.inProgress, now: _later).status,
        TaskStatus.inProgress,
      );
      expect(
        applyStatusChange(
          task(status: TaskStatus.done),
          TaskStatus.pending,
          now: _later,
        ).status,
        TaskStatus.pending,
      );
    });
  });

  group('L-02 归档还原到归档前的状态', () {
    test('归档 inProgress 再取消 → 回到 inProgress，不是 pending', () {
      final t = task(status: TaskStatus.inProgress);
      final archived = archive(t, now: _now);

      expect(archived.isArchived, isTrue);
      expect(archived.statusBeforeArchive, TaskStatus.inProgress);
      expect(archived.status, TaskStatus.inProgress, reason: '归档不改 status 本身');

      final restored = unarchive(archived);
      expect(restored.status, TaskStatus.inProgress);
      expect(restored.archivedAt, isNull);
      expect(
        restored.statusBeforeArchive,
        isNull,
        reason: '快照必须清掉，否则下次归档还原会用到陈旧值',
      );
    });

    test('四种状态各走一遍归档往返', () {
      // 只测 inProgress 的话，一个「一律还原成 inProgress」的实现也能过。
      for (final s in TaskStatus.values) {
        final t = task(status: s);
        expect(unarchive(archive(t, now: _now)).status, s, reason: s.name);
      }
    });
  });

  group('L-03 / L-03b 重复任务的 status 恒为 pending', () {
    test('L-03 尝试把重复任务标为 done → 抛 DomainInvariantViolation', () {
      final t = task(rrule: 'RRULE:FREQ=DAILY');
      expect(
        () => applyStatusChange(t, TaskStatus.done, now: _later),
        throwsA(isA<DomainInvariantViolation>()),
      );
    });

    test('L-03 变异演练补漏：连「设成 pending」这种空操作也必须拒绝', () async {
      // 变异演练发现的漏洞：把 applyStatusChange 里的 isRecurring 守卫整段删掉，
      // 上面那条 L-03 **照样通过** —— 因为末尾的 checkInvariants() 也会拦下
      // 「重复任务 + done」。两处重复，测试分不出来。
      //
      // 但两者并不等价：设成 pending 时状态没变，checkInvariants() 放行，
      // 只有前置守卫会拦。而调用方走到这里本身就说明它拿错了模型 ——
      // 该写 occurrence_overrides 却在改 tasks.status。
      // 让它静默成功，等于把一个编程错误藏到下一层。
      final t = task(rrule: 'RRULE:FREQ=DAILY');
      expect(t.status, TaskStatus.pending, reason: '前提：本就是 pending');
      expect(
        () => applyStatusChange(t, TaskStatus.pending, now: _later),
        throwsA(isA<DomainInvariantViolation>()),
        reason: '空操作也要拒绝，否则前置守卫等于没有',
      );
    });

    test('L-03b release 语义下同样抛出 —— 不依赖 assert', () {
      // Dart 的 assert 在 AOT release 构建里被整条移除。用 assert 表达的
      // 不变量会在 debug 下变绿、正式包里零保护。
      //
      // 这条走的是纯函数 checkInvariants()，其中只有 if + throw，
      // 编译模式不影响其行为。
      final bad = Task(
        id: 't1',
        title: '重复任务',
        kind: TaskKind.single,
        timeZoneId: 'Asia/Shanghai',
        status: TaskStatus.done,
        completedAt: _now,
        recurrence: Recurrence.parse('RRULE:FREQ=DAILY'),
      );
      expect(bad.checkInvariants, throwsA(isA<DomainInvariantViolation>()));
    });

    test('checkInvariants 里没有一处用 assert 表达不变量', () {
      // 结构守卫：源码里出现 assert 就说明有人写回去了。
      // 放在测试里而不是靠 review —— review 会漏，测试不会。
      final source = _readSource('lib/domain/entities/task.dart');
      final assertLines = source
          .split('\n')
          .where((l) => RegExp(r'^\s*assert\s*\(').hasMatch(l))
          .toList();
      expect(
        assertLines,
        isEmpty,
        reason: '不变量必须用显式 throw（task-lifecycle §3.1）：\n$assertLines',
      );
    });
  });

  group('L-04 / L-10 / L-11 阶段推导父任务状态', () {
    test('L-04 阶段全部完成 → done', () {
      expect(
        deriveStatusFromStages([
          stage(0, TaskStatus.done),
          stage(1, TaskStatus.done),
        ]),
        TaskStatus.done,
      );
    });

    test('全部 pending → pending', () {
      expect(
        deriveStatusFromStages([
          stage(0, TaskStatus.pending),
          stage(1, TaskStatus.pending),
        ]),
        TaskStatus.pending,
      );
    });

    test('全部 skipped → skipped（不是 done）', () {
      // 「全部 done 或 skipped」这一行的边界：一个 done 都没有时是 skipped。
      // 实现里若把两行的判断顺序调换，这条会红。
      expect(
        deriveStatusFromStages([
          stage(0, TaskStatus.skipped),
          stage(1, TaskStatus.skipped),
        ]),
        TaskStatus.skipped,
      );
    });

    test('done + skipped 混合（至少一个 done）→ done', () {
      expect(
        deriveStatusFromStages([
          stage(0, TaskStatus.done),
          stage(1, TaskStatus.skipped),
        ]),
        TaskStatus.done,
      );
    });

    test('L-10 autoStartOnFirstStage=true，5 个完成 2 个 → inProgress', () {
      final stages = [
        stage(0, TaskStatus.done),
        stage(1, TaskStatus.done),
        stage(2, TaskStatus.pending),
        stage(3, TaskStatus.pending),
        stage(4, TaskStatus.pending),
      ];
      expect(
        deriveStatusFromStages(stages, config: (autoStartOnFirstStage: true)),
        TaskStatus.inProgress,
      );
    });

    test('L-11 autoStartOnFirstStage=false，同上 → 保持 pending', () {
      final stages = [
        stage(0, TaskStatus.done),
        stage(1, TaskStatus.done),
        stage(2, TaskStatus.pending),
        stage(3, TaskStatus.pending),
        stage(4, TaskStatus.pending),
      ];
      expect(
        deriveStatusFromStages(stages, config: (autoStartOnFirstStage: false)),
        TaskStatus.pending,
      );
      // 进度信息不受配置影响 —— 关掉开关只是父任务不自动变色，不丢信息。
      expect(stages.where((s) => s.status == TaskStatus.done).length, 2);
      expect(stages.length, 5);
    });

    test('L-11 附带：该配置只影响这一行，其余三行不受影响', () {
      const off = (autoStartOnFirstStage: false);
      expect(
        deriveStatusFromStages([stage(0, TaskStatus.done)], config: off),
        TaskStatus.done,
      );
      expect(
        deriveStatusFromStages([stage(0, TaskStatus.skipped)], config: off),
        TaskStatus.skipped,
      );
      expect(
        deriveStatusFromStages([stage(0, TaskStatus.pending)], config: off),
        TaskStatus.pending,
      );
    });

    test('无阶段时返回 null，由调用方决定保留原状态', () {
      expect(deriveStatusFromStages([]), isNull);
    });
  });

  group('L-05 / L-06 父任务与阶段的不对称', () {
    test('L-05 父任务标完成 → 所有阶段变 done', () {
      final r = completeTaskWithStages(task(kind: TaskKind.staged), [
        stage(0, TaskStatus.pending),
        stage(1, TaskStatus.inProgress),
        stage(2, TaskStatus.done),
      ], now: _later);
      expect(r.task.status, TaskStatus.done);
      expect(r.stages.every((s) => s.status == TaskStatus.done), isTrue);
      // 已完成的那个不该被改动完成时刻。
      expect(r.stages[2].completedAt, _now);
      expect(r.stages[0].completedAt, _later);
    });

    test('L-06 父任务取消完成 → 阶段状态**保持不变**', () {
      // 这条不对称是刻意的（§4.2）：破坏用户已记录的阶段进度，
      // 比留下「父任务未完成但阶段全完成」更糟。
      // 将来有人「顺手统一一下」改成回滚阶段，这条会变红。
      final stages = [stage(0, TaskStatus.done), stage(1, TaskStatus.done)];
      final r = uncompleteTaskKeepingStages(
        task(status: TaskStatus.done, kind: TaskKind.staged),
        stages,
        now: _later,
      );
      expect(r.task.status, TaskStatus.pending);
      expect(r.task.completedAt, isNull, reason: '取消完成必须清 completedAt');
      expect(
        r.stages.every((s) => s.status == TaskStatus.done),
        isTrue,
        reason: '阶段状态不该被回滚',
      );
      expect(r.stages, same(stages), reason: '连列表都不该重建');
    });
  });

  group('L-07 / L-08 删除与恢复的级联', () {
    test('L-07 删除父任务 → 子实体全部打墓碑，无一物理删除', () {
      final stages = [stage(0, TaskStatus.pending), stage(1, TaskStatus.done)];
      final r = softDeleteTaskCascade(task(), stages, now: _now);

      expect(r.task.deletedAt, _now);
      expect(r.stages.length, 2, reason: '不能物理删 —— 恢复时子数据会丢');
      expect(r.stages.every((s) => s.deletedAt == _now), isTrue);
      // 状态本身不该被删除动作改掉。
      expect(r.stages[1].status, TaskStatus.done);
    });

    test('L-08 恢复已删任务 → 子实体一并恢复', () {
      final deleted = softDeleteTaskCascade(task(), [
        stage(0, TaskStatus.pending),
      ], now: _now);
      final r = restoreTaskCascade(deleted.task, deleted.stages);

      expect(r.task.deletedAt, isNull);
      expect(r.stages.every((s) => s.deletedAt == null), isTrue);
    });

    test('L-08 边界：删父任务前就单独删掉的阶段，不跟着复活', () {
      // 那是用户的另一次决定，恢复父任务不该撤销它。
      final earlier = DateTime.utc(2026, 3, 1);
      final stages = [
        stage(0, TaskStatus.pending).copyWith(deletedAt: earlier),
        stage(1, TaskStatus.pending),
      ];
      final deleted = softDeleteTaskCascade(task(), stages, now: _now);
      final r = restoreTaskCascade(deleted.task, deleted.stages);

      expect(r.stages[0].deletedAt, earlier, reason: '早先单独删的应保持已删');
      expect(r.stages[1].deletedAt, isNull);
    });
  });

  group('L-09 回收站保留期', () {
    final deletedAt = DateTime.utc(2026, 1, 1);
    final t = task(deletedAt: deletedAt);

    test('未到期不清理', () {
      expect(
        isPurgeable(
          t,
          now: deletedAt.add(const Duration(days: 29)),
          retentionDays: 30,
        ),
        isFalse,
      );
    });

    test('边界日**不清**（恰好第 30 天仍保留）', () {
      // 用 >= 的话，用户在最后一天打开回收站会发现东西已经没了。
      expect(
        isPurgeable(
          t,
          now: deletedAt.add(const Duration(days: 30)),
          retentionDays: 30,
        ),
        isFalse,
      );
    });

    test('超过一分钟即可清理', () {
      expect(
        isPurgeable(
          t,
          now: deletedAt.add(const Duration(days: 30, minutes: 1)),
          retentionDays: 30,
        ),
        isTrue,
      );
    });

    test('未删除的任务永不可清理', () {
      expect(
        isPurgeable(task(), now: DateTime.utc(2030), retentionDays: 30),
        isFalse,
      );
    });

    group('剩余时间', () {
      // 界面要写「还剩几天」，而它必须与上面那条判据同源。
      // 这一组钉的就是「同源」——两处各算各的时，下面第二条会露馅。
      test('刚删掉时剩满一个保留期', () {
        expect(
          timeUntilPurge(t, now: deletedAt, retentionDays: 30),
          const Duration(days: 30),
        );
      });

      test('**差几个小时到期时，剩余不足一天**', () {
        // 29 天 20 小时：`30 - 差值.inDays` 会算成「还剩 1 天」，
        // 而再过 4 小时它就真的被清了。界面据此显示「还剩 1 天」
        // 是在承诺一件明早就不成立的事。
        final left = timeUntilPurge(
          t,
          now: deletedAt.add(const Duration(days: 29, hours: 20)),
          retentionDays: 30,
        )!;
        expect(left.inDays, 0);
        expect(left.isNegative, isFalse, reason: '还没到期，不该是负的');
      });

      test('过期后为负 —— 「早就该清了」是个真实状态', () {
        // 清理发生在下次启动，所以「已过期但还在」必然存在。
        // 压成 0 的话，界面分不出「今天最后一天」和「早该没了」。
        expect(
          timeUntilPurge(
            t,
            now: deletedAt.add(const Duration(days: 40)),
            retentionDays: 30,
          ),
          const Duration(days: -10),
        );
      });

      test('恰好到期是 0，而 0 不算过期', () {
        final at = deletedAt.add(const Duration(days: 30));
        expect(timeUntilPurge(t, now: at, retentionDays: 30), Duration.zero);
        expect(isPurgeable(t, now: at, retentionDays: 30), isFalse);
      });

      test('未删除的没有剩余时间可言', () {
        expect(
          timeUntilPurge(task(), now: DateTime.utc(2030), retentionDays: 30),
          isNull,
        );
      });
    });
  });

  group('L-12 / L-13 归档维度', () {
    test('L-12 归档一个重复任务 → 成功，且不变量不被破坏', () {
      // 这正是把归档移出 TaskStatus 枚举的收益：与非重复任务同一条路径。
      final t = task(rrule: 'RRULE:FREQ=WEEKLY;BYDAY=MO');
      final archived = archive(t, now: _now);

      expect(archived.archivedAt, _now);
      expect(
        archived.status,
        TaskStatus.pending,
        reason: '重复任务 status 恒为 pending',
      );
      expect(archived.checkInvariants, returnsNormally);
    });

    test('L-13 归档态下改 status → 抛异常', () {
      // 否则 statusBeforeArchive 会与现实脱节。
      final archived = archive(task(status: TaskStatus.inProgress), now: _now);
      expect(
        () => applyStatusChange(archived, TaskStatus.done, now: _later),
        throwsA(isA<IllegalTransitionException>()),
      );
    });

    test('未归档态下 statusBeforeArchive 必须为空', () {
      final bad = task(
        status: TaskStatus.pending,
        statusBeforeArchive: TaskStatus.done,
      );
      expect(bad.checkInvariants, throwsA(isA<DomainInvariantViolation>()));
    });
  });

  group('L-14 三个可见性谓词互斥且完备', () {
    test('对全部 8 种 (deleted, archived, status) 组合恰好命中一个', () {
      // 「互斥且完备」这句话必须逐组合验证 —— 手写过滤条件的分叉
      // 正是从「某一类任务落进了两个桶」开始的。
      final samples = <Task>[
        for (final deleted in [null, _now])
          for (final archived in [null, _now])
            for (final s in [TaskStatus.pending, TaskStatus.done])
              task(
                status: s,
                deletedAt: deleted,
                archivedAt: archived,
                statusBeforeArchive: archived == null ? null : s,
              ),
      ];

      expect(samples.length, 8);
      for (final t in samples) {
        expect(
          TaskVisibility.matchedBucketCount(t),
          1,
          reason: '$t 落在了 ${TaskVisibility.matchedBucketCount(t)} 个桶里',
        );
      }
    });

    test('已删除且已归档的任务归入回收站，不出现在归档列表', () {
      // 这是最容易写错的一格：归档列表若只判 archivedAt，
      // 已删的归档任务会同时出现在两处。
      final t = task(
        archivedAt: _now,
        deletedAt: _now,
        statusBeforeArchive: TaskStatus.pending,
      );
      expect(TaskVisibility.isInTrash(t), isTrue);
      expect(TaskVisibility.isArchived(t), isFalse);
      expect(TaskVisibility.isActive(t), isFalse);
    });
  });

  group('completedAt 与 status 同进同退（§5）', () {
    test('标完成时记录点击瞬时，不是计划时间', () {
      final t = applyStatusChange(task(), TaskStatus.done, now: _later);
      expect(t.completedAt, _later);
    });

    test('取消完成时置空', () {
      final done = applyStatusChange(task(), TaskStatus.done, now: _later);
      final undone = applyStatusChange(done, TaskStatus.pending, now: _later);
      expect(undone.completedAt, isNull);
    });

    test('done 但无 completedAt 的实体过不了不变量', () {
      final bad = task(
        status: TaskStatus.done,
        completedAt: null,
      ).copyWith(completedAt: null);
      expect(bad.checkInvariants, throwsA(isA<DomainInvariantViolation>()));
    });
  });

  group('开始与结束的不变量（结束侧与开始侧对称）', () {
    // 这五条是补上的。一开始只写了开始侧的 `isAllDay && startMinute`，
    // 而那时编辑器还写不出结束时间 —— 于是「没有测试会红」与
    // 「不会出问题」看起来是一回事。写得出来的那天，坏数据就落库了。
    Task withTimes({
      bool isAllDay = false,
      PlanDate? planDate,
      MinuteOfDay? startMinute,
      PlanDate? endDate,
      MinuteOfDay? endMinute,
    }) => Task(
      id: 't1',
      title: '任务',
      kind: TaskKind.single,
      timeZoneId: 'Asia/Shanghai',
      isAllDay: isAllDay,
      planDate: planDate,
      startMinute: startMinute,
      endDate: endDate,
      endMinute: endMinute,
    );

    final bad = <String, Task>{
      '全天却带结束时刻': withTimes(
        isAllDay: true,
        planDate: const PlanDate(2026, 9, 8),
        endDate: const PlanDate(2026, 9, 8),
        endMinute: MinuteOfDay.of(18, 0),
      ),
      '有结束时刻却没有结束日期': withTimes(
        planDate: const PlanDate(2026, 9, 8),
        endMinute: MinuteOfDay.of(18, 0),
      ),
      '有结束日期却没有开始日期': withTimes(endDate: const PlanDate(2026, 9, 8)),
      '结束日期早于开始日期': withTimes(
        planDate: const PlanDate(2026, 9, 8),
        endDate: const PlanDate(2026, 9, 7),
      ),
      '同一天里结束时刻早于开始时刻': withTimes(
        planDate: const PlanDate(2026, 9, 8),
        startMinute: MinuteOfDay.of(14, 0),
        endDate: const PlanDate(2026, 9, 8),
        endMinute: MinuteOfDay.of(9, 0),
      ),
    };

    bad.forEach((name, t) {
      test('$name → 抛 DomainInvariantViolation', () {
        expect(t.checkInvariants, throwsA(isA<DomainInvariantViolation>()));
      });
    });

    // ── 对照组：这些是**合法**的，不许被上面的规则误伤 ──────────
    final good = <String, Task>{
      '只有开始，没有结束': withTimes(planDate: const PlanDate(2026, 9, 8)),
      '同一天开始结束，结束时刻在后': withTimes(
        planDate: const PlanDate(2026, 9, 8),
        startMinute: MinuteOfDay.of(9, 0),
        endDate: const PlanDate(2026, 9, 8),
        endMinute: MinuteOfDay.of(10, 30),
      ),
      // 「九点开始，当天结束」—— 缺失的结束时刻按当天最后一分钟算。
      // 按 00:00 理解的话这条会被误判成违规，而它完全正常。
      '同一天开始结束，不写结束时刻': withTimes(
        planDate: const PlanDate(2026, 9, 8),
        startMinute: MinuteOfDay.of(9, 0),
        endDate: const PlanDate(2026, 9, 8),
      ),
      '跨天：结束时刻比开始时刻早也没关系': withTimes(
        planDate: const PlanDate(2026, 9, 8),
        startMinute: MinuteOfDay.of(22, 0),
        endDate: const PlanDate(2026, 9, 9),
        endMinute: MinuteOfDay.of(2, 0),
      ),
      '全天跨天': withTimes(
        isAllDay: true,
        planDate: const PlanDate(2026, 9, 8),
        endDate: const PlanDate(2026, 9, 10),
      ),
    };

    good.forEach((name, t) {
      test('对照组：$name → 不抛', () {
        expect(t.checkInvariants, returnsNormally);
      });
    });
  });

  group('copyWith 的哨兵语义', () {
    test('不传 = 不改；显式传 null = 清空', () {
      // 「清空备注」和「不动备注」若写成同一个调用，这类缺陷在测试里
      // 极难看出来 —— 两者中总有一个碰巧是对的。
      final t = task().copyWith(note: '原备注');
      expect(t.copyWith(title: '新标题').note, '原备注');
      expect(t.copyWith(note: null).note, isNull);
    });
  });
}

String _readSource(String relativePath) =>
    // 测试运行目录是包根，直接相对读取即可。
    File(relativePath).readAsStringSync();

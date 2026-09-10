/// 命令的 JSON 往返 —— **overview §6 里 V4 那一格的验收项**。
///
/// 「AI Agent 只需输出 JSON 形态的命令」这句话要成立，前提是每一个命令
/// 都能无损往返。少一个字段、或者 `null` 与「不传」分不清，
/// Agent 产出的命令执行出来就与它的意图不符 —— 而那时已是 V4，
/// 改协议要同时动客户端与服务端。
///
/// 这个文件是纯 Dart 的：不启动 Flutter binding，不碰数据库。
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/patch/unset.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/domain/commands/task_command.dart';
import 'package:planning_assistant/domain/entities/occurrence.dart';
import 'package:planning_assistant/domain/entities/reminder.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/value_objects/occurrence_key.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';

/// 每种命令一个**字段填满**的样本。
///
/// 全用默认值的样本无法暴露「某个字段忘了序列化」—— 默认值在两边都对得上。
final _samples = <TaskCommand>[
  const CreateTaskCommand(
    taskId: 'task-1',
    title: '标题',
    kind: TaskKind.staged,
    timeZoneId: 'America/New_York',
    note: '备注',
    categoryId: 'cat-1',
    priority: TaskPriority.urgent,
    isAllDay: false,
    planDate: PlanDate(2026, 3, 8),
    startMinute: MinuteOfDay.midnight,
    endDate: PlanDate(2026, 3, 10),
    endMinute: MinuteOfDay.endOfDay,
    recurrenceRule: 'RRULE:FREQ=DAILY;COUNT=3',
    colorArgb: 0xFF112233,
    icon: 'star',
    sortOrder: 3.5,
  ),
  UpdateTaskFieldsCommand(
    taskId: 'task-1',
    title: '新标题',
    note: '新备注',
    categoryId: 'cat-2',
    priority: TaskPriority.low,
    planDate: const PlanDate(2026, 4, 1),
    startMinute: MinuteOfDay.of(8, 15),
    endDate: const PlanDate(2026, 4, 2),
    endMinute: MinuteOfDay.of(9, 45),
    recurrenceRule: 'RRULE:FREQ=WEEKLY',
    colorArgb: 0xFF445566,
    icon: 'moon',
    sortOrder: 7.25,
  ),
  const ChangeTaskStatusCommand(
    taskId: 'task-1',
    status: TaskStatus.inProgress,
  ),
  const ArchiveTaskCommand('task-1'),
  const UnarchiveTaskCommand('task-1'),
  const DeleteTaskCommand('task-1'),
  const RestoreTaskCommand('task-1'),
  const ReplaceStagesCommand(
    taskId: 'task-1',
    stages: [
      StageSpec(
        id: 'stage-0',
        title: '阶段零',
        orderIndex: 0,
        startOffsetMinutes: 30,
        durationMinutes: 60,
        colorArgb: 0xFF778899,
        status: TaskStatus.done,
      ),
      StageSpec(id: 'stage-1', title: '阶段一', orderIndex: 1),
    ],
  ),
  const CompleteTaskWithStagesCommand('task-1'),
  // 两种 kind 各来一条：只放相对那种的话，绝对提醒的日期与时刻
  // 在往返里一个字节都不会被碰到。
  ReplaceRemindersCommand(
    taskId: 'task-1',
    reminders: [
      const ReminderSpec(
        id: 'rem-0',
        kind: ReminderKind.relativeToStart,
        offsetMinutes: -15,
      ),
      ReminderSpec(
        id: 'rem-1',
        kind: ReminderKind.absolute,
        absoluteDate: const PlanDate(2026, 9, 20),
        absoluteMinute: MinuteOfDay.of(8, 30),
        isEnabled: false,
      ),
    ],
  ),
  SetOccurrenceStatusCommand(
    taskId: 'task-1',
    occurrenceKey: _key,
    status: OccurrenceStatus.done,
  ),
  SkipOccurrenceCommand(taskId: 'task-1', occurrenceKey: _key),
  SetStageOccurrenceStatusCommand(
    taskId: 'task-1',
    stageId: 'stage-1',
    occurrenceKey: _key,
    status: TaskStatus.done,
  ),
  ConvertTaskAllDayModeCommand(
    taskId: 'task-1',
    toAllDay: false,
    startMinute: MinuteOfDay.of(9, 30),
  ),
  const ConvertTaskAllDayModeCommand(taskId: 'task-1', toAllDay: true),
  const ReplaceChecklistCommand(
    taskId: 'task-1',
    items: [
      ChecklistItemSpec(id: 'c0', title: '带伞', orderIndex: 0, isDone: true),
      ChecklistItemSpec(id: 'c1', title: '买菜', orderIndex: 1),
    ],
  ),
  MoveOccurrenceCommand(
    taskId: 'task-1',
    occurrenceKey: _key,
    planDate: const PlanDate(2026, 9, 20),
    startMinute: MinuteOfDay.of(14, 30),
  ),
  SplitRecurringTaskCommand(
    taskId: 'task-1',
    splitAt: _key,
    newTask: const CreateTaskCommand(
      taskId: 'task-2',
      title: '分裂出来的那一半',
      kind: TaskKind.single,
      timeZoneId: 'Asia/Shanghai',
      planDate: PlanDate(2026, 9, 20),
      splitFromTaskId: 'task-1',
    ),
    stages: const [StageSpec(id: 's9', title: '第一步', orderIndex: 0)],
  ),
];

/// 样本里用的那一次。带时刻的形态 —— 全天形态是纯日期，
/// 用它才验得到 `THH:mm` 那一段有没有丢。
final _key = OccurrenceKey.timed(
  const PlanDate(2026, 9, 8),
  MinuteOfDay.of(9, 0),
);

void main() {
  group('JSON 往返（V4 验收项）', () {
    test('样本覆盖了全部命令类型 —— 少一种就说明漏测了', () {
      // 没有这条的话，新增命令时忘了加样本，下面所有用例照样全绿。
      expect(_samples.map((c) => c.type).toSet(), TaskCommand.allTypes.toSet());
      expect(
        TaskCommand.allTypes.toSet().length,
        TaskCommand.allTypes.length,
        reason: '类型串重复会让 fromJson 永远走到先匹配的那个',
      );
    });

    test('`allTypes` 与源码里声明的 kType **逐个对得上**', () {
      // ## 这条是补出来的，因为上面那条曾经形同虚设
      //
      // `allTypes` 是**手写**的一张表。M2 后期加了四条命令
      // （改某次状态、跳过、挪走、本次及以后）都没往里加 ——
      // 于是上面那条「样本覆盖全部类型」比的是**两张都过时的表**：
      // 样本少四个、allTypes 也少四个，两边一样，照样全绿。
      //
      // 当时还有一条 `expect(allTypes.length, 9)` 看着像兜底，其实不是：
      // 它只在**有人改了 allTypes** 时才响，而真实的失败模式恰恰是
      // 「忘了改」。计数式守卫验的是基数，要验的是同一性。
      //
      // 所以改成扫源码：`task_command.dart` 里每一个 `kType` 声明都必须
      // 在 allTypes 里，反之亦然。
      final source = File('lib/domain/commands/task_command.dart')
          .readAsStringSync();
      final declared = RegExp(r"static const kType = '(\w+)';")
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toSet();

      // 自检：扫出来得像回事，不能因为正则失配变成空集合而「通过」。
      expect(declared, contains(CreateTaskCommand.kType));
      expect(declared.length, greaterThan(8));

      expect(
        TaskCommand.allTypes.toSet(),
        declared,
        reason:
            'allTypes 与源码里的 kType 分叉了 —— '
            '少的那些命令 fromJson 认不出来，回放时会被静默丢弃',
      );
    });

    for (final sample in _samples) {
      test('${sample.type} 经 jsonEncode/jsonDecode 后语义不变', () {
        // 走真正的 jsonEncode/Decode，而不是直接把 Map 传回去 ——
        // 后者测不出「值不是合法 JSON 类型」这一类问题。
        final wire = jsonEncode(sample.toJson());
        final back = TaskCommand.fromJson(
          jsonDecode(wire) as Map<String, Object?>,
        );

        expect(back.type, sample.type);
        expect(
          jsonEncode(back.toJson()),
          wire,
          reason: '${sample.type} 往返后 JSON 不一致',
        );
      });
    }

    test('CreateTask 的每个字段都逐一还原（不只是 JSON 串相等）', () {
      // JSON 串相等只证明「两次序列化一致」。若某字段两次都漏掉，
      // 串照样相等 —— 必须逐字段核对还原结果。
      final original = _samples.whereType<CreateTaskCommand>().single;
      final back = TaskCommand.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, Object?>,
      ) as CreateTaskCommand;

      expect(back.taskId, original.taskId);
      expect(back.title, original.title);
      expect(back.kind, original.kind);
      expect(back.timeZoneId, original.timeZoneId);
      expect(back.note, original.note);
      expect(back.categoryId, original.categoryId);
      expect(back.priority, original.priority);
      expect(back.isAllDay, original.isAllDay);
      expect(back.planDate, original.planDate);
      expect(back.startMinute, original.startMinute);
      expect(back.endDate, original.endDate);
      expect(back.endMinute, original.endMinute);
      expect(back.recurrenceRule, original.recurrenceRule);
      expect(back.colorArgb, original.colorArgb);
      expect(back.icon, original.icon);
      expect(back.sortOrder, original.sortOrder);
    });

    test('ReplaceStages 的阶段列表逐项还原', () {
      final original = _samples.whereType<ReplaceStagesCommand>().single;
      final back = TaskCommand.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, Object?>,
      ) as ReplaceStagesCommand;

      expect(back.stages.length, 2);
      expect(back.stages[0].id, 'stage-0');
      expect(back.stages[0].startOffsetMinutes, 30);
      expect(back.stages[0].durationMinutes, 60, reason: '与 startOffset 不能搞反');
      expect(back.stages[0].status, TaskStatus.done);
      expect(back.stages[1].startOffsetMinutes, isNull);
      expect(back.stages[1].status, TaskStatus.pending);
    });
  });

  group('补丁语义：「不改」与「清空」在协议上必须可区分', () {
    test('不传的字段在 JSON 里不出现', () {
      const cmd = UpdateTaskFieldsCommand(taskId: 't1', title: '只改标题');
      final json = cmd.toJson();

      expect(json.containsKey('title'), isTrue);
      expect(json.containsKey('note'), isFalse, reason: '不改就不该出现在载荷里');
      expect(json.containsKey('categoryId'), isFalse);
      expect(json.containsKey('planDate'), isFalse);
    });

    test('显式传 null 的字段在 JSON 里是 null', () {
      const cmd = UpdateTaskFieldsCommand(taskId: 't1', note: null);
      final json = cmd.toJson();

      expect(json.containsKey('note'), isTrue);
      expect(json['note'], isNull);
    });

    test('两者往返后仍然可区分 —— 这是本组的关键', () {
      // 若序列化把「不改」也写成 null，往返后两者会塌成同一个东西，
      // 而「清空备注」这个功能就实现不出来了。
      const keep = UpdateTaskFieldsCommand(taskId: 't1', title: 'x');
      const clear = UpdateTaskFieldsCommand(
        taskId: 't1',
        title: 'x',
        note: null,
      );

      final keepBack = TaskCommand.fromJson(
        jsonDecode(jsonEncode(keep.toJson())) as Map<String, Object?>,
      ) as UpdateTaskFieldsCommand;
      final clearBack = TaskCommand.fromJson(
        jsonDecode(jsonEncode(clear.toJson())) as Map<String, Object?>,
      ) as UpdateTaskFieldsCommand;

      expect(identical(keepBack.note, unset), isTrue, reason: '「不改」应还原为哨兵');
      expect(clearBack.note, isNull);
      expect(identical(clearBack.note, unset), isFalse, reason: '「清空」不是哨兵');
    });

    test('哨兵是专门的类型，不与随手写的 const Object() 相等', () {
      // 这条盯的是 core/patch/unset.dart 里记的那个坑：
      // 两处各写 `static const Object _unset = Object();` 时，Dart 会把它们
      // 规范化成同一个实例，于是跨类传哨兵「碰巧能用」。
      // 碰巧能用比不能用更危险 —— 改成别的 const 值时行为会静默改变。
      expect(identical(unset, const Object()), isFalse);
      expect(
        identical(unset, const Unset()),
        isTrue,
        reason: '同类型的 const 仍规范化',
      );
    });
  });

  group('坏载荷不静默吞掉', () {
    test('未知命令类型抛 UnknownCommandException', () {
      // V3 云端下发本端不认识的命令时，静默跳过会让两端状态永久分歧，
      // 且没有任何迹象。
      expect(
        () => TaskCommand.fromJson({'type': 'nukeEverything', 'taskId': 't'}),
        throwsA(isA<UnknownCommandException>()),
      );
    });

    test('缺少 type 字段同样抛出', () {
      expect(
        () => TaskCommand.fromJson({'taskId': 't'}),
        throwsA(isA<UnknownCommandException>()),
      );
    });

    test('type 不是字符串时抛出，而不是 crash 在类型转换上', () {
      expect(
        () => TaskCommand.fromJson({'type': 42}),
        throwsA(isA<UnknownCommandException>()),
      );
    });

    test('未知的状态串抛 FormatException', () {
      expect(
        () => TaskCommand.fromJson({
          'type': 'changeTaskStatus',
          'taskId': 't',
          'status': 'exploded',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('allTypes 与 fromJson 支持的类型完全一致', () {
      // allTypes 漏登记一个，守卫测试就会漏掉它；多登记一个，
      // 这里会因为 fromJson 抛异常而红。
      for (final type in TaskCommand.allTypes) {
        expect(
          () => TaskCommand.fromJson({'type': type}),
          isNot(throwsA(isA<UnknownCommandException>())),
          reason: '$type 在 allTypes 里但 fromJson 不认识',
        );
      }
    });
  });
}

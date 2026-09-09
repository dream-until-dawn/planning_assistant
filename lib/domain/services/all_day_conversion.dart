/// 全天 ⇄ 定时的切换（R-27、data-model §4.6）。
///
/// ## 为什么这件事需要一条专门的领域操作
///
/// `occurrenceKey` 的形态**跟着 `isAllDay` 走**：全天是 `yyyy-MM-dd`，
/// 定时是 `yyyy-MM-ddTHH:mm`。§4.6 特意没让全天补成 `T00:00`，
/// 理由是「用纯日期表达『这一天』语义上更诚实」——
/// 代价就落在这里：**切换形态时，已有例外的 key 必须跟着迁移**，
/// 否则它们全部失联（例外还在库里，却再也挂不上任何一次发生）。
///
/// 所以 `isAllDay` 不在 `UpdateTaskFieldsCommand` 里。那条命令是
/// 「改几个字段」，而这件事是「改一个字段 + 重写另外两张表的主键」。
/// 混在一起的话，任何一条改标题的路径都得顺带考虑 key 迁移。
///
/// ## 主键变了，所以是「删旧建新」不是「改一行」
///
/// 例外的行 id 是 `taskId#occurrenceKey` 派生的，阶段状态是
/// `stageId#occurrenceKey`。key 一变，行的身份就变了 ——
/// 原地改字段的话，V3 对端会看到一行「id 没变但 key 变了」的记录，
/// 而它手上那份旧的永远等不到墓碑。所以旧行打墓碑、新行另起。
library;

import '../../core/time/minute_of_day.dart';
import '../entities/occurrence_override.dart';
import '../entities/stage_occurrence_state.dart';
import '../entities/task.dart';
import '../value_objects/occurrence_key.dart';
import '../value_objects/task_status.dart';

/// 一次切换要写回的全部东西。
///
/// [movedOverrides] / [movedStageStates] 里的 `from` 是**旧 key**：
/// 调用方要拿它去打旧行的墓碑，再写 `to` 那一行。
typedef AllDayConversion = ({
  Task task,
  List<({OccurrenceKey from, OccurrenceOverride to})> movedOverrides,
  List<({OccurrenceKey from, StageOccurrenceState to})> movedStageStates,
});

/// 把一条任务在全天与定时之间切换，并算出所有 key 的迁移。
///
/// [startMinute] 只在转成**定时**时给：那是新的每日开始时刻，
/// 也是所有例外 key 的时间部分。转成全天时必须为 null ——
/// 允许传一个「转成全天时的时刻」是自相矛盾的入参。
///
/// **同一天上有两条例外时抛异常**，不做「留一条丢一条」：
/// 定时 → 全天会把 `9:00` 与 `14:00` 两次压成同一个 `yyyy-MM-dd`。
/// 悄悄丢一条的话，用户跳过的那一次会复活、或者改过的标题不见了 ——
/// 而他只是拨了一个开关。这种时候正确的做法是拦住并说清楚。
AllDayConversion convertAllDayMode(
  Task task, {
  required bool toAllDay,
  required MinuteOfDay? startMinute,
  required List<OccurrenceOverride> overrides,
  required List<StageOccurrenceState> stageStates,
}) {
  if (toAllDay && startMinute != null) {
    throw const DomainInvariantViolation('转成全天任务时不该带开始时刻');
  }
  if (!toAllDay && startMinute == null) {
    throw const DomainInvariantViolation('转成定时任务必须给一个开始时刻');
  }

  OccurrenceKey remap(OccurrenceKey old) => toAllDay
      ? OccurrenceKey.allDay(old.date)
      : OccurrenceKey.timed(old.date, startMinute!);

  // 撞车检查放在最前面：**一行都还没写就要发现**。
  _requireNoCollision([for (final o in overrides) o.key], remap, '例外');
  for (final entry in _byStage(stageStates).entries) {
    _requireNoCollision(
      [for (final s in entry.value) s.occurrenceKey],
      remap,
      '阶段「${entry.key}」的状态',
    );
  }

  return (
    task: task.copyWith(
      isAllDay: toAllDay,
      // 转全天：清掉时刻。**日期留着** —— 用户改的是「有没有具体时刻」，
      // 不是「哪一天」。
      startMinute: toAllDay ? null : startMinute,
      endMinute: toAllDay ? null : task.endMinute,
    )..checkInvariants(),
    movedOverrides: [
      for (final o in overrides)
        if (o.key.value != remap(o.key).value)
          (from: o.key, to: o.withKey(remap(o.key))),
    ],
    movedStageStates: [
      for (final s in stageStates)
        if (s.occurrenceKey.value != remap(s.occurrenceKey).value)
          (from: s.occurrenceKey, to: s.withKey(remap(s.occurrenceKey))),
    ],
  );
}

Map<String, List<StageOccurrenceState>> _byStage(
  List<StageOccurrenceState> states,
) {
  final out = <String, List<StageOccurrenceState>>{};
  for (final s in states) {
    (out[s.stageId] ??= []).add(s);
  }
  return out;
}

void _requireNoCollision(
  List<OccurrenceKey> keys,
  OccurrenceKey Function(OccurrenceKey) remap,
  String what,
) {
  final seen = <String, OccurrenceKey>{};
  for (final key in keys) {
    final to = remap(key);
    final clash = seen[to.value];
    if (clash != null) {
      throw DomainInvariantViolation(
        '切换之后 $what 会撞在同一个 key 上：'
        '${clash.value} 与 ${key.value} 都变成 ${to.value}。'
        '先处理掉其中一条再切换。',
      );
    }
    seen[to.value] = key;
  }
}

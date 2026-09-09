/// 视图里的**一行**：一条任务，或者它的某一次发生（view-specs §0.2）。
///
/// ## 为什么不是直接用 `Occurrence`
///
/// 规格里共享数据源的出参写的是 `Stream<List<Occurrence>>`。但列表要显示
/// 两类 `Occurrence` 表达不了的东西：
///
/// | | `Occurrence` 能表达吗 |
/// |---|---|
/// | 没有日期的任务（「无日期」分组，§2.1） | ✘ —— `start` 是必填的墙钟 |
/// | 展开窗口之外的任务 | ✘ —— 窗口外不产出 |
///
/// 两者都不能从列表里消失：无日期是个合法且常见的状态，而「明年的事」
/// 也得看得见。所以这一层是 `(任务, 可选的某一次)`：
///
///  · 不重复的任务 → 一行，`occurrence` 为 null，日期取任务自己的；
///  · 重复的任务 → 每次发生一行，日期与状态取那一次的。
///
/// ## 为什么这些访问器要在这里
///
/// 分组、排序、筛选原本直接读 `Task` 的字段。若让它们各自去写
/// `occurrence?.start.date ?? task.planDate`，同一个「生效日期」的定义
/// 会散在四五处 —— 而漏掉一处的表现是「这一次被挪到了周三，
/// 列表却还把它排在周一」。所以在这里定义一次。
library;

import '../../../../core/time/date_and_minute.dart';
import '../../../../core/time/minute_of_day.dart';
import '../../../../core/time/plan_date.dart';
import '../../../../domain/entities/occurrence.dart';
import '../../../../domain/entities/stage.dart';
import '../../../../domain/entities/task.dart';
import '../../../../domain/services/effective_span.dart';
import '../../../../domain/value_objects/occurrence_key.dart';
import '../../../../domain/value_objects/task_status.dart';

final class TaskOccurrence {
  const TaskOccurrence({
    required this.task,
    this.occurrence,
    this.stages = const [],
  });

  final Task task;

  /// 这条任务的阶段。**只为算有效跨度**（data-model §4.7）——
  /// 末阶段可能排到 `endDate` 之后，那时跨度以阶段为准。
  ///
  /// 默认空表：不带阶段时 [effectiveEndDate] 与 [endDate] 一致，
  /// 所以旧的调用点行为不变。
  final List<Stage> stages;

  /// null = 这一行就是任务本身（不重复，或没有日期）。
  final Occurrence? occurrence;

  bool get isOccurrence => occurrence != null;

  /// 这一行的稳定标识。
  ///
  /// **重复任务的每一次都要有自己的 id**：拿 taskId 当行标识的话，
  /// 同一条规则展开出的三十行会共用一个 key —— Flutter 的列表复用
  /// 会认错行，勾一行动的是另一行。
  String get id {
    final o = occurrence;
    return o == null ? task.id : '${task.id}#${o.key.value}';
  }

  /// 这一次的原始标识。不重复的任务没有。
  OccurrenceKey? get key => occurrence?.key;

  /// **生效**的日期。被例外挪过的那一次，用挪之后的。
  PlanDate? get planDate => occurrence?.start.date ?? task.planDate;

  /// 生效的开始时刻。全天没有。
  MinuteOfDay? get startMinute {
    final o = occurrence;
    if (o != null) return o.isAllDay ? null : o.start.minuteOfDay;
    return task.startMinute;
  }

  /// 生效的结束日期 / 时刻。没有明确结束时都是 null。
  ///
  /// 时间轴要靠它算块高（§1.2「高度∝时长」），甘特要靠它算条长。
  /// 与开始侧一样，被例外挪过的那一次用挪之后的。
  PlanDate? get endDate {
    final o = occurrence;
    if (o == null) return task.endDate;
    return o.end?.date;
  }

  MinuteOfDay? get endMinute {
    final o = occurrence;
    if (o == null) return task.isAllDay ? null : task.endMinute;
    if (o.isAllDay) return null;
    return o.end?.minuteOfDay;
  }

  /// **有效**结束 —— 存储的结束与各阶段结束里靠后的那个（§4.7）。
  ///
  /// 四个视图一律用它，不得各自计算：甘特自行「扩展到末阶段」而时间轴
  /// 按 `endDate` 画的话，同一条任务在两个视图里跨度不同，
  /// 而那正是「四视图共享同一份数据源」要排除的。
  EffectiveSpan? get span {
    final date = planDate;
    if (date == null) return null;
    return effectiveSpan(
      start: DateAndMinute(date, startMinute ?? MinuteOfDay.midnight),
      // **走这一行自己的结束**，不是任务的 —— 重复任务的每一次
      // 各有各的结束（被例外挪过的那一次尤其）。
      end: storedEnd(endDate: endDate, endMinute: endMinute),
      stages: stages,
    );
  }

  /// [span] 的结束日期。没有日期的行为 null。
  PlanDate? get effectiveEndDate {
    final s = span;
    if (s == null) return null;
    // 存储侧与阶段侧都没给出结束时，跨度是零长 —— 那时**不谎报一个
    // 结束日期**，与 `endDate` 一样返回 null。有阶段撑开时才有值。
    if (s.end == s.start && endDate == null) return null;
    return s.end.date;
  }

  /// [span] 的结束时刻。全天任务没有。
  MinuteOfDay? get effectiveEndMinute {
    if (isAllDay) return null;
    final s = span;
    if (s == null || (s.end == s.start && endDate == null)) return null;
    return s.end.minute;
  }

  /// 生效的标题。例外可以只改某一次的标题（FR-TASK-05）。
  String get title => occurrence?.titleOverride ?? task.title;

  String? get note => occurrence?.noteOverride ?? task.note;

  /// 生效的状态。
  ///
  /// 重复任务的 `tasks.status` **恒为 pending**（data-model §4.3），
  /// 真实状态在例外里 —— 所以这里必须看 occurrence，
  /// 否则每一次都显示成未完成。
  TaskStatus get status {
    final o = occurrence;
    if (o == null) return task.status;
    return switch (o.status) {
      OccurrenceStatus.pending => TaskStatus.pending,
      OccurrenceStatus.inProgress => TaskStatus.inProgress,
      OccurrenceStatus.done => TaskStatus.done,
      OccurrenceStatus.skipped => TaskStatus.skipped,
    };
  }

  bool get isAllDay => occurrence?.isAllDay ?? task.isAllDay;

  TaskPriority get priority => task.priority;
  String? get categoryId => task.categoryId;
  double get sortOrder => task.sortOrder;
  String get taskId => task.id;
  bool get isRecurring => task.isRecurring;

  @override
  String toString() => 'TaskOccurrence($id)';
}

/// 任务编辑器的表单状态与保存（FR-TASK-01）。
///
/// **写路径只有一条：构造命令 → `CommandDispatcher`。**
/// 这里拿不到仓库，也不该拿 —— 分层守卫盯着这条
/// （module-map §3：presentation 不得持有 Repository）。
/// 理由是 FR-AI-01：V4 的语音/Agent 要能构造同一批命令走同一条路，
/// UI 绕过命令直接写库的话，那条路就绕过了全部不变量与 outbox。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../core/patch/unset.dart';
import '../../../core/time/minute_of_day.dart';
import '../../../core/time/plan_date.dart';
import '../../../domain/commands/task_command.dart';
import '../../../domain/entities/task.dart';

/// 编辑器里那张表单。
///
/// 与 [Task] 刻意**不是**同一个类型：表单里「标题还没填」是合法中间态，
/// 而领域实体不允许标题为空。把两者混成一个类型的话，
/// 要么实体的不变量被放宽，要么表单没法表达「填一半」。
final class TaskDraft {
  const TaskDraft({
    this.title = '',
    this.note = '',
    this.isAllDay = true,
    this.planDate,
    this.startMinute,
  });

  final String title;
  final String note;

  /// 默认全天。**大多数事情没有精确到分钟的时刻**，
  /// 让用户先说「哪天」，要不要具体到几点是可选的加法。
  final bool isAllDay;

  final PlanDate? planDate;
  final MinuteOfDay? startMinute;

  /// 能不能保存。**只要求标题非空**（FR-TASK-01：仅填标题即可保存）。
  ///
  /// 用 `trim()`：一串空格不是标题。不 trim 的话用户能存出一条
  /// 看起来空白、却怎么也搜不到的任务。
  bool get canSave => title.trim().isNotEmpty;

  TaskDraft copyWith({
    String? title,
    String? note,
    bool? isAllDay,
    Object? planDate = unset,
    Object? startMinute = unset,
  }) => TaskDraft(
    title: title ?? this.title,
    note: note ?? this.note,
    isAllDay: isAllDay ?? this.isAllDay,
    // 日期与时刻都**要能被清掉**（「其实不用定在哪天」是常见操作），
    // 所以用 core/patch 的哨兵，不用 `?? this.x` —— 后者把 null
    // 解释成「不改」，于是清空这个功能实现不出来。
    //
    // 初版只给 startMinute 用了哨兵，planDate 漏了 —— 同一个坑
    // 在同一个类里补了两处、漏了第三处，是测试抓出来的。
    planDate: patch(planDate, this.planDate),
    startMinute: patch(startMinute, this.startMinute),
  );
}

/// 表单控制器。
final class TaskEditorController extends Notifier<TaskDraft> {
  @override
  TaskDraft build() => const TaskDraft();

  void setTitle(String value) => state = state.copyWith(title: value);

  void setNote(String value) => state = state.copyWith(note: value);

  void setPlanDate(PlanDate? date) => state = state.copyWith(planDate: date);

  /// 切全天。
  ///
  /// 关掉「全天」时**不自动塞一个时刻** —— 由 UI 让用户挑；
  /// 打开「全天」时必须**清掉**已选时刻，否则会存下一条
  /// 「全天但有 09:30」的任务，两个字段互相矛盾。
  void setAllDay(bool value) => state = value
      ? state.copyWith(isAllDay: true, startMinute: null)
      : state.copyWith(isAllDay: false);

  void setStartMinute(MinuteOfDay? minute) => state = minute == null
      ? state.copyWith(startMinute: null)
      : state.copyWith(startMinute: minute, isAllDay: false);

  /// 保存。返回新任务的 ID。
  ///
  /// 调用方应先看 [TaskDraft.canSave]；这里再挡一道，
  /// 因为「按钮禁用」是界面约定，不是不变量。
  Future<String> save() async {
    final draft = state;
    if (!draft.canSave) {
      throw StateError('标题为空，不能保存');
    }

    final resolver = ref.read(timeZoneResolverProvider);
    final id = ref.read(idGeneratorProvider).newId();

    await ref
        .read(taskCommandDispatcherProvider)
        .dispatch(
          CreateTaskCommand(
            taskId: id,
            title: draft.title.trim(),
            kind: TaskKind.single,
            // 记**用户所在的时区**，不是 UTC（ADR-0005）：
            // 「每天 07:00 起床」飞到伦敦后仍应是当地 07:00。
            timeZoneId: resolver.currentZoneId(),
            note: draft.note.trim().isEmpty ? null : draft.note.trim(),
            isAllDay: draft.isAllDay,
            planDate: draft.planDate,
            startMinute: draft.isAllDay ? null : draft.startMinute,
          ),
        );
    return id;
  }
}

/// **autoDispose 是必需的，不是优化**：不自动销毁的话，
/// 保存完再点「新建」，表单里还留着上一条的标题。
///
/// Riverpod 3 把 autoDispose 从 Notifier 基类挪到了 provider 上
/// （`AutoDisposeNotifier` 已删除）—— 类照常 extends [Notifier]。
final taskEditorProvider =
    NotifierProvider.autoDispose<TaskEditorController, TaskDraft>(
      TaskEditorController.new,
    );

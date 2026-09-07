/// 取「今日概览」（overview §6，V2 桌面小组件与常驻通知的数据源）。
///
/// **这条路径必须不依赖 Flutter**：V2 的小组件跑在后台 isolate、甚至另一个
/// 进程，那里没有 binding。所以整条链路（Drift → 领域实体 → 概览）
/// 只用纯 Dart 与 `sqlite3` 的原生库。
///
/// 验收方式是 `test/domain/today_digest_pure_dart_test.dart`：
/// 它用 `package:test`（不是 `flutter_test`），并由 CI 用 **`dart test`**
/// 而非 `flutter test` 跑一遍。任何一处引入 `dart:ui`，那一步会直接编译失败 ——
/// 这比「读一遍 import 列表」可靠得多。
library;

import '../../core/time/local_wall_time.dart';
import '../../core/time/minute_of_day.dart';
import '../../core/time/plan_date.dart';
import '../../domain/entities/occurrence.dart';
import '../../domain/entities/task.dart';
import '../../domain/queries/today_digest.dart';
import '../../domain/recurrence/recurrence_engine.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/value_objects/task_status.dart';

final class TodayDigestService {
  const TodayDigestService(this._repo, this._engine);

  final TaskRepository _repo;
  final RecurrenceEngine _engine;

  /// 某一天的概览。
  ///
  /// 两类任务都要算进来：
  ///  · 不重复任务：`planDate` 恰为该日；
  ///  · 重复任务：把规则在该日展开，有发生才算。
  ///
  /// 漏掉后者的话，「每天 09:00 跑步」这类任务永远不出现在概览里 ——
  /// 而它恰恰是最需要被提醒的那种。
  Future<TodayDigest> forDate(PlanDate date) async {
    final tasks = await _repo.findTasks();
    final window = DateRange(date, date);

    final onDate = <Task>[];
    final progress = <String, (int, int)>{};

    for (final task in tasks) {
      if (!await _occursOn(task, window)) continue;
      onDate.add(task);

      // 阶段进度：概览要显示 2/5，所以这里就得算出来。
      final stages = await _repo.findStagesOfTask(task.id);
      if (stages.isNotEmpty) {
        progress[task.id] = (
          stages.where((s) => s.status == TaskStatus.done).length,
          stages.length,
        );
      }
    }

    return buildTodayDigest(
      date: date.toString(),
      tasks: onDate,
      stageProgress: progress,
    );
  }

  Future<bool> _occursOn(Task task, DateRange window) async {
    final planDate = task.planDate;
    if (planDate == null) return false;

    if (!task.isRecurring) return planDate == window.start;

    final occurrences = _engine.expand(
      context: RecurrenceContext(
        taskId: task.id,
        dtStart: LocalWallTime(
          date: planDate,
          minuteOfDay: task.startMinute ?? MinuteOfDay.midnight,
          timeZoneId: task.timeZoneId,
        ),
        isAllDay: task.isAllDay,
        recurrence: task.recurrence,
      ),
      window: window,
    );
    // skip 掉的那一次不算 —— 用户明确说了这次不做。
    return occurrences.any((o) => o.status != OccurrenceStatus.skipped);
  }
}

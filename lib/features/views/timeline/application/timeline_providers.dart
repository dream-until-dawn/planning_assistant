/// 时间轴的数据源（view-specs §1）。
///
/// **视图不自己查库**（§0.2）—— 与列表走同一条流，只是展开用的是
/// [expandInWindow]（窗口内一次不落）而不是列表那套折叠策略。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app_providers.dart';
import '../../../../core/time/plan_date.dart';
import '../../../../domain/recurrence/recurrence_engine.dart';
import '../../../../domain/value_objects/task_status.dart';
import '../../shared/application/occurrence_expansion.dart';
import '../../shared/application/overlap_layout.dart';
import '../../shared/application/task_filter.dart';
import '../../shared/application/task_occurrence.dart';
import '../../shared/application/task_providers.dart';
import '../../shared/application/view_shared_state.dart';
import 'timeline_blocks.dart';

/// 时间轴看的是**哪一天** —— 共享状态里的聚焦日期（FR-VIEW-06）。
///
/// 单独拆出来是为了让下面几个 provider 只依赖「日期」这一件事：
/// 直接读 `viewSharedStateProvider` 的话，改一下筛选也会让它们重算。
final timelineDateProvider = Provider<PlanDate>(
  (ref) => ref.watch(viewSharedStateProvider).focusedDate,
);

/// 这一天要显示的发生，**已筛选**。
///
/// 筛选放在这里而不是下游：日历那侧的同名 provider 就是「已筛选」的意思，
/// 两个形状一样的名字表示不同的东西，是下一个 bug 的温床。
/// 有一条测试盯着三个视图对同一份筛选的反应（FR-VIEW-05）。
final timelineOccurrencesProvider = Provider<List<TaskOccurrence>>((ref) {
  final date = ref.watch(timelineDateProvider);
  final filter = ref.watch(viewSharedStateProvider).filter;

  return switch (ref.watch(visibleTasksProvider)) {
    AsyncData(:final value) => applyFilter(
      expandInWindow(
        tasks: value,
        // 例外还没读出来时先按「没有例外」展开 —— 下一帧到了自动重算。
        // 抛或者卡住的话，首帧会是一屏错误，而它其实只是还没读完。
        overrides: switch (ref.watch(allOverridesProvider)) {
          AsyncData(:final value) => value,
          _ => const [],
        },
        // **只要这一天。** 跨天任务由 `expandInWindow` 按覆盖区间捞回来，
        // 不需要在这里把窗口撑宽 —— 撑宽多少才够是个没有答案的问题。
        window: DateRange(date, date),
        // 阶段进来算有效跨度（§4.7）—— 四视图共用同一个答案。
        stagesByTask: ref.watch(stagesByTaskProvider),
        stageStatesByTask: ref.watch(stageStatesByTaskProvider),
        engine: RecurrenceEngine(ref.watch(timeZoneResolverProvider)),
        // 跳过的那次默认不出现（FR-TASK-05），显式筛「已跳过」才现身。
        includeSkipped: filter.statuses.contains(TaskStatus.skipped),
      ),
      filter,
    ),
    _ => const [],
  };
});

/// 摆到这一天上的块与「随时」区。
final timelineDayProvider = Provider<TimelineDay>(
  (ref) => timelineDayFor(
    ref.watch(timelineOccurrencesProvider),
    ref.watch(timelineDateProvider),
  ),
);

/// 块的左右排布（§1.2「同时段 N 个任务等宽并排」）。
///
/// 与竖向甘特共用 [layoutOverlaps]，只是单位是分钟。
final timelineLayoutProvider = Provider<List<OverlapCluster<TimelineBlock>>>((
  ref,
) {
  final day = ref.watch(timelineDayProvider);
  return layoutOverlaps([
    for (final b in day.blocks)
      OverlapInput(item: b, start: b.startMinute, end: b.endMinute),
  ]);
});

/// 整分钟的心跳，供当前时刻线用。
///
/// **单独拆成一个可覆盖的 provider，是为了测试。** 直接在下面起
/// `Timer` 的话，每个 widget 测试跑完都会剩一个最多 60 秒的定时器，
/// binding 判「树都拆了还有定时器在」，整批测试变红 ——
/// 而那与被测的行为毫无关系。测试里覆盖成一条空流即可。
///
/// 对齐到**下一个整分**，不是「每 60 秒一次」：后者的相位取决于
/// 视图什么时候建起来，于是「线什么时候跳」在 59 秒里随机 ——
/// 排查「线没动」时分不清是坏了还是还没到。
final minuteTickProvider = Provider<Stream<void>>((ref) {
  final clock = ref.watch(clockProvider);
  final controller = StreamController<void>.broadcast();
  Timer? timer;

  void schedule() {
    // 相位按 **UTC 的整分**算。所有时区的偏移都是整分钟
    // （半小时、45 分钟的时区也不例外），所以 UTC 的分界线
    // 与任何本地时区的分界线是同一条 —— 不必先换算再对齐。
    final now = clock.nowUtc();
    final next = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));
    timer = Timer(next.difference(now), () {
      controller.add(null);
      schedule();
    });
  }

  schedule();
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});

/// 「今天」的当前时刻（当天第几分钟），用来画那条线（§1.2）。
///
/// **不是今天就给 null** —— 在别的日子上画一条「现在」是假的。
final currentMinuteProvider = StreamProvider<int?>((ref) {
  final tick = ref.watch(minuteTickProvider);
  final resolver = ref.watch(timeZoneResolverProvider);
  final clock = ref.watch(clockProvider);
  final date = ref.watch(timelineDateProvider);

  int? read() {
    final wall = resolver.toWallTime(clock.nowUtc(), resolver.currentZoneId());
    return wall.date == date ? wall.minuteOfDay.value : null;
  }

  // 先立刻给一个值，再跟着心跳走。等第一次心跳的话，
  // 那条线在进入视图后最多一分钟内都不出现。
  return () async* {
    yield read();
    yield* tick.map((_) => read());
  }();
});

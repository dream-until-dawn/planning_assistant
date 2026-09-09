/// 时间轴（议程）的数据源（view-specs §1）。
///
/// **视图不自己查库**（§0.2）—— 与列表走同一条流，只是展开策略是
/// [expandForAgenda]（每条任务只留本次与下次）而不是列表那套。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app_providers.dart';
import '../../../../core/time/date_and_minute.dart';
import '../../../../core/time/plan_date.dart';
import '../../../../domain/recurrence/recurrence_engine.dart';
import '../../../../domain/value_objects/task_status.dart';
import '../../shared/application/occurrence_expansion.dart';
import '../../shared/application/task_filter.dart';
import '../../shared/application/task_occurrence.dart';
import '../../shared/application/task_providers.dart';
import '../../shared/application/view_shared_state.dart';
import 'agenda_entries.dart';

/// 共享的聚焦日期（FR-VIEW-06）。
///
/// **它不再筛内容。** 上一版时间轴是单日的，这个 provider 决定「显示哪天」；
/// 现在议程横跨多天，它只决定**进入视图时滚到哪** ——
/// 「日历选中 9/20 → 切时间轴 → 显示 9/20」这条验收由滚动位置兑现，
/// 而不是靠把别的日子藏起来。
final timelineDateProvider = Provider<PlanDate>(
  (ref) => ref.watch(viewSharedStateProvider).focusedDate,
);

/// 议程要显示的行，**已筛选**。
///
/// 筛选放在这里而不是下游：日历那侧的同名 provider 就是「已筛选」的意思，
/// 两个形状一样的名字表示不同的东西，是下一个 bug 的温床。
/// 有一条测试盯着三个视图对同一份筛选的反应（FR-VIEW-05）。
final agendaRowsProvider = Provider<List<TaskOccurrence>>((ref) {
  final filter = ref.watch(viewSharedStateProvider).filter;

  return switch (ref.watch(visibleTasksProvider)) {
    AsyncData(:final value) => applyFilter(
      expandForAgenda(
        tasks: value,
        // 例外还没读出来时先按「没有例外」展开 —— 下一帧到了自动重算。
        // 抛或者卡住的话，首帧会是一屏错误，而它其实只是还没读完。
        overrides: switch (ref.watch(allOverridesProvider)) {
          AsyncData(:final value) => value,
          _ => const [],
        },
        today: ref.watch(todayProvider),
        engine: RecurrenceEngine(ref.watch(timeZoneResolverProvider)),
        // 做完的、跳过的默认不出现（这个视图回答「接下来是什么」），
        // 显式筛它们才现身 —— 那是它们唯一的入口。
        includeSkipped: filter.statuses.contains(TaskStatus.skipped),
        includeCompleted: filter.statuses.contains(TaskStatus.done),
        // 阶段进来是为了各自成行（用户：「阶段是独立的卡片」）。
        stagesByTask: ref.watch(stagesByTaskProvider),
        stageStatesByTask: ref.watch(stageStatesByTaskProvider),
      ),
      filter,
    ),
    _ => const [],
  };
});

/// 摊平成时间轴上的一列：任务一行，它每个排了时间的阶段各一行。
final agendaEntriesProvider = Provider<List<AgendaEntry>>(
  (ref) => agendaEntries(ref.watch(agendaRowsProvider)),
);

/// 整分钟的心跳，供「现在」那条分隔线用。
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

/// 此刻是「哪天几点」，每分钟更新。
///
/// 上一版是 `currentMinuteProvider`，只给当天第几分钟、不是今天就给 null ——
/// 那是「单日刻度尺」的形状。议程横跨多天，「现在」落在**哪一天的**
/// 哪个时刻才是它要回答的问题。
final nowProvider = StreamProvider<DateAndMinute>((ref) {
  final tick = ref.watch(minuteTickProvider);
  final resolver = ref.watch(timeZoneResolverProvider);
  final clock = ref.watch(clockProvider);

  DateAndMinute read() {
    final wall = resolver.toWallTime(clock.nowUtc(), resolver.currentZoneId());
    return DateAndMinute(wall.date, wall.minuteOfDay);
  }

  // 先立刻给一个值，再跟着心跳走。等第一次心跳的话，
  // 那条线在进入视图后最多一分钟内都不出现。
  return () async* {
    yield read();
    yield* tick.map((_) => read());
  }();
});

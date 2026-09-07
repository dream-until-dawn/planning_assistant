/// 重复规则引擎。
///
/// 纯函数：输入输出都是值对象，不碰数据库、不读系统时钟。
/// 时区换算经注入的 `TimeZoneResolver`，因此仍是确定性的。
///
/// 算法五步见 docs/02-domain/recurrence-engine.md §3。
/// **第 4 步最容易漏**：override 可能把窗口外的一次挪进窗口，
/// 只按规则展开当前窗口会让那一次凭空消失。
library;

import 'package:meta/meta.dart';

import '../../core/time/local_wall_time.dart';
import '../../core/time/minute_of_day.dart';
import '../../core/time/plan_date.dart';
import '../../core/time/time_zone_resolver.dart';
import '../entities/occurrence.dart';
import '../entities/occurrence_override.dart';
import '../value_objects/occurrence_key.dart';
import '../value_objects/recurrence.dart';

/// 可见时间窗，按**墙钟日期**闭区间。
@immutable
final class DateRange {
  const DateRange(this.start, this.end);

  final PlanDate start;
  final PlanDate end;

  bool contains(PlanDate d) => !d.isBefore(start) && !d.isAfter(end);

  @override
  String toString() => '[$start..$end]';
}

/// 展开一个任务所需的全部输入。
@immutable
final class RecurrenceContext {
  const RecurrenceContext({
    required this.taskId,
    required this.dtStart,
    required this.isAllDay,
    this.recurrence,
    this.durationMinutes,
  });

  final String taskId;

  /// 首次发生的墙钟，等价于 iCalendar 的 `DTSTART`。
  final LocalWallTime dtStart;

  final bool isAllDay;

  /// null 表示不重复 —— 只有 [dtStart] 这一次。
  final Recurrence? recurrence;

  /// 时长；null 表示没有明确结束。
  final int? durationMinutes;

  String get timeZoneId => dtStart.timeZoneId;
}

/// 展开时用到的上限，防止畸形规则把内存吃光。
const int _maxInstancesPerExpansion = 20000;

final class RecurrenceEngine {
  const RecurrenceEngine(this._tz);

  final TimeZoneResolver _tz;

  /// 在 [window] 内展开 [context] 的全部发生实例，并应用 [overrides]。
  ///
  /// [overrides] 应包含**两类**：原始时刻落在窗口内的，以及原始时刻在窗口外
  /// 但被挪进了窗口的。调用方（Repository）负责按这两个条件查询；
  /// 引擎这一侧只负责正确合并，不做 IO。
  List<Occurrence> expand({
    required RecurrenceContext context,
    required DateRange window,
    List<OccurrenceOverride> overrides = const [],
  }) {
    final byKey = <OccurrenceKey, OccurrenceOverride>{
      for (final o in overrides)
        if (o.taskId == context.taskId) o.key: o,
    };

    // ── 步骤 1：在墙钟域展开原始发生时刻 ──────────────────────────
    final rawStarts = _rawStarts(context, window);

    // ── 步骤 2 & 3：算 key、应用 override ────────────────────────
    final result = <OccurrenceKey, Occurrence>{};
    final consumed = <OccurrenceKey>{};

    for (final raw in rawStarts) {
      final key = OccurrenceKey.fromWallTime(raw, isAllDay: context.isAllDay);
      final override = byKey[key];
      if (override != null) {
        consumed.add(key);
        if (override.isSkip) continue;
      }
      final occ = _materialize(context, key, raw, override);
      // 被挪出窗口的实例必须消失，不能在原位留残影（R-23）。
      if (window.contains(occ.start.date)) {
        result[key] = occ;
      }
    }

    // ── 步骤 4：补齐被 modify 挪进窗口的实例 ──────────────────────
    //
    // 用户把 10/5 那次挪到了 9/8。展开 9 月的规则时不会产生 10/5，
    // 于是这条被挪进来的实例会凭空消失。这里把它们补回来。
    for (final o in byKey.values) {
      if (consumed.contains(o.key) || o.isSkip || !o.movesOccurrence) continue;
      final movedDate = o.planDateOverride ?? o.key.date;
      if (!window.contains(movedDate)) continue;
      // 只有当 key 确实是该规则的一次真实发生时才补 ——
      // 否则一条脏数据就能凭空造出一个实例。
      if (!_isGenuineOccurrence(context, o.key)) continue;
      final raw = _wallOf(context, o.key);
      result[o.key] = _materialize(context, o.key, raw, o);
    }

    // ── 步骤 5：排序返回 ────────────────────────────────────────
    final list = result.values.toList()
      ..sort((a, b) => a.start.compareToSameZone(b.start));
    return list;
  }

  /// 步骤 1：墙钟域展开。
  List<LocalWallTime> _rawStarts(RecurrenceContext c, DateRange window) {
    final zone = c.timeZoneId;
    if (c.recurrence == null) {
      // 不重复：只有 DTSTART 这一次。
      return window.contains(c.dtStart.date) ? [c.dtStart] : const [];
    }

    var rule = c.recurrence!.rule;

    // `UNTIL` 在存储中是**真 UTC**，而展开在墙钟域进行 ——
    // 必须先换算，否则边界会静默错一次（recurrence-engine §2.2）。
    final untilUtc = rule.until;
    if (untilUtc != null) {
      rule = rule.copyWith(until: _tz.untilForExpansion(untilUtc, zone));
    }

    // 窗口右端多留一天：跨天任务的开始可能在窗口前一天。
    final windowEndExclusive = window.end.addDays(1).toFakeUtc();

    final out = <LocalWallTime>[];
    for (final fake in rule.getInstances(start: c.dtStart.toFakeUtc())) {
      if (!fake.isBefore(windowEndExclusive)) break;
      if (out.length >= _maxInstancesPerExpansion) {
        throw StateError(
          '规则 ${c.recurrence} 在 $window 内展开超过 $_maxInstancesPerExpansion 次，'
          '疑似畸形规则',
        );
      }
      out.add(LocalWallTime.fromFakeUtc(fake, zone));
    }
    return out;
  }

  /// key 是否确实是该规则的一次真实发生。
  bool _isGenuineOccurrence(RecurrenceContext c, OccurrenceKey key) {
    if (c.recurrence == null) {
      return OccurrenceKey.fromWallTime(c.dtStart, isAllDay: c.isAllDay) == key;
    }
    var rule = c.recurrence!.rule;
    final untilUtc = rule.until;
    if (untilUtc != null) {
      rule = rule.copyWith(
        until: _tz.untilForExpansion(untilUtc, c.timeZoneId),
      );
    }
    final target = _wallOf(c, key).toFakeUtc();
    // 只需确认目标时刻是否出现在序列中；取到它或越过它即可停。
    for (final fake in rule.getInstances(start: c.dtStart.toFakeUtc())) {
      if (fake.isAtSameMomentAs(target)) return true;
      if (fake.isAfter(target)) return false;
    }
    return false;
  }

  LocalWallTime _wallOf(RecurrenceContext c, OccurrenceKey key) =>
      LocalWallTime(
        date: key.date,
        minuteOfDay: key.minuteOfDay ?? c.dtStart.minuteOfDay,
        timeZoneId: c.timeZoneId,
      );

  /// 步骤 2 的产物 + 步骤 3 的覆盖。
  Occurrence _materialize(
    RecurrenceContext c,
    OccurrenceKey key,
    LocalWallTime rawStart,
    OccurrenceOverride? o,
  ) {
    var start = rawStart;
    if (o != null && o.movesOccurrence) {
      start = LocalWallTime(
        date: o.planDateOverride ?? rawStart.date,
        minuteOfDay: o.startMinuteOverride ?? rawStart.minuteOfDay,
        timeZoneId: c.timeZoneId,
      );
    }

    // **DST 解析必须在这里做，不能留给调用方**（§4.1）。
    //
    // 展开是在墙钟域进行的，rrule 不知道时区 —— 春季跳表日会产出一个
    // 当天根本不存在的墙钟（如 America/New_York 的 02:30）。
    // 不在这里顺延的话，日历会显示一个不存在的时刻，
    // 而排通知时又会被换算到别处，两边对不上。
    //
    // 注意顺序：先应用 override（用户可能把这次挪走了），再解析 DST，
    // 因为挪过去的新时刻同样可能落进空隙。
    final resolved = _tz.resolve(start);
    final dstAdjusted = resolved.dstAdjusted;
    start = resolved.effectiveWallTime;

    LocalWallTime? end;
    if (o?.endDateOverride != null || o?.endMinuteOverride != null) {
      end = LocalWallTime(
        date: o!.endDateOverride ?? start.date,
        minuteOfDay: o.endMinuteOverride ?? start.minuteOfDay,
        timeZoneId: c.timeZoneId,
      );
    } else if (c.durationMinutes != null && !c.isAllDay) {
      end = start.addMinutes(c.durationMinutes!);
    }

    return Occurrence(
      taskId: c.taskId,
      key: key,
      start: start,
      end: end,
      isAllDay: c.isAllDay,
      status: o?.status ?? OccurrenceStatus.pending,
      titleOverride: o?.titleOverride,
      noteOverride: o?.noteOverride,
      isModified: o != null,
      dstAdjusted: dstAdjusted,
    );
  }

  /// 把「到某日止」翻译成可写入 `UNTIL` 的真 UTC。
  ///
  /// **必须取该日的日终**（recurrence-engine §6.1c）。若把结束日期当成该日
  /// `00:00`，所有非零点开始的任务都会少一次 —— 而那是绝大多数任务。
  ///
  /// 末尾补 59 秒的理由：本项目的计划时间是**分钟粒度**（`MinuteOfDay`），
  /// 因此 `23:59:00` 对自家数据已经足够。但导入的 `.ics` 可以带秒，
  /// 若停在 `23:59:00`，外部那条 `23:59:30` 的事件会被悄悄排除。
  /// 补到 `23:59:59` 让「到某日止」对秒级数据同样成立。
  DateTime untilForEndDate(PlanDate endDate, String zoneId) => _tz
      .untilForStorage(
        LocalWallTime(
          date: endDate,
          minuteOfDay: MinuteOfDay.endOfDay,
          timeZoneId: zoneId,
        ),
      )
      .add(const Duration(seconds: 59));

  /// 构造带「到某日止」的规则串。UI 的「到某日止」应经由它，而不是自己拼。
  Recurrence withEndDate(Recurrence base, PlanDate endDate, String zoneId) {
    final until = untilForEndDate(endDate, zoneId);
    return Recurrence.parse(
      // RFC 5545 §3.3.10：UNTIL 与 COUNT 不得同时出现，
      // 因此设 UNTIL 时必须显式清掉 COUNT。
      encodeRrule(base.rule.copyWith(until: until, clearCount: true)),
    );
  }
}

/// 墙钟 ⇄ 绝对时刻的换算。**项目内唯一允许做时区换算的地方**（cross-cutting §1.2）。
library;

import 'package:meta/meta.dart';
import 'package:timezone/timezone.dart' as tz;

import 'local_wall_time.dart';
import 'minute_of_day.dart';
import 'plan_date.dart';

/// 换算结果。
///
/// 带 [dstAdjusted] 是因为 DST 跳表日的结果**与用户输入的墙钟不同** ——
/// 那一天用户设的 02:30 根本不存在。UI 需要知道这件事才能解释，
/// 静默改掉时刻而不告诉用户，是日历应用最招人恨的行为之一。
@immutable
final class InstantResolution {
  const InstantResolution({
    required this.instant,
    required this.effectiveWallTime,
    required this.dstAdjusted,
  });

  /// 绝对时刻，恒为 UTC。
  final DateTime instant;

  /// 实际生效的墙钟。无 DST 影响时与输入相同。
  final LocalWallTime effectiveWallTime;

  /// 输入的墙钟在该时区当天不存在，已被顺延。
  final bool dstAdjusted;

  @override
  String toString() =>
      'InstantResolution($instant, wall=$effectiveWallTime, '
      'dstAdjusted=$dstAdjusted)';
}

abstract interface class TimeZoneResolver {
  String currentZoneId();

  /// 墙钟 → 绝对时刻。
  InstantResolution resolve(LocalWallTime wall);

  /// [resolve] 的简写，丢弃 DST 元信息。
  DateTime toInstant(LocalWallTime wall);

  /// 绝对时刻 → 指定时区的墙钟。
  LocalWallTime toWallTime(DateTime instant, String zoneId);

  /// RRULE `UNTIL` 专用：墙钟结束点 → 可写入规则串的**真 UTC**。
  ///
  /// RFC 5545 §3.3.10 要求 DTSTART 带 TZID 时 UNTIL 必须是真 UTC，
  /// 而展开在墙钟域进行。这一对函数是项目内唯一允许做该换算的地方，
  /// 详见 docs/02-domain/recurrence-engine.md §2.2。
  DateTime untilForStorage(LocalWallTime wallEnd);

  /// 存储中的真 UTC `UNTIL` → 可喂给 rrule 的**假 UTC 墙钟值**。
  DateTime untilForExpansion(DateTime utcUntil, String zoneId);
}

/// 基于 `timezone` 包（IANA tz 数据库）的实现。
///
/// 使用前必须先调用 `initializeTimeZones()`（由 bootstrap 负责）。
final class TzTimeZoneResolver implements TimeZoneResolver {
  const TzTimeZoneResolver({this.fixedCurrentZoneId});

  /// 固定当前时区，供测试注入。为 null 时读系统时区。
  final String? fixedCurrentZoneId;

  @override
  String currentZoneId() => fixedCurrentZoneId ?? tz.local.name;

  @override
  DateTime toInstant(LocalWallTime wall) => resolve(wall).instant;

  /// 按「候选偏移 + 跳变点」换算，覆盖三种情形：
  ///
  /// | 情形 | 要的结果 |
  /// |---|---|
  /// | 正常时刻 | 精确匹配 |
  /// | 春季跳表（墙钟不存在） | 该时段后**第一个合法时刻** |
  /// | 秋季回拨（墙钟重复） | **较早**的那个绝对时刻 |
  ///
  /// **为什么不直接用 `tz.TZDateTime(loc, y, m, d, h, min)`**：实测它对不存在的
  /// 02:30 给出 **03:30**（按偏移量平移），而 recurrence-engine §4.1 规定的是
  /// **03:00**（该时段后第一个合法时刻）。按 §7 的规矩，行为与需求不符时
  /// 在我们这一侧做显式修正，而不是改需求去迁就库。
  ///
  /// **为什么不在绝对时刻上二分「当地时间 >= 目标」**：初版这么写过，错的 ——
  /// **当地墙钟在 UTC 上不是单调的**。秋季回拨时 01:00–01:59 会出现两次，
  /// 二分的单调性前提不成立，结果会落到较晚那个。春季跳表恰好是单调的，
  /// 所以那组用例过了、这组没过。
  @override
  InstantResolution resolve(LocalWallTime wall) {
    final loc = tz.getLocation(wall.timeZoneId);
    final target = wall.toFakeUtc();

    DateTime localWallAt(int epochMs) {
      final l = tz.TZDateTime.fromMillisecondsSinceEpoch(loc, epochMs);
      return DateTime.utc(l.year, l.month, l.day, l.hour, l.minute);
    }

    int offsetMsAt(int epochMs) => tz.TZDateTime.fromMillisecondsSinceEpoch(
      loc,
      epochMs,
    ).timeZoneOffset.inMilliseconds;

    // 窗口取目标 ±2 天：任何两次 DST 跳变都相隔数月，窗口内至多一次跳变。
    final targetMs = target.millisecondsSinceEpoch;
    const dayMs = Duration.millisecondsPerDay;
    final lo = targetMs - 2 * dayMs;
    final hi = targetMs + 2 * dayMs;

    final offsetLo = offsetMsAt(lo);
    final offsetHi = offsetMsAt(hi);

    /// `candidate` 若确实映射回 [target] 则返回它，否则 null。
    int? candidateFor(int offsetMs) {
      final c = targetMs - offsetMs;
      return localWallAt(c) == target ? c : null;
    }

    if (offsetLo == offsetHi) {
      // 窗口内无跳变：唯一解。
      final c = candidateFor(offsetLo);
      if (c == null) {
        throw StateError('时区 ${wall.timeZoneId} 在 $wall 处换算失败（无跳变却无解）');
      }
      return _resolutionAt(c, wall);
    }

    // 有跳变：二分找**偏移发生变化**的那一刻。偏移是分段常量，这一步是单调的。
    var a = lo;
    var b = hi;
    while (b - a > Duration.millisecondsPerMinute) {
      final mid = a + (b - a) ~/ 2;
      if (offsetMsAt(mid) == offsetLo) {
        a = mid;
      } else {
        b = mid;
      }
    }
    final transitionMs = b; // 跳变后的第一刻

    final beforeCandidate = candidateFor(offsetLo);
    final afterCandidate = candidateFor(offsetHi);
    final valid = <int>[
      if (beforeCandidate != null && beforeCandidate < transitionMs)
        beforeCandidate,
      if (afterCandidate != null && afterCandidate >= transitionMs)
        afterCandidate,
    ];

    if (valid.isEmpty) {
      // 墙钟不存在（春季跳表落进空隙）：取跳变后第一刻，
      // 它的墙钟就是「该时段结束后第一个合法时刻」。
      return _resolutionAt(transitionMs, wall);
    }
    // 墙钟重复时取较早者。
    valid.sort();
    return _resolutionAt(valid.first, wall);
  }

  InstantResolution _resolutionAt(int epochMs, LocalWallTime requested) {
    final instant = DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true);
    final effective = toWallTime(instant, requested.timeZoneId);
    return InstantResolution(
      instant: instant,
      effectiveWallTime: effective,
      dstAdjusted: effective != requested,
    );
  }

  @override
  LocalWallTime toWallTime(DateTime instant, String zoneId) {
    final loc = tz.getLocation(zoneId);
    final local = tz.TZDateTime.from(instant, loc);
    return LocalWallTime(
      date: PlanDate(local.year, local.month, local.day),
      minuteOfDay: MinuteOfDay.of(local.hour, local.minute),
      timeZoneId: zoneId,
    );
  }

  @override
  DateTime untilForStorage(LocalWallTime wallEnd) => toInstant(wallEnd);

  @override
  DateTime untilForExpansion(DateTime utcUntil, String zoneId) =>
      toWallTime(utcUntil, zoneId).toFakeUtc();
}

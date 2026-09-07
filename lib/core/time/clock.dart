/// 时间抽象。
///
/// 依据 docs/01-architecture/cross-cutting.md §1：本项目区分三种时间，
/// 且**禁止在业务代码中直接调用 `DateTime.now()`** ——
/// 那会让时间相关逻辑无法测试，进而让相关测试沦为「永远绿」的摆设。
/// 该禁令由 test/architecture/layer_dependency_test.dart 强制。
library;

/// 绝对时刻的来源。测试中注入固定时钟。
abstract interface class Clock {
  /// 当前瞬时，始终为 UTC。
  DateTime nowUtc();
}

/// 生产实现。**这是全项目唯一允许出现 `DateTime.now()` 的地方**，
/// 因此它位于 core 层而非 domain 层（守卫只扫 domain 与 feature application）。
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// 固定时钟，测试专用。
class FixedClock implements Clock {
  FixedClock(this._now);

  DateTime _now;

  set now(DateTime value) => _now = value.toUtc();

  @override
  DateTime nowUtc() => _now.toUtc();
}

/// 墙钟 ⇄ 绝对时刻的换算。
///
/// 计划时间存「墙钟 + IANA 时区」而非 UTC 时间戳（ADR-0005），
/// 因此换算必须集中在这一个接口后面。
abstract interface class TimeZoneResolver {
  /// 当前系统时区的 IANA 标识，如 `Asia/Shanghai`。
  String currentZoneId();

  /// 墙钟 → 绝对时刻。
  ///
  /// 夏令时的两种边界按 docs/02-domain/recurrence-engine.md §4.1 处理：
  /// 春季跳表时顺延到该时段结束后的第一个合法时刻；秋季回拨时取较早的那个。
  DateTime toInstant(DateTime wallTime, String zoneId);

  /// 绝对时刻 → 墙钟。
  DateTime toWallTime(DateTime instant, String zoneId);

  /// RRULE 的 `UNTIL` 专用：墙钟结束点 → 可写入规则串的真 UTC。
  ///
  /// RFC 5545 §3.3.10 要求 DTSTART 带 TZID 时 UNTIL 必须是真 UTC，
  /// 而展开在墙钟域进行 —— 这一对函数是项目内**唯一**允许做该换算的地方。
  /// 详见 docs/02-domain/recurrence-engine.md §2.2。
  DateTime untilForStorage(DateTime wallEnd, String zoneId);

  /// 存储中的真 UTC `UNTIL` → 可喂给 rrule 的假 UTC 墙钟值。
  DateTime untilForExpansion(DateTime utcUntil, String zoneId);
}

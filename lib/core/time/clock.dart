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

/// 便于把时钟当函数传递（`clock.nowUtc` 可直接作为 `DateTime Function()`）。
///
/// 保留这个别名是因为 DAO 与分发器的构造参数写成函数类型更轻，
/// 但**默认实现仍必须是 [Clock]** —— 直接收裸函数的话，
/// 生产代码里传个 `DateTime.now` 就绕过了整条禁令，且守卫扫不到。
typedef NowFn = DateTime Function();

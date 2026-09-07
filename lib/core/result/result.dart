/// 结果类型。
///
/// 依据 docs/01-architecture/cross-cutting.md §3 的三类错误：
/// - **领域失败**（预期内，如时间非法）→ `Result.failure`，UI 显示可读文案，**不抛异常**
/// - **基础设施失败**（DB 写不进去）→ 抛异常，在 Application 层捕获转 `Result`
/// - **程序缺陷**（不变量被破坏）→ 显式 throw，**绝不用 assert**（release 会剥离）
library;

/// 领域失败：预期之内、可以向用户解释的失败。
class DomainFailure {
  const DomainFailure(this.code, {this.detail});

  /// 稳定的机器可读标识，用于查本地化文案。
  final String code;

  /// 给日志看的细节。**不得包含任务标题等用户内容**（NFR-PRIV-01）。
  final String? detail;

  @override
  String toString() =>
      'DomainFailure($code${detail == null ? '' : ', $detail'})';
}

/// 领域不变量被破坏。这是**程序缺陷**，不是可预期的失败。
///
/// 必须显式抛出而不是用 `assert` —— Dart 的 assert 在 AOT release 构建中
/// 被整条剥离，用它表达的不变量在正式包里等于不存在，
/// 且会让对应测试在 debug 下变绿、在 release 下失去意义。
/// 见 docs/01-architecture/cross-cutting.md §3.1。
class DomainInvariantViolation implements Exception {
  const DomainInvariantViolation(this.message);

  final String message;

  @override
  String toString() => 'DomainInvariantViolation: $message';
}

/// 非法状态迁移。见 docs/02-domain/task-lifecycle.md §2.1。
class IllegalTransitionException implements Exception {
  const IllegalTransitionException(this.from, this.to);

  final String from;
  final String to;

  @override
  String toString() => 'IllegalTransitionException: $from -> $to 不是合法迁移';
}

/// 成功或领域失败。
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(DomainFailure failure) = Failure<T>;

  bool get isSuccess => this is Success<T>;

  /// 成功时取值，失败时返回 [orElse]。
  T valueOr(T orElse) => switch (this) {
    Success<T>(:final value) => value,
    Failure<T>() => orElse,
  };

  R fold<R>(
    R Function(T value) onSuccess,
    R Function(DomainFailure failure) onFailure,
  ) => switch (this) {
    Success<T>(:final value) => onSuccess(value),
    Failure<T>(:final failure) => onFailure(failure),
  };
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.failure);
  final DomainFailure failure;
}

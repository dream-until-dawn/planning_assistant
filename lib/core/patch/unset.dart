/// 「不改这个字段」的哨兵。
///
/// ## 为什么需要它
///
/// `copyWith(note: null)` 有两种可能的意思：「把备注清空」和「别动备注」。
/// 用 `null` 当默认值时两者无法区分，于是「清空备注」这个功能实现不出来 ——
/// 而这类缺陷在测试里极难发现，因为两种解释中总有一种碰巧是调用方想要的。
///
/// ## 为什么是一个专门的类型，而不是 `const Object()`
///
/// 一开始 `Task` 与 `UpdateTaskFieldsCommand` 各自写了
/// `static const Object _unset = Object();`。**它们是同一个实例** ——
/// Dart 会把 `const Object()` 规范化（canonicalize），两处 `const Object()`
/// 指向同一对象。于是跨类传递哨兵「碰巧能用」。
///
/// 碰巧能用比不能用更危险：把其中一处改成别的 const 值，行为会静默改变，
/// 而且没有任何一条测试会红。所以改成专门的 [Unset] 类型 ——
/// 别处随手写的 `const Object()` 不会与它 identical，
/// 需要共享哨兵的地方必须显式 import 同一个 [unset]。
library;

/// 哨兵类型。除了 [unset] 之外不该有第二个实例。
final class Unset {
  const Unset();

  @override
  String toString() => '<不改>';
}

/// 唯一的哨兵实例。
const Unset unset = Unset();

/// 取补丁值：是哨兵就保留 [current]，否则用给定值（含显式 `null`）。
///
/// 集中成一个函数，省得每个字段写一遍 `x == unset ? this.x : x as T?`
/// —— 那种重复里漏一个 `?` 或写错字段名都不会被编译器发现。
T? patch<T>(Object? candidate, T? current) =>
    identical(candidate, unset) ? current : candidate as T?;

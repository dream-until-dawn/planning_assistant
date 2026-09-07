/// 标识符生成。
///
/// 依据 docs/01-architecture/cross-cutting.md §2：
/// 全部实体主键用 **UUID v7**（时间有序，索引友好，且云端合并时不会主键冲突）。
/// **禁止自增整数主键** —— 多端同步时必然冲突。
library;

import 'package:uuid/uuid.dart';

/// ID 来源。接口化以便测试注入确定性序列。
abstract interface class IdGenerator {
  /// 生成一个新的实体主键。
  String newId();
}

/// 生产实现：UUID v7。
///
/// `uuid 4.6.0` 提供 `v7()`（已读包源码确认，见 lib/uuid.dart:745）。
/// v7 的前 48 bit 是毫秒时间戳，因此字典序 ≈ 生成时序，对 SQLite 主键索引友好。
class UuidV7Generator implements IdGenerator {
  const UuidV7Generator(this._uuid);

  final Uuid _uuid;

  @override
  String newId() => _uuid.v7();
}

/// 确定性序列，测试专用。
class SequentialIdGenerator implements IdGenerator {
  SequentialIdGenerator({this.prefix = 'id'});

  final String prefix;
  int _n = 0;

  @override
  String newId() => '$prefix-${_n++}';
}

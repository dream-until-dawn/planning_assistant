/// 同步信封（data-model §5）。
///
/// **V1 就带上，不等 V3**。这是 ADR-0006 的核心决定：信封字段一旦缺席，
/// 后补时既没有历史 `createdAt`，也无从判断哪条更新 —— 存量数据只能整体丢弃
/// 或用导入时刻伪造，两条路都不可接受。V1 每行多 6 列的成本远低于此。
library;

import 'package:drift/drift.dart';

/// 每张**可同步**的表都必须 `with SyncEnvelope`。
///
/// 不带信封的表只有三张，且都有明确理由（data-model §5）：
/// `scheduled_notifications`（本地排期簿记）、`change_log`（信封的来源本身）、
/// 以及 `settings` 里 `scope='device'` 的行（用列而非表区分）。
mixin SyncEnvelope on Table {
  /// 创建时刻，Instant ms。**创建后不再变**。
  IntColumn get createdAt => integer()();

  /// 最后一次本地写入时刻，Instant ms。
  IntColumn get updatedAt => integer()();

  /// 墓碑标记：非空即已删除。
  ///
  /// **物理删除会让「删除」这件事无法同步** —— 对端只会看到「这条还在」。
  /// 所有查询默认带 `deletedAt IS NULL`，由 DAO 基类统一加，见 `BaseDao`。
  IntColumn get deletedAt => integer().nullable()();

  /// 本地修订号，每次写入 +1。与 [updatedAt]、[lastWriterId] 一起支撑
  /// V3 的 LWW 与冲突检测（future-sync.md）。
  IntColumn get revision => integer().withDefault(const Constant(1))();

  /// 写入方设备 ID。
  TextColumn get lastWriterId => text()();

  /// 服务端版本标记。V1 恒为 NULL。
  TextColumn get remoteVersion => text().nullable()();
}

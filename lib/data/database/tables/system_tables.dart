/// 配置、排期簿记与变更日志（data-model §3.9–3.11）。
library;

import 'package:drift/drift.dart';

import 'sync_envelope.dart';

/// 配置项（§3.10）。
///
/// 值统一用 JSON 编码，类型由 settings-spec 的注册表声明 ——
/// 每加一个配置项就加一列的话，配置中心的每次扩展都成了一次 schema 迁移。
@DataClassName('SettingRow')
class Settings extends Table with SyncEnvelope {
  TextColumn get key => text()();
  TextColumn get valueJson => text()();

  /// `global`（参与同步）| `device`（不同步）。
  ///
  /// 用列而不是拆两张表：注册表按 key 查询时不必先知道 scope。
  TextColumn get scope => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// 通知排期簿记（§3.9）。**本地表：不同步、不导出，因此不带信封。**
///
/// 系统通知 ID 是设备本地的，同步到别的设备毫无意义且会造成误取消。
@DataClassName('ScheduledNotificationRow')
class ScheduledNotifications extends Table {
  /// 传给系统的 ID。
  IntColumn get osNotificationId => integer()();

  TextColumn get reminderId => text()();
  TextColumn get taskId => text()();
  TextColumn get occurrenceKey => text()();

  /// UTC ms。
  IntColumn get fireAtInstant => integer()();

  /// `scheduled` | `fired` | `cancelled`。
  TextColumn get state => text()();

  @override
  Set<Column<Object>> get primaryKey => {osNotificationId};
}

/// 变更日志 / outbox（§3.11）。**信封的来源本身，因此自己不带信封。**
///
/// V1 就写这张表。它在 V1 内部也有价值：**回放一致性测试**
/// （清库后按 seq 回放应还原等价状态）是发现「写操作绕过命令管道」
/// 最有效的手段 —— 绕过的写不会留下 change_log 行，回放后状态就对不上。
@DataClassName('ChangeLogRow')
class ChangeLog extends Table {
  /// 本地单调序号。回放顺序即写入顺序。
  IntColumn get seq => integer().autoIncrement()();

  /// `task` / `stage` / …
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();

  /// `upsert` | `delete`。
  TextColumn get op => text()();

  /// upsert 时为该行的完整 JSON。
  TextColumn get payloadJson => text().nullable()();

  /// Instant ms。
  IntColumn get occurredAt => integer()();

  TextColumn get deviceId => text()();

  /// V3 用；V1 恒为 NULL。
  IntColumn get syncedAt => integer().nullable()();
}

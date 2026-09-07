/// 任务及其从属结构的表定义（data-model §3.1–3.5）。
///
/// **列名与文档逐字对应**，导出格式直接用列名（§6），偏离会同时破坏
/// 导出契约与将来服务端的解析。
library;

import 'package:drift/drift.dart';

import 'sync_envelope.dart';
import 'taxonomy_tables.dart';

/// 任务主表（§3.1）。
@DataClassName('TaskRow')
class Tasks extends Table with SyncEnvelope {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get note => text().nullable()();

  /// `single` | `staged`。**不用 Drift 的 enum 列**：
  /// `intEnum` 把序号写进库，将来枚举重排会静默改写全部历史数据；
  /// `textEnum` 虽存名字，但重命名同样破坏存量。存字符串并在 mapper 里
  /// 显式转换，未知值可被发现而不是被当成 0。
  TextColumn get kind => text()();

  /// 删分类不删任务（FR-CFG-03）。
  TextColumn get categoryId => text().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// 0 无 / 1 低 / 2 普通 / 3 高 / 4 紧急。
  IntColumn get priority => integer().withDefault(const Constant(2))();

  /// `pending`|`inProgress`|`done`|`skipped`。
  ///
  /// **重复任务此列恒为 `pending`**，真实状态在 `occurrence_overrides`（§4.3）。
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// 归档时快照的 [status]，取消归档时还原；非归档态恒为 NULL。
  TextColumn get statusBeforeArchive => text().nullable()();

  BoolColumn get isAllDay => boolean().withDefault(const Constant(false))();

  /// `yyyy-MM-dd`。重复任务即 DTSTART 的日期。
  TextColumn get planDate => text().nullable()();

  /// 0..1439，`isAllDay=1` 时为 NULL。
  IntColumn get startMinute => integer().nullable()();
  TextColumn get endDate => text().nullable()();
  IntColumn get endMinute => integer().nullable()();

  /// IANA 时区，创建时的。**存墙钟 + 时区而非 UTC 时间戳**，理由见 ADR-0005。
  TextColumn get timeZoneId => text()();

  /// RFC 5545 `RRULE:` 串。NULL = 不重复。
  ///
  /// **必须是 `encodeRrule()` 产出的规范形**（含 UNTIL 时必带 `Z`），
  /// 不得直接存外部原串 —— recurrence-engine §2.3。
  TextColumn get recurrenceRule => text().nullable()();

  /// JSON 数组。**V1 不参与展开**，仅作导入 .ics 的原始留档（§4.5）。
  TextColumn get recurrenceExDates => text().nullable()();

  /// 「本次及以后」分裂的溯源（§4.4）。
  TextColumn get splitFromTaskId => text().nullable()();

  IntColumn get colorArgb => integer().nullable()();
  TextColumn get icon => text().nullable()();

  /// 手动排序。用浮点便于在两条之间插入而不重排整表。
  RealColumn get sortOrder => real().withDefault(const Constant(0))();

  IntColumn get completedAt => integer().nullable()();

  /// 非空即已归档。**归档不是 `status` 的取值** —— 否则重复任务
  /// （status 恒为 pending）将永远无法归档。task-lifecycle §1.1。
  IntColumn get archivedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 阶段（§3.2）。时间用**相对偏移**，理由见 §4.1。
@DataClassName('StageRow')
class Stages extends Table with SyncEnvelope {
  TextColumn get id => text()();
  TextColumn get taskId =>
      text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();

  /// 从 0 起连续。
  IntColumn get orderIndex => integer()();

  /// 相对任务（或该次发生）开始的分钟偏移。
  IntColumn get startOffsetMinutes => integer().nullable()();
  IntColumn get durationMinutes => integer().nullable()();
  IntColumn get colorArgb => integer().nullable()();

  /// 仅非重复任务使用；重复任务的阶段状态在 `stage_occurrence_states`。
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get completedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 清单项（§3.3）。
@DataClassName('ChecklistItemRow')
class ChecklistItems extends Table with SyncEnvelope {
  TextColumn get id => text()();
  TextColumn get taskId =>
      text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  IntColumn get orderIndex => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 单次发生的例外（§3.4），相当于 iCalendar 的 `RECURRENCE-ID` + 修改。
@DataClassName('OccurrenceOverrideRow')
class OccurrenceOverrides extends Table with SyncEnvelope {
  TextColumn get id => text()();
  TextColumn get taskId =>
      text().references(Tasks, #id, onDelete: KeyAction.cascade)();

  /// **原始**发生时刻的墙钟串（未被修改前的），唯一标识是哪一次。
  /// 格式见 §4.6：全天任务是纯日期，定时任务带 `THH:mm`。
  TextColumn get occurrenceKey => text()();

  /// `skip` | `modify`。
  TextColumn get action => text()();

  TextColumn get status => text().nullable()();
  IntColumn get completedAt => integer().nullable()();

  /// NULL = 继承任务的对应字段。
  TextColumn get titleOverride => text().nullable()();
  TextColumn get noteOverride => text().nullable()();
  TextColumn get planDateOverride => text().nullable()();
  IntColumn get startMinuteOverride => integer().nullable()();
  TextColumn get endDateOverride => text().nullable()();
  IntColumn get endMinuteOverride => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 重复的阶段事项，每次发生的每个阶段有独立状态（§3.5，FR-TASK-07）。
///
/// **只有被交互过的 (阶段, 发生) 才落行** —— 未触碰的视为 `pending`，不占存储。
@DataClassName('StageOccurrenceStateRow')
class StageOccurrenceStates extends Table with SyncEnvelope {
  TextColumn get id => text()();
  TextColumn get taskId =>
      text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get stageId =>
      text().references(Stages, #id, onDelete: KeyAction.cascade)();
  TextColumn get occurrenceKey => text()();
  TextColumn get status => text()();
  IntColumn get completedAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 提醒（§3.8）。
@DataClassName('ReminderRow')
class Reminders extends Table with SyncEnvelope {
  TextColumn get id => text()();
  TextColumn get taskId =>
      text().references(Tasks, #id, onDelete: KeyAction.cascade)();

  /// `relativeToStart` | `relativeToEnd` | `absolute`。
  TextColumn get kind => text()();

  /// 负数 = 提前；[kind] 为相对时必填。
  IntColumn get offsetMinutes => integer().nullable()();

  /// `kind=absolute` 时的墙钟日期。
  TextColumn get absoluteDate => text().nullable()();
  IntColumn get absoluteMinute => integer().nullable()();

  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 某一次发生里、某个阶段的完成状态（FR-TASK-07、data-model §3.6）。
///
/// ## 为什么阶段状态不能只存在 `Stage` 上
///
/// 一条「每周三·健身」拆成热身 / 主训 / 拉伸三个阶段。
/// 阶段状态若只有 `Stage.status` 一份，这周勾掉「热身」，
/// **每一周的热身都成了已完成** —— 下周打开还是三分之一，
/// 而他这周确实只做了热身。
///
/// 与 `OccurrenceOverride` 是同一族但**不是同一张表**：
/// 那张记的是「这一次整体怎么了」（跳过 / 挪走 / 改标题），
/// 这张记的是「这一次里的第 N 步做完没有」。
/// 塞进一张的话，override 会因为勾一个阶段而被创建出来，
/// 而 override 的存在本身是有语义的（引擎要据它补齐被挪进窗口的实例）。
library;

import 'package:meta/meta.dart';

import '../value_objects/occurrence_key.dart';
import '../value_objects/task_status.dart';

@immutable
final class StageOccurrenceState {
  const StageOccurrenceState({
    required this.id,
    required this.taskId,
    required this.stageId,
    required this.occurrenceKey,
    required this.status,
    this.completedAt,
    this.deletedAt,
  });

  final String id;
  final String taskId;
  final String stageId;

  /// **原始**发生时刻的标识 —— 与 override 同一个约定（§4.2）：
  /// 这一次即使被挪到别的日期，它仍然是同一次。
  final OccurrenceKey occurrenceKey;

  final TaskStatus status;
  final DateTime? completedAt;
  final DateTime? deletedAt;

  /// 一条状态在库里的身份。
  ///
  /// **由 (stageId, occurrenceKey) 派生，不用随机 id**：
  /// 同一个阶段的同一次只该有一行。随机 id 的话，
  /// 连点两下会攒出两行互相矛盾的状态，而读的时候谁在前谁说了算。
  /// 与派生行 id `taskId#occurrenceKey` 是同一个做法。
  static String idFor(String stageId, OccurrenceKey key) =>
      '$stageId#${key.value}';

  StageOccurrenceState copyWith({
    TaskStatus? status,
    DateTime? completedAt,
    DateTime? deletedAt,
  }) => StageOccurrenceState(
    id: id,
    taskId: taskId,
    stageId: stageId,
    occurrenceKey: occurrenceKey,
    status: status ?? this.status,
    completedAt: completedAt ?? this.completedAt,
    deletedAt: deletedAt ?? this.deletedAt,
  );
}

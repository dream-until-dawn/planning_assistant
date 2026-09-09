/// 清单项（FR-TASK-09、data-model §3.3）。
///
/// ## 与阶段的分工
///
/// 术语表把它定义成「任务详情内的**轻量**勾选项，**不参与时间排布**」，
/// 而阶段是「有独立时间与状态的子区段」。差别不是大小，是**有没有时间**：
///
/// | | 有时间 | 上视图 | 决定父任务进度 | 每次发生各记一份 |
/// |---|---|---|---|---|
/// | [Stage] | 相对偏移 + 时长 | 甘特分段、时间轴撑长跨度 | 是（FR-TASK-02） | 是（FR-TASK-07） |
/// | 清单项 | **没有** | **不上** | 否 | 否 —— 见下 |
///
/// ## 清单是整条任务共用的，不按发生分
///
/// 这条不对称是**照着表设计的**：`stage_occurrence_states` 有，
/// 而清单没有对应的表。阶段那份是必要的（一条每周三的健身，
/// 这周的热身与下周的热身是两件事）；清单是「买什么」这一类
/// 附在任务身上的备忘，不随每次发生重置。
///
/// **代价要说清**：重复任务的清单勾上了就一直勾着。
/// 将来若要按发生分，那是加一张表 + 一条判据的事，
/// 别在这里偷偷塞一个 occurrenceKey —— 那会让「轻量」这个定位失效。
library;

import 'package:meta/meta.dart';

@immutable
final class ChecklistItem {
  const ChecklistItem({
    required this.id,
    required this.taskId,
    required this.title,
    required this.orderIndex,
    this.isDone = false,
    this.deletedAt,
  });

  final String id;
  final String taskId;
  final String title;

  /// 显示顺序。与阶段一样要求**连续从 0 开始**（由命令层校验）。
  final int orderIndex;

  final bool isDone;
  final DateTime? deletedAt;

  ChecklistItem copyWith({
    String? title,
    int? orderIndex,
    bool? isDone,
    DateTime? deletedAt,
  }) => ChecklistItem(
    id: id,
    taskId: taskId,
    title: title ?? this.title,
    orderIndex: orderIndex ?? this.orderIndex,
    isDone: isDone ?? this.isDone,
    deletedAt: deletedAt ?? this.deletedAt,
  );
}

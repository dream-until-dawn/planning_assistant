/// 今日概览 —— **V2 桌面小组件与常驻通知的数据源**（overview §6）。
///
/// 它在 V1 就必须存在且**不依赖任何 Widget**：V2 的小组件跑在后台 isolate，
/// 甚至跑在另一个进程里，那里没有 Flutter binding。等到 V2 再来抽离，
/// 会发现查询早已长在 Provider 与 BuildContext 上，拆不动。
///
/// 验收方式写在 overview §6：**一个纯 Dart 测试，不启动 Flutter binding
/// 就能取到今日概览**。见 `test/domain/today_digest_test.dart`。
library;

import '../entities/task.dart';
import '../policies/task_lifecycle.dart';
import '../value_objects/task_status.dart';

/// 概览里的一条。
///
/// 刻意**不用 [Task] 实体**：概览要跨进程传给小组件，
/// 带上整个实体意味着把所有字段（含同步信封）都序列化过去，
/// 而小组件只需要这四样。
final class DigestItem {
  const DigestItem({
    required this.taskId,
    required this.title,
    required this.status,
    this.startMinute,
    this.stageProgress,
  });

  final String taskId;
  final String title;
  final TaskStatus status;

  /// 0..1439；全天任务为 null。
  final int? startMinute;

  /// 阶段事项的进度 `(已完成, 总数)`；非阶段事项为 null。
  final (int done, int total)? stageProgress;

  bool get isAllDay => startMinute == null;
  bool get isDone => status == TaskStatus.done;
}

/// 今日概览。
final class TodayDigest {
  const TodayDigest({
    required this.date,
    required this.items,
    required this.totalCount,
    required this.doneCount,
  });

  /// 概览针对的日期（`yyyy-MM-dd`）。
  ///
  /// 带上它是因为小组件可能显示的是**昨天生成**的概览 ——
  /// 不带日期的话，用户看到的是过期数据却毫不知情。
  final String date;

  final List<DigestItem> items;
  final int totalCount;
  final int doneCount;

  int get remainingCount => totalCount - doneCount;
  bool get isEmpty => totalCount == 0;
  bool get isAllDone => totalCount > 0 && doneCount == totalCount;
}

/// 从任务列表算出今日概览。**纯函数**。
///
/// 传入的是已经筛好的任务与阶段进度 —— 取数在数据层，这里只做整形。
/// 把查询也放进来的话，这个函数就没法在没有数据库的环境里测了。
TodayDigest buildTodayDigest({
  required String date,
  required List<Task> tasks,
  Map<String, (int done, int total)> stageProgress = const {},
}) {
  // 只算活跃任务：归档的与回收站的不该出现在今日概览里。
  final visible = tasks.where(TaskVisibility.isActive).toList();

  final items = [
    for (final t in visible)
      DigestItem(
        taskId: t.id,
        title: t.title,
        status: t.status,
        startMinute: t.isAllDay ? null : t.startMinute?.value,
        stageProgress: stageProgress[t.id],
      ),
  ]..sort(_byTimeThenTitle);

  return TodayDigest(
    date: date,
    items: items,
    totalCount: items.length,
    doneCount: items.where((i) => i.isDone).length,
  );
}

/// 全天在前，其余按时刻升序；同刻按标题。
///
/// 顺序必须是确定的：不确定的话小组件每次刷新条目都会跳，
/// 而用户会以为数据变了。
int _byTimeThenTitle(DigestItem a, DigestItem b) {
  if (a.isAllDay != b.isAllDay) return a.isAllDay ? -1 : 1;
  if (!a.isAllDay) {
    final byTime = a.startMinute!.compareTo(b.startMinute!);
    if (byTime != 0) return byTime;
  }
  return a.title.compareTo(b.title);
}

/// 概览的通知文案（notifications §8）。**纯函数，独立单测**。
///
/// 常驻通知与桌面小组件**共用**这一个函数 —— 两处各写一份的话，
/// 同一天的同一批任务会在两个地方显示成不同的措辞。
String buildDigestText(TodayDigest digest) {
  if (digest.isEmpty) return '今天没有安排';
  if (digest.isAllDone) return '今天的 ${digest.totalCount} 项都完成了';

  final next = digest.items.firstWhere(
    (i) => !i.isDone,
    orElse: () => digest.items.first,
  );
  final time = next.isAllDay ? '全天' : _formatMinute(next.startMinute!);

  return '还剩 ${digest.remainingCount}/${digest.totalCount} 项 · '
      '下一项 $time ${next.title}';
}

/// 0..1439 → `HH:mm`。
String _formatMinute(int minuteOfDay) {
  final h = (minuteOfDay ~/ 60).toString().padLeft(2, '0');
  final m = (minuteOfDay % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

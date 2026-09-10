/// 对账：**该排的**与**已排的**之间的差（notifications.md §5、N-10/N-11）。
///
/// 纯函数，输入两个列表输出差异 —— 没有它的话，「补上缺的、取消多的」
/// 会写成一段边读边写的循环，而那种代码只能靠跑真机去验。
///
/// ## 它能查出什么，不能查出什么
///
/// 「已排的」那一份来自 `scheduled_notifications` 表与插件的清单。
/// **两者都是我们自己的记账**（插件那份也只是它写在 SharedPreferences 里的
/// JSON，见 §5），所以这个对账查的是「我们以为排了什么」与「我们记下排了
/// 什么」之间的分歧 —— 比如某次 `zonedSchedule` 抛了、某次 `cancel` 没执行。
///
/// **它查不出「系统悄悄把闹钟丢了」**：那种情况两份记账里它都还在。
/// 那个由「每次进前台整窗口重排」兜底，不由这里。
library;

import 'package:meta/meta.dart';

import 'notification_planner.dart';

/// 已经排出去的一条（`scheduled_notifications` 的领域视图）。
@immutable
final class ScheduledNotification {
  const ScheduledNotification({
    required this.osId,
    required this.key,
    required this.fireAtUtc,
  });

  /// 传给系统的 ID。**设备本地**，不同步（见表定义）。
  final int osId;

  /// 与 [PlannedNotification.key] 同一套串（`notificationKeyOf`）。
  final String key;

  final DateTime fireAtUtc;

  @override
  String toString() => 'ScheduledNotification(#$osId $key @ $fireAtUtc)';
}

/// 对账结果。
///
/// 时刻变了的那些**同时出现在两边**：先按旧 id 取消，再按新时刻排一条。
/// 不做「原地改时间」是因为系统没有那个操作 —— 插件的
/// `zonedSchedule` 用同 id 重排也是先取消再排，把它摊开在这里，
/// 调用方就不必猜哪一步是原子的。
typedef ScheduleDiff = ({
  List<PlannedNotification> toSchedule,
  List<int> toCancel,
});

/// 算出要新排哪些、要取消哪些。
///
/// **key 相同且时刻相同的一条都不动** —— 这正是稳定 key（`notificationKeyOf`）
/// 换来的东西。每次续排全删全建的话，一条两周后的提醒会被反复取消重排，
/// 白占系统配额，而且每次重排都是一次真的系统调用。
ScheduleDiff reconcileSchedule({
  required List<PlannedNotification> planned,
  required List<ScheduledNotification> existing,
}) {
  final byKey = <String, ScheduledNotification>{};
  final duplicates = <int>[];
  for (final e in existing) {
    final prior = byKey[e.key];
    if (prior == null) {
      byKey[e.key] = e;
      continue;
    }
    // **同一个 key 有两行**：一次发生只该有一条排期。留下的那条按 osId
    // 取小的（确定性，不看输入顺序），另一条取消掉 —— 留着的话它会
    // 在同一时刻响第二遍，而用户不知道为什么同一件事响了两次。
    final keep = prior.osId <= e.osId ? prior : e;
    final drop = identical(keep, prior) ? e : prior;
    byKey[e.key] = keep;
    duplicates.add(drop.osId);
  }

  final wanted = {for (final p in planned) p.key: p};

  final toSchedule = <PlannedNotification>[];
  final toCancel = <int>[...duplicates];

  for (final p in planned) {
    final already = byKey[p.key];
    if (already == null) {
      toSchedule.add(p); // N-10：缺的补上
      continue;
    }
    if (!already.fireAtUtc.isAtSameMomentAs(p.triggerUtc)) {
      // 时刻变了（N-01 的落地）：旧的取消，新的重排。
      toCancel.add(already.osId);
      toSchedule.add(p);
    }
  }

  for (final e in existing) {
    // N-11：计划里没有了（任务删了、完成了、被跳过了、或滚出窗口了）。
    // **按 key 判断而不是按 osId** —— osId 是排期时才分配的，
    // 计划那一侧根本没有它。
    if (!wanted.containsKey(e.key) && !toCancel.contains(e.osId)) {
      toCancel.add(e.osId);
    }
  }

  return (toSchedule: toSchedule, toCancel: toCancel);
}

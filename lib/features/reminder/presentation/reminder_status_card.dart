/// 提醒当前处在什么状态（FR-NOTI-04 的「UI 状态可查」那一半）。
///
/// ## 为什么必须有这张卡片
///
/// 降级是**静默**的：通知权限没给就一条都不排，精确闹钟不可用就降一档
/// 精度继续排。两种情况下应用看起来都一切正常，而用户的提醒要么不响、
/// 要么晚几分钟响 —— 他只会觉得「这个应用的提醒不准」。
///
/// notifications.md §4.4 那张表写的是「明确告知，不假装一切正常」。
/// 这张卡片就是那句话的落点。
///
/// ## 一切正常时不显示
///
/// 常驻一条「提醒工作正常」的绿卡片，等于每次进设置页都告诉用户
/// 一件他没问的事。状态卡片只在**有事**时出现。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/theme/app_theme.dart';
import '../../../design/tokens/dimensions.dart';
import '../../../platform/notification/notification_platform.dart';
import '../application/reminder_providers.dart';

class ReminderStatusCard extends ConsumerWidget {
  const ReminderStatusCard({super.key});

  static const Key cardKey = ValueKey('reminder-status-card');

  /// 「去开权限」。
  static const Key grantKey = ValueKey('reminder-status-grant');

  /// 「去设精确闹钟」。
  static const Key exactKey = ValueKey('reminder-status-exact');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = ref.watch(lastResyncProvider);
    // 还没跑过一轮续排 —— 什么都不说，比说一句没根据的好。
    if (outcome == null) return const SizedBox.shrink();

    if (outcome.blockedByPermission) {
      return _Card(
        key: cardKey,
        title: '提醒暂时不会响',
        body: '还没有通知权限，所以一条都没有排。给了权限就会自动补上。',
        actionKey: grantKey,
        actionLabel: '去开权限',
        onAction: () async {
          await ref
              .read(notificationPlatformProvider)
              .requestNotifyPermission();
          // **回来之后先确认这张卡片还在树上。**
          //
          // 上面那一下挂起的是**系统权限弹窗** —— 用户在那儿待多久都可能，
          // 回来时先退出设置页也完全正常。而 `ref` 绑在这个 element 上，
          // 它没了再 `read` 就会抛。这是这个应用里最宽的一个失效窗口。
          //
          // `ConsumerWidget` 没有 `mounted`，用 `context.mounted`——
          // 两者是同一个 element 的两种问法。
          if (!context.mounted) return;
          // 给完权限立刻补排 —— 让用户等到下次进前台才生效，
          // 他会以为刚才那一下没起作用。
          await ref.read(reminderSyncProvider.notifier).resyncNow();
        },
      );
    }

    if (outcome.mode == ReminderScheduleMode.inexact) {
      return _Card(
        key: cardKey,
        title: '提醒可能晚几分钟',
        body: '系统没给精确闹钟的权限，提醒仍然会响，但时间不保证准。',
        actionKey: exactKey,
        actionLabel: '去设精确闹钟',
        onAction: () async {
          await ref.read(notificationPlatformProvider).openExactAlarmSettings();
          // 同上，而且这一下更宽：它把用户**跳去了系统设置页**。
          if (!context.mounted) return;
          await ref.read(reminderSyncProvider.notifier).resyncNow();
        },
      );
    }

    return const SizedBox.shrink();
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.body,
    required this.actionKey,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final String title;
  final String body;
  final Key actionKey;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          // **用 `sunken` 而不是警示色。** 这两种状态都不是错误 ——
          // 用户没给权限是他的选择，精确闹钟拿不到是系统的限制。
          // 涂成红黄会把「有件事你可能想知道」说成「出问题了」。
          color: colors.sunken,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleSmall),
              const SizedBox(height: Spacing.xs),
              Text(body, style: text.bodyMedium),
              const SizedBox(height: Spacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: actionKey,
                  onPressed: onAction,
                  child: Text(actionLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

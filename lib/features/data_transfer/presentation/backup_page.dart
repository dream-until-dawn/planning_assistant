/// 备份与恢复（FR-DATA-04/05）。设置页的**二级页**。
///
/// ## 这一页只做「应用内」的备份
///
/// 文件写在应用文档目录里 —— 列得出、恢复得回来，但**拿不到应用外面去**
/// （分享出去要引新插件，理由写在 `BackupStore` 的头注里）。
/// 所以这一页的文案不说「导出到手机」，只说「存在这台设备上」：
/// 承诺得比做到的多，比什么都不说更糟。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/empty_illustration.dart';
import '../../../design/components/empty_state.dart';
import '../../../design/theme/app_theme.dart';
import '../../../design/tokens/dimensions.dart';
import '../../../platform/storage/backup_store.dart';
import '../../settings/application/registry.dart';
import '../../settings/application/settings_providers.dart';
import '../application/backup_providers.dart';

class BackupPage extends ConsumerWidget {
  const BackupPage({super.key});

  static const Key pageKey = ValueKey('backup-page');
  static const Key emptyKey = ValueKey('backup-empty');
  static const Key errorKey = ValueKey('backup-error');
  static const Key backupNowKey = ValueKey('backup-now');
  static const Key restoreConfirmKey = ValueKey('backup-restore-confirm');
  static const Key deleteConfirmKey = ValueKey('backup-delete-confirm');

  static Key itemKey(String name) => ValueKey('backup-item-$name');
  static Key restoreKey(String name) => ValueKey('backup-restore-$name');
  static Key deleteKey(String name) => ValueKey('backup-delete-$name');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final files = ref.watch(backupListProvider);

    return Scaffold(
      key: pageKey,
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('备份'),
      ),
      body: Column(
        children: [
          const _Header(),
          Expanded(
            child: switch (files) {
              // 同回收站：本地目录首帧通常一帧内就来了，转圈只会闪一下。
              AsyncLoading() => const SizedBox.shrink(),
              AsyncError() => const EmptyState(
                key: BackupPage.errorKey,
                illustration: EmptyIllustration(motif: EmptyMotif.offline),
                message: '没能读出备份列表。\n重开一次试试？',
              ),
              AsyncData(:final value) when value.isEmpty => const EmptyState(
                key: BackupPage.emptyKey,
                illustration: EmptyIllustration(motif: EmptyMotif.box),
                message: '还没有备份。',
              ),
              AsyncData(:final value) => _BackupList(files: value),
            },
          ),
        ],
      ),
    );
  }
}

/// 说清「备份是什么」+ 立刻备一份。
class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final auto = ref.setting(autoBackupEnabled);
    final interval = ref.setting(autoBackupIntervalDays);
    // **在 build 里读、带进回调**：回调是异步的，那时 `ref.setting`
    // （它是 `watch`）会撞上「不在 build 里」的断言；而改成 `read`
    // 又会在没人订阅时读到 `AsyncLoading` 的回落值。
    final keep = ref.setting(autoBackupKeepCount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.md,
        Spacing.lg,
        Spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            // **说在哪儿、也说清不在哪儿**：用户以为备份进了云或相册，
            // 换手机时才会发现什么都没带走。
            '备份存在这台设备上，换机或卸载不会带走。',
            style: text.bodySmall?.copyWith(color: colors.disabledText),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            auto ? '自动备份：每 $interval 天一次' : '自动备份：已关闭',
            style: text.bodySmall?.copyWith(color: colors.disabledText),
          ),
          const SizedBox(height: Spacing.md),
          FilledButton.icon(
            key: BackupPage.backupNowKey,
            onPressed: () => _backupNow(context, ref, keep),
            icon: const Icon(Icons.backup_outlined),
            label: const Text('立即备份'),
          ),
        ],
      ),
    );
  }

  Future<void> _backupNow(BuildContext context, WidgetRef ref, int keep) async {
    // messenger 先取：await 之后 context 可能已经不在树上了。
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref
        .read(backupServiceProvider)
        .backupNow(keepCount: keep);
    // await 之后这一页可能已经不在树上了（用户退了回去）——
    // 那时候 `ref` 已经失效，读它会抛。
    if (!context.mounted) return;
    ref.invalidate(backupListProvider);
    // **成败都说一声。** 这一下是用户主动按的，而没有回音的按钮
    // 会让人反复按 —— 每按一次就多一份备份。
    messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
  }
}

class _BackupList extends ConsumerWidget {
  const _BackupList({required this.files});

  final List<BackupFile> files;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: Spacing.xxl),
      itemCount: files.length,
      itemBuilder: (context, i) {
        final file = files[i];
        return ListTile(
          key: BackupPage.itemKey(file.name),
          title: Text(_when(file.createdAt.toLocal())),
          subtitle: Text(_size(file.sizeBytes), style: text.bodySmall),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                key: BackupPage.restoreKey(file.name),
                onPressed: () => _restore(context, ref, file),
                child: const Text('恢复'),
              ),
              IconButton(
                key: BackupPage.deleteKey(file.name),
                tooltip: '删除这份备份',
                onPressed: () => _delete(context, ref, file),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    BackupFile file,
  ) async {
    // **恢复是整库替换，不是合并**（`ExportService.import` 的语义）——
    // 现在库里的东西会没。看不见的后果尤其要先说。
    final ok = await _confirm(
      context,
      title: '用这份备份覆盖现在的数据？',
      body: '恢复会替换掉当前所有任务与设置，现在库里的内容不会保留。',
      action: '恢复',
      actionKey: BackupPage.restoreConfirmKey,
    );
    if (!ok || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref.read(backupServiceProvider).restore(file.name);
    messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    BackupFile file,
  ) async {
    final ok = await _confirm(
      context,
      title: '删掉这份备份？',
      body: '删掉之后找不回来。当前的数据不受影响。',
      action: '删除',
      actionKey: BackupPage.deleteConfirmKey,
    );
    if (!ok || !context.mounted) return;

    await ref.read(backupServiceProvider).delete(file.name);
    if (!context.mounted) return;
    ref.invalidate(backupListProvider);
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  required Key actionKey,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          key: actionKey,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// 「2026-09-10 12:30」。
///
/// **列表上不显示文件名。** 文件名是 UTC 的 ISO 串，用户读不出「哪一次」,
/// 而他要挑的正是「哪一次」。文件名只用来做 key 与传给服务。
String _when(DateTime at) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${at.year}-${two(at.month)}-${two(at.day)} '
      '${two(at.hour)}:${two(at.minute)}';
}

String _size(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// 超期清理（task-lifecycle §6、用例 L-09）。
///
/// 「物理清理由**启动时的一次后台任务**执行」——§6 的原话。
///
/// ## 为什么判据在领域层，动作在这里
///
/// 「这条该不该清」是 `isPurgeable(task, now, retentionDays)`，
/// 领域层早就写好也测过了（L-09：只清超过保留期的，边界日不清）。
/// 这一层只做三件事：把配置读出来、把要清的挑出来、调仓库。
///
/// 分开的好处是边界日那种事不会在这里被重新实现一遍 ——
/// 而重新实现一遍就意味着两处判据，迟早差一天。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../domain/policies/task_lifecycle.dart';
import '../../../domain/repositories/task_repository.dart';
import '../../settings/application/registry.dart';
import '../../settings/application/settings_providers.dart';

/// 清一遍过期的墓碑，返回清掉了几条。
///
/// **失败不该拦住启动**：清理是维护性的，清不掉下次再清。
/// 调用方拿到异常也只是记一笔，见 `PlanningAssistantApp` 里那处。
final trashPurgeProvider = Provider<Future<int> Function()>((ref) {
  return () async {
    final repo = ref.read(taskRepositoryProvider);
    final now = ref.read(clockProvider).nowUtc();
    final days = settingOf(ref, trashRetentionDays);

    final trashed = await repo.findTasks(scope: TaskScope.trashed);
    final doomed = [
      for (final task in trashed)
        if (isPurgeable(task, now: now, retentionDays: days)) task.id,
    ];
    if (doomed.isEmpty) return 0;
    return repo.purgeDeleted(doomed);
  };
});

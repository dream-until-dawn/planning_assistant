/// 免打扰时段落在提醒上时怎么办（settings-spec §2.3、notifications.md §7）。
///
/// **住在领域层，不是 `features/reminder/`。** 它是排期判据的一部分 ——
/// `planNotifications` 要按它决定顺延还是丢弃 —— 而领域层不得依赖 features
/// （module-map §3，有守卫盯着，写这一版时就是被它拦下的）。放在 features 下
/// 的话，要么让领域层反向依赖，要么把这个判断挪出纯函数；两条都比挪个文件贵。
/// （`DefaultTaskDuration` 留在 features 下，是因为只有界面读它。）
///
/// **两档就够**，不做「照常响」：那等于关掉免打扰，而免打扰本来就有开关
/// （`reminder.quietHoursEnabled`）。多一个语义重叠的取值，只会让
/// 「我到底设没设免打扰」多一种说不清的状态。
library;

/// 免打扰时段内的提醒怎么处理。
enum QuietHoursBehavior {
  /// 顺延到时段结束的那一刻。默认。
  ///
  /// **默认选它而不是丢弃**：用户设免打扰是为了「别在这个时间吵我」，
  /// 不是「这段时间的事不用提醒我」。丢弃会让一条 23:30 的提醒
  /// 彻底不出现，而用户第二天早上才发现漏了。
  postpone('postpone', '顺延到结束'),

  /// 直接丢弃这一次。
  suppress('suppress', '不提醒');

  const QuietHoursBehavior(this.storageKey, this.label);

  /// 存进配置与导出 JSON 的串。**与枚举名一致**，同项目其它配置枚举。
  final String storageKey;
  final String label;

  /// 认不出的值回落到默认（同其它配置枚举的约定）。
  static QuietHoursBehavior fromStorageKey(String? key) {
    for (final v in QuietHoursBehavior.values) {
      if (v.storageKey == key) return v;
    }
    return QuietHoursBehavior.postpone;
  }
}

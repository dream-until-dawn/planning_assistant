/// 四视图的标识（view-specs §7.3、配置项 `view.defaultView`）。
///
/// 放 `application/` 而不是 `presentation/`：它是**一个名字**，
/// 不是一个界面。设置页要存它、外壳要读它、路由要认它 ——
/// 跨 feature 通信只能经 application 层（module-map §3）。
library;

/// 视图种类。
///
/// 顺序即切换器里的显示顺序，**别随手调** —— 用户会形成肌肉记忆。
enum ViewKind {
  /// 列表。默认视图，对新用户最易理解（view-specs §6）。
  list('list', '列表'),

  timeline('timeline', '时间轴'),

  calendar('calendar', '日历'),

  gantt('gantt', '甘特');

  const ViewKind(this.storageKey, this.label);

  /// 存进配置的字符串。**与枚举名解耦**：改 Dart 端的枚举名
  /// 不应该让用户已存的配置失效。
  final String storageKey;

  /// 给人看的名字。
  // TODO(M4): 走 l10n 资源（NFR-A11Y-04）
  final String label;

  /// 默认视图（view-specs §6）。
  static const ViewKind fallback = ViewKind.list;

  /// 从配置里存的字符串还原。
  ///
  /// **认不出来就回落到 [fallback]，不抛异常**（view-specs §7.4）。
  /// 用户降级安装、或配置被别的版本写过时，这里会读到当前版本
  /// 不认识的名字 —— 那种情况下正确的行为是给他一个能用的界面，
  /// 不是白屏或崩溃。
  ///
  /// 回落是**显式的一条分支**，不是 `firstWhere` 抛异常后被谁吞掉 ——
  /// 那样的话「回落」和「别处出了错」长得一模一样。
  static ViewKind fromStorageKey(String? key) {
    for (final kind in ViewKind.values) {
      if (kind.storageKey == key) return kind;
    }
    return fallback;
  }
}

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
  list('list', '列表', anchorsToDay: false),

  timeline('timeline', '时间轴', anchorsToDay: true),

  calendar('calendar', '日历', anchorsToDay: true),

  gantt('gantt', '甘特', anchorsToDay: true);

  const ViewKind(this.storageKey, this.label, {required this.anchorsToDay});

  /// 存进配置的字符串。**与枚举名解耦**：改 Dart 端的枚举名
  /// 不应该让用户已存的配置失效。
  final String storageKey;

  /// 给人看的名字。
  // TODO(M4): 走 l10n 资源（NFR-A11Y-04）
  final String label;

  /// 这个视图是不是**对着某一天**（FR-VIEW-07）。
  ///
  /// 决定加号带不带日期：时间轴、日历、甘特都有一个用户正看着的
  /// 聚焦日，在那儿点加号，他说的是「这一天」——
  /// 不带的话，日历翻到 9/20 建出来的任务会落进「随时」区。
  ///
  /// **列表不是。** 它横跨所有日期，用户在那儿点加号没有指向任何一天。
  /// 一律盖上「今天」的话，「随时」这一类任务就再也建不出来了
  /// —— 而它是 FR-VIEW-01 里点了名的一档。
  /// 修 A 的时候顺手把 B 堵死，是这一晚上反复出现的那个形状。
  final bool anchorsToDay;

  /// 默认视图（view-specs §6）。
  static const ViewKind fallback = ViewKind.list;

  /// **当前版本实装了的视图。** M3 把另外三个逐个加进来。
  ///
  /// 这是「哪些视图能用」的**唯一声明**。两处需要它：
  ///
  /// - 组合根的视图注册表必须与它一致（架构守卫盯着）；
  /// - 设置页「默认视图」只列这里面的 —— 否则用户能选一个
  ///   选了没反应的视图，而那比没有这个选项更糟。
  ///
  /// 放在枚举上而不是组合根：设置页属于 settings feature，
  /// 够不到组合根（module-map §3），而它确实需要知道这件事。
  /// M3 做完之后是全部四个。**仍然保留这个集合**，不改成
  /// 「等于 values」的写法：它的用处是「已实装」与「已声明」之间
  /// 可以不一致，而 M4 加新视图时那个差又会回来。
  static const Set<ViewKind> implemented = {
    ViewKind.list,
    ViewKind.timeline,
    ViewKind.calendar,
    ViewKind.gantt,
  };

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

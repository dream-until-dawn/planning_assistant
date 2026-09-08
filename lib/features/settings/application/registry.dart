/// 配置注册表（settings-spec §1、§2）。
///
/// > 规格里写的路径是 `features/settings/registry.dart`（直接放在 feature
/// > 根下）。分层守卫判它「未分类到任何一层」而变红 —— 判得对：
/// > `lib/` 下不在层目录里的文件，守卫对它的一切约束都静默失效。
/// > 挪到 `application/`：它是**声明数据**，不是界面也不是领域不变量。
///
/// **全部声明集中在这里。** 加一项配置 = 这里加一条，设置页自动出现
/// （FR-CFG-07：新增配置只改一处）。
///
/// ## 现在只声明**有消费者**的项
///
/// settings-spec §2 列了四十来项。这里只放已经有人读的：
/// 放一条没人读的声明，设置页上就会出现一个**改了没反应**的开关 ——
/// 比没有更糟，而且它会一直「看起来已经做好了」。
///
/// 每接一个功能，把它对应的那条搬进来。
library;

import '../../../design/tokens/dimensions.dart';
import '../../views/shared/application/view_kind.dart';
import '../../views/task_list/application/task_grouping.dart';
import '../domain/setting_spec.dart';

/// 主题明暗（`theme.mode`）。
enum ThemeModeSetting {
  system('system', '跟随系统'),
  light('light', '亮色'),
  dark('dark', '暗色');

  const ThemeModeSetting(this.storageKey, this.label);

  final String storageKey;
  final String label;

  static ThemeModeSetting fromStorageKey(String? key) {
    for (final v in values) {
      if (v.storageKey == key) return v;
    }
    return ThemeModeSetting.system;
  }
}

/// 枚举类配置的通用声明工厂。
///
/// 手写五遍 encode/decode 的话，迟早有一处把 `name` 当成存储值 ——
/// 而 `name` 会随重命名而变，那等于静默改写用户的配置。
SettingSpec<T> _enumSpec<T>({
  required String key,
  required T defaultValue,
  required List<(T, String)> options,
  required String Function(T) storageKeyOf,
  required T Function(String?) fromStorageKey,
  required SettingGroup group,
  required String label,
  String? description,
}) => SettingSpec<T>(
  key: key,
  defaultValue: defaultValue,
  exposure: SettingExposure.exposed,
  group: group,
  editor: SettingEditor.select,
  label: label,
  description: description,
  options: options,
  encode: storageKeyOf,
  // 认不出的值回落到默认 —— 用户降级安装、或配置被别的版本写过时
  // 会读到当前版本不认识的名字，那时正确的行为是给他一个能用的界面。
  decode: (json) => fromStorageKey(json is String ? json : null),
);

/// 全部配置声明。**顺序即设置页内的显示顺序**（同组内）。
final List<SettingSpecBase> settingsRegistry = [
  themeMode,
  cornerStyle,
  defaultView,
  listGroupBy,
  listSortBy,
  timelineTickMinutes,
  defaultCategoryId,
  swipeRight,
  swipeLeft,
];

// ── 外观 ────────────────────────────────────────────────────────

final SettingSpec<ThemeModeSetting> themeMode = _enumSpec(
  key: 'theme.mode',
  defaultValue: ThemeModeSetting.system,
  options: [for (final v in ThemeModeSetting.values) (v, v.label)],
  storageKeyOf: (v) => v.storageKey,
  fromStorageKey: ThemeModeSetting.fromStorageKey,
  group: SettingGroup.appearance,
  label: '主题',
);

final SettingSpec<CornerStyle> cornerStyle = _enumSpec(
  key: 'theme.cornerStyle',
  defaultValue: CornerStyle.standard,
  options: const [
    (CornerStyle.soft, '更圆'),
    (CornerStyle.standard, '标准'),
    (CornerStyle.sharp, '更方'),
  ],
  storageKeyOf: (v) => v.name,
  fromStorageKey: (key) {
    for (final v in CornerStyle.values) {
      if (v.name == key) return v;
    }
    return CornerStyle.standard;
  },
  group: SettingGroup.appearance,
  label: '圆角',
  description: '影响卡片、按钮等所有圆角',
);

// ── 行为 ────────────────────────────────────────────────────────

/// 滑动手势的动作（view-specs §2.4、settings-spec §2.4）。
enum SwipeAction {
  complete('complete', '完成'),
  postpone('postpone', '推迟一天'),
  none('none', '不做事');

  const SwipeAction(this.storageKey, this.label);

  final String storageKey;
  final String label;

  /// **只列做得出来的那几个。**
  ///
  /// settings-spec 里还写了 `delete`。没放进来是因为「滑一下就把整条
  /// 重复任务删了」在误触时代价太大，而撤销目前只是一条 Snackbar ——
  /// 等回收站的入口做出来（M3）再加。摆一个删不掉的「删除」选项，
  /// 比没有这个选项更糟。
  static SwipeAction fromStorageKey(String? key) {
    for (final v in values) {
      if (v.storageKey == key) return v;
    }
    return SwipeAction.none;
  }
}

final SettingSpec<SwipeAction> swipeRight = _enumSpec(
  key: 'behavior.swipeRight',
  defaultValue: SwipeAction.complete,
  options: [for (final v in SwipeAction.values) (v, v.label)],
  storageKeyOf: (v) => v.storageKey,
  fromStorageKey: SwipeAction.fromStorageKey,
  group: SettingGroup.behavior,
  label: '右滑',
  description: '在列表里向右滑一张卡片',
);

final SettingSpec<SwipeAction> swipeLeft = _enumSpec(
  key: 'behavior.swipeLeft',
  defaultValue: SwipeAction.postpone,
  options: [for (final v in SwipeAction.values) (v, v.label)],
  storageKeyOf: (v) => v.storageKey,
  fromStorageKey: SwipeAction.fromStorageKey,
  group: SettingGroup.behavior,
  label: '左滑',
  description: '在列表里向左滑一张卡片',
);

/// 「未分类」在这项配置里的存储值（settings-spec §2.4 的默认值）。
///
/// **它只是这一项配置的取值，不是第三种「未分类」的编码。**
/// 任务那一侧仍然只有一种：`categoryId IS NULL`（§3.0）。
/// 这里需要一个字符串，是因为配置的值域是字符串 —— 存不了 null 与
/// 「没设过」的区别。读出来时由 `defaultCategoryIdProvider` 折算回 null。
const String kUncategorizedSettingValue = 'uncategorized';

/// 新任务默认落在哪个分类（settings-spec §2.4、§3「设为默认」）。
///
/// **不在设置页里出现**（`hidden`），入口在分类管理页的每一行上 ——
/// 它的选项是用户自己的分类，是运行时数据，而注册表里的 `select`
/// 只能列静态选项。硬塞进设置页要么列不全，要么得再造一种编辑器，
/// 而那一整套只为这一项服务。
///
/// 隐藏不等于没人管：它照常参与读取、导出与导入（FR-CFG-08），
/// 而**消费者是任务编辑器的初值**（`TaskEditorController.build`）——
/// 没有消费者的声明会变成一个改了没反应的开关，见本文件开头那段。
final SettingSpec<String> defaultCategoryId = SettingSpec<String>(
  key: 'behavior.defaultCategoryId',
  defaultValue: kUncategorizedSettingValue,
  group: SettingGroup.behavior,
  label: '新任务的默认分类',
  encode: (v) => v,
  // 不是字符串就当没设过。分类被删之后这里会留着一个死 id ——
  // 那不在这一层处理：解码只管「读出来的是不是一个 id」，
  // 「这个 id 还在不在」由 `defaultCategoryIdProvider` 判。
  decode: (json) => json is String ? json : kUncategorizedSettingValue,
);

// ── 视图 ────────────────────────────────────────────────────────

final SettingSpec<ViewKind> defaultView = _enumSpec(
  key: 'view.defaultView',
  defaultValue: ViewKind.fallback,
  // **只列实装了的**（`ViewKind.implemented`）。列上没做的那三个，
  // 用户选了会静默无效 —— 一个改了没反应的选项比没有这个选项更糟。
  options: [
    for (final v in ViewKind.values)
      if (ViewKind.implemented.contains(v)) (v, v.label),
  ],
  storageKeyOf: (v) => v.storageKey,
  fromStorageKey: ViewKind.fromStorageKey,
  group: SettingGroup.view,
  label: '默认视图',
  description: '冷启动进入哪个视图',
);

final SettingSpec<ListGroupBy> listGroupBy = _enumSpec(
  key: 'view.listGroupBy',
  defaultValue: ListGroupBy.fallback,
  options: const [
    (ListGroupBy.date, '按日期'),
    (ListGroupBy.category, '按分类'),
    (ListGroupBy.priority, '按优先级'),
    (ListGroupBy.status, '按状态'),
  ],
  storageKeyOf: (v) => v.storageKey,
  fromStorageKey: ListGroupBy.fromStorageKey,
  group: SettingGroup.view,
  label: '列表分组',
);

/// 时间轴的刻度粒度（view-specs §1.2）。
///
/// **它同时决定纵向的比例尺**：一格恒为 `TimelineMetrics.tickHeight`，
/// 于是选 15 分钟就是把一天拉长四倍。只加密刻度线而不改比例的话，
/// 15 分钟一格只有十几个逻辑像素，标签互相压着，等于没有这个选项。
final SettingSpec<int> timelineTickMinutes = SettingSpec<int>(
  key: 'view.timelineTickMinutes',
  defaultValue: 60,
  exposure: SettingExposure.exposed,
  group: SettingGroup.view,
  editor: SettingEditor.select,
  label: '时间轴刻度',
  description: '时间轴上每一格代表多久',
  options: const [(15, '15 分钟'), (30, '30 分钟'), (60, '1 小时')],
  encode: (v) => v,
  // 认不出的值回落到默认。**这里必须显式列出合法值**：
  // 存进来一个 7 分钟的话，刻度线会落在 07:00、07:07…… 这种地方，
  // 而它是「配置文件被手改过」，不是一个该被当真的选择。
  decode: (json) =>
      json is int && const [15, 30, 60].contains(json) ? json : 60,
);

final SettingSpec<ListSortBy> listSortBy = _enumSpec(
  key: 'view.listSortBy',
  defaultValue: ListSortBy.fallback,
  options: const [
    (ListSortBy.time, '按时间'),
    (ListSortBy.priority, '按优先级'),
    (ListSortBy.created, '按创建时间'),
    (ListSortBy.manual, '手动排序'),
  ],
  storageKeyOf: (v) => v.storageKey,
  fromStorageKey: ListSortBy.fromStorageKey,
  group: SettingGroup.view,
  label: '组内排序',
);

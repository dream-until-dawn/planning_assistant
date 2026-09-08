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

// ── 视图 ────────────────────────────────────────────────────────

final SettingSpec<ViewKind> defaultView = _enumSpec(
  key: 'view.defaultView',
  defaultValue: ViewKind.fallback,
  options: [for (final v in ViewKind.values) (v, v.label)],
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

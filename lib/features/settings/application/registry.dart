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

import '../../../core/time/weekday.dart';
import '../../../design/tokens/dimensions.dart';
import '../../views/calendar/application/calendar_split.dart';
import '../../views/gantt/application/gantt_layout.dart';
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
  reduceMotion,
  defaultView,
  listGroupBy,
  listSortBy,
  firstDayOfWeek,
  calendarSplitRatio,
  ganttLaneBy,
  trashRetentionDays,
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

/// 关掉动效（design-system §7、NFR-A11Y）。
///
/// **与系统设置取「或」**，不是取代它 —— 打开系统的「减少动态效果」
/// 之后还要再来应用里关一次，那等于没有响应系统设置。
/// 取「或」的那一步在 `reducedMotionProvider` 里，这里只是应用内这一半。
final SettingSpec<bool> reduceMotion = SettingSpec<bool>(
  key: 'theme.reduceMotion',
  defaultValue: false,
  exposure: SettingExposure.exposed,
  group: SettingGroup.appearance,
  label: '减少动态效果',
  description: '关掉切换与过渡动画；系统开了这项时自动生效',
  encode: (v) => v,
  decode: (json) => json is bool ? json : false,
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
  delete('delete', '删除'),
  none('none', '不做事');

  const SwipeAction(this.storageKey, this.label);

  final String storageKey;
  final String label;

  /// **只列做得出来的那几个。**
  ///
  /// `delete` 一度不在这里：「滑一下就把整条重复任务删了」在误触时
  /// 代价太大，而当时唯一的退路是一条 Snackbar —— 划走了就找不回来。
  /// 回收站做出来之后这个理由消失了：删除是软删除，进回收站，
  /// 随时能恢复。所以补上。
  ///
  /// 这条注释留着是因为它记的是**判据**，不是当时的结论：
  /// 一个动作能不能放进滑动手势，看的是「误触之后有没有回头路」。
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

/// 一周从周几起（view-specs §3.2，日历与甘特都用）。
///
/// 只给三个选项，不是七个：周一（ISO / 多数地区）、周日（北美等）、
/// 周六（部分中东地区）。剩下四个在现实里没有哪个地区用作周起始日，
/// 列出来只会让这个选择器变长。
final SettingSpec<Weekday> firstDayOfWeek = _enumSpec(
  key: 'view.firstDayOfWeek',
  defaultValue: Weekday.monday,
  options: const [
    (Weekday.monday, '周一'),
    (Weekday.sunday, '周日'),
    (Weekday.saturday, '周六'),
  ],
  storageKeyOf: (v) => v.storageKey,
  fromStorageKey: Weekday.fromStorageKey,
  group: SettingGroup.view,
  label: '一周从哪天开始',
  description: '影响日历的排列',
);

/// 回收站保留期（task-lifecycle §6）。
///
/// 超过它的墓碑会在下次启动时被物理清理（L-09）。
///
/// **给的是几个档位，不是任意数字**：一个能填 0 的输入框意味着
/// 「删了立刻永久消失」，那与回收站的意义正相反。
final SettingSpec<int> trashRetentionDays = SettingSpec<int>(
  key: 'data.trashRetentionDays',
  defaultValue: 30,
  exposure: SettingExposure.exposed,
  group: SettingGroup.data,
  editor: SettingEditor.select,
  label: '回收站保留',
  description: '超过这个天数的已删任务会在下次启动时清理掉',
  options: const [(7, '7 天'), (30, '30 天'), (90, '90 天')],
  encode: (v) => v,
  // 认不出的值回落到默认。**必须显式列出合法值** ——
  // 配置文件被手改成 0 的话，「删了立刻永久消失」就成了默认行为。
  decode: (json) => json is int && const [7, 30, 90].contains(json) ? json : 30,
);

/// 甘特的泳道按什么分（view-specs §4.3）。
///
/// 规格里还列了 `tag`，**没做** —— 模型里没有标签这个东西
/// （`domain/entities/` 下没有 tag）。列上去的话用户能选一个
/// 选了没反应的维度，比没有这个选项更糟（同「默认视图」那条）。
final SettingSpec<GanttLaneBy> ganttLaneBy = _enumSpec(
  key: 'view.ganttLaneBy',
  defaultValue: GanttLaneBy.category,
  options: const [(GanttLaneBy.category, '按分类'), (GanttLaneBy.task, '按任务')],
  storageKeyOf: (v) => v.storageKey,
  fromStorageKey: GanttLaneBy.fromStorageKey,
  group: SettingGroup.view,
  label: '甘特泳道',
  description: '甘特图按什么分列',
);

/// 日历上下两半的比例（view-specs §3.1「比例可拖拽，记住用户选择」）。
///
/// **隐藏项**：它由拖拽产生，不由设置页产生。摆一个数字输入框让人填
/// 「0.58」，比没有这个选项更糟。
final SettingSpec<double> calendarSplitRatio = SettingSpec<double>(
  key: 'view.calendarSplitRatio',
  defaultValue: CalendarSplit.byDefault,
  encode: (v) => v,
  // 存进来的值可能来自手改的配置文件。**夹回合法区间**而不是照单全收：
  // 0 或 1 会让某一半压成零高，而那一半再也拖不回来。
  decode: (json) => json is num
      ? CalendarSplit.clamp(json.toDouble())
      : CalendarSplit.byDefault,
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

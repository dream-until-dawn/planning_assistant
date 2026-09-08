/// 配置项的**声明**（settings-spec §1）。
///
/// 每个配置项是一条声明，不是散落在代码里的常量。由此得到四条性质：
///
/// | 性质 | 怎么来的 |
/// |---|---|
/// | FR-CFG-01 永远有默认值 | [defaultValue] 必填；读取接口返回 `T` 而非 `T?` |
/// | FR-CFG-07 新增配置只改一处 | 设置页遍历注册表自动渲染，不写死 UI |
/// | FR-CFG-08 隐藏项也能用 | `hidden` 的项不进设置页，但照常参与读取与导入导出 |
/// | 可测试 | 注册表是纯数据，能断言「key 无重复」「默认值自洽」 |
///
/// **这一层是 feature 本地的 domain**，与顶层 `domain/` 受同样约束：
/// 零 Flutter 依赖（module-map §3 那条警告）。所以这里没有 `editor`
/// 对应的 widget，只有一个枚举 —— 渲染成什么控件是 presentation 的事。
library;

import 'package:meta/meta.dart';

/// 参与同步与否（settings-spec §1）。
enum SettingScope {
  /// 参与同步与导出。
  global('global'),

  /// 设备本地，**永不导入导出**（settings-spec §5）。
  device('device');

  const SettingScope(this.wireName);

  final String wireName;
}

/// 在设置页可不可见。
enum SettingExposure {
  exposed,

  /// 不进设置页，但**照常参与读取、导出与导入**（FR-CFG-08）——
  /// 普通用户用默认值，高级用户改配置文件。
  hidden,
}

/// 渲染成什么控件。
///
/// 只是个**名字**，不是 widget —— 这一层不认识 Flutter。
enum SettingEditor { toggle, select, slider, color }

/// 设置页的分组。顺序即显示顺序（settings-spec §4）。
enum SettingGroup {
  appearance('外观'),
  view('视图'),
  reminder('提醒'),
  behavior('行为'),
  data('数据');

  const SettingGroup(this.title);

  final String title;
}

/// 配置声明的**非泛型门面**。
///
/// ## 为什么需要它
///
/// 注册表要把不同类型的声明装进一个列表。写成
/// `List<SettingSpec<Object?>>` 看着能编译 —— Dart 的泛型对读是协变的 ——
/// 但列表里装的其实是 `SettingSpec<ThemeModeSetting>` 之类，
/// 通过 `Object?` 视图调 `encode(...)` 会在**运行时**炸：
///
/// ```
/// type '(ThemeModeSetting) => String' is not a subtype of type '(Object?) => Object'
/// ```
///
/// 设置页一度是能跑的，因为传进去的值恰好来自同一条声明的 `options`，
/// 运行时类型碰巧对得上 —— 那是「碰巧能用」，不是安全。
/// 注册表自检测试第一次遍历就把它炸了出来。
///
/// 所以遍历注册表时只用这一组**已经把类型擦掉**的成员；
/// 需要类型的地方（读某一项、写某一项）走泛型的 [SettingSpec]。
abstract interface class SettingSpecBase {
  String get key;
  SettingScope get scope;
  SettingExposure get exposure;
  SettingGroup? get group;
  SettingEditor get editor;
  String? get label;
  String? get description;
  bool get isExposed;

  /// 默认值，类型已擦除。
  Object? get defaultValueDynamic;

  /// `select` 的选项，类型已擦除。
  List<(Object?, String)> get optionsDynamic;

  /// 编码，**内部转回 T**。传错类型会抛 —— 那是调用方的错，不该静默。
  Object encodeDynamic(Object? value);

  Object? decodeDynamic(Object json);

  String? validateDynamic(Object? value);
}

/// 一条配置声明。
@immutable
final class SettingSpec<T> implements SettingSpecBase {
  const SettingSpec({
    required this.key,
    required this.defaultValue,
    required this.decode,
    required this.encode,
    this.scope = SettingScope.global,
    this.exposure = SettingExposure.hidden,
    this.group,
    this.editor = SettingEditor.toggle,
    this.label,
    this.description,
    this.options = const [],
    this.validate,
  });

  // 「暴露的项必须有 group 与 label」这类约束**不用 assert 表达**
  // （cross-cutting §3.1：assert 在 release 里会被剥掉，那时不变量
  // 等于没有）。而且构造期的 assert 只在那一条被构造时才响，
  // 漏声明一条它压根不知道。
  //
  // 这些约束由 `test/application/settings_registry_test.dart` 遍历整张
  // 注册表来验 —— settings-spec §1.2 本来就是这么规定的。

  /// 点分命名空间，如 `theme.primaryColor`。**全局唯一。**
  @override
  final String key;

  /// 必填。读取接口因此可以返回 `T` 而不是 `T?`，
  /// 调用方永远不需要处理 null（FR-CFG-01）。
  final T defaultValue;

  @override
  final SettingScope scope;
  @override
  final SettingExposure exposure;
  @override
  final SettingGroup? group;
  @override
  final SettingEditor editor;

  /// 给人看的名字。隐藏项可以没有。
  // TODO(M4): 走 l10n 资源（NFR-A11Y-04）
  @override
  final String? label;

  @override
  final String? description;

  /// `select` 类型的可选项：`(存储值, 显示名)`。
  final List<(T, String)> options;

  /// 从 JSON 值还原。**解不出来时抛**，由读取层兜成默认值 ——
  /// 静默返回默认值的话，「配置坏了」与「用户就是这么设的」分不开。
  final T Function(Object json) decode;

  final Object Function(T value) encode;

  /// 返回错误文案，或 null 表示通过。
  final String? Function(T value)? validate;

  @override
  bool get isExposed => exposure == SettingExposure.exposed;

  @override
  Object? get defaultValueDynamic => defaultValue;

  @override
  List<(Object?, String)> get optionsDynamic => [
    for (final (value, label) in options) (value, label),
  ];

  @override
  Object encodeDynamic(Object? value) => encode(value as T);

  @override
  Object? decodeDynamic(Object json) => decode(json);

  @override
  String? validateDynamic(Object? value) => validate?.call(value as T);

  @override
  String toString() => 'SettingSpec($key)';
}

/// 配置的读取与写入（settings-spec §1.1）。
///
/// 读取接口返回 `T` 而不是 `T?` —— 调用方**不需要处理 null**，
/// 也不需要知道值从哪来（库里有值用库里的，没有用默认值）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../domain/setting_spec.dart';

/// 库里已存的原始配置。未设过的 key 不在里面。
final rawSettingsProvider = StreamProvider<Map<String, Object?>>(
  (ref) => ref.watch(settingsRepositoryProvider).watchAll(),
);

/// 从已读出的原始表里解一项。**永远有值**（FR-CFG-01）。
///
/// 解不出来时回落到默认值并**不声张** —— 这是有意的取舍：
/// 配置值坏掉时，让用户看到一个能用的界面，比让他看到一屏报错有用。
/// 坏值也不会被悄悄写回去（写入是另一条路径），所以它仍在库里、
/// 下次导出时仍然查得到。
T _resolve<T>(AsyncValue<Map<String, Object?>> raw, SettingSpec<T> spec) {
  final map = switch (raw) {
    AsyncData(:final value) => value,
    // 还没读出来时用默认值，而不是抛或者卡住 ——
    // 首帧就得有一套能用的配置，否则应用启动会闪一下。
    _ => const <String, Object?>{},
  };

  final stored = map[spec.key];
  if (stored == null) return spec.defaultValue;
  try {
    return spec.decode(stored);
  } on Object {
    return spec.defaultValue;
  }
}

/// 在 **provider 里**读一项配置。
T settingOf<T>(Ref ref, SettingSpec<T> spec) =>
    _resolve(ref.watch(rawSettingsProvider), spec);

/// 在 **widget 里**读一项配置。
///
/// 单独开一个入口是因为 Riverpod 3 的 `Ref` 与 `WidgetRef` 是两个类型 ——
/// 而两处解析用的是同一个 [_resolve]，不会分叉。
extension SettingsWidgetRef on WidgetRef {
  T setting<T>(SettingSpec<T> spec) =>
      _resolve(watch(rawSettingsProvider), spec);

  /// 遍历注册表时用 —— 那时手上只有擦掉类型的门面。
  Object? settingDynamic(SettingSpecBase spec) {
    final raw = watch(rawSettingsProvider);
    final map = switch (raw) {
      AsyncData(:final value) => value,
      _ => const <String, Object?>{},
    };
    final stored = map[spec.key];
    if (stored == null) return spec.defaultValueDynamic;
    try {
      return spec.decodeDynamic(stored);
    } on Object {
      return spec.defaultValueDynamic;
    }
  }
}

/// 写一项配置。
final class SettingsWriter {
  const SettingsWriter(this._ref);

  final Ref _ref;

  Future<void> set<T>(SettingSpec<T> spec, T value) {
    final error = spec.validate?.call(value);
    if (error != null) {
      // 校验不过不写。**抛而不是静默丢弃** —— 静默的话界面会显示
      // 「已保存」而实际没存，那是最难查的一类不一致。
      throw ArgumentError.value(value, spec.key, error);
    }
    return _ref
        .read(settingsRepositoryProvider)
        .put(spec.key, spec.encode(value), scope: spec.scope.wireName);
  }

  /// 遍历注册表时用的写入口。校验与编码都走门面。
  Future<void> setDynamic(SettingSpecBase spec, Object? value) {
    final error = spec.validateDynamic(value);
    if (error != null) {
      throw ArgumentError.value(value, spec.key, error);
    }
    return _ref
        .read(settingsRepositoryProvider)
        .put(spec.key, spec.encodeDynamic(value), scope: spec.scope.wireName);
  }

  /// 恢复某项的默认值。
  Future<void> reset(SettingSpecBase spec) =>
      _ref.read(settingsRepositoryProvider).remove(spec.key);
}

final settingsWriterProvider = Provider<SettingsWriter>(SettingsWriter.new);

/// 配置存取的**抽象接口**（module-map：`domain/repositories/` 只有接口）。
///
/// 存的是 `key → JSON 值`，不认识 `SettingSpec` —— 那是 feature 的事。
/// 这一层只管「把这段 JSON 存到这个 key 上」。
library;

abstract interface class SettingsRepository {
  /// 全部已存的配置。**未设过的 key 不在里面**，
  /// 由读取层用默认值补（FR-CFG-01）。
  Future<Map<String, Object?>> loadAll();

  /// 同上，但持续推送 —— 改一项配置，界面立刻跟着变。
  Stream<Map<String, Object?>> watchAll();

  /// 写一项。[scope] 决定它参不参与同步与导出（settings-spec §1）。
  Future<void> put(String key, Object? value, {required String scope});

  /// 删一项 —— 等同于「恢复默认」，因为读不到就用默认值。
  ///
  /// **不是写入默认值**：写进去的话，将来改了默认值，
  /// 那些「其实没设过」的用户不会跟着变。
  Future<void> remove(String key);
}

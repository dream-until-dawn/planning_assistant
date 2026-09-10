/// 整库导出/导入的端口（FR-DATA-04）。
///
/// **为什么要有这个抽象**：备份服务住在 `features/data_transfer/application/`，
/// 而 feature 的 application 层不得依赖 `data/` 的具体实现
/// （module-map §3，有守卫盯着）。`ExportService` 是 data 层的类，
/// 所以中间隔一个端口，由组合根把实现接上 —— 与 `TaskRepository`
/// 那一套是同一个办法。
library;

/// **进出都是字符串，不是 `Map`。**
///
/// 编解码那两个函数（`encodeExportBundle` / `decodeExportBundle`）住在
/// `data/dto/`，与格式契约放在一起 —— 而备份服务够不着 data 层。
/// 让端口收发 `Map` 的话，服务就得自己 `jsonEncode`，于是**格式知识
/// 分散到了两个层**：哪天缩进或顶层校验改了，只会改一边。
abstract interface class ExportPort {
  /// 导出整库，返回可直接落盘的 JSON 文本。
  ///
  /// [appVersion] / [deviceId] / [exportedAt] 由调用方注入 ——
  /// 在实现里现取的话导出结果就不可复现，往返测试也无从断言。
  Future<String> exportJson({
    required String appVersion,
    required String deviceId,
    required DateTime exportedAt,
  });

  /// 导入一份 JSON 文本，**先清库再写入**（不做增量合并，理由见实现）。
  ///
  /// 文本坏掉或包不合法时**抛异常，且库没被动过** ——
  /// 那条性质由 `export_import_test` 的「坏包不写进库」盯着。
  Future<void> importJson(String json);
}

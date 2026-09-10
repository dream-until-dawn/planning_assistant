/// 备份文件放在哪、怎么读写（FR-DATA-05 的落地面）。
///
/// ## V1 的备份是**应用内**的
///
/// 文件写在应用自己的文档目录里：应用内看得见、列得出、恢复得回来，
/// 但**用户拿不到应用外面去**。分享到别的应用（分享面板 / SAF 选目录）
/// 要引一个新插件，而引插件在这个项目里是一次技术栈决定
/// （版本矩阵 + 探针 + ADR），不该顺手塞进 M4 收尾。
///
/// 这条限制是**写下来的取舍，不是没做完**：备份与恢复本身完整可用，
/// 缺的是「把那个文件递给别的应用」。见 roadmap M5。
///
/// ## 为什么是接口
///
/// 备份服务要能在没有文件系统的地方测（widget 测试跑在内存里）。
/// 而这一层薄到只剩「列目录、读写文件」—— 换成假实现之后
/// 被替换掉的东西里没有任何判断。
library;

/// 一份备份。
typedef BackupFile = ({String name, DateTime createdAt, int sizeBytes});

abstract interface class BackupStore {
  /// 全部备份，**按创建时间倒序**（新的在前）。
  ///
  /// 顺序定在这儿而不是让每个调用方自己排：保留策略要删「最旧的几份」，
  /// 界面要「最新的在上面」，两处各排一次迟早排反一个。
  Future<List<BackupFile>> list();

  Future<BackupFile> write(String name, String contents);

  Future<String> read(String name);

  Future<void> delete(String name);
}

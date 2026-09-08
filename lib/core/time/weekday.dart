/// 星期几。
///
/// **放 core 而不是某个 feature**：三处都需要它 —— 重复规则（`BYDAY`）、
/// 配置项 `view.firstDayOfWeek`、日历的表头与格子起始日。
/// 留在 `features/task/` 里的话，设置和日历要跨 feature 去取一个
/// 「星期二」，而那不是任务这个 feature 的知识。
library;

enum Weekday {
  monday('MO', 'monday', '一', 1),
  tuesday('TU', 'tuesday', '二', 2),
  wednesday('WE', 'wednesday', '三', 3),
  thursday('TH', 'thursday', '四', 4),
  friday('FR', 'friday', '五', 5),
  saturday('SA', 'saturday', '六', 6),
  sunday('SU', 'sunday', '日', 7);

  const Weekday(this.rruleName, this.storageKey, this.label, this.isoNumber);

  /// RFC 5545 的 `BYDAY` 缩写。**这个不能改** —— 它是外部格式。
  final String rruleName;

  /// 存进配置表的字符串（settings-spec §2 里 `view.firstDayOfWeek` 写的
  /// 就是 `monday` 这种）。
  ///
  /// **与 [rruleName] 分开**：一个是 RFC 的词，一个是我们自己配置的词，
  /// 现在恰好一一对应，但它们的变更理由不同 —— 合成一个的话，
  /// 哪天要换配置的写法就会牵动 RRULE 的编码。
  ///
  /// **也与 `name` 分开**：`name` 会随 Dart 标识符重命名而变，
  /// 拿它当存储值等于静默改写用户的配置（同 registry 里那段注释）。
  final String storageKey;

  /// 给人看的名字。
  // TODO(M4): 走 l10n 资源（NFR-A11Y-04）
  final String label;

  /// `DateTime.weekday` 的取值（周一 = 1 … 周日 = 7）。
  final int isoNumber;

  static Weekday fromIso(int iso) =>
      values.firstWhere((w) => w.isoNumber == iso);

  /// 认不出来回落到周一（配置项的默认值，settings-spec §2）。
  static Weekday fromStorageKey(String? key) {
    for (final w in values) {
      if (w.storageKey == key) return w;
    }
    return Weekday.monday;
  }
}

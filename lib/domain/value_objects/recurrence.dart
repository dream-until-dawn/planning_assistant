/// 重复规则。存储形态是 **RFC 5545 的 `RRULE:` 字符串**（ADR-0004）。
///
/// 本文件是**项目内唯一允许编解码 RRULE 的地方**。
/// 直接调用 `RecurrenceRule.toString()` 是被守卫禁止的 —— 理由见 [encodeRrule]。
library;

import 'package:meta/meta.dart';
import 'package:rrule/rrule.dart';

/// 规范形编码器。
///
/// **必须显式传 `isTimeUtc: true`**：`rrule` 的默认编码会丢掉 `UNTIL` 的 `Z` 后缀
/// （实测，见 environment-notes §2.2）。丢掉 `Z` 之后的串按 RFC 5545 是
/// **浮动本地时间**，而 DTSTART 带 TZID 时该值 MUST 为真 UTC ——
/// 也就是说，缺了它我们自己的导出会产出不合规的规则串。
///
/// 更隐蔽的是：`rrule` 解析无 `Z` 的串仍得到等值规则，
/// 所以**只做语义往返断言的测试恒绿**，只有服务端与 `.ics` 互通会错。
const _canonicalCodec = RecurrenceRuleStringCodec(
  toStringOptions: RecurrenceRuleToStringOptions(isTimeUtc: true),
);

/// 把规则编码成**规范形**。项目内唯一的编码出口。
String encodeRrule(RecurrenceRule rule) => _canonicalCodec.encode(rule);

/// 解析 RRULE 串。非法输入一律转成 [FormatException]。
///
/// **为什么要包一层**：实测 `rrule` 对畸形输入抛的不是 `FormatException`，
/// 而是解析内部的 `TypeError`（`Null check operator used on a null value`）。
/// 直接放它出去有两个问题：调用方没法用 `on FormatException` 处理；
/// 而且库里一条脏数据会让应用**崩溃**，而不是被识别成「这条规则读不出来」。
RecurrenceRule decodeRrule(String value) {
  try {
    return RecurrenceRule.fromString(value);
  } on FormatException {
    rethrow;
  } catch (e) {
    // 刻意宽捕：库没有承诺过它只抛哪几类异常，而这一层的职责就是
    // 把「解析失败」这件事表达成一个稳定的类型。
    throw FormatException('不是合法的 RRULE 串（$e）', value);
  }
}

/// 规则串是否已是规范形。
///
/// 这是一条**数据不变量**（recurrence-engine §2.3）：库中任何一条
/// `tasks.recurrenceRule` 都必须满足它。它与编解码器自身的性质不同 ——
/// C1/C2/C3 考察「编解码器对不对」，这条考察「这条数据有没有真的走过编解码器」。
/// 某条写入路径漏了规范化时，只有它会红。
bool isCanonicalRrule(String value) {
  try {
    return encodeRrule(decodeRrule(value)) == value;
  } on FormatException {
    return false;
  }
}

/// 重复规则值对象。
@immutable
final class Recurrence {
  const Recurrence._(this.canonical, this.rule);

  /// 从任意合法 RRULE 串构造，**自动规范化**。
  ///
  /// 一切入库路径都应经过这里，而不是把外部原串直接存下去。
  factory Recurrence.parse(String raw) {
    final rule = decodeRrule(raw);
    return Recurrence._(encodeRrule(rule), rule);
  }

  /// 规范形串，用于存储与比较。
  final String canonical;

  /// 解析后的规则，用于展开。
  final RecurrenceRule rule;

  /// `UNTIL`（真 UTC）。无结束日期时为 null。
  ///
  /// **它是真 UTC，不是墙钟**。喂给展开之前必须经
  /// `TimeZoneResolver.untilForExpansion()` 换算，见 recurrence-engine §2.2。
  DateTime? get untilUtc => rule.until;

  int? get count => rule.count;

  bool get hasEnd => untilUtc != null || count != null;

  @override
  bool operator ==(Object other) =>
      other is Recurrence && other.canonical == canonical;

  @override
  int get hashCode => canonical.hashCode;

  @override
  String toString() => canonical;
}

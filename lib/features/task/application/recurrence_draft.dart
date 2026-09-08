/// 编辑器里的重复规则（FR-TASK-03/04）。
///
/// **这是「用户在界面上选了什么」，不是 RRULE。** 两者不是一一对应的：
/// RRULE 能表达的东西远多于界面暴露的那几种，而界面选出的东西
/// 必须能编码成合规的 RRULE。所以这一层只覆盖 FR-TASK-03 点名的几种，
/// 剩下的留给「高级：直接填 RRULE」（V2+）。
///
/// 编码的方向是单向的：草稿 → RRULE。**不做 RRULE → 草稿的反解** ——
/// 那需要处理界面表达不了的规则，而「打开一条规则却显示不出来」
/// 比不支持编辑更糟。编辑已有重复任务时该怎么办，见 TODO。
library;

import 'package:meta/meta.dart';

import '../../../core/time/plan_date.dart';

/// 重复频率。**只有 FR-TASK-03 点名的四种。**
enum RecurrenceFrequency {
  daily('DAILY', '每天'),
  weekly('WEEKLY', '每周'),
  monthly('MONTHLY', '每月'),
  yearly('YEARLY', '每年');

  const RecurrenceFrequency(this.rruleName, this.label);

  final String rruleName;
  final String label;
}

/// 结束条件（FR-TASK-04）。
enum RecurrenceEndMode {
  never('永不结束'),
  count('重复 N 次'),
  until('到某天为止');

  const RecurrenceEndMode(this.label);

  final String label;
}

/// 周几。`rrule` 包用的是两字母缩写。
enum Weekday {
  monday('MO', '一', 1),
  tuesday('TU', '二', 2),
  wednesday('WE', '三', 3),
  thursday('TH', '四', 4),
  friday('FR', '五', 5),
  saturday('SA', '六', 6),
  sunday('SU', '日', 7);

  const Weekday(this.rruleName, this.label, this.isoNumber);

  final String rruleName;
  final String label;

  /// `DateTime.weekday` 的取值（周一 = 1）。
  final int isoNumber;

  static Weekday fromIso(int iso) =>
      values.firstWhere((w) => w.isoNumber == iso);
}

@immutable
final class RecurrenceDraft {
  const RecurrenceDraft({
    this.enabled = false,
    this.frequency = RecurrenceFrequency.daily,
    this.interval = 1,
    this.weekdays = const {},
    this.endMode = RecurrenceEndMode.never,
    this.count = 10,
    this.until,
  });

  /// 关掉时整条规则不生效 —— 保留其余字段，方便用户来回切着看。
  final bool enabled;

  final RecurrenceFrequency frequency;

  /// 每 N 天/周/月/年。**下限 1** —— 0 会让规则退化成无限循环同一天。
  final int interval;

  /// 每周哪几天。**仅 [RecurrenceFrequency.weekly] 用**。
  ///
  /// 空集合表示「跟随开始日期那一天」—— 这是 RRULE 的默认行为
  /// （不写 BYDAY 时按 DTSTART 的星期几重复），不是「一天都不重复」。
  final Set<Weekday> weekdays;

  final RecurrenceEndMode endMode;

  /// 重复次数。**含首次** —— 与 RFC 5545 的 COUNT 一致。
  final int count;

  /// 到这一天为止（含当天）。
  final PlanDate? until;

  RecurrenceDraft copyWith({
    bool? enabled,
    RecurrenceFrequency? frequency,
    int? interval,
    Set<Weekday>? weekdays,
    RecurrenceEndMode? endMode,
    int? count,
    PlanDate? until,
  }) => RecurrenceDraft(
    enabled: enabled ?? this.enabled,
    frequency: frequency ?? this.frequency,
    interval: interval ?? this.interval,
    weekdays: weekdays ?? this.weekdays,
    endMode: endMode ?? this.endMode,
    count: count ?? this.count,
    until: until ?? this.until,
  );

  RecurrenceDraft toggleWeekday(Weekday day) => copyWith(
    weekdays: weekdays.contains(day)
        ? (weekdays.toSet()..remove(day))
        : (weekdays.toSet()..add(day)),
  );

  /// 能不能编码成规则。
  ///
  /// 「到某天为止」必须真的选了那一天 —— 没选就编码的话会得到一条
  /// 永不结束的规则，而用户以为它会停。
  String? get blockedReason {
    if (!enabled) return null;
    if (interval < 1) return '间隔至少是 1';
    if (endMode == RecurrenceEndMode.count && count < 1) return '次数至少是 1';
    if (endMode == RecurrenceEndMode.until && until == null) {
      return '选一个结束日期';
    }
    return null;
  }

  bool get isValid => blockedReason == null;

  /// 编码成 RRULE 串。关闭或不合法时返回 null。
  ///
  /// **带 `RRULE:` 前缀。** 我一度在这里写「不带前缀，与 Recurrence.parse
  /// 的期望一致」—— 没验就写，而且是错的：`rrule` 包会直接抛
  /// 「Content line is not an RRULE but a FREQ」。
  ///
  /// 拼出来的是「一个合法的 RRULE」，不保证是**规范形**（部件顺序可能不同），
  /// 而存进库的必须是规范形（data-model 的往返要求），
  /// 所以调用方要经 `Recurrence.parse(...).canonical`。
  String? toRrule() {
    if (!enabled || !isValid) return null;

    final parts = <String>['FREQ=${frequency.rruleName}'];
    if (interval != 1) parts.add('INTERVAL=$interval');

    if (frequency == RecurrenceFrequency.weekly && weekdays.isNotEmpty) {
      // 按周一到周日排序输出，而不是集合的迭代序 ——
      // 否则同一份选择可能编出两个不同的串，规范形往返会失败。
      final sorted = weekdays.toList()
        ..sort((a, b) => a.isoNumber.compareTo(b.isoNumber));
      parts.add('BYDAY=${sorted.map((w) => w.rruleName).join(',')}');
    }

    switch (endMode) {
      case RecurrenceEndMode.never:
        break;
      case RecurrenceEndMode.count:
        parts.add('COUNT=$count');
      case RecurrenceEndMode.until:
        final u = until!;
        // UNTIL 必须带 Z 后缀才合规（M1 那次「严格往返」翻车就是栽在这）。
        // 取当天的 23:59:59Z：UNTIL 是闭区间，用 00:00 会把当天排除掉。
        parts.add(
          'UNTIL='
          '${u.year.toString().padLeft(4, '0')}'
          '${u.month.toString().padLeft(2, '0')}'
          '${u.day.toString().padLeft(2, '0')}'
          'T235959Z',
        );
    }

    return 'RRULE:${parts.join(';')}';
  }

  /// 给人看的一句话，如「每 2 周的一、三、五」。
  String describe() {
    if (!enabled) return '不重复';
    final every = interval == 1 ? '每' : '每 $interval ';
    final unit = switch (frequency) {
      RecurrenceFrequency.daily => '天',
      RecurrenceFrequency.weekly => '周',
      RecurrenceFrequency.monthly => '月',
      RecurrenceFrequency.yearly => '年',
    };

    final buffer = StringBuffer('$every$unit');
    if (frequency == RecurrenceFrequency.weekly && weekdays.isNotEmpty) {
      final sorted = weekdays.toList()
        ..sort((a, b) => a.isoNumber.compareTo(b.isoNumber));
      buffer.write('的${sorted.map((w) => w.label).join('、')}');
    }
    switch (endMode) {
      case RecurrenceEndMode.never:
        break;
      case RecurrenceEndMode.count:
        buffer.write('，共 $count 次');
      case RecurrenceEndMode.until:
        if (until != null) buffer.write('，到 $until 为止');
    }
    return buffer.toString();
  }
}

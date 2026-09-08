/// 编辑器里的重复规则（FR-TASK-03/04）。
///
/// **这是「用户在界面上选了什么」，不是 RRULE。** 两者不是一一对应的：
/// RRULE 能表达的东西远多于界面暴露的那几种，而界面选出的东西
/// 必须能编码成合规的 RRULE。所以这一层只覆盖 FR-TASK-03 点名的几种，
/// 剩下的留给「高级：直接填 RRULE」（V2+）。
///
/// 编码的主方向是单向的：草稿 → RRULE。反方向只有 [RecurrenceDraft.fromRrule]，
/// 而且**只为显示**：认不出来的规则返回 null，由调用方退回一句「重复」。
/// 拿它去做**编辑**是另一回事 —— 把一条界面表达不了的规则显示成一条
/// 能表达的，用户一保存就悄悄改写了自己的规则。那件事见 TODO。
library;

import 'package:meta/meta.dart';
import 'package:rrule/rrule.dart';

import '../../../core/patch/unset.dart';
import '../../../core/time/plan_date.dart';
import '../../../domain/value_objects/recurrence.dart';

/// 重复频率。**只有 FR-TASK-03 点名的四种。**
enum RecurrenceFrequency {
  daily('DAILY', '每天', '天'),
  weekly('WEEKLY', '每周', '周'),
  monthly('MONTHLY', '每月', '月'),
  yearly('YEARLY', '每年', '年');

  const RecurrenceFrequency(this.rruleName, this.label, this.unitLabel);

  final String rruleName;

  /// 选项上的名字，如「每周」。
  final String label;

  /// 光是单位，如「周」。给「每 2 周」这种带间隔的说法用。
  /// 放枚举上而不是在 [RecurrenceDraft.describe] 里再 switch 一遍 ——
  /// 界面上的间隔控件也要说同一句话。
  final String unitLabel;
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

  /// [until] 走 [unset] 哨兵，其余字段非空所以用 `??` 就够。
  ///
  /// 一度写成 `until: until ?? this.until` —— 那样**清不掉结束日期**：
  /// 传 `null` 的意思变成了「别动」。见 `core/patch/unset.dart` 开头那段。
  RecurrenceDraft copyWith({
    bool? enabled,
    RecurrenceFrequency? frequency,
    int? interval,
    Set<Weekday>? weekdays,
    RecurrenceEndMode? endMode,
    int? count,
    Object? until = unset,
  }) => RecurrenceDraft(
    enabled: enabled ?? this.enabled,
    frequency: frequency ?? this.frequency,
    interval: interval ?? this.interval,
    weekdays: weekdays ?? this.weekdays,
    endMode: endMode ?? this.endMode,
    count: count ?? this.count,
    until: patch(until, this.until),
  );

  /// 频率的两边对照。用列表而不是 `switch`：`Frequency` 是个带 `==`
  /// 的普通类、不是枚举，穷尽性检查本来就帮不上忙。
  static const List<(Frequency, RecurrenceFrequency)> _frequencies = [
    (Frequency.daily, RecurrenceFrequency.daily),
    (Frequency.weekly, RecurrenceFrequency.weekly),
    (Frequency.monthly, RecurrenceFrequency.monthly),
    (Frequency.yearly, RecurrenceFrequency.yearly),
  ];

  /// 从一条规则还原成草稿，**只为显示**；认不出来返回 null。
  ///
  /// 「认不出来」不是错误，是**这个界面表达不了**。库里的规则可能来自
  /// 导入或同步，RRULE 能表达的东西远多于这几个控件。那时正确的做法是
  /// 说一句「重复」，而不是挑几个认得的部件拼一句**说错的**话 ——
  /// 卡片上一度就是那样：`INTERVAL=3` 的规则显示成「每周」。
  ///
  /// 表达不了的例子：`BYDAY=-1FR`（每月最后一个周五）、`BYMONTHDAY=15`、
  /// `BYSETPOS`。FR-TASK-03 点了前两种的名，界面还没做。
  // TODO(M3): 补 BYMONTHDAY / 带序号的 BYDAY，那时这里也要跟着认。
  static RecurrenceDraft? fromRrule(Recurrence recurrence) {
    final r = recurrence.rule;

    RecurrenceFrequency? frequency;
    for (final (from, to) in _frequencies) {
      if (r.frequency == from) frequency = to;
    }
    // 秒/分/小时级的重复这个界面没有，也不该假装有。
    if (frequency == null) return null;

    // 任何一个「界面上没有的部件」都直接判为认不出来。
    // **列全**而不是只看眼前用得上的那几个：漏掉一个，带那个部件的规则
    // 会被显示成一条不含它的规则，而那句话是错的。
    if (r.bySeconds.isNotEmpty ||
        r.byMinutes.isNotEmpty ||
        r.byHours.isNotEmpty ||
        r.byMonthDays.isNotEmpty ||
        r.byYearDays.isNotEmpty ||
        r.byWeeks.isNotEmpty ||
        r.byMonths.isNotEmpty ||
        r.bySetPositions.isNotEmpty) {
      return null;
    }
    // 带序号的星期（`-1FR` = 最后一个周五）与「每周五」是两回事。
    if (r.byWeekDays.any((d) => d.hasOccurrence)) return null;
    // BYDAY 只在「每周」下有对应控件。
    if (r.byWeekDays.isNotEmpty && frequency != RecurrenceFrequency.weekly) {
      return null;
    }

    final until = r.until;
    final count = r.count;
    return RecurrenceDraft(
      enabled: true,
      frequency: frequency,
      // 不写 INTERVAL 等同于 1（RFC 5545）。
      interval: r.interval ?? 1,
      weekdays: {for (final d in r.byWeekDays) Weekday.fromIso(d.day)},
      endMode: until != null
          ? RecurrenceEndMode.until
          : count != null
          ? RecurrenceEndMode.count
          : RecurrenceEndMode.never,
      // 没有 COUNT 时留默认值，免得用户切到「重复 N 次」看见一个 0。
      count: count ?? 10,
      // UNTIL 是真 UTC。[toRrule] 写的是当天 23:59:59Z，取年月日就回到原来
      // 那天。外来规则若把 UNTIL 定在别的时刻，东八区可能差一天 ——
      // 只用于显示，接受；真要参与展开必须走 `untilForExpansion()`。
      until: until == null
          ? null
          : PlanDate(until.year, until.month, until.day),
    );
  }

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

  /// 给人看的一句话，如「每 2 周的一、三、五，共 6 次」。
  ///
  /// [withEnd] 关掉时省去结束条件那一截，给卡片副信息用 ——
  /// 那里只有一行且会截断，「每 3 周的一、三、五」说的是**重复什么**，
  /// 已经完整；什么时候停是编辑器里的细节。
  /// 省略与说错是两回事：省略后的句子仍然为真。
  String describe({bool withEnd = true}) {
    if (!enabled) return '不重复';
    final every = interval == 1 ? '每' : '每 $interval ';
    final buffer = StringBuffer('$every${frequency.unitLabel}');
    if (frequency == RecurrenceFrequency.weekly && weekdays.isNotEmpty) {
      final sorted = weekdays.toList()
        ..sort((a, b) => a.isoNumber.compareTo(b.isoNumber));
      buffer.write('的${sorted.map((w) => w.label).join('、')}');
    }
    if (withEnd) {
      switch (endMode) {
        case RecurrenceEndMode.never:
          break;
        case RecurrenceEndMode.count:
          buffer.write('，共 $count 次');
        case RecurrenceEndMode.until:
          if (until != null) buffer.write('，到 $until 为止');
      }
    }
    return buffer.toString();
  }
}

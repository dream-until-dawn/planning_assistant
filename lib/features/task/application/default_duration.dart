/// 新建单事项时，默认的结束离开始多远（配置项 `behavior.defaultDuration`）。
///
/// ## 为什么是枚举而不是「一个分钟数」
///
/// 四个档位里有一个是「**到当天结束**」——它跟着开始那天走，
/// 不是一个固定时长。硬塞进分钟数的话就得挑个哨兵值（`0`？`-1`？），
/// 而那会让「时长」这个字段里同时住着两种意思。
///
/// 顺带也回答了「为什么不给输入框」：能填任意数字的框，第一件事就是
/// 有人填 0 —— 结束等于开始的任务在甘特上是根零长的条、在时间轴上
/// 高度为零。同 `trashRetentionDays` 那条的理由。
library;

import '../../../core/time/date_and_minute.dart';
import '../../../core/time/minute_of_day.dart';

enum DefaultTaskDuration {
  oneHour('1h', '1 小时', minutes: 60),
  threeHours('3h', '3 小时', minutes: 180),

  /// 默认值。**它让默认新建的任务跨午夜** —— 下午三点建的事排到明天
  /// 下午三点，于是它在日历上是一条两天的横条、在列表与时间轴里
  /// 两天都出现。
  ///
  /// 那不一定是错的（「这件事我今明两天做」很常见），但也不该由实现
  /// 替所有人定死，所以才有这个配置项。用户 2026-09-09 定的默认值。
  oneDay('24h', '24 小时', minutes: minutesPerDay),

  /// 到开始那天的最后一分钟。**不是固定时长** —— 早上八点建的是十六
  /// 小时，晚上十一点建的是一小时。
  endOfDay('endOfDay', '到当天结束');

  const DefaultTaskDuration(this.storageKey, this.label, {this.minutes});

  /// 存进配置的字符串。**与枚举名解耦**：改 Dart 端的名字不该让
  /// 用户已存的配置失效（同 `ViewKind.storageKey`）。
  final String storageKey;

  final String label;

  /// 固定时长的那几档是分钟数；[endOfDay] 没有。
  final int? minutes;

  static DefaultTaskDuration fromStorageKey(String? key) {
    for (final v in values) {
      if (v.storageKey == key) return v;
    }
    return DefaultTaskDuration.oneDay;
  }

  /// 从 [start] 算出默认结束。
  ///
  /// 固定时长那几档直接偏移（跨天由 `shiftFrom` 处理，它用 `floorDiv`，
  /// 负偏移也对）；[endOfDay] 取开始那天的 23:59。
  DateAndMinute endFrom(DateAndMinute start) => switch (minutes) {
    final int m => shiftFrom(start, m),
    null => DateAndMinute(start.date, MinuteOfDay.endOfDay),
  };

  // **这一栏只管定时任务。** 一度还有个 `endDateFrom`，把时长折成天数
  // 给全天任务算结束日期。用户 2026-09-10 定下「全天只选一个日期」之后
  // 它没有调用方了 —— 全天就是一天，没有「多长」可言。
  //
  // 删掉而不是留着：一个没人调的换算函数与僵尸豁免是同一个形状，
  // 下一个人无从判断它是「还没接上」还是「不该接」。
}

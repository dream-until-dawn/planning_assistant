/// 时区换算的**差分测试**。
///
/// 思路来自评审方：与其靠人再想出几个边界用例，不如把
/// **「实现对不对」变成「实现与一个独立定义的语义是否一致」**。
///
/// oracle 的定义直接取自 recurrence-engine §4.1 的语义：
///
///   resolve(W).instant = 满足「当地墙钟 ≥ W」的**最小** epoch
///
/// 这一条同时覆盖三种情形：
///  · 正常时刻 → 精确匹配
///  · 春季跳表（W 不存在）→ 该时段后第一个合法时刻
///  · 秋季回拨（W 重复）→ 较早的那个
///
/// oracle 用**暴力扫描**实现，不共用被测实现的任何逻辑 ——
/// 共用就成了「对着实现抄」，跨模块的那种。
///
/// 它的价值不在某一次抓到的缺陷，而在于：改 `resolve()`、换时区库、
/// 加新规则时，一次覆盖几千个组合，补上手写用例表覆盖不到的那部分。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/local_wall_time.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/core/time/time_zone_resolver.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const _resolver = TzTimeZoneResolver();

/// 时区样本按**行为特征**选，不是「多挑几个」。
const _zones = <String, String>{
  'Asia/Shanghai': '正偏移，无 DST',
  'Etc/UTC': '零偏移对照',
  'Pacific/Kiritimati': 'UTC+14，最东',
  'Pacific/Niue': 'UTC-11，最西',
  'America/New_York': '北半球 DST，负偏移',
  'Europe/Dublin': '北半球 DST，近零偏移',
  'Australia/Sydney': '南半球 DST，正偏移',
  'Australia/Lord_Howe': '**30 分钟** DST 跳变',
  'Pacific/Chatham': '45 分钟偏移 + DST',
  'America/Santiago': '南美 DST，跳变在午夜',
  'Asia/Kathmandu': '45 分钟偏移，无 DST',
  'Africa/Cairo': '近年重启 DST',
};

/// oracle：暴力扫描出「当地墙钟 ≥ target」的最小 epoch。
///
/// 步长 1 秒、范围 ±2 天。慢，但**独立** —— 这正是它的价值。
DateTime? _oracle(tz.Location loc, DateTime targetWall) {
  final targetMs = targetWall.millisecondsSinceEpoch;
  const dayMs = Duration.millisecondsPerDay;
  const stepMs = Duration.millisecondsPerMinute;

  for (var t = targetMs - 2 * dayMs; t <= targetMs + 2 * dayMs; t += stepMs) {
    final l = tz.TZDateTime.fromMillisecondsSinceEpoch(loc, t);
    final wall = DateTime.utc(l.year, l.month, l.day, l.hour, l.minute);
    if (!wall.isBefore(targetWall)) {
      return DateTime.fromMillisecondsSinceEpoch(t, isUtc: true);
    }
  }
  return null;
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('差分：实现与独立 oracle 在数千组合上一致', () {
    // 日期覆盖各时区的 DST 跳变周边 + 全年采样。
    final dates = <PlanDate>[
      for (var m = 1; m <= 12; m++) PlanDate(2026, m, 1),
      for (var m = 1; m <= 12; m++) PlanDate(2026, m, 15),
      // 已知跳变日及其前后
      const PlanDate(2026, 3, 7), const PlanDate(2026, 3, 8),
      const PlanDate(2026, 3, 9), const PlanDate(2026, 3, 29),
      const PlanDate(2026, 4, 5), const PlanDate(2026, 9, 6),
      const PlanDate(2026, 10, 4), const PlanDate(2026, 10, 25),
      const PlanDate(2026, 11, 1), const PlanDate(2028, 2, 29),
    ];
    const times = <(int, int)>[
      (0, 0),
      (0, 30),
      (1, 0),
      (1, 30),
      (2, 0),
      (2, 15),
      (2, 30),
      (2, 45),
      (3, 0),
      (12, 0),
      (23, 0),
      (23, 59),
    ];

    final mismatches = <String>[];
    var compared = 0;

    for (final zone in _zones.keys) {
      final loc = tz.getLocation(zone);
      for (final date in dates) {
        for (final (h, mi) in times) {
          final wall = LocalWallTime(
            date: date,
            minuteOfDay: MinuteOfDay.of(h, mi),
            timeZoneId: zone,
          );
          final expected = _oracle(loc, wall.toFakeUtc());
          if (expected == null) continue;
          compared++;
          final actual = _resolver.resolve(wall).instant;
          if (actual != expected) {
            mismatches.add(
              '  $zone ${date}T${MinuteOfDay.of(h, mi)}  '
              'oracle=${expected.toIso8601String()}  '
              '实现=${actual.toIso8601String()}',
            );
          }
        }
      }
    }

    expect(compared, greaterThan(3000), reason: '样本量不足时这条测试没有意义');
    expect(
      mismatches,
      isEmpty,
      reason:
          '共比对 $compared 组，${mismatches.length} 组不一致：\n'
          '${mismatches.take(20).join('\n')}',
    );
  });

  test('不变式：resolve() 的 instant 必须落在整分钟边界上', () {
    // 输入是分钟粒度的墙钟，输出就不该带秒。
    //
    // **这条防的是一类，不是一个**：它不依赖「猜到问题出在二分精度」。
    // 初版二分只收敛到 1 分钟，DST 空隙里的结果带最多 60 秒误差，
    // 而当时那条断言 instant 的用例恰好挑中了空隙里唯一收敛精确的输入（02:30）。
    // 有了这条不变式，那 14 个错误输入会全部变红。
    final offenders = <String>[];
    for (final zone in _zones.keys) {
      for (final date in [
        const PlanDate(2026, 3, 8),
        const PlanDate(2026, 3, 29),
        const PlanDate(2026, 4, 5),
        const PlanDate(2026, 9, 6),
        const PlanDate(2026, 10, 4),
        const PlanDate(2026, 11, 1),
        const PlanDate(2026, 6, 15),
      ]) {
        for (var h = 0; h < 24; h++) {
          for (final mi in [0, 1, 15, 30, 45, 59]) {
            final r = _resolver.resolve(
              LocalWallTime(
                date: date,
                minuteOfDay: MinuteOfDay.of(h, mi),
                timeZoneId: zone,
              ),
            );
            if (r.instant.second != 0 || r.instant.millisecond != 0) {
              offenders.add(
                '  $zone $date ${MinuteOfDay.of(h, mi)} → ${r.instant}',
              );
            }
          }
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          '${offenders.length} 处 instant 带了秒：\n'
          '${offenders.take(20).join('\n')}',
    );
  });

  test('B1 回归：DST 空隙内每一个输入都换算到同一个绝对时刻', () {
    // 评审方要求逐个断言，不能只挑 02:30。
    // America/New_York 2026-03-08：02:00–02:59 全部不存在。
    for (final mi in [0, 1, 15, 30, 45, 59]) {
      final r = _resolver.resolve(
        LocalWallTime(
          date: const PlanDate(2026, 3, 8),
          minuteOfDay: MinuteOfDay.of(2, mi),
          timeZoneId: 'America/New_York',
        ),
      );
      expect(
        r.instant,
        DateTime.utc(2026, 3, 8, 7),
        reason: '02:${mi.toString().padLeft(2, '0')} 应换算到 07:00:00.000Z',
      );
      expect(r.effectiveWallTime.minuteOfDay, MinuteOfDay.of(3, 0));
      expect(r.dstAdjusted, isTrue);
    }
  });

  test('30 分钟 DST 跳变（Lord_Howe）同样精确', () {
    // Lord_Howe 的 DST 只跳 30 分钟，是最容易被「按小时假设」写错的一种。
    for (final mi in [0, 15, 30, 45]) {
      final r = _resolver.resolve(
        LocalWallTime(
          date: const PlanDate(2026, 10, 4),
          minuteOfDay: MinuteOfDay.of(2, mi),
          timeZoneId: 'Australia/Lord_Howe',
        ),
      );
      expect(r.instant.second, 0);
      expect(r.instant.millisecond, 0);
    }
  });
}

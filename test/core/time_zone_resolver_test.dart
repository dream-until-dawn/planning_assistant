/// 时区换算的行为契约。
///
/// **期望值全部手算或来自 IANA tz 规则，不是「跑一遍看输出」**
/// （testing-strategy §1.1）。每条注明依据。
///
/// 这些用例对应 recurrence-engine §6.5 的 R-40..R-43，
/// 是 M1 里最容易写出「永远绿」测试的地方 —— 因为国内没有 DST，
/// 不写这些用例本地也永远不会红。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/local_wall_time.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/core/time/time_zone_resolver.dart';
import 'package:timezone/data/latest.dart' as tzdata;

const _resolver = TzTimeZoneResolver();

LocalWallTime wall(String zone, int y, int mo, int d, int h, int mi) =>
    LocalWallTime(
      date: PlanDate(y, mo, d),
      minuteOfDay: MinuteOfDay.of(h, mi),
      timeZoneId: zone,
    );

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('基本换算（无 DST 的时区）', () {
    test('Asia/Shanghai 恒为 UTC+8', () {
      // 手算：2026-09-08 09:00 +08:00 → 2026-09-08 01:00 UTC
      final r = _resolver.resolve(wall('Asia/Shanghai', 2026, 9, 8, 9, 0));
      expect(r.instant, DateTime.utc(2026, 9, 8, 1));
      expect(r.dstAdjusted, isFalse);
      expect(r.effectiveWallTime, wall('Asia/Shanghai', 2026, 9, 8, 9, 0));
    });

    test('往返恒等：toWallTime(toInstant(w)) == w', () {
      for (final zone in [
        'Asia/Shanghai',
        'Etc/UTC',
        'Pacific/Kiritimati',
        'Pacific/Niue',
        'America/New_York',
        'Europe/London',
      ]) {
        final w = wall(zone, 2026, 6, 15, 14, 30);
        final back = _resolver.toWallTime(_resolver.toInstant(w), zone);
        expect(back, w, reason: zone);
      }
    });
  });

  group('极端时区（UNTIL 边界用例的基础，recurrence-engine §6.1b）', () {
    test('Pacific/Kiritimati 是 UTC+14', () {
      // 手算：2026-09-30 23:00 +14:00 → 同日 09:00 UTC
      expect(
        _resolver.toInstant(wall('Pacific/Kiritimati', 2026, 9, 30, 23, 0)),
        DateTime.utc(2026, 9, 30, 9),
      );
    });

    test('Pacific/Niue 是 UTC-11', () {
      // 手算：2026-09-30 23:00 -11:00 → **次日** 10:00 UTC
      expect(
        _resolver.toInstant(wall('Pacific/Niue', 2026, 9, 30, 23, 0)),
        DateTime.utc(2026, 10, 1, 10),
        reason: '负偏移会让当地日期领先于 UTC 日期，这正是 UNTIL 容易错的原因',
      );
    });

    test('两个极端时区的同一墙钟相差 25 小时', () {
      final east = _resolver.toInstant(
        wall('Pacific/Kiritimati', 2026, 9, 30, 12, 0),
      );
      final west = _resolver.toInstant(
        wall('Pacific/Niue', 2026, 9, 30, 12, 0),
      );
      expect(west.difference(east), const Duration(hours: 25));
    });
  });

  group('DST 春季跳表（墙钟不存在）', () {
    // America/New_York 2026-03-08：02:00 EST → 03:00 EDT，02:00-02:59 不存在。
    // 依据 IANA tz 规则：美国 DST 于三月第二个周日 02:00 本地时间开始。
    // 2026-03-01 是周日，故第二个周日是 03-08。

    test('跳表前后的偏移确实不同（前提成立）', () {
      final before = _resolver.toInstant(
        wall('America/New_York', 2026, 3, 8, 1, 30),
      );
      final after = _resolver.toInstant(
        wall('America/New_York', 2026, 3, 8, 3, 30),
      );
      // 01:30 EST(-5) = 06:30 UTC；03:30 EDT(-4) = 07:30 UTC。相差 1 小时而非 2。
      expect(before, DateTime.utc(2026, 3, 8, 6, 30));
      expect(after, DateTime.utc(2026, 3, 8, 7, 30));
      expect(after.difference(before), const Duration(hours: 1));
    });

    test('不存在的 02:30 顺延到该时段后第一个合法时刻 03:00，而非 03:30', () {
      // 这是本项目的规定（recurrence-engine §4.1），**与 timezone 包的默认行为不同**：
      // 直接构造 TZDateTime(loc, 2026, 3, 8, 2, 30) 会得到 03:30（按偏移量平移）。
      // 我们要的是「尽可能接近用户设定的 02:30」，因此取第一个合法时刻。
      final r = _resolver.resolve(wall('America/New_York', 2026, 3, 8, 2, 30));

      expect(
        r.effectiveWallTime,
        wall('America/New_York', 2026, 3, 8, 3, 0),
        reason: '应为 03:00（第一个合法时刻），不是 03:30（按偏移平移）',
      );
      expect(r.instant, DateTime.utc(2026, 3, 8, 7));
      expect(r.dstAdjusted, isTrue, reason: '必须标记，否则 UI 无法向用户解释时刻为何变了');
    });

    test('整个不存在的时段都顺延到同一个 03:00', () {
      for (final minute in [0, 1, 30, 59]) {
        final r = _resolver.resolve(
          wall('America/New_York', 2026, 3, 8, 2, minute),
        );
        expect(
          r.effectiveWallTime.minuteOfDay,
          MinuteOfDay.of(3, 0),
          reason: '02:$minute 同样不存在',
        );
        expect(r.dstAdjusted, isTrue);
      }
    });

    test('紧邻不存在时段的合法时刻不受影响，且不打标记', () {
      for (final (h, mi) in [(1, 59), (3, 0), (3, 1)]) {
        final w = wall('America/New_York', 2026, 3, 8, h, mi);
        final r = _resolver.resolve(w);
        expect(r.effectiveWallTime, w, reason: '$h:$mi 是合法时刻');
        expect(r.dstAdjusted, isFalse, reason: '$h:$mi 不该被标记');
      }
    });
  });

  group('DST 秋季回拨（墙钟重复）', () {
    // America/New_York 2026-11-01：02:00 EDT → 01:00 EST，01:00-01:59 出现两次。
    // 依据 IANA tz 规则：美国 DST 于十一月第一个周日 02:00 本地时间结束。

    test('重复的 01:30 取较早的那个绝对时刻', () {
      // 手算：较早 = EDT(-4) 的 01:30 = 05:30 UTC；较晚 = EST(-5) 的 01:30 = 06:30 UTC。
      // 规定取较早（recurrence-engine §4.1），与多数日历应用一致。
      final r = _resolver.resolve(wall('America/New_York', 2026, 11, 1, 1, 30));

      expect(r.instant, DateTime.utc(2026, 11, 1, 5, 30));
      expect(r.dstAdjusted, isFalse, reason: '该墙钟是存在的（只是有两个），不属于「被顺延」');
    });

    test('两个候选绝对时刻确实映射到同一墙钟（前提成立）', () {
      final earlier = DateTime.utc(2026, 11, 1, 5, 30);
      final later = DateTime.utc(2026, 11, 1, 6, 30);
      final w1 = _resolver.toWallTime(earlier, 'America/New_York');
      final w2 = _resolver.toWallTime(later, 'America/New_York');
      expect(w1, w2, reason: '这才叫「重复」；若不等则本组用例的前提不成立');
      expect(w1.minuteOfDay, MinuteOfDay.of(1, 30));
    });

    test('回拨日的往返不再恒等，这是固有的而非缺陷', () {
      // 较晚那个绝对时刻换算成墙钟后再换回来，会落到较早那个。
      // 记录此既有行为，避免将来有人「修」它。
      final later = DateTime.utc(2026, 11, 1, 6, 30);
      final w = _resolver.toWallTime(later, 'America/New_York');
      expect(_resolver.toInstant(w), DateTime.utc(2026, 11, 1, 5, 30));
    });
  });

  group('南半球 DST + 正偏移（变异演练 M4 补漏）', () {
    // 补这一组的原因：上面两组 DST 用例都用 America/New_York（负偏移），
    // 真实绝对时刻落在「墙钟当成 UTC」之后。而**正偏移**时区正相反 ——
    // 真实时刻在它之前。变异演练把搜索窗口左端从 -2 天缩到 0 时，
    // 前两组全绿而缺陷仍在，正是因为没有正偏移的样本。
    //
    // Australia/Sydney：AEST(+10) ⇄ AEDT(+11)
    // 依据 IANA 规则：十月第一个周日 02:00 开始，四月第一个周日 03:00 结束。
    // 手算 2026 年：10-01 是周四 → 首个周日 10-04；04-01 是周三 → 首个周日 04-05。

    test('春季跳表（10-04）：不存在的 02:30 顺延到 03:00', () {
      final r = _resolver.resolve(wall('Australia/Sydney', 2026, 10, 4, 2, 30));
      expect(r.effectiveWallTime, wall('Australia/Sydney', 2026, 10, 4, 3, 0));
      expect(r.dstAdjusted, isTrue);
      // 03:00 AEDT(+11) → 前一日 16:00 UTC。注意它**早于**把墙钟当成 UTC 的时刻，
      // 这正是正偏移时区与负偏移时区的关键差别。
      expect(r.instant, DateTime.utc(2026, 10, 3, 16));
    });

    test('秋季回拨（04-05）：重复的 02:30 取较早者', () {
      final r = _resolver.resolve(wall('Australia/Sydney', 2026, 4, 5, 2, 30));
      // 较早 = AEDT(+11) 的 02:30 = 前一日 15:30 UTC
      expect(r.instant, DateTime.utc(2026, 4, 4, 15, 30));
      expect(r.dstAdjusted, isFalse);
    });

    test('正偏移时区的真实时刻确实早于「墙钟当成 UTC」', () {
      // 这条是 M4 的直接判据：若搜索窗口不向左展开，这类换算会失败。
      for (final zone in [
        'Australia/Sydney',
        'Pacific/Auckland',
        'Asia/Shanghai',
      ]) {
        final w = wall(zone, 2026, 10, 4, 2, 30);
        expect(
          _resolver.toInstant(w).isBefore(w.toFakeUtc()),
          isTrue,
          reason: '$zone 是正偏移，绝对时刻必然早于同值的 UTC 时刻',
        );
      }
    });
  });

  group('UNTIL 换算（recurrence-engine §2.2）', () {
    test('untilForStorage 产出真 UTC', () {
      // Kiritimati UTC+14，日终 23:59 → 同日 09:59 UTC
      expect(
        _resolver.untilForStorage(
          wall('Pacific/Kiritimati', 2026, 9, 30, 23, 59),
        ),
        DateTime.utc(2026, 9, 30, 9, 59),
      );
    });

    test('untilForExpansion 把真 UTC 还原成假 UTC 墙钟值', () {
      expect(
        _resolver.untilForExpansion(
          DateTime.utc(2026, 9, 30, 9, 59),
          'Pacific/Kiritimati',
        ),
        DateTime.utc(2026, 9, 30, 23, 59),
        reason: '结果的 isUtc 为 true，但携带的是墙钟值，用于喂给 rrule',
      );
    });

    test('R-09d 往返恒等：untilForExpansion(untilForStorage(w)) == w', () {
      for (final zone in [
        'Pacific/Kiritimati',
        'Pacific/Niue',
        'America/New_York',
        'Asia/Shanghai',
        'Etc/UTC',
      ]) {
        for (final (h, mi) in [(0, 0), (7, 0), (23, 0), (23, 59)]) {
          final w = wall(zone, 2026, 9, 30, h, mi);
          final roundTripped = _resolver.untilForExpansion(
            _resolver.untilForStorage(w),
            zone,
          );
          expect(roundTripped, w.toFakeUtc(), reason: '$zone $h:$mi');
        }
      }
    });

    test('往返恒等在 DST 跳表日**不成立**，且这是刻意的', () {
      // 02:30 不存在，storage 会落到 03:00，因此 expansion 还原出的是 03:00。
      // 这不是缺陷：不存在的墙钟本就没有对应的绝对时刻可往返。
      // 记录下来，避免将来有人把它当 bug「修」掉。
      final w = wall('America/New_York', 2026, 3, 8, 2, 30);
      final roundTripped = _resolver.untilForExpansion(
        _resolver.untilForStorage(w),
        'America/New_York',
      );
      expect(roundTripped, isNot(w.toFakeUtc()));
      expect(roundTripped, DateTime.utc(2026, 3, 8, 3));
    });
  });

  group('currentZoneId', () {
    test('可注入固定值，便于测试', () {
      const fixed = TzTimeZoneResolver(fixedCurrentZoneId: 'Asia/Shanghai');
      expect(fixed.currentZoneId(), 'Asia/Shanghai');
    });
  });
}

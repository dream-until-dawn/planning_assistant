/// `LocalWallTime` 的行为契约。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/local_wall_time.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';

LocalWallTime w(
  int y,
  int mo,
  int d,
  int h,
  int mi, [
  String z = 'Asia/Shanghai',
]) => LocalWallTime(
  date: PlanDate(y, mo, d),
  minuteOfDay: MinuteOfDay.of(h, mi),
  timeZoneId: z,
);

void main() {
  group('假 UTC 往返', () {
    test('toFakeUtc 携带墙钟值而非 UTC 时刻', () {
      final t = w(2026, 9, 8, 9, 30).toFakeUtc();
      expect(t, DateTime.utc(2026, 9, 8, 9, 30));
      expect(t.isUtc, isTrue, reason: 'rrule 要求 isUtc=true，但它只是占位');
    });

    test('fromFakeUtc 是 toFakeUtc 的逆', () {
      for (final t in [
        w(2026, 1, 1, 0, 0),
        w(2026, 12, 31, 23, 59),
        w(2028, 2, 29, 12, 0),
      ]) {
        expect(LocalWallTime.fromFakeUtc(t.toFakeUtc(), t.timeZoneId), t);
      }
    });
  });

  group('addMinutes 跨日', () {
    test('向前跨日', () {
      expect(w(2026, 9, 8, 23, 30).addMinutes(60), w(2026, 9, 9, 0, 30));
    });

    test('向后跨日', () {
      expect(w(2026, 9, 8, 0, 30).addMinutes(-60), w(2026, 9, 7, 23, 30));
    });

    test('跨月与跨闰日', () {
      expect(w(2026, 1, 31, 23, 0).addMinutes(120), w(2026, 2, 1, 1, 0));
      expect(
        w(2028, 2, 28, 23, 0).addMinutes(120),
        w(2028, 2, 29, 1, 0),
        reason: '闰年',
      );
      expect(
        w(2026, 2, 28, 23, 0).addMinutes(120),
        w(2026, 3, 1, 1, 0),
        reason: '非闰年',
      );
    });

    test('多日跨越', () {
      expect(w(2026, 9, 8, 12, 0).addMinutes(3 * 1440), w(2026, 9, 11, 12, 0));
    });

    test('时区随对象保留', () {
      final r = w(2026, 9, 8, 23, 30, 'America/New_York').addMinutes(60);
      expect(r.timeZoneId, 'America/New_York');
    });
  });

  group('全天构造', () {
    test('allDay 的时刻是占位，不表示「零点」这个语义', () {
      const a = LocalWallTime.allDay(
        date: PlanDate(2026, 9, 8),
        timeZoneId: 'Asia/Shanghai',
      );
      expect(a.minuteOfDay, MinuteOfDay.midnight);
      // 是否全天由 tasks.isAllDay 决定，不可从 minuteOfDay==0 反推：
      // 一个定时任务完全可以就定在 00:00。
      expect(a, w(2026, 9, 8, 0, 0), reason: '两者在值上不可区分，这正是不能反推的原因');
    });
  });

  group('跨时区比较必须显式拒绝', () {
    test('同一时区可比较', () {
      expect(
        w(2026, 9, 8, 9, 0).compareToSameZone(w(2026, 9, 8, 10, 0)),
        lessThan(0),
      );
      expect(
        w(2026, 9, 9, 9, 0).compareToSameZone(w(2026, 9, 8, 10, 0)),
        greaterThan(0),
      );
      expect(w(2026, 9, 8, 9, 0).compareToSameZone(w(2026, 9, 8, 9, 0)), 0);
    });

    test('不同时区抛异常，而不是按字面量比大小', () {
      // 两个不同时区的墙钟值没有可比性。默默比较是错的 ——
      // 那正是 ADR-0005 想消灭的那类 bug。
      expect(
        () => w(
          2026,
          9,
          8,
          9,
          0,
          'Asia/Shanghai',
        ).compareToSameZone(w(2026, 9, 8, 9, 0, 'America/New_York')),
        throwsArgumentError,
      );
    });
  });

  group('值语义', () {
    test('三个字段全等才相等', () {
      expect(w(2026, 9, 8, 9, 0), w(2026, 9, 8, 9, 0));
      expect(w(2026, 9, 8, 9, 0), isNot(w(2026, 9, 8, 9, 1)));
      expect(w(2026, 9, 8, 9, 0), isNot(w(2026, 9, 9, 9, 0)));
      expect(
        w(2026, 9, 8, 9, 0, 'Asia/Shanghai'),
        isNot(w(2026, 9, 8, 9, 0, 'America/New_York')),
        reason: '时区是值的一部分，同样的日期时刻在不同时区是不同的计划时间',
      );
    });

    test('可作为 Set/Map 的键', () {
      expect({w(2026, 9, 8, 9, 0), w(2026, 9, 8, 9, 0)}, hasLength(1));
    });

    test('withTimeZone 只换时区，不做换算', () {
      final r = w(2026, 9, 8, 9, 0).withTimeZone('America/New_York');
      expect(r.date, const PlanDate(2026, 9, 8));
      expect(r.minuteOfDay, MinuteOfDay.of(9, 0));
      expect(r.timeZoneId, 'America/New_York');
    });
  });
}

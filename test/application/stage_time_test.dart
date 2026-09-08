/// 阶段时间的偏移换算（data-model §4.1）。
///
/// 存偏移、看绝对，这中间的换算是**每个阶段每次显示都要走一遍**的路。
/// 算错一分钟不会崩，只会让甘特图上的条稍微歪一点 ——
/// 所以这里往返验，而不是只验单向。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/time/minute_of_day.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/features/task/application/stage_time.dart';

DateAndMinute at(int y, int mo, int d, int h, int mi) =>
    DateAndMinute(PlanDate(y, mo, d), MinuteOfDay.of(h, mi));

void main() {
  group('往前加偏移', () {
    final cases = <String, (DateAndMinute, int, DateAndMinute)>{
      '零偏移就是锚点本身': (at(2026, 9, 8, 9, 0), 0, at(2026, 9, 8, 9, 0)),
      '同一天里加 90 分钟': (at(2026, 9, 8, 9, 0), 90, at(2026, 9, 8, 10, 30)),
      '跨过午夜': (at(2026, 9, 8, 23, 0), 120, at(2026, 9, 9, 1, 0)),
      '整整一天': (at(2026, 9, 8, 9, 0), 1440, at(2026, 9, 9, 9, 0)),
      '跨月': (at(2026, 9, 30, 22, 0), 1440 * 2, at(2026, 10, 2, 22, 0)),
      // 界面产不出负偏移，但换算本身得是对的 —— 见下面那条对照。
      '负偏移退回前一天': (at(2026, 9, 8, 0, 15), -30, at(2026, 9, 7, 23, 45)),
    };

    cases.forEach((name, c) {
      test(name, () {
        final (anchor, offset, expected) = c;
        expect(shiftFrom(anchor, offset), expected);
      });
    });

    test('负偏移不能用截断除法算', () {
      // `-30 ~/ 1440 == 0` —— 截断而不是下取整，会把「前一天 23:30」
      // 算成「当天 -30 分」，而 MinuteOfDay(-30) 直接抛 RangeError。
      // 正数样例一条都测不出这个，所以单独立一条。
      expect(
        () => shiftFrom(at(2026, 9, 8, 0, 0), -1),
        returnsNormally,
        reason: '负偏移不该炸',
      );
      expect(shiftFrom(at(2026, 9, 8, 0, 0), -1), at(2026, 9, 7, 23, 59));
    });
  });

  group('求偏移是加偏移的逆', () {
    final pairs = <String, (DateAndMinute, DateAndMinute)>{
      '同一天往后': (at(2026, 9, 8, 9, 0), at(2026, 9, 8, 17, 30)),
      '跨天': (at(2026, 9, 8, 22, 0), at(2026, 9, 11, 3, 15)),
      '同一时刻': (at(2026, 9, 8, 9, 0), at(2026, 9, 8, 9, 0)),
      '往回': (at(2026, 9, 8, 9, 0), at(2026, 9, 6, 8, 0)),
      '跨年': (at(2026, 12, 31, 23, 30), at(2027, 1, 1, 0, 30)),
    };

    pairs.forEach((name, p) {
      test(name, () {
        final (anchor, target) = p;
        // 往返：算出偏移再加回去，必须回到原处。
        // 单向验的话，两个方向可以一起错同样的量而看不出来。
        expect(shiftFrom(anchor, offsetFrom(anchor, target)), target);
      });
    });

    test('偏移的数值本身也对，不只是往返闭合', () {
      // 只验往返的话，两个函数一起把「天」当成 1000 分钟也能闭合。
      expect(
        offsetFrom(at(2026, 9, 8, 9, 0), at(2026, 9, 9, 9, 0)),
        1440,
        reason: '差一天就是 1440 分钟',
      );
      expect(offsetFrom(at(2026, 9, 8, 9, 0), at(2026, 9, 8, 10, 30)), 90);
      expect(offsetFrom(at(2026, 9, 8, 9, 0), at(2026, 9, 8, 8, 0)), -60);
    });
  });
}

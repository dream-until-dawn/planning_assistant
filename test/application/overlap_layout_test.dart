/// 重叠排布（view-specs §1.2 与 §4.5 的 G-02/G-03）。
///
/// 时间轴与甘特共用这一套，所以它错了是**两个视图一起错**。
/// 而排布错的样子很难一眼看出来：块与块之间对不齐、或者叠在一起，
/// 看着像「渲染有点问题」，不像算法错。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/features/views/shared/application/overlap_layout.dart';

/// `[start, end)`，单位随便 —— 时间轴按分钟，甘特按天。
OverlapInput<String> _at(String name, int start, int end) =>
    OverlapInput(item: name, start: start, end: end);

/// 每个 item 排在第几列 / 共几列。
Map<String, (int, int)> _placement(List<OverlapCluster<String>> clusters) => {
  for (final c in clusters)
    for (final s in c.slots) s.item: (s.column, s.columnCount),
};

void main() {
  group('不重叠的各走各的', () {
    test('首尾相接不算重叠（左闭右开）', () {
      // 闭区间的话，09-10 与 10-11 会被判成并排，白白折掉一半宽度。
      final clusters = layoutOverlaps([_at('a', 0, 60), _at('b', 60, 120)]);
      expect(clusters, hasLength(2));
      expect(_placement(clusters), {'a': (0, 1), 'b': (0, 1)});
    });

    test('隔开的两个各占满宽', () {
      final clusters = layoutOverlaps([_at('a', 0, 60), _at('b', 120, 180)]);
      expect(clusters, hasLength(2));
      for (final c in clusters) {
        expect(c.slots.single.columnCount, 1);
      }
    });
  });

  group('G-02：两个重叠 → 两列各占半宽', () {
    test('各在一列，列数都是 2', () {
      final clusters = layoutOverlaps([_at('a', 0, 60), _at('b', 30, 90)]);
      expect(clusters, hasLength(1));
      expect(_placement(clusters), {'a': (0, 2), 'b': (1, 2)});
    });

    test('输入顺序不影响结果', () {
      // 数据源的顺序不该决定谁在左边 —— 那会让同一天的图
      // 在两次进入时长得不一样。
      final forward = _placement(
        layoutOverlaps([_at('a', 0, 60), _at('b', 30, 90)]),
      );
      final backward = _placement(
        layoutOverlaps([_at('b', 30, 90), _at('a', 0, 60)]),
      );
      expect(backward, forward);
    });
  });

  group('G-03：四个重叠 → 三列 + 折叠指示', () {
    test('只排前三个，第四个折起来', () {
      final clusters = layoutOverlaps([
        _at('a', 0, 60),
        _at('b', 10, 60),
        _at('c', 20, 60),
        _at('d', 30, 60),
      ]);
      expect(clusters, hasLength(1));
      final cluster = clusters.single;
      expect(cluster.slots, hasLength(3));
      expect(cluster.hidden, ['d'], reason: '折掉的应当是**后面**那个，不是中间某个');
      expect(cluster.hiddenCount, 1);
      expect(cluster.slots.every((s) => s.columnCount == 3), isTrue);
    });

    test('上限可调', () {
      final clusters = layoutOverlaps([
        _at('a', 0, 60),
        _at('b', 10, 60),
        _at('c', 20, 60),
      ], maxColumns: 2);
      expect(clusters.single.slots, hasLength(2));
      expect(clusters.single.hidden, ['c']);
    });

    test('对照组：正好三个不折', () {
      // 少了这条，一个「超过两个就折」的实现也能让上面绿。
      final clusters = layoutOverlaps([
        _at('a', 0, 60),
        _at('b', 10, 60),
        _at('c', 20, 60),
      ]);
      expect(clusters.single.hidden, isEmpty);
      expect(clusters.single.slots, hasLength(3));
    });
  });

  group('列数是「同时并存的最大数」，不是簇的大小', () {
    test('A 09-10、B 10-11、C 09-11 连成一簇，但只要两列', () {
      // 按簇的大小算列宽的话，这三个会各占三分之一 ——
      // 而 A 与 B 明明可以共用一列，白白窄了三分之一。
      final clusters = layoutOverlaps([
        _at('A', 540, 600),
        _at('B', 600, 660),
        _at('C', 540, 660),
      ]);
      expect(clusters, hasLength(1), reason: 'C 把 A 和 B 连了起来');
      final placement = _placement(clusters);
      expect(placement.values.map((p) => p.$2).toSet(), {2});
      expect(
        placement['A']!.$1,
        placement['B']!.$1,
        reason: 'A 与 B 不重叠，该复用同一列',
      );
      expect(placement['C']!.$1, isNot(placement['A']!.$1));
    });

    test('传递重叠要连成一簇', () {
      // A 与 C 不重叠，但都跟 B 重叠。分成两簇的话，A 和 C 会各自
      // 按「两列」算，画出来宽度对不齐，还会压到 B。
      final clusters = layoutOverlaps([
        _at('A', 0, 30),
        _at('B', 20, 70),
        _at('C', 60, 90),
      ]);
      expect(clusters, hasLength(1));
    });
  });

  group('没有时长的那些', () {
    test('同一刻开始的两个零长段要并排，不叠在一起', () {
      // 按左闭右开算的话它们谁也不跟谁重叠，会各占满宽画在同一个位置。
      final clusters = layoutOverlaps([_at('a', 540, 540), _at('b', 540, 540)]);
      expect(clusters, hasLength(1));
      expect(clusters.single.slots.map((s) => s.column).toSet(), {0, 1});
    });

    test('零长段落在别人区间里也要并排', () {
      final clusters = layoutOverlaps([_at('长', 540, 600), _at('点', 570, 570)]);
      expect(clusters, hasLength(1));
      expect(clusters.single.slots, hasLength(2));
    });
  });

  group('边角', () {
    test('空输入返回空表，不抛', () {
      expect(layoutOverlaps<String>(const []), isEmpty);
    });

    test('单个就是一列满宽', () {
      final clusters = layoutOverlaps([_at('a', 0, 60)]);
      expect(clusters.single.slots.single.columnCount, 1);
    });

    test('簇的范围覆盖它里面所有段（含被折掉的）', () {
      // 「+N」指示器靠它定位。只按可见的算的话，指示器会落在
      // 簇的中间而不是末尾。
      final clusters = layoutOverlaps([
        _at('a', 0, 60),
        _at('b', 10, 70),
        _at('c', 20, 80),
        _at('d', 30, 200),
      ]);
      expect(clusters.single.start, 0);
      expect(clusters.single.end, 200, reason: '被折掉的 d 也算在范围里');
    });
  });
}

/// **用法级**对比度守卫（design-system §10.2、testing-strategy §7.3）。
///
/// §10 那一层验的是 **token 本身**：`brand.primary.text` 对三个亮表面达标。
/// 但 token 达标不等于**用对了地方** —— 把 `brand.primary.graphic`（3.46）
/// 拿去当标签色，两个 token 都是合规 token，组合出来的是不合规的界面。
///
/// 所以这一层验的是**实际渲染出来的那一对颜色**：
/// 渲染组件 → 遍历渲染树 → 每段文字与它真正压着的背景配对 → 算对比度。
///
/// 这比扫源码文本强在哪：
///
/// - 不依赖写法。`colors.brandGraphic`、`const Color(0xFF379986)`、
///   某个中间变量传进来的，渲染出来都是同一个像素值。
/// - 不依赖命名。守的是「文字压在背景上」这个**几何事实**，
///   不是「变量名里有没有 graphic」。
/// - 会连带覆盖以后新增的组件 —— 只要把组件加进下面的画廊。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/design/theme/app_theme.dart';
import 'package:planning_assistant/design/tokens/colors.dart';
import 'package:planning_assistant/design/tokens/contrast.dart';

/// 一段文字与它压着的背景。
typedef Pairing = ({String text, int fg, int bg, double ratio});

/// 正文门槛。**不做 WCAG 的大字号豁免**（≥18pt 可降到 3.0）——
/// design-system §10 定的谓词里没有这一条，这里就不自作主张放宽。
/// 真撞上合理的大字号被判失败，那是去改文档里的谓词，不是在这里开口子。
const double kTextThreshold = 4.5;

int _rgb(Color c) =>
    ((c.r * 255).round() << 16) |
    ((c.g * 255).round() << 8) |
    (c.b * 255).round();

/// 把带 alpha 的颜色合成到已知的不透明底色上。
int _composite(Color fg, int bg) {
  int mix(double f, int b) =>
      ((f * 255 * fg.a) + b * (1 - fg.a)).round().clamp(0, 255);
  return (mix(fg.r, (bg >> 16) & 0xFF) << 16) |
      (mix(fg.g, (bg >> 8) & 0xFF) << 8) |
      mix(fg.b, bg & 0xFF);
}

/// 从某个 widget 上取它画出来的背景色（取不到返回 null）。
Color? _backgroundOf(Widget w) => switch (w) {
  ColoredBox(:final color) => color,
  Material(:final color) => color,
  Card(:final color) => color,
  DecoratedBox(:final decoration) => switch (decoration) {
    BoxDecoration(:final color) => color,
    _ => null,
  },
  Container(:final color) => color,
  _ => null,
};

/// 遍历渲染出来的每段文字，与其**最近的不透明背景**配对。
///
/// 半透明背景按顺序往上合成，直到遇到不透明的为止 ——
/// 否则「白底上盖一层半透明再写字」会被当成在那层半透明色上判，
/// 得出的是一个屏幕上根本不存在的数。
List<Pairing> pairingsIn(WidgetTester tester) {
  final result = <Pairing>[];

  for (final element in find.byType(Text).evaluate()) {
    final render = element.renderObject;
    if (render is! RenderParagraph) continue;

    final plain = render.text.toPlainText();
    final color = render.text.style?.color;
    if (color == null) {
      fail('「$plain」没有显式文字色，无从判定对比度');
    }

    // 从这段文字往上找背景：半透明的先攒着，遇到第一个不透明的停。
    final translucent = <Color>[];
    Color? opaque;
    element.visitAncestorElements((ancestor) {
      final bg = _backgroundOf(ancestor.widget);
      if (bg == null || bg.a == 0) return true;
      if (bg.a == 1.0) {
        opaque = bg;
        return false;
      }
      translucent.add(bg);
      return true;
    });

    final base = opaque;
    if (base == null) {
      fail('「$plain」上方找不到不透明背景，无从判定对比度');
    }

    var bg = _rgb(base);
    for (final layer in translucent.reversed) {
      bg = _composite(layer, bg);
    }
    final fg = color.a == 1.0 ? _rgb(color) : _composite(color, bg);

    result.add((text: plain, fg: fg, bg: bg, ratio: contrastRatio(fg, bg)));
  }
  return result;
}

/// 禁用态豁免（§2.3：`text.disabled` 2.34，仅用于禁用态、不承载信息）。
bool _isExempt(Pairing p) =>
    p.fg == TextColors.disabled || p.fg == TextColors.disabledDark;

String _describe(Pairing p) =>
    '「${p.text}」 #${p.fg.toRadixString(16).padLeft(6, '0')} '
    'on #${p.bg.toRadixString(16).padLeft(6, '0')} = '
    '${p.ratio.toStringAsFixed(2)}:1';

Future<void> _pump(WidgetTester tester, Brightness b, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: b == Brightness.light ? AppTheme.light() : AppTheme.dark(),
      home: Scaffold(body: child),
    ),
  );
}

Widget _on(Color Function(AppSemanticColors) bg, Widget child) => Builder(
  builder: (context) => ColoredBox(color: bg(context.appColors), child: child),
);

void main() {
  group('守卫自身必须能失败（§1.4）', () {
    testWidgets('把 brandGraphic 当标签色用会被抓到', (tester) async {
      // brandGraphic 对 card 是 3.46 —— 合规的**图形**色，不合规的文字色。
      // 这正是 §10.2 那条 lint 要拦的东西。
      await _pump(
        tester,
        Brightness.light,
        _on(
          (c) => c.card,
          Builder(
            builder: (context) => Text(
              '看板',
              style: TextStyle(color: context.appColors.brandGraphic),
            ),
          ),
        ),
      );

      final bad = pairingsIn(tester).where((p) => p.ratio < kTextThreshold);
      expect(bad, hasLength(1), reason: '这个违规必须被抓到，否则守卫是摆设');
      expect(bad.first.ratio, closeTo(3.46, 0.01));
    });

    testWidgets('换成 brandText 就通过 —— 抓的是对比度，不是颜色名', (tester) async {
      await _pump(
        tester,
        Brightness.light,
        _on(
          (c) => c.card,
          Builder(
            builder: (context) => Text(
              '看板',
              style: TextStyle(color: context.appColors.brandText),
            ),
          ),
        ),
      );
      final all = pairingsIn(tester);
      expect(all, hasLength(1));
      expect(all.single.ratio, greaterThanOrEqualTo(kTextThreshold));
    });

    testWidgets('半透明背景要合成后再判', (tester) async {
      // 白底上盖 30% 薄荷，再写 onBrand 文字。
      // 30% 薄荷压白 = 更浅的薄荷，比纯薄荷更亮，
      // 所以对比度应当**高于**纯薄荷上的 6.62。不合成就得不到这个数。
      await _pump(
        tester,
        Brightness.light,
        _on(
          (c) => c.card,
          Builder(
            builder: (context) => ColoredBox(
              color: context.appColors.brandFill.withValues(alpha: 0.3),
              child: Text(
                '合成',
                style: TextStyle(color: context.appColors.onBrand),
              ),
            ),
          ),
        ),
      );
      expect(pairingsIn(tester).single.ratio, greaterThan(6.62));
    });
  });

  group('组件画廊：每段文字都达标', () {
    // **新增组件请加进这里** —— 守卫只覆盖渲染得到的东西。
    final gallery = <String, Widget>{
      '任务卡片（普通）': const TaskCard(
        data: TaskCardData(
          title: '买菜',
          categoryName: '生活',
          categoryColor: Color(0xFF7FD1C1),
          timeLabel: '14:00',
        ),
      ),
      '任务卡片（逾期）': const TaskCard(
        data: TaskCardData(
          title: '预约体检',
          categoryName: '健康',
          categoryColor: Color(0xFFFFB7C5),
          timeLabel: '昨天 18:00',
          isOverdue: true,
        ),
      ),
      '任务卡片（已完成）': const TaskCard(
        data: TaskCardData(
          title: '交水电费',
          categoryName: '生活',
          categoryColor: Color(0xFF7FD1C1),
          timeLabel: '10:00',
          isDone: true,
        ),
      ),
      '任务卡片（阶段）': const TaskCard(
        data: TaskCardData(
          title: '写季度总结',
          categoryName: '工作',
          categoryColor: Color(0xFFA8C8F0),
          timeLabel: '09:30',
          stageProgress: (2, 5),
        ),
      ),
    };

    for (final brightness in Brightness.values) {
      for (final entry in gallery.entries) {
        testWidgets('${brightness.name} · ${entry.key}', (tester) async {
          await _pump(tester, brightness, entry.value);

          final pairings = pairingsIn(tester);
          expect(pairings, isNotEmpty, reason: '一段文字都没量到，等于空对空');

          final bad = pairings
              .where((p) => !_isExempt(p) && p.ratio < kTextThreshold)
              .map(_describe)
              .toList();
          expect(bad, isEmpty, reason: '这些文字压在背景上不达标：${bad.join(' / ')}');
        });
      }
    }
  });
}

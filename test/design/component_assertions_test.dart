/// 按钮与 Chip 的**布局约束**（测试策略 §7.1，断言型）。
///
/// 不产图。断的是约束：触控尺寸、不溢出、信息不靠颜色单独承载、
/// 禁用态可分辨。与 `component_golden_test.dart` 的分工同 §7.1 那张表。
@TestOn('vm')
library;

import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/design/components/app_button.dart';
import 'package:planning_assistant/design/components/app_chip.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/design/theme/app_theme.dart';
import 'package:planning_assistant/design/tokens/dimensions.dart';

/// 一个真实会出现的长标签。短标签验不出换行与溢出 ——
/// §1.5 那条判据：夹具里的字面量常量，逐个问「取别的会怎样」。
const _longLabel = '保存并继续添加下一个日程';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1.0,
  Brightness brightness = Brightness.light,
  Size surface = const Size(400, 800),
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(Spacing.pageHorizontal),
            child: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('按钮：触控目标任何缩放、任何变体下都 ≥48dp', () {
    for (final variant in AppButtonVariant.values) {
      for (final scale in FontScale.goldenScales) {
        testWidgets('${variant.name} × $scale', (tester) async {
          await _pump(
            tester,
            AppButton(label: '保存', variant: variant, onPressed: () {}),
            textScale: scale,
          );
          final size = tester.getSize(find.byType(AppButton));
          expect(
            size.height,
            greaterThanOrEqualTo(Spacing.minTouchTarget),
            reason: '高 ${size.height}',
          );
          expect(
            size.width,
            greaterThanOrEqualTo(Spacing.minTouchTarget),
            reason: '宽 ${size.width}',
          );
        });
      }
    }
  });

  group('按钮：长标签不溢出', () {
    for (final scale in FontScale.goldenScales) {
      testWidgets('缩放 $scale：窄屏 320dp 也不溢出', (tester) async {
        // 小屏 + 大字号 + 长标签，三个最坏值一起上。
        await _pump(
          tester,
          AppButton(label: _longLabel, onPressed: () {}, expand: true),
          textScale: scale,
          surface: const Size(320, 800),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('缩放 $scale：带图标同样不溢出', (tester) async {
        await _pump(
          tester,
          AppButton(label: _longLabel, icon: Icons.add, onPressed: () {}),
          textScale: scale,
          surface: const Size(320, 800),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('按钮：expand 决定撑不撑满', () {
    testWidgets('expand=true 撑满可用宽度', (tester) async {
      await _pump(
        tester,
        AppButton(label: '保存', onPressed: () {}, expand: true),
      );
      final w = tester.getSize(find.byType(AppButton)).width;
      expect(w, closeTo(400 - Spacing.pageHorizontal * 2, 0.5));
    });

    // 对照组（§7.1.1）：保护的是实现选择。
    // 「一律撑满」能让上面那条绿，但那样卡片内的文字按钮会占满整行。
    testWidgets('对照组：expand=false 时按内容收窄', (tester) async {
      await _pump(tester, AppButton(label: '保存', onPressed: () {}));
      final w = tester.getSize(find.byType(AppButton)).width;
      expect(
        w,
        lessThan(400 - Spacing.pageHorizontal * 2),
        reason: '不撑满时应当只占内容宽度，否则 expand 这个参数等于不存在',
      );
    });
  });

  group('按钮：禁用态', () {
    testWidgets('onPressed 为 null 时语义上是禁用的', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const AppButton(label: '保存'));
      final node = tester.getSemantics(find.byType(AppButton));
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('禁用态与启用态的标签色**不同** —— 否则看不出点不动', (tester) async {
      await _pump(tester, const AppButton(label: '保存'));
      final disabled = tester.widget<Text>(find.text('保存')).style!.color;

      await _pump(tester, AppButton(label: '保存', onPressed: () {}));
      final enabled = tester.widget<Text>(find.text('保存')).style!.color;

      expect(disabled, isNot(enabled));
    });

    testWidgets('禁用态的点击回调真的没接上', (tester) async {
      // 初版写的是「点一下，然后断言计数器还是 0」—— 那个计数器压根没接到
      // 任何回调上，断言恒等于 0 == 0，属于 §1.1 明令禁止的同义反复。
      // 要验的是 InkWell 的 onTap 到底是不是 null。
      await _pump(tester, const AppButton(label: '保存'));
      final disabled = tester.widget<InkWell>(
        find.descendant(
          of: find.byType(AppButton),
          matching: find.byType(InkWell),
        ),
      );
      expect(disabled.onTap, isNull);
    });

    testWidgets('对照组：启用态点一下真的会响', (tester) async {
      // 没有这条，上面那条用「永远返回 null 的按钮」也能通过。
      var taps = 0;
      await _pump(tester, AppButton(label: '保存', onPressed: () => taps++));
      await tester.tap(find.byType(AppButton));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('Chip：信息不靠颜色单独承载（§8.1）', () {
    testWidgets('分类名以文字出现，不只是那个圆点', (tester) async {
      await _pump(
        tester,
        const CategoryChip(name: '工作', color: Color(0xFFA8C8F0)),
      );
      expect(find.text('工作'), findsOneWidget);
    });

    testWidgets('选中态有勾，不只是底色深浅', (tester) async {
      // 没有这条，灰度屏 / 色觉障碍下选中与未选中几乎分不出。
      await _pump(tester, const SelectableChip(label: '今天', selected: true));
      expect(find.byIcon(SelectableChip.checkIcon), findsOneWidget);
    });

    testWidgets('对照组：未选中时没有勾', (tester) async {
      // 否则「一律画勾」也能让上面那条绿，而那样就没有选中态了。
      await _pump(tester, const SelectableChip(label: '今天', selected: false));
      expect(find.byIcon(SelectableChip.checkIcon), findsNothing);
    });

    testWidgets('选中态在语义树上可读', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const SelectableChip(label: '今天', selected: true));
      final node = tester.getSemantics(find.byType(SelectableChip));
      expect(node.flagsCollection.isSelected, Tristate.isTrue);
      handle.dispose();
    });
  });

  group('Chip：可点的触控目标 ≥48dp', () {
    for (final scale in FontScale.goldenScales) {
      testWidgets('缩放 $scale', (tester) async {
        await _pump(
          tester,
          SelectableChip(label: '今天', selected: false, onSelected: (_) {}),
          textScale: scale,
        );
        final size = tester.getSize(find.byType(SelectableChip));
        expect(size.height, greaterThanOrEqualTo(Spacing.minTouchTarget));
      });
    }
  });

  group('Chip：回调', () {
    testWidgets('点击把当前选中态取反后回传', (tester) async {
      bool? got;
      await _pump(
        tester,
        SelectableChip(
          label: '今天',
          selected: false,
          onSelected: (v) => got = v,
        ),
      );
      await tester.tap(find.byType(SelectableChip));
      expect(got, isTrue, reason: '未选中被点应当回传 true');

      got = null;
      await _pump(
        tester,
        SelectableChip(label: '今天', selected: true, onSelected: (v) => got = v),
      );
      await tester.tap(find.byType(SelectableChip));
      expect(got, isFalse, reason: '已选中被点应当回传 false');
    });
  });

  group('圆角档位对组件真的生效（FR-CFG-02）', () {
    // theme_test 验的是 `cardTheme.shape` —— 值确实装进主题了。
    // 但任务卡片自己画 DecoratedBox，压根不读 cardTheme，
    // 于是那个配置项曾经对它完全无效，而测试是绿的。
    // 这一条量的是**真任务卡片画出来的那个圆角**。
    //
    // 初版这里量的是本文件里自建的一个探针组件 —— 那只能证明探针用了
    // appShape，证明不了 TaskCard 用了。换成量真组件。
    Future<double> renderedRadius(
      WidgetTester tester,
      CornerStyle style,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(corners: style),
          home: const Scaffold(
            body: TaskCard(
              data: TaskCardData(
                title: '买菜',
                categoryName: '生活',
                categoryColor: Color(0xFF7FD1C1),
              ),
            ),
          ),
        ),
      );
      // MaterialApp 用 AnimatedTheme 过渡主题，而 AppShape.lerp 在 t<0.5
      // 时返回旧值 —— 不 settle 的话量到的是上一档的圆角。
      await tester.pumpAndSettle();
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(TaskCard),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final d = box.decoration as BoxDecoration;
      return (d.borderRadius! as BorderRadius).topLeft.x;
    }

    testWidgets('三档产出三个不同的实际圆角', (tester) async {
      final seen = <double>{};
      for (final style in CornerStyle.values) {
        final r = await renderedRadius(tester, style);
        expect(
          r,
          closeTo(style.apply(Radii.lg), 0.01),
          reason: '${style.name} 档画出来的圆角',
        );
        seen.add(r);
      }
      expect(seen.length, 3, reason: '三档画出同一个圆角 = 配置项等于不存在');
    });
  });

  group('页面用的是设计系统的按钮，不是 Material 的（design-system §8.5）', () {
    // ## 为什么要扫源码
    //
    // `AppButton` 管着三样东西：圆角档位（`CornerStyle`）、对比度约束
    // （primary 用 `onBrand` 6.62，白字只有 1.78 是禁止的）、以及禁用态
    // 的画法。原生的 `FilledButton` / `ElevatedButton` / `OutlinedButton`
    // 三样各走各的，而画出来**只是差一点** —— 差一点正是这个项目
    // 反复栽的那一类：截图上看着对，量起来不对。
    //
    // 备份页一度是全项目唯一一处原生 `FilledButton`，真机截图之后才发现。
    //
    // **`TextButton` 不在这条里**：对话框的「取消/确定」是平台惯例，
    // 而 `AppButton` 的 `text` 变体不是为对话框做的。这条线是有意画的，
    // 不是漏了。
    const banned = ['FilledButton', 'ElevatedButton', 'OutlinedButton'];

    List<String> offenders(Iterable<({String path, String source})> files) => [
      for (final f in files)
        for (final name in banned)
          // **raw 串 + 拼接，不用插值。** 普通字符串里反斜杠 b 是退格符、
          // 反斜杠 s 会被静默丢掉，而 Dart 编译期对这一族一声不吭 ——
          // 插值写法会把这个正则变成一个匹配不到任何东西的东西，守卫全绿。
          // （写这一行时当场栽了一次，是下面那条自检把它拦住的。）
          if (RegExp(r'\b' + name + r'\s*[.(]').hasMatch(f.source))
            '${f.path} 用了 $name',
    ];

    test('守卫自身能失败（§1.4）', () {
      // 一个永远返回空表的扫描器与「全项目都合规」在结果上一模一样。
      expect(
        offenders([
          (path: 'fake.dart', source: 'FilledButton.icon(onPressed: null)'),
        ]),
        ['fake.dart 用了 FilledButton'],
      );
      expect(
        offenders([
          // `TextButton` 与只是提到名字的注释都不该被算进来。
          (
            path: 'fake.dart',
            source: '// 不用 FilledButtonish\nTextButton(child: x)',
          ),
        ]),
        isEmpty,
      );
    });

    test('lib/ 下一处都没有', () {
      final files = [
        for (final f in Directory('lib').listSync(recursive: true))
          if (f is File && f.path.endsWith('.dart'))
            (path: f.path.replaceAll('\\', '/'), source: f.readAsStringSync()),
      ];
      expect(files, isNotEmpty, reason: '一个文件都没扫到 —— 守卫是僵尸');
      expect(offenders(files), isEmpty);
    });
  });
}

/// 任务卡片的**布局约束**（测试策略 §7.1，断言型）。
///
/// **这个文件不产出任何图片。** 它断的是约束，不是外观：
///
/// | 要断的事 | 怎么断 |
/// |---|---|
/// | 标题不被截断成一行 | 查 `RenderParagraph.didExceedMaxLines` |
/// | 触控目标 ≥48dp | `tester.getSize` |
/// | 内容不出屏 | `tester.getRect` 落在视口内 |
/// | 无溢出 | 无 `RenderFlex overflow` 异常 |
///
/// 由此得到一条可验证的性质：**改间距 token 时这些必须全绿**
/// —— 它们不看外观。§7.2 的那条判据靠这个文件的一半。
@TestOn('vm')
library;

import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/design/theme/app_theme.dart';
import 'package:planning_assistant/design/tokens/dimensions.dart';

const _shortTitle = '买菜';
const _longTitle =
    '把这个季度所有还没有归档的项目文档整理一遍并且逐个确认负责人'
    '与截止日期然后同步给团队里的每一个人确保没有遗漏';

TaskCardData _data({
  String title = _shortTitle,
  String? timeLabel = '14:00',
  String categoryName = '工作',
  (int, int)? stageProgress,
  List<TaskCardStage> stages = const [],
  bool isDone = false,
  bool isOverdue = false,
  bool isRecurring = false,
}) => TaskCardData(
  title: title,
  categoryName: categoryName,
  categoryColor: const Color(0xFF7FD1C1),
  timeLabel: timeLabel,
  stageProgress: stageProgress,
  stages: stages,
  isDone: isDone,
  isOverdue: isOverdue,
  isRecurring: isRecurring,
);

const _stages = [
  TaskCardStage(id: 's1', title: '打包', isDone: true),
  TaskCardStage(id: 's2', title: '搬运', isDone: false),
];

/// 在指定字号缩放与主题下渲染一张卡片。
Future<void> _pumpCard(
  WidgetTester tester, {
  required TaskCardData data,
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
            child: TaskCard(
              data: data,
              onToggleDone: () {},
              onToggleStage: (_, _) {},
            ),
          ),
        ),
      ),
    ),
  );
}

/// 找到承载某段文字的 `RenderParagraph`。
RenderParagraph _paragraphOf(WidgetTester tester, String text) {
  final element = tester.element(find.text(text));
  RenderParagraph? found;
  void visit(RenderObject o) {
    if (found != null) return;
    if (o is RenderParagraph) {
      found = o;
      return;
    }
    o.visitChildren(visit);
  }

  visit(element.renderObject!);
  expect(found, isNotNull, reason: '找不到「$text」的 RenderParagraph');
  return found!;
}

void main() {
  group('标题截断：两行，且短标题不该被截', () {
    for (final scale in FontScale.goldenScales) {
      testWidgets('缩放 $scale：短标题不截断', (tester) async {
        await _pumpCard(tester, data: _data(), textScale: scale);
        expect(
          _paragraphOf(tester, _shortTitle).didExceedMaxLines,
          isFalse,
          reason: '两个字的标题在任何缩放下都不该被截',
        );
      });

      testWidgets('缩放 $scale：超长标题截断而不是撑破卡片', (tester) async {
        await _pumpCard(
          tester,
          data: _data(title: _longTitle),
          textScale: scale,
        );
        // 截断本身是**预期行为**：不截的话卡片会长成一整屏。
        expect(_paragraphOf(tester, _longTitle).didExceedMaxLines, isTrue);
        // 而且必须真的只占两行的高度。
        expect(
          _paragraphOf(tester, _longTitle).size.height,
          lessThan(tester.getSize(find.byType(TaskCard)).height),
        );
      });
    }
  });

  group('阶段子项（用户第 ② 条）', () {
    for (final scale in FontScale.goldenScales) {
      testWidgets('缩放 $scale：子项的勾选框也 ≥48dp', (tester) async {
        // 完成钮量过了，子项**没量过就等于没有** ——
        // 它是卡片上第二种可点的东西，而且是更小的那一种。
        await _pumpCard(
          tester,
          data: _data(stages: _stages),
          textScale: scale,
        );
        final size = tester.getSize(find.byKey(TaskCard.stageKey('s1')));
        expect(size.width, greaterThanOrEqualTo(Spacing.minTouchTarget));
        expect(size.height, greaterThanOrEqualTo(Spacing.minTouchTarget));
      });

      testWidgets('缩放 $scale：子项标题不出屏', (tester) async {
        await _pumpCard(
          tester,
          data: _data(
            stages: const [
              TaskCardStage(id: 's1', title: _longTitle, isDone: false),
            ],
          ),
          textScale: scale,
        );
        // 长标题**截断**而不是把卡片顶宽 —— 子项只有一行。
        expect(_paragraphOf(tester, _longTitle).didExceedMaxLines, isTrue);
        expect(
          tester.getRect(find.byType(TaskCard)).right,
          lessThanOrEqualTo(tester.view.physicalSize.width),
        );
      });
    }

    testWidgets('没有回调时子项只读', (tester) async {
      // 卡片被当成纯展示用（比如将来的只读预览）时，
      // 勾选框不能看着能点、点了没反应。
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TaskCard(data: _data(stages: _stages)),
          ),
        ),
      );
      expect(
        tester.widget<Checkbox>(find.byKey(TaskCard.stageKey('s1'))).onChanged,
        isNull,
      );
    });
  });

  group('触控目标：任何缩放下都 ≥48dp', () {
    for (final scale in FontScale.goldenScales) {
      testWidgets('缩放 $scale', (tester) async {
        await _pumpCard(tester, data: _data(), textScale: scale);
        final size = tester.getSize(find.byKey(TaskCard.doneButtonKey));
        expect(
          size.width,
          greaterThanOrEqualTo(Spacing.minTouchTarget),
          reason: '完成钮触控宽度 ${size.width}',
        );
        expect(
          size.height,
          greaterThanOrEqualTo(Spacing.minTouchTarget),
          reason: '完成钮触控高度 ${size.height}',
        );
      });
    }
  });

  group('不出屏、不溢出', () {
    for (final scale in FontScale.goldenScales) {
      testWidgets('缩放 $scale：卡片右边界不超出视口', (tester) async {
        const surface = Size(400, 800);
        await _pumpCard(
          tester,
          data: _data(title: _longTitle, stageProgress: (2, 5)),
          textScale: scale,
          surface: surface,
        );
        final rect = tester.getRect(find.byType(TaskCard));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(
          rect.right,
          lessThanOrEqualTo(surface.width + 0.01),
          reason: '卡片右边界 ${rect.right} 超出了 ${surface.width}',
        );
      });

      testWidgets('缩放 $scale：无 RenderFlex 溢出', (tester) async {
        await _pumpCard(
          tester,
          data: _data(title: _longTitle, stageProgress: (12, 20)),
          textScale: scale,
        );
        // pumpWidget 期间的溢出会记在 takeException 里。
        expect(tester.takeException(), isNull);
      });

      testWidgets('缩放 $scale：窄屏（320dp）同样不溢出', (tester) async {
        // 小屏 + 大字号是最容易破版的组合，而它恰恰是无障碍用户的常态。
        await _pumpCard(
          tester,
          data: _data(title: _longTitle, stageProgress: (2, 5)),
          textScale: scale,
          surface: const Size(320, 800),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('信息不靠颜色单独承载（§8.1）', () {
    testWidgets('分类名以文字出现，不只是左边那条色条', (tester) async {
      // 色觉障碍可用性。这条是**断言**不是快照：
      // 它问的是「这段文字在不在」，与间距、配色都无关。
      await _pumpCard(tester, data: _data());
      expect(find.text('工作'), findsOneWidget);
    });

    testWidgets('阶段进度以文字出现', (tester) async {
      await _pumpCard(tester, data: _data(stageProgress: (2, 5)));
      expect(find.textContaining('2/5'), findsOneWidget);
    });

    testWidgets('完成状态在语义树上可读，不只是划线', (tester) async {
      // 划线是视觉，屏幕阅读器读不到。语义树上必须有 checked 标记，
      // 否则视障用户无从知道这条已完成。
      // 必须在测试体内 dispose：addTearDown 跑在框架的句柄校验之后，
      // 会报「SemanticsHandle 未释放」而盖掉真正的失败原因。
      final handle = tester.ensureSemantics();

      await _pumpCard(tester, data: _data(isDone: true));
      final node = tester.getSemantics(find.byKey(TaskCard.doneButtonKey));
      expect(node.flagsCollection.isChecked, CheckedState.isTrue);
      expect(node.label, contains(TaskCard.toggleSemanticLabel));

      handle.dispose();
    });
  });

  group('逾期：色条与文字用**不同**的两个色（§2.4）', () {
    testWidgets('逾期时时间文字换成 overdue.text，而非 fill', (tester) async {
      await _pumpCard(tester, data: _data(isOverdue: true));

      final context = tester.element(find.byType(TaskCard));
      final colors = context.appColors;
      final timeStyle = tester.widget<Text>(find.text('14:00')).style!;

      expect(timeStyle.color, colors.overdueText);
      expect(
        timeStyle.color,
        isNot(colors.overdueFill),
        reason: 'fill 作文字只有 1.94:1 —— 这正是 §2.4 拆两个 token 的理由',
      );
    });

    testWidgets('非逾期时不使用逾期色', (tester) async {
      await _pumpCard(tester, data: _data());
      final context = tester.element(find.byType(TaskCard));
      final colors = context.appColors;
      final timeStyle = tester.widget<Text>(find.text('14:00')).style;
      expect(timeStyle?.color, isNot(colors.overdueText));
    });
  });

  group('全天任务没有时间标签', () {
    testWidgets('timeLabel 为 null 时不渲染时间', (tester) async {
      await _pumpCard(tester, data: _data(timeLabel: null));
      expect(find.text('14:00'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('时间下沉：挤的时候换行，不挤的时候不换行', () {
    // golden 抓到过一个断言型漏掉的溢出（2.8× 时 RenderFlex 溢出 3px）。
    // 判据没错，错的是**夹具的取值范围**：断言这边一直用「14:00」，
    // 而画廊用「昨天 18:00」—— 同一个缩放下两者宽度差一倍。
    // 所以时间标签也得参数化，不能只挑一个短的。
    const shortTime = '14:00';
    const longTime = '昨天 18:00';
    const absurdTime = '昨天 18:00 — 明天 09:30';

    /// 时间有没有下沉到副信息下方。**比 y 坐标，不看图。**
    bool isStacked(WidgetTester tester, String label) {
      final timeTop = tester.getTopLeft(find.text(label)).dy;
      final subtitleTop = tester.getTopLeft(find.text('工作')).dy;
      return timeTop > subtitleTop;
    }

    for (final scale in FontScale.goldenScales) {
      for (final label in const [shortTime, longTime]) {
        testWidgets('缩放 $scale ×「$label」：不溢出', (tester) async {
          await _pumpCard(
            tester,
            data: _data(title: _longTitle, timeLabel: label),
            textScale: scale,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('极长时间标签也不溢出', (tester) async {
      // 不依赖具体字体的字宽：这个标签在**任何**字体下都挤，
      // 所以它验的是「挤了会下沉」这条规则本身，
      // 而不是「在测试字体的度量下恰好够宽」。
      await _pumpCard(
        tester,
        data: _data(title: _longTitle, timeLabel: absurdTime),
      );
      expect(tester.takeException(), isNull);
      expect(isStacked(tester, absurdTime), isTrue, reason: '挤成这样必须下沉');
    });

    // 副信息也得参数化，理由与时间标签同（§1.5）。
    //
    // 夹具里它一直钉死成「工作」两个字，而真实取值早就长得多了：
    // 重复任务的副信息是「分类 · 每 3 周的一、三、五」——
    // 一条**已经在跑的**代码路径，夹具却从没喂过它。
    group('副信息很长时（重复任务的规则说明）', () {
      const longSubtitle = '未分类 · 每 3 周的一、三、五';
      const absurdSubtitle =
          '某个名字特别长的分类 · 每 3 周的一、二、三、四、五、六、日，'
          '到 2027-12-31 为止';

      for (final scale in FontScale.goldenScales) {
        for (final subtitle in const [longSubtitle, absurdSubtitle]) {
          testWidgets('缩放 $scale × 长副信息（${subtitle.length} 字）：不溢出', (
            tester,
          ) async {
            await _pumpCard(
              tester,
              data: _data(
                title: _longTitle,
                categoryName: subtitle,
                // 重复图标要占掉副信息那一行的宽度，一并算进来。
                isRecurring: true,
                stageProgress: (2, 5),
              ),
              textScale: scale,
            );
            expect(tester.takeException(), isNull);
          });
        }
      }

      testWidgets('长副信息会被截断，而不是把卡片撑开', (tester) async {
        // 截断是刻意的（`maxLines: 1` + ellipsis）。没有这条的话，
        // 把它改成 `maxLines: 3` 也不会有任何测试变红，
        // 而那会让每张重复任务的卡片高度都不一样。
        await _pumpCard(
          tester,
          data: _data(categoryName: absurdSubtitle, isRecurring: true),
        );
        expect(
          _paragraphOf(tester, absurdSubtitle).didExceedMaxLines,
          isTrue,
          reason: '这么长的副信息应当省略号截断',
        );
      });
    });

    // ↓ 对照组（测试策略 §7.1.1）：保护的是**实现选择**，不是需求。
    //
    // 「一律下沉」能让上面每一条都绿 —— 溢出确实没了 ——
    // 但那是另一个设计：正常情况下时间就该在标题右边，
    // 一行显示「几点做什么」。没有这条，退化成一律下沉不会被发现。
    testWidgets('对照组：1.0× + 短标签时时间留在同一行', (tester) async {
      await _pumpCard(tester, data: _data(timeLabel: shortTime));
      expect(
        isStacked(tester, shortTime),
        isFalse,
        reason: '不挤的时候不该下沉，否则等于退化成「一律下沉」',
      );
    });
  });
}

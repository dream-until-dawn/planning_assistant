/// 任务卡片的**视觉回归**（测试策略 §7.1，快照型）。
///
/// **这个文件只拍图，不断言约束。** 与
/// `task_card_assertions_test.dart` 的分工是刻意的：
///
/// | | 本文件（快照型） | 断言型 |
/// |---|---|---|
/// | 产出 | 图片 | 无 |
/// | 断的是 | 外观 | 布局约束 |
/// | 改间距 token | **就该红** | 不该红 |
/// | 红了怎么办 | 人看图确认是否有意 | 布局真破了，去修 |
///
/// ## 这些图**不能**证明什么
///
/// 测试环境里没有中文字体，汉字全渲染成 .notdef 方框（□）——
/// 图看着像排版，其实汉字的字宽是 Roboto 的缺字宽度，不是真正的全角宽。
/// 而应用没有内置字体（pubspec 里没有 fonts:），线上用的是**系统字体**，
/// 各家 OEM 各不相同。也就是说：
///
/// - 这些图能证明的是**几何与配色**：色条位置、圆角、间距、明暗两套色、
///   完成态的划线与填充、逾期色条与逾期文字确实是两个色。
/// - 这些图**不能**证明「真机上中文不会溢出」——
///   字宽根本不是这里量到的那个。
///
/// 所以「大字号下不破版」这件事由断言型那边扛，而且要用
/// **任何字体下都挤**的极端标签去验规则本身
/// （见 assertions 里的「极长时间标签也不溢出」），
/// 不能靠某个字体的度量恰好越过阈值。
///
/// 覆盖矩阵：**明暗 × 三档有效缩放（1.0 / 2.0 / 2.8）= 6 组**。
/// 2.8 是应用内 1.4 × 系统 2.0，用户真能造出来的最坏值 ——
/// NFR-A11Y-02 字面只写了系统那一层（design-system §3.4）。
@Tags(['golden'])
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/design/components/task_card.dart';
import 'package:planning_assistant/design/theme/app_theme.dart';
import 'package:planning_assistant/design/tokens/dimensions.dart';

/// 一屏里放齐各种状态，一张图覆盖尽量多的组合。
///
/// 分成多张图的话，改一个 token 要看六七张才知道影响面。
const _cases = <(String, TaskCardData)>[
  (
    '普通',
    TaskCardData(
      title: '买菜',
      categoryName: '生活',
      categoryColor: Color(0xFF7FD1C1),
      timeLabel: '14:00',
    ),
  ),
  (
    '阶段事项',
    TaskCardData(
      title: '写季度总结',
      categoryName: '工作',
      categoryColor: Color(0xFFA8C8F0),
      timeLabel: '09:30',
      stageProgress: (2, 5),
    ),
  ),
  (
    '已完成',
    TaskCardData(
      title: '交水电费',
      categoryName: '生活',
      categoryColor: Color(0xFF7FD1C1),
      timeLabel: '10:00',
      isDone: true,
    ),
  ),
  (
    '逾期',
    TaskCardData(
      title: '预约体检',
      categoryName: '健康',
      categoryColor: Color(0xFFFFB7C5),
      timeLabel: '昨天 18:00',
      isOverdue: true,
    ),
  ),
  (
    '全天',
    TaskCardData(
      title: '读完这本书',
      categoryName: '学习',
      categoryColor: Color(0xFFFFD79A),
    ),
  ),
  (
    '超长标题',
    TaskCardData(
      title: '把这个季度所有还没有归档的项目文档整理一遍并逐个确认负责人与截止日期',
      categoryName: '工作',
      categoryColor: Color(0xFFA8C8F0),
      timeLabel: '23:59',
      stageProgress: (12, 20),
    ),
  ),
];

Widget _gallery(Brightness brightness, double scale) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.pageHorizontal),
        child: Column(
          children: [
            for (final (_, data) in _cases) ...[
              TaskCard(data: data, onToggleDone: () {}),
              const SizedBox(height: Spacing.cardGap),
            ],
          ],
        ),
      ),
    ),
  ),
);

/// 缩放越大内容越高，画布跟着放大，否则底下几张会被裁掉。
Size _surfaceFor(double scale) => Size(400, 900 * scale);

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in FontScale.goldenScales) {
      final name = 'task_card_${brightness.name}_x${scale.toStringAsFixed(1)}';

      testWidgets(name, (tester) async {
        await tester.binding.setSurfaceSize(_surfaceFor(scale));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(_gallery(brightness, scale));
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
      });
    }
  }
}

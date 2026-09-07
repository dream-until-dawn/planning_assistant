/// M0 冒烟：应用根能起来。
///
/// 这条测试的价值有限（它只能发现「根 Widget 直接崩溃」），
/// 保留它是因为 M2 会在此基础上扩成真正的外壳测试。
/// 按 testing-strategy §1 的标准，此刻它能被「PlanningAssistantApp 构造抛异常」
/// 或「home 为 null」弄红 —— 仅此而已，不宣称更多。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';

void main() {
  testWidgets('应用根可构建且渲染出占位页', (tester) async {
    await tester.pumpWidget(const PlanningAssistantApp());

    expect(find.text('计划助手'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('未开启 debug 横幅（发版观感）', (tester) async {
    await tester.pumpWidget(const PlanningAssistantApp());
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.debugShowCheckedModeBanner, isFalse);
  });
}

/// 应用根：MaterialApp + 路由 + 主题装配。
///
/// M0 阶段只是占位骨架。真正的主题装配见 docs/03-design/design-system.md §9，
/// 路由与外壳见 lib/features/shell/（M2）。
library;

import 'package:flutter/material.dart';

class PlanningAssistantApp extends StatelessWidget {
  const PlanningAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '计划助手',
      debugShowCheckedModeBanner: false,
      // TODO(M2): 换成 design/theme 装配的明暗双主题。
      // 刻意不用 ColorScheme.fromSeed —— 它会把低饱和色算成高饱和，
      // 破坏「可爱清新」基调。见 design-system.md §9。
      theme: ThemeData(useMaterial3: true),
      home: const _ScaffoldPlaceholder(),
    );
  }
}

/// M0 占位页。存在的意义只是让 `flutter run` 能起来并验证工具链。
class _ScaffoldPlaceholder extends StatelessWidget {
  const _ScaffoldPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('计划助手', style: TextStyle(fontSize: 24)),
              SizedBox(height: 8),
              Text('M0 · 工程基建', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

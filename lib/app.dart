/// 应用根：MaterialApp + 路由 + 主题装配。
///
/// 主题已接上 design/theme（M2）。路由与外壳见 lib/features/shell/，尚未做。
library;

import 'package:flutter/material.dart';

import 'design/theme/app_theme.dart';

class PlanningAssistantApp extends StatelessWidget {
  const PlanningAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '计划助手',
      debugShowCheckedModeBanner: false,
      // 明暗双主题由 design/theme 装配。刻意不用 ColorScheme.fromSeed ——
      // 它会把低饱和色算成高饱和，破坏「可爱清新」基调（design-system §9）。
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
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

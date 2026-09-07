/// 应用初始化编排。
///
/// `main.dart` 只负责调用它；这里也不写业务，只做启动期的装配顺序编排。
/// 依据 docs/01-architecture/module-map.md §1。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 启动应用。
///
/// [appBuilder] 由调用方提供，便于集成测试替换根 Widget。
Future<void> bootstrap(Widget Function() appBuilder) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 顶层错误兜底（NFR-REL-01）：任何未捕获异常都必须落日志，绝不静默吞掉。
  // M1 接入 core/logging 的门面后，这里改为写本地滚动日志文件。
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kReleaseMode) {
      // TODO(M1): 落本地日志文件，不外发（NFR-PRIV-01）
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('未捕获的异步异常: $error');
    return true;
  };

  // TODO(M1): 初始化顺序 —— 时区库 → 数据库 → 通知渠道 → 提醒对账
  runApp(ProviderScope(child: appBuilder()));
}

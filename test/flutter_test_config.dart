/// 测试环境的全局装配。`flutter test` 会自动找这个文件。
///
/// **唯一职责：把随包的 Quicksand 装进测试环境。**
///
/// 不装的话，golden 里的拉丁与数字用的是测试环境的默认字体（Roboto），
/// 而线上用的是打包进 APK 的 Quicksand —— 两者字宽不同，
/// 于是「golden 里不溢出」证明不了「真机上不溢出」。
///
/// 装上之后，**我们能控制的那一半变得可信了**：拉丁与数字的排版
/// 与线上一致。中文那一半仍然不可信，而且堵不上 —— 那是系统字体，
/// 各家 OEM 不同，不存在一个「正确的」基准（见 §3.2 与
/// `design/task_card_golden_test.dart` 顶部）。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 与 `pubspec.yaml` 的 `fonts:` 声明必须一致。
/// 不一致由 `design/font_test.dart` 判失败 —— 那条读的是 pubspec 本身。
const String fontFamily = 'Quicksand';
const String fontAsset = 'assets/fonts/Quicksand[wght].ttf';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 直接读文件而不是走 rootBundle：顺带证明字体真的在 pubspec 说的那个
  // 路径上。文件不在，这里就抛，而不是安静地退回默认字体。
  final bytes = File(fontAsset).readAsBytesSync();
  final loader = FontLoader(fontFamily)
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();

  await testMain();
}

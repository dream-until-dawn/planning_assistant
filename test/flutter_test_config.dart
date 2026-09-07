/// 测试环境的全局装配。`flutter test` 会自动找这个文件。
///
/// **职责：把界面上真实用到的字体装进测试环境。** 两种：
///
/// | 字体 | 从哪来 | 不装的后果 |
/// |---|---|---|
/// | Quicksand | 仓库里的 asset（随包） | 拉丁与数字按 Roboto 的字宽排版，与线上不同 |
/// | MaterialIcons | Flutter SDK 缓存 | **所有图标渲染成方框** |
///
/// 第二条是拍完外壳的第一张 golden 才发现的：整屏只有标题、
/// 一句文案和三个图标，而三个图标全是 □ —— 那张图证明不了
/// 「悬浮按钮长什么样」，而它恰恰是那一屏最显眼的东西。
///
/// 装上之后，**我们能控制的部分变得可信了**：拉丁、数字、图标的排版
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

/// Flutter 自带的图标字体。`uses-material-design: true` 会把它打进 APK，
/// 但**测试环境不会自动加载**，得自己找。
const String iconFontFamily = 'MaterialIcons';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 直接读文件而不是走 rootBundle：顺带证明字体真的在 pubspec 说的那个
  // 路径上。文件不在，这里就抛，而不是安静地退回默认字体。
  await _load(fontFamily, File(fontAsset));
  await _load(iconFontFamily, _materialIconsFile());

  await testMain();
}

Future<void> _load(String family, File file) async {
  final bytes = file.readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

/// 从 Flutter SDK 缓存里找图标字体。
///
/// **向上逐级找，不写死层数。** 初版按
/// 「`<flutter>/bin/cache/dart-sdk/bin/dart`，往上退四级」算，
/// 而 `flutter test` 里 `Platform.resolvedExecutable` 其实是
/// `<flutter>/bin/cache/artifacts/engine/windows-x64/flutter_tester.exe`
/// —— 层数不同，算出来的根是 `<flutter>/bin`。
///
/// 两种布局都存在，以后还可能有第三种，所以判据换成
/// 「哪一级祖先下面有这个文件」，与目录深度无关。
///
/// **找不到就抛，绝不静默跳过** —— 静默跳过的后果是图标继续渲染成方框，
/// 而 golden 会照常「通过」，只是拍到的是一屏 □。
/// 那正是这个文件要避免的事情本身。
File _materialIconsFile() {
  const relative =
      'bin/cache/artifacts/material_fonts/materialicons-regular.otf';

  final tried = <String>[];
  for (
    Directory? dir = File(Platform.resolvedExecutable).absolute.parent;
    dir != null;
    dir = dir.path == dir.parent.path ? null : dir.parent
  ) {
    final candidate = File('${dir.path}/$relative');
    tried.add(candidate.path);
    if (candidate.existsSync()) return candidate;
  }

  throw StateError(
    '找不到 MaterialIcons 字体。\n'
    '从 ${Platform.resolvedExecutable} 向上逐级找过：\n'
    '${tried.join('\n')}\n'
    '找不到就意味着 golden 里所有图标都是方框，所以这里直接失败，'
    '而不是让测试「通过」。',
  );
}

/// 视图注册表的完备性守卫（view-specs §7.3）。
///
/// §7.3 承诺「新增一个视图 = 枚举加一项 + 注册一个构建器」。
/// 这条守卫盯的是那个「+」被漏掉的情况。
///
/// **「没实现」和「忘了注册」在代码里长得一模一样** —— 都是注册表里
/// 没有那个键。区别只存在于写代码的人脑子里，所以必须写下来：
/// 每个枚举值要么在注册表里，要么在 `unimplementedViews` 里。
/// 两处都没有 = 用户点到一个没反应的按钮，而这在运行前就该被拦下。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/features/views/shared/application/view_kind.dart';

void main() {
  group('每个视图都有明确归属', () {
    test('注册表 ∪ 未实现名单 = 全部枚举值', () {
      final accounted = {...viewRegistry.keys, ...unimplementedViews};
      final missing = ViewKind.values.toSet().difference(accounted);
      expect(
        missing,
        isEmpty,
        reason:
            '这些视图既没注册也没列进未实现名单，'
            '切过去会是一个点了没反应的按钮：$missing',
      );
    });

    test('两边不重叠 —— 一个视图不能既实现又未实现', () {
      final both = viewRegistry.keys.toSet().intersection(unimplementedViews);
      expect(both, isEmpty, reason: '这些视图同时出现在注册表和未实现名单里：$both');
    });

    test('未实现名单里没有已经不存在的枚举值', () {
      // 名单会变成僵尸：视图删掉了，名单里还留着。
      expect(unimplementedViews.difference(ViewKind.values.toSet()), isEmpty);
    });
  });

  group('注册表本身不是空的', () {
    test('至少有一个视图能用', () {
      // 全部列进「未实现」也能让上面第一条绿 —— 那时应用没有任何界面。
      expect(viewRegistry, isNotEmpty);
    });

    test('默认视图必须是实装了的', () {
      // 否则冷启动直接落在一个没注册的视图上（§6 要求直达）。
      expect(
        viewRegistry.keys,
        contains(ViewKind.fallback),
        reason: '默认视图 ${ViewKind.fallback.label} 没有注册，冷启动会白屏',
      );
    });
  });
}

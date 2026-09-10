/// 注册表自检（settings-spec §1.2）。
///
/// 注册表是**纯数据**，所以这些性质能整表遍历着验 ——
/// 而不是等到某一条被构造时才由 assert 响一下（那还会在 release 里
/// 被剥掉，见 `SettingSpec` 里的注释）。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/features/settings/application/registry.dart';
import 'package:planning_assistant/features/settings/domain/setting_spec.dart';

void main() {
  group('FR-CFG-01 §1.2 的五条', () {
    test('key 全局唯一', () {
      final keys = settingsRegistry.map((s) => s.key).toList();
      expect(keys.toSet(), hasLength(keys.length), reason: '有重复的 key：$keys');
    });

    test('每个 defaultValue 都能通过自身的 validate', () {
      for (final spec in settingsRegistry) {
        final error = spec.validateDynamic(spec.defaultValueDynamic);
        expect(error, isNull, reason: '${spec.key} 的默认值自己就不合法：$error');
      }
    });

    test('每个 defaultValue 都能 encode 后 decode 回等值', () {
      // 往返不成立的话，「用户从没改过」与「用户设成了默认值」
      // 会得到两个不同的结果，而这两件事应当无从区分。
      for (final spec in settingsRegistry) {
        final roundTripped = spec.decodeDynamic(
          spec.encodeDynamic(spec.defaultValueDynamic),
        );
        expect(
          roundTripped,
          spec.defaultValueDynamic,
          reason: '${spec.key} 往返不等值',
        );
      }
    });

    test('exposed 的项都有 group 与文案', () {
      for (final spec in settingsRegistry.where((s) => s.isExposed)) {
        expect(spec.group, isNotNull, reason: '${spec.key} 没有分组，设置页不知道放哪');
        expect(spec.label, isNotNull, reason: '${spec.key} 没有文案');
        expect(spec.label, isNotEmpty);
      }
    });

    test('每个用到的 group 至少有一个 exposed 项', () {
      // 否则设置页出现空分组。反向的「没用到的 group」不算问题 ——
      // 分组是逐步搬进来的。
      final used = settingsRegistry
          .where((s) => s.isExposed)
          .map((s) => s.group)
          .toSet();
      for (final group in used) {
        final count = settingsRegistry
            .where((s) => s.isExposed && s.group == group)
            .length;
        expect(count, greaterThan(0));
      }
    });
  });

  group('select 类型的额外约束', () {
    test('每个 select 项都有选项，且默认值在选项里', () {
      // 默认值不在选项里的话，设置页打开就是「一个都没选中」，
      // 而 FR-CFG-01 说永远有值 —— 那时界面与实际值对不上。
      for (final spec in settingsRegistry.where(
        (s) => s.editor == SettingEditor.select,
      )) {
        expect(
          spec.optionsDynamic,
          isNotEmpty,
          reason: '${spec.key} 是 select 却没有选项',
        );
        expect(
          spec.optionsDynamic.map((o) => o.$1),
          contains(spec.defaultValueDynamic),
          reason: '${spec.key} 的默认值不在选项里',
        );
      }
    });

    test('选项的存储值互不相同', () {
      // 撞了的话，界面上两个选项会同时高亮，而且写进去只剩一个。
      for (final spec in settingsRegistry.where(
        (s) => s.editor == SettingEditor.select,
      )) {
        final encoded = spec.optionsDynamic
            .map((o) => spec.encodeDynamic(o.$1))
            .toList();
        expect(
          encoded.toSet(),
          hasLength(encoded.length),
          reason: '${spec.key} 的选项存储值有重复：$encoded',
        );
      }
    });

    test('选项文案互不相同', () {
      for (final spec in settingsRegistry.where(
        (s) => s.editor == SettingEditor.select,
      )) {
        final labels = spec.optionsDynamic.map((o) => o.$2).toList();
        expect(labels.toSet(), hasLength(labels.length), reason: spec.key);
      }
    });
  });

  group('控件类型与值的类型对得上', () {
    test('暴露的 toggle 项，值必须是 bool', () {
      // `SettingEditor` 的默认值就是 `toggle`，所以**忘了写 editor 的项
      // 会静悄悄变成开关**。值不是 bool 的话，设置页画不出开关，
      // 只能回落到那句「这个类型的控件还没做」——
      // 而那一行在页面上看着与别的项一样，key 也照样有。
      //
      // **只管暴露项**：隐藏项不上页面，逼它们挑一个控件是在问一个
      // 没人需要答的问题（`view.calendarSplitRatio` 就是一例：
      // 它是个 double，而 slider 这个控件根本还没做）。
      // 哪天把某个隐藏项暴露出来，这条当场就会拦住它 —— 而那正是
      // 需要答这个问题的时刻。
      for (final spec in settingsRegistry.where(
        (s) => s.isExposed && s.editor == SettingEditor.toggle,
      )) {
        expect(
          spec.defaultValueDynamic,
          isA<bool>(),
          reason:
              '${spec.key} 用的是 toggle，但默认值是 '
              '${spec.defaultValueDynamic.runtimeType} —— '
              '多半是忘了写 editor',
        );
      }
    });
  });

  group('解码的稳健性', () {
    test('认不出的存储值回落到默认，不抛', () {
      // 用户降级安装、或配置被别的版本写过时会读到这种值。
      for (final spec in settingsRegistry) {
        expect(
          () => spec.decodeDynamic('这个值任何版本都不认识'),
          returnsNormally,
          reason: '${spec.key} 遇到未知值时抛了',
        );
      }
    });

    test('类型不对的存储值也不抛', () {
      // JSON 里存的可能是数字、布尔、甚至对象 —— 库被别的东西写过。
      for (final spec in settingsRegistry) {
        for (final junk in <Object>[42, true, <String, Object>{}]) {
          expect(
            () => spec.decodeDynamic(junk),
            returnsNormally,
            reason: '${spec.key} 遇到 $junk 时抛了',
          );
        }
      }
    });
  });

  group('注册表的顺序（settings-spec §1.2）', () {
    test('分组是连续的，且顺序与 SettingGroup 的声明顺序一致', () {
      // ## 为什么这也要管
      //
      // 页面按 `SettingGroup.values` 分段渲染，所以**跨组的注册表顺序
      // 对界面没有影响** —— 看着像一条纯风格约定。
      //
      // 但它不是。设置页那条「每个暴露项都出现」是**照注册表顺序
      // 一路往下滚**的，而 `scrollUntilVisible` 只会往一个方向滚：
      // 注册表的组序一旦与页面对不上，走到某一项时它已经在上方，
      // 滚 50 次也找不到，报的是「Bad state: No element」——
      // 离「注册表的顺序不对」隔着三层。加两条备份配置时撞见过一次。
      //
      // 所以把它钉成一条明写的约束，而不是让下一个人再查一遍。
      final seen = <SettingGroup>[];
      for (final spec in settingsRegistry) {
        // 没写 group 的只可能是隐藏项（上面那条「exposed 的项都有 group」
        // 盯着），它们不上页面，夹在哪儿都不影响顺序。
        final group = spec.group;
        if (group == null) continue;
        if (seen.isNotEmpty && seen.last == group) continue;
        expect(
          seen,
          isNot(contains(group)),
          reason: '${spec.key} 所在的 ${group.name} 组在注册表里断开了',
        );
        seen.add(group);
      }
      expect(
        seen,
        SettingGroup.values.where(seen.contains).toList(),
        reason: '注册表的分组顺序与 SettingGroup 的声明顺序不一致',
      );
    });
  });

  group('注册表不是空的', () {
    test('至少有一项，且至少有一项是暴露的', () {
      // 空注册表能让上面每一条都「通过」—— 全称量词在空集上恒真。
      expect(settingsRegistry, isNotEmpty);
      expect(settingsRegistry.where((s) => s.isExposed), isNotEmpty);
    });
  });
}

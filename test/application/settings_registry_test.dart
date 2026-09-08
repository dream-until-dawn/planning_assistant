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
  group('§1.2 的五条', () {
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

  group('注册表不是空的', () {
    test('至少有一项，且至少有一项是暴露的', () {
      // 空注册表能让上面每一条都「通过」—— 全称量词在空集上恒真。
      expect(settingsRegistry, isNotEmpty);
      expect(settingsRegistry.where((s) => s.isExposed), isNotEmpty);
    });
  });
}

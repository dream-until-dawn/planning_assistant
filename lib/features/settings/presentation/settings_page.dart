/// 设置页（settings-spec §4、FR-CFG-07）。
///
/// **遍历注册表渲染，不写死任何一项。** 加一项配置 = 注册表加一条，
/// 这个文件一个字不用改 —— 那就是 FR-CFG-07 的兑现方式，
/// 也是「加一项配置 ≤1 处改动」（NFR-MAINT-04）唯一站得住的实现。
///
/// 分组与顺序由 `SettingGroup` 的声明顺序 + 注册表内的顺序决定。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/theme/app_theme.dart';
import '../../../design/tokens/dimensions.dart';
import '../application/registry.dart';
import '../application/settings_providers.dart';
import '../domain/setting_spec.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const Key pageKey = ValueKey('settings-page');

  /// 某一项的 Key。
  static Key itemKey(String settingKey) => ValueKey('setting-$settingKey');

  /// 某一项的某个选项的 Key。
  static Key optionKey(String settingKey, String storageValue) =>
      ValueKey('setting-$settingKey-$storageValue');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;

    // 只渲染暴露的项。隐藏项照常参与读取与导入导出（FR-CFG-08），
    // 只是没有入口。
    final exposed = settingsRegistry.where((s) => s.isExposed).toList();

    return Scaffold(
      key: pageKey,
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('设置'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.pageHorizontal),
          children: [
            for (final group in SettingGroup.values)
              ..._groupSection(context, ref, group, exposed),
          ],
        ),
      ),
    );
  }

  List<Widget> _groupSection(
    BuildContext context,
    WidgetRef ref,
    SettingGroup group,
    List<SettingSpecBase> exposed,
  ) {
    final items = exposed.where((s) => s.group == group).toList();
    // **空分组不画标题。** settings-spec §1.2 有一条断言要求每个分组至少
    // 有一个暴露项，但那条约束的是注册表；这里再挡一道，
    // 因为注册表是逐步搬进来的，中间态必然有空分组。
    if (items.isEmpty) return const [];

    final text = Theme.of(context).textTheme;
    return [
      Padding(
        padding: const EdgeInsets.only(
          top: Spacing.groupGap,
          bottom: Spacing.sm,
        ),
        child: Text(group.title, style: text.titleMedium),
      ),
      for (final spec in items) _SettingTile(spec: spec),
    ];
  }
}

class _SettingTile extends ConsumerWidget {
  const _SettingTile({required this.spec});

  final SettingSpecBase spec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final current = ref.settingDynamic(spec);

    return Padding(
      key: SettingsPage.itemKey(spec.key),
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(spec.label!, style: text.bodyLarge),
          if (spec.description != null) ...[
            const SizedBox(height: Spacing.xxs),
            Text(spec.description!, style: text.bodySmall),
          ],
          const SizedBox(height: Spacing.sm),
          switch (spec.editor) {
            // `select` 用一排 Chip 而不是下拉：选项都在两三个到四个之间，
            // 摊开一眼看全，也省一次「点开-再点」的往返。
            SettingEditor.select => _Options(spec: spec, current: current),
            // 其余控件等有对应的配置项时再做。**不放占位控件** ——
            // 点了没反应的开关比没有更糟。
            _ => Text(
              '（这个类型的控件还没做：${spec.editor.name}）',
              style: text.bodySmall,
            ),
          },
        ],
      ),
    );
  }
}

class _Options extends ConsumerWidget {
  const _Options({required this.spec, required this.current});

  final SettingSpecBase spec;
  final Object? current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;

    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.xs,
      children: [
        for (final (value, label) in spec.optionsDynamic)
          _OptionChip(
            key: SettingsPage.optionKey(
              spec.key,
              '${spec.encodeDynamic(value)}',
            ),
            label: label,
            selected: value == current,
            onTap: () =>
                ref.read(settingsWriterProvider).setDynamic(spec, value),
            colors: colors,
            text: text,
          ),
      ],
    );
  }
}

/// 单选项。
///
/// 与筛选条的 `SelectableChip` 长得像但**语义不同**：那个是多选、
/// 点第二下会取消；这个是单选，点已选中的一项**什么也不做** ——
/// 配置项没有「都不选」这个状态（FR-CFG-01：永远有值）。
class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colors,
    required this.text,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppSemanticColors colors;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(Radii.full),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Spacing.minTouchTarget),
          child: Center(
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? colors.brandFill : colors.sunken,
                borderRadius: BorderRadius.circular(Radii.full),
                border: Border.all(
                  color: selected ? colors.brandGraphic : colors.borderSubtle,
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: Spacing.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 选中态**不只靠颜色**（§8.1）——灰度屏也要分得出。
                    if (selected) ...[
                      Icon(
                        Icons.check,
                        size: TypeScale.labelSize * 1.2,
                        color: colors.onBrand,
                      ),
                      const SizedBox(width: Spacing.xs),
                    ],
                    Text(
                      label,
                      style: text.labelLarge?.copyWith(
                        color: selected ? colors.onBrand : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

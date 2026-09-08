/// 视图共享状态（view-specs §0.1、FR-VIEW-05/06）。
@TestOn('vm')
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app_providers.dart';
import 'package:planning_assistant/core/time/clock.dart';
import 'package:planning_assistant/core/time/plan_date.dart';
import 'package:planning_assistant/core/time/time_zone_resolver.dart';
import 'package:planning_assistant/domain/entities/task.dart';
import 'package:planning_assistant/domain/value_objects/task_status.dart';
import 'package:planning_assistant/features/views/shared/application/view_shared_state.dart';
import 'package:timezone/data/latest.dart' as tzdata;

ProviderContainer _container({required DateTime nowUtc, required String zone}) {
  final container = ProviderContainer(
    overrides: [
      clockProvider.overrideWithValue(FixedClock(nowUtc)),
      timeZoneResolverProvider.overrideWithValue(
        TzTimeZoneResolver(fixedCurrentZoneId: zone),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('「今天」是本地墙钟的今天，不是 UTC 的今天', () {
    test('东八区：UTC 还在昨天，本地已经是今天', () {
      // 2026-09-07 23:00 UTC = 2026-09-08 07:00 Asia/Shanghai。
      // 直接把 nowUtc 截成日期会得到 9/7 —— 用户一早打开应用，
      // 看到的是昨天的安排。
      final c = _container(
        nowUtc: DateTime.utc(2026, 9, 7, 23),
        zone: 'Asia/Shanghai',
      );
      expect(
        c.read(viewSharedStateProvider).focusedDate,
        const PlanDate(2026, 9, 8),
      );
    });

    test('西五区：UTC 已经是明天，本地还在今天', () {
      // 2026-09-08 02:00 UTC = 2026-09-07 22:00 America/New_York。
      // 反方向的同一个错：晚上用应用会跳到明天。
      final c = _container(
        nowUtc: DateTime.utc(2026, 9, 8, 2),
        zone: 'America/New_York',
      );
      expect(
        c.read(viewSharedStateProvider).focusedDate,
        const PlanDate(2026, 9, 7),
      );
    });

    test('同一时刻在两个时区给出不同的「今天」', () {
      // 上面两条各自成立，也可能是因为实现恰好在两处都返回了固定值。
      // 这条比较的是**同一个瞬时**在两个时区的结果必须不同。
      final instant = DateTime.utc(2026, 9, 7, 23);
      final east = _container(nowUtc: instant, zone: 'Asia/Shanghai');
      final west = _container(nowUtc: instant, zone: 'America/New_York');
      expect(
        east.read(viewSharedStateProvider).focusedDate,
        isNot(west.read(viewSharedStateProvider).focusedDate),
      );
    });
  });

  group('筛选', () {
    test('默认不筛，且 isEmpty 为真', () {
      final c = _container(
        nowUtc: DateTime.utc(2026, 9, 7, 3),
        zone: 'Asia/Shanghai',
      );
      final state = c.read(viewSharedStateProvider);
      expect(state.filter, FilterSpec.none);
      expect(state.filter.isEmpty, isTrue);
    });

    test('设了筛选之后 isEmpty 为假', () {
      // 对照组：否则 isEmpty 恒真也能让上面那条绿。
      // 每个维度都要单独试 —— 只试一个的话，别的维度漏进 isEmpty
      // 不会被发现，表现是「设了筛选却当成没筛」。
      expect(const FilterSpec(categoryIds: {'work'}).isEmpty, isFalse);
      expect(const FilterSpec(categoryIds: {null}).isEmpty, isFalse);
      expect(const FilterSpec(statuses: {TaskStatus.done}).isEmpty, isFalse);
      expect(
        const FilterSpec(priorities: {TaskPriority.urgent}).isEmpty,
        isFalse,
      );
      expect(const FilterSpec(keyword: '体检').isEmpty, isFalse);
      expect(const FilterSpec(dateFrom: PlanDate(2026, 9, 1)).isEmpty, isFalse);
      expect(const FilterSpec(dateTo: PlanDate(2026, 9, 30)).isEmpty, isFalse);
    });

    test('只有空白的关键词不算筛选', () {
      // 输入框里剩个空格就当成「正在筛选」的话，
      // 用户会看到一个清不掉的「已筛选」状态。
      expect(const FilterSpec(keyword: '   ').isEmpty, isTrue);
    });

    test('关键词可以被清空', () {
      // copyWith 用 `?? this.x` 的话，传 null 表示「不改」，
      // 于是清空关键词这个功能实现不出来。
      const withKeyword = FilterSpec(keyword: '体检');
      expect(withKeyword.copyWith(keyword: null).keyword, isNull);
    });

    test('对照组：不传关键词时保持原值', () {
      // 否则「一律清空」也能让上面那条绿。
      const withKeyword = FilterSpec(keyword: '体检');
      expect(withKeyword.copyWith(statuses: {TaskStatus.done}).keyword, '体检');
    });

    test('值相等按内容比，不按引用', () {
      // 状态要参与 Riverpod 的重建判定，引用相等会让筛选改了不刷新，
      // 或者没改也刷新。
      expect(
        const FilterSpec(categoryIds: {'a', 'b'}),
        const FilterSpec(categoryIds: {'b', 'a'}),
      );
      expect(
        const FilterSpec(categoryIds: {'a'}).hashCode,
        const FilterSpec(categoryIds: {'a'}).hashCode,
      );
      expect(
        const FilterSpec(categoryIds: {'a'}),
        isNot(const FilterSpec(categoryIds: {'b'})),
      );
    });
  });

  group('选中态', () {
    test('可以被清掉（点空白处取消选中）', () {
      const state = ViewSharedState(
        focusedDate: PlanDate(2026, 9, 7),
        selectedOccurrenceId: 'occ-1',
      );
      expect(
        state.copyWith(selectedOccurrenceId: null).selectedOccurrenceId,
        isNull,
      );
    });

    test('对照组：不传时保持原值', () {
      const state = ViewSharedState(
        focusedDate: PlanDate(2026, 9, 7),
        selectedOccurrenceId: 'occ-1',
      );
      expect(
        state.copyWith(granularity: TimeGranularity.week).selectedOccurrenceId,
        'occ-1',
      );
    });
  });

  group('状态跨「视图切换」保持（FR-VIEW-05/06）', () {
    test('改筛选与聚焦日期后，读到的还是同一份', () {
      // 视图切换不换路由，所以这里没有什么可以「恢复」——
      // 这条验的是 provider 本身不会自己把状态丢掉。
      final c = _container(
        nowUtc: DateTime.utc(2026, 9, 7, 3),
        zone: 'Asia/Shanghai',
      );
      final notifier = c.read(viewSharedStateProvider.notifier)
        ..setFilter(const FilterSpec(categoryIds: {'work'}))
        ..focusDate(const PlanDate(2026, 9, 20))
        ..setGranularity(TimeGranularity.week);

      final state = c.read(viewSharedStateProvider);
      expect(state.filter.categoryIds, {'work'});
      expect(state.focusedDate, const PlanDate(2026, 9, 20));
      expect(state.granularity, TimeGranularity.week);

      notifier.clearFilter();
      expect(c.read(viewSharedStateProvider).filter, FilterSpec.none);
      // 清筛选**不该**顺手改掉聚焦日期。
      expect(
        c.read(viewSharedStateProvider).focusedDate,
        const PlanDate(2026, 9, 20),
      );
    });

    test('focusToday 回到本地今天', () {
      final c = _container(
        nowUtc: DateTime.utc(2026, 9, 7, 23),
        zone: 'Asia/Shanghai',
      );
      c.read(viewSharedStateProvider.notifier)
        ..focusDate(const PlanDate(2020, 1, 1))
        ..focusToday();
      expect(
        c.read(viewSharedStateProvider).focusedDate,
        const PlanDate(2026, 9, 8),
      );
    });
  });

  group('Provider 忘了覆盖时必须炸', () {
    // Riverpod 3 把 provider 里抛的异常包进 ProviderException，
    // 顶层消息只有一句「Tried to use a provider that is in error state」——
    // 我们那句「必须在 overrides 中提供」在 `.exception` 里。
    // 所以断言要挖到里层，否则等于只验了「抛了点什么」。
    //
    // `ProviderException` 没有从 flutter_riverpod 导出，而为了一个断言去
    // import 传递依赖 `package:riverpod` 不划算 —— 所以用 predicate
    // 动态取 `.exception`，并给一句人能读懂的描述。
    Matcher missingOverride(String name) => throwsA(
      predicate((Object? e) {
        final inner = (e as dynamic).exception;
        return inner is StateError && inner.message.contains(name);
      }, '一个包着「提到 $name 的 StateError」的 ProviderException'),
    );

    test('没覆盖就读，抛出的错要指名道姓', () {
      // 给默认值的话，测试会静默用上真实时钟 ——
      // 「测试依赖真实时间」要等到某天半夜跑 CI 才暴露。
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(() => c.read(clockProvider), missingOverride('clockProvider'));
      expect(
        () => c.read(timeZoneResolverProvider),
        missingOverride('timeZoneResolverProvider'),
      );
      expect(
        () => c.read(timeZoneSetupProvider),
        missingOverride('timeZoneSetupProvider'),
      );
    });
  });
}

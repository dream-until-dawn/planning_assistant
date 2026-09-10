/// 我们依赖的一条 Riverpod 传播时序（`ReminderSyncScope` 建在它上面）。
///
/// ## 为什么这条要有测试
///
/// 续排是「源变了 → 在监听回调里读一批 provider → 照读到的排」。
/// 那批里有派生的 provider，而**在源的监听回调里同步读下游，读到的值
/// 不可靠**：实测下来时对时错。推迟一个微任务再读，每次都对。
///
/// ## 两个被证伪的解释，都记下来
///
/// 这条是查一个真缺陷时挖出来的：改了提醒之后那一轮续排读到旧值，
/// 监听确实触发、手动再调立刻就对。
///
/// **解释一（我写的）：「没人 watch 的派生 provider 会读到旧值」。**
/// 假的 —— 下面第二条用例给它加了真正的订阅者，一样错。
/// 假因果比没有解释更糟：它会让下一个人去「加个 watcher」，而那什么也
/// 不解决。
///
/// **解释二（评审写的）：「下游的重算排在监听回调之后」。**
/// 方向对，但它预言的是**每一次都滞后**，而实测是**时对时错**
/// （见第一条用例里那串 `[-1, 1, 1, 3]`：第 2 次错、第 1 和第 3 次对）。
/// 所以这也只是部分解释。
///
/// **所以这一份只钉可观察的事实，不写机制**：同步读不可靠、
/// 推迟一个微任务就可靠。`_sync()` 推迟微任务的理由就是最后那一条 ——
/// 它是这三条里唯一稳定的。
///
/// 升级 Riverpod 时这一份大概会红。红了要做的**不是**调断言迁就它，
/// 是重新问一遍「同步读还可不可靠」——若变可靠了，`_sync()` 里那个
/// 微任务就可以去掉；若换了个错法，那个微任务更得留着。
@TestOn('vm')
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _source = StreamProvider<int>((ref) => const Stream<int>.empty());
final _derived = Provider<int>(
  (ref) => switch (ref.watch(_source)) {
    AsyncData(:final value) => value,
    _ => -1,
  },
);

/// 装一个容器，把 [_source] 换成受控的流。
({ProviderContainer container, void Function(int) push, void Function() close})
_setUp() {
  final controller = StreamController<int>();
  final container = ProviderContainer(
    overrides: [_source.overrideWith((ref) => controller.stream)],
  );
  addTearDown(container.dispose);
  addTearDown(controller.close);
  return (
    container: container,
    push: controller.add,
    close: () => unawaited(controller.close()),
  );
}

void main() {
  test('**在源的监听回调里同步读派生 → 结果不可靠**', () async {
    final (:container, :push, close: _) = _setUp();
    final seenBySource = <int?>[];
    final seenByDerived = <int>[];

    container.listen(_source, (_, next) {
      seenBySource.add(next.value);
      // 同步读下游 —— 本次变更还没传到它。
      seenByDerived.add(container.read(_derived));
    }, fireImmediately: true);

    for (final v in [1, 2, 3]) {
      push(v);
      await Future<void>.delayed(Duration.zero);
    }

    expect(seenBySource, [null, 1, 2, 3]);
    // **不是「每次晚一拍」**：第 1、3 次读对了，第 2 次读到的是上一个值。
    // 钉住这串具体的数是为了让「同步读不可靠」这句话有个能红的锚 ——
    // 而不是因为我们理解了它为什么这么排。
    expect(seenByDerived, [
      -1,
      1,
      1,
      3,
    ], reason: '同步读派生的结果变了 —— 去看这个文件头那两条被证伪的解释');
  });

  test('**有人 watch 也一样错** —— 「没人 watch」不是原因', () async {
    // 这条是评审加的对照。少了它，注释里那句假因果
    // （「没人 watch 的派生 provider 会读到旧值」）读起来完全成立，
    // 而下一个人会去加一个 watcher，然后什么也不解决。
    final (:container, :push, close: _) = _setUp();
    final seenByDerived = <int>[];

    // 先让它有一个真正的订阅者。
    container.listen(_derived, (_, _) {});

    container.listen(_source, (_, _) {
      seenByDerived.add(container.read(_derived));
    });

    for (final v in [1, 2]) {
      push(v);
      await Future<void>.delayed(Duration.zero);
    }

    // 第 2 次仍然读到 1 —— 有订阅者也救不了。
    expect(seenByDerived, [
      1,
      1,
    ], reason: '有 watcher 就不错的话，这条会是 [1, 2]，那句假因果也就成立了');
  });

  test('**推迟一个微任务再读就对了** —— 修法在这儿', () async {
    final (:container, :push, close: _) = _setUp();
    final seenByDerived = <int>[];

    container.listen(_source, (_, _) {
      // 与上面唯一的差别：换一个时刻读。
      Future<void>.microtask(() => seenByDerived.add(container.read(_derived)));
    });

    for (final v in [1, 2, 3]) {
      push(v);
      await Future<void>.delayed(Duration.zero);
    }

    expect(seenByDerived, [1, 2, 3], reason: '推迟之后还滞后的话，`_sync()` 那个微任务就白加了');
  });
}

/// **续排读到的每一个数据源，都要在它的触发集里**（testing-strategy §3.8）。
///
/// ## 这一族与「每一列都要被读回来」同形
///
/// 那一条问「写进去的读回来了没有」，这一条问「读的东西变了会不会重算」。
/// 域都可枚举：那边是表的列，这边是**一个函数体里 `ref.read(...)` 了哪些
/// provider** —— 静态可数。
///
/// 立它的由头是 M4 接线时的一个真缺陷（评审挑出一半、写用例撞出另一半）：
/// `_sync()` 读了 `stagesByTaskProvider` / `stageStatesByTaskProvider`，
/// 而监听集里一个都没有 —— **改一个阶段不触发续排**。
/// 算法有测试兜着，接线没有。
///
/// ## 判据
///
/// > `resyncNow()` 体内读到的每一个 provider，要么直接在 `ref.listen`
/// > 的触发集里，要么**传递地**依赖触发集里的某一个；
/// > 否则进豁免表，并写明「它变了为什么不需要重排」。
///
/// 「传递地」那一半是必须的：续排读的是 `stagesByTaskProvider`（派生），
/// 而监听的是 `allStagesProvider`（源）。**派生 provider 的值随源变化，
/// 所以监听源就够。** 但这个「就够」不能靠记忆 —— 下面那张别名表把它写成
/// 一条**声明**，并由守卫回去核对那条声明是不是真的（见「别名表的自检」）。
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _wiring = 'lib/features/reminder/application/reminder_providers.dart';

/// 派生 provider → 它依赖的源。
///
/// **这是一条会被核对的声明，不是一张备忘。** 下面「别名表的自检」会去
/// 找每个派生 provider 的定义，确认它真的 `watch` 了所声明的那个源；
/// 声明错了或者实现改了，那条自检先红。
const Map<String, String> kDerivedFrom = {
  'remindersByTaskProvider': 'allRemindersProvider',
  'stagesByTaskProvider': 'allStagesProvider',
  'stageStatesByTaskProvider': 'allStageStatesProvider',
};

/// 读了但不必进触发集的，每条都要写明「它变了为什么不需要重排」。
const Map<String, String> kExemptReads = {
  'clockProvider':
      '时钟是**注入的协作者**，不是数据源 —— 它没有「变了」这回事，'
      '每次读都给出当时的时刻。为什么不改实现：给它加监听等于每次读都重排。',
  'timeZoneResolverProvider':
      '同上，注入的换算器。时区**真的变了**走的是另一条路：'
      '「下次启动检查」（notifications.md §7 的设计选择，已记录降级），'
      '不靠续排的监听集。为什么不改实现：那条路是有意选的，不是漏的。',
  'todayProvider':
      '跨零点会变，而**变了不必立刻重排**：窗口是从「现在」起算的滚动窗口'
      '（见 `resyncNow` 头注），今天与明天算出的窗口相差一天，'
      '而窗口长度默认 14 天 —— 已排的那些不会因为跨了零点失效。'
      '为什么不改实现：为它加监听会让每天零点无谓地重排一次全窗口。',
};

String _read(String path) => File(path).readAsStringSync();

/// 取 `name` 那个方法/函数的体（大括号配对）。
String bodyOf(String src, String signature) {
  final at = src.indexOf(signature);
  if (at < 0) return '';
  final open = src.indexOf('{', at);
  var depth = 0;
  for (var i = open; i < src.length; i++) {
    if (src[i] == '{') depth++;
    if (src[i] == '}') {
      depth--;
      if (depth == 0) return src.substring(open, i);
    }
  }
  return '';
}

Set<String> readsIn(String body) => {
  for (final m in RegExp(r'ref\.read\((\w+)').allMatches(body)) m.group(1)!,
};

/// 续排体内**读配置**的那些（`settingOf(ref, xxx)`）。
///
/// ## 为什么这一半必须单列出来
///
/// 头一版的 `readsIn` 只认 `ref.read(...)` 一种拼法 —— 于是守卫全绿，
/// 而 `resyncNow` 里那句 `settingOf(ref, reminderWindowDays)` 它根本看不见。
/// **机制要锚在判据上，不是锚在判据的一种写法上**：判据说的是
/// 「读到的数据源」，而配置也是数据源，只是换了个读法。
///
/// 补上之后当场露出一个真缺陷：改「滚动排期窗口」不会触发续排
/// （见下面那条用例）。
Set<String> settingReadsIn(String body) => {
  for (final m in RegExp(r'settingOf\(ref,\s*(\w+)\)').allMatches(body))
    m.group(1)!,
};

Set<String> listensIn(String body) => {
  for (final m in RegExp(r'ref\.listen\((\w+)').allMatches(body)) m.group(1)!,
};

void main() {
  final src = _read(_wiring);
  final resync = bodyOf(src, 'Future<ResyncOutcome> resyncNow()');
  final scope = bodyOf(src, 'Widget build(BuildContext context)');

  test('前提：两段都切得出来（守卫不对着空字符串报绿）', () {
    // 少了这条，改一次方法签名就能让整个守卫无声地变成一句空话 ——
    // 而它报的会是「全都覆盖了」。
    expect(resync, isNotEmpty, reason: 'resyncNow 的体没切出来');
    expect(scope, isNotEmpty, reason: 'ReminderSyncScope.build 的体没切出来');
    expect(
      readsIn(resync).length,
      greaterThanOrEqualTo(5),
      reason: '读得太少，多半切错了',
    );
    expect(
      listensIn(scope).length,
      greaterThanOrEqualTo(5),
      reason: '监听得太少，多半切错了',
    );
  });

  test('FR-NOTI-01 续排读到的每个源，都在触发集里（或传递地在）', () {
    final listens = listensIn(scope);
    final uncovered = <String>[];
    for (final p in readsIn(resync)) {
      if (kExemptReads.containsKey(p)) continue;
      if (listens.contains(p)) continue;
      if (listens.contains(kDerivedFrom[p])) continue;
      uncovered.add(p);
    }
    expect(
      uncovered,
      isEmpty,
      reason:
          '续排会读这些，而它们变了不会触发续排：$uncovered\n'
          '要么加进 ref.listen，要么进 kExemptReads 并写明为什么不必重排。',
    );
  });

  test('FR-NOTI-01 续排读到的每一条配置，都在被监听的那个配置包里', () {
    // 配置也是数据源，只是读法不同（`settingOf` 而不是 `ref.read`）。
    // 被监听的 provider 多半是**记录**（`reminderSettingsProvider`），
    // 记录的值变了才会通知；所以续排读的每条配置都必须是**某个被监听的
    // provider 读过的**，否则改它不会让任何被监听的值变，也就不会重排。
    // 覆盖面 = **被监听的每一个 provider** 各自读了哪些配置的并集。
    // 不写死某一个 provider：窗口那条就是单独一个 provider，
    // 把判据钉在「配置包」上会让它显得非并进那个记录不可。
    final covered = <String>{};
    for (final p in listensIn(scope)) {
      covered.addAll(settingReadsIn(_findDefinition(p) ?? ''));
    }
    expect(covered, isNotEmpty, reason: '被监听的 provider 一条配置都没读到，多半切错了');

    final outside = [
      for (final spec in settingReadsIn(resync))
        if (!covered.contains(spec)) spec,
    ];
    // 续排现在改成读 `reminderWindowDaysProvider` 了，所以这条断言的
    // **直接**对象可能是空集 —— 但它守的口子没有关：谁哪天图省事在
    // 续排体里直接写一句 `settingOf(ref, xxx)`，它立刻回到有事可做的状态。
    // 这就是「它守着一条将来才会开的口子」，不是「它现在挡着一个洞」。
    expect(
      outside,
      isEmpty,
      reason:
          '续排会读这几条配置，而它们不在被监听的配置包里：$outside\n'
          '改它们不会触发续排。把它们并进 ReminderSettings，'
          '或者单独监听（前者更好：少一个会漂移的地方）。',
    );
  });

  group('别名表的自检 —— 声明必须与实现相符', () {
    test('每个派生 provider 都真的 watch 了它声明依赖的那个源', () {
      // 「派生的跟着源变」这句话如果只写在注释里，实现改掉之后它仍然
      // 读着像真的。这里回去核对一遍。
      for (final e in kDerivedFrom.entries) {
        final def = _findDefinition(e.key);
        expect(def, isNotNull, reason: '${e.key} 的定义找不到了');
        expect(
          def!.contains('ref.watch(${e.value})') ||
              def.contains('watch(${e.value})'),
          isTrue,
          reason: '${e.key} 声明依赖 ${e.value}，但它的定义里没有 watch 它',
        );
      }
    });

    test('别名表里没有僵尸 —— 声明的派生 provider 确实还被续排读着', () {
      final reads = readsIn(resync);
      for (final k in kDerivedFrom.keys) {
        expect(
          reads,
          contains(k),
          reason: '$k 已经不被续排读了 —— 把这条别名删掉，别留着让人以为它在管事',
        );
      }
    });
  });

  group('豁免表的反僵尸', () {
    test('每条豁免当前确实还在被读 —— 不读了就该删掉它', () {
      final reads = readsIn(resync);
      for (final k in kExemptReads.keys) {
        expect(reads, contains(k), reason: '$k 已经不被续排读了，这条豁免是僵尸');
      }
    });

    test('每条豁免都回答了「为什么不改实现」', () {
      for (final e in kExemptReads.entries) {
        expect(
          e.value.contains('为什么不改实现'),
          isTrue,
          reason: '${e.key} 是与守卫同批进来的豁免，必须回答这一问',
        );
      }
    });
  });

  group('守卫自身能失败（§1.4）', () {
    test('少监听一个源会被抓出来', () {
      const body = 'ref.read(aProvider); ref.read(bProvider);';
      const scopeBody = 'ref.listen(aProvider, (_, _) => x());';
      final uncovered = [
        for (final p in readsIn(body))
          if (!listensIn(scopeBody).contains(p)) p,
      ];
      expect(uncovered, ['bProvider']);
    });

    test('传递覆盖算数：读派生的、监听源的', () {
      const body = 'ref.read(stagesByTaskProvider);';
      const scopeBody = 'ref.listen(allStagesProvider, (_, _) => x());';
      final listens = listensIn(scopeBody);
      final uncovered = [
        for (final p in readsIn(body))
          if (!listens.contains(p) && !listens.contains(kDerivedFrom[p])) p,
      ];
      expect(uncovered, isEmpty);
    });
  });
}

/// 在 `lib/` 里找一个顶层 provider 的定义体。
String? _findDefinition(String name) {
  for (final f in Directory(
    'lib',
  ).listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.dart') || f.path.endsWith('.g.dart')) continue;
    final src = f.readAsStringSync();
    final at = src.indexOf('final $name =');
    if (at < 0) continue;
    // 到下一个顶层 `);` 为止，够覆盖 provider 的构造体。
    final end = src.indexOf('\n);', at);
    return src.substring(at, end < 0 ? src.length : end);
  }
  return null;
}

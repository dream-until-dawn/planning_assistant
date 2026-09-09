/// **重复规则的每个旋钮，用户都得够得着**（FR-TASK-03/04）。
///
/// ## 这条测试是为了什么写的
///
/// 第一版的重复区漏了三个控件：间隔、次数、结束日期。
/// `interval` 恒为 1、`count` 恒为默认的 10、`until` 永远是 null ——
/// 而 `RecurrenceDraft` 的单元测试把这三个都测透了，856 条全绿。
/// 测的是**模型**：给定一个 draft，编出来的串对不对、展开的日子对不对。
/// 没有一条问过：**用户能不能造出那个 draft**。
///
/// 最难看的是「到某天为止」：选中它 → 规则必然非法 → 保存永久灰着，
/// 而页面上没有任何地方能选那个日期。一条走进去出不来的路。
/// 当时确实有一条测试盯着它，断言「拦住了、没落库」，然后就停在那儿 ——
/// **验证了「拦住」，没验证「拦住之后有路走」**。
///
/// ## 所以这里怎么验
///
/// 每个旋钮一条：走真界面把它拨到**非默认值**，保存，然后看**落库的
/// RRULE 串**变成了该变的样子。不看 draft、不看界面文案 —— 那两者
/// 都可能在链路断掉时依然好看（M2 里已经栽过一次：draft 和界面都对，
/// `categoryId` 却没进命令）。
///
/// 外加一条**完备性守卫**：探针表必须覆盖 `RecurrenceDraft` 的每个字段。
/// 以后加一个字段却忘了配控件，这条会红 —— 这正是当初漏掉的那件事。
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/core/time/weekday.dart';
import 'package:planning_assistant/features/task/application/recurrence_draft.dart';
import 'package:planning_assistant/features/task/application/task_shape.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';

import '../support/app_harness.dart';

/// 装的时钟是 2026-09-07 11:00（上海），也就是**周一**。
/// 于是「今天」= 2026-09-07，结束日期选择器的默认（+30 天）= 2026-10-07。
const _plusThirty = '20261007';

Future<Harness> _pumpEditor(WidgetTester tester) async {
  await setScreenSize(tester, const Size(390, 844));

  final harness = appHarness();
  await tester.pumpWidget(
    ProviderScope(overrides: harness.overrides, child: PlanningAssistantApp()),
  );
  await tester.pumpAndSettle();

  await tapCreate(tester, TaskShape.recurringSingle);
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '晨会');
  await tester.pump();
  return harness;
}

/// 保存并取回落库的规则串。
Future<String?> _saveAndReadRule(WidgetTester tester, Harness harness) async {
  await tapVisible(tester, TaskEditorPage.saveButtonKey);
  final rows = await harness.db.select(harness.db.tasks).get();
  return rows.single.recurrenceRule;
}

/// 一个旋钮的探针。
typedef _Probe = ({
  /// [RecurrenceDraft] 里的字段名。完备性守卫按它对表。
  String field,

  /// 拨这个旋钮的界面操作。进来时重复已经打开。
  Future<void> Function(WidgetTester) drive,

  /// 落库的规则串该长成什么样。
  Matcher rule,
});

final List<_Probe> _probes = [
  (
    field: 'enabled',
    // 开关本身：不碰它就没有规则，碰了才有。下面的对照组管另一半。
    drive: (t) async {},
    rule: startsWith('RRULE:'),
  ),
  (
    field: 'frequency',
    drive: (t) =>
        tapVisible(t, TaskEditorPage.frequencyKey(RecurrenceFrequency.monthly)),
    rule: contains('FREQ=MONTHLY'),
  ),
  (
    field: 'interval',
    // 加两下：1 → 3。加一下也行，但 2 比 3 更容易与别的默认值撞上。
    drive: (t) async {
      final inc = TaskEditorPage.stepperIncKey(TaskEditorPage.intervalStepper);
      await tapVisible(t, inc);
      await tapVisible(t, inc);
    },
    rule: contains('INTERVAL=3'),
  ),
  (
    field: 'weekdays',
    drive: (t) async {
      await tapVisible(
        t,
        TaskEditorPage.frequencyKey(RecurrenceFrequency.weekly),
      );
      await tapVisible(t, TaskEditorPage.weekdayKey(Weekday.tuesday));
    },
    rule: contains('BYDAY=TU'),
  ),
  // ── 「每月」那三个档位（FR-TASK-03 的「每月 15 号」「每月最后一个周五」）──
  //
  // 四条各拨一个字段，期望值**互不相同**：都写成 `BYDAY=1MO` 的话，
  // 序号与星期几各自没接上也看不出来。
  (
    field: 'monthlyMode',
    drive: (t) async {
      await tapVisible(
        t,
        TaskEditorPage.frequencyKey(RecurrenceFrequency.monthly),
      );
      await tapVisible(t, TaskEditorPage.monthlyModeKey(MonthlyMode.onWeekday));
    },
    rule: contains('BYDAY=1MO'),
  ),
  (
    field: 'monthDay',
    // 加两下：1 → 3。与默认值差一位，「加减器没接上」时立刻露馅。
    drive: (t) async {
      await tapVisible(
        t,
        TaskEditorPage.frequencyKey(RecurrenceFrequency.monthly),
      );
      await tapVisible(t, TaskEditorPage.monthlyModeKey(MonthlyMode.onDate));
      final inc = TaskEditorPage.stepperIncKey(TaskEditorPage.monthDayStepper);
      await tapVisible(t, inc);
      await tapVisible(t, inc);
    },
    rule: contains('BYMONTHDAY=3'),
  ),
  (
    field: 'monthOrdinal',
    drive: (t) async {
      await tapVisible(
        t,
        TaskEditorPage.frequencyKey(RecurrenceFrequency.monthly),
      );
      await tapVisible(t, TaskEditorPage.monthlyModeKey(MonthlyMode.onWeekday));
      await tapVisible(t, TaskEditorPage.monthOrdinalKey(3));
    },
    rule: contains('BYDAY=3MO'),
  ),
  (
    field: 'monthWeekday',
    drive: (t) async {
      await tapVisible(
        t,
        TaskEditorPage.frequencyKey(RecurrenceFrequency.monthly),
      );
      await tapVisible(t, TaskEditorPage.monthlyModeKey(MonthlyMode.onWeekday));
      await tapVisible(t, TaskEditorPage.monthWeekdayKey(Weekday.friday));
    },
    rule: contains('BYDAY=1FR'),
  ),
  (
    field: 'endMode',
    drive: (t) =>
        tapVisible(t, TaskEditorPage.endModeKey(RecurrenceEndMode.count)),
    rule: contains('COUNT='),
  ),
  (
    field: 'count',
    // 减一下：10 → 9。减而不是加，是为了让期望值与默认值差一位数字，
    // 「加减器根本没接上」时 COUNT=10 会立刻露馅。
    drive: (t) async {
      await tapVisible(t, TaskEditorPage.endModeKey(RecurrenceEndMode.count));
      await tapVisible(
        t,
        TaskEditorPage.stepperDecKey(TaskEditorPage.countStepper),
      );
    },
    rule: contains('COUNT=9'),
  ),
  (
    field: 'until',
    // 选择器默认停在「开始日期 + 30 天」，直接确定就是那天。
    drive: (t) async {
      await tapVisible(t, TaskEditorPage.endModeKey(RecurrenceEndMode.until));
      await tapVisible(t, TaskEditorPage.untilFieldKey);
      await t.tap(find.text('确定'));
      await t.pumpAndSettle();
    },
    rule: contains('UNTIL=${_plusThirty}T235959Z'),
  ),
];

void main() {
  group('每个旋钮都够得着，而且拨了真的进库', () {
    for (final probe in _probes) {
      testAppWidgets(probe.field, (tester) async {
        final harness = await _pumpEditor(tester);
        await probe.drive(tester);

        // 界面上没被挡住 —— 挡住的话下面读到的会是 null，
        // 而 null 与「规则里没这一段」在报错信息里长得不一样。
        expect(
          find.byKey(TaskEditorPage.blockedReasonKey),
          findsNothing,
          reason: '拨完 ${probe.field} 之后不该还存不下去',
        );

        expect(await _saveAndReadRule(tester, harness), probe.rule);
      });
    }

    testAppWidgets('「最后一天」这一档也够得着', (tester) async {
      // 它不是一个独立字段（走的还是 monthDay），所以完备性守卫盯不到它 ——
      // 而它恰恰是这批里最要紧的一档：想月末的人选 31 号会漏掉 5 个月。
      final harness = await _pumpEditor(tester);
      await tapVisible(
        tester,
        TaskEditorPage.frequencyKey(RecurrenceFrequency.monthly),
      );
      await tapVisible(
        tester,
        TaskEditorPage.monthlyModeKey(MonthlyMode.onDate),
      );
      await tapVisible(tester, TaskEditorPage.lastDayOfMonthKey);

      expect(
        await _saveAndReadRule(tester, harness),
        contains('BYMONTHDAY=-1'),
      );
    });

    testAppWidgets('选到 29 号以上会说「这些月份会跳过」', (tester) async {
      // RFC 5545 里短月份是**跳过**，不是夹到月末（实测 2026 年
      // `BYMONTHDAY=31` 只命中 7 次）。不说的话，选 31 号的人
      // 要到三月才发现二月没提醒 —— 而那时他会以为是应用坏了。
      await _pumpEditor(tester);
      await tapVisible(
        tester,
        TaskEditorPage.frequencyKey(RecurrenceFrequency.monthly),
      );
      await tapVisible(
        tester,
        TaskEditorPage.monthlyModeKey(MonthlyMode.onDate),
      );
      expect(
        find.byKey(TaskEditorPage.monthSkipHintKey),
        findsNothing,
        reason: '1 号不会跳过任何月份，不该吓唬用户',
      );

      final inc = TaskEditorPage.stepperIncKey(TaskEditorPage.monthDayStepper);
      for (var i = 1; i < 29; i++) {
        await tapVisible(tester, inc);
      }
      expect(find.byKey(TaskEditorPage.monthSkipHintKey), findsOneWidget);
    });

    testAppWidgets('对照组：把开关拨掉就没有规则', (tester) async {
      // 少了这条，一个「永远写死一条 RRULE」的实现能让上面七条全绿。
      //
      // 新建面板上选的是「重复单事项」，开关**开局就是开的** ——
      // 所以这条对照组从「不去打开」改成「拨掉它」。
      // 验的还是同一件事：那个开关真的管着规则写不写。
      final harness = await _pumpEditor(tester);
      await tapVisible(tester, TaskEditorPage.recurrenceSwitchKey);
      expect(await _saveAndReadRule(tester, harness), isNull);
    });
  });

  group('完备性', () {
    test('探针表覆盖 RecurrenceDraft 的每一个字段', () {
      // 扫构造器的 `this.x` —— 那串参数就是字段全集。
      // 用源码而不是手写一份清单：手写的那份会与代码分叉，
      // 而分叉的方向恰好是「新加的字段没人管」。
      final source = File('lib/features/task/application/recurrence_draft.dart')
          .readAsStringSync();
      final start = source.indexOf('const RecurrenceDraft({');
      expect(start, isNonNegative, reason: '构造器长得不一样了，这条守卫得跟着改');
      final block = source.substring(start, source.indexOf('});', start));
      final fields = RegExp(r'this\.(\w+)')
          .allMatches(block)
          .map((m) => m.group(1)!)
          .toSet();

      // 自检：扫出来的东西得像回事，不能因为正则失配变成空集合而「通过」。
      expect(fields, contains('enabled'));
      expect(fields.length, greaterThan(3));

      expect(
        _probes.map((p) => p.field).toSet(),
        fields,
        reason:
            '每个字段都要有一条走界面的探针 —— 没有探针的字段，'
            '很可能界面上根本没有对应的控件（interval/count/until 就是这么漏的）',
      );
    });
  });
}

/// **写路径能表达的每个字段，要么界面上够得着，要么写明为什么还不。**
///
/// ## 为什么要有这份账
///
/// M2 里同一个形状连着栽了三次：
///
/// | 缺的东西 | 命令里有 | 实体里有 | 界面上有 |
/// |---|---|---|---|
/// | 重复的间隔/次数/结束日期 | ✔ | ✔ | ✘ |
/// | 任务的结束日期/结束时刻 | ✔ | ✔ | ✘ |
/// | 阶段各自的时间段 | ✔ | ✔ | ✘ |
///
/// 三次都不是「写错了」，是**一条链路只接了一头**：命令、实体、
/// 数据库列、序列化、单元测试全都齐备，只差最后那个控件。
/// 而没有任何一条测试问过「用户能不能造出这个值」——
/// 于是 856 条全绿，功能却缺了一块。
///
/// 前两次是我自己在模拟器上点出来的，第三次是用户问出来的。
/// 靠人看是碰运气，所以立这份账。
///
/// ## 怎么记
///
/// 以**命令**为准（`CreateTaskCommand` / `StageSpec`），不是实体 ——
/// 命令是「写路径能表达什么」的定义，也是 FR-AI-01 里语音与 Agent
/// 将来要构造的东西。每个字段归三类之一：
///
/// - [_Kind.reachable]：有一条走真界面的探针，把它拨到非默认值并断言落库；
/// - [_Kind.system]：不是用户输入（ID、时区、由别的字段派生）；
/// - [_Kind.deferred]：**该做还没做**，必须写明理由与期次。
///   这一栏是欠债清单，不是豁免栏 —— 往里放东西要下决心。
///
/// 外加一条完备性守卫：扫命令构造器的 `this.x`，要求账目**恰好覆盖**它。
/// 加了字段却没归类，这条会红。
@TestOn('vm')
library;

import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/data/database/app_database.dart';
import 'package:planning_assistant/features/shell/presentation/app_shell.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';

import '../support/app_harness.dart';

enum _Kind { reachable, system, deferred }

typedef _Entry = ({
  /// 命令构造器里的参数名。完备性守卫按它对表。
  String field,
  _Kind kind,

  /// system / deferred 的理由。deferred 还要带期次。
  String why,

  /// reachable 才有：把这个字段拨到**非默认值**的界面操作。
  Future<void> Function(WidgetTester)? drive,

  /// reachable 才有：落库之后该长什么样。
  void Function(TaskRow task, List<StageRow> stages)? check,
});

// ── 建任务命令 ────────────────────────────────────────────────

final List<_Entry> _taskFields = [
  (
    field: 'taskId',
    kind: _Kind.system,
    why: '由调用方生成的 UUID —— 命令自带 ID 才幂等，不是用户输入',
    drive: null,
    check: null,
  ),
  (
    field: 'title',
    kind: _Kind.reachable,
    why: '',
    drive: (t) async {}, // 标题在每条探针的开场里都填了
    check: (task, _) => expect(task.title, '晨会'),
  ),
  (
    field: 'kind',
    kind: _Kind.reachable,
    why: '',
    // 不是一个直接的控件：填够两个阶段就是阶段事项（FR-TASK-02）。
    drive: (t) async {
      for (final title in ['第一步', '第二步']) {
        await tapVisible(t, TaskEditorPage.addStageKey);
        final field = _lastStageField(t);
        await t.ensureVisible(field);
        await t.pumpAndSettle();
        await t.enterText(field, title);
        await t.pumpAndSettle();
      }
    },
    check: (task, stages) {
      expect(task.kind, 'staged');
      expect(stages, hasLength(2));
    },
  ),
  (
    field: 'timeZoneId',
    kind: _Kind.system,
    why: '创建时所在时区（ADR-0005），从系统读，不给用户选',
    drive: null,
    check: null,
  ),
  (
    field: 'note',
    kind: _Kind.reachable,
    why: '',
    drive: (t) async {
      await t.enterText(find.byKey(TaskEditorPage.noteFieldKey), '带上电脑');
      await t.pump();
    },
    check: (task, _) => expect(task.note, '带上电脑'),
  ),
  (
    field: 'categoryId',
    kind: _Kind.reachable,
    why: '',
    drive: (t) async {
      // 默认就是「未分类」（写 NULL），所以要拨到一个真分类上。
      // 默认分类用固定 ID（导入导出与同步时两台设备上的「工作」要是同一条）。
      await tapVisible(
        t,
        TaskEditorPage.categoryChipKey('cat-default-briefcase'),
      );
    },
    check: (task, _) => expect(task.categoryId, 'cat-default-briefcase'),
  ),
  (
    field: 'priority',
    kind: _Kind.deferred,
    why:
        '优先级还没有控件（M3）。FR-TASK-01 点了它的名，筛选条也有这一维 —— '
        '在补上之前，那一维筛出来的永远只有「普通」这一档',
    drive: null,
    check: null,
  ),
  (
    field: 'isAllDay',
    kind: _Kind.reachable,
    why: '',
    drive: (t) => tapVisible(t, TaskEditorPage.allDaySwitchKey),
    check: (task, _) => expect(task.isAllDay, isFalse, reason: '默认是全天'),
  ),
  (
    field: 'planDate',
    kind: _Kind.reachable,
    why: '',
    // 关掉全天会补上今天 —— 那也是一条真实的、用户看得见的路径。
    drive: (t) => tapVisible(t, TaskEditorPage.allDaySwitchKey),
    check: (task, _) => expect(task.planDate, isNotNull),
  ),
  (
    field: 'startMinute',
    kind: _Kind.reachable,
    why: '',
    drive: (t) async {
      await tapVisible(t, TaskEditorPage.allDaySwitchKey);
      await tapVisible(t, TaskEditorPage.timeFieldKey);
      await t.tap(find.text('确定'));
      await t.pumpAndSettle();
    },
    check: (task, _) => expect(task.startMinute, isNotNull),
  ),
  (
    field: 'endDate',
    kind: _Kind.reachable,
    why: '',
    drive: (t) => tapVisible(t, TaskEditorPage.endSwitchKey),
    check: (task, _) => expect(task.endDate, isNotNull),
  ),
  (
    field: 'endMinute',
    kind: _Kind.reachable,
    why: '',
    drive: (t) async {
      await tapVisible(t, TaskEditorPage.allDaySwitchKey);
      await tapVisible(t, TaskEditorPage.endSwitchKey);
      await tapVisible(t, TaskEditorPage.endTimeFieldKey);
      await t.tap(find.text('确定'));
      await t.pumpAndSettle();
    },
    check: (task, _) => expect(task.endMinute, isNotNull),
  ),
  (
    field: 'recurrenceRule',
    kind: _Kind.reachable,
    why: '',
    // 各个部件的探针在 recurrence_reachability_test.dart，这里只验这一维接上了。
    drive: (t) => tapVisible(t, TaskEditorPage.recurrenceSwitchKey),
    check: (task, _) => expect(task.recurrenceRule, startsWith('RRULE:')),
  ),
  (
    field: 'colorArgb',
    kind: _Kind.deferred,
    why: '任务级颜色覆盖（NULL 时用分类色）。V2 —— V1 的颜色由分类承载',
    drive: null,
    check: null,
  ),
  (
    field: 'icon',
    kind: _Kind.deferred,
    why: '任务级图标。V2，同上',
    drive: null,
    check: null,
  ),
  (
    field: 'splitFromTaskId',
    kind: _Kind.system,
    why:
        '「本次及以后」分裂出新任务时由 SplitRecurringTaskCommand 填的溯源，'
        '不是用户输入（data-model §4.4）',
    drive: null,
    check: null,
  ),
  (
    field: 'sortOrder',
    kind: _Kind.deferred,
    why: '手动排序。要等列表的拖拽重排（view-specs §2.4，M3）',
    drive: null,
    check: null,
  ),
];

// ── 阶段载荷 ──────────────────────────────────────────────────

final List<_Entry> _stageFields = [
  (field: 'id', kind: _Kind.system, why: '生成的', drive: null, check: null),
  (
    field: 'title',
    kind: _Kind.reachable,
    why: '',
    drive: null, // 见下：阶段探针共用一段开场
    check: (_, stages) => expect(stages.first.title, '第一步'),
  ),
  (
    field: 'orderIndex',
    kind: _Kind.system,
    why: '保存时按列表位置转成从 0 起连续的序号，不是用户直接填的数',
    drive: null,
    check: null,
  ),
  (
    field: 'startOffsetMinutes',
    kind: _Kind.reachable,
    why: '',
    drive: null,
    check: (_, stages) => expect(stages.first.startOffsetMinutes, isNotNull),
  ),
  (
    field: 'durationMinutes',
    kind: _Kind.reachable,
    why: '',
    drive: null,
    check: (_, stages) => expect(stages.first.durationMinutes, isNotNull),
  ),
  (
    field: 'colorArgb',
    kind: _Kind.deferred,
    why: '甘特图的分段色。等甘特视图（M3）—— 在没有那张图之前它没有意义',
    drive: null,
    check: null,
  ),
  (
    field: 'status',
    kind: _Kind.system,
    why: '新建时恒为 pending。勾完成是列表里的事，不是编辑器里的',
    drive: null,
    check: null,
  ),
];

/// 阶段标题输入框。`editor-stage-<id>` 是它们的 key 形状。
Finder _stageTitleFields() => find.byWidgetPredicate(
  (w) =>
      w is TextField &&
      (w.key as ValueKey<String>?)?.value.startsWith('editor-stage-') == true,
);

Finder _lastStageField(WidgetTester tester) => _stageTitleFields().last;

/// 从阶段行的 key 里取出阶段 id —— 那个 id 是运行时生成的，
/// 测试没有别的途径知道它。
String _stageIdOf(WidgetTester tester, {required bool first}) {
  final finder = first ? _stageTitleFields().first : _stageTitleFields().last;
  final key = (tester.widget(finder) as TextField).key! as ValueKey<String>;
  return key.value.replaceFirst('editor-stage-', '');
}

Future<Harness> _pumpEditor(WidgetTester tester) async {
  await setScreenSize(tester, const Size(390, 844));
  final harness = appHarness();
  await seedCategories(harness);
  await tester.pumpWidget(
    ProviderScope(overrides: harness.overrides, child: PlanningAssistantApp()),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(AppShell.fabKey));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '晨会');
  await tester.pump();
  return harness;
}

/// 扫构造器的 `this.x`，取字段全集。
Set<String> _constructorFields(String path, String signature) {
  final source = File(path).readAsStringSync();
  final start = source.indexOf(signature);
  expect(start, isNonNegative, reason: '$signature 长得不一样了，这条守卫得跟着改');
  final block = source.substring(start, source.indexOf('});', start));
  return RegExp(r'this\.(\w+)')
      .allMatches(block)
      .map((m) => m.group(1)!)
      .toSet();
}

void main() {
  group('CreateTaskCommand 的每个字段', () {
    for (final e in _taskFields.where((e) => e.kind == _Kind.reachable)) {
      testAppWidgets('${e.field}：界面上拨得到，而且落库', (tester) async {
        final harness = await _pumpEditor(tester);
        await e.drive!(tester);

        await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
        await tester.pumpAndSettle();

        final tasks = await harness.db.select(harness.db.tasks).get();
        expect(tasks, hasLength(1), reason: '没存下去 —— 多半是被 blockedReason 挡了');
        final stages = await harness.db.select(harness.db.stages).get();
        e.check!(tasks.single, stages);
      });
    }
  });

  group('StageSpec 的每个字段', () {
    // 三个可达字段共用一段开场：加两个阶段、给第一个定时间。
    // 分开写三条会把同一串操作抄三遍，而它们验的是同一次保存的不同侧面。
    for (final e in _stageFields.where((e) => e.kind == _Kind.reachable)) {
      testAppWidgets('${e.field}：界面上拨得到，而且落库', (tester) async {
        final harness = await _pumpEditor(tester);
        await tapVisible(tester, TaskEditorPage.allDaySwitchKey);

        for (final title in ['第一步', '第二步']) {
          await tapVisible(tester, TaskEditorPage.addStageKey);
          final field = _lastStageField(tester);
          await tester.ensureVisible(field);
          await tester.pumpAndSettle();
          await tester.enterText(field, title);
          await tester.pumpAndSettle();
        }

        // 给**第一个**阶段定时间（`_lastStageField` 取的是最后一行）。
        final firstStageId = _stageIdOf(tester, first: true);

        await tapVisible(tester, TaskEditorPage.stageTimeKey(firstStageId));
        await tester.tap(find.byKey(TaskEditorPage.stageTimeConfirmKey));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(TaskEditorPage.saveButtonKey));
        await tester.pumpAndSettle();

        final tasks = await harness.db.select(harness.db.tasks).get();
        expect(tasks, hasLength(1));
        final stages = await (harness.db.select(
          harness.db.stages,
        )..orderBy([(s) => OrderingTerm(expression: s.orderIndex)])).get();
        e.check!(tasks.single, stages);
      });
    }
  });

  group('账目完备', () {
    test('CreateTaskCommand 的每个字段都归了类', () {
      final fields = _constructorFields(
        'lib/domain/commands/task_command.dart',
        'const CreateTaskCommand({',
      );
      // 自检：扫出来得像回事，不能因为正则失配变成空集合而「通过」。
      expect(fields, contains('title'));
      expect(fields.length, greaterThan(8));

      expect(
        _taskFields.map((e) => e.field).toSet(),
        fields,
        reason: '写路径新增的字段必须归类：有控件就写探针，没有就进 deferred 并写明理由',
      );
    });

    test('StageSpec 的每个字段都归了类', () {
      final fields = _constructorFields(
        'lib/domain/commands/task_command.dart',
        'const StageSpec({',
      );
      expect(fields, contains('title'));
      expect(_stageFields.map((e) => e.field).toSet(), fields, reason: '同上');
    });

    test('deferred 的每一条都写了理由', () {
      // 空理由的 deferred = 一句「以后再说」，与没记等价。
      for (final e in [..._taskFields, ..._stageFields]) {
        if (e.kind != _Kind.deferred) continue;
        expect(
          e.why.length,
          greaterThan(10),
          reason: '${e.field} 记成了欠债，但没说清欠的是什么、什么时候还',
        );
      }
    });

    test('reachable 的每一条都配了断言', () {
      // 只有 drive 没有 check 的探针，验的是「点得动」，不是「进了库」。
      for (final e in [..._taskFields, ..._stageFields]) {
        if (e.kind != _Kind.reachable) continue;
        expect(e.check, isNotNull, reason: '${e.field} 缺落库断言');
      }
    });

    test('当前的欠债清单（改动时请一并更新这条）', () {
      // 钉住数量而不只是「允许有 deferred」：新欠一笔债要显式改这里，
      // 而不是悄悄加进列表。还清一笔也一样。
      final deferred = [
        ..._taskFields,
        ..._stageFields,
      ].where((e) => e.kind == _Kind.deferred).map((e) => e.field).toList();
      expect(deferred, [
        'priority',
        'colorArgb',
        'icon',
        'sortOrder',
        'colorArgb', // StageSpec 的那个
      ]);
    });
  });
}

/// **新建时，每种形态只出现它用得上的那几个区**（用户 2026-09-10 定）。
///
/// > 既然新建任务都用 5 个子项了，其对应的新建/编辑则隐藏无关设置项。
///
/// 面板上已经选过「是哪一样」了，表单再把五样的全部控件都摆出来，
/// 那次选择就白选了 —— 而更糟的是**填了没用**：阶段事项的起止由阶段
/// 推出，你在日期栏里填什么都会被下一次推导盖掉。
///
/// ## 这一份用一张表说话
///
/// 判据集中在 [_matrix] 里，一眼读得完。散在五个用例里的话，
/// 「哪一样该有哪几区」就只能靠把五个用例都读一遍拼出来 ——
/// 而那正是这条要求想收拾的那种散落。
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/features/task/application/task_shape.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';

import '../support/app_harness.dart';

/// 表单上的几个区，按它们在页面上的顺序。
enum _Section {
  span('时间（日期/全天/时刻/有结束）', TaskEditorPage.dateFieldKey),
  recurrence('重复', TaskEditorPage.recurrenceSwitchKey),
  stages('阶段', TaskEditorPage.stageSectionKey),
  reminders('提醒', TaskEditorPage.reminderSectionKey),
  checklist('清单', TaskEditorPage.checklistSectionKey);

  const _Section(this.label, this.key);

  final String label;
  final Key key;
}

/// **新建**时每种形态该出现哪几个区。
///
/// 编辑已有任务不在这张表的域里：那时几乎所有区都留着，理由写在
/// `_showsSpanFields` 与阶段/重复区那两处注释上 —— 形态是从当前字段
/// 反推的，藏起来会让「给这条任务加上时间/重复/阶段」那几条路断掉。
const Map<TaskShape, Set<_Section>> _matrix = {
  TaskShape.single: {_Section.span, _Section.reminders, _Section.checklist},
  TaskShape.staged: {
    // **没有 span**：起止由阶段推出（`derived_span.dart`）。
    _Section.stages,
    _Section.reminders,
    _Section.checklist,
  },
  TaskShape.recurringSingle: {
    _Section.span,
    _Section.recurrence,
    _Section.reminders,
    _Section.checklist,
  },
  TaskShape.recurringStaged: {
    _Section.recurrence,
    _Section.stages,
    _Section.reminders,
    _Section.checklist,
  },
  TaskShape.scratch: {
    // 不排时间，所以**提醒也不出现** —— 编辑器里那句话本来就写着
    // 「没有日期的任务不会提醒」，留一个设了不会响的区正是这个项目
    // 一直在防的「点了没反应」。
    _Section.checklist,
  },
};

Future<void> _openEditor(WidgetTester tester, TaskShape shape) async {
  await setScreenSize(tester, const Size(390, 844));
  final harness = appHarness();
  await seedCategories(harness);
  await tester.pumpWidget(
    ProviderScope(overrides: harness.overrides, child: PlanningAssistantApp()),
  );
  await tester.pumpAndSettle();
  await tapCreate(tester, shape);
}

/// 某个区在不在表单上。
///
/// **要滚过去找** —— `ListView` 只建看得见的那几项，靠后的区压根没进树，
/// 直接 `findsNothing` 会把「还没建出来」读成「不在」，于是这份表里
/// 一半的「该有」会假绿。
Future<bool> _isPresent(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  if (finder.evaluate().isNotEmpty) return true;
  try {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  } on Object {
    return false;
  }
  return finder.evaluate().isNotEmpty;
}

void main() {
  test('前提：这张表把五种形态都写全了', () {
    // 少了它，新加一种形态时这份守卫会**默默地不管它**。
    expect(_matrix.keys.toSet(), TaskShape.values.toSet());
  });

  for (final entry in _matrix.entries) {
    final shape = entry.key;
    testAppWidgets('${shape.label}：只出现该出现的那几个区', (tester) async {
      await _openEditor(tester, shape);

      for (final section in _Section.values) {
        final want = entry.value.contains(section);
        final got = await _isPresent(tester, section.key);
        expect(
          got,
          want,
          reason: want
              ? '${shape.label} 该有「${section.label}」，却没有'
              : '${shape.label} 不该有「${section.label}」，却出现了 —— '
                    '面板上已经选过形态了，这一区在这儿要么用不上、'
                    '要么填了会被覆盖',
        );
      }
    });
  }

  testAppWidgets('阶段事项：把起止**显示出来**，只是不给填', (tester) async {
    // 推出来的东西也要给人看见 —— 起止决定这条任务落在日历与甘特图的
    // 哪一段。只藏不显示的话，用户改完阶段时间不知道任务挪到了哪儿，
    // 而那恰恰是他改阶段时间想控制的东西。
    await _openEditor(tester, TaskShape.staged);
    expect(
      await _isPresent(tester, const ValueKey('editor-derived-span')),
      isTrue,
      reason: '阶段事项该有一行只读的「由阶段决定：…」',
    );
  });

  testAppWidgets('**编辑**已有任务时，时间那几个控件回来', (tester) async {
    // 形态是从当前字段反推的（`TaskShape.of` 只看它现在是什么样），
    // 所以「给这条临时事项加上时间」只有这一条路：藏起来就断了 ——
    // 想加时间要先变成单事项，而想变成单事项又得先加时间。
    await _openEditor(tester, TaskShape.scratch);
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '随手记');
    await tester.pump();
    expect(
      await _isPresent(tester, TaskEditorPage.dateFieldKey),
      isFalse,
      reason: '前提：新建临时事项时没有日期栏',
    );
    await tapVisible(tester, TaskEditorPage.saveButtonKey);

    await openEditorFromCard(tester);
    expect(
      await _isPresent(tester, TaskEditorPage.dateFieldKey),
      isTrue,
      reason: '编辑时也藏起来的话，这条任务再也加不上时间',
    );
  });
}

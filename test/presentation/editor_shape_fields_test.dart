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

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/app.dart';
import 'package:planning_assistant/data/database/app_database.dart';
import 'package:planning_assistant/features/task/application/task_shape.dart';
import 'package:planning_assistant/features/task/presentation/task_editor_page.dart';

import '../support/app_harness.dart';

/// 表单上的几个区，按它们在页面上的顺序。
enum _Section {
  // 全天开关是时间区的**第一行**，也是它唯一恒在的控件 ——
  // 下面是一个日期栏还是两个「日期+时刻」栏由它决定，
  // 拿哪一个当锚都会漏掉另一半（用户 2026-09-10 改的形状）。
  span('时间（全天/日期/起止）', TaskEditorPage.allDaySwitchKey),
  recurrence('重复', TaskEditorPage.recurrenceSwitchKey),
  stages('阶段', TaskEditorPage.stageSectionKey),
  reminders('提醒', TaskEditorPage.reminderSectionKey),
  // **一格都不勾** —— 用户 2026-09-10：「把清单隐藏了，目前不需要这个」。
  // 留在这张表里正是为了让它被画回来时有人喊。
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
  TaskShape.single: {_Section.span, _Section.reminders},
  TaskShape.staged: {
    // **没有 span**：起止由阶段推出（`derived_span.dart`）。
    _Section.stages,
    _Section.reminders,
  },
  TaskShape.recurringSingle: {
    _Section.span,
    _Section.recurrence,
    _Section.reminders,
  },
  TaskShape.recurringStaged: {
    _Section.recurrence,
    _Section.stages,
    _Section.reminders,
  },
  TaskShape.scratch: {
    // 不排时间，所以**提醒也不出现** —— 编辑器里那句话本来就写着
    // 「没有日期的任务不会提醒」，留一个设了不会响的区正是这个项目
    // 一直在防的「点了没反应」。
    //
    // 一格都没有：临时事项的表单就是「标题 + 备注 + 分类 + 优先级」。
  },
};

Future<Harness> _openEditor(WidgetTester tester, TaskShape shape) async {
  await setScreenSize(tester, const Size(390, 844));
  final harness = appHarness();
  await seedCategories(harness);
  await tester.pumpWidget(
    ProviderScope(overrides: harness.overrides, child: PlanningAssistantApp()),
  );
  await tester.pumpAndSettle();
  await tapCreate(tester, shape);
  return harness;
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

  testAppWidgets('阶段事项：阶段区标的是**必填**，不是「可选」', (tester) async {
    // 用户那条要求里「各自的必填项和非填写」说的正是这个：
    // 标成「可选」与 `blockedReason` 那句「阶段事项至少要两个阶段」
    // 直接打架 —— 用户按标签填完，保存键却是灰的。
    await _openEditor(tester, TaskShape.staged);
    await _isPresent(tester, TaskEditorPage.stageSectionKey);
    expect(find.textContaining('阶段（可选）'), findsNothing);
    expect(find.textContaining('至少两个'), findsOneWidget);
  });

  testAppWidgets('阶段时间对话框**给得出时刻** —— 阶段事项没有全天', (tester) async {
    // ## 真机上撞见的
    //
    // 对话框里两行只有日期，没有时刻按钮 —— 用户挑不出「几点」。
    // 原因是它照 `draft.isAllDay` 走，而阶段事项的草稿开局是全天
    // （表单上没有那个开关，没人拨得动它）。
    //
    // 而推导**仍然会给任务写上时刻**（`_rederiveSpanIfStaged` 一并置
    // `isAllDay: false`）。于是两边说的不是一回事：对话框当它是全天，
    // 存下去的却是定时。
    //
    // 判据收在 `TaskShape.canBeAllDay` 上，草稿初值与对话框都问它。
    await _openEditor(tester, TaskShape.staged);
    await tester.enterText(find.byKey(TaskEditorPage.titleFieldKey), '装修');
    await tester.pump();
    await tapVisible(tester, TaskEditorPage.addStageKey);
    final field = find
        .descendant(
          of: find.byKey(TaskEditorPage.stageSectionKey),
          matching: find.byType(TextField),
        )
        .last;
    final id = ((tester.widget(field) as TextField).key! as ValueKey<String>)
        .value
        .replaceFirst('editor-stage-', '');

    await tapVisible(tester, TaskEditorPage.stageTimeKey(id));
    expect(
      find.byKey(TaskEditorPage.stageTimeStartTimeKey),
      findsOneWidget,
      reason: '对话框只给了日期 —— 阶段时间挑不出几点',
    );
    expect(find.byKey(TaskEditorPage.stageTimeEndTimeKey), findsOneWidget);
  });

  testAppWidgets('对照组：一条**全天的**阶段事项，对话框照样给得出时刻', (tester) async {
    // ## 为什么要单独来一条
    //
    // 上一条被**两处**修法各自挡住：草稿初值不再是全天，对话框也不再照
    // 草稿走。任意去掉一处它都还是绿的 —— 也就是说它证不出对话框那一处
    // 有没有用（演练时两处一起去掉才红）。
    //
    // 而对话框那一处保护的正是这里造的东西：库里一条 `is_all_day = 1`
    // 的阶段事项。编辑器新建时造不出它，导入与 V3 同步造得出。
    final harness = await _openEditor(tester, TaskShape.staged);
    await tapBack(tester);

    const taskId = 'staged-all-day';
    await harness.db
        .into(harness.db.tasks)
        .insert(
          TasksCompanion.insert(
            id: taskId,
            title: '装修',
            kind: 'staged',
            timeZoneId: 'Asia/Shanghai',
            isAllDay: const Value(true),
            planDate: const Value('2026-09-07'),
            endDate: const Value('2026-09-09'),
          ),
        );
    for (final (i, name) in ['拆除', '刷漆'].indexed) {
      await harness.db
          .into(harness.db.stages)
          .insert(
            StagesCompanion.insert(
              id: 'ad-stage-$i',
              taskId: taskId,
              title: name,
              orderIndex: i,
              startOffsetMinutes: Value(i * 1440),
              durationMinutes: const Value(60),
            ),
          );
    }
    await tester.pumpAndSettle();

    await openEditorFromCard(tester);
    await _isPresent(tester, TaskEditorPage.stageSectionKey);
    await tapVisible(tester, TaskEditorPage.stageTimeKey('ad-stage-0'));
    expect(
      find.byKey(TaskEditorPage.stageTimeStartTimeKey),
      findsOneWidget,
      reason: '全天的阶段事项：对话框只给日期，而推导会给任务写上时刻',
    );
  });

  testAppWidgets('提醒区不对有日期的任务说「没有日期不会提醒」', (tester) async {
    // 那句话是给不排时间的形态写的，而那一样现在压根不显示这个区。
    // 留着的话，阶段事项（日期是推出来的）会被告知一件不成立的事。
    await _openEditor(tester, TaskShape.staged);
    await _isPresent(tester, TaskEditorPage.reminderSectionKey);
    expect(find.textContaining('没有日期'), findsNothing);
  });

  testAppWidgets('阶段事项：有阶段但一个都没填时间时，起止**够得着**（评审 S-2）', (tester) async {
    // ## 逃生口一度锚在代理上
    //
    // 判据本来写的是 `stages.isEmpty`，而它只是「推不出来」的一种写法。
    // 「**有阶段、但一个都没填时间**」时两者给出相反的答案：
    // 控件不出现，推导又推不出东西 —— 那条任务存着的起止**改不了也看不见**，
    // 而它仍然在决定这条任务排在列表哪儿。
    //
    // 改成用推导自己的判据（`canDeriveSpan`）之后两边不可能再各说各话。
    //
    // ## 夹具 2026-09-10 换成直接铺库
    //
    // 原来是走界面建一条「两个阶段、都不填时间」的任务。用户那一批
    // 「加强必填项校验」之后**那条路自己没了** —— 阶段时间成了必填，
    // 保存键当场就是灰的。
    //
    // 但这个状态并没有从世界上消失：导入、V3 同步、以及将来任何一条
    // 不经编辑器的写路径都造得出它。**能不能建**与**建出来之后够不够
    // 得着**是两个问题，这条守的是后一个，所以夹具改成直接铺库。
    final harness = await _openEditor(tester, TaskShape.staged);
    await tapBack(tester);

    const taskId = 'staged-no-times';
    await harness.db
        .into(harness.db.tasks)
        .insert(
          TasksCompanion.insert(
            id: taskId,
            title: '搬家',
            kind: 'staged',
            timeZoneId: 'Asia/Shanghai',
            planDate: const Value('2026-09-07'),
            endDate: const Value('2026-09-09'),
          ),
        );
    for (final (i, name) in ['打包', '搬运'].indexed) {
      await harness.db
          .into(harness.db.stages)
          .insert(
            StagesCompanion.insert(
              id: 'stage-$i',
              taskId: taskId,
              title: name,
              orderIndex: i,
            ),
          );
    }
    await tester.pumpAndSettle();

    await openEditorFromCard(tester);
    expect(
      await _isPresent(tester, TaskEditorPage.allDaySwitchKey),
      isTrue,
      reason: '推不出起止，控件又藏着 —— 这条任务的起止就再也够不着了',
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

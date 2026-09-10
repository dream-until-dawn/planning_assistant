/// **改阶段列表只能走一个入口** —— 那个入口顺带重推起止。
///
/// ## 这条守卫是一个阻断项换来的（评审 R-3，2026-09-10）
///
/// 阶段事项的起止由阶段推出（`derived_span.dart`）。重推挂在
/// `setStageTime` 上 —— 而判据其实是「**阶段集合变了就重推**」。
/// 于是 `removeStage` 漏了：删掉最早那个阶段之后，任务的开始**停在被删掉
/// 的那个阶段的时刻**上，`derived_span.dart` 头注写的那条不变量
/// （最早那个阶段的偏移恒为 0、任务开始就是它）在草稿里当场不成立，
/// **而那条草稿存得下去**（三个删成两个不会被 `blockedReason` 挡）。
///
/// 别的几个入口当时没事，但**理由各不相同**：
///
/// | 入口 | 为什么当时没事 |
/// |---|---|
/// | `addStage` | 新行没时间 → 被 `blockedReason` 挡住 → 用户必须去点时间 |
/// | `reorderStages` / `moveStageUp` / `moveStageDown` | 只动顺序不动时间 |
/// | `setStageTitle` / `setStageDone` | 不碰时间 |
/// | **`removeStage`** | **没有理由，就是漏了** |
///
/// 四个入口靠四条各不相同的论证成立 —— 那正是「机制锚在判据的**一种
/// 写法**上」的形状。下一个入口靠哪条论证成立，没人保证得了。
///
/// ## 它的域是可枚举的
///
/// 一个文件里 `copyWith(stages:` 出现在哪几处是**静态可数**的。
/// 与「每张表的每一列都要在 mapper 读方向里出现」、「`_sync()` 读的每个
/// 源都要在触发集里」同形，只是域从「列」「provider」换成了「赋值点」。
///
/// ## 它不管什么
///
/// 它只保证「改了阶段列表就会经过那个漏斗」，**不保证漏斗里做的事是对的**
/// —— 推导本身由 `derived_span_test` 与 `stage_offset_follows_test` 守。
/// 这条守的是**接线**，那两条守的是**算法**。
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 被扫的那个文件。
const _path = 'lib/features/task/application/task_editor_controller.dart';

/// 允许出现 `copyWith(stages:` 的两处，按**它们所在的成员**点名。
///
/// 写成员名而不是行号：行号会随任何一次编辑失效，而那时它报出来的样子
/// 是「多了一处没走漏斗的赋值」—— 与真实原因差得很远。
const _allowedMembers = {
  // 漏斗自己。
  '_setStages',
  // 推导写回：它就在漏斗里被调用，再走一次漏斗会无限递归。
  '_rederiveSpanIfStaged',
  // 关掉重复时把「第一次发生」的进度搬回草稿。**只改 status，不碰时间**，
  // 而它已经在 `setRecurrence` 里与别的字段一起写，走漏斗要拆成两次赋值。
  'setRecurrence',
};

/// 从 `_path` 里粗切出「每个成员名 → 它的源文本」。
///
/// **不做真正的解析**，只需要知道某一行落在哪个成员里。判据是
/// 「**缩进恰好两格**且不是注释/闭合括号」的行开一个新成员 ——
/// 这个文件里每个成员都长这样，而成员体一律缩进 ≥4 格。
///
/// 两处踩过的坑，写在这儿免得下一个人重踩：
///
/// * **按回车换行一起切**。工作树是 CRLF，只按换行符切会让每行尾巴挂一个
///   回车符，`startsWith` / `endsWith` 一族当场全失效
///   （这个仓库里同一族坑第七次了，见 testing-strategy §1.19.1）。
/// * **别在字符类里放空格**。头一版的成员头正则里带了空格，
///   于是 `    if (...)` 这种四格缩进的行也被认成了成员头，
///   扫出来的「方法名」是 `if` 和 `state`。
/// 行分隔符。**用 raw 串**：非 raw 里的 \r / \n 是真的控制字符，
/// 那样写出来的正则**看起来**一样、也恰好能用，而下一个人改它时
/// 没有任何东西提醒他那两个字符不是转义序列（第 1 条 lint 的地盘）。
final _lineBreak = RegExp(r'\r?\n');

/// 每一处「改了阶段列表的 `state` 赋值」落在哪个成员里。
///
/// ## 为什么要走括号，不能只找一个字面片段
///
/// 头一版找的是 `copyWith(stages:` 这个串。**它漏掉了多行写法** ——
/// `dart format` 会把参数多的那几处折成
///
/// ```
/// state = state.copyWith(
///   isAllDay: false,
///   stages: [ … ],
/// );
/// ```
///
/// 于是那个片段一次都不出现，而那正是推导写回自己那一处。
/// 守卫当时**报绿**，报的还是「豁免名单里那条已经不改阶段列表了」——
/// 又一次「失败信息指向的不是真因」（§3.1.1）。
///
/// 所以改成扫 `state.copyWith(`，按括号配对切出实参段，
/// 再看**顶层**有没有 `stages:`。嵌套里的 `stages:`（比如传给别的函数）
/// 不算 —— 那不是在改这张草稿的阶段列表。
List<String> _stageAssignmentOwners(String source) {
  const marker = 'state.copyWith(';
  final lines = source.split(_lineBreak);
  // 每个字符的偏移 → 它在第几行，用来把命中点归到成员上。
  final owners = <String>[];
  for (var at = source.indexOf(marker); at >= 0;) {
    final open = at + marker.length - 1;
    final close = _matchingParen(source, open);
    if (close > open && _hasTopLevelStages(source.substring(open + 1, close))) {
      owners.add(_ownerOf(lines, _lineOf(source, at)));
    }
    at = source.indexOf(marker, at + marker.length);
  }
  return owners;
}

/// [open] 处那个 `(` 对应的 `)` 的下标；找不到返回 -1。
///
/// 只数括号，不管字符串与注释里的括号 —— 这个文件里那几处实参段中没有
/// （核过），而扫描器只在它一个文件上跑。多出来的那天，
/// 下面「豁免里每条都真的命中」那条自检会先喊。
int _matchingParen(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '(') depth++;
    if (source[i] == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// 实参段的**顶层**有没有 `stages:`。
bool _hasTopLevelStages(String args) {
  var depth = 0;
  for (var i = 0; i < args.length; i++) {
    final c = args[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') depth--;
    if (depth == 0 && args.startsWith('stages:', i)) return true;
  }
  return false;
}

int _lineOf(String source, int offset) =>
    _lineBreak.allMatches(source.substring(0, offset)).length;

/// 从第 [line] 行往上找最近的成员头。
///
/// **不做真正的解析**：判据是「缩进恰好两格、且不是注释或闭合括号」——
/// 这个文件里每个成员都长这样，成员体一律缩进 ≥4 格。
String _ownerOf(List<String> lines, int line) {
  for (var i = line; i >= 0; i--) {
    if (_isMemberHeader(lines[i])) return _nameOf(lines[i]) ?? '<unnamed>';
  }
  return '<top>';
}

bool _isMemberHeader(String line) {
  if (line.length < 3) return false;
  if (!line.startsWith('  ') || line[2] == ' ') return false;
  final rest = line.substring(2);
  // **别在字符类里放空格**：头一版的成员头正则里带了空格，于是
  // `    if (...)` 这种四格缩进的行也被认成了成员头，
  // 扫出来的「方法名」是 `if` 和 `state`。
  return !rest.startsWith('//') &&
      !rest.startsWith('}') &&
      !rest.startsWith(')') &&
      !rest.startsWith(']');
}

/// 成员头那一行里 `(` / `=` / `<` 之前的最后一个标识符。
String? _nameOf(String header) {
  final upto = header.split(RegExp(r'[(=<]')).first;
  final ids = RegExp(r'[A-Za-z_]\w*').allMatches(upto).toList();
  return ids.isEmpty ? null : ids.last.group(0);
}

void main() {
  test('改阶段列表的赋值只出现在点名的那几个成员里', () {
    final source = File(_path).readAsStringSync();
    final owners = _stageAssignmentOwners(source);

    // 自检：真的扫到了东西。正则/括号配对失配变成空集合的话，
    // 这条守卫会**空转着报绿** —— 而它头一版正是这么绿的。
    expect(owners, isNotEmpty, reason: '一处都没扫到 —— 扫描器自己坏了');
    expect(owners, contains('_setStages'), reason: '漏斗自己那一处都没扫到');

    final offenders = owners.where((o) => !_allowedMembers.contains(o)).toSet();
    expect(
      offenders,
      isEmpty,
      reason:
          '这些成员直接改了阶段列表，没走 `_setStages`：$offenders —— '
          '于是改完不会重推起止，而那条草稿存得下去（评审 R-3）',
    );
  });

  test('自检：豁免名单里每一条都**真的**被扫到了', () {
    // 一条从来没生效过的豁免，读的人以为那儿开了个口子，
    // 实际守卫压根到不了（反僵尸三层的第三问）。
    final owners = _stageAssignmentOwners(File(_path).readAsStringSync());
    for (final name in _allowedMembers) {
      expect(owners, contains(name), reason: '$name 已经不改阶段列表了 —— 这条豁免该删掉');
    }
  });
}

/// **每一列都要有人读回来**（testing-strategy §3.7）。
///
/// ## 这一族栽过四次
///
/// | | 那一列 / 那个字段 | 断在哪 |
/// |---|---|---|
/// | M2 | `durationMinutes` | 声明了、引擎读、引擎测了 —— 写入侧没有生产者 |
/// | 时间轴 | `isOverdue` | 卡片读、组件测了 —— 整形那一步没接上 |
/// | M3 | `occurrence_overrides.completed_at` | 写路径写、**读路径不取** → 叠加例外时丢失 |
/// | M4 | `categories.isSystemDefault` | 声明了，全 `lib/` 只有表定义提到它 |
///
/// 四次都是**两侧各自有测试、中间那根线没人接**，四次都是干别的时顺手撞见的。
/// 领域用例覆盖的是「算得对不对」，而「该读的时候没读」不在它的射程里。
///
/// ## 为什么这一族立得起结构性断言
///
/// 它与「所有的主张」那种没法枚举的东西不同：**表的列是一个有限的、
/// 具名的集合**。域可枚举，判据就写得出来：
///
/// > 每张表的每一列，都必须在**对应 mapper 的读方向**里出现。
/// > 出现不了，要么进豁免表（写明理由），要么它就是一列死数据。
///
/// ## 域：有 mapper 的那几张表
///
/// 「读方向」这件事需要一个结构上的锚。这个仓库里的锚是 mapper：
/// `extension … on XxxRow`（列名以裸标识符出现）或
/// `xxxFromRow(XxxRow row)`（以 `row.列名` 出现）。
///
/// **另外五张表没有 mapper**（`change_log`、`scheduled_notifications`、
/// `settings`、`tags`、`task_tags`）—— 它们不映射到领域实体，由仓库/DAO
/// 直接读。它们**在这条规则的域之外，不是被豁免**：这条规则问的是
/// 「mapper 读回来了没有」，而它们没有 mapper，这个问题对它们不成立。
///
/// 两者的差别不是措辞：豁免是「本该管、这次放过」，域外是「这条规则
/// 压根没说它」。把域外写成豁免，下一个人会以为那儿开了个口子。
/// 这五张表因此**不受本守卫保护**，这是已知的边界，写在这里而不是藏着。
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _tablesDir = 'lib/data/database/tables';
const _mappersDir = 'lib/data/mappers';

/// 同步信封的列。**整类豁免，理由是设计本身。**
///
/// 它们由 `SyncedDao.upsert()` 统一盖章，mapper 刻意不把它们搬进实体
/// （`task_mapper.dart` 的 `toCompanion` 头上写着「不含信封字段」——
/// 一并写出就会与 DAO 的盖章互相覆盖，且哪边赢取决于调用顺序）。
/// 真正的使用者是 V3 同步（ADR-0006、data-model §5）。
const Set<String> kEnvelopeColumns = {
  'createdAt',
  'updatedAt',
  'deletedAt',
  'revision',
  'lastWriterId',
  'remoteVersion',
};

/// 逐列豁免：`表.列` → 由谁承担。
///
/// **每条都要写清「谁读它 / 为什么不必读」**，空着的话这张表会变成垃圾桶。
/// 加一条豁免时要回答的第四问（它是随守卫同批进来的，还是后来加的）：
/// 下面两条都是**同批**的 —— 也就是说，它们是「被守的规则」与「现有实现」
/// 一开始就不一致的地方，所以各自附了「为什么改实现不如开豁免」。
const Map<String, String> kExemptColumns = {
  'Categories.isSystemDefault':
      '**当前确实没有使用者**，而且是写下来的取舍：「未分类」是 '
      '`categoryId IS NULL` 而不是一行（settings-spec §3.0、data-model §3、'
      'M2 演练报告都记着）。列留着是因为删列要迁移。'
      '为什么不改实现：删掉它才是行为变更（要写迁移），而留着不读正是设计。',
  'OccurrenceOverrides.id':
      '**派生的代理键**：`overrideRowId(taskId, key)` 在写入侧算出来'
      '（`occurrence_override_mapper.dart`），而实体的身份就是 '
      '(taskId, key) 那两列 —— 两列都被读回来了。'
      '为什么不改实现：把它读进实体等于把一个纯函数的结果存两份，'
      '两份迟早对不上。',
};

/// 一张表。
typedef TableDef = ({
  String name,
  String rowClass,
  List<String> columns,
  bool envelope,
});

List<String> _columnsIn(
  String src, {
  required int fromLine,
  required int toLine,
}) {
  final lines = src.split('\n');
  final out = <String>[];
  for (var i = fromLine; i < toLine && i < lines.length; i++) {
    final m = RegExp(r'^\s*\w*Column get (\w+)\s*=>').firstMatch(lines[i]);
    if (m != null) out.add(m.group(1)!);
  }
  return out;
}

/// 从表定义文件里读出每张表。
List<TableDef> tableDefs() {
  final out = <TableDef>[];
  for (final f in Directory(_tablesDir).listSync().whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    final src = f.readAsStringSync();
    final lines = src.split('\n');
    String? pendingRow;
    for (var i = 0; i < lines.length; i++) {
      final dataName = RegExp(r"@DataClassName\('(\w+)'\)")
          .firstMatch(lines[i]);
      if (dataName != null) {
        pendingRow = dataName.group(1);
        continue;
      }
      final cls = RegExp(r'^class (\w+) extends Table( with SyncEnvelope)?')
          .firstMatch(lines[i]);
      if (cls == null) continue;
      // 类体到下一个顶层 `}` 为止。
      var end = i + 1;
      while (end < lines.length && !lines[end].startsWith('}')) {
        end++;
      }
      out.add((
        name: cls.group(1)!,
        rowClass: pendingRow ?? cls.group(1)!,
        columns: _columnsIn(src, fromLine: i, toLine: end),
        envelope: cls.group(2) != null,
      ));
      pendingRow = null;
    }
  }
  return out;
}

/// 每个 row 类的**读方向**源码。
///
/// 两种形态都收：`extension … on XxxRow { … }` 里列名是裸标识符；
/// `xxxFromRow(XxxRow row) => …` 里是 `row.列名`。
/// **写方向不收** —— `toCompanion` 住在 `on 实体` 的扩展里、
/// `xxxToCompanion` 是另一个函数，天然分得开。这一点是这条守卫成立的前提：
/// 只看写方向的话，`completed_at` 那次（写了、没读回）就抓不到。
Map<String, String> readDirections() {
  final out = <String, String>{};
  for (final f in Directory(_mappersDir).listSync().whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    final src = f.readAsStringSync();

    for (final m in RegExp(r'extension \w+ on (\w+Row)\s*\{').allMatches(src)) {
      final open = src.indexOf('{', m.start);
      var depth = 0;
      var j = open;
      for (; j < src.length; j++) {
        if (src[j] == '{') depth++;
        if (src[j] == '}') {
          depth--;
          if (depth == 0) break;
        }
      }
      out[m.group(1)!] = (out[m.group(1)!] ?? '') + src.substring(open, j);
    }

    final fromRow = RegExp(r'\w+\s+\w*[Ff]romRow\((\w+Row) row\)\s*(=>|\{)');
    for (final m in fromRow.allMatches(src)) {
      var depth = 0;
      var j = m.end;
      for (; j < src.length; j++) {
        final c = src[j];
        if (c == '(' || c == '{' || c == '[') depth++;
        if (c == ')' || c == '}' || c == ']') depth--;
        if (c == ';' && depth <= 0) break;
      }
      out[m.group(1)!] = (out[m.group(1)!] ?? '') + src.substring(m.start, j);
    }
  }
  return out;
}

bool _mentions(String body, String name) =>
    RegExp('\\b$name\\b').hasMatch(body);

void main() {
  final tables = tableDefs();
  final reads = readDirections();

  test('前提：表定义与 mapper 都扫得到（守卫不对着空集合报绿）', () {
    // 少了这条，把目录改个名就能让整个守卫无声地变成一句空话。
    expect(tables.length, greaterThanOrEqualTo(10), reason: '表扫少了');
    expect(reads.length, greaterThanOrEqualTo(5), reason: 'mapper 扫少了');
    for (final t in tables) {
      expect(t.columns, isNotEmpty, reason: '${t.name} 一列都没解析出来');
    }
  });

  group('每张有 mapper 的表，每一列都要在读方向里出现', () {
    for (final t in tableDefs()) {
      final body = readDirections()[t.rowClass];
      if (body == null) continue; // 域外：没有 mapper，见头注
      test('${t.name} → ${t.rowClass}', () {
        final missing = <String>[];
        for (final c in t.columns) {
          if (kEnvelopeColumns.contains(c)) continue;
          if (kExemptColumns.containsKey('${t.name}.$c')) continue;
          if (!_mentions(body, c)) missing.add(c);
        }
        expect(
          missing,
          isEmpty,
          reason:
              '${t.name} 的这些列写得进去、读不回来：$missing\n'
              '要么在读方向里取用它，要么进 kExemptColumns 并写明由谁承担。',
        );
      });
    }
  });

  group('豁免表的反僵尸（四问）', () {
    test('① 豁免指向的表与列都还在', () {
      for (final key in kExemptColumns.keys) {
        final parts = key.split('.');
        final t = tables.where((t) => t.name == parts.first);
        expect(t, hasLength(1), reason: '$key 指的表没了');
        expect(
          t.single.columns,
          contains(parts.last),
          reason: '$key 指的列没了 —— 豁免该跟着删',
        );
      }
    });

    test('② 豁免**当前确实还在被违反** —— 不再违反就该删掉它', () {
      // 反僵尸的核心：一条已经不需要的豁免留在表里，读的人以为那儿
      // 开着口子，而实际上没有。它比没有豁免更误导。
      for (final key in kExemptColumns.keys) {
        final parts = key.split('.');
        final t = tables.firstWhere((t) => t.name == parts.first);
        final body = readDirections()[t.rowClass];
        expect(body, isNotNull, reason: '$key 所在的表没有 mapper，豁免无从谈起');
        expect(
          _mentions(body!, parts.last),
          isFalse,
          reason: '$key 现在已经被读回来了 —— 把这条豁免删掉',
        );
      }
    });

    test('③ 豁免落在守卫的扫描范围里', () {
      // 「从来没生效过的豁免」踩过一次（`stage.status` 那条白名单里有一个
      // 根本不在扫描目录下的文件）。这里逐条确认它的表真的会被扫到。
      for (final key in kExemptColumns.keys) {
        final name = key.split('.').first;
        final t = tables.firstWhere((t) => t.name == name);
        expect(
          readDirections().containsKey(t.rowClass),
          isTrue,
          reason: '$key 所在的表在域外，这条豁免永远轮不到生效',
        );
      }
    });

    test('④ 每条豁免都写明了由谁承担，不是一句「以后再说」', () {
      for (final e in kExemptColumns.entries) {
        expect(e.value.length, greaterThan(30), reason: '${e.key} 的理由太短');
        expect(
          RegExp(r'(§|ADR|mapper|演练|settings-spec|data-model)')
              .hasMatch(e.value),
          isTrue,
          reason: '${e.key} 的理由没点名任何文档或代码位置',
        );
        expect(
          e.value.contains('为什么不改实现'),
          isTrue,
          reason: '${e.key} 是与守卫同批进来的豁免，必须回答「为什么改实现不如开豁免」',
        );
      }
    });
  });

  group('守卫自身能失败（§1.4）', () {
    test('给一张表加一列没人读的，会被抓出来', () {
      const body = 'Task toEntity() => Task(id: id, title: title);';
      const cols = ['id', 'title', 'ghostColumn'];
      final missing = [
        for (final c in cols)
          if (!_mentions(body, c)) c,
      ];
      expect(missing, ['ghostColumn']);
    });

    test('只在写方向出现的列不算读回来', () {
      // `completed_at` 那次就是这个形状：写路径写了，读路径没取。
      const readBody =
          'OccurrenceOverride fromRow(r) => OccurrenceOverride('
          'taskId: r.taskId, key: r.occurrenceKey);';
      expect(_mentions(readBody, 'completedAt'), isFalse);
      expect(_mentions(readBody, 'taskId'), isTrue);
    });
  });
}

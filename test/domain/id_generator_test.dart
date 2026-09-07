/// UUID v7 的可用性与**时间有序性**验证（M0 检查表项）。
///
/// 我们选 v7 不是因为它是新版本，而是因为它的前 48 bit 是毫秒时间戳，
/// 因此**字典序 ≈ 生成时序**，对 SQLite 主键索引友好
/// （见 docs/01-architecture/cross-cutting.md §2）。
///
/// 因此只断言「v7() 能调用」是不够的 —— 那条测试对「包把 v7 实现成了 v4」
/// 完全免疫。必须断言我们真正依赖的那个性质。
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:planning_assistant/core/id/id_generator.dart';
import 'package:uuid/uuid.dart';

void main() {
  const gen = UuidV7Generator(Uuid());

  test('生成的是合法 UUID，且版本号为 7', () {
    final id = gen.newId();
    // 8-4-4-4-12 十六进制，第三段首位是版本号
    expect(
      id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
      reason: '第三段应以 7 开头（版本号），第四段首位应为 8/9/a/b（variant）',
    );
  });

  test('唯一性：连续生成 10000 个无重复', () {
    final ids = List.generate(10000, (_) => gen.newId());
    expect(ids.toSet(), hasLength(10000));
  });

  test('时间有序：跨毫秒生成的 ID 字典序递增（这才是选 v7 的理由）', () async {
    final ids = <String>[];
    for (var i = 0; i < 20; i++) {
      ids.add(gen.newId());
      // 保证跨越毫秒边界；v7 只保证毫秒级有序
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }

    final sorted = [...ids]..sort();
    expect(
      ids,
      equals(sorted),
      reason:
          '字典序必须等于生成顺序，否则主键索引会退化为随机插入。'
          '若此断言失败，说明包的 v7 实现不再保证时间有序，'
          '应改为在 core/id/ 内自实现（v7 规范简单：48bit 毫秒 + 随机位）',
    );
  });

  test('时间戳可解析：前 48 bit 与生成时刻相符（误差 < 5 秒）', () {
    final before = DateTime.now().millisecondsSinceEpoch;
    final id = gen.newId();
    final after = DateTime.now().millisecondsSinceEpoch;

    // v7 布局：前 12 个十六进制字符 = 48 bit 毫秒时间戳
    final hex = id.replaceAll('-', '').substring(0, 12);
    final ms = int.parse(hex, radix: 16);

    expect(ms, greaterThanOrEqualTo(before - 5000));
    expect(ms, lessThanOrEqualTo(after + 5000));
  });

  test('SequentialIdGenerator 产出确定性序列（测试基础设施自身可用）', () {
    final seq = SequentialIdGenerator(prefix: 't');
    expect([seq.newId(), seq.newId(), seq.newId()], ['t-0', 't-1', 't-2']);
  });
}

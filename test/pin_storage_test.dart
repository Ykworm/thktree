import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/data/services/pin_storage.dart';

void main() {
  late Directory tmpDir;
  late PinStorage store;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('pin_storage_test');
    store = PinStorage(rootDir: tmpDir.path);
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('空存储读写：getAll 返回空列表', () async {
    expect(await store.getAll(), isEmpty);
  });

  test('add 后 getAll 可取，跨实例持久化', () async {
    await store.add(
      kind: PinKind.message,
      themeId: 'thm_1',
      nodeId: 'nd_1',
      msgId: 'msg_1',
      excerpt: 'hello',
    );
    final pins = await store.getAll();
    expect(pins.length, 1);
    expect(pins.first.kind, PinKind.message);
    expect(pins.first.msgId, 'msg_1');
    expect(pins.first.excerpt, 'hello');

    // 新实例从磁盘读到同一份数据
    final store2 = PinStorage(rootDir: tmpDir.path);
    expect((await store2.getAll()).first.msgId, 'msg_1');

    // 文件带 schema 版本
    final text = await File('${tmpDir.path}/pins.json').readAsString();
    expect((jsonDecode(text) as Map)['schema'], 'pins/v1');
  });

  test('上限 5 条，满后 FIFO 淘汰最早的', () async {
    for (var i = 1; i <= 6; i++) {
      await store.add(
        kind: PinKind.message,
        msgId: 'msg_$i',
        excerpt: 'e$i',
      );
      // 保证 createdAt 有先后
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    final pins = await store.getAll();
    expect(pins.length, PinStorage.maxPins);
    // 最早的 msg_1 被淘汰，最新在前
    expect(pins.map((p) => p.msgId), ['msg_6', 'msg_5', 'msg_4', 'msg_3', 'msg_2']);
  });

  test('同锚点去重：同 msgId 重复 Pin 刷新 excerpt/createdAt 并移到最前', () async {
    await store.add(kind: PinKind.message, msgId: 'msg_1', excerpt: 'old');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await store.add(kind: PinKind.message, msgId: 'msg_2', excerpt: 'other');
    await Future<void>.delayed(const Duration(milliseconds: 2));

    final firstId = (await store.getAll()).last.id;
    final firstCreatedAt = (await store.getAll()).last.createdAt;

    await store.add(kind: PinKind.message, msgId: 'msg_1', excerpt: 'new');

    final pins = await store.getAll();
    expect(pins.length, 2);
    // 移到最前，id 不变，excerpt/createdAt 刷新
    expect(pins.first.msgId, 'msg_1');
    expect(pins.first.id, firstId);
    expect(pins.first.excerpt, 'new');
    expect(pins.first.createdAt.isAfter(firstCreatedAt), isTrue);
  });

  test('message 与 note 锚点互不去重', () async {
    await store.add(kind: PinKind.message, msgId: 'x', excerpt: 'm');
    await store.add(kind: PinKind.note, noteId: 'x', excerpt: 'n');
    expect((await store.getAll()).length, 2);
  });

  test('remove 删除单条，不存在时静默跳过', () async {
    final pins = await store.add(
      kind: PinKind.note,
      noteId: 'note_1',
      excerpt: 'n1',
    );
    await store.remove(pins.first.id);
    expect(await store.getAll(), isEmpty);

    // 不存在的 id 不报错
    await store.remove('pin_404');
    expect(await store.getAll(), isEmpty);
  });

  test('坏 JSON 容错：当空处理不崩溃', () async {
    await File('${tmpDir.path}/pins.json').writeAsString('not json {{{');
    expect(await store.getAll(), isEmpty);

    // 容错后仍可正常写入
    await store.add(kind: PinKind.note, noteId: 'note_1', excerpt: 'n1');
    expect((await store.getAll()).length, 1);
  });
}

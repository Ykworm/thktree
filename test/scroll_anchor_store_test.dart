import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/data/services/scroll_anchor_store.dart';

void main() {
  late Directory tmpDir;
  late ScrollAnchorStore store;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('scroll_anchor_test');
    store = ScrollAnchorStore(rootDir: tmpDir.path);
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('空存储读写：anchorFor 返回 null，load 返回空表', () async {
    expect(await store.anchorFor('nd_1'), isNull);
    expect(await store.load(), isEmpty);
  });

  test('setAnchor 后 anchorFor 可取，跨实例持久化', () async {
    await store.setAnchor('nd_1', 'msg_1');
    expect(await store.anchorFor('nd_1'), 'msg_1');

    // 新实例从磁盘读到同一份数据
    final store2 = ScrollAnchorStore(rootDir: tmpDir.path);
    expect(await store2.anchorFor('nd_1'), 'msg_1');

    // 文件带 schema 版本
    final text =
        await File('${tmpDir.path}/scroll_anchors.json').readAsString();
    expect((jsonDecode(text) as Map)['schema'], 'scroll_anchors/v1');
  });

  test('同一 nodeId 覆盖更新', () async {
    await store.setAnchor('nd_1', 'msg_1');
    await store.setAnchor('nd_1', 'msg_2');
    expect(await store.anchorFor('nd_1'), 'msg_2');
    expect((await store.load()).length, 1);
  });

  test('remove 删除锚点，不存在时静默跳过', () async {
    await store.setAnchor('nd_1', 'msg_1');
    await store.setAnchor('nd_2', 'msg_9');
    await store.remove('nd_1');
    expect(await store.anchorFor('nd_1'), isNull);
    expect(await store.anchorFor('nd_2'), 'msg_9');

    // 不存在的 nodeId 不报错
    await store.remove('nd_404');
    expect((await store.load()).length, 1);
  });

  test('坏 JSON 容错：当空处理不崩溃', () async {
    await File('${tmpDir.path}/scroll_anchors.json')
        .writeAsString('not json {{{');
    expect(await store.load(), isEmpty);
    expect(await store.anchorFor('nd_1'), isNull);

    // 容错后仍可正常写入
    await store.setAnchor('nd_1', 'msg_1');
    expect(await store.anchorFor('nd_1'), 'msg_1');
  });

  test('save 全量写入后 load 一致', () async {
    await store.save({
      'nd_1': ScrollAnchor(msgId: 'msg_1', updatedAt: DateTime.utc(2026)),
      'nd_2': ScrollAnchor(msgId: 'msg_2', updatedAt: DateTime.utc(2026)),
    });
    final store2 = ScrollAnchorStore(rootDir: tmpDir.path);
    final loaded = await store2.load();
    expect(loaded.keys, containsAll(['nd_1', 'nd_2']));
    expect(loaded['nd_2']!.msgId, 'msg_2');
  });
}

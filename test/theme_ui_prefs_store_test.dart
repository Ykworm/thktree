import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/data/services/theme_ui_prefs_store.dart';

void main() {
  late Directory tmpDir;
  late ThemeUiPrefsStore store;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('theme_ui_prefs_test');
    store = ThemeUiPrefsStore(rootDir: tmpDir.path);
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test('空存储返回默认空偏好', () async {
    final prefs = await store.forTheme('theme_a');
    expect(prefs.collapsedIds, isEmpty);
    expect(prefs.hiddenRootIds, isEmpty);
  });

  test('折叠 id 持久化跨实例', () async {
    await store.setCollapsedIds('theme_a', {'n1', 'n2'});
    expect(await store.forTheme('theme_a'), isA<ThemeUiPrefs>());
    expect((await store.forTheme('theme_a')).collapsedIds, {'n1', 'n2'});

    final store2 = ThemeUiPrefsStore(rootDir: tmpDir.path);
    final loaded = await store2.forTheme('theme_a');
    expect(loaded.collapsedIds, {'n1', 'n2'});

    final text =
        await File('${tmpDir.path}/theme_ui_prefs.json').readAsString();
    expect((jsonDecode(text) as Map)['schema'], 'theme_ui_prefs/v1');
  });

  test('hide / show root 仅改 hiddenRootIds', () async {
    await store.setCollapsedIds('theme_a', {'n_parent'});
    await store.setRootHidden('theme_a', 'root_1', hidden: true);
    await store.setRootHidden('theme_a', 'root_2', hidden: true);

    var prefs = await store.forTheme('theme_a');
    expect(prefs.hiddenRootIds, {'root_1', 'root_2'});
    expect(prefs.collapsedIds, {'n_parent'});

    await store.setRootHidden('theme_a', 'root_1', hidden: false);
    prefs = await store.forTheme('theme_a');
    expect(prefs.hiddenRootIds, {'root_2'});
    expect(prefs.collapsedIds, {'n_parent'});
  });

  test('不同 themeId 互不影响', () async {
    await store.setCollapsedIds('t1', {'a'});
    await store.setRootHidden('t2', 'r1', hidden: true);

    expect((await store.forTheme('t1')).collapsedIds, {'a'});
    expect((await store.forTheme('t1')).hiddenRootIds, isEmpty);
    expect((await store.forTheme('t2')).collapsedIds, isEmpty);
    expect((await store.forTheme('t2')).hiddenRootIds, {'r1'});
  });

  test('坏 JSON 容错为空，仍可继续写', () async {
    await File('${tmpDir.path}/theme_ui_prefs.json')
        .writeAsString('not json {{{');
    expect((await store.forTheme('t')).collapsedIds, isEmpty);
    await store.setCollapsedIds('t', {'x'});
    expect((await store.forTheme('t')).collapsedIds, {'x'});
  });
}

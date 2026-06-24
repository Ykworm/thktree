// 搜索测试用的磁盘 fixture 工具。
//
// 向 themesDir 写入一个主题 + 1 条笔记 + 1 个含对话的节点，
// 触发 searchServiceProvider 自动 rebuildAll 索引。
//
// 使用方式：
//   final fixture = await writeSearchFixture(paths.themesDir);

import 'dart:io';

import 'package:path/path.dart' as p;

/// 搜索 fixture 数据结构。
class SearchFixtureData {
  const SearchFixtureData({
    required this.themeId,
    required this.noteTitle,
    required this.nodeTitle,
    required this.keyword,
  });

  final String themeId;
  final String noteTitle;
  final String nodeTitle;
  final String keyword;
}

/// 向 themesDir 写入一个主题 + 1 条笔记 + 1 个含对话的节点。
/// 返回 (themeId, noteTitle, nodeTitle, keyword)。
Future<SearchFixtureData> writeSearchFixture(Directory themesDir) async {
  final ts = DateTime.now().millisecondsSinceEpoch;
  final themeId = 'thk${ts.toRadixString(16).substring(0, 6)}';
  final noteId = 'note_${ts}_001';
  final nodeId = 'node_${ts}_001';
  final keyword = 'SEK_SEARCH_KW_$ts';
  final noteTitle = '搜索测试笔记_$ts';
  final nodeTitle = '搜索测试节点_$ts';
  final themeTitle = '搜索测试主题_$ts';

  final themeDir = p.join(themesDir.path, themeId);
  final notesDir = p.join(themeDir, 'notes');
  final nodeDir = p.join(themeDir, 'nodes', nodeId);

  // 创建目录结构
  await Directory(notesDir).create(recursive: true);
  await Directory(nodeDir).create(recursive: true);

  final now = DateTime.now().toUtc().toIso8601String();

  // ── theme.meta.json ────────────────────────────────────────────────────
  await File(p.join(themeDir, 'theme.meta.json')).writeAsString('''
{
  "schema": "theme_meta/v1",
  "themeId": "$themeId",
  "title": "$themeTitle",
  "createdAt": "$now",
  "updatedAt": "$now"
}
''');

  // ── note .md ───────────────────────────────────────────────────────────
  await File(p.join(notesDir, '$noteId.md')).writeAsString('''
---
themeId: "$themeId"
noteId: "$noteId"
title: "$noteTitle"
createdAt: "$now"
updatedAt: "$now"
---
决策树是一种 $keyword 算法，常用于分类和回归任务。它通过递归分裂特征空间构建树形结构。
''');

  // ── node.meta.json ─────────────────────────────────────────────────────
  await File(p.join(nodeDir, 'node.meta.json')).writeAsString('''
{
  "schema": "node_meta/v1",
  "themeId": "$themeId",
  "nodeId": "$nodeId",
  "parentId": null,
  "kind": "chat",
  "title": "$nodeTitle",
  "createdAt": "$now",
  "updatedAt": "$now"
}
''');

  // ── session.md ─────────────────────────────────────────────────────────
  final msgId1 = 'msg_${ts.toRadixString(16).padLeft(26, '0').substring(0, 26).toUpperCase()}';
  final msgId2 = 'msg_${(ts + 1).toRadixString(16).padLeft(26, '0').substring(0, 26).toUpperCase()}';
  await File(p.join(nodeDir, 'session.md')).writeAsString('''
---
nodeId: "$nodeId"
updatedAt: "$now"
---

## user · $now · $msgId1
什么是决策树？它的 $keyword 在机器学习中有什么应用？

## assistant · $now · $msgId2
决策树是一种监督学习算法，它的核心 $keyword 是通过递归分裂特征空间来构建树形结构，常用于分类和回归任务。
''');

  return SearchFixtureData(
    themeId: themeId,
    noteTitle: noteTitle,
    nodeTitle: nodeTitle,
    keyword: keyword,
  );
}

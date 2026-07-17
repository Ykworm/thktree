import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thk_tree/data/services/keyword_global_storage.dart';
import 'package:thk_tree/data/stores/theme_store.dart';
import 'package:thk_tree/ui/core/app_services.dart';

/// 一个碰撞对。
class CollisionPair {
  const CollisionPair({
    required this.keywordA,
    required this.keywordB,
    required this.themesA,
    required this.themesB,
    this.summary,
  });

  final String keywordA;
  final String keywordB;
  final List<String> themesA;
  final List<String> themesB;
  final String? summary;

  CollisionPair copyWith({String? summary}) {
    return CollisionPair(
      keywordA: keywordA,
      keywordB: keywordB,
      themesA: themesA,
      themesB: themesB,
      summary: summary ?? this.summary,
    );
  }
}

/// 思维碰撞页面状态。
class ThinkingCollisionState {
  const ThinkingCollisionState({
    this.pairs = const [],
    this.loading = false,
    this.creatingChat = false,
    this.error,
  });

  final List<CollisionPair> pairs;
  final bool loading;
  final bool creatingChat;
  final String? error;

  ThinkingCollisionState copyWith({
    List<CollisionPair>? pairs,
    bool? loading,
    bool? creatingChat,
    String? error,
  }) {
    return ThinkingCollisionState(
      pairs: pairs ?? this.pairs,
      loading: loading ?? this.loading,
      creatingChat: creatingChat ?? this.creatingChat,
      error: error,
    );
  }
}

/// 思维碰撞 Controller。
class ThinkingCollisionController extends Notifier<ThinkingCollisionState> {
  @override
  ThinkingCollisionState build() {
    return const ThinkingCollisionState();
  }

  /// 加载关键词、生成碰撞对（纯本地，不调 LLM）。
  Future<void> loadPairs() async {
    state = state.copyWith(loading: true, error: null);

    try {
      final storage = await ref.read(keywordGlobalStorageProvider.future);
      final file = await storage.loadOrInit();

      final allKeywords = file.keywords.values.toList();
      if (allKeywords.length < 2) {
        state = state.copyWith(
          loading: false,
          pairs: [],
          error: 'no_keywords',
        );
        return;
      }

      final rng = Random();
      final pairs = <CollisionPair>[];

      // 策略 1：优先用跨主题关键词配对
      final crossThemeKeywords = allKeywords
          .where((kw) => kw.crossThemeCount >= 2)
          .toList();

      if (crossThemeKeywords.length >= 2) {
        final shuffled = List.of(crossThemeKeywords)..shuffle(rng);
        for (var i = 0;
            i < shuffled.length - 1 && pairs.length < 6;
            i += 2) {
          pairs.add(_buildPair(shuffled[i].keyword, shuffled[i + 1].keyword, file));
        }
      }

      // 策略 2：不足时随机抽取兜底
      if (pairs.length < 3) {
        final existing = <String>{
          for (final p in pairs) '${p.keywordA}|${p.keywordB}'
        };
        final shuffled = List.of(allKeywords)..shuffle(rng);
        for (var i = 0;
            i < shuffled.length - 1 && pairs.length < 6;
            i += 2) {
          final key = '${shuffled[i].keyword}|${shuffled[i + 1].keyword}';
          if (!existing.contains(key)) {
            pairs.add(_buildPair(shuffled[i].keyword, shuffled[i + 1].keyword, file));
            existing.add(key);
          }
        }
      }

      state = state.copyWith(loading: false, pairs: pairs);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  CollisionPair _buildPair(
    String keywordA,
    String keywordB,
    KeywordGlobalFile file,
  ) {
    final refsA = file.keywordLeafMap[keywordA] ?? const [];
    final refsB = file.keywordLeafMap[keywordB] ?? const [];
    return CollisionPair(
      keywordA: keywordA,
      keywordB: keywordB,
      themesA: refsA.map((r) => r.themeId).toSet().toList(),
      themesB: refsB.map((r) => r.themeId).toSet().toList(),
    );
  }

  /// 重新随机排列碰撞对。
  void shuffle() {
    final rng = Random();
    final shuffled = List.of(state.pairs)..shuffle(rng);
    state = state.copyWith(pairs: shuffled);
  }

  /// 点击碰撞对：创建 chat node 并返回给 UI 跳转。
  Future<({String themeId, String nodeId, String title})?> createChatFromPair(
    CollisionPair pair,
  ) async {
    state = state.copyWith(creatingChat: true);

    try {
      final paths = await ref.read(appPathsProvider.future);
      final nodeStore = await ref.read(nodeStoreProvider.future);
      final sessionStore = await ref.read(sessionStoreProvider.future);

      // 查找"未分类"主题（app 启动时已确保存在）
      final themeStore = ThemeStore(paths: paths, db: nodeStore.db);
      final themes = await themeStore.listThemes();
      final uncategorized = themes.firstWhere((t) => t.title == '未分类');
      final themeId = uncategorized.themeId;
      final themePath = '${paths.themesDir.path}/$themeId';

      // 创建聊天节点
      final title = '「${pair.keywordA}」×「${pair.keywordB}」';
      final node = await nodeStore.createChatNode(
        themeId: themeId,
        themePath: themePath,
        parentId: null,
        title: title,
      );

      // 写入首条 user 消息
      await sessionStore.appendUserMessage(
        nodeId: node.nodeId,
        content: '帮我分析「${pair.keywordA}」和「${pair.keywordB}」之间的思维联系',
      );

      state = state.copyWith(creatingChat: false);

      return (themeId: themeId, nodeId: node.nodeId, title: title);
    } catch (e) {
      state = state.copyWith(creatingChat: false, error: e.toString());
      return null;
    }
  }

}

final thinkingCollisionControllerProvider =
    NotifierProvider<ThinkingCollisionController, ThinkingCollisionState>(
  ThinkingCollisionController.new,
);

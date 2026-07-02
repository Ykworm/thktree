import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:thk_tree/data/models/llm_model_config.dart';

import 'package:thk_tree/data/services/keyword_analysis_storage.dart';
import 'package:thk_tree/data/services/keyword_aggregation_service.dart';
import 'package:thk_tree/data/services/keyword_extraction_service.dart';
import 'package:thk_tree/data/services/keyword_global_storage.dart';
import 'package:thk_tree/ui/core/app_services.dart';

/// 单个 theme 下的 leaf + 状态信息，供选择页展示。
class ThemeLeafInfo {
  const ThemeLeafInfo({
    required this.themeId,
    required this.themeTitle,
    required this.leaves,
  });

  final String themeId;
  final String themeTitle;
  final List<LeafWithStatus> leaves;
}

/// leaf 节点 + 其 keyword analysis 状态。
class LeafWithStatus {
  const LeafWithStatus({
    required this.nodeId,
    required this.title,
    this.status = LeafStatus.pending,
    this.lastAnalyzedAt,
  });

  final String nodeId;
  final String title;
  final LeafStatus status;
  final DateTime? lastAnalyzedAt;
}

/// 分析流程状态。
enum AnalysisPhase {
  idle,
  extracting, // Prompt A 运行中
  aggregating, // Prompt B 运行中
  done,
  error,
}

/// 分析流程进度。
class AnalysisProgress {
  const AnalysisProgress({
    required this.phase,
    this.totalLeaves = 0,
    this.completedLeaves = 0,
    this.currentLeafTitle,
    this.error,
  });

  final AnalysisPhase phase;
  final int totalLeaves;
  final int completedLeaves;
  final String? currentLeafTitle;
  final String? error;

  double get progress =>
      totalLeaves > 0 ? completedLeaves / totalLeaves : 0.0;
}

/// 关键词分析 Controller：管理 leaf 选择 + Prompt A/B 分析流程。
///
/// 生命周期：
/// - 初始化时加载所有 theme 的 leaf + 分析状态
/// - 用户选择 leaf → 调用 [startAnalysis]
/// - 分析完毕后刷新排行榜
class KeywordAnalysisController extends AsyncNotifier<AnalysisProgress> {
  @override
  AnalysisProgress build() {
    return const AnalysisProgress(phase: AnalysisPhase.idle);
  }

  /// 所有 theme + leaf 信息（初始化后可用）。
  List<ThemeLeafInfo> themeLeaves = [];

  /// 用户选中的 leaf nodeId 集合。
  final Set<String> selectedLeafIds = {};

  /// 取消令牌，支持用户取消分析。
  CancelToken? _cancelToken;

  /// 加载所有 theme 的 leaf + 分析状态。
  Future<void> loadThemesAndLeaves() async {
    // 等待所有依赖的 provider 就绪
    final themeStore = await ref.read(themeStoreProvider.future);
    final nodeStore = await ref.read(nodeStoreProvider.future);
    final appPaths = await ref.read(appPathsProvider.future);

    final themes = await themeStore.listThemes();
    final result = <ThemeLeafInfo>[];

    for (final theme in themes) {
      final nodes = await nodeStore.listNodes(themeId: theme.themeId);
      // 只取 leaf（chat 节点）
      final chatNodes =
          nodes.where((n) => n.kind.toString().contains('chat')).toList();

      if (chatNodes.isEmpty) continue;

      // 读取该 theme 的 keyword_analysis.json
      final storage = KeywordAnalysisStorage(
        themePath: p.join(appPaths.themesDir.path, theme.themeId),
      );
      final analysisFile = await storage.loadOrInit();

      final leaves = <LeafWithStatus>[];
      for (final node in chatNodes) {
        final record = analysisFile.leaves[node.nodeId];
        leaves.add(LeafWithStatus(
          nodeId: node.nodeId,
          title: node.title,
          status: record?.status ?? LeafStatus.pending,
          lastAnalyzedAt: record?.lastAnalyzedAt,
        ));
      }

      result.add(ThemeLeafInfo(
        themeId: theme.themeId,
        themeTitle: theme.title,
        leaves: leaves,
      ));
    }

    themeLeaves = result;
  }

  /// 切换 leaf 选中状态。
  void toggleLeaf(String leafId) {
    if (selectedLeafIds.contains(leafId)) {
      selectedLeafIds.remove(leafId);
    } else {
      selectedLeafIds.add(leafId);
    }
  }

  /// 全选指定 theme 的所有 leaf。
  void selectAllForTheme(String themeId) {
    final theme = themeLeaves.firstWhere((t) => t.themeId == themeId);
    for (final leaf in theme.leaves) {
      selectedLeafIds.add(leaf.nodeId);
    }
  }

  /// 取消全选指定 theme 的所有 leaf。
  void deselectAllForTheme(String themeId) {
    final theme = themeLeaves.firstWhere((t) => t.themeId == themeId);
    for (final leaf in theme.leaves) {
      selectedLeafIds.remove(leaf.nodeId);
    }
  }

  /// 获取选中 leaf 所属的 themeId。
  String? getThemeIdForLeaf(String leafId) {
    for (final theme in themeLeaves) {
      if (theme.leaves.any((l) => l.nodeId == leafId)) {
        return theme.themeId;
      }
    }
    return null;
  }

  /// 启动 Prompt A + B 分析流程。
  ///
  /// 1. 遍历选中的 leaf，逐个调用 Prompt A（关键词抽取）
  /// 2. 处理 new_category（如有）
  /// 3. 更新 keyword_analysis.json
  /// 4. 全部完成后调用 Prompt B（聚合 + score）
  /// 5. 写入 keyword_global.json
  Future<void> startAnalysis() async {
    if (selectedLeafIds.isEmpty) return;

    _cancelToken = CancelToken();

    final totalLeaves = selectedLeafIds.length;
    state = AsyncValue.data(AnalysisProgress(
      phase: AnalysisPhase.extracting,
      totalLeaves: totalLeaves,
      completedLeaves: 0,
    ));

    try {
      final appPaths = ref.read(appPathsProvider).requireValue;
      final llmConfig = ref.read(llmConfigStoreProvider);
      final extractionService = ref.read(keywordExtractionServiceProvider);
      final aggregationService = ref.read(keywordAggregationServiceProvider);
      final globalStorage =
          ref.read(keywordGlobalStorageProvider).requireValue;
      final categoryStorage =
          ref.read(keywordCategoryStorageProvider).requireValue;
      final nodeStore = ref.read(nodeStoreProvider).requireValue;

      // 加载 LLM 配置
      final providers = await llmConfig.loadAll();
      if (providers.isEmpty) {
        throw StateError('未配置 LLM');
      }
      final provider = providers.first;
      final apiKey = await llmConfig.readApiKey(provider.id);
      if (apiKey.isEmpty) {
        throw StateError('未配置 API Key');
      }

      // 获取默认模型
      final selectedModelId = provider.selectedModelId;
      LlmModelConfig? selectedModel;
      if (selectedModelId != null && provider.models.isNotEmpty) {
        selectedModel = provider.models.where((m) => m.id == selectedModelId).firstOrNull;
      }
      selectedModel ??= provider.models.isNotEmpty ? provider.models.first : null;
      if (selectedModel == null) {
        throw StateError('未配置模型');
      }

      // 加载 catalog
      final catalog = await categoryStorage.loadOrInit();

      // 加载 global storage
      final globalFile = await globalStorage.loadOrInit();

      // 逐个 leaf 执行 Prompt A
      final allKeywordInputs = <ScoreAggregationInput>[];
      final keywordLeafRefs = <String, List<KeywordLeafRef>>{};

      for (final leafId in selectedLeafIds) {
        final themeId = getThemeIdForLeaf(leafId);
        if (themeId == null) continue;

        final leafInfo = themeLeaves
            .expand((t) => t.leaves)
            .firstWhere((l) => l.nodeId == leafId);

        state = AsyncValue.data(AnalysisProgress(
          phase: AnalysisPhase.extracting,
          totalLeaves: totalLeaves,
          completedLeaves: selectedLeafIds.toList().indexOf(leafId),
          currentLeafTitle: leafInfo.title,
        ));

        // 读取 session.md
        final nodeRow = await nodeStore.getNodeRow(nodeId: leafId);
        final sessionPath = nodeRow['sessionPath'] as String?;
        if (sessionPath == null) {
          dev.log('[KeywordAnalysis] No sessionPath for leaf $leafId');
          continue;
        }

        final sessionFile = File(sessionPath);
        if (!await sessionFile.exists()) {
          dev.log('[KeywordAnalysis] session.md not found: $sessionPath');
          continue;
        }

        final sessionContent = await sessionFile.readAsString();
        // 截取前 8000 字符避免 token 超限
        final truncated = sessionContent.length > 8000
            ? sessionContent.substring(0, 8000)
            : sessionContent;

        // 调用 Prompt A
        final extractionResult = await extractionService.extract(
          chatTitle: leafInfo.title,
          chatContent: truncated,
          catalog: catalog,
          provider: provider,
          modelId: selectedModel.id,
          apiKey: apiKey,
          contextWindow: selectedModel.contextWindow,
          cancelToken: _cancelToken,
        );

        // 处理 new_category
        List<KeywordEntry> keywords = extractionResult.keywords;
        if (extractionResult.hasPendingNewCategory &&
            extractionResult.pendingNewCategory != null) {
          final newId = await categoryStorage.addLlmCategory(
            name: extractionResult.pendingNewCategory!.name,
            aliases: extractionResult.pendingNewCategory!.aliases,
          );
          // 替换 marker 为新分配的 id
          keywords = keywords.map((k) {
            if (k.categoryId == KeywordExtractionService.newCategoryMarker) {
              return KeywordEntry(keyword: k.keyword, categoryId: newId);
            }
            return k;
          }).toList();
        }

        // 更新 keyword_analysis.json
        final storage = KeywordAnalysisStorage(
          themePath: p.join(appPaths.themesDir.path, themeId),
        );
        await storage.updateAsync((file) {
          file.leaves[leafId] = LeafAnalysisRecord(
            leafId: leafId,
            status: LeafStatus.fresh,
            lastAnalyzedAt: DateTime.now().toUtc(),
            lastUserMessageAt: file.leaves[leafId]?.lastUserMessageAt,
            keywords: keywords,
          );
          return file;
        });

        // 计算 leaf 深度（从节点层级推算）
        _computeLeafDepth(nodeRow);

        // 构建聚合输入
        for (final kw in keywords) {
          keywordLeafRefs.putIfAbsent(kw.keyword, () => []);
          keywordLeafRefs[kw.keyword]!.add(KeywordLeafRef(
            themeId: themeId,
            leafId: leafId,
            categoryId: kw.categoryId,
          ));
        }
      }

      // 构建 Prompt B 输入
      for (final entry in keywordLeafRefs.entries) {
        final keyword = entry.key;
        final refs = entry.value;
        final uniqueThemeIds = refs.map((r) => r.themeId).toSet();
        final categoryId = refs.first.categoryId;

        // 计算 depth_avg（简化：用所有关联 leaf 的平均深度）
        double depthAvg = 0;
        for (final ref in refs) {
          final nodeRow = await nodeStore.getNodeRow(nodeId: ref.leafId);
          depthAvg += _computeLeafDepth(nodeRow);
        }
        depthAvg /= refs.length;

        // 计算 stale_ratio
        int staleCount = 0;
        for (final ref in refs) {
          final storage = KeywordAnalysisStorage(
            themePath: p.join(appPaths.themesDir.path, ref.themeId),
          );
          final file = await storage.loadOrInit();
          final record = file.leaves[ref.leafId];
          if (record != null && record.status == LeafStatus.stale) {
            staleCount++;
          }
        }

        allKeywordInputs.add(ScoreAggregationInput(
          keyword: keyword,
          categoryId: categoryId,
          crossThemeCount: uniqueThemeIds.length,
          crossLeafCount: refs.length,
          depthAvg: depthAvg,
          staleRatio: refs.isNotEmpty ? staleCount / refs.length : 0.0,
        ));
      }

      // 调用 Prompt B
      if (allKeywordInputs.isNotEmpty) {
        state = AsyncValue.data(AnalysisProgress(
          phase: AnalysisPhase.aggregating,
          totalLeaves: totalLeaves,
          completedLeaves: totalLeaves,
        ));

        final scorePrompt =
            globalFile.scorePrompt ?? KeywordGlobalFile.defaultScorePrompt;
        final scoredEntries = await aggregationService.aggregate(
          inputs: allKeywordInputs,
          scorePrompt: scorePrompt,
          provider: provider,
          modelId: selectedModel.id,
          apiKey: apiKey,
          contextWindow: selectedModel.contextWindow,
          cancelToken: _cancelToken,
        );

        // 更新 keyword_global.json
        await globalStorage.updateAsync((current) {
          current.updatedAt = DateTime.now().toUtc();
          current.keywords.clear();
          current.keywordLeafMap.clear();

          for (final entry in scoredEntries) {
            current.keywords[entry.keyword] = entry;
          }
          for (final entry in keywordLeafRefs.entries) {
            current.keywordLeafMap[entry.key] = entry.value;
          }

          return current;
        });
      }

      state = const AsyncValue.data(AnalysisProgress(
        phase: AnalysisPhase.done,
      ));
    } catch (e, st) {
      dev.log('[KeywordAnalysis] Error: $e\n$st');
      state = AsyncValue.data(AnalysisProgress(
        phase: AnalysisPhase.error,
        error: e.toString(),
      ));
    }
  }

  /// 取消正在进行的分析。
  void cancel() {
    _cancelToken?.cancel('用户取消');
  }

  /// 重置状态为 idle。
  void reset() {
    state = const AsyncValue.data(AnalysisProgress(phase: AnalysisPhase.idle));
  }

  /// 计算 leaf 在 theme tree 中的绝对深度。
  ///
  /// 通过 DB 行的 parentId 递归计算。
  double _computeLeafDepth(Map<String, Object?> nodeRow) {
    // 简化实现：通过 parentId 链计算深度
    // 暂时返回 0，实际需要递归查 DB
    return 0;
  }
}

/// KeywordAnalysisController 的 provider。
final keywordAnalysisControllerProvider =
    AsyncNotifierProvider<KeywordAnalysisController, AnalysisProgress>(
  KeywordAnalysisController.new,
);

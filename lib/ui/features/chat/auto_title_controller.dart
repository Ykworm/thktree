import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/data/services/title_suggestion_service.dart';
import 'package:thk_tree/data/services/llm_prompts.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/shared/llm_setup_check.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';
import 'package:thk_tree/ui/features/themes/theme_detail_controller.dart';

/// 自动 title 生成任务的状态。
///
/// 状态机：
///   idle → running → done   （成功）
///   idle → running → failed （模型未配置 / LLM 失败 / 写 DB 失败）
class AutoTitleState {
  const AutoTitleState({
    required this.status,
    this.newTitle,
    this.error,
  });

  final AutoTitleStatus status;
  final String? newTitle;
  final Object? error;

  static const initial = AutoTitleState(status: AutoTitleStatus.idle);

  AutoTitleState copyWith({
    AutoTitleStatus? status,
    String? newTitle,
    Object? error,
  }) {
    return AutoTitleState(
      status: status ?? this.status,
      newTitle: newTitle ?? this.newTitle,
      error: error ?? this.error,
    );
  }
}

enum AutoTitleStatus { idle, running, done, failed }

/// 空白分支（A 模式）后置自动 title 生成的 Notifier。
///
/// 设计要点：
/// 1. **以 nodeId 为 family key** —— 同一 node 多次进入 chat_screen 共享同一 Notifier 实例（autoDispose 范围内）
/// 2. **任务与 widget 解耦** —— `runIfNeeded` 内部所有 `ref.read` 都用 Notifier 自己的 ref，
///    widget dispose 后（autoDispose 触发前）任务仍能继续执行
/// 3. **完成后调 `themeDetailControllerProvider(themeId).notifier).refresh()`** —
///    不论 widget 是否 mounted 都会触发 tree 刷新
/// 4. **写 DB 前查 DB title 兜底** —— 用户手动改 title 不会被 LLM 覆盖
/// 5. **`ref.keepAlive()` 防止 widget unmount 中断任务** ——
///    `autoDispose` 会在 chat_screen dispose 时取消内部 Future，
///    导致用户提前 pop 后 LLM 调用 / DB 写 / tree refresh 全被打断。
///    `keepAlive()` 声明"我自己保持 alive"，任务跑完才允许 dispose。
///
/// Riverpod 3.x 范式（参考 `ChatController` / `ThemeDetailController`）：
/// - 类继承 `AsyncNotifier<AutoTitleState>`（无 `AutoDisposeFamilyAsyncNotifier` 这种类）
/// - provider 用 `AsyncNotifierProvider.autoDispose.family` 把 autoDispose + family 作为 modifier
class AutoTitleController extends AsyncNotifier<AutoTitleState> {
  AutoTitleController(this.nodeId);

  final String nodeId;

  @override
  Future<AutoTitleState> build() async {
    // keepAlive：任务与 widget 完全解耦，chat_screen dispose 不影响 Notifier
    ref.keepAlive();
    // 不需要预加载数据，初始即为 idle
    return AutoTitleState.initial;
  }

  /// 占位 title 判读 + 启动 LLM 调用（幂等）。
  ///
  /// 调用方（chat_screen build 边沿检测）保证只触发一次，
  /// 但本方法内部仍做双重去重：
  ///   - state.status != idle → return
  ///   - currentTitle != placeholder → return
  ///   - 写 DB 前查 DB title → 用户手动改过则跳过
  Future<void> runIfNeeded({
    required String themeId,
    required String currentTitle,
    required String transcript,
    required String placeholder,
  }) async {
    // 守卫 1：去重
    if (state.value?.status != AutoTitleStatus.idle) return;

    // 守卫 2：title 已被改过
    if (currentTitle != placeholder) {
      state = AsyncData(state.value!.copyWith(status: AutoTitleStatus.done, newTitle: currentTitle));
      return;
    }

    // 守卫 3：查 DB title 兜底（用户可能在 LLM 启动前手动改了 DB）
    try {
      final nodeStore = await ref.read(nodeStoreProvider.future);
      final row = await nodeStore.getNodeRow(nodeId: nodeId);
      final dbTitle = row['title'] as String?;
      if (dbTitle != null && dbTitle != placeholder) {
        debugPrint('[AutoTitle] nodeId=$nodeId DB title 已被改 ($dbTitle), 跳过');
        state = AsyncData(AutoTitleState(status: AutoTitleStatus.done, newTitle: dbTitle));
        return;
      }
    } catch (e, st) {
      debugPrint('[AutoTitle] 查 DB title 失败（继续走 LLM 流程）: $e\n$st');
    }

    state = const AsyncData(AutoTitleState(status: AutoTitleStatus.running));

    try {
      final settings = ref.read(settingsControllerProvider).value;
      final providers = ref.read(llmProvidersProvider).value ?? const <LlmProviderConfig>[];
      final configStore = ref.read(llmConfigStoreProvider);

      // 解析 model（核心纯函数，Notifier 自己的 ref 读 settings / configStore 后传入）
      final resolved = await resolveModelForTitleCore(
        settings: settings,
        providers: providers,
        configStore: configStore,
        currentProviderId: settings?.chatDefaultProviderId,
        currentModelId: settings?.chatDefaultModelId,
      );
      if (resolved == null) {
        state = const AsyncData(AutoTitleState(status: AutoTitleStatus.failed, error: 'noModel'));
        return;
      }
      final (provider, modelId, apiKey) = resolved;

      final contextWindow = _resolveContextWindow(
        settings?.chatDefaultProviderId,
        settings?.chatDefaultModelId,
      );
      final newTitle = await _generateTitleWithRetry(
        provider: provider,
        modelId: modelId,
        apiKey: apiKey,
        contextWindow: contextWindow,
        transcript: transcript,
      );

      if (newTitle == null || newTitle.trim().isEmpty) {
        state = const AsyncData(AutoTitleState(status: AutoTitleStatus.failed, error: 'empty'));
        return;
      }

      final trimmed = newTitle.trim();

      // 写 DB（disk-first）
      try {
        final nodeStore = await ref.read(nodeStoreProvider.future);
        await nodeStore.updateNodeTitle(nodeId: nodeId, newTitle: trimmed);
      } catch (e, st) {
        debugPrint('[AutoTitle] updateNodeTitle 失败: $e\n$st');
        state = AsyncData(AutoTitleState(status: AutoTitleStatus.failed, error: e));
        return;
      }

      // 刷新 tree controller（widget dispose 后仍能跑）
      try {
        await ref.read(themeDetailControllerProvider(themeId).notifier).refresh();
      } catch (e, st) {
        debugPrint('[AutoTitle] themeDetailController.refresh 失败（下次进入 tree 会重新加载）: $e\n$st');
      }

      state = AsyncData(AutoTitleState(status: AutoTitleStatus.done, newTitle: trimmed));
    } catch (e, st) {
      debugPrint('[AutoTitle] FAILED nodeId=$nodeId: $e\n$st');
      state = AsyncData(AutoTitleState(status: AutoTitleStatus.failed, error: e));
    }
  }

  /// 调 LLM 生成 title，带 3 次重试 + 指数退避 1s/2s/4s。
  Future<String?> _generateTitleWithRetry({
    required LlmProviderConfig provider,
    required String modelId,
    required String apiKey,
    required int contextWindow,
    required String transcript,
  }) async {
    const maxAttempts = 3;
    String? lastError;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final title = await _callTitleLlm(
          provider: provider,
          modelId: modelId,
          apiKey: apiKey,
          contextWindow: contextWindow,
          transcript: transcript,
        );
        if (title != null && title.trim().isNotEmpty) return title.trim();
      } catch (e) {
        lastError = e.toString();
        debugPrint('[AutoTitle] attempt ${attempt + 1} failed: $e');
      }
      if (attempt < maxAttempts - 1) {
        await Future<void>.delayed(Duration(seconds: 1 << attempt)); // 1s / 2s / 4s
      }
    }

    if (lastError != null) {
      debugPrint('[AutoTitle] all $maxAttempts attempts failed, last error: $lastError');
    }
    return null;
  }

  /// 调一次 LLM 生成 title（不带重试）。
  Future<String?> _callTitleLlm({
    required LlmProviderConfig provider,
    required String modelId,
    required String apiKey,
    required int contextWindow,
    required String transcript,
  }) async {
    if (transcript.trim().isEmpty) return null;
    final candidates = await TitleSuggestionService.generateTitles(
      content: transcript,
      direction: null,
      languageCode: ref.llmLanguageCode,
      provider: provider,
      modelId: modelId,
      apiKey: apiKey,
      contextWindow: contextWindow,
    );
    return candidates.isEmpty ? null : candidates.first;
  }

  int _resolveContextWindow(String? providerId, String? modelId) {
    if (providerId != null && modelId != null) {
      final providers = ref.read(llmProvidersProvider).value;
      if (providers != null) {
        final provider = providers.where((p) => p.id == providerId).firstOrNull;
        if (provider != null) {
          final model = provider.models.where((m) => m.id == modelId).firstOrNull;
          if (model != null) return model.contextWindow;
        }
      }
    }
    // fallback 到第一个有 models 的 provider 的默认 context window
    final providers = ref.read(llmProvidersProvider).value;
    if (providers != null) {
      for (final p in providers) {
        if (p.models.isNotEmpty) {
          return p.models.first.contextWindow;
        }
      }
    }
    return 64000;
  }
}

final autoTitleControllerProvider =
    AsyncNotifierProvider.autoDispose.family<AutoTitleController, AutoTitleState, String>(
  AutoTitleController.new,
);

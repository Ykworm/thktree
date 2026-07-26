import 'dart:async';
import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thk_tree/data/models/llm_model_config.dart';
import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/data/services/user_input_summary_service.dart';
import 'package:thk_tree/data/services/user_input_summary_storage.dart';
import 'package:thk_tree/data/services/llm_prompts.dart';
import 'package:thk_tree/ui/core/app_services.dart';

/// 用户输入总结页面的状态。
class UserInputSummaryState {
  const UserInputSummaryState({
    this.phase = SummaryPhase.idle,
    this.days = 30,
    this.cache,
    this.inputs = const [],
    this.error,
  });

  final SummaryPhase phase;
  final int days;
  final UserInputSummaryCache? cache;
  final List<UserInputRecord> inputs;
  final String? error;

  UserInputSummaryState copyWith({
    SummaryPhase? phase,
    int? days,
    UserInputSummaryCache? cache,
    List<UserInputRecord>? inputs,
    String? error,
  }) {
    return UserInputSummaryState(
      phase: phase ?? this.phase,
      days: days ?? this.days,
      cache: cache ?? this.cache,
      inputs: inputs ?? this.inputs,
      error: error,
    );
  }
}

enum SummaryPhase {
  idle,
  scanning,
  analyzing,
  done,
  error,
}

/// 用户输入总结 Controller。
///
/// 职责：
/// - 加载缓存（如有）
/// - 触发扫描 + LLM 分析
/// - 管理天数切换
class UserInputSummaryController extends Notifier<UserInputSummaryState> {
  CancelToken? _cancelToken;

  @override
  UserInputSummaryState build() {
    return const UserInputSummaryState();
  }

  /// 初始化：加载指定天数的缓存。
  Future<void> init({int days = 30}) async {
    state = state.copyWith(days: days);
    final storage = await _getStorage();
    final cache = await storage.read(days);
    if (cache.isValid && cache.reportMarkdown != null) {
      state = state.copyWith(
        phase: SummaryPhase.done,
        cache: cache,
      );
    }
  }

  /// 切换天数并重新加载缓存。
  Future<void> changeDays(int days) async {
    if (days == state.days) return;
    state = state.copyWith(days: days);
    final storage = await _getStorage();
    final cache = await storage.read(days);
    if (cache.isValid && cache.reportMarkdown != null) {
      state = state.copyWith(
        phase: SummaryPhase.done,
        cache: cache,
      );
    } else {
      state = state.copyWith(
        phase: SummaryPhase.idle,
        cache: null,
      );
    }
  }

  /// 启动分析流程。
  Future<void> startAnalysis() async {
    _cancelToken = CancelToken();

    try {
      // Step 1: 扫描 user inputs
      state = state.copyWith(phase: SummaryPhase.scanning, error: null);

      final appPaths = await ref.read(appPathsProvider.future);
      final inputs = await UserInputSummaryService.collectUserInputs(
        themesDir: appPaths.themesDir,
        days: state.days,
      );

      if (inputs.isEmpty) {
        state = state.copyWith(
          phase: SummaryPhase.done,
          inputs: [],
          cache: UserInputSummaryCache(
            days: state.days,
            reportMarkdown: null,
            inputCount: 0,
          ),
        );
        return;
      }

      state = state.copyWith(inputs: inputs);

      // Step 2: 调用 LLM 生成报告
      state = state.copyWith(phase: SummaryPhase.analyzing);

      final llmConfig = ref.read(llmConfigStoreProvider);
      final providers = await llmConfig.loadAll();
      if (providers.isEmpty) {
        throw StateError('未配置 LLM');
      }

      LlmProviderConfig? provider;
      String? apiKey;
      LlmModelConfig? selectedModel;
      for (final p in providers) {
        final key = await llmConfig.readApiKey(p.id);
        if (key.isEmpty || p.models.isEmpty) continue;
        LlmModelConfig? model;
        if (p.selectedModelId != null) {
          model = p.models.where((m) => m.id == p.selectedModelId).firstOrNull;
        }
        model ??= p.models.first;
        provider = p;
        apiKey = key;
        selectedModel = model;
        break;
      }
      if (provider == null || apiKey == null || apiKey.isEmpty) {
        throw StateError('未配置 API Key');
      }
      if (selectedModel == null) {
        throw StateError('未配置模型');
      }

      final report = await UserInputSummaryService.generateReport(
        inputs: inputs,
        languageCode: ref.llmLanguageCode,
        provider: provider,
        modelId: selectedModel.id,
        apiKey: apiKey,
        contextWindow: selectedModel.contextWindow,
        cancelToken: _cancelToken,
      );

      // Step 3: 持久化
      final cache = UserInputSummaryCache(
        days: state.days,
        reportMarkdown: report,
        inputCount: inputs.length,
      );
      final storage = await _getStorage();
      await storage.write(cache);

      state = state.copyWith(
        phase: SummaryPhase.done,
        cache: cache,
      );
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        state = state.copyWith(phase: SummaryPhase.idle);
        return;
      }
      dev.log('[UserInputSummary] Error: $e');
      state = state.copyWith(
        phase: SummaryPhase.error,
        error: e.toString(),
      );
    }
  }

  /// 取消正在进行的分析。
  void cancel() {
    _cancelToken?.cancel('用户取消');
  }

  Future<UserInputSummaryStorage> _getStorage() async {
    final paths = await ref.read(appPathsProvider.future);
    return UserInputSummaryStorage(rootDir: paths.rootDir.path);
  }
}

final userInputSummaryControllerProvider =
    NotifierProvider<UserInputSummaryController, UserInputSummaryState>(
  UserInputSummaryController.new,
);

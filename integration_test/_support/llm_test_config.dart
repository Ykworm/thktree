// LLM 集成测试配置加载器。
//
// 用法：
//   final config = await LlmTestConfig.loadFromAsset(
//     'assets/test_llm_config/test_llm_config.json',
//   );
//   final app = await createTestApp(llmSettings: config.toAppSettings());
//
// 为什么用 asset 而不是文件？
// 集成测试代码运行在 iOS simulator 进程里，simulator 看不到 host 工程里的
// `tool/test_llm_config.json`。把 config 打进 Flutter assets 后，
// simulator 进程通过 rootBundle.loadString 就能读到。
//
// 配置文件格式参考：assets/test_llm_config/test_llm_config.example.json

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:thk_tree/data/models/llm_model_config.dart';
import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/data/models/preset_providers.dart';
import 'package:thk_tree/data/services/llm_provider.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import 'package:thk_tree/data/stores/llm_config_store.dart';

import 'in_memory_llm_config_store.dart';

class LlmTestConfig {
  LlmTestConfig._({
    required this.activeProvider,
    required Map<LlmProvider, _ProviderEntry> entries,
  // ignore: prefer_initializing_formals
  }) : _entries = entries;

  /// 默认当前激活的厂商。
  final LlmProvider activeProvider;

  /// 所有厂商的配置（apiKey 可能为空，表示未配置）。
  final Map<LlmProvider, _ProviderEntry> _entries;

  /// 从 Flutter asset 读取配置。
  ///
  /// 抛出 [FlutterError] 如果 asset 不存在（pubspec.yaml 没声明或文件缺失）。
  /// 抛出 [FormatException] 如果 JSON 非法或字段缺失。
  /// 抛出 [StateError] 如果 [activeProvider] 引用了未在 [providers] 中声明的厂商，
  /// 或 [activeProvider] 引用了未填 apiKey 的厂商。
  static Future<LlmTestConfig> loadFromAsset(String assetPath) async {
    String rawString;
    try {
      rawString = await rootBundle.loadString(assetPath);
    } catch (e) {
      throw StateError(
        'LLM test config asset not found: $assetPath\n'
        '请确认 pubspec.yaml 的 flutter.assets 包含其所在目录，'
        '且本地文件已创建。\n'
        '原始错误: $e',
      );
    }

    final Map<String, Object?> raw;
    try {
      raw = jsonDecode(rawString) as Map<String, Object?>;
    } catch (e) {
      throw FormatException('Invalid JSON in $assetPath: $e');
    }

    final activeName = raw['activeProvider'] as String?;
    if (activeName == null || activeName.isEmpty) {
      throw const FormatException('Missing required field: activeProvider');
    }
    final active = LlmProvider.values.firstWhere(
      (p) => p.name == activeName,
      orElse: () => throw FormatException(
        'Unknown LlmProvider in activeProvider: $activeName '
        '(valid: ${LlmProvider.values.map((p) => p.name).join(', ')})',
      ),
    );

    final providersJson = raw['providers'] as Map<String, Object?>?;
    if (providersJson == null) {
      throw const FormatException('Missing required field: providers');
    }

    final entries = <LlmProvider, _ProviderEntry>{};
    for (final provider in LlmProvider.values) {
      final entry = providersJson[provider.name] as Map<String, Object?>?;
      if (entry == null) {
        entries[provider] = const _ProviderEntry(apiKey: '', model: '');
        continue;
      }
      entries[provider] = _ProviderEntry(
        apiKey: (entry['apiKey'] as String? ?? '').trim(),
        model: (entry['model'] as String? ?? '').trim(),
      );
    }

    final activeEntry = entries[active]!;
    if (activeEntry.apiKey.isEmpty) {
      throw StateError(
        'activeProvider "$activeName" 在 providers 中没有有效的 apiKey。\n'
        '请在 assets/test_llm_config/test_llm_config.json 里填入该厂商的 API Key。',
      );
    }

    return LlmTestConfig._(activeProvider: active, entries: entries);
  }

  /// 把当前激活厂商转成 [AppSettings] 用于 Riverpod override。
  ///
  /// 其他厂商字段也一并填入（虽然不会被使用，但要满足 [AppSettings] 的 required 字段）。
  AppSettings toAppSettings() {
    return AppSettings(
      llmProvider: activeProvider,
      deepSeekApiKey: _entries[LlmProvider.deepseek]!.apiKey,
      openaiApiKey: _entries[LlmProvider.openai]!.apiKey,
      claudeApiKey: _entries[LlmProvider.claude]!.apiKey,
      geminiApiKey: _entries[LlmProvider.gemini]!.apiKey,
      minimaxApiKey: _entries[LlmProvider.minimax]!.apiKey,
      kimiApiKey: _entries[LlmProvider.kimi]!.apiKey,
      deepSeekModel: _entries[LlmProvider.deepseek]!.model.isEmpty
          ? LlmProvider.deepseek.defaultModel
          : _entries[LlmProvider.deepseek]!.model,
      openaiModel: _entries[LlmProvider.openai]!.model.isEmpty
          ? LlmProvider.openai.defaultModel
          : _entries[LlmProvider.openai]!.model,
      claudeModel: _entries[LlmProvider.claude]!.model.isEmpty
          ? LlmProvider.claude.defaultModel
          : _entries[LlmProvider.claude]!.model,
      geminiModel: _entries[LlmProvider.gemini]!.model.isEmpty
          ? LlmProvider.gemini.defaultModel
          : _entries[LlmProvider.gemini]!.model,
      minimaxModel: _entries[LlmProvider.minimax]!.model.isEmpty
          ? LlmProvider.minimax.defaultModel
          : _entries[LlmProvider.minimax]!.model,
      kimiModel: _entries[LlmProvider.kimi]!.model.isEmpty
          ? LlmProvider.kimi.defaultModel
          : _entries[LlmProvider.kimi]!.model,
      localeLanguageCode: null,
      faceIdEnabled: false,
      darkMode: false,
    );
  }

  /// 把当前配置转成 [LlmConfigStore] 用于 Riverpod override。
  ///
  /// 行为说明：
  /// - 为每个 [LlmProvider] 生成一个对应的 preset provider config；
  /// - 每个 config 的 `models` 列表只包含该厂商当前选中的 model（来自 JSON 配置，
  ///   缺省则用 [LlmProvider.defaultModel]）；
  /// - `apiKeys` 只为非空的 provider 填入（空 key 的 provider 会被
  ///   [chat_controller] 跳过）。
  ///
  /// ⚠️ Provider ID 映射要点：
  ///   [LlmProvider.claude] 对应的 preset ID 是 `preset_anthropic`（不是 `preset_claude`），
  ///   详见 [preset_providers.dart]。
  ///
  /// 为什么不能用 JSON 里只填 activeProvider 的简单方案？
  /// [chat_controller] 的 fallback 路径会扫描 `loadAll()` 找到第一个有 key 且
  /// 有 model 的 provider；如果只返回 activeProvider，session 级别的 providerId
  /// 找不到时会回退到 activeProvider，仍然 OK；但若 JSON 配置变化或排查问题，
  /// 一次性返回全部更便于在测试日志里观察。
  LlmConfigStore toLlmConfigStore() {
    final presetById = <String, LlmProviderConfig>{
      for (final p in createPresetProviders()) p.id: p,
    };

    final providers = <LlmProviderConfig>[];
    final apiKeys = <String, String>{};

    for (final entry in _entries.entries) {
      final provider = entry.key;
      final presetId = _presetIdFor(provider);
      final preset = presetById[presetId];
      if (preset == null) {
        // 理论上不会发生：所有 LlmProvider 都在 preset 列表里有对应项。
        // 这里静默跳过，避免一个枚举值变更导致所有集成测试崩溃。
        continue;
      }

      final modelId = entry.value.model.isEmpty
          ? provider.defaultModel
          : entry.value.model;

      providers.add(
        preset.copyWith(
          models: [
            LlmModelConfig(
              id: modelId,
              name: modelId,
              contextWindow: provider.contextWindowTokens,
            ),
          ],
          selectedModelId: modelId,
        ),
      );

      if (entry.value.apiKey.isNotEmpty) {
        apiKeys[presetId] = entry.value.apiKey;
      }
    }

    return InMemoryLlmConfigStore(
      providers: providers,
      apiKeys: apiKeys,
    );
  }

  /// [LlmProvider] → preset ID 的映射。
  ///
  /// ⚠️ [LlmProvider.claude] 对应 `preset_anthropic`，因为 preset ID 是按
  /// [LlmProviderType] 命名（type=anthropic），而不是按 [LlmProvider] 名字
  /// （name=claude）。
  static String _presetIdFor(LlmProvider provider) {
    switch (provider) {
      case LlmProvider.claude:
        return 'preset_anthropic';
      case LlmProvider.deepseek:
        return 'preset_deepseek';
      case LlmProvider.openai:
        return 'preset_openai';
      case LlmProvider.gemini:
        return 'preset_gemini';
      case LlmProvider.minimax:
        return 'preset_minimax';
      case LlmProvider.kimi:
        return 'preset_kimi';
    }
  }
}

class _ProviderEntry {
  const _ProviderEntry({required this.apiKey, required this.model});
  final String apiKey;
  final String model;
}

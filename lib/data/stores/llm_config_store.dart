import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../models/llm_model_config.dart';
import '../models/llm_provider_config.dart';
import '../models/preset_providers.dart';

/// 独立的 JSON 文件存储服务，管理 LLM 提供商配置。
///
/// 配置数据以 JSON 数组形式存储在应用文档目录下的 `llm_providers.json` 中。
/// API Key 通过 `flutter_secure_storage` 单独加密存储，键名为 `llm_key_{providerId}`，
/// 不写入 JSON 文件，避免明文泄露。
class LlmConfigStore {
  LlmConfigStore({required this.secureStorage});

  final FlutterSecureStorage secureStorage;

  List<LlmProviderConfig>? _cache;

  /// 获取存储文件路径
  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/llm_providers.json');
  }

  /// 加载所有提供商配置
  Future<List<LlmProviderConfig>> loadAll() async {
    if (_cache != null) return _cache!;
    final file = await _getFile();
    if (!file.existsSync()) return [];
    final json = jsonDecode(await file.readAsString()) as List<dynamic>;
    _cache = json
        .map((e) => LlmProviderConfig.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cache!;
  }

  /// 保存所有提供商配置到文件
  Future<void> _saveAll(List<LlmProviderConfig> providers) async {
    _cache = providers;
    final file = await _getFile();
    final json = providers.map((p) => p.toJson()).toList();
    await file.writeAsString(jsonEncode(json));
  }

  /// 添加提供商
  Future<void> addProvider(LlmProviderConfig provider) async {
    final providers = await loadAll();
    providers.add(provider);
    await _saveAll(providers);
  }

  /// 更新提供商
  Future<void> updateProvider(LlmProviderConfig provider) async {
    final providers = await loadAll();
    final index = providers.indexWhere((p) => p.id == provider.id);
    if (index >= 0) {
      providers[index] = provider;
      await _saveAll(providers);
    }
  }

  /// 删除提供商
  Future<void> deleteProvider(String providerId) async {
    final providers = await loadAll();
    providers.removeWhere((p) => p.id == providerId);
    await _saveAll(providers);
    // 同时删除对应的 API Key
    await secureStorage.delete(key: 'llm_key_$providerId');
  }

  /// 根据 ID 获取提供商
  Future<LlmProviderConfig?> getProvider(String id) async {
    final providers = await loadAll();
    try {
      return providers.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 保存 API Key（加密存储）
  Future<void> saveApiKey(String providerId, String apiKey) async {
    try {
      await secureStorage.write(
        key: 'llm_key_$providerId',
        value: apiKey,
        iOptions: const IOSOptions(
          accessibility: KeychainAccessibility.first_unlock,
        ),
      );
    } catch (e) {
      debugPrint('[LlmConfigStore] saveApiKey failed for $providerId: $e');
      rethrow;
    }
  }

  /// 读取 API Key
  Future<String> readApiKey(String providerId) async {
    try {
      return await secureStorage.read(
        key: 'llm_key_$providerId',
        iOptions: const IOSOptions(
          accessibility: KeychainAccessibility.first_unlock,
        ),
      ) ?? '';
    } catch (e) {
      debugPrint('[LlmConfigStore] readApiKey failed for $providerId: $e');
      return '';
    }
  }

  /// 更新提供商的模型列表
  Future<void> updateModels(
    String providerId,
    List<LlmModelConfig> models,
  ) async {
    final providers = await loadAll();
    final index = providers.indexWhere((p) => p.id == providerId);
    if (index >= 0) {
      providers[index] = providers[index].copyWith(models: models);
      await _saveAll(providers);
    }
  }

  /// 清除缓存（用于测试或强制刷新）
  void clearCache() {
    _cache = null;
  }

  /// 检查是否已初始化（JSON 文件是否存在）
  Future<bool> isInitialized() async {
    final file = await _getFile();
    return file.existsSync();
  }

  /// 初始化预置提供商（首次启动时调用）。
  ///
  /// 如果 JSON 文件已存在则跳过（幂等），
  /// 多次调用不会重复创建数据。
  Future<void> initializeIfNeeded() async {
    if (await isInitialized()) return;
    final presets = createPresetProviders();
    await _saveAll(presets);
  }

  /// 旧配置中 provider name 到新 LlmProviderType 的映射。
  ///
  /// 旧的 secure storage 键格式为 `llm_api_key_{name}` 和 `llm_model_{name}`，
  /// 其中 name 来自旧 LlmProvider 枚举的 `.name` 属性。
  static const _legacyProviderNameMap = {
    'openai': LlmProviderType.openai,
    'claude': LlmProviderType.anthropic,
    'gemini': LlmProviderType.gemini,
    'deepseek': LlmProviderType.deepseek,
    'minimax': LlmProviderType.minimax,
    'kimi': LlmProviderType.kimi,
  };

  /// 根据 LlmProviderType 返回旧的 provider name（用于查找旧键）。
  String? _legacyKeyName(LlmProviderType type) {
    for (final entry in _legacyProviderNameMap.entries) {
      if (entry.value == type) return entry.key;
    }
    return null;
  }

  /// 根据 LlmProviderType 查找预置提供商的 ID。
  String? _presetIdForType(LlmProviderType type) {
    final providers = _cache;
    if (providers == null) return null;
    try {
      return providers.firstWhere((p) => p.type == type && p.id.startsWith('preset_')).id;
    } catch (_) {
      return null;
    }
  }

  /// 从旧的 secure storage 格式迁移到新格式。
  ///
  /// 仅在初始化后执行一次（通过标记键 `llm_config_migrated` 保证幂等）。
  /// 旧的键格式：
  /// - `llm_provider`: 当前选中的 provider name
  /// - `llm_api_key_{provider_name}`: 各 provider 的 API Key
  /// - `llm_model_{provider_name}`: 各 provider 的模型名称
  Future<void> migrateFromLegacy() async {
    // 检查是否已迁移
    final migrated = await secureStorage.read(key: 'llm_config_migrated');
    if (migrated == 'true') return;

    // 确保预置提供商已加载到缓存
    final providers = await loadAll();

    for (final provider in providers) {
      if (provider.type == LlmProviderType.custom) continue;
      final legacyKeyName = _legacyKeyName(provider.type);
      if (legacyKeyName == null) continue;

      // 迁移 API Key
      final oldApiKey = await secureStorage.read(key: 'llm_api_key_$legacyKeyName');
      if (oldApiKey != null && oldApiKey.isNotEmpty) {
        await saveApiKey(provider.id, oldApiKey);
      }

      // 迁移模型名到 selectedModelId
      final oldModel = await secureStorage.read(key: 'llm_model_$legacyKeyName');
      if (oldModel != null && oldModel.isNotEmpty) {
        final updated = provider.copyWith(selectedModelId: oldModel);
        await updateProvider(updated);
      }
    }

    // 迁移当前选中的 provider
    final legacyProviderName = await secureStorage.read(key: 'llm_provider');
    if (legacyProviderName != null && legacyProviderName.isNotEmpty) {
      final legacyType = _legacyProviderNameMap[legacyProviderName];
      if (legacyType != null) {
        final presetId = _presetIdForType(legacyType);
        if (presetId != null) {
          // 将旧的选中 provider 写入新格式存储
          await secureStorage.write(key: 'llm_selected_provider', value: presetId);
        }
      }
    }

    // 标记迁移完成
    await secureStorage.write(key: 'llm_config_migrated', value: 'true');
  }
}

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
  ///
  /// 使用 tmp + rename 实现原子写入：先写到 `llm_providers.json.tmp`，
  /// 再调用 `rename` 原子替换 `llm_providers.json`。
  /// 这样即使进程在写入中途崩溃，也不会留下半截 JSON（`rename` 在 POSIX 上是原子的，
  /// 要么旧文件完整保留，要么新文件完整替换）。
  Future<void> _saveAll(List<LlmProviderConfig> providers) async {
    _cache = List<LlmProviderConfig>.from(providers);
    final file = await _getFile();
    final json = _cache!.map((p) => p.toJson()).toList();
    final tmpPath = '${file.path}.tmp';
    final tmpFile = File(tmpPath);
    await tmpFile.writeAsString(jsonEncode(json));
    await tmpFile.rename(file.path);
  }

  /// 添加提供商
  Future<void> addProvider(LlmProviderConfig provider) async {
    final providers = List<LlmProviderConfig>.from(await loadAll());
    providers.add(provider);
    await _saveAll(providers);
  }

  /// 更新提供商
  Future<void> updateProvider(LlmProviderConfig provider) async {
    final providers = List<LlmProviderConfig>.from(await loadAll());
    final index = providers.indexWhere((p) => p.id == provider.id);
    if (index >= 0) {
      providers[index] = provider;
      await _saveAll(providers);
    }
  }

  /// 删除提供商
  Future<void> deleteProvider(String providerId) async {
    final providers = List<LlmProviderConfig>.from(await loadAll());
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
    final providers = List<LlmProviderConfig>.from(await loadAll());
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

  /// 增量迁移：将缺失的预置提供商追加到已有配置中。
  ///
  /// 每次 APP 升级新增预置提供商后调用此方法，
  /// 已有提供商不受影响，仅补齐缺失项。
  Future<void> migrateMissingPresets() async {
    if (!await isInitialized()) {
      debugPrint('[LlmConfigStore] migrateMissingPresets: not initialized, skip');
      return;
    }
    final existing = await loadAll();
    final existingIds = existing.map((p) => p.id).toSet();
    final presets = createPresetProviders();
    final missing = presets.where((p) => !existingIds.contains(p.id)).toList();
    debugPrint('[LlmConfigStore] migrateMissingPresets: existing=${existingIds.length}, missing=${missing.map((p) => p.id).toList()}');
    if (missing.isEmpty) return;
    final updated = List<LlmProviderConfig>.from(existing)..addAll(missing);
    await _saveAll(updated);
    debugPrint('[LlmConfigStore] migrateMissingPresets: added ${missing.length} presets');
  }

  /// 迁移：DeepSeek 全量切到 Anthropic 兼容协议（ADR-020，2026-07-06）。
  ///
  /// 升级前老用户已存的 `preset_deepseek` baseUrl 是
  /// `https://api.deepseek.com/v1`（OpenAI 兼容端点），
  /// 新协议需要 `/anthropic/v1` 端点。此方法把 type=deepseek 且 baseUrl
  /// 不含 `/anthropic/` 的 provider 统一迁移到 Anthropic 端点，
  /// 并把 `isOpenAiCompatible` 设为 false。API Key 不受影响。
  Future<void> migrateDeepSeekToAnthropic() async {
    if (!await isInitialized()) {
      debugPrint('[LlmConfigStore] migrateDeepSeekToAnthropic: not initialized, skip');
      return;
    }
    final existing = await loadAll();
    var changed = false;
    final updated = existing.map((p) {
      if (p.type != LlmProviderType.deepseek) return p;
      if (p.baseUrl.contains('/anthropic/')) return p; // 已经是新端点，跳过
      // 老 baseUrl 形如 https://api.deepseek.com/v1 或 https://api.deepseek.com
      // 去掉可能的 /v1 后缀，拼 /anthropic/v1
      var base = p.baseUrl;
      if (base.endsWith('/v1')) {
        base = base.substring(0, base.length - 3);
      }
      base = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
      final newBaseUrl = '$base/anthropic/v1';
      debugPrint(
        '[LlmConfigStore] migrateDeepSeekToAnthropic: ${p.id} '
        'baseUrl ${p.baseUrl} -> $newBaseUrl, isOpenAiCompatible -> false',
      );
      changed = true;
      return p.copyWith(
        baseUrl: newBaseUrl,
        defaultBaseUrl: newBaseUrl,
        isOpenAiCompatible: false,
      );
    }).toList();
    if (!changed) return;
    await _saveAll(updated);
    debugPrint('[LlmConfigStore] migrateDeepSeekToAnthropic: migrated DeepSeek providers');
  }

}

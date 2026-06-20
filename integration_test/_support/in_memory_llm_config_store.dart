// LLM 集成测试用的内存假 Store。
//
// 继承自 LlmConfigStore，重写 3 个 chat_controller 在测试中会调用的方法：
//   - loadAll()      → 返回构造函数注入的 providers 列表
//   - getProvider(id)→ 在内存列表里查找
//   - readApiKey(id) → 返回构造函数注入的 apiKeys map
//
// 其他方法（saveApiKey/updateProvider/migrateFromLegacy 等）测试不会触发，
// 保留父类占位实现即可。
//
// 为什么必须 extends LlmConfigStore 而不能用 Mock 库：
// Riverpod 的 overrideWithValue 要求类型完全匹配原 Provider 声明的类型。
// llmConfigStoreProvider 是 Provider<LlmConfigStore>，所以 override 的必须是
// LlmConfigStore 实例（或子类）。

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/data/stores/llm_config_store.dart';

class InMemoryLlmConfigStore extends LlmConfigStore {
  InMemoryLlmConfigStore({
    required List<LlmProviderConfig> providers,
    required Map<String, String> apiKeys,
  })  : _providers = List.unmodifiable(providers),
        _apiKeys = Map.unmodifiable(apiKeys),
        super(secureStorage: const FlutterSecureStorage());

  final List<LlmProviderConfig> _providers;
  final Map<String, String> _apiKeys;

  @override
  Future<List<LlmProviderConfig>> loadAll() async => _providers;

  @override
  Future<LlmProviderConfig?> getProvider(String id) async {
    for (final p in _providers) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<String> readApiKey(String providerId) async {
    return _apiKeys[providerId] ?? '';
  }
}
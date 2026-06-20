# 集成测试：LLM 配置注入原理与实践

> **创建**：2026-06-18
> **最近更新**：2026-06-18
> **维护者**：AI + 用户审阅
> **状态**：详细版（208 行）
> **简化导航版**：[docs/_shared/integration-testing/llm-injection.md](../../../_shared/integration-testing/llm-injection.md)

> 适用对象：要给 LLM 链路写集成测试的开发者
> 关键结论：**`chat_controller` 读的是 `llmConfigStoreProvider`，不是 `appSettingsProvider`**。注入 LLM 配置时必须 override 前者。

---

## 1. 为什么需要"注入"

集成测试跑在 iOS Simulator 进程里，**不是** host 进程。Simulator 有两个数据源在测试环境里取不到真值：

| 数据源 | 真值位置 | 测试环境表现 |
|--------|----------|--------------|
| Provider 列表 | app docs dir 的 `llm_providers.json` | 文件不存在 → `loadAll()` 返回 `[]` |
| API Key | iOS Keychain 键 `llm_key_{providerId}` | 读不到 → 返回 `''` |
| 旧式 AppSettings Key | iOS Keychain 键 `llm_api_key_{providerName}` | 读不到 → `settings.apiKey` 为 `''` |

`chat_controller.sendUserMessage()` 在 3 个路径全部拿不到 Key 时，会 `appendAssistantMessage("[未配置 API Key] ...")` 然后 `return`，**根本不进入流式** → 集成测试看到的现象是"点了发送没反应，10s 内找不到 stop_button"。

---

## 2. `chat_controller` 真实的 Key 查找链（3 路径）

`lib/ui/features/chat/chat_controller.dart:300-394`：

```
sendUserMessage(text)
   │
   ├─ if (sessionProviderId != null && sessionModelId != null)  // 对话级模型
   │    └─ configStore.getProvider(id) → readApiKey(id)
   │
   └─ else  // 没有对话级（新建节点通常走这里）
        ├─ configStore.loadAll() → 遍历 readApiKey 找第一个有 key 且有 model 的 provider
        └─ 还没找到 → settings.apiKey（来自 _loadSettings → settingsStoreProvider）
```

> **注意**：路径 C（`_loadSettings`）依赖 `settingsStoreProvider`，那是真的 Keychain 读 `SettingsStore`。如果测试只 override 了 `appSettingsProvider`，路径 B 先尝试 `loadAll`（返回空数组）就退出了，根本走不到路径 C。所以 **`appSettingsProvider.overrideWith` 是死注入**。

---

## 3. Riverpod Override 机制

### 3.1 三件事

```
声明（Provider，全局静态）
    ↓
实例化（ProviderScope 挂树根）
    ↓
拦截（overrides 替换值）
```

### 3.2 三个关键事实

1. **Provider 是全局静态声明**——`final fooProvider = Provider<Foo>(...)` 在 `app_services.dart` 里，整个进程只有这一个对象。
2. **ProviderScope 实例化**——`ThkTreeApp` 子树里任何 `ref.read(fooProvider)` 第一次被调用时执行工厂函数得到 value。
3. **`overrides` 拦截**——`ProviderScope(overrides: [fooProvider.overrideWithValue(x)])` 后，**整个子树**里所有 `ref.read(fooProvider)` 拿到的都是 `x`，工厂函数**完全不被执行**。

### 3.3 类型约束

`overrideWithValue` 要求**类型完全匹配**原 Provider 声明的类型。`llmConfigStoreProvider` 是 `Provider<LlmConfigStore>`，所以 override 的必须是 `LlmConfigStore` 实例（或子类）。

> 假的不能是任意类型——必须 `extends LlmConfigStore`。这也是为什么我们用继承而不是 `Mock` 库。

---

## 4. 注入点的选择

整工程唯一挂 `ProviderScope` 的地方是 [`lib/main_test.dart:60`](../../../lib/main_test.dart)。**不在这里开注入点就没法注入**。

- ✅ 改 `lib/main_test.dart`（本身是测试专用入口，文件名带 `_test`）
- ❌ 在 integration_test/ 里复制一份 ProviderScope（70 行重复，更糟）

### createTestApp 当前签名

`lib/main_test.dart` 当前只接受 3 个参数（无通用 `extraOverrides` 入口）：

```dart
Future<Widget> createTestApp({
  Locale? locale,
  AppSettings? llmSettings,
  LlmConfigStore? llmConfigStore,
}) async {
  // ...
  return ProviderScope(
    overrides: [
      appPathsProvider.overrideWithValue(AsyncData(paths)),
      localeProvider.overrideWith(() => LocaleNotifier(initialLocale)),
      if (llmSettings != null)
        appSettingsProvider.overrideWith((ref) async => llmSettings),
      if (llmConfigStore != null)
        llmConfigStoreProvider.overrideWithValue(llmConfigStore),
    ],
    child: const ThkTreeApp(),
  );
}
```

> **未来扩展路线图**：如果需要注入其他 provider（如 Mock LLM 场景下的 `llmClientProvider`），需要给 `createTestApp` 增加 `List<Override> extraOverrides = const []` 参数并在 `overrides` 里 `...extraOverrides` 展开。当前未实现，因为 LLM 链路测试只需要 `llmConfigStoreProvider` 这一项注入。

---

## 5. 假 Store 实现

### 5.1 `InMemoryLlmConfigStore extends LlmConfigStore`

```dart
class InMemoryLlmConfigStore extends LlmConfigStore {
  InMemoryLlmConfigStore({
    required List<LlmProviderConfig> providers,
    required Map<String, String> apiKeys,
  })  : _providers = providers,
        _apiKeys = apiKeys,
        super(secureStorage: const FlutterSecureStorage());

  final List<LlmProviderConfig> _providers;
  final Map<String, String> _apiKeys;

  @override
  Future<List<LlmProviderConfig>> loadAll() async => List.unmodifiable(_providers);

  @override
  Future<LlmProviderConfig?> getProvider(String id) async {
    for (final p in _providers) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<String> readApiKey(String providerId) async => _apiKeys[providerId] ?? '';
}
```

### 5.2 只需重写 3 个方法

`LlmConfigStore` 的其他方法（`saveApiKey` / `updateProvider` / `deleteProvider` / `migrateFromLegacy` 等）测试不会触发，**保留父类空实现即可**——父类构造时传一个 `FlutterSecureStorage` 占位，但不会真去读写。

### 5.3 Provider ID 映射表（关键避坑）

`LlmProvider` 枚举（用于 `AppSettings`）和 `LlmProviderConfig.id`（用于 store）是两套独立命名：

| `LlmProvider` | 对应 preset ID | 对应 `LlmProviderType` |
|---------------|----------------|------------------------|
| `LlmProvider.deepseek` | `preset_deepseek` | `LlmProviderType.deepseek` |
| `LlmProvider.openai` | `preset_openai` | `LlmProviderType.openai` |
| **`LlmProvider.claude`** | **`preset_anthropic`** ⚠️ | `LlmProviderType.anthropic` |
| `LlmProvider.gemini` | `preset_gemini` | `LlmProviderType.gemini` |
| `LlmProvider.minimax` | `preset_minimax` | `LlmProviderType.minimax` |
| `LlmProvider.kimi` | `preset_kimi` | `LlmProviderType.kimi` |

> ⚠️ **`claude → preset_anthropic` 不是 `preset_claude`！** 这是历史遗留：新格式统一用协议类型名，旧 `claude` 命名映射到 Anthropic 协议。

---

## 6. 完整数据流（修好后）

```
testWidgets('...')
   │
   ├─ LlmTestConfig.loadFromDefine()                            // 同步读编译期常量
   │    └─ String.fromEnvironment('TEST_LLM_CONFIG_JSON') → JSON → LlmTestConfig 对象
   │
   ├─ config.toLlmConfigStore()  // 新增方法
   │    └─ 用 preset_anthropic 等 + apiKeys 构造 InMemoryLlmConfigStore
   │
   ├─ createTestApp(
   │      locale: Locale('zh'),
   │      llmSettings: config.toAppSettings(),               // 覆盖 appSettingsProvider
   │      llmConfigStore: config.toLlmConfigStore(),         // 覆盖 llmConfigStoreProvider ⭐
   │    )
   │
   └─ tester.pumpWidget(app)
        │
        └─ chat_controller.sendUserMessage(text)
             └─ ref.read(llmConfigStoreProvider)  → 拿到 InMemoryLlmConfigStore
                  └─ configStore.loadAll()          → 返回 [preset_deepseek]
                  └─ configStore.readApiKey(id)    → 返回真 Key
                       └─ LlmClient.forConfig(provider).streamChatCompletion(apiKey: key, model: m)
                            └─ 真发请求给 DeepSeek ✅
```

---

## 7. 为什么"只改 main_test.dart 一个 lib/ 文件"是合理的

| 担忧 | 实际情况 |
|------|----------|
| "改 lib/ 是改生产代码" | `main_test.dart` 文件名带 `_test`，**全工程只有 integration_test import 它**，生产路径 `lib/main.dart` 完全不引用 |
| "为什么它住在 lib/ 下" | 集成测试需要 import `ThkTreeApp`（生产 widget），而 import 必须走 package 路径；放在 lib/ 才能 `package:thk_tree/main_test.dart` |
| "能不能纯在 integration_test/ 里搞定" | 不能——`ProviderScope` 必须挂在 `ThkTreeApp` 上，而 ThkTreeApp 的封装在 main_test.dart 里。要么改 main_test.dart 暴露注入点，要么复制 70 行 ProviderScope。后者更糟 |

---

## 8. 相关文件索引

| 文件 | 作用 |
|------|------|
| `lib/ui/core/app_services.dart` | `llmConfigStoreProvider` / `appSettingsProvider` 定义处 |
| `lib/data/stores/llm_config_store.dart` | `LlmConfigStore` 类（被继承） |
| `lib/data/models/preset_providers.dart` | 预置 provider ID 列表（**§ 5.3 映射表的来源**） |
| `lib/data/models/llm_provider_config.dart` | `LlmProviderConfig` / `LlmProviderType` 模型 |
| `lib/data/services/settings_store.dart` | `AppSettings` / `SettingsStore`（旧格式） |
| `lib/ui/features/chat/chat_controller.dart:300-394` | 3 路径查找链 |
| `lib/main_test.dart` | 唯一 ProviderScope 注入点 |
| `integration_test/_support/llm_test_config.dart` | JSON 配置加载器（`loadFromDefine()` 同步读编译期常量，`loadFromAsset()` 已 @Deprecated 作为逃生通道） |
| `integration_test/_support/in_memory_llm_config_store.dart` | 假 Store 实现（新建） |
| `integration_test/theme_chat_e2e_test.dart` | 使用例 |
| `~/.thktree/test_llm_config.json` | 真 Key 存储（**不入仓**，通过 `--dart-define-from-file` 路径注入） |
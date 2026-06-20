# 集成测试 Fixtures 详解

> **适用对象**：要给集成测试配 LLM 厂商 / 修改 Key / 新增厂商的开发者  
> **核心问题**：为什么 Simulator 跑测试必须从 asset 读 Key？为什么"只 override AppSettings"是死注入？

---

## 1. 为什么用 asset 而不是 host 文件

### 1.1 进程边界问题

```
Host 进程（macOS）              Simulator 进程（iOS）
┌─────────────────────┐        ┌─────────────────────┐
│ 你的工程            │        │ Flutter Engine      │
│  ├─ tool/           │   不可见  │                     │
│  │  └─ config.json  │  ───────>│  ├─ assets/         │
│  └─ lib/            │        │  │  └─ test_llm_...  │
│                     │        │  └─ Main isolate     │
└─────────────────────┘        └─────────────────────┘
```

- Host 进程能读 `tool/` 下的所有文件
- Simulator 进程**看不到** host 的 `tool/` 目录（沙盒隔离）
- 但 Simulator 进程**能**读 `.app` bundle 里的 assets（Flutter 框架打包进 `rootBundle`）

### 1.2 解决方案

把 LLM Key 配置打进 Flutter assets：

```yaml
# pubspec.yaml
flutter:
  assets:
    - assets/test_llm_config/test_llm_config.json  # 真 Key（gitignored）
    - assets/test_llm_config/test_llm_config.example.json  # 模板（提交）
```

测试代码用 `rootBundle.loadString` 读：

```dart
// integration_test/_support/llm_test_config.dart:51
final rawString = await rootBundle.loadString('assets/test_llm_config/test_llm_config.json');
```

⚠️ **如果忘了在 pubspec.yaml 声明**，会抛：
```
StateError: LLM test config asset not found: assets/test_llm_config/test_llm_config.json
请确认 pubspec.yaml 的 flutter.assets 包含其所在目录，且本地文件已创建。
原始错误: ...
```
（错误信息友好，会提示修复路径）

---

## 2. JSON 配置文件结构

### 2.1 完整示例

参考 [`assets/test_llm_config/test_llm_config.example.json`](../../../assets/test_llm_config/test_llm_config.example.json)：

```json
{
  "activeProvider": "deepseek",
  "providers": {
    "deepseek": { "apiKey": "sk-xxxxxxxxxxxxxxxx", "model": "deepseek-chat" },
    "openai":   { "apiKey": "", "model": "" },
    "claude":   { "apiKey": "", "model": "" },
    "gemini":   { "apiKey": "", "model": "" },
    "minimax":  { "apiKey": "", "model": "" },
    "kimi":     { "apiKey": "", "model": "" }
  }
}
```

### 2.2 字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `activeProvider` | String | ✅ | 当前激活的厂商名，必须在 `LlmProvider` enum 里 |
| `providers.<name>.apiKey` | String | ✅（可空字符串） | 厂商 API Key，空字符串表示"未配置" |
| `providers.<name>.model` | String | ✅（可空字符串） | 模型 ID，空字符串则用 `provider.defaultModel` |

### 2.3 复制流程

```bash
# 第一次跑测试前
cp assets/test_llm_config/test_llm_config.example.json \
   assets/test_llm_config/test_llm_config.json

# 编辑填入真实 Key（用你喜欢的编辑器）
code assets/test_llm_config/test_llm_config.json

# 验证 JSON 合法
jq . assets/test_llm_config/test_llm_config.json

# 跑测试
flutter test integration_test/theme_chat_e2e_test.dart -d "iPhone 15 Pro"
```

⚠️ `test_llm_config.json` **必须**加进 `.gitignore`（已在仓库根 .gitignore 配置），**不要**提交真 Key。

---

## 3. `LlmTestConfig.loadFromAsset()` 失败模式

`integration_test/_support/llm_test_config.dart:48` 定义，3 种典型失败：

### 3.1 asset 不存在

```
StateError: LLM test config asset not found: assets/test_llm_config/test_llm_config.json
请确认 pubspec.yaml 的 flutter.assets 包含其所在目录，且本地文件已创建。
原始错误: Unable to load asset
```

**根因**：`pubspec.yaml` 的 `flutter.assets` 没声明该路径，或本地文件未创建。

**修复**：
1. `cp ...example.json ...test_llm_config.json`
2. 检查 `pubspec.yaml` 的 `flutter.assets` 块是否包含 `assets/test_llm_config/`

### 3.2 JSON 非法

```
FormatException: Invalid JSON in assets/test_llm_config/test_llm_config.json: Unexpected character (at character 15)
```

**根因**：JSON 语法错误（多余逗号、引号未闭合、注释残留等）。

**修复**：`jq . assets/test_llm_config/test_llm_config.json` 看具体哪里错。

### 3.3 activeProvider 未填 Key

```
StateError: activeProvider "deepseek" 在 providers 中没有有效的 apiKey。
请在 assets/test_llm_config/test_llm_config.json 里填入该厂商的 API Key。
```

**根因**：`activeProvider` 指向的厂商 `apiKey` 为空字符串。

**修复**：填入真 Key（注意 trim，loader 会自动 trim）。

### 3.4 activeProvider 未在 enum 里

```
FormatException: Unknown LlmProvider in activeProvider: foo (valid: deepseek, openai, claude, gemini, minimax, kimi)
```

**根因**：`activeProvider` 用了不在 `LlmProvider` enum 里的值。

**修复**：对照 `lib/data/services/llm_provider.dart` 的 enum 拼写。

---

## 4. `toAppSettings()` vs `toLlmConfigStore()` 双注入

### 4.1 为什么需要两层

`chat_controller.sendUserMessage()` 在 3 个路径查找 API Key（详见 [docs/modules/llm/specs/integration-test-llm-injection.md § 2](../../modules/llm/specs/integration-test-llm-injection.md#2-chat_controller-真实的-key-查找链3-路径)）：

```
路径 A：session 级 model  → configStore.getProvider(id).readApiKey(id)
路径 B：loadAll 遍历      → configStore.loadAll() 找第一个有 key 有 model 的
路径 C：旧式 AppSettings   → settings.apiKey (来自 _loadSettings → settingsStoreProvider)
```

**关键事实**：
- Simulator 里 `loadAll()` 返回 `[]`（因为 `llm_providers.json` 文件不存在）
- Simulator 里 Keychain 是空的（Keychain 键 `llm_key_*` 都不存在）
- 所以路径 A 和路径 B 拿不到东西
- 路径 C 也读不到（settingsStoreProvider 走 Keychain）

→ **必须 override 假实现，把真 Key 注入进去**

### 4.2 双注入的作用

| 注入层 | 覆盖哪个 provider | 覆盖哪条路径 |
|--------|-------------------|--------------|
| `llmSettings: config.toAppSettings()` | `appSettingsProvider` | 路径 C（旧式 fallback） |
| `llmConfigStore: config.toLlmConfigStore()` | `llmConfigStoreProvider` | 路径 A + 路径 B（主路径） |

### 4.3 `appSettingsProvider.overrideWith` 是死注入

⚠️ **常见错误**：以为只需要 override `appSettingsProvider` 就行。

**为什么是死注入**：

```dart
// chat_controller 路径 B 的代码（伪代码）
if (loadAll().isEmpty) return;  // ← Simulator 里 loadAll 返回 []，这里就 return 了
settings.apiKey  // ← 永远走不到
```

路径 B 第一行就检查 `loadAll()` 是否为空，**Simulator 里这个数组永远为空**——所以路径 B 永远走不到路径 C。

**结论**：必须 override `llmConfigStoreProvider`，让 `loadAll()` 返回真数据。

### 4.4 推荐注入方式（lib/main_test.dart）

```dart
Future<Widget> createTestApp({
  Locale? locale,
  AppSettings? llmSettings,
  LlmConfigStore? llmConfigStore,    // ← 双注入参数
  List<Override> extraOverrides = const [],
}) async {
  return ProviderScope(
    overrides: [
      // ...
      if (llmSettings != null)
        appSettingsProvider.overrideWith((ref) async => llmSettings),
      if (llmConfigStore != null)
        llmConfigStoreProvider.overrideWithValue(llmConfigStore),
      ...extraOverrides,
    ],
    child: const ThkTreeApp(),
  );
}
```

测试代码用法（参考 `theme_chat_e2e_test.dart:50-54`）：

```dart
final app = await createTestApp(
  locale: const Locale('zh'),
  llmSettings: llmConfig.toAppSettings(),
  llmConfigStore: llmConfig.toLlmConfigStore(),  // ← 关键
);
```

---

## 5. `InMemoryLlmConfigStore extends LlmConfigStore`

### 5.1 为什么用继承而不是 Mock 库

```dart
// Riverpod 的 overrideWithValue 要求类型完全匹配
llmConfigStoreProvider.overrideWithValue(<X>)  // X 必须是 LlmConfigStore 或子类
```

`mockito` / `mocktail` 生成的 mock 类型是 `MockLlmConfigStore extends Mock implements LlmConfigStore`，**不继承** LlmConfigStore——会编译失败。

所以最简洁方案：**手写一个 InMemoryLlmConfigStore extends LlmConfigStore**，只重写 3 个方法。

### 5.2 完整实现

[`integration_test/_support/in_memory_llm_config_store.dart`](../../../integration_test/_support/in_memory_llm_config_store.dart)：

```dart
class InMemoryLlmConfigStore extends LlmConfigStore {
  InMemoryLlmConfigStore({
    required List<LlmProviderConfig> providers,
    required Map<String, String> apiKeys,
  })  : _providers = providers,
        _apiKeys = apiKeys,
        super(secureStorage: const FlutterSecureStorage());  // 占位父类构造

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

### 5.3 只需重写 3 个方法

| 方法 | 测试触发 | 实现 |
|------|----------|------|
| `loadAll()` | 路径 B 遍历查找 | 返回预定义列表 |
| `getProvider(id)` | 路径 A 会话级查找 | 遍历列表找匹配 |
| `readApiKey(id)` | 路径 A/B 拿到 provider 后读 key | 从 map 读 |

其他方法（`saveApiKey` / `updateProvider` / `deleteProvider` / `migrateFromLegacy` 等）测试不会触发，**保留父类空实现**——父类构造时传一个 `FlutterSecureStorage` 占位，但不会真去读写 Keychain。

---

## 6. Provider ID 映射表（⚠️ 关键避坑）

`LlmProvider` 枚举（用于 `AppSettings`）和 `LlmProviderConfig.id`（用于 store）是**两套独立命名**：

| `LlmProvider`（enum name） | 对应 preset ID（store 用） | 对应 `LlmProviderType` |
|------------------------------|-----------------------------|------------------------|
| `LlmProvider.deepseek` | `preset_deepseek` | `LlmProviderType.deepseek` |
| `LlmProvider.openai` | `preset_openai` | `LlmProviderType.openai` |
| **`LlmProvider.claude`** | **`preset_anthropic`** ⚠️ | `LlmProviderType.anthropic` |
| `LlmProvider.gemini` | `preset_preset_gemini` | `LlmProviderType.gemini` |
| `LlmProvider.minimax` | `preset_minimax` | `LlmProviderType.minimax` |
| `LlmProvider.kimi` | `preset_kimi` | `LlmProviderType.kimi` |

⚠️ **`claude → preset_anthropic` 不是 `preset_claude`！**

### 6.1 为什么会这样？

历史遗留：新格式统一用**协议类型名**（anthropic 是协议名），旧 `claude` 命名映射到 Anthropic 协议。

源码位置：`integration_test/_support/llm_test_config.dart:214-228`：

```dart
static String _presetIdFor(LlmProvider provider) {
  switch (provider) {
    case LlmProvider.claude:
      return 'preset_anthropic';  // ⚠️ 不是 preset_claude
    case LlmProvider.deepseek:
      return 'preset_deepseek';
    // ...
  }
}
```

### 6.2 触发症状

如果哪天有人手贱改成 `preset_claude`：
- `loadAll()` 返回的 providers 列表里**找不到** `preset_claude`
- `getProvider('preset_claude')` 返回 null
- 路径 A 找不到 → 路径 B 遍历 → 第一个有 key 的 provider 用错协议发请求 → 401 / 400 错误

**修复**：永远走 `_presetIdFor()` 这个映射函数，不要硬编码字符串。

---

## 7. 如何新增一种 LLM

假设要新增 `LlmProvider.tongyi`（通义千问）：

### 7.1 改 `LlmProvider` enum

```dart
// lib/data/services/llm_provider.dart
enum LlmProvider {
  deepseek,
  openai,
  claude,
  gemini,
  minimax,
  kimi,
  tongyi,  // ← 新增
}
```

### 7.2 加 `LlmProviderType`

```dart
// lib/data/models/llm_provider_config.dart
enum LlmProviderType {
  deepseek,
  openai,
  anthropic,
  gemini,
  minimax,
  kimi,
  tongyi,  // ← 新增
}
```

### 7.3 在 preset_providers.dart 注册

```dart
// lib/data/models/preset_providers.dart
LlmProviderConfig createPresetTongyi() {
  return LlmProviderConfig(
    id: 'preset_tongyi',
    type: LlmProviderType.tongyi,
    name: 'Tongyi Qianwen',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    models: [...],
  );
}
```

### 7.4 在 `_presetIdFor()` 补映射

```dart
// integration_test/_support/llm_test_config.dart
case LlmProvider.tongyi:
  return 'preset_tongyi';  // ← 新增
```

### 7.5 在 JSON 模板补字段

```json
{
  "activeProvider": "deepseek",
  "providers": {
    "tongyi": { "apiKey": "", "model": "" }  // ← 新增
  }
}
```

### 7.6 跑通验证

```bash
flutter test integration_test/theme_chat_e2e_test.dart -d "iPhone 15 Pro"
```

把 `activeProvider` 改成 `"tongyi"` 验证新厂商能跑通真实 API 调用。

---

## 8. 完整数据流示例

```
testWidgets('...')
   │
   ├─ LlmTestConfig.loadFromAsset('assets/test_llm_config/test_llm_config.json')
   │    └─ rootBundle.loadString → JSON → LlmTestConfig 对象
   │       (activeProvider = deepseek, providers = { deepseek: { apiKey: 'sk-xxx', model: 'deepseek-chat' } })
   │
   ├─ config.toAppSettings()     → AppSettings(llmProvider: deepseek, deepSeekApiKey: 'sk-xxx', ...)
   │
   ├─ config.toLlmConfigStore()  → InMemoryLlmConfigStore(
   │                                providers: [preset_deepseek],
   │                                apiKeys: { preset_deepseek: 'sk-xxx' })
   │
   ├─ createTestApp(
   │      locale: Locale('zh'),
   │      llmSettings: config.toAppSettings(),       // 覆盖 appSettingsProvider
   │      llmConfigStore: config.toLlmConfigStore(), // 覆盖 llmConfigStoreProvider ⭐
   │    )
   │
   └─ tester.pumpWidget(app)
        │
        └─ ChatController.sendUserMessage('hello')
             │
             └─ ref.read(llmConfigStoreProvider)
                  │
                  └─ 拿到 InMemoryLlmConfigStore (路径 A/B)
                       │
                       ├─ loadAll()                → [preset_deepseek]  (路径 B 命中)
                       └─ readApiKey('preset_deepseek')  → 'sk-xxx' (路径 B 拿到 Key)
                            │
                            └─ LlmClient.forConfig(preset_deepseek)
                                 .streamChatCompletion(apiKey: 'sk-xxx', model: 'deepseek-chat')
                                      │
                                      └─ 真发请求给 DeepSeek API ✅
```
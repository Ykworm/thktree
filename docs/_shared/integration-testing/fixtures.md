# 集成测试 Fixtures 详解

> **适用对象**：要给集成测试配 LLM 厂商 / 修改 Key / 新增厂商的开发者  
> **核心问题**：为什么 Simulator 跑测试必须用 `--dart-define-from-file` 注入 Key？为什么"只 override AppSettings"是死注入？

> **最近变更（2026-06-20）**：从 `assets/test_llm_config/test_llm_config.json` 迁移到 `--dart-define-from-file` 编译期常量注入。Key 不再打进 Flutter bundle，`flutter build ipa --release` 物理上不含任何 Key。详见 [docs/_tmp/2026-06-20-llm-test-config-redesign.md](../../../_tmp/2026-06-20-llm-test-config-redesign.md)。

---

## 1. 为什么用 dart-define 而不是 assets

### 1.1 进程边界问题（旧的 asset 方案的痛点）

旧方案把 LLM Key 放进 `assets/test_llm_config/test_llm_config.json`,通过 `pubspec.yaml` 的 `flutter.assets` 声明打进 bundle。Simulator 进程能读 `.app` bundle 里的 assets（Flutter 框架打包进 `rootBundle`），所以测试代码可以用 `rootBundle.loadString` 读到 Key。

**但这带来严重的安全副作用**：所有 build flavor——包括 `flutter build ipa --release`——都会把真 Key 烤进 `.app`。`unzip + grep` 就能直接还原 Key。`.gitignore` 只解决"不提交"，不解决"不进 release 包"——这是两个独立维度，需要独立机制。

### 1.2 新方案：编译期常量注入

通过 Flutter 3.7+ 的 `String.fromEnvironment('TEST_LLM_CONFIG_JSON')` 读编译期常量；运行时通过 `--dart-define-from-file=<path>` 把 JSON 字符串注入 Dart 编译过程。**Key 只存在于开发者本机的 `--dart-define-from-file` 路径中**，物理上不进任何 bundle / `.app` / `.apk` / `.ipa`。

```dart
// integration_test/_support/llm_test_config.dart:loadFromDefine
static LlmTestConfig loadFromDefine() {
  const raw = String.fromEnvironment('TEST_LLM_CONFIG_JSON');
  if (raw.isEmpty) {
    throw StateError('LLM 测试配置未注入。\n'
        '请通过 --dart-define-from-file=<path> 传入。');
  }
  return _parse(raw);
}
```

```bash
# 推荐做法：配置放工程外(~/.thktree/),不入仓
mkdir -p ~/.thktree
$EDITOR ~/.thktree/test_llm_config.json    # 填入真 Key

# 跑测试（必须先经生成器压缩为单行紧凑 JSON）
dart run tools/gen_dart_define.dart \
  $HOME/.thktree/test_llm_config.json \
  build/dart_define.json
flutter test integration_test/theme_chat_e2e_test.dart \
  --dart-define-from-file=build/dart_define.json
```

> **为什么需要生成器**：Flutter 的 `--dart-define-from-file` 只接受 `{"KEY":"VALUE"}` 简单映射，且注入的 value 不能含字面换行符。直接把 `~/.thktree/test_llm_config.json`（pretty-print，含字面 `\n`）喂过去会触发 `frontend_server` 的 URI 解析错。详见 [design 第 3 节](../../../_tmp/2026-06-20-llm-test-config-redesign.md#3-方案总览) 与 ADR-013。

⚠️ **如果忘了传 `--dart-define-from-file`**，会抛：
```
StateError: LLM 测试配置未注入。

集成测试需要通过 --dart-define-from-file=<path> 传入 LLM 配置 JSON。

准备步骤:
  1. 在工程外创建 test_llm_config.json,JSON 结构见
     docs/_tmp/2026-06-20-llm-test-config-redesign.md 第 7 节
  2. 填入对应厂商的 apiKey(推荐放 ~/.thktree/)
  3. 运行:
       dart run tools/gen_dart_define.dart \
         /your/path/test_llm_config.json \
         build/dart_define.json
       flutter test integration_test/ \
         --dart-define-from-file=build/dart_define.json
```
（错误信息友好，会提示修复路径）

### 1.3 旧方案为何被弃用

| 维度 | 旧方案（assets） | 新方案（dart-define） |
|------|------------------|----------------------|
| Key 进 release 包 | ✅ 会（pubspec 声明打进 bundle） | ❌ 不会（编译期常量,只存在于本机） |
| 静态可还原 | ⚠️ `unzip + grep` 即可 | ✅ 物理不可还原 |
| Simulator 可见 | ✅ rootBundle 可读 | ✅ `String.fromEnvironment` 编译期可读 |
| 部署到新开发者 | ⚠️ clone 后手动填 assets 文件 | ⚠️ clone 后手动建 `~/.thktree/test_llm_config.json` |
| 删除 / 修改 Key | ⚠️ 要改 .gitignore + 重 build | ✅ 改完 JSON 重跑测试即可 |

---

## 2. JSON 配置文件结构

### 2.1 完整示例

JSON 配置文件的结构与字段定义：

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

设计文档里有完整字段定义与各厂商示例： [docs/_tmp/2026-06-20-llm-test-config-redesign.md 第 7 节](../../../_tmp/2026-06-20-llm-test-config-redesign.md)。

### 2.2 字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `activeProvider` | String | ✅ | 当前激活的厂商名，必须在 `LlmProvider` enum 里 |
| `providers.<name>.apiKey` | String | ✅（可空字符串） | 厂商 API Key，空字符串表示"未配置" |
| `providers.<name>.model` | String | ✅（可空字符串） | 模型 ID，空字符串则用 `provider.defaultModel` |

### 2.3 复制流程

推荐把 JSON 配置放在工程外的 `~/.thktree/test_llm_config.json`，不入仓、不进任何打包路径。

```bash
# 第一次跑测试前：创建工程外配置目录
mkdir -p ~/.thktree

# 从设计文档复制示例 JSON 到本地路径
# （设计文档 第 7 节 有完整结构，也可以从 docs/_tmp/... 手动复制一份）
$EDITOR ~/.thktree/test_llm_config.json   # 填入真实 Key

# 验证 JSON 合法
jq . ~/.thktree/test_llm_config.json

# 跑测试（必须先生成 build/dart_define.json 再跑测试）
dart run tools/gen_dart_define.dart \
  $HOME/.thktree/test_llm_config.json \
  build/dart_define.json
flutter test integration_test/theme_chat_e2e_test.dart \
  -d "iPhone 15 Pro" \
  --dart-define-from-file=build/dart_define.json
```

⚠️ `test_llm_config.json` **必须**放在工程外（不入仓），且运行测试时 **必须** 走生成器压缩为 `build/dart_define.json` 再注入。两个约束同时生效，Key 才不会进 bundle。

---

## 3. `LlmTestConfig.loadFromDefine()` 失败模式

`integration_test/_support/llm_test_config.dart` 定义，4 种典型失败：

### 3.1 dart-define 未注入

```
StateError: LLM 测试配置未注入。

集成测试需要通过 --dart-define-from-file=<path> 传入 LLM 配置 JSON。

准备步骤:
  1. 在工程外创建 test_llm_config.json，JSON 结构见
     docs/_tmp/2026-06-20-llm-test-config-redesign.md 第 7 节
  2. 填入对应厂商的 apiKey（推荐放 ~/.thktree/）
  3. 运行:
       dart run tools/gen_dart_define.dart \
         /your/path/test_llm_config.json \
         build/dart_define.json
       flutter test integration_test/ \
         --dart-define-from-file=build/dart_define.json
```

**根因**：跑测试时忘了传 `--dart-define-from-file=...`，`String.fromEnvironment('TEST_LLM_CONFIG_JSON')` 返回空字符串。

**修复**：检查运行命令是否带 `--dart-define-from-file=...` 且路径存在。

### 3.2 JSON 非法

```
FormatException: Invalid JSON in test config: Unexpected character (at character 15)
```

**根因**：注入的 JSON 字符串语法错误（多余逗号、引号未闭合、注释残留等）。

**修复**：`jq . ~/.thktree/test_llm_config.json` 看具体哪里错（注意：错误信息不会包含本地文件路径，Key 是从 dart-define 读出来的）。

### 3.3 activeProvider 未填 Key

```
StateError: activeProvider "deepseek" 在 providers 中没有有效的 apiKey。
请在 dart-define 注入的 test_llm_config.json 里填入该厂商的 API Key。
```

**根因**：`activeProvider` 指向的厂商 `apiKey` 为空字符串。

**修复**：填入真 Key（注意 trim，loader 会自动 trim）。

### 3.4 activeProvider 未在 enum 里

```
FormatException: Unknown LlmProvider in activeProvider: foo (valid: deepseek, openai, claude, gemini, minimax, kimi)
```

**根因**：`activeProvider` 用了不在 `LlmProvider` enum 里的值。

**修复**：对照 `lib/data/services/llm_provider.dart` 的 enum 拼写。

### 3.5 `loadFromAsset()` 逃生通道（不推荐）

如果遇到 dart-define 平台问题（如老 Flutter 版本不支持），可以临时回退到 assets 路径：

```dart
// @Deprecated 逃生通道，仅在 dart-define 遇到平台问题时回退
// 生产 release 构建禁止使用本方法。
final config = await LlmTestConfig.loadFromAsset(
  'assets/test_llm_config/test_llm_config.json',
);
```

⚠️ **回退到 assets 等于倒回原安全风险**（Key 进 bundle）。只是逃生通道，不是替代方案。

---

## 4. `toAppSettings()` vs `toLlmConfigStore()` 双注入

### 4.1 为什么需要两层

`chat_controller.sendUserMessage()` 在 3 个路径查找 API Key（详见 [docs/modules/llm/specs/integration-test-llm-injection.md 第 2 节](../../modules/llm/specs/integration-test-llm-injection.md#2-chat_controller-真实的-key-查找链3-路径)）：

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

`createTestApp` 当前只有 3 个参数（`locale` / `llmSettings` / `llmConfigStore`），双注入已经全部覆盖。如果未来要 inject 其他 provider，详见 [integration-test-llm-injection.md 第 4 节](../../modules/llm/specs/integration-test-llm-injection.md) 的后续路线图。

```dart
Future<Widget> createTestApp({
  Locale? locale,
  AppSettings? llmSettings,
  LlmConfigStore? llmConfigStore,    // ← 双注入参数
}) async {
  return ProviderScope(
    overrides: [
      // ...
      if (llmSettings != null)
        appSettingsProvider.overrideWith((ref) async => llmSettings),
      if (llmConfigStore != null)
        llmConfigStoreProvider.overrideWithValue(llmConfigStore),
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
dart run tools/gen_dart_define.dart \
  $HOME/.thktree/test_llm_config.json \
  build/dart_define.json
flutter test integration_test/theme_chat_e2e_test.dart \
  -d "iPhone 15 Pro" \
  --dart-define-from-file=build/dart_define.json
```

把 `activeProvider` 改成 `"tongyi"` 验证新厂商能跑通真实 API 调用。

---

## 8. 完整数据流示例

```
testWidgets('...')
   │
   ├─ dart run tools/gen_dart_define.dart \
   │    ~/.thktree/test_llm_config.json \
   │    build/dart_define.json
   │    └─ 读 pretty-print JSON → jsonDecode → jsonEncode 压缩为单行 → 包成 dart-define 期望格式
   │
   ├─ flutter test ... --dart-define-from-file=build/dart_define.json
   │    └─ Dart 编译期把紧凑 JSON 字符串注入 TEST_LLM_CONFIG_JSON 编译期常量
   │
   ├─ LlmTestConfig.loadFromDefine()
   │    └─ String.fromEnvironment('TEST_LLM_CONFIG_JSON') → JSON → LlmTestConfig 对象
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
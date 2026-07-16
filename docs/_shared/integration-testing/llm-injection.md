# LLM 配置注入（导航版）

> **本文件**：30 行导航 + TL;DR
> **详细版**（208 行）：[docs/modules/llm/specs/integration-test-llm-injection.md](../../modules/llm/specs/integration-test-llm-injection.md) — 强烈建议先读
>
> **最近变更**：2026-06-20 — API Key 注入机制从 `assets/test_llm_config/` 物理文件迁移到 `--dart-define-from-file` 编译期注入。详见 [设计稿](../(已归档))。

---

## TL;DR

1. **`chat_controller` 读 `llmConfigStoreProvider`**，不是 `appSettingsProvider`
2. **注入点只在 `lib/main_test.dart`**（生产路径 `lib/main.dart` 不引用它）
3. **真实 API 测试**：必须 override `LlmConfigStore` 子类（`InMemoryLlmConfigStore`），单独 override `appSettingsProvider` 是死注入
4. **API Key 来自 `--dart-define-from-file` 编译期注入**（同步 `loadFromDefine()` 读 `String.fromEnvironment`），**不**打进 .app / .apk / .ipa bundle
5. **Key 不入仓**——配置文件放工程外（如 `~/.thktree/test_llm_config.json`），只传路径给 dart-define

## 双注入

```dart
final app = await createTestApp(
  locale: const Locale('zh'),
  llmSettings: llmConfig.toAppSettings(),       // 覆盖 appSettingsProvider（路径 C 兼容）
  llmConfigStore: llmConfig.toLlmConfigStore(), // 覆盖 llmConfigStoreProvider ⭐（路径 A/B 主路径）
);
```

## Mock LLM（不需要真实 API）

当测试目标是“断网/错误态/重试 UI”，可以不注入真实 provider/key，转为注入 Mock `LlmClient`：

```dart
final app = await createTestApp(
  locale: const Locale('zh'),
  extraOverrides: [
    llmClientProvider.overrideWith((ref) async => const FakeLlmClient()),
    settingsStoreProvider.overrideWithValue(InMemorySettingsStore(fakeSettings)),
  ],
);
```

说明：
- `FakeLlmClient` 里用 `Stream.error(DioException(type: connectionError))` 模拟断网
- `settingsStoreProvider` 用内存实现避免读 Keychain
- 完整落地示例：`integration_test/offline_test.dart`

## 本目录相关章节

- [fixtures.md 第 4 节](./fixtures.md#4-toappsettings-vs-tollmconfigstore-双注入) — 双注入原理详解
- [fixtures.md 第 5 节](./fixtures.md#5-inmemoryllmconfigstore-extends-llmconfigstore) — 假 Store 实现
- [fixtures.md 第 6 节](./fixtures.md#6-provider-id-映射表-关键避坑) — Provider ID 映射表（`claude → preset_anthropic`）
- [helpers.md](./helpers.md) — UI 工具函数（与注入无关，但注入后跑测试必备）

## 跑测试前必读

详细版必读章节：
- [第 1 节 为什么需要"注入"](../../modules/llm/specs/integration-test-llm-injection.md#1-为什么需要注入)
- [第 2 节 3 路径查找链](../../modules/llm/specs/integration-test-llm-injection.md#2-chat_controller-真实的-key-查找链3-路径)
- [第 4 节 注入点的选择](../../modules/llm/specs/integration-test-llm-injection.md#4-注入点的选择)
- [第 5 节 Provider ID 映射表](../../modules/llm/specs/integration-test-llm-injection.md#53-provider-id-映射表关键避坑)

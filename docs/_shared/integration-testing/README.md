# 集成测试总论

> **适用对象**：要给 ThkTree 写集成测试、维护现有测试、或排查集成测试问题的开发者  
> **目标**：30 分钟内理解整套测试的架构、约束、怎么跑、怎么新增

---

## 1. 目标与边界

### 覆盖
- 现有 `integration_test/*.dart` 测试文件的用途、现状、阻塞点
- `_support/` 辅助代码（fixtures + helpers）的使用约定
- LLM 配置注入原理（Riverpod Override 机制）
- 跑测试 / 调试 / 新增测试的完整流程

### 不覆盖
- **Widget 单元测试**（`test/` 目录）—— 那是另一套测试体系，速度更快、用 mock
- **平台原生测试**（iOS XCTest / Android JUnit）—— 走 `test_driver/`
- **手动 QA 脚本**（`tools/check_*.py`）—— 那是脚本化的人工校验

---

## 2. 架构总览

```
┌─────────────────────────────────────────────────────────────────┐
│ integration_test/*.dart                    （多个测试文件）       │
│   ├── chat_streaming_test.dart                                    │
│   ├── backup_restore_test.dart                                    │
│   ├── branch_creation_test.dart                                   │
│   ├── node_reorder_test.dart                                      │
│   ├── offline_test.dart            ⭐ Mock LLM（不需要真实 API）   │
│   ├── theme_chat_e2e_test.dart      ⭐ 完整可跑通                 │
│   └── note_crud_test.dart          ⭐ 完整可跑通（纯 CRUD）       │
│                                                                   │
│ 依赖 ↓                                                           │
│   ├── _support/test_helpers.dart           （325 行 UI 工具）      │
│   ├── _support/llm_test_config.dart        （JSON 加载器）        │
│   │    ├── loadFromDefine()                （同步读编译期常量）   │
│   │    └── loadFromAsset() @Deprecated     （逃生通道）           │
│   └── _support/in_memory_llm_config_store.dart （假 Store）      │
│                                                                   │
│ 入口 ↓                                                           │
│   └── lib/main_test.dart                   ⭐ 唯一 ProviderScope  │
│        ├── createTestApp()                                       │
│        │   ├── locale: Locale('zh')                              │
│        │   ├── llmSettings: AppSettings?                         │
│        │   └── llmConfigStore: LlmConfigStore?                   │
│        │   └── extraOverrides: List<Override>                    │
│        └── ProviderScope(overrides: [...])                       │
│                                                                   │
│ 资产 ↓                                                           │
│   ~/.thktree/test_llm_config.json          （不入仓，工程外）    │
│        ├── activeProvider: "deepseek"                            │
│        └── providers: { deepseek: { apiKey, model }, ... }       │
│                                                                   │
│ 生成器 ↓                                                         │
│   tools/gen_dart_define.dart               （把开发者 JSON 压缩   │
│        └── jsonDecode → jsonEncode(compact) → wrap as 映射）     │
│           输出 build/dart_define.json     （build/ 在 .gitignore） │
└─────────────────────────────────────────────────────────────────┘

测试运行路径：
  # 0. 生成 build/dart_define.json（必须，先生成再跑测试）
  dart run tools/gen_dart_define.dart \
    ~/.thktree/test_llm_config.json \
    build/dart_define.json

  flutter test integration_test/<file>.dart \
    --dart-define-from-file=build/dart_define.json \
    -d <device>
      ↓
  Simulator 进程跑测试代码（不是 host）
      ↓
  createTestApp() → ProviderScope(overrides: [...]) → ThkTreeApp
      ↓
  关键 override：llmConfigStoreProvider.overrideWithValue(InMemoryLlmConfigStore)
      ↓
  chat_controller.ref.read(llmConfigStoreProvider)  → 拿到假 Store
      ↓
  假 Store.readApiKey(id)  → 返回真 Key（来自 dart-define 注入）
      ↓
  LlmClient.forConfig(provider).streamChatCompletion(apiKey, model)
      ↓
  真发请求给 DeepSeek / OpenAI / ...
```

### 关键事实
1. **集成测试跑在 Simulator 进程**，不是 host 进程
2. **`lib/main_test.dart` 是唯一注入点**——生产路径 `lib/main.dart` 完全不引用它
3. **`chat_controller` 读 `llmConfigStoreProvider`**——不是 `appSettingsProvider`，单独 override 后者是死注入
4. **API Key 来自 `--dart-define-from-file` 编译期注入**（同步 `loadFromDefine()` 读 `String.fromEnvironment`），**不**打进 .app / .apk / .ipa bundle
5. **Key 不入仓**——配置文件放工程外（如 `~/.thktree/test_llm_config.json`），开发者友好的 pretty-print JSON 经 `tools/gen_dart_define.dart` 压缩为单行紧凑 JSON 后再注入
6. **不要直接把 `~/.thktree/test_llm_config.json` 喂给 `--dart-define-from-file`**——`--dart-define-from-file` 只接受 `{"KEY":"VALUE"}` 简单映射，且 value 不能含字面 `\n`，否则 `frontend_server` 报 URI 解析错

---

## 3. 目录约定

```
integration_test/
├── _support/                                    # ⭐ 辅助代码（被所有 test 共享）
│   ├── llm_test_config.dart                     # JSON → AppSettings/LlmConfigStore
│   ├── in_memory_llm_config_store.dart          # 假 Store（extends LlmConfigStore）
│   └── test_helpers.dart                        # UI 工具函数
├── chat_streaming_test.dart                     # 按"测试目标"命名
├── backup_restore_test.dart
├── branch_creation_test.dart
├── node_reorder_test.dart
├── offline_test.dart                            # Mock LLM（断网/重试）
├── llm_error_retry_test.dart            # LLM 错误态 + 重试（mock LLM）
└── theme_chat_e2e_test.dart
```

| 目录 | 作用 | 命名约定 |
|------|------|----------|
| `_support/` | 测试专用辅助代码（fixtures、helpers） | 不带 `_test.dart` 后缀，方便内部 import |
| `integration_test/*.dart` | 实际测试文件 | 必须 `_test.dart` 后缀，Flutter 框架要求 |

⚠️ **不要**把生产代码放到 `_support/` 里——它是测试专用，**会被打进 Simulator app bundle**。

---

## 4. 命名与文件结构

### 4.1 文件命名
- ✅ `xxx_test.dart`（Flutter 框架硬性要求）
- ❌ `xxx_integration_test.dart`（冗余，`integration_test/` 目录本身就是集成测试）

### 4.2 `group` / `testWidgets` 命名
```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('对话发送与流式回复测试', () {                  // 中文 group 名
    testWidgets('发送消息并等待流式回复', (tester) async {  // 中文测试名
      // ...
    });
  });
}
```

- ✅ `group` + `testWidgets` 都用中文（贴合产品用户视角）
- ✅ 每个 testWidgets 是独立的入口，可单独跑（`flutter test integration_test/foo.dart --plain-name "..."`）

### 4.3 helper 函数命名
- 顶层 helper（被多文件复用）→ 放进 `_support/test_helpers.dart`，命名 `xxxAndWait` / `waitForXxx`
- 文件内 helper（私有）→ 文件底部 `Future<void> _xxx(...) async { ... }`

---

## 5. ValueKey 约定 ⭐ 关键

集成测试要靠 `find.byKey(ValueKey('xxx'))` 定位 UI 元素，所以**生产 widget 必须给关键交互点加 ValueKey**。

### 5.1 命名规范

| 类型 | 命名 | 示例 |
|------|------|------|
| 导航栏按钮 | `<动词>_<对象>_button` | `add_theme_button`、`add_node_button` |
| 对话框输入框 | `<对象>_input` | `theme_title_input`、`node_title_input` |
| 对话框确认按钮 | `<对象>_create_button` | `theme_create_button`、`node_create_button` |
| 聊天控件 | `<对象>` | `chat_input`、`send_button`、`stop_button` |
| 节点列表 | `<对象>_list` | `node_list` |
| 拖拽把手 | `drag_handle_<nodeId>` | `drag_handle_node1`、`drag_handle_parent` |
| 底部 tab | 不用 ValueKey | 用 `find.text('主题').first` 定位 |

### 5.2 必须加 ValueKey 的清单
| Widget | Key | 文件 | 状态 |
|--------|-----|------|------|
| `theme_list_screen.dart` 导航栏 + 按钮 | `add_theme_button` | ✅ 已加 | `theme_chat_e2e` 依赖 |
| `theme_list_screen.dart` 创建 dialog 输入框 | `theme_title_input` | ✅ 已加 | 同上 |
| `theme_list_screen.dart` 创建 dialog 确认按钮 | `theme_create_button` | ✅ 已加 | 同上 |
| `theme_detail_screen.dart` 导航栏 + 按钮 | `add_node_button` | ✅ 已加 | 同上 |
| `theme_detail_screen.dart` 创建 dialog 输入框 | `node_title_input` | ✅ 已加 | 同上 |
| `theme_detail_screen.dart` 创建 dialog 确认按钮 | `node_create_button` | ✅ 已加 | 同上 |
| `chat_screen.dart` 输入框 | `chat_input` | ✅ 已存在 | 所有 chat 测试依赖 |
| `chat_screen.dart` 发送按钮 | `send_button` | ✅ 已存在 | 同上 |
| `chat_screen.dart` 停止按钮 | `stop_button` | ✅ 已存在 | 同上 |
| 节点拖拽把手 | `drag_handle_<nodeId>` | ⚠️ **待核实** | `node_reorder_test` 假设存在 |
| 节点列表 | `node_list` | ⚠️ **待核实** | `node_reorder_test` 假设存在 |
| 备份/恢复 入口 | - | ❌ 未加 | `backup_restore_test` 阻塞点 |
| 选中文本 ActionSheet | - | ❌ 未加 | `branch_creation_test` 阻塞点 |

⚠️ **测试代码假设了 Key 但生产 widget 可能没有**——这就是为什么 4 个 test 文件（chat_streaming / backup_restore / branch_creation / node_reorder）跑不通。

### 5.3 不加 ValueKey 的位置
- 纯展示型 Text widget（用 `find.text('xxx')` 即可）
- 列表项的标题（用 `find.descendant` + `find.text` 组合定位）
- 装饰性 icon

---

## 6. 真实 vs Mock LLM

### 当前策略：混合（真实 API + Mock）

- **真实 API 测试**：如 `theme_chat_e2e_test.dart`、`branch_creation_test.dart`，验证真链路（SSE、超时、真实厂商兼容性）
- **Mock 测试**：如 `offline_test.dart`，验证错误态/重试等 UI 与状态机，不依赖外部网络与真实 key

### 不验证回复内容

测试只验证：
- 消息数量（4 条 / 2 条）
- 按钮状态变化（`send_button` ↔ `stop_button`）
- 文本存在（`find.text('xxx')`）
- 流式期间/结束后 UI 稳定

**不验证** LLM 回复的具体文字内容（避免 flake）。

### Mock LLM（已落地）

`lib/main_test.dart` 的 `createTestApp()` 已支持 `extraOverrides`，因此可以在单个 test 文件里按需注入 Mock：

```dart
final app = await createTestApp(
  locale: const Locale('zh'),
  extraOverrides: [
    llmClientProvider.overrideWith((ref) async => const FakeLlmClient()),
    settingsStoreProvider.overrideWithValue(InMemorySettingsStore(fakeSettings)),
  ],
);
```

推荐用 Mock LLM 覆盖：
- 断网/超时等可重试错误（`DioExceptionType.connectionError` 等）
- 重试按钮/错误文案/按钮状态恢复
- 不希望 CI 依赖外网的场景

---

## 7. 运行命令

### 7.1 列出可用设备
```bash
flutter devices
```

### 7.2 跑单个测试文件

```bash
# 不依赖真实 API 的 mock 测试（例如 offline_test）不需要 --dart-define-from-file
flutter test integration_test/offline_test.dart

# 0. 先生成 build/dart_define.json（必须，把 ~/.thktree/test_llm_config.json 压缩为单行紧凑 JSON）
dart run tools/gen_dart_define.dart \
  ~/.thktree/test_llm_config.json \
  build/dart_define.json

# 1. 跑测试（必须带 --dart-define-from-file，否则 LlmTestConfig.loadFromDefine() 会抛 StateError）
flutter test integration_test/theme_chat_e2e_test.dart \
  --dart-define-from-file=build/dart_define.json \
  -d "<iOS Simulator>"
```

### 7.3 跑指定 testWidgets

```bash
flutter test integration_test/chat_streaming_test.dart \
  --dart-define-from-file=build/dart_define.json \
  --plain-name "发送消息并等待流式回复" \
  -d "<iOS Simulator>"
```

### 7.4 跑全部集成测试

```bash
flutter test integration_test/ \
  --dart-define-from-file=build/dart_define.json \
  -d "<iOS Simulator>"
```

### 7.5 跑 iOS 模拟器（推荐）
- 测试主题/节点/聊天等 UI 流程——必须用 iOS Simulator（不能在 host 上跑）
- 推荐 iPhone 15 Pro / iPhone 16 系列

### 7.6 跑 macOS 桌面端
```bash
# macOS 桌面端集成测试需要 network.client entitlement + MemStore
flutter test integration_test/desktop_theme_chat_e2e_test.dart \
  --dart-define-from-file=build/dart_define.json \
  -d macos
```
详见 [macos-desktop-e2e.md](./macos-desktop-e2e.md)。

### 7.6 配置 LLM Key

第一次跑前必须创建工程外 JSON 配置（**不放工程内**，避免 `.gitignore` 失误导致 Key 进 release 包），并经生成器压缩后注入：

```bash
# 1. 创建工程外配置目录（推荐 ~/.thktree/）
mkdir -p ~/.thktree

# 2. 创建配置文件并填入真实 Key（JSON 结构见 fixtures.md 第 2.1 节）
$EDITOR ~/.thktree/test_llm_config.json

# 3. 跑生成器：把 pretty-print JSON 压缩为单行紧凑 JSON（不能直接喂给 --dart-define-from-file）
dart run tools/gen_dart_define.dart \
  ~/.thktree/test_llm_config.json \
  build/dart_define.json

# 验证 JSON 合法
jq . ~/.thktree/test_llm_config.json
```

JSON 格式示例（参考 [fixtures.md 第 2.1 节](./fixtures.md#21-完整示例)）：

```json
{
  "activeProvider": "deepseek",
  "providers": {
    "deepseek": { "apiKey": "sk-xxx", "model": "deepseek-chat" },
    "openai":   { "apiKey": "",      "model": "" },
    "claude":   { "apiKey": "",      "model": "" },
    ...
  }
}
```

⚠️ **两个约束同时生效**才安全：① Key 配置文件放工程外（不入仓） ② 跑测试前必须经生成器压缩为 `build/dart_define.json` 再注入（不要直接把 `~/.thktree/test_llm_config.json` 喂给 `--dart-define-from-file`，含字面 `\n` 会触发 frontend_server URI 解析错）。

---

## 8. 调试技巧

### 8.1 加 dev.log / print
- **不要**用 `debugPrint`（integration_test 里可能不输出到 console）
- ✅ 用 `print('[your_test] xxx: $value')` 输出到 host 终端
- ✅ 用 `import 'dart:developer' as dev; dev.log(...)` 输出到 DevTools

### 8.2 超时排查
- 默认 `pumpAndSettleWithTimeout` / `waitForLLMResponse` 都是 30 秒
- 真 API 慢（特别是 deepseek 冷启动）→ 单轮 LLM 调用建议 90 秒
- `waitForWidget(stop_button, timeout: 10s)` 出现说明已进入流式
- `waitForWidget(send_button, timeout: 90s)` 出现说明流式结束

### 8.3 常见错误

| 现象 | 根因 | 解决 |
|------|------|------|
| 点发送 10s 后找不到 stop_button | 路径 B 拿到空 loadAll() 直接退出，路径 C Keychain 空 | 双注入：llmSettings + llmConfigStore（详见 [fixtures.md](./fixtures.md)） |
| `StateError: LLM test config not injected (TEST_LLM_CONFIG_JSON is empty)` | 跑测试没带 `--dart-define-from-file=...` | 先跑生成器，再用 `--dart-define-from-file=build/dart_define.json` |
| `FormatException: Invalid JSON` | JSON 格式错或字段缺失 | 用 `jq . ~/.thktree/test_llm_config.json` 验证（注意：错误信息不会带本地文件路径，Key 是从 dart-define 读出来的） |
| frontend_server `URI parse error` | 直接把 pretty-print JSON 喂给 `--dart-define-from-file`，含字面 `\n` 触发 URI 解析错 | 必须先跑 `tools/gen_dart_define.dart` 压缩为单行紧凑 JSON |
| `Unknown LlmProvider: xxx` | activeProvider 用了不在 enum 里的值 | 参考 [fixtures.md 第 6 节](./fixtures.md) |
| 超时但 UI 没动 | Riverpod state 没刷新 | 加 `await tester.pump(Duration(milliseconds: 500))` |
| macOS: 流式不开始（发送后 stop_button 不出现） | macOS Sandbox 缺 `network.client` entitlement，HTTP 出站被拦截 | 在 `macos/Runner/DebugProfile.entitlements` 加 `<key>com.apple.security.network.client</key><true/>` |
| macOS: Keychain 写失败（`PlatformException -34018`） | macOS Sandbox 无 Keychain Sharing entitlement | 集成测试用 `_MemStore` 替代 `FlutterSecureStorage`（见 [macos-desktop-e2e.md 第 4.2 节](./macos-desktop-e2e.md#42-内存安全存储)） |
| macOS: 创建后文字找不到（`waitForText` 超时） | `SliverList`/`ListView.separated` 懒加载，离屏 widget 未构建 | 用 `tester.scrollUntilVisible(find.text(...), 100, scrollable: find.byType(Scrollable).first)` |
| macOS: 发送按钮 tap/send 后无反应 | CupertinoTextField multiline 不响应 `receiveAction(send)` | 用 `tester.sendKeyEvent(LogicalKeyboardKey.enter)` |
| macOS: 默认模型不对（显示 gpt-4o 而不是 DeepSeek/Kimi） | `SettingsController` 读 `settingsStoreProvider`，空 store 返回空 `AppSettings` → 降级到第一个 provider | 预填 `settingsStoreProvider` 的 keys（`chat_default_provider_id`/`chat_default_model_id`），见 [macos-desktop-e2e.md 第 4.2 节](./macos-desktop-e2e.md#42-内存安全存储) |

### 8.4 抓取日志
- iOS Simulator 日志：`flutter logs`（开新终端跑）
- DevTools：`flutter run --profile` → 浏览器打开提示的 URL

---

## 9. 新增测试 Checklist

按这 8 步走：

- [ ] **1. 选模块** — 确认要测的功能在哪个模块（chat / themes / llm / settings 等）
- [ ] **2. 写场景** — 用"操作 → 期望"两列表格描述（如 [theme-chat-e2e 第 2 节](./theme-chat-e2e.md#2-场景表)）
- [ ] **3. 补 ValueKey** — 列出所有 `find.byKey(ValueKey('xxx'))` 需要的 Key，检查生产 widget 是否已加；缺的补上
- [ ] **4. 用 helpers** — 优先复用 `_support/test_helpers.dart` 的工具，避免重复
- [ ] **5. 选 fixtures** — 涉及 LLM 调用时用 `LlmTestConfig.loadFromDefine()`（读 `--dart-define-from-file` 注入的编译期常量）
- [ ] **6. 加文档** — 在 `_shared/integration-testing/<场景>.md` 写一份 spec（参照已有 5 个）
- [ ] **7. 跑通** — `flutter test integration_test/<file>.dart -d "<iOS Simulator>"`
- [ ] **8. 更新本 README 速览表** — 在 第 10 节 加一行

---

## 10. 测试文件清单

### 10.1 移动端（iOS，共 10 个可跑通）

| 文件 | 场景 | 状态 | Spec |
|------|------|------|------|
| `theme_chat_e2e_test.dart` | 主题 → 节点 → 聊天 2 round 完整链路 | ✅ | [theme-chat-e2e.md](./theme-chat-e2e.md) |
| `note_crud_test.dart` | 笔记 CRUD 生命周期（创建/编辑/重命名/持久化/删除） | ✅ | [note-crud.md](./note-crud.md) |
| `llm_error_retry_test.dart` | LLM 错误态展示 / 重试触发 / 上报 / cancelled / i18n | ✅ | —（mock，内嵌场景表） |
| `chat_async_recovery_test.dart` | 后台中断恢复：find/resume/cancel/bridge 配对 | ✅ | [chat-async-recovery.md](./chat-async-recovery.md) |
| `branch_creation_test.dart` | 4 种分支模式：empty / 原始上下文 / 总结 / bookmark | ⚠️ | [branch-creation.md](./branch-creation.md) |
| `node_reorder_test.dart` | 同层重排 / 跨层禁止 / 刷新保持 | ⚠️ | [node-reorder.md](./node-reorder.md) |
| `chat_streaming_test.dart` | 流式发送 / 空消息拦截 / 快速连续发送 | ❌ | [chat-streaming.md](./chat-streaming.md) |
| `backup_restore_test.dart` | 备份恢复往返 / 文件格式 / 冲突 / 覆盖 | ❌ | [backup-restore.md](./backup-restore.md) |
| `offline_test.dart` | Mock LLM 断网/超时/重试 | ✅ | —（内嵌） |
| `search_test.dart` | 全文搜索 CRUD + 排序 | ✅ | — |

### 10.2 移动端（iOS，共 9 个无专门 spec 的专项测试）

| 文件 | 场景 | 状态 |
|------|------|------|
| `chat_latex_overflow_test.dart` | LaTeX 公式溢出修复验证 | ✅ |
| `chat_breadcrumb_test.dart` | 聊天面包屑导航 | ✅ |
| `keyword_ranking_test.dart` | Lab → 关键词排行 | ✅ |
| `lab_tab_test.dart` | Lab 页面 tab 切换 + 独立入口 | ✅ |
| `note_title_required_test.dart` | 笔记标题必填校验 | ✅ |
| `note_to_chat_test.dart` | 笔记转对话 | ✅ |
| `note_search_test.dart` | 笔记搜索 | ✅ |
| `topic_library_tree_note_test.dart` | 搜狗话题库 → 树 → 笔记全链路 | ✅ |
| `search_settings_button_test.dart` | 搜索页设置按钮 tap → 设置页 | ✅ |

### 10.3 macOS 桌面端

**已写且验证通过（4 个）：**

| 文件 | 场景 | 状态 | Spec |
|------|------|------|------|
| `desktop_theme_chat_e2e_test.dart` | 侧栏 → 三栏展开 → 主题 → 节点 → 聊天 2 round | ✅ | [macos-desktop-e2e.md](./macos-desktop-e2e.md) |
| `desktop_shell_smoke_test.dart` | 桌面壳渲染冒烟（sidebar + 内容区） | ✅ | — |
| `desktop_sidebar_nav_test.dart` | 侧栏四个入口切换（搜索/主题/笔记/Lab） | ✅ | — |
| `desktop_comprehensive_e2e_test.dart` | 3主题×3层 + 分支模式 + 图片 + 合并 + 排序 + 分享 | 🔧 骨架 | — |

**iOS 测试已复制到 macOS worktree 但未验证（20 个）：**

| 文件 | 需适配的点 |
|------|-----------|
| `theme_chat_e2e_test.dart` | 导航入口：底部 tab → 侧栏 `sidebar_item_1` |
| `note_crud_test.dart` | 笔记入口从导航栈 push → NotesWorkspace 两栏 |
| `llm_error_retry_test.dart` | LLM 路径一致，需在 macOS 运行确认 |
| `chat_async_recovery_test.dart` | 恢复逻辑一致，需验证 |
| `branch_creation_test.dart` | 分支入口走 GestureDetector 而非 ActionSheet |
| `node_reorder_test.dart` | 拖拽行为一致，需验证 |
| `offline_test.dart` | Mock LLM 一致，需验证 |
| `search_test.dart` | 搜索走桌面 SearchWorkspace，需调整 |
| `chat_latex_overflow_test.dart` | 渲染一致，需验证 |
| `chat_breadcrumb_test.dart` | 面包屑导航一致，需验证 |
| `keyword_ranking_test.dart` | Lab 页一致，需验证 |
| `lab_tab_test.dart` | Lab 页一致，需验证 |
| `chat_streaming_test.dart` | 同上 |
| `backup_restore_test.dart` | 同上 |
| `note_title_required_test.dart` | 同上 |
| `note_to_chat_test.dart` | 同上 |
| `note_search_test.dart` | 同上 |
| `topic_library_tree_note_test.dart` | 同上 |
| `search_settings_button_test.dart` | 同上 |

**macOS 专属交互有待开发测试（0/10）：**

| 待开发 | 场景 |
|--------|------|
| `desktop_context_menu_test.dart` | 右键菜单（节点更多操作） |
| `desktop_shortcut_test.dart` | 快捷键：Cmd+N / Cmd+Enter / Cmd+, / Cmd+F / Cmd+B / Cmd+S |
| `desktop_hover_test.dart` | 鼠标 hover 效果 |
| `desktop_menu_bar_test.dart` | 原生菜单栏（ThkTree → 设置/关于/退出，文件 → 新建） |
| `desktop_image_picker_test.dart` | File picker 选图片 + 聊天发送 |
| `desktop_window_resize_test.dart` | 窗口缩放 → PaneScaffold breakpoint 切换 |
| `desktop_pane_drag_resize_test.dart` | 拖动分隔条调整三栏宽度 |
| `desktop_share_export_test.dart` | 分享导出（Markdown 复制 / 图片保存） |
| `desktop_dark_mode_test.dart` | 外观：浅色 / 深色 / 跟随系统 |
| `desktop_model_switch_test.dart` | 聊天中切换模型 + 模型面板交互 |

### 10.4 Support 文件

| 文件 | 作用 |
|------|------|
| `test_helpers.dart` | UI 工具函数（`waitForText` / `waitForWidget` / `_createXxx`） |
| `_support/llm_test_config.dart` | LLM 配置解析 + `toAppSettings()` / `toLlmConfigStore()` |
| `_support/in_memory_llm_config_store.dart` | 假 LlmConfigStore（API Key 从 Map 读） |
| `_support/step_timer.dart` | 步骤计时代理 |
| `_support/search_fixtures.dart` | 搜索测试 fixtures |
| `_support/failing_search_service.dart` | Mock 搜索服务 |
| `_support/topic_library.dart` | 话题库测试数据 |
| `_support/topic_llm_client.dart` | 话题库 Mock LLM |

**状态图例**：✅ 完整可跑通 | ⚠️ 部分实现 | ❌ TODO/占位 | 🔧 骨架/开发中

---

## 11. 相关文档索引

| 文档 | 作用 |
|------|------|
| [fixtures.md](./fixtures.md) | LLM 配置 fixtures 详解（JSON 格式、InMemoryLlmConfigStore、Provider ID 映射） |
| [helpers.md](./helpers.md) | test_helpers.dart 工具函数清单 |
| [llm-injection.md](./llm-injection.md) | LLM 注入导航版（详细版在 modules/llm/specs/） |
| [chat-streaming.md](./chat-streaming.md) | 对话流式测试 spec |
| [theme-chat-e2e.md](./theme-chat-e2e.md) | 主题→节点→聊天 E2E 测试 spec |
| [backup-restore.md](./backup-restore.md) | 备份恢复测试 spec |
| [branch-creation.md](./branch-creation.md) | 分支创建测试 spec |
| [node-reorder.md](./node-reorder.md) | 节点拖拽测试 spec |
| [note-crud.md](./note-crud.md) | 笔记 CRUD 集成测试 spec |
| [macos-desktop-e2e.md](./macos-desktop-e2e.md) | macOS 桌面端 E2E 测试 spec（7 个 macOS 专属 bug 修复记录） |
| [docs/modules/llm/specs/integration-test-llm-injection.md](../../modules/llm/specs/integration-test-llm-injection.md) | LLM 注入原理详细版（208 行） |
| [lib/main_test.dart](../../../lib/main_test.dart) | 唯一 ProviderScope 注入点 |

---

## 12. 相关历史

- 2026-05：集成测试起步（chat_streaming_test.dart 雏形）
- 2026-06：theme_chat_e2e_test.dart 跑通，建立 LLM 注入机制（双层：llmSettings + llmConfigStore）
- 2026-06：LLM 注入原理文档化（`docs/modules/llm/specs/integration-test-llm-injection.md`）
- 2026-06：集成测试文档体系建立（本 README + 7 个 spec）
- 2026-06-20：**LLM Key 注入机制迁移** — 从 `assets/test_llm_config/test_llm_config.json`（含真 Key 进 bundle 风险）迁移到 `--dart-define-from-file` 编译期常量注入（Key 不进 .app / .apk / .ipa bundle）；新增 `tools/gen_dart_define.dart` 生成器（压缩 pretty-print JSON 为单行紧凑 JSON），详见 [docs/_tmp/2026-06-20-llm-test-config-redesign.md](../../_tmp/2026-06-20-llm-test-config-redesign.md) + [docs/CHANGELOG/2026-06-20-llm-test-config-redesign.md](../../CHANGELOG/2026-06-20-llm-test-config-redesign.md)

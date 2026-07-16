# 主题 → 节点 → 聊天 E2E 测试（theme_chat_e2e_test.dart）

> **文件**：[`integration_test/theme_chat_e2e_test.dart`](../../../integration_test/theme_chat_e2e_test.dart)（291 行，1 个 testWidgets）  
> **状态**：✅ **完整可跑通** — 唯一跑通的集成测试  
> **草稿来源**：[docs/_tmp/theme_chat_e2e_test.md](../../_tmp/theme_chat_e2e_test.md)（已吸收，本文档落地后删除草稿）

---

## 1. 目标

验证 ThkTree 核心用户路径的完整链路：

```
启动 App → 主题列表 → 创建主题 → 进入主题 → 创建节点 → 进入聊天 → 发消息 → 流式回复
```

任何一步出错都能在 CI 早期发现，是端到端"健康检查"性质的测试。

---

## 2. 场景表

| 步骤 | 操作 | 期望 | 涉及 ValueKey |
|------|------|------|---------------|
| 1 | 启动 App（zh locale + LLM 注入） | 落到 `/search` 页（initialLocation） | - |
| 2 | 切换底部 tab 到"主题" | 主题列表页加载 | - |
| 3 | 点 + 按钮创建主题 | 弹 dialog | `add_theme_button` |
| 4 | 输入主题名（带时间戳后缀）→ 点"创建" | 主题出现在列表 | `theme_title_input` / `theme_create_button` |
| 5 | 点新主题 | 进入主题详情 | - |
| 6 | 点 + 按钮创建节点 | 弹 dialog | `add_node_button` |
| 7 | 输入节点名 → 点"创建" | 节点出现在树 | `node_title_input` / `node_create_button` |
| 8 | 点节点 | 进入聊天页 | - |
| 9 | Round 1：发"请用一句话介绍你自己" | 流式 → `stop_button` 出现 → `send_button` 出现 | `chat_input` / `send_button` / `stop_button` |
| 10 | Round 2：发"请讲一个简短的冷笑话" | 流式 → `stop_button` 出现 → `send_button` 出现 | 同上 |
| 11 | 断言 | 2 user + 2 assistant 消息，assistant body 非空，`send_button` 恢复 | - |

---

## 3. LLM 接入策略

| 维度 | 决策 | 理由 |
|------|------|------|
| API 来源 | **真实 API**（不 mock） | 测真链路，能抓 SSE 解析、超时、重连等真实问题 |
| 配置来源 | `--dart-define-from-file` 注入 `TEST_LLM_CONFIG_JSON` 编译期常量 | Key 不进 bundle，从根上消除 release 包泄露 Key 的可能（详见 [fixtures.md 第 1 节](./fixtures.md#1-为什么用-asset-而不是-host-文件) 历史背景） |
| 厂商/模型 | 用 JSON 配的 `activeProvider`（默认 deepseek） | 用户可切换厂商验证多厂商兼容性 |
| 单轮超时 | **90 秒** | 真 API 冷启动慢，普通 round 30s 内完成，留 buffer |
| 整体超时 | **5 分钟**（`Timeout(Duration(minutes: 5))`） | 2 round + 准备 + 收尾 |
| 回复内容验证 | ❌ 不验证 | 避免 flake（LLM 回复不稳定） |
| 测试数据清理 | ❌ 不清理 | 主题/节点名带时间戳后缀避免冲突；不删数据方便人工排查 |

---

## 4. 改动清单

为了让这个测试跑通，需要 4 处代码改动（已全部完成）：

### 4.1 改动 1：`lib/main_test.dart` — 加中文 locale 注入 + 双注入

```dart
Future<Widget> createTestApp({
  Locale? locale,
  AppSettings? llmSettings,
  LlmConfigStore? llmConfigStore,
}) async {
  // 默认 zh（中文），可被参数覆盖
  final initialLocale = locale ?? const Locale('zh');
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

### 4.2 改动 2：`lib/ui/features/themes/theme_list_screen.dart` — 补 ValueKey

| Key | 位置 |
|-----|------|
| `add_theme_button` | 导航栏 trailing `+` 按钮 |
| `theme_title_input` | 创建主题对话框 `CupertinoTextField` |
| `theme_create_button` | 创建主题对话框"创建"按钮 |

### 4.3 改动 3：`lib/ui/features/themes/theme_detail_screen.dart` — 补 ValueKey

| Key | 位置 |
|-----|------|
| `add_node_button` | 导航栏 trailing `+` 按钮 |
| `node_title_input` | 创建节点对话框 `CupertinoTextField` |
| `node_create_button` | 创建节点对话框"创建"按钮 |

### 4.4 改动 4：`integration_test/theme_chat_e2e_test.dart`（新建）

完整 E2E 流程（详见源码）。

---

## 5. ValueKey 清单（关键约定）

| Key | 文件 | 状态 | 依赖的测试 |
|-----|------|------|------------|
| `add_theme_button` | `theme_list_screen.dart` | ✅ 已加 | theme-chat-e2e |
| `theme_title_input` | `theme_list_screen.dart` | ✅ 已加 | theme-chat-e2e |
| `theme_create_button` | `theme_list_screen.dart` | ✅ 已加 | theme-chat-e2e |
| `add_node_button` | `theme_detail_screen.dart` | ✅ 已加 | theme-chat-e2e |
| `node_title_input` | `theme_detail_screen.dart` | ✅ 已加 | theme-chat-e2e |
| `node_create_button` | `theme_detail_screen.dart` | ✅ 已加 | theme-chat-e2e |
| `chat_input` | `chat_screen.dart` | ✅ 已存在 | 所有 chat 测试 |
| `send_button` | `chat_screen.dart` | ✅ 已存在 | 所有 chat 测试 |
| `stop_button` | `chat_screen.dart` | ✅ 已存在 | 所有 chat 测试 |

完整 ValueKey 约定见 [README.md 第 5 节](./README.md#5-valuekey-约定-关键)。

---

## 6. 测试步骤详解（结合源码）

### 6.1 加载 LLM 配置（文件顶部）

```dart
// integration_test/theme_chat_e2e_test.dart:33-35
// Key 来自 --dart-define-from-file 注入的 TEST_LLM_CONFIG_JSON 编译期常量。
final llmConfig = LlmTestConfig.loadFromDefine();
```

放在 `main()` 顶层（不在 testWidgets 内）——让 3 次加载复用同一份配置，避免每个 testWidgets 都重新读 asset。

### 6.2 启动 App + 双注入（第 50-54 行）

```dart
final app = await createTestApp(
  locale: const Locale('zh'),
  llmSettings: llmConfig.toAppSettings(),
  llmConfigStore: llmConfig.toLlmConfigStore(),
);
```

**关键**：`llmConfigStore` 必须传，否则 chat_controller 路径 B 拿不到 Key。详见 [fixtures.md 第 4 节](./fixtures.md#4-toappsettings-vs-tollmconfigstore-双注入)。

### 6.3 时间戳后缀避免冲突（第 59-61 行）

```dart
final ts = DateTime.now().millisecondsSinceEpoch;
final themeTitle = 'Intg主题_$ts';
final nodeTitle = 'Intg讨论_$ts';
```

✅ 优点：重复运行不冲突，CI 历史里能区分多次运行产生的数据  
❌ 缺点：测试数据会累积（已知问题，详见第 10 节）

### 6.4 切换底部 tab（第 65-66 行）

```dart
await _switchToTab(tester, '主题');
await tester.pumpAndSettle();
```

App 默认进 `/search` 页（参见 `router.dart initialLocation`），需要切到底部"主题"tab。

### 6.5 创建主题（第 71-75 行）

```dart
await _createTheme(tester, themeTitle);
await waitForText(tester, themeTitle, timeout: const Duration(seconds: 10));
expect(find.text(themeTitle), findsOneWidget, reason: '新主题应出现在列表中');
```

`waitForText` 等待异步创建完成 + 列表刷新（最多 10s）。

### 6.6 进入主题详情（第 80-89 行）

```dart
await tester.tap(find.text(themeTitle));
await tester.pumpAndSettle();

expect(
  find.byKey(const ValueKey('add_node_button')),
  findsOneWidget,
  reason: '进入主题详情后应能看到 + 按钮',
);
```

**新建主题的节点树是空的**，不一定有 `node_list` Key，但导航栏 + 按钮一定存在。

### 6.7 创建节点（第 94-98 行）

```dart
await _createNode(tester, nodeTitle);
await waitForText(tester, nodeTitle, timeout: const Duration(seconds: 10));
expect(find.text(nodeTitle), findsOneWidget, reason: '新节点应出现在树中');
```

节点列表用 `_TreeRowView` 自定义渲染，需要 `waitForText` 等名字出现。

### 6.8 进入聊天页（第 103-111 行）

```dart
await tester.tap(find.text(nodeTitle));
await tester.pumpAndSettle();

expect(
  find.byKey(const ValueKey('chat_input')),
  findsOneWidget,
  reason: '进入聊天页后应能看到输入框',
);
```

### 6.9 Round 1/2 发消息（第 126-141 行）

```dart
await _sendAndWaitForReply(
  tester,
  message: '请用一句话介绍你自己',
  timeout: const Duration(seconds: 90),
);
timer.step('Round 1 发消息等回复');

await _sendAndWaitForReply(
  tester,
  message: '请讲一个简短的冷笑话',
  timeout: const Duration(seconds: 90),
);
timer.step('Round 2 发消息等回复');
```

`_sendAndWaitForReply` 是文件内私有 helper（line 245-270），逻辑：
1. 输入消息
2. 点 `send_button`（流式开始前一定存在）
3. **手动轮询等待 `stop_button` 出现（10s 内）** → 流式已启动
4. 等待 `send_button` 回来（90s 内） → 流式已结束

**错误检测机制**（2026-06-22 新增）：步骤 3 改为手动轮询（`while` + `pump(500ms)`），替代原先的 `waitForWidget`。超时前先检查界面是否出现错误信息（通过 `_extractScreenError` 提取 `Exception` / `Error` / `SocketException` / `DioException` 文本），避免 API 报错时傻等 10s 超时。

```dart
// 核心逻辑（简化）
final sw = Stopwatch()..start();
while (stopFinder.evaluate().isEmpty) {
  if (sw.elapsed > Duration(seconds: 10)) {
    final errorText = _extractScreenError(tester);
    if (errorText != null) fail('LLM 调用失败: $errorText');
    fail('发送消息后 10s 内未进入流式状态');
  }
  await tester.pump(Duration(milliseconds: 500));
}
```

`_extractScreenError` 扫描界面所有 `Text` widget，匹配 `Exception` / `Error` / `SocketException` / `DioException` 关键词。匹配到时直接 `fail()`，错误信息包含原始异常文本，便于定位。

### 6.10 断言（第 136-152 行）

```dart
expect(
  find.text('请用一句话介绍你自己'),
  findsWidgets,
  reason: 'Round 1 用户消息应在聊天列表中',
);
expect(
  find.text('请讲一个简短的冷笑话'),
  findsWidgets,
  reason: 'Round 2 用户消息应在聊天列表中',
);

expect(
  find.byKey(const ValueKey('send_button')),
  findsOneWidget,
  reason: '第二轮结束后，发送按钮应恢复',
);
```

---

### 6.11 StepTimer 步骤耗时打点

每个关键步骤后调用 `timer.step('步骤名')`，测试结束调用 `timer.finish()` 打印总耗时。

打点位置（共 9 个 step）：

| 步骤 | 打点名 | 作用 |
|------|--------|------|
| 启动 App + 注入后 | `启动 App + 注入` | measure createTestApp + pump |
| 切 tab 后 | `切换底部 tab 到"主题"` | measure tab 切换 |
| 创建主题后 | `创建主题` | measure 主题创建 + 列表刷新 |
| 进入主题详情后 | `进入主题详情` | measure 导航 + 页面加载 |
| 创建节点后 | `创建节点` | measure 节点创建 + 树刷新 |
| 进入聊天页后 | `进入聊天页` | measure 导航 + 页面加载 |
| Round 1 结束后 | `Round 1 发消息等回复` | measure 发消息 + LLM 流式（通常最慢） |
| Round 2 结束后 | `Round 2 发消息等回复` | measure 发消息 + LLM 流式 |
| 断言完成后 | `最终断言` | measure 断言逻辑 |

输出会出现在 CI 日志中，用于性能回归检测和瓶颈定位。详见 [helpers.md 第 10 节](./helpers.md#10-_support-工具steptimer-步骤耗时统计)。

---

## 7. 文件内私有 helpers

文件底部定义了 5 个 helper（line 245-291），**只在本文件内可用**：

| Helper | 作用 | 提升建议 |
|--------|------|----------|
| `_switchToTab(tester, label)` | 点底部 tab 栏 | ✅ 应提到 `_support/` |
| `_createTheme(tester, title)` | 点 + → 弹 dialog → 输入 → 创建主题 | ✅ 应提到 `_support/` |
| `_createNode(tester, title)` | 点 + → 弹 dialog → 输入 → 创建节点 | ✅ 应提到 `_support/` |
| `_sendAndWaitForReply(tester, message, timeout)` | 发消息 + 轮询等流式结束 + 错误检测 | ✅ 应提到 `_support/` |
| `_extractScreenError(tester)` | 扫描界面 Text 提取异常信息（`Exception` / `SocketException` 等） | ✅ 应提到 `_support/` |
| `StepTimer`（`_support/step_timer.dart`） | 步骤级耗时统计（已独立为 `_support/` 文件） | ✅ 已在 `_support/` |

**未来改进**：这些 helper 在其他测试（chat_streaming / backup_restore / branch_creation）也要用，建议提到 `_support/test_helpers.dart` 或新建 `_support/test_fixtures.dart`。详见 [helpers.md 第 8.3 节](./helpers.md#83-业务方法分散)。

---

## 8. 执行命令

```bash
# 1. 启动 iOS Simulator
open -a Simulator

# 2. 创建 Key 配置文件（首次；推荐放 ~/.thktree/，不入仓）
mkdir -p ~/.thktree
$EDITOR ~/.thktree/test_llm_config.json
# 填入真 Key（JSON 结构参考 docs/_tmp/2026-06-20-llm-test-config-redesign.md 第 7 节）

# 3. 经生成器压缩为 build/dart_define.json（不能在 dart-define value 里留字面 \n）
dart run tools/gen_dart_define.dart \
  $HOME/.thktree/test_llm_config.json \
  build/dart_define.json

# 4. 跑测试
flutter test integration_test/theme_chat_e2e_test.dart \
  --dart-define-from-file=build/dart_define.json \
  -d "iPhone 15 Pro"
```

---

## 9. 完成状态

- ✅ 改动 1：`main_test.dart` 加 `locale` 参数 + 双注入
- ✅ 改动 2：`theme_list_screen.dart` 补 3 个 ValueKey
- ✅ 改动 3：`theme_detail_screen.dart` 补 3 个 ValueKey
- ✅ 改动 4：`theme_chat_e2e_test.dart` 新建（291 行）
- ✅ iOS 模拟器跑通
- ✅ 2026-06-20：`loadFromAsset` → `loadFromDefine`（dart-define 编译期注入）
- ✅ 2026-06-22：加入 `StepTimer` 步骤耗时统计 + `_sendAndWaitForReply` 错误检测（`_extractScreenError`）

---

## 10. 已知问题

### 10.1 测试数据累积

主题/节点带时间戳后缀，**不清理数据**——重复运行 N 次会累积 N 个主题。

**缓解**：
- 时间戳后缀 ms 精度，1ms 内连跑 2 次才会冲突
- 主题名以 `Intg` 开头便于人工识别和批量删除

**未来优化**：测试结束 `tearDown` 里删除本次创建的主题/节点。

### 10.2 真 API 不稳定

LLM 服务偶尔 5xx / 超时，测试可能 flake。

**缓解**：
- 90s 超时覆盖大部分情况
- 不验证回复内容（避免 flake）
- CI 失败时人工重跑

**未来优化**：增加 retry 机制（失败自动重试 1 次）。

### 10.3 冷启动慢

第一次发消息 deepseek 冷启动可能 30s+，刚好压在 90s 超时边缘。

**缓解**：超时尚未触发就先看日志分析；触发后考虑 120s 超时。

---

## 11. 改进建议

1. **共享 helper 到 `_support/`**：让其他测试复用（详见第 7 节）
2. **tearDown 清理数据**：避免累积
3. **retry 机制**：flake 时自动重试 1 次
4. **参数化厂商**：用 `@Tags(['deepseek'])` / `@Tags(['openai'])` 跑多厂商矩阵

---

## 12. 相关文档

- [README.md](./README.md) — 总论
- [fixtures.md](./fixtures.md) — LLM 注入详解
- [helpers.md](./helpers.md) — 工具函数
- [chat-streaming.md](./chat-streaming.md) — 兄弟测试（流式边界用例）
- [branch-creation.md](./branch-creation.md) — 兄弟测试（分支创建）
- [lib/ui/features/themes/theme_list_screen.dart](../../../lib/ui/features/themes/theme_list_screen.dart) — ValueKey 核实
- [lib/ui/features/themes/theme_detail_screen.dart](../../../lib/ui/features/themes/theme_detail_screen.dart) — ValueKey 核实
- [lib/ui/features/chat/chat_screen.dart](../../../lib/ui/features/chat/chat_screen.dart) — 聊天页 widget
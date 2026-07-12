# macOS 桌面端 E2E 测试（desktop_theme_chat_e2e_test.dart）

> **文件**：[`integration_test/desktop_theme_chat_e2e_test.dart`](../../../integration_test/desktop_theme_chat_e2e_test.dart)（~120 行，1 个 testWidgets）  
> **平台**：macOS 桌面（`-d macos`）  
> **状态**：✅ **完整可跑通** — UI 全链路 + LLM 流式回复  
> **对应 iOS 版**：[theme-chat-e2e.md](./theme-chat-e2e.md)

---

## 1. 与 iOS 版的关键差异

本测试从 `theme_chat_e2e_test.dart` 派生，针对 macOS 桌面端（多栏布局 + Sandbox）做了适配：

| 维度 | iOS 版 | macOS 桌面版 |
|------|--------|-------------|
| 导航入口 | 底部 tab `find.text('主题')` | 侧栏 `sidebar_item_1` |
| 布局 | 单栏 push 导航 | 三栏展开（PaneScaffold 280+320+flex） |
| 安全存储 | iOS Keychain（Simulator 可用） | macOS Sandbox Keychain **不可用** → `_MemStore` 替代 |
| 网络权限 | 自动拥有 | 需显式加 `com.apple.security.network.client` |
| 列表渲染 | `SliverList` 离屏懒加载 | 同 iOS，需 `scrollUntilVisible` |
| 键盘发送 | `receiveAction(send)` | `sendKeyEvent(Enter)`（multiline 不响应 send action） |
| 模型配置 | `appSettingsProvider` 覆盖 | 额外需 `settingsStoreProvider` 预填（SettingsController 读 store 不读 appSettingsProvider） |

---

## 2. 场景表

| 步骤 | 操作 | 期望 | macOS 特有 |
|------|------|------|-----------|
| 1 | 启动 App（zh + DeepSeek/Kimi + MemStore） | 落在搜索工作区（`/search`） | `_MemStore` 预填 `chat_default_provider_id` |
| 2 | 点侧栏"主题"（`sidebar_item_1`） | 主题列表加载，三栏展开 | `PaneScaffold` breakpoint=800，960px 内容区不会折叠 |
| 3 | 创建主题 | 弹 dialog，输入 → 创建 | 同 iOS |
| 4 | `scrollUntilVisible` 定位新主题 | 列表滚动到新建主题 | `SliverList` 懒加载，离屏 widget 不被 `find.text` 找到 |
| 5 | 点新主题行 → 等 `add_node_button` | 中间栏展示 ThemeDetailScreen | 需 `tapAt(getCenter(...))` 或 `warnIfMissed: false` 避免 hit test 失败 |
| 6 | 创建节点 | 同 iOS，创建成功后 `scrollUntilVisible` | `ListView.separated` 也是懒加载 |
| 7 | 点节点 → 等 `chat_input` | 右栏展示 ChatScreen | 三栏布局中右栏宽度 358px，组件正常渲染 |
| 8 | Round 1：输入文本 → Enter 发送 | 流式 → `stop_button` → `send_button` | `sendKeyEvent(Enter)` 触发 `_send()` |
| 9 | Round 2：发冷笑话 | 同上 | 短回复可能 pump 间隙完成，需同时检测 `stop_button` 和 `send_button` |

---

## 3. 修复清单

跑通这个测试共修复 7 个 macOS 专属 bug：

| # | 问题 | 根因 | 修复 |
|---|------|------|------|
| 1 | 三栏折叠不展开 | PaneScaffold breakpoint=1100 > 内容区 960px | breakpoint → 800 |
| 2 | Row 溢出 16px | 分隔条含 8px hit area，`used` 计算用 1px | `used` 累加真实宽度 |
| 3 | 默认模型选错（gpt-4o） | `SettingsStore.load()` 返回空，降级到第一个 provider | 预填 `chat_default_provider_id/model_id` |
| 4 | 发送不触发 | `receiveAction(send)` 不匹配 multiline CupertinoTextField | `sendKeyEvent(Enter)` |
| 5 | 创建后文字找不到 | `SliverList`/`ListView.separated` 懒加载 | `scrollUntilVisible` |
| 6 | 流式不返回 | macOS Sandbox 缺 `network.client` | 加 entitlement |
| 7 | dispose 时 UnmountedRefException | Riverpod provider 已释放但还在微任务中访问 | try/catch |

---

## 4. macOS 特有配置

### 4.1 entitlements

```xml
<key>com.apple.security.network.client</key>
<true/>
```

### 4.2 内存安全存储

```dart
class _MemStore extends FlutterSecureStorage {
  _MemStore([Map<String, String> initial = const {}]) : _s = Map.from(initial);
  // 实现 FlutterSecureStorage 接口，但数据存内存 Map
}
```

预填示例：
```dart
final store = _MemStore({
  'chat_default_provider_id': 'preset_kimi',
  'chat_default_model_id': 'moonshot-v1-8k',
  'last_used_chat_provider_id': 'preset_kimi',
  'last_used_chat_model_id': 'moonshot-v1-8k',
});
```

### 4.3 窗口尺寸

macOS 集成测试中窗口设为 1500×970（`MainFlutterWindow.swift`），侧栏 220px，内容区约 1280px。PaneScaffold breakpoint=800，三栏展开（280+320+flex）。

### 4.4 滚动查找

macOS 桌面端主题列表和节点树都使用懒加载列表，新建项在末尾不可见时必须 `scrollUntilVisible`：

```dart
await tester.scrollUntilVisible(
  find.text(title),
  100,
  scrollable: find.byType(Scrollable).first,
);
```

### 4.5 键盘发送

CupertinoTextField multiline 模式的 `textInputAction` 默认为 `newline`，`receiveAction(send)` 不触发。需用 `sendKeyEvent(Enter)` 模拟物理键盘：

```dart
await tester.sendKeyEvent(LogicalKeyboardKey.enter);
```

---

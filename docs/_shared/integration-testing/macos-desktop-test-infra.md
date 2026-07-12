# macOS 桌面端可复用集成测试基础设施

> **目标**：建立一套 composable、reusable 的 macOS 桌面端集成测试工具库，使每个测试 case 可以组合多个 helper 模块，不重复造轮子。

---

## 1. 架构概览

```
┌─────────────────────────────────────────────────────────────────────┐
│  Test Scripts（测试用例）                                            │
│  desktop_comprehensive_e2e_test.dart                                │
│  desktop_shortcut_test.dart                                         │
│  desktop_context_menu_test.dart        ... etc                      │
│                                                                     │
│  ← 组合调用                                                         │
│                                                                     │
│  Scenario Helpers（场景级）                                          │
│  createThemeWithNodes()     createBranchWithMode()   mergeNodes()   │
│  reorderAtLevel()           shareAsImage()          sendImageMsg() │
│                                                                     │
│  ← 组合调用                                                         │
│                                                                     │
│  Domain Helpers（业务级）                                            │
│  createTheme()   selectTheme()   createNode()    selectNode()       │
│  sendMessage()   waitForReply()  switchModel()   pickImage()        │
│  createBranch()   mergeChats()   dragToReorder()  shareExport()    │
│                                                                     │
│  ← 调用                                                             │
│                                                                     │
│  Primitive Helpers（基础级）                                         │
│  tapByKey()   enterTextByKey()  scrollToText()   waitForKey()      │
│  sendShortcut()  rightClick()   hoverWidget()   assertExists()     │
│                                                                     │
│  ← 依赖                                                             │
│                                                                     │
│  Fixtures（测试数据）                                                 │
│  _MemStore                LlmTestConfig          test_helpers.dart  │
│  ThemeContext / NodeContext / ChatContext / AppContext               │
└─────────────────────────────────────────────────────────────────────┘
```

### 设计原则

1. **自下而上**：基础 helper 不能依赖业务 helper，场景 helper 可以组合任意 helper
2. **Context 传递**：每个业务操作返回 Context 对象，下游操作接收 Context，避免字符串满天飞
3. **参数化**：所有业务 helper 接受可选配置参数（timeout、模型、分支模式等）
4. **幂等查找**：用 `find.byKey` / `find.text` 定位，不依赖 Widget 实例引用
5. **macOS aware**：所有 helper 默认支持 macOS 特有交互（侧栏导航、Enter 发送、_MemStore）

---

## 2. Context 对象设计

```dart
/// 应用级 Context（单例，整个测试生命周期唯一）
class DesktopTestApp {
  final Widget app;
  final LlmTestConfig llmConfig;

  Future<void> tearDown() async { /* 清理测试数据 */ }
}

/// 主题 Context
class ThemeCtx {
  final String themeId;
  final String title;
  final List<NodeCtx> roots; // 根节点列表

  /// 查找主题行 GestureDetector
  Finder get rowFinder => find.ancestor(
    of: find.text(title),
    matching: find.byType(GestureDetector),
  );
}

/// 节点 Context
class NodeCtx {
  final String nodeId;
  final String title;
  final ThemeCtx theme;     // 所属主题
  final NodeCtx? parent;    // 父节点（null=根）
  final List<NodeCtx> children; // 子节点列表
  final int depth;          // 深度（根=1）
  final NodeSourceType sourceType; // empty / originalContext / summary

  Finder get rowFinder => find.text(title);
}

/// 聊天 Context
class ChatCtx {
  final NodeCtx node;       // 绑定的节点
  final String modelId;     // 当前模型
  final List<String> userMessages; // 已发送的消息文本
}
```

### Context 的树形结构

```
DesktopTestApp
 └── ThemeCtx(id=thm_001)
      ├── NodeCtx(id=nd_001, depth=1)     ← 根节点
      │    ├── NodeCtx(id=nd_002, depth=2)
      │    │    └── NodeCtx(id=nd_003, depth=3)
      │    └── NodeCtx(id=nd_004, depth=2)
      └── NodeCtx(id=nd_005, depth=1)     ← 根节点
```

Context 对象在测试中传递，使后续操作自动定位正确的 UI 元素。

---

## 3. Helper 模块设计

### 3.1 基础 Helper：`desktop_primitive_helpers.dart`

| 函数 | 作用 | 参数 |
|------|------|------|
| `tapKey(Key)` | tap widget by Key | `Key key`, `bool warnIfMissed = false` |
| `enterTextByKey(Key, String)` | 输入文本 | `Key key`, `String text` |
| `scrollToText(String)` | 滚动到可见文本 | `String text`, `Scrollable? target` |
| `waitForKey(Key, Duration)` | 等 widget 出现 | `Key key`, `Duration timeout` |
| `sendShortcut(SingleActivator)` | 模拟快捷键 | `SingleActivator shortcut` |
| `rightClick(Finder)` | 模拟右键 | `Finder finder` |
| `hover(Finder)` | 模拟鼠标悬停 | `Finder finder` |
| `assertText(String, int?)` | 断言文本存在 | `String text`, `int? count` |
| `pumpAndSettleFor(Duration)` | pump+等动画 | `Duration duration` |

### 3.2 导航 Helper：`desktop_nav.dart`

| 函数 | 作用 |
|------|------|
| `switchToThemes(tester)` | 侧栏 → 主题分支 |
| `switchToNotes(tester)` | 侧栏 → 笔记分支 |
| `switchToSearch(tester)` | 侧栏 → 搜索分支 |
| `switchToLab(tester)` | 侧栏 → Lab 分支 |
| `openSettings(tester)` | 侧栏底部齿轮 → 设置页 |

### 3.3 主题 Helper：`desktop_theme_helpers.dart`

| 函数 | 作用 | 返回 |
|------|------|------|
| `createTheme(tester, title)` | 创建单个主题 | `ThemeCtx` |
| `selectTheme(tester, ctx)` | 选中已有主题（展开三栏） | `void` |
| `createThemes(tester, titles)` | 批量创建主题 | `List<ThemeCtx>` |

### 3.4 节点 Helper：`desktop_node_helpers.dart`

| 函数 | 作用 | 返回 |
|------|------|------|
| `createRootNode(tester, theme, title)` | 在主题下创建根节点 | `NodeCtx` |
| `createChildNode(tester, parent, title)` | 在父节点下创建子节点 | `NodeCtx` |
| `selectNode(tester, ctx)` | 选中节点（打开右栏聊天） | `ChatCtx` |
| `assertMaxDepthReached(tester, ctx)` | 验证深度限制生效 | `void` |
| `createNodeTree(tester, theme, {depth, countPerLevel})` | 在主题下创建完整 N 层树 | `ThemeCtx`（更新 roots） |

### 3.5 聊天 Helper：`desktop_chat_helpers.dart`

| 函数 | 作用 | 返回 |
|------|------|------|
| `sendMessage(tester, text)` | 输入文本+Enter 发送 | `void` |
| `waitForReply(tester, timeout)` | 等流式完成（stop→send） | `void` |
| `sendAndWait(tester, text)` | 发送+等回复（组合） | `void` |
| `switchModel(tester, providerId, modelId)` | 切换当前聊天模型 | `void` |
| `attachImage(tester, imagePath)` | 选图片附件（mock file_picker） | `void` |
| `startChat(tester, nodeCtx, ChatConfig)` | 选中节点+配置模型→就绪 | `ChatCtx` |

### 3.6 分支 Helper：`desktop_branch_helpers.dart`

| 函数 | 作用 | 返回 |
|------|------|------|
| `createBranch(tester, parent, BranchMode)` | 按指定模式创建分支 | `NodeCtx` |
| `createBranchesAllModes(tester, parent)` | 空、原文、总结三种全试 | `List<NodeCtx>` |

```dart
enum BranchMode { empty, originalContext, summary }
```

### 3.7 其它 Helper

| 模块文件 | 主要函数 | 作用 |
|----------|---------|------|
| `desktop_merge_helpers.dart` | `mergeNode(tester, source, target?)` | 合并节点 |
| `desktop_reorder_helpers.dart` | `reorderNodes(tester, nodes, newOrder)` | 同层排序 |
| `desktop_share_helpers.dart` | `shareAsImage(tester, node)` | 分享为图片 |
| `desktop_interaction_helpers.dart` | `rightClickMenu(tester)` / `hoverEffect(tester)` / `menuBarAction(tester)` | 交互验证 |

### 3.8 Fixture：`desktop_test_fixtures.dart`

```dart
/// 创建 macOS 集成测试用的预填 _MemStore
_MemStore createTestStore({String providerId, String modelId});

/// 标准 macOS 桌面测试 App 工厂（包含所有必要 override）
Future<DesktopTestApp> createDesktopTestApp({
  Locale locale = const Locale('zh'),
  String activeProvider = 'kimi',
  String activeModel = 'moonshot-v1-8k',
  List<Override> extraOverrides = const [],
});
```

---

## 4. 测试脚本 → Helper 映射表

每个测试脚本使用哪些 domain helper 模块：

| 测试脚本 | 需要的 Helper 模块 | 状态 |
|----------|-------------------|------|
| `desktop_theme_chat_e2e_test.dart` | nav + theme + node + chat | ✅ 已完成 |
| `desktop_comprehensive_e2e_test.dart` | nav + theme + node + chat + branch + merge + reorder + share | 🔧 待重写 |
| `desktop_shortcut_test.dart` | nav + interaction + chat | 🔲 待开发 |
| `desktop_context_menu_test.dart` | nav + theme + node + interaction | 🔲 待开发 |
| `desktop_hover_test.dart` | nav + theme + interaction | 🔲 待开发 |
| `desktop_menu_bar_test.dart` | interaction | 🔲 待开发 |
| `desktop_image_picker_test.dart` | nav + node + chat | 🔲 待开发 |
| `desktop_window_resize_test.dart` | nav + theme（验证 breakpoint 切换） | 🔲 待开发 |
| `desktop_pane_drag_resize_test.dart` | nav + theme | 🔲 待开发 |
| `desktop_share_export_test.dart` | nav + node + chat + share | 🔲 待开发 |
| `desktop_dark_mode_test.dart` | nav + interaction | 🔲 待开发 |
| `desktop_model_switch_test.dart` | nav + node + chat | 🔲 待开发 |

---

## 5. 组合示例

### 示例 1：`desktop_comprehensive_e2e_test.dart`

```dart
testWidgets('综合：3主题×3层 + 三分支 + 合并 + 排序 + 分享', (tester) async {
  final app = await createDesktopTestApp(activeProvider: 'kimi');
  await switchToThemes(tester);

  // A. 创建 3 个主题，每个 3 层
  final themes = <ThemeCtx>[];
  for (int i = 0; i < 3; i++) {
    final theme = await createTheme(tester, '综合主题_$i');
    theme = await createNodeTree(tester, theme, depth: 3, countPerLevel: 3);
    themes.add(theme);
  }

  // B. 深度限制验证
  final deepest = themes[0].roots.first.children.first.children.first;
  await assertMaxDepthExceeded(tester, deepest);

  // C. 三种分支创建
  final node = themes[0].roots.first;
  final branches = await createBranchesAllModes(tester, node);

  // D. 图片 + Kimi
  final chat = await startChat(tester, themes[1].roots.first,
    ChatConfig(model: 'moonshot-v1-8k'));
  await attachImage(tester, 'test_image.png');
  await sendAndWait(tester, '描述这张图片');

  // E. 节点合并
  await mergeNode(tester, themes[0].roots[1],
    target: themes[1].roots[0]);

  // F. 同层排序
  await reorderNodes(tester, themes[2].roots, [2, 0, 1]);

  // G. 分享导出
  await shareAsImage(tester, themes[0].roots.first);
});
```

### 示例 2：`desktop_shortcut_test.dart`

```dart
testWidgets('快捷键：Cmd+N 新建主题 / Cmd+Enter 新建节点 / Cmd+, 设置', (tester) async {
  await createDesktopTestApp();
  await switchToThemes(tester);

  // Cmd+N 新建主题
  await sendShortcut(tester, SingleActivator(LogicalKeyboardKey.keyN, meta: true));
  await enterTextByKey(tester, const ValueKey('theme_title_input'), '快捷主题');
  await tapKey(tester, const ValueKey('theme_create_button'));
  await scrollToText(tester, '快捷主题');
  assertText(tester, '快捷主题', 1);

  // Cmd+, 打开设置
  await sendShortcut(tester, SingleActivator(LogicalKeyboardKey.comma, meta: true));
  assertText(tester, '设置'); // 设置页可见
});
```

---

## 6. 文件结构

```
integration_test/
├── _support/
│   ├── test_helpers.dart                   # 已有
│   ├── llm_test_config.dart                # 已有
│   ├── in_memory_llm_config_store.dart     # 已有
│   ├── step_timer.dart                     # 已有
│   │
│   ├── desktop_test_fixtures.dart          # NEW: MemStore + createDesktopTestApp
│   ├── desktop_primitive_helpers.dart      # NEW: tapKey/scrollToText/waitForKey/sendShortcut
│   ├── desktop_nav.dart                    # NEW: 侧栏导航
│   ├── desktop_theme_helpers.dart          # NEW: 主题创建/选择
│   ├── desktop_node_helpers.dart           # NEW: 节点创建/树/深度
│   ├── desktop_chat_helpers.dart           # NEW: 聊天/模型/图片
│   ├── desktop_branch_helpers.dart         # NEW: 分支创建
│   ├── desktop_merge_helpers.dart          # NEW: 节点合并
│   ├── desktop_reorder_helpers.dart        # NEW: 排序
│   ├── desktop_share_helpers.dart          # NEW: 分享导出
│   └── desktop_interaction_helpers.dart    # NEW: 右键/hover/快捷键/菜单栏
│
├── desktop_theme_chat_e2e_test.dart        # 已有（用现有 helpers 重写后移入）
├── desktop_comprehensive_e2e_test.dart     # 重写：组合所有 helper
├── desktop_shortcut_test.dart              # NEW
├── desktop_context_menu_test.dart          # NEW
├── desktop_hover_test.dart                 # NEW
├── desktop_menu_bar_test.dart              # NEW
├── desktop_image_picker_test.dart          # NEW
├── desktop_window_resize_test.dart         # NEW
├── desktop_pane_drag_resize_test.dart      # NEW
├── desktop_share_export_test.dart          # NEW
├── desktop_dark_mode_test.dart             # NEW
└── desktop_model_switch_test.dart          # NEW
```

---

## 7. 迁移计划

已完成的 `desktop_theme_chat_e2e_test.dart` 中包含内联的 helper 函数（`_createTheme`、`_createNode`、送发+等流式）。这些需要提取到对应模块：

| 现有内联函数 | 迁移目标 |
|------------|---------|
| `_createTheme(tester, title)` | → `desktop_theme_helpers.dart` → `createTheme()` |
| `_createNode(tester, title)` | → `desktop_node_helpers.dart` → `createRootNode()` |
| 发送+等流式循环 | → `desktop_chat_helpers.dart` → `sendAndWait()` |
| `_MemStore` 类 | → `desktop_test_fixtures.dart` |
| `scrollUntilVisible(find.byType(Scrollable).first)` | → `desktop_primitive_helpers.dart` → `scrollToText()` |
| `sendKeyEvent(Enter)` | → `desktop_chat_helpers.dart` → `sendMessage()` |

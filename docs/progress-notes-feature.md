# 笔记功能开发进度

| 属性 | 说明 |
|------|------|
| 文档版本 | 0.1 |
| 更新日期 | 2026-05-27 |
| 关联需求 | REQUIREMENTS.md § 笔记与对话联动 |

---

## 1. 整体状态

笔记模块的基本 CRUD 链路已完成：用户可以从对话中摘录文本追加到笔记，也能在笔记详情页直接编辑正文。**刷新机制经过多轮迭代，当前已稳定**。

---

## 2. 已完成的功能

### 2.1 “添加到笔记”入口
- 在消息气泡上选中文本后，上下文菜单出现“添加到笔记”选项
- 点击后弹出笔记选择页（`NoteSelectScreen`），展示现有笔记列表
- 用户选择已有笔记即追加文本；也可新建笔记后再追加
- 实现位置：[message_bubble.dart](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/ui/core/shared/message_bubble.dart)

### 2.2 笔记存储层 (`NoteStore`)
- 笔记以 Markdown 文件存储，包含 YAML frontmatter（id / title / createdAt / updatedAt / themeId）
- 支持操作：
  - `createNote(themeId, title)` — 新建笔记
  - `listNoteMetas()` — 列出笔记元数据
  - `readBody(noteId)` — 读取笔记正文
  - `appendBody(noteId, text)` — 追加文本到笔记末尾
  - `writeBody(noteId, body)` — 覆盖笔记正文（保留 frontmatter，更新 updatedAt）
- 文件路径：`{root}/themes/{themeId}/notes/{noteId}.md`
- 实现位置：[note_store.dart](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/data/stores/note_store.dart)

### 2.3 笔记内容可编辑
- `NoteDetailScreen` 支持编辑/只读切换
- AppBar 右侧有编辑按钮（✏️），点击后正文切换为多行 `TextField`
- 保存时调用 `writeBody` 覆盖文件，同时触发版本通知
- 实现位置：[note_detail_screen.dart](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/ui/features/notes/note_detail_screen.dart#L9-L107)

### 2.4 笔记列表浏览
- 按主题分组的笔记总览 (`NoteBrowseScreen`），点击进入该主题下的笔记列表
- 主题内的笔记列表 (`ThemeNoteListScreen`），点击进入笔记内容
- 支持下拉刷新
- 实现位置：
  - [note_browse_screen.dart](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/ui/features/notes/note_browse_screen.dart)
  - [note_detail_screen.dart](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/ui/features/notes/note_detail_screen.dart#L163-L250)

---

## 3. 刷新机制设计（关键）

### 3.1 问题背景
笔记写盘后，笔记列表页和内容页不会自动更新——因为页面常驻（`StatefulShellRoute.indexedStack`），不销毁重建，也不会重新读取磁盘。

### 3.2 方案：全局版本号 + tab 切换触发
- 定义 `noteListVersionProvider`（`NotifierProvider<int>`），所有写操作后调用 `bump()` 递增
- `_MainShell`（[router.dart](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/ui/core/router.dart#L87-L122)）在用户点击笔记 tab 时调用 `bump()`
- 笔记列表页和内容页在 `build()` 中 `ref.watch(noteListVersionProvider)`，发现版本变化后异步 `_load()`

### 3.3 曾尝试过但不可行的方案
- ❌ `ref.listen` 放在 `initState` — Riverpod 3.x 不允许在 initState 中调用
- ❌ `ref.listen` 放在 `build` — 触发 `_refresh` → `setState` → rebuild → 再注册 listen，循环不稳定
- ❌ `WidgetsBindingObserver.resumed` — 只在 app 前后台切换触发，同一应用内 tab 切换不会触发
- ❌ `FutureBuilder` + 替换 Future — `FutureBuilder` 可能不重新执行新 Future
- ❌ `ValueKey(version)` 强制重建 — 配合 `setState` 时 `RefreshIndicator` 动画异常

### 3.4 当前采用的稳定方案
- 全部页面从 `FutureBuilder` 改为手动 `_load()` + `setState` 管理数据
- 加载态、空态、错误态全部包裹在可滚动的 `ListView` 中（`_ScrollableWrap`），保证下拉手势总能触发 `RefreshIndicator`
- 内容页 (`NoteDetailScreen`) 也增加了 `RefreshIndicator`，可下拉重新读取文件内容

### 3.5 版本号触发点汇总

| 操作 | 触发 bump 的位置 |
|------|-----------------|
| 聊天页选中文本追加到笔记 | `note_select_screen.dart` `_appendToNote()` / `_createAndAppend()` |
| 笔记详情页编辑保存 | `note_detail_screen.dart` `_toggleEditing()` |
| 笔记总览页新建笔记 | `note_browse_screen.dart` `_createNoteInUncategorized()` |
| 用户点击底部笔记 tab | `router.dart` `_MainShell` `onDestinationSelected` |

---

## 4. 测试覆盖

- `test/data/stores/note_store_test.dart` — NoteStore 的创建、追加、覆写、读取测试（4 个用例）
- `test/ui/core/shared/message_bubble_test.dart` — 消息气泡 UI 测试
- 全量测试：`flutter test` → 48 passed

---

## 5. 待处理事项

| 优先级 | 事项 | 说明 |
|--------|------|------|
| 🔴 | 选中文本在复杂 Markdown 中不准确 | 当前依赖系统剪贴板复制，在 SelectionArea + Markdown 场景下可能有偏差，需改为直接从 `SelectableRegionState` 获取选区 |
| 🟡 | 笔记删除功能 | 尚未实现 |
| 🟡 | 笔记重命名功能 | 尚未实现 |
| 🟢 | 笔记搜索/过滤 | 尚未实现 |
| 🟢 | `appPathsProvider` 未就绪时的加载态 | `_loadThemeNotes` 已改为 `await ref.read(appPathsProvider.future)`，但在未完成前页面会短暂显示空列表 |

---

## 6. 关键问题与解决记录

| 日期 | 问题 | 根因 | 解决 |
|------|------|------|------|
| 2026-05-27 | 添加到笔记后，笔记列表不刷新 | 页面常驻不销毁，切 tab 不触发重读 | 全局版本号 + tab 切换 bump |
| 2026-05-27 | 下拉刷新无动画/无效 | RefreshIndicator 子 widget 不是可滚动列表 | 改用 `_ScrollableWrap` 包裹所有状态 |
| 2026-05-27 | ref.listen 报错 | Riverpod 3.x 不允许在 initState 调用 | 改为 build 内版本号比较 + 异步加载 |
| 2026-05-27 | 笔记页面数据突然为空 | `appPathsProvider.future` 未 await | 改为 `await ref.read(appPathsProvider.future)` |

---

## 7. 标题生成与对话总结功能优化（2026-06-04）

### 7.1 已完成的功能

#### 7.1.1 手动触发标题生成
- 移除自动触发机制（原来进入页面自动生成）
- 用户需要主动点击"生成标题"按钮
- 首次生成时会弹出模型选择器，选择后记住该偏好
- 实现位置：[title_suggestion_screen.dart](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/ui/core/shared/title_suggestion_screen.dart#L103-L145)

#### 7.1.2 独立模型选择
- 标题生成和对话总结支持配置独立的模型
- 设置页面新增两个入口：
  - **标题生成模型** (`titleModelProviderId` + `titleModelModelId`)
  - **对话总结模型** (`summaryModelProviderId` + `summaryModelModelId`)
- 未配置时每次弹选择器；已配置则直接使用
- 用户选择后自动保存到 `SettingsStore`
- 实现位置：[settings_screen.dart](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/ui/features/settings/settings_screen.dart#L231-L280)

#### 7.1.3 消息边界截断
- 超长内容按消息边界截断，填满模型 context window 的 90%
- 截断策略：从尾部向前裁剪消息，保留完整对话轮次
- 兜底机制：如果仍超限，砍掉最早 20% 的消息
- 实现位置：[title_suggestion_service.dart](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/data/services/title_suggestion_service.dart#L80-L140)

#### 7.1.4 Token 估算与 CJK 支持
- 新增 `_estimateTokens()` 方法，支持语言检测
- CJK 字符（中文/日文/韩文）按 `chars / 1.5` 估算
- 英文字符按 `chars / 4` 估算
- 混合文本按比例加权
- 实现位置：[title_suggestion_service.dart](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/data/services/title_suggestion_service.dart#L50-L78)

#### 7.1.5 未知 Context Window 处理
- 模型列表获取时，若 context window 未知（`contextWindow == 0`），弹出选择器
- 选项：1M / 512K / 256K / 128K / 64K / 32K / 16K / 8K / 4K
- 用户选择后保存到 `LlmModelConfig`
- 实现位置：[llm_provider_detail_screen.dart](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/ui/features/llm/llm_provider_detail_screen.dart#L400-L450)

#### 7.1.6 提示词优化
- `_titleSystemPrompt` 调整为引导模型提取讨论主题、关注用户提问
- `_summarySystemPrompt` 保持不变

### 7.2 数据模型变更

#### SettingsStore 新增字段
```dart
final String? titleModelProviderId;
final String? titleModelModelId;
final String? summaryModelProviderId;
final String? summaryModelModelId;
```

#### LlmModelConfig 变更
```dart
final int contextWindow; // 0 表示未知
```

### 7.3 UI 设计要点

- 所有新增 UI 遵循 iOS HIG（Human Interface Guidelines）
- 使用 `SafeArea` 包裹所有页面
- 模型选择器使用 `CupertinoActionSheet`
- 空态引导使用图标 + 文字 + 按钮组合

### 7.4 关键问题与解决

| 日期 | 问题 | 根因 | 解决 |
|------|------|------|------|
| 2026-06-04 | 选择模型后下次不生效 | 未保存到 settings | 在 `_showModelSelectorAndGenerate()` 中添加 `saveTitleModel()` |
| 2026-06-04 | Anthropic 模型 context window 始终为 100M | 默认值设为 100M | 改为 0（未知），让用户手动选择 |
| 2026-06-04 | 长对话超出模型限制 | 未做截断 | 实现消息边界截断 + 20% 兜底 |
| 2026-06-04 | 中文内容 token 估算不准确 | 按英文比例 `chars / 4` | 增加 CJK 检测，中文按 `chars / 1.5` |

### 7.5 测试覆盖

- `_estimateTokens()` — 纯英文、纯中文、混合文本测试
- `_truncateByMessages()` — 短对话不截断、超长对话截断、20% 兜底测试
- `SettingsStore` — 读写 4 个新字段测试

### 7.6 文件变更统计

```
 lib/data/models/llm_model_config.dart              |   4 +-
 lib/data/services/model_fetcher.dart               |   9 +-
 lib/data/services/settings_store.dart              |  49 ++
 lib/data/services/title_suggestion_service.dart    | 129 +++-
 lib/l10n/app_en.arb                                | 754 ++++++++++++-------
 lib/l10n/app_zh.arb                                | 200 ++---
 lib/ui/core/shared/title_suggestion_screen.dart    | 282 ++++++-
 lib/ui/features/llm/llm_provider_detail_screen.dart| 136 +++-
 lib/ui/features/settings/settings_controller.dart  |  12 +
 lib/ui/features/settings/settings_screen.dart      | 231 ++++++
 31 files changed, 2388 insertions(+), 796 deletions(-)
```

### 7.7 后续优化方向

| 优先级 | 事项 | 说明 |
|--------|------|------|
| 🟡 | "找回初心"功能 | 帮助用户回溯对话起源，高亮最早的关键提问 |
| 🟢 | 更精确的 token 估算 | 集成 tiktoken 库，替代简单的 `chars / N` 估算 |
| 🟢 | 模型选择器优化 | 显示模型的实际 context window 大小，帮助用户决策 |
| 🟢 | 批量设置 context window | 多个模型未知时，支持一次性设置所有 |


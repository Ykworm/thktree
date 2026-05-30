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

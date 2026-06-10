# 笔记详情/编辑设计

> 涵盖 `NoteDetailScreen`（阅读/编辑切换）、`NoteEditorScreen`（Notion 风格独立编辑器）和 `NoteSelectScreen`（聊天 → 笔记的弹窗选择页）。
>
> 配套阅读：[`../../../_shared/design-system.md`](../../../_shared/design-system.md) · [`./README.md`](./README.md) · [`./notes-list-design.md`](./notes-list-design.md)

---

## Summary

笔记详情页是笔记模块的"工作台"：单屏内集成阅读、编辑、复制、转对话、重命名、删除六大能力。独立的 `NoteEditorScreen` 提供 Notion 风格的从零创作体验，500ms 防抖自动保存。`NoteSelectScreen` 是从聊天上下文注入笔记的弹窗，承担"添加到笔记"的入口。

---

## 设计决策

| 决策点 | 选择 | 说明 |
|--------|------|------|
| 详情页操作密度 | 单屏 4 按钮（复制/分支/编辑/删除） | iOS HIG 推荐 3-4 个 trailing actions |
| 标题交互 | 点击标题重命名 | 与详情内容形成视觉区分 |
| 阅读态渲染 | GptMarkdown | 复用项目已有的 Markdown 渲染 |
| 编辑模式切换 | 详情页内就地切换 vs 跳转独立编辑器 | 详情页内 edit 适合轻编辑，独立编辑器适合重写 |
| 编辑器风格 | Notion 风格（28pt w600 标题 + 17pt 正文，无边框） | 简洁、可聚焦 |
| 自动保存策略 | 500ms 防抖 | 既不频繁落盘，也不丢失内容 |
| 删除位置 | 详情页 AppBar 红色垃圾桶 | 符合 iOS HIG（破坏性操作在 nav bar） |
| 复制反馈 | icon 切到绿色 check 2 秒 | 轻量提示，不打断阅读 |
| 转对话 | 创建新节点，写入笔记内容作为 user input | 复用 `NodeLocationPicker` |

---

## 1. NoteDetailScreen — 笔记详情/阅读页

### 1.1 屏幕形态

**阅读态：**

```
┌─────────────────────────────────────────────────────────────┐
│  ← 心理学读书笔记            [📋] [🌿] [✏️] [🗑️]            │  ← ThkNavBar.inline
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  # 焦虑与防御机制                                           │
│                                                             │
│  ## 核心观点                                                 │
│  焦虑是个体面对威胁时...                                    │
│                                                             │
│  ## 防御机制分类                                             │
│  1. 原始防御：否认、投射、分裂...                           │
│  2. 成熟防御：升华、幽默、合理化...                         │
│                                                             │
│  --- GptMarkdown 渲染区域 ---                               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**编辑态：**

```
┌─────────────────────────────────────────────────────────────┐
│  ← 心理学读书笔记            [   ] [🌿] [✓] [🗑️]            │  ← 复制按钮隐藏
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ # 焦虑与防御机制                                     │    │
│  │                                                     │    │
│  │ ## 核心观点                                          │    │
│  │ 焦虑是个体面对威胁时...                             │    │
│  │                                                     │    │
│  │ ## 防御机制分类                                      │    │
│  │ 1. 原始防御...                                      │    │
│  │                                                     │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  [B] [I] [S] [<] [•] [1.] [🔗]  ← MarkdownToolbar         │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 顶部导航栏

```dart
CupertinoPageScaffold(
  backgroundColor: AppColors.pageBg,
  navigationBar: ThkNavBar.inline(
    title: _title,
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_editing && _body.isNotEmpty)
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _copyAll,
            child: Icon(
              _copied ? AppIcons.checkCircle : AppIcons.copy,
              color: _copied
                  ? CupertinoColors.systemGreen
                  : AppColors.accent,
            ),
          ),
        CupertinoButton(...branch...),
        CupertinoButton(...edit/check...),
        CupertinoButton(...trash...),
      ],
    ),
    onTitleTap: _renameNote,
  ),
)
```

| 元素 | 规范 |
|------|------|
| 背景 | `AppColors.pageBg`（区别于 `surface` 的页面级背景） |
| 标题 | `_title`（笔记元数据中的标题） |
| `onTitleTap` | 触发重命名 dialog |
| 复制按钮 | 仅阅读态 + 内容非空时显示 |
| 分支/编辑/删除 | 始终显示 |

### 1.3 四件套操作

#### 1.3.1 📋 复制 (`_copyAll`)

```dart
Future<void> _copyAll() async {
  if (_body.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: _body));
  if (!mounted) return;
  setState(() => _copied = true);
  await Future<void>.delayed(const Duration(seconds: 2));
  if (mounted) {
    setState(() => _copied = false);
  }
}
```

- 仅在阅读态 + `_body.isNotEmpty` 时显示
- 复制后 icon 切到 `AppIcons.checkCircle`，颜色 `systemGreen`，2 秒后恢复
- 复制内容是**原始 Markdown 文本**（不是渲染后的纯文本）

#### 1.3.2 🌿 创建对话分支 (`_createChatFromNote`)

```dart
Future<void> _createChatFromNote() async {
  if (_body.isEmpty) {
    ThkAlert.show(context, message: l10n.noMessagesYet);
    return;
  }
  // 1. 选位置（主题 + 父节点）
  final location = await showNodeLocationPicker(context, ref, ...);
  if (location == null) return;
  // 2. 解析 provider/model（继承全局设置）
  // 3. 创建新 chat node
  // 4. 把笔记内容写入 user input
  // 5. 跳转到对话页
}
```

详细流程见 [`./note-detail-design.md#4-转对话流程`](#4-转对话流程)。

#### 1.3.3 ✏️ 编辑/完成 (`_toggleEditing`)

```dart
Future<void> _toggleEditing() async {
  if (_editing) {
    await _store.writeBody(widget.noteId, _controller.text);
    _body = _controller.text;
    ref.read(noteListVersionProvider.notifier).bump();
    _updateSearchIndex();
    if (!mounted) return;
  }
  setState(() => _editing = !_editing);
}
```

- 退出编辑态时落盘
- 触发 `noteListVersionProvider` bump（让列表页更新）
- 异步更新搜索索引

#### 1.3.4 🗑️ 删除 (`_deleteNote`)

```dart
CupertinoButton(
  padding: EdgeInsets.zero,
  onPressed: _deleteNote,
  child: const Icon(
    CupertinoIcons.trash,
    color: CupertinoColors.systemRed,
  ),
),
```

- 弹 `CupertinoAlertDialog`（`isDestructiveAction: true`）二次确认
- 确认后 `deleteNote` + `bump` + `Navigator.pop()`
- 失败时 `ThkAlert` 兜底

### 1.4 重命名 (`_renameNote`)

```dart
Future<void> _renameNote() async {
  final controller = TextEditingController(text: _title);
  final newTitle = await showCupertinoDialog<String>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Text(l10n.renameNote),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: ThkTextField(
          controller: controller,
          placeholder: l10n.titleHint,
          autofocus: true,
          maxLength: 30,
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () {
            final value = controller.text.trim();
            Navigator.of(context).pop(value.isEmpty ? null : value);
          },
          child: Text(l10n.save),
        ),
      ],
    ),
  );
  if (newTitle == null || newTitle.isEmpty) return;
  if (newTitle == _title) return;
  await _store.renameNote(noteId: widget.noteId, newTitle: newTitle);
  ref.read(noteListVersionProvider.notifier).bump();
}
```

| 元素 | 规范 |
|------|------|
| 触发 | 点击标题 |
| 弹窗 | `CupertinoAlertDialog` |
| 输入框 | `ThkTextField`，`autofocus: true`，`maxLength: 30` |
| 取消 | 弹回 `null` |
| 保存 | `controller.text.trim()`，空字符串视为取消 |
| 重复值 | 比较 `newTitle == _title` 跳过 |

### 1.5 阅读态与编辑态切换

```dart
Widget _buildBody(AppLocalizations l10n) {
  if (_editing) {
    return Column(
      children: [
        Expanded(
          child: CupertinoTextField(
            controller: _controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            padding: const EdgeInsets.all(16),
            style: const TextStyle(
              fontSize: 17,
              height: 1.6,
              color: AppColors.textPrimary,
            ),
            decoration: const BoxDecoration(color: AppColors.surface),
          ),
        ),
        MarkdownToolbar(controller: _controller),
      ],
    );
  }
  if (_loading) return const Center(child: CupertinoActivityIndicator());
  if (_error != null) return Center(child: Text(_error.toString(), ...));
  if (_body.isEmpty) return Center(child: Text(l10n.noMessagesYet, ...));
  return Container(
    color: AppColors.surface,
    child: SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: GptMarkdown(
        _body,
        style: const TextStyle(fontSize: 17, height: 1.6),
      ),
    ),
  );
}
```

| 状态 | 视觉 |
|------|------|
| 编辑中 | `Column(CupertinoTextField + MarkdownToolbar)`，背景 `surface` |
| 加载中 | `Center(CupertinoActivityIndicator)` |
| 错误 | `Center(systemRed 文字)` |
| 内容为空 | `Center(l10n.noMessagesYet + textSecondary)` |
| 正常阅读 | `Container(surface) + SingleChildScrollView + GptMarkdown` |

**SafeArea 处理**：

```dart
child: SafeArea(
  bottom: !_editing,  // 编辑时不保留 bottom safe area，让键盘顶起
  child: _buildBody(l10n),
),
```

### 1.6 GptMarkdown 渲染

复用项目已引入的 `package:gpt_markdown`：

```dart
GptMarkdown(
  _body,
  style: const TextStyle(fontSize: 17, height: 1.6),
)
```

- 字体 17pt、行高 1.6 — 与编辑器正文保持一致
- GptMarkdown 支持流式渲染 + 代码高亮，**适合大段内容**
- 容器 `padding: EdgeInsets.zero`，由父级控制内边距

### 1.7 状态管理

| 字段 | 类型 | 用途 |
|------|------|------|
| `_editing` | `bool` | 当前是否编辑态 |
| `_controller` | `TextEditingController` | 编辑态 TextField |
| `_store` | `NoteStore` | CRUD 入口 |
| `_body` | `String` | 缓存正文（避免每次 `readBody`） |
| `_title` | `String` | 缓存标题 |
| `_loading` | `bool` | 首次加载态 |
| `_error` | `Object?` | 错误信息 |
| `_lastSeenVersion` | `int?` | 版本号去重 |
| `_copied` | `bool` | 复制成功反馈 |

`initState` 中初始化 store + 读取初始 version；`build` 中检测版本变化 → `addPostFrameCallback` 重新 `_loadBody()`（**编辑态不重载，避免覆盖用户输入**）。

```dart
final version = ref.watch(noteListVersionProvider);
if (_lastSeenVersion != version) {
  _lastSeenVersion = version;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && !_editing) {
      _loadBody();
    }
  });
}
```

---

## 2. NoteEditorScreen — Notion 风格独立编辑器

### 2.1 屏幕形态

```
┌─────────────────────────────────────────────────────────────┐
│  ← 心理学                                            [ ✓ ]  │  ← ThkNavBar.inline
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  焦虑与防御机制                                              │  ← 28pt w600 大标题
│  ─────────────────                                          │
│                                                             │
│  ## 核心观点                                                 │  ← 17pt 正文
│  焦虑是个体面对威胁时...                                    │
│                                                             │
│  ## 防御机制分类                                             │
│  1. 原始防御：否认、投射、分裂...                           │
│  2. 成熟防御：升华、幽默、合理化...                         │
│                                                             │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  [B] [I] [S] [<] [•] [1.] [🔗]  ← MarkdownToolbar          │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 顶部导航栏

```dart
return CupertinoPageScaffold(
  backgroundColor: AppColors.pageBg,
  navigationBar: ThkNavBar.inline(
    title: widget.themeTitle,        // 显示主题名而非"笔记"
    trailing: CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        _saveNow();
        Navigator.of(context).pop();
      },
      child: Icon(AppIcons.check),
    ),
  ),
)
```

| 元素 | 规范 |
|------|------|
| 标题 | `widget.themeTitle`（主题名）— 让用户在编辑时知道归类 |
| 右上角 | ✓ 完成（`AppIcons.check`）— 立即保存并返回 |
| 返回手势 | pop 前 `_saveNow` 防丢失 |

### 2.3 Notion 风格输入区

```dart
SafeArea(
  child: Column(
    children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题输入
              CupertinoTextField(
                controller: _titleController,
                placeholder: l10n.noTitle,
                placeholderStyle: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                decoration: const BoxDecoration(color: AppColors.surface, border: null),
                maxLines: null,
                onChanged: (_) => _scheduleSave(),
              ),
              const SizedBox(height: 16),
              // 内容编辑区
              CupertinoTextField(
                controller: _bodyController,
                placeholder: l10n.startWriting,
                placeholderStyle: const TextStyle(fontSize: 17, color: AppColors.textTertiary),
                style: const TextStyle(fontSize: 17, height: 1.6, color: AppColors.textPrimary),
                decoration: const BoxDecoration(color: AppColors.surface, border: null),
                maxLines: null,
                minLines: 10,
                onChanged: (_) => _scheduleSave(),
              ),
            ],
          ),
        ),
      ),
      // Markdown 工具栏
      MarkdownToolbar(controller: _bodyController),
    ],
  ),
)
```

| 元素 | 规范 |
|------|------|
| 标题 | 28pt · w600 · `textPrimary`，placeholder 用 `textTertiary` |
| 标题占位 | `l10n.noTitle`（"无标题"） |
| 正文 | 17pt · 行高 1.6 · `textPrimary`，placeholder 用 `textTertiary` |
| 正文占位 | `l10n.startWriting`（"开始书写..."） |
| 输入框样式 | `BoxDecoration(color: surface, border: null)` — 透明边框 |
| `minLines` | 10（避免初创时输入框太矮） |
| `maxLines` | null（自适应扩展） |
| `onChanged` | 触发 `_scheduleSave()` |
| 间距 | 标题与正文之间 `SizedBox(height: 16)` |
| 工具栏 | `MarkdownToolbar(controller: _bodyController)` |

### 2.4 自动保存（500ms 防抖）

```dart
Timer? _saveTimer;
bool _dirty = false;

void _scheduleSave() {
  _dirty = true;
  _saveTimer?.cancel();
  _saveTimer = Timer(const Duration(milliseconds: 500), _saveNow);
}

Future<void> _saveNow() async {
  if (!_dirty || _noteId == null) return;
  _dirty = false;
  try {
    final title = _titleController.text.trim();
    final body = _bodyController.text;
    await _store.renameNote(noteId: _noteId!, newTitle: title);
    if (body.isNotEmpty) {
      await _store.writeBody(_noteId!, body);
    }
    ref.read(noteListVersionProvider.notifier).bump();
    _updateSearchIndex();
  } catch (e) {
    _dirty = true;  // 失败时重新标记，等下次重试
  }
}
```

| 触发点 | 行为 |
|--------|------|
| 标题/正文 `onChanged` | `_scheduleSave()` — 500ms 防抖 |
| 顶部 ✓ 按钮 | `_saveNow()` 立即保存 + pop |
| `dispose()` | `_saveNow()` + 清理 timer + dispose controllers |

**为什么 500ms？**
- 太短（< 200ms）：频繁落盘，电池/IO 开销大
- 太长（> 1s）：用户切换页面时可能丢失最后输入
- 500ms 是手感与性能的平衡点

**失败重试**：保存抛异常时把 `_dirty` 置回 `true`，下次输入或退出时再尝试。

### 2.5 createMode 初始化

```dart
@override
void initState() {
  super.initState();
  _titleController = TextEditingController();
  _bodyController = TextEditingController();
  _store = NoteStore(notesDir: Directory(widget.notesDir));
  _noteId = widget.noteId;
  if (widget.createMode) {
    _createNote();
  } else {
    _loadNote();
  }
}

Future<void> _createNote() async {
  try {
    final meta = await _store.createNote(themeId: widget.themeId, title: '');
    if (!mounted) return;
    setState(() => _noteId = meta.noteId);
  } catch (e) {
    ThkAlert.show(context, message: e.toString());
  }
}
```

- `createMode: true` — 立即在磁盘上创建空文件（`createNote` 返回 `noteId`），后续输入就基于这个 id 持续落盘
- `createMode: false` — 读取已有笔记的 title/body 到 controllers

### 2.6 搜索索引联动

```dart
void _updateSearchIndex() {
  unawaited(() async {
    try {
      final searchIndex = await ref.read(searchServiceProvider.future);
      final metas = await _store.listNoteMetas();
      final meta = metas.where((m) => m.noteId == _noteId).firstOrNull;
      if (meta == null) return;
      await searchIndex.upsertNote(
        noteId: meta.noteId,
        themeId: meta.themeId,
        themeTitle: widget.themeTitle,
        noteTitle: meta.title,
        body: _bodyController.text,
      );
    } catch (_) {
      // 静默失败
    }
  }());
}
```

- 自动保存与显式保存都触发
- `unawaited` 包装，**永不阻塞主流程**
- 失败时静默吞掉（搜索索引只是辅助）

---

## 3. NoteSelectScreen — 聊天 → 笔记的弹窗选择页

### 3.1 屏幕形态

```
┌─────────────────────────────────────────────────────────────┐
│  添加到笔记                                          [取消]  │  ← CupertinoModalPopup
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ 心理学读书笔记                                       │    │  ← ThkListTile
│  │ 12 条 · 上次编辑 2 小时前                            │    │
│  ├─────────────────────────────────────────────────────┤    │
│  │ 焦虑与防御机制                                       │    │
│  │ 1 条 · 上次编辑 昨天                                 │    │
│  ├─────────────────────────────────────────────────────┤    │
│  │ + 新建笔记                                           │    │  ← 高亮 tinted 按钮
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 触发链路

```
聊天页 (message_bubble.dart)
  选中文本 → 上下文菜单 → "添加到笔记"
    │
    ▼
Navigator.push(NoteSelectScreen(text: 选中文本))
    │
    ├── 用户选已有笔记 → _appendToNote(noteId) → 追加文本
    │
    └── 用户选"新建笔记" → _createAndAppend(themeId) → 创建后追加
```

### 3.3 关键方法

#### `_appendToNote(noteId)` — 追加到已有笔记

```dart
Future<void> _appendToNote(String noteId) async {
  // 1. 读现有 body
  final existing = await _store.readBody(noteId);
  // 2. 追加文本（带空行分隔）
  final newBody = existing.isEmpty
      ? widget.text
      : '$existing\n\n${widget.text}';
  // 3. 写回
  await _store.writeBody(noteId, newBody);
  // 4. bump 触发列表/详情刷新
  ref.read(noteListVersionProvider.notifier).bump();
  // 5. 提示
  ThkAlert.show(context, message: l10n.addedToNote);
  // 6. pop
  Navigator.of(context).pop();
}
```

#### `_createAndAppend(themeId)` — 新建并追加

```dart
Future<void> _createAndAppend(String themeId) async {
  // 1. 创建空笔记
  final meta = await _store.createNote(themeId: themeId, title: '');
  // 2. 写入文本
  await _store.writeBody(meta.noteId, widget.text);
  // 3. bump
  ref.read(noteListVersionProvider.notifier).bump();
  // 4. 提示 + pop
}
```

### 3.4 弹窗形式

通常用 `CupertinoModalPopup` 或 push `CupertinoPageRoute`，具体由 `message_bubble.dart` 触发方决定。

---

## 4. 转对话流程（`_createChatFromNote`）

笔记详情页右上角 🌿 按钮的完整流程：

```dart
Future<void> _createChatFromNote() async {
  if (_body.isEmpty) {
    ThkAlert.show(context, message: l10n.noMessagesYet);
    return;
  }
  // 1. 选位置（主题 + 父节点）
  final location = await showNodeLocationPicker(context, ref, ...);
  if (location == null) return;
  if (!mounted) return;

  // 2. 解析 provider/model（继承全局设置）
  String? providerId;
  String? modelId;
  final settings = ref.read(settingsControllerProvider).value;
  if (settings != null) {
    providerId = _mapLegacyProviderToPresetId(settings.llmProvider);
    modelId = settings.model;
  }

  // 3. 创建新 chat node
  final container = ProviderScope.containerOf(context, listen: false);
  final nodeStore = await container.read(nodeStoreProvider.future);
  final sessionStore = await container.read(sessionStoreProvider.future);
  final themeRow = await nodeStore.getThemeRow(themeId: location.themeId);
  final themePath = themeRow['themePath']! as String;

  // 4. 合并笔记 title 和内容作为 user input
  final userInput = '$_title\n\n$_body';

  final childNode = await nodeStore.createChatNode(
    themeId: location.themeId,
    themePath: themePath,
    parentId: location.parentId,
    title: _title,                              // 对话标题 = 笔记标题
  );

  // 5. 写入 user input
  await sessionStore.appendUserMessage(
    nodeId: childNode.nodeId,
    content: userInput,
  );

  // 6. 记录来源（用于回溯）
  final nodeSourceExcerpt = userInput.length <= 80
      ? userInput
      : '${userInput.substring(0, 80)}...';
  await nodeStore.updateNodeSourceInfo(
    nodeId: childNode.nodeId,
    sourceExcerpt: nodeSourceExcerpt,
    sourceType: 'note',                         // 标记来源是笔记
  );

  // 7. 应用 provider/model
  if (providerId != null && modelId != null) {
    await sessionStore.updateSessionModel(
      nodeId: childNode.nodeId,
      providerId: providerId,
      modelId: modelId,
    );
  }

  // 8. 刷新主题树
  unawaited(
    container
        .read(themeDetailControllerProvider(location.themeId).notifier)
        .refresh()
        .catchError((_) {}),
  );

  // 9. 跳转到对话页
  context.push(
    '/themes/${location.themeId}/nodes/${childNode.nodeId}',
    extra: ChatScreenLaunchParams(
      title: _title,
      autoTriggerReply: true,                    // 自动触发一次回复
    ),
  );
}
```

| 阶段 | 关键调用 |
|------|----------|
| 1. 选位置 | `showNodeLocationPicker` |
| 2. 解析 provider | `_mapLegacyProviderToPresetId` (旧枚举 → 新 preset id) |
| 3. 创建节点 | `nodeStore.createChatNode` |
| 4. 写入 user input | `sessionStore.appendUserMessage` |
| 5. 记录来源 | `nodeStore.updateNodeSourceInfo(sourceType: 'note')` |
| 6. 应用模型 | `sessionStore.updateSessionModel` |
| 7. 刷新树 | `themeDetailControllerProvider.refresh` |
| 8. 跳转 | `context.push('/themes/.../nodes/...', extra: autoTriggerReply: true)` |

**为什么合并 title + body 作为 user input？**
- 让 LLM 看到完整上下文（"这是一个叫'XXX'的笔记讨论 XXX 主题"）
- 避免模型困惑"用户在说什么"
- `autoTriggerReply: true` 让用户进入页面就看到回复，不需要手动点发送

---

## 5. 实现文件清单

| 文件 | 内容 |
|------|------|
| `lib/ui/features/notes/note_detail_screen.dart` | `NoteDetailScreen` + `ThemeNoteListScreen`（与列表页同文件） |
| `lib/ui/features/notes/note_editor_screen.dart` | `NoteEditorScreen` |
| `lib/ui/features/notes/note_select_screen.dart` | `NoteSelectScreen` |
| `lib/ui/features/notes/node_location_picker.dart` | `showNodeLocationPicker` — 主题/父节点选择 |
| `lib/ui/core/widgets/markdown_toolbar.dart` | `MarkdownToolbar` 组件 |
| `lib/data/stores/note_store.dart` | `readBody / writeBody / renameNote / deleteNote / createNote / listNoteMetas` |
| `lib/ui/core/theme/app_colors.dart` | `AppColors.accent / surface / pageBg / textPrimary / textSecondary / textTertiary` |
| `lib/ui/core/theme/app_icons.dart` | `AppIcons.add / edit / check / copy / branch / delete / checkCircle` |
| `lib/ui/features/chat/chat_screen_launch_params.dart` | `ChatScreenLaunchParams(autoTriggerReply: true)` |
| `lib/l10n/app_zh.arb` · `app_en.arb` | `renameNote / titleHint / deleteNote / deleteNoteConfirmTitle / delete / deleteFailed / noTitle / startWriting / addedToNote / branchFailed` |

---

## 6. Test Plan

### 6.1 NoteDetailScreen
1. **阅读态**：`_body` 非空时显示 `GptMarkdown` 渲染
2. **空态**：`_body` 为空时显示 `l10n.noMessagesYet`
3. **编辑态**：点击 ✏️ → 切换为 `CupertinoTextField` + `MarkdownToolbar`
4. **复制**：点击 📋 → 内容写入剪贴板 → icon 变绿 2 秒 → 恢复
5. **复制空内容**：`_body.isEmpty` 时按钮不显示
6. **编辑态隐藏复制**：`_editing == true` 时复制按钮不显示
7. **重命名**：点击标题 → 弹 dialog → 输入新名 → `renameNote` + bump
8. **重命名空值**：trim 后为空视为取消
9. **重命名重复**：`newTitle == _title` 时不调用 `renameNote`
10. **删除**：点击 🗑️ → 弹 dialog → 确认 → `deleteNote` + `bump` + pop
11. **删除失败**：抛异常时 `ThkAlert` 提示，不 pop
12. **转对话**：点击 🌿 → 选位置 → 创建节点 → 跳转到对话页
13. **转对话空内容**：`_body.isEmpty` 时 `ThkAlert` 提示，终止流程
14. **版本号触发**：外部写操作后 `bump()` → 当前页 `addPostFrameCallback` 重新加载
15. **编辑态不重载**：`_editing == true` 时版本号变化不触发 `_loadBody()`
16. **SafeArea**：编辑时 `bottom: false`，让键盘顶起

### 6.2 NoteEditorScreen
1. **createMode**：进入页面立即创建空文件，title 空、body 空
2. **editMode**：进入页面读取已有 title/body 到 controllers
3. **自动保存**：onChanged 后 500ms 触发 `_saveNow`
4. **防抖**：连续输入只触发一次保存
5. **重试**：保存失败时 `_dirty = true`，下次输入重新尝试
6. **dispose 保存**：退出页面时 `_saveNow` + dispose controllers
7. **✓ 按钮**：点击立即保存 + pop
8. **标题字体**：28pt w600
9. **正文字体**：17pt 1.6
10. **无边框**：两个 `CupertinoTextField` 都 `border: null`
11. **占位符**：title 空时显示 `l10n.noTitle`，body 空时显示 `l10n.startWriting`
12. **搜索索引**：保存后 `upsertNote` 被调用，失败时静默

### 6.3 NoteSelectScreen
1. **追加到已有笔记**：`_appendToNote` 把文本拼接到 body 末尾（带 `\n\n` 分隔）
2. **空笔记追加**：原 body 为空时不带分隔符
3. **新建并追加**：`_createAndAppend` 创建空笔记后写入文本
4. **bump**：操作后 `noteListVersionProvider` 被 bump
5. **取消**：用户取消时不写入磁盘

### 6.4 转对话
1. **空内容拦截**：`_body.isEmpty` 时不进入 picker
2. **位置选择**：调 `showNodeLocationPicker`，`null` 时终止
3. **新节点创建**：`nodeStore.createChatNode` 调用参数正确
4. **user input**：合并 `'$_title\n\n$_body'` 写入 `appendUserMessage`
5. **来源标记**：`sourceType: 'note'`，`sourceExcerpt` 截断 80 字符
6. **provider 映射**：`_mapLegacyProviderToPresetId` 正确把 6 种枚举映射到 preset id
7. **模型应用**：`providerId != null && modelId != null` 时 `updateSessionModel`
8. **跳转**：`context.push` 带 `autoTriggerReply: true`

### 6.5 共享
1. **noteListVersionProvider**：所有写操作都通过它 bump
2. **搜索索引 fire-and-forget**：失败时不影响主流程
3. **大字体**：iOS Dynamic Type 放大时布局不溢出
4. **无障碍**：所有按钮和输入框都有语义标签

---

## 7. Assumptions

- 笔记大小 < 1MB（更大时 GptMarkdown 渲染可能卡顿，需要分页或懒加载）
- 用户不会同时打开同一笔记的多个编辑实例（最后一个写会覆盖前面的）
- "转对话" 总是创建新节点，不在原对话上续写
- 笔记内容是用户私有，不做协作/分享
- 搜索索引是 best-effort，失败不重试（依赖下次保存时覆盖）
- 不做笔记的全选复制（独立于"复制全部"功能 — 那个复制的是 raw body）
- 不做笔记的版本历史
- 不做笔记的回收站（删除即彻底）

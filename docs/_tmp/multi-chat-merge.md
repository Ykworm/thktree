# 多 Chat 合并功能 — Brainstorming 草稿

> 状态：writing-plans 完成，待用户确认后进入实现
> 日期：2026-07-09
> 任务类型：普通功能
> 模式：freemode（在 dev 上直接改）

## 功能概述

选择最多 3 个 chat node，合并它们的 title + 完整对话历史，创建一个新的 chat node。合并内容作为新 chat 的首条 user message（`autoTriggerReply=false`，AI 不自动回复），用户输入新问题后一起发给 AI 继续对话。

## 设计决策

| 决策点 | 结论 | 理由 |
|--------|------|------|
| content 指什么 | 完整对话历史（session.md 全量） | 压缩没意义，参考 max 模式全量上下文优势 |
| 是否压缩 | 不压缩，全量注入 | 保留原始信息 |
| 顺序 | 按用户选择顺序，不做额外排序 | LLM 能处理，怎么实现容易怎么做 |
| 新 chat title | 用户自己起 | 目的性强，AI 生成不靠谱（至少 3 个 topic） |
| 注入方式 | 作为已发送的 user message（非预填输入框） | 复用现有 showBranchFlow 机制 |
| autoTriggerReply | false | 等用户输入新问题一起发，少一轮废话 |
| image 处理 | 第一版不显示，body 标注 `[图片]` | 现有消息格式一条只支持一张 imagePath，多图需扩展，后续迭代 |
| 可选 node 类型 | 仅 kind=chat | summary 无对话历史 |

## 合并消息格式

纯文本，保留角色和模型名，用来源标题分隔：

```
## 来自「title1」
User：什么是决策树？
deepseek-chat：决策树是一种监督学习算法...
User：那随机森林呢？
deepseek-chat：随机森林是...

## 来自「title3」
User：...
kimi：...

## 来自「title2」
User：...
deepseek-chat：...
```

生成逻辑：
- `role == user` → `User：${body}`
- `role == assistant` → `${modelId ?? 'Assistant'}：${body}`
- 有 image 的消息 → body 中标注 `[图片]`
- modelId 暂用原值（如 `deepseek-chat`），后续可加 modelId → 友好显示名映射

## UIUX 设计

### 双入口

| 入口 | 进入方式 | 默认模式 |
|------|----------|----------|
| Tree page | more sheet →「合并 chat」 | 多选模式 |
| Chat page | more → 查看树（FullTreeScreen）→ 顶部「多选」按钮 | 浏览模式 |

两个入口共用同一套多选状态 + 合并流程。

### FullTreeScreen 模式切换

- **浏览模式**（默认）：点 node → 进入 chat 页面（现有行为不变）
- **多选模式**：点 node → 勾选/取消勾选
- 从「合并 chat」入口进入 → 自动激活多选模式
- 从「查看树」入口进入 → 默认浏览，顶部有「多选」按钮可切换
- 多选模式下点「取消」退回浏览模式

### 多选模式 UI

```
┌─────────────────────────────────┐
│ 最多选择 3 个 chat 进行合并 · 已选 2/3 │  ← 顶部提示条（常驻）
├─────────────────────────────────┤
│  ☑ title1                       │
│  ☐ title2 (summary, 不可选/置灰)  │
│  ☑ title3                       │
│  ☐ title4                       │
│  ...                            │
├─────────────────────────────────┤
│  已选 2/3        [合并&创建新 chat] │  ← 底部操作栏
│                 [取消]              │
└─────────────────────────────────┘
```

- 选第 4 个时拒绝 + toast「最多选 3 个」
- summary 类型不可选（置灰或不显示 checkbox）

### 两步流程

```
Step 1: FullTreeScreen（多选模式）
  ├─ 顶部提示条："最多选择 3 个 chat 进行合并 · 已选 x/3"
  ├─ 勾选 ≤3 个 chat node
  ├─ 底部：「已选 x/3」+「合并&创建新 chat」+「取消」
  │
  ↓ 点击「合并&创建新 chat」
  │
Step 2: 新 page（title + 位置合一）
  ├─ 左上角：返回
  ├─ 上方：输入 title（必填，空则 Submit 不可点）
  ├─ 下方：mini tree 选择挂载位置（单选，默认根节点）
  ├─ 底部：Submit
  │
  ↓ Submit
  │
  创建新 chat → 合并内容写入 session.md → 导航到新 chat
```

### 新 chat 创建后

- session.md 里有合并内容作为首条 user message
- `autoTriggerReply=false`，AI 不自动回复
- 用户看到合并的大 message，在输入框输入新问题
- 发送时 AI 把合并 message + 新问题一起处理

## 技术实现

### 复用现有机制

| 机制 | 说明 |
|------|------|
| `showBranchFlow` | createChatNode + appendUserMessage + autoTriggerReply=false，核心流程直接复用 |
| `buildConversationTranscript` | 现有合并 transcript 逻辑，扩展数据源即可 |
| `SessionStore.readSession(nodeId)` | 读取各 node 的完整对话历史，返回 `SessionDocument{frontmatter, messages}` |
| `FullTreeScreen` | 扩展为支持多选模式 |

### 需要新增

1. **FullTreeScreen 多选模式**
   - 多选状态管理（Riverpod NotifierProvider）
   - checkbox UI（每个 `_FullTreeNodeRow` 加选择圈）
   - 顶部提示条 + 底部操作栏
   - summary 类型过滤
   - 模式切换逻辑

2. **合并逻辑**
   - `mergeChatTranscripts(List<NodeEntity> nodes)` → 读各 node session.md → 拼接结构化文本
   - 格式化：`## 来自「title」\n User：xxx\n modelId：xxx`

3. **合并确认 page（Step 2）**
   - title 输入框
   - mini tree 位置选择器（单选父节点）
   - Submit 按钮

4. **入口**
   - Tree page more sheet 加「合并 chat」选项
   - FullTreeScreen 顶部加「多选」按钮

### 不需要改的

- ChatComposer（不用预填）
- ChatScreenLaunchParams（现有字段够用）
- session.md 格式（appendUserMessage 已有）

## 待确认 / 后续迭代

- [ ] modelId → 友好显示名映射（第一版用原值）
- [ ] image 显示（第一版标注 `[图片]`）
- [ ] 合并消息的 token 量估算提示（如果 3 个对话都很长）

---

## 实现计划（Writing Plans）

> 所有代码和文档改动都在 dev 分支上，不走 worktree。

### 改动总览

| # | 文件 | 改动类型 | 说明 |
|---|------|----------|------|
| 1 | `lib/ui/features/themes/full_tree_screen.dart` | 修改 | 加多选模式 |
| 2 | `lib/data/services/session_markdown.dart` | 新增函数 | `buildMergedTranscript` |
| 3 | `lib/ui/features/themes/merge_chat_confirm_screen.dart` | 新建 | Step 2 确认 page |
| 4 | `lib/ui/features/themes/theme_detail_screen.dart` | 修改 | more sheet 加入口 |
| 5 | `lib/l10n/app_*.arb` | 修改 | 新增文案 |

### Step 1：合并逻辑（纯函数，无 UI 依赖，先写先测）

**文件**：`lib/data/services/session_markdown.dart`

新增函数：

```dart
String buildMergedTranscript(List<({String title, SessionDocument document})> sources) {
  final buffer = StringBuffer();
  for (var i = 0; i < sources.length; i++) {
    final source = sources[i];
    if (i > 0) { buffer.writeln(); buffer.writeln(); }
    buffer.writeln('## 来自「${source.title}」');
    buffer.writeln();
    for (final message in source.document.messages) {
      final body = message.body.trim();
      if (body.isEmpty) continue;
      final label = switch (message.role) {
        SessionRole.user => 'User',
        SessionRole.assistant => message.modelId ?? 'Assistant',
        SessionRole.system => 'System',
      };
      // image 标注
      final bodyWithImage = message.imagePath != null ? '[图片] $body' : body;
      buffer.writeln('$label：$bodyWithImage');
    }
  }
  return buffer.toString();
}
```

与现有 `buildConversationTranscript` 并存，不改动原函数（它被 `showBranchFlow` 使用）。

### Step 2：FullTreeScreen 多选模式

**文件**：`lib/ui/features/themes/full_tree_screen.dart`

**2.1 构造参数**

```dart
class FullTreeScreen extends ConsumerStatefulWidget {
  final String themeId;
  final String? currentNodeId;
  final bool initialMultiSelect;  // 新增，默认 false
  // ...
}
```

**2.2 State 字段**

```dart
bool _multiSelectMode = false;
final List<String> _selectedNodeIds = [];  // List 保持选择顺序，≤3
```

`initState` 中 `_multiSelectMode = widget.initialMultiSelect`。

**2.3 导航栏 trailing**

- 浏览模式：trailing 显示「多选」按钮（文字按钮），点击切到多选模式
- 多选模式：trailing 显示「完成」按钮，点击切回浏览模式

**2.4 `_FullTreeNodeRow` 改造**

新增参数：
```dart
final bool isMultiSelectMode;
final bool isSelected;
final ValueChanged<String>? onToggleSelect;  // nodeId
```

- `isMultiSelectMode == true` 时：
  - `onTap` → `onToggleSelect?.call(node.nodeId)`（不导航）
  - 左侧显示选择圈（☑ / ☐）
  - `node.kind != chat` → 选择圈置灰，不可点
- `isMultiSelectMode == false` 时：保持现有行为（`onTap` → 导航到 chat）

**2.5 顶部提示条**

多选模式时，导航栏下方插一行提示：
```
"最多选择 3 个 chat 进行合并 · 已选 {_selectedNodeIds.length}/3"
```

**2.6 底部操作栏**

多选模式时，底部固定操作栏：
- 左：「已选 x/3」
- 中：「取消」（退回浏览模式，清空选择）
- 右：「合并&创建新 chat」（`_selectedNodeIds.isNotEmpty` 时可点）

点击「合并&创建新 chat」→ 导航到 `MergeChatConfirmScreen`，传入选中的 node 列表 + themeId。

**2.7 选择逻辑**

```dart
void _toggleSelect(String nodeId) {
  final node = _allNodes.firstWhere((n) => n.nodeId == nodeId);
  if (node.kind != NodeKind.chat) return;  // summary 不可选
  if (_selectedNodeIds.contains(nodeId)) {
    _selectedNodeIds.remove(nodeId);
  } else {
    if (_selectedNodeIds.length >= 3) {
      // toast: 最多选 3 个
      return;
    }
    _selectedNodeIds.add(nodeId);
  }
  setState(() {});
}
```

### Step 3：MergeChatConfirmScreen（Step 2 page）

**文件**：`lib/ui/features/themes/merge_chat_confirm_screen.dart`（新建）

**构造参数**：
```dart
class MergeChatConfirmScreen extends ConsumerStatefulWidget {
  final String themeId;
  final List<NodeEntity> selectedNodes;  // 已选的 chat node（按选择顺序）
}
```

**页面结构**：
```
CupertinoPageScaffold
├─ ThkNavBar.inline(title: "合并 & 创建", leading: 返回)
├─ body: ListView
│   ├─ TextField: 输入新 chat title（必填）
│   ├─ "选择挂载位置" 标题
│   └─ 递归 tree widget（单选父节点，默认根节点）
└─ 底部: Submit 按钮（title 为空时禁用）
```

**tree 位置选择器**：
- 用 `themeDetailControllerProvider(themeId)` 获取 nodes
- 递归渲染 tree（简化版，类似 `_FullTreeNodeRow` 但单选）
- 点击 node → 设为 `_selectedParentId`
- 顶部多一个「根节点（顶层）」选项，`_selectedParentId = null`

**Submit 逻辑**：
```dart
Future<void> _submit() async {
  // 1. 读取各 node 的 session
  final sources = <({String title, SessionDocument document})>[];
  for (final node in widget.selectedNodes) {
    final doc = await sessionStore.readSession(node.nodeId);
    sources.add((title: node.title, document: doc));
  }
  // 2. 合并
  final mergedText = buildMergedTranscript(sources);
  // 3. 创建新 chat node
  final newNode = await nodeStore.createChatNode(
    themeId: widget.themeId,
    themePath: themePath,
    parentId: _selectedParentId,
    title: _titleController.text,
  );
  // 4. 写入合并内容作为首条 user message
  await sessionStore.appendUserMessage(nodeId: newNode.nodeId, content: mergedText);
  // 5. 刷新 tree 数据
  ref.invalidate(themeDetailControllerProvider(widget.themeId));
  // 6. 导航到新 chat（autoTriggerReply: false）
  context.pushReplacement('/themes/${widget.themeId}/nodes/${newNode.nodeId}',
    extra: ChatScreenLaunchParams(title: _titleController.text, autoTriggerReply: false));
}
```

### Step 4：入口接入

**4.1 Tree page more sheet**

**文件**：`lib/ui/features/themes/theme_detail_screen.dart`，`_showOverflowMenu` 方法

在 `actions` 列表中新增：
```dart
CupertinoActionSheetAction(
  onPressed: () {
    Navigator.of(context).pop();
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => FullTreeScreen(
        themeId: widget.themeId,
        currentNodeId: null,
        initialMultiSelect: true,  // 直接进多选模式
      ),
    ));
  },
  child: Text(l10n.mergeChats),
),
```

**4.2 FullTreeScreen 顶部「多选」按钮**

已在 Step 2.3 中实现。从 chat page more → 查看树进入时默认浏览模式，用户点「多选」切换。

### Step 5：l10n 文案

**文件**：`lib/l10n/app_zh.arb` + `lib/l10n/app_en.arb`

新增 key：
- `mergeChats` — "合并 Chat" / "Merge Chats"
- `mergeChatHint` — "最多选择 3 个 chat 进行合并" / "Select up to 3 chats to merge"
- `selectedCount` — "已选 {count}/3" / "{count}/3 selected"
- `mergeAndCreate` — "合并 & 创建新 Chat" / "Merge & Create New Chat"
- `selectMountLocation` — "选择挂载位置" / "Select Mount Location"
- `rootNode` — "根节点（顶层）" / "Root (Top Level)"
- `maxSelectionReached` — "最多选 3 个" / "Maximum 3 selections"

### 验收方式

**编译 + 静态检查**：
- `flutter analyze` 无新增 error/warning
- 编译通过

**手工验证**（关键路径）：
1. Tree page more →「合并 chat」→ FullTreeScreen 自动进多选模式
2. 勾选 2-3 个 chat node，验证 summary 不可选
3. 选第 4 个 → toast「最多选 3 个」
4. 点「合并&创建新 chat」→ Step 2 page
5. 输入 title + 选挂载位置 → Submit
6. 新 chat 打开，合并消息显示在对话区（单条 user message，纯文本带角色标注）
7. AI 不自动回复
8. 输入新问题发送 → AI 基于合并内容 + 新问题回复
9. Chat page more → 查看树 → 顶部「多选」按钮 → 同流程可走通
10. 多选模式「取消」→ 退回浏览模式，选择清空

### 实现顺序

1. Step 1：合并逻辑（`buildMergedTranscript`）— 纯函数，无依赖
2. Step 5：l10n 文案 — 后续步骤依赖
3. Step 2：FullTreeScreen 多选模式 — 主要 UI 工作量
4. Step 3：MergeChatConfirmScreen — Step 2 page
5. Step 4：入口接入 — 接上即可
6. 验收：编译 + 手工验证

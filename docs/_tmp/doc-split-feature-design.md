# 文档拆分功能设计（Doc Split）

> 状态：草稿
> 日期：2026-06-30
> 方案：方案 C — Chat 驱动 + Markdown 解析

## 1. 功能概述

用户在某个 theme 下导入一段 Markdown 文本，LLM 自动对其进行树状逻辑拆分，输出多个拆分维度供用户选择。用户确认后，按选定维度将树结构物化为 theme 下的真实 chat 节点。每个节点有 title 和 content，用户进入节点后 content 作为首条 user message 显示，LLM 自动回复。

## 2. UX 流程

```
ThemeDetailScreen（右上角菜单）
  ↓ 点击「导入文档拆分」
全屏编辑页面（DocSplitInputScreen）— 编辑器铺满 title bar 与 tab bar 之间
  ↓ 用户粘贴 MD 文本 → 点击确认
创建 chat 节点（autoTriggerReply: false, sourceType: 'docSplit'）
  ↓ MD 文本写入 session.md 作为 user message
跳转 ChatScreen
  ↓ 用户看到 MD 文本已显示（作为已发送消息）
用户发送指令（如"请按主题维度拆分"）
  ↓ LLM 收到完整上下文（MD 文本 + 用户指令）
LLM 返回多个拆分维度 + 树结构预览
  ↓ 用户选择/调整（在 Chat 中自然对话）
用户从右上角菜单点「提交树结构」
  ↓ App 解析最新 assistant 消息中的树
批量创建节点到 theme 下
  ↓ 刷新 ThemeDetailScreen
```

### 2.1 关键交互决策

| 决策点 | 选择 | 理由 |
|--------|------|------|
| 入口位置 | ThemeDetailScreen 右上角菜单 | 与现有操作入口风格一致 |
| MD 文本发送方式 | 作为 user message 写入，不触发 LLM 回复 | 用户可先编辑上下文再发送 |
| 提交按钮位置 | ChatScreen 右上角更多菜单（ThkGridBottomSheet） | 避免底部误触 |
| 预览对话处理 | 提交后不保留 | 只保留物化的节点树 |
| 节点进入行为 | 自动触发 LLM 回复 | 用户可立即基于 content 展开对话 |

## 3. LLM Prompt 设计

### 3.1 System Prompt 片段

当检测到 `sourceType: 'docSplit'` 节点时，追加 system prompt 指令：

```
你是一个文档结构分析助手。用户会提供一段文档文本，你需要：
1. 分析文档内容，提出 2-3 种不同的拆分维度（如按主题、按逻辑结构、按时间线等）
2. 每种维度展示完整的树结构
3. 树结构使用以下 Markdown 格式输出：

## 维度A：[维度名称]
[维度说明]

- **[节点标题]**
  [节点内容：该节点的详细说明，2-4句话概括核心信息]
  - **[子节点标题]**
    [子节点内容]
  - **[子节点标题]**
    [子节点内容]
- **[节点标题]**
  [节点内容]

4. 每个维度之间用分隔线（---）隔开
5. 节点标题用加粗（**标题**），内容紧跟标题后（不加粗，缩进对齐）
6. 缩进表示层级关系（2空格 = 一级子节点）
```

### 3.2 用户后续指令

用户可以自然语言与 LLM 对话：
- "按维度A拆分" → LLM 详细展开维度A的树
- "维度B的第二层太细了，合并一下" → LLM 调整
- "我觉得应该这样分：..." → LLM 按用户思路重新拆分
- "就按这个来" → LLM 确认最终结构

## 4. 树解析逻辑（TreeParser）

### 4.1 输入

最近一条 assistant 消息的 Markdown 文本。

### 4.2 解析规则

```
## 维度X：名称          → 维度标题（解析时忽略，用户已选定）
- **标题A**             → 节点 title="标题A"，depth=0
  内容文本...           → 节点 content="内容文本..."
  - **子标题A1**        → 节点 title="子标题A1"，depth=1（parent=标题A）
    子内容...           → 节点 content="子内容..."
- **标题B**             → 节点 title="标题B"，depth=0
  内容文本...           → 节点 content="内容文本..."
```

### 4.3 解析输出

```dart
class ParsedTreeNode {
  final String title;
  final String content;
  final int depth;
  final List<ParsedTreeNode> children;
}
```

### 4.4 错误处理

- 无法解析 → toast "无法解析树结构，请让 LLM 重新输出标准格式"
- 树结构为空 → toast "未检测到有效节点"
- content 为空 → 使用 title 作为 content 的降级处理

## 5. 节点物化逻辑（DocSplitService）

### 5.1 流程

```
1. 从 session.md 读取最后一条 assistant 消息
2. TreeParser 解析 → List<ParsedTreeNode>
3. 深度优先遍历：
   a. nodeStore.createChatNode(themeId, themePath, parentId, title)
   b. sessionStore.appendUserMessage(nodeId, content)
   c. nodeStore.updateNodeSourceInfo(nodeId, sourceExcerpt, sourceType: 'docSplit')
   d. 继续创建子节点（parentId = 当前节点 nodeId）
4. 删除 docSplit 预览节点（nodeStore.deleteNode + 删除 nodeDir）
5. themeDetailController.refresh()
6. Navigator.pop() 回到 ThemeDetailScreen
```

### 5.2 数据字段

| 字段 | 值 | 说明 |
|------|---|------|
| kind | `chat` | 复用现有类型 |
| sourceType | `docSplit` | 新增来源标记 |
| sourceExcerpt | MD 文本前 80 字 + "..." | 记录来源 |
| title | 解析得到的节点标题 | — |
| session.md user message | LLM 生成的 content | 用户进入节点后可见 |

## 6. 需要改动的文件

### 6.1 新增文件

| 文件 | 职责 |
|------|------|
| `lib/data/services/tree_parser.dart` | 解析 LLM 输出的 Markdown 树结构 |
| `lib/data/services/doc_split_service.dart` | 协调解析 + 批量创建节点 |

### 6.2 修改文件

| 文件 | 改动 |
|------|------|
| `lib/ui/features/themes/theme_detail_screen.dart` | 菜单新增「导入文档拆分」入口 |
| `lib/ui/features/chat/chat_screen.dart` | 右上角菜单新增「提交树结构」，检测 docSplit sourceType |
| `lib/data/stores/node_store.dart` | createChatNode 支持 docSplit 流程 |
| `lib/domain/node.dart` | sourceType 新增 'docSplit' 枚举值 |
| `lib/ui/features/doc_split/doc_split_input_screen.dart` | 新增全屏文本输入页面 |
| `lib/l10n/` | 新增相关 l10n key |

### 6.3 不改动的文件

- `ThemeDetailController` — 复用现有 refresh() 方法
- `SessionStore` — 复用现有 appendUserMessage()
- `NodeStore` — createChatNode 签名不变，只在调用层传不同参数

## 7. 边界条件

1. **MD 文本过长** — 建议限制在合理范围内（如 50K 字符），超长提示用户分段
2. **LLM 输出格式不稳定** — TreeParser 需要容错，支持多种缩进格式
3. **深度嵌套** — 建议限制最大深度为 4 层（H1-H4），超过截断
4. **节点数量** — 单次物化建议限制 50 个节点以内
5. **并发创建** — 批量创建使用事务或顺序执行，避免 ID 冲突

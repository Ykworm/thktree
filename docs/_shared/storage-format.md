# storage-format.md — 磁盘 + SQLite 存储契约（权威）
本文档定义“数据怎么存、怎么解析、怎么迁移”。实现端（写入/解析/测试/重建索引）只认这一份。
产品需求与流程见仓库根目录 REQUIREMENTS.md。

## 0. 总原则

- Markdown 文件是正文真相源（source of truth）
- SQLite 只做索引/检索/性能加速，可随时删除并从磁盘重建
- 允许崩溃/断电后仍可解析：文件必须有明确“中间态”表示（streaming/error）
- 单写者：同一时间只允许一个写入流程改动同一个 `.md` 文件（包括流式）

---

## 1. 目录结构（磁盘契约）

数据根目录记为 `{root}`（平台具体路径由实现决定）。

```text
{root}/
  themes/
    {themeId}/
      theme.meta.json
      nodes/
        {nodeId}/
          node.meta.json
          session.md
          context-summary.md          # 可选：存在表示该 node 有已确认总结
      notes/
        {noteId}.md
  index.sqlite                         # 可选：SQLite 索引
```

约束：
- Theme 必须位于 `themes/{themeId}/`
- Node 必须位于 `themes/{themeId}/nodes/{nodeId}/`
- Note 必须位于 `themes/{themeId}/notes/{noteId}.md`

---

## 2. 通用约定

### 2.1 编码与换行

- 所有文本文件 UTF-8，无 BOM
- 换行统一 `\n`

### 2.2 时间格式（必须）

- 统一使用 UTC ISO8601：`YYYY-MM-DDTHH:mm:ss.SSSZ`
- 示例：`2026-05-25T12:01:03.120Z`

### 2.3 ID 规则（必须）

所有 ID 在同一 `{root}` 内全局唯一，且可离线生成。

默认采用 ULID（26 位 Crockford Base32，大写），便于排序与 rg：
- themeId：`thm_<ULID>`
- nodeId：`nd_<ULID>`
- noteId：`nt_<ULID>`
- msgId：`msg_<ULID>`
- requestId：`req_<ULID>`

示例：
- `msg_01J8Z9128M0X0Z8XJ2A1C4D3E5`

### 2.4 原子写（必须）

- 覆盖写：写入 `*.tmp` 同目录临时文件后 `rename` 原子替换
- 追加写（session 流式）：仍需保证崩溃后可解析；不得出现“写一半 frontmatter/标题行”的状态

---

## 3. JSON 元数据文件

### 3.1 theme.meta.json（必须）

路径：`themes/{themeId}/theme.meta.json`

```json
{
  "schema": "theme_meta/v1",
  "themeId": "thm_01J8Z8T3C3P7W6XK9YB2V2J0QK",
  "title": "My Theme",
  "createdAt": "2026-05-25T12:00:00.000Z",
  "updatedAt": "2026-05-25T12:00:00.000Z"
}
```

字段：
- schema：固定 `theme_meta/v1`
- themeId：必填
- title：必填，可修改
- createdAt/updatedAt：必填；任何可见字段变化必须更新 updatedAt

### 3.2 node.meta.json（必须）

路径：`themes/{themeId}/nodes/{nodeId}/node.meta.json`

```json
{
  "schema": "node_meta/v1",
  "themeId": "thm_01J8Z8T3C3P7W6XK9YB2V2J0QK",
  "nodeId": "nd_01J8Z8W2K4T9Z5D1H3G0W7N2Q9",
  "parentId": null,
  "kind": "chat",
  "title": "New Chat",
  "createdAt": "2026-05-25T12:01:00.000Z",
  "updatedAt": "2026-05-25T12:01:00.000Z"
}
```

字段：
- schema：固定 `node_meta/v1`
- themeId/nodeId：必填
- parentId：可为 null（Theme 下根节点）
- kind：枚举 `chat` | `summary`
- title：必填，可修改
- createdAt/updatedAt：必填

---

## 4. session.md（对话正文真相源）

路径：`themes/{themeId}/nodes/{nodeId}/session.md`

### 4.1 文件结构（必须）

- 顶部 YAML frontmatter（必须存在）
- 之后由 0..N 个“消息块”组成
- 消息块 = “标题行（单行） + 正文（多行 Markdown）”

### 4.2 Frontmatter：session/v1（必须）

```markdown
---
schema: session/v1
themeId: "thm_..."
nodeId: "nd_..."
kind: "chat"
parentId: null
title: "..."
createdAt: "2026-05-25T12:01:00.000Z"
updatedAt: "2026-05-25T12:01:00.000Z"
---
```

字段：
- schema：固定 `session/v1`
- themeId/nodeId：必填
- kind：`chat` | `summary`（必须与 node.meta.json 一致）
- parentId：必须与 node.meta.json 一致
- title：必填，可修改
- createdAt/updatedAt：必填；追加消息或修改 title 必须更新 updatedAt

### 4.3 消息块标题行（必须）

标题行语法（必须从行首开始）：

```
## <role> · <timestamp> · <msgId>[ · <modelId>]
```

- role：枚举 `user` | `assistant` | `system`
- timestamp：见 2.2
- msgId：见 2.3
- modelId：**可选**（仅 assistant 消息）；记录回复该消息的 LLM 模型 ID（如 `gpt-4o`、`deepseek-chat`）。向后兼容：旧消息无此字段时解析为 `null`

分隔符必须是：空格 + `·` + 空格（即 ` ␠·␠`）。

正文边界：
- 正文从标题行下一行开始
- 到下一个符合标题行语法的行之前结束（或 EOF）

### 4.4 流式中间态（必须）

当 assistant 回复尚未完成时，在该 assistant 消息块正文最后追加独占一行：

```
<!-- streaming -->
```

规则：
- 该标记必须是块内最后一行（除换行外）
- 流结束后必须删除该行，文件最终态不含该行
- 若崩溃停留在 streaming：解析器视该块 `status=streaming`，UI 可提示"未完成，可重试"

**作为后台恢复入口**：该标记同时承担"后台中断恢复"的角色。`SessionStore.findInterrupted()` 扫描磁盘 session.md 列表，以 `<!-- streaming -->` 标记为"未完成"判定依据。切回前台 / 冷启动 / App 从挂起恢复时调用，结果作为 `ChatTaskService.resumeInterrupted()` 的入参。具体策略见 [ADR-015](../DECISIONS.md#adr-015-ios-llm-流式中断恢复策略--disk-first--自动重发--30s-边界)。

**与错误态区分**：仅 `<!-- streaming -->` 是"未完成 / 可恢复"，`<!-- error: <code> -->` 属于"已结束 / 不可恢复"，不进入 `findInterrupted()` 扫描结果。

### 4.4.1 推理内容（reasoning，2026-07-06 起支持）

当 assistant 消息来自支持深度思考的模型（详见 [ADR-022](../DECISIONS.md#adr-022-per-session-深度思考开关--双-modelcapability-区分)），且产生了可读的推理 / 思维链内容时，正文按以下结构组织：

```markdown
<!-- reasoning:start -->
让模型先想想这道题该怎么解……
<!-- reasoning:end -->

这里是模型最终生成给用户的回答正文。
```

规则（必须）：
- 推理内容块必须从标题行下一行开始，依次为 `<!-- reasoning:start -->` → 推理正文（多行 Markdown）→ `<!-- reasoning:end -->`，独占一行分别位于块首尾。
- 推理块与正文块之间空一行（Markdown paragraph 间距）。
- 三个 marker **必须独占一行**，不得缩进、不得前后拼接其他字符。
- 旧消息无 reasoning 标记块时解析为 `reasoning: null`，向后兼容。
- 解析器（`session_markdown.dart::_extractReasoningAndBody`）按顺序剥外层 marker，提取 reasoning 与 body 两条独立的文本字段。
- 重建（`serializeSessionMessageBody`）按 `reasoning != null` 决定是否插入 marker 块；body 为空时不写入 `<空正文>` 哨兵，直接结尾换行。
- UI 端 `MessageBubble` 渲染折叠的"思考过程"展开块（已有功能，由 `SessionMessage.reasoning` 字段驱动）。

### 4.5 错误态（必须）

当一次请求失败且该 assistant 消息无法完成时，将 streaming 标记替换为：

```
<!-- error: <code> -->
```

`<code>` 建议枚举：
- `network` | `timeout` | `cancelled` | `server` | `parse` | `unknown`

规则：
- 错误态消息块必须保留（不删除）
- 后续重试必须生成“新的 assistant 消息块”（新的 msgId），旧块保持可追溯

### 4.6 完整示例

```markdown
---
schema: session/v1
themeId: "thm_01J8Z8T3C3P7W6XK9YB2V2J0QK"
nodeId: "nd_01J8Z8W2K4T9Z5D1H3G0W7N2Q9"
kind: "chat"
parentId: null
title: "New Chat"
createdAt: "2026-05-25T12:01:00.000Z"
updatedAt: "2026-05-25T12:01:03.120Z"
---

## user · 2026-05-25T12:01:00.000Z · msg_01J8Z90Z5H7H7G1W5Q2QH1B9Y8
你好，帮我设计一下数据格式。

## assistant · 2026-05-25T12:01:03.120Z · msg_01J8Z9128M0X0Z8XJ2A1C4D3E5 · gpt-4o
好的，我们先确定目录结构……
```

---

## 5. context-summary.md（已确认总结）

路径：`themes/{themeId}/nodes/{nodeId}/context-summary.md`

语义：
- 文件存在表示该 node 有一份“已确认总结”
- 正常 chat 发请求时注入其 body（而不是注入祖先全量对话）

### 5.1 文件结构（必须）

- 顶部 YAML frontmatter（必须）
- body 为已确认总结正文（Markdown）

```markdown
---
schema: context_summary/v1
themeId: "thm_..."
nodeId: "nd_..."
approvedAt: "2026-05-25T12:10:00.000Z"
stale: false
sourceUpToMsgId: "msg_..."
---
这里是已确认总结正文（Markdown）。
```

字段：
- schema：固定 `context_summary/v1`
- themeId/nodeId：必填
- approvedAt：必填（用户确认采用时间）
- stale：必填，默认 false
- sourceUpToMsgId：必填；用于“总结覆盖到哪条消息之前/截至哪条消息”，辅助 stale 判定与引用

stale 最低要求（必须做到）：
- 任一相关上游对话追加新消息后，将 stale 置为 true（UI 提示但不强制阻断发送）

---

## 6. notes/{noteId}.md（笔记真相源）

路径：`themes/{themeId}/notes/{noteId}.md`

### 6.1 文件结构（必须）

- 顶部 YAML frontmatter（必须）
- body 为笔记正文（Markdown，可累积追加）

```markdown
---
schema: note/v1
themeId: "thm_..."
noteId: "nt_..."
createdAt: "2026-05-25T12:05:00.000Z"
updatedAt: "2026-05-25T12:05:00.000Z"
sourceNodeId: "nd_..."
spawnedNodeId: null
---
摘录内容或备忘正文……
```

字段：
- schema：固定 `note/v1`
- themeId/noteId：必填
- createdAt/updatedAt：必填
- sourceNodeId：可选
- spawnedNodeId：可选（场景 A 成功发起对话后写入）

### 6.2 themeId 可变性（2026-07-03 新增）

`themeId` 在创建时固定，但支持跨主题转移（`NoteStore.moveNote()`）：
- 文件物理移动到目标主题的 `notes/` 目录
- frontmatter 中 `themeId` 更新为目标主题 ID
- 原文件删除

注意：`noteId` 全局唯一，跨主题转移不改变 `noteId`。

---

## 7. SQLite 索引（可重建）

推荐路径：`{root}/index.sqlite`

约束：
- SQLite 必须可完全从磁盘重建
- SQLite 不得成为唯一真相源

### 7.1 基础表（建议）

themes / nodes / notes / messages_meta（列名可按实现调整，但主键/对齐键不能变）

对齐键（必须）：
- theme：themeId
- node：nodeId
- note：noteId
- message：msgId（并且必须保存 nodeId/themeId）

### 7.2 全局搜索（建议）

做法：SQLite 用 FTS（若可用）存可搜索文本。

建议使用 FTS5（如运行环境支持）：
- entityType：`message` | `note` | `summary`
- entityId：msgId | noteId | nodeId
- themeId、nodeId（可为空）
- content（正文纯文本或 Markdown）

若 FTS5 不可用可降级为 LIKE，但契约目标仍是“从索引查到定位信息，再回到磁盘文件展示”。

---

## 8. Reindex（重建索引）必须支持

实现必须提供“全量重建”能力：
1. 扫描 themes/*/theme.meta.json 写入 themes
2. 扫描 nodes/*/node.meta.json 写入 nodes（含 parentId/kind/title/path）
3. 解析每个 session.md：
   - 验证 schema
   - 逐条解析消息块标题行 + 正文
   - 生成 messages_meta（role、createdAt、preview、charCount 等）
   - 若启用搜索：写入 FTS
4. 解析 notes/*.md：写入 notes；若启用搜索写入 FTS
5. 若存在 context-summary.md：写入/更新 summary 索引

一致性要求：
- 同一 msgId 不允许出现在不同 nodeId/themeId
- streaming/error 块也必须可解析并可索引（至少能显示/定位）

---

## 9. 版本升级（schema 迁移）

- 每种文件用 `schema: name/vN` 明确版本
- 新增/变更格式必须：
  1) 在本文档补全 v(N+1) 定义
  2) 给出 vN -> v(N+1) 迁移算法（磁盘与索引）
  3) 指定迁移触发策略（启动检测/手动触发）

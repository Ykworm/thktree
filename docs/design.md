# 轻量 SDD（MVP）— ThkTree

本文件描述“代码怎么组织、关键状态机怎么跑、跨模块契约怎么对齐”。存储格式权威见 docs/storage-format.md；产品需求见 REQUIREMENTS.md。

---

## 1. 目标与非目标

目标：
- 确立模块边界与责任，避免实现分叉
- 固定关键状态机：流式写入、错误/重试、重建索引、stale
- 明确跨层契约：ID、时间、路径、对齐键、单写者

非目标：
- 不写 UI 细节与视觉稿
- 不展开业务需求（以 REQUIREMENTS.md 为准）

---

## 2. 模块边界（建议目录）

建议按职责拆分（文件/目录名可按 Flutter 习惯调整，但边界不要混）：

- domain
  - entities：Theme / Node / Note / Message（纯数据结构）
  - ids：ULID/ID 生成与校验
  - errors：统一错误类型（network/timeout/cancelled/parse/…）
- storage
  - fs_layout：路径计算（{root}/themes/...）
  - md_parser：session.md / note.md / context-summary.md 解析器（只认 storage-format）
  - md_writer：原子写与追加写、streaming/error 状态管理（只认 storage-format）
  - meta_json：theme.meta.json / node.meta.json 读写
- index
  - sqlite：schema 管理、事务封装、升级策略（可 drop + reindex）
  - reindex：磁盘扫描 → SQLite 重建
  - search：FTS5 可用则用 FTS5，否则降级 LIKE
- llm
  - deepseek_client：HTTP + SSE 解析、请求/响应模型
  - prompt_builder：system + context-summary + 本节点历史
  - streaming_controller：将 SSE token 驱动 md_writer（单写者）
- state
  - riverpod providers：围绕用例（用例层）组合 storage/index/llm
- ui
  - screens：Theme 列表、树、节点详情（对话/子孙/汇总）、笔记、设置、总结向导
  - router：go_router

---

## 3. 核心写入与并发契约（单写者）

约束：
- 同一 node 的 session.md 同时只能有一个写入流程（发送、流式、重试、错误落盘）
- 任一时刻 app 内最多一个“写入者”持有某个 file lock（实现可用 mutex/队列）

建议实现方式：
- 每个 nodeId 一个队列（顺序执行任务）
- 流式期间禁止再次发送（UI disable），或进入队列并提示“排队/取消”

---

## 4. session.md 状态机（流式）

对每次“用户发送 → assistant 回复”定义状态机（写盘与索引同源）：

1) begin_send
- 生成 userMsgId、timestamp
- 追加 user 消息块到 session.md（立即落盘）
- 更新 messages_meta / search 索引（如启用）

2) begin_stream
- 生成 assistantMsgId、timestamp
- 追加 assistant 消息块（空正文或初始片段）+ `<!-- streaming -->`
- 写入/更新 messages_meta（preview 可为空或占位）

3) on_token(delta)
- 将 delta 追加到 assistant 消息正文（保持最后一行仍为 `<!-- streaming -->`）
- 可按节流策略更新 messages_meta.preview（例如每 N 字符或每 200ms）

4) end_stream_success
- 移除 `<!-- streaming -->`
- 最终一次更新 messages_meta / search（若启用）

5) end_stream_error(code)
- 将 `<!-- streaming -->` 替换为 `<!-- error: code -->`
- 该 assistant 消息块保留，不回滚
- “重试”必须生成新的 assistant 消息块（新 msgId），旧块保持可追溯

恢复规则：
- 启动或进入节点时，如发现最后一条 assistant 消息仍为 streaming：视为未完成，可提供“重试/继续生成”入口（MVP 先做重试）

---

## 5. SQLite 索引策略（与磁盘对齐）

原则：
- SQLite 永远可从磁盘重建
- 对齐键固定：themeId / nodeId / noteId / msgId（与 storage-format 一致）

建议索引内容：
- nodes：树关系与标题、更新时间、路径
- messages_meta：role、createdAt、preview、charCount、nodeId/themeId
- notes：更新时间、来源 node、spawned node、路径
- search（FTS5 优先）：content + 定位信息（entityType/entityId/nodeId/themeId）

写入时机：
- 每次落盘成功后再更新 SQLite（或反过来，但需要事务与崩溃恢复；MVP 推荐“先文件后索引”）
- 出现 SQLite 失败：不阻断正文落盘；记录错误并允许 reindex 修复

---

## 6. Reindex（重建索引）与容错

必须支持：
- 删除/损坏 index.sqlite 后，通过扫描 `{root}` 重新生成索引

触发：
- 启动检测（找不到 index.sqlite 或 schema 版本不匹配）
- 设置页提供“重建索引”按钮（MVP 可不做 UI，但逻辑必须可调用）

失败策略：
- 单个文件解析失败不应导致全量失败：记录错误项（nodeId/path/reason），其余继续
- 解析必须严格按 storage-format.md；无法解析时不要写入“半条索引”

---

## 7. stale 规则（总结过期）

最小可行：
- 任何祖先链新增消息 → 相关子节点的 context-summary stale=true

对齐字段：
- context-summary.md 中的 `approvedAt` 与 `sourceUpToMsgId` 用于判定“覆盖范围”

建议实现（MVP 可简化）：
- 在 SQLite 记录每个 node 的 `lastMsgAt`
- summary 记录 `approvedAt`
- 若祖先链任一 node.lastMsgAt > approvedAt，则 stale=true

---

## 8. DeepSeek SSE 集成（工程计划）

统一约束：
- 不记录 API key，不写入磁盘
- SSE 解析必须可在断流/半包情况下正确组装增量

重试行为（MVP 建议）：
- 失败后保留 error 块
- 点击重试：以当前上下文重新请求，生成新的 assistant 消息块

取消：
- 用户取消时：将当前流标记为 `<!-- error: cancelled -->`

---

## 9. 迁移与版本管理

契约：
- 所有磁盘文件都用 `schema: name/vN`
- 若升级到 v(N+1)：先更新 docs/storage-format.md，再实现兼容解析/迁移，再更新代码写入

SQLite：
- schema 不匹配可直接 drop + reindex（MVP 优先）


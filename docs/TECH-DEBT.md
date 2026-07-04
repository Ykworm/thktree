# 技术债

> 记录已知的、暂时搁置的技术问题。
> 你手动维护，或在 code review 时追加；AI 改代码时也应同步更新本表。

| 项目 | 严重程度 | 说明 | 记录日期 |
|------|----------|------|----------|
| `appPathsProvider` 未就绪时笔记列表短暂空态 | 中 | 笔记模块 CHANGELOG § 5 已记；`_loadThemeNotes` 已改为 `await ref.read(appPathsProvider.future)`，但未完成前页面会闪一下空列表 | 2026-06-07 |
| `BiometricService` 已实现但 `AuthGate` 未接线 | 中 | settings 模块 feature 表"生物认证（Face ID）"标 🔨 进行中；服务在但启动时的鉴权门未完成 | 2026-06-07 |
| `ShareService` + `ShareCardWidget` 存在但分享流程未闭环 | 中 | settings 模块 feature 表"分享功能"标 🔨 部分实现，缺触发入口/分享内容生成 | 2026-06-07 |
| 标题自动建议触发时机未集成 | 中 | chat 模块 `TitleSuggestionService` 已写，但"何时调用"（首次进入/对话超过 N 轮/手动按钮）决策未定 | 2026-06-07 |
| LLM 模型列表刷新 UI 未完成 | 低 | `ModelFetcher` 存在但模型列表手动刷新的入口/UI 未实现 | 2026-06-07 |
| 全文搜索结果准确性未做对比测试 | 低 | SQLite FTS5 + BM25 已上线，无 query 质量基线，5 套配色方案行高 56px 的实际体验数据未收集 | 2026-06-07 |
| `docs/_tmp/` 集成测试 report 缺定期清理机制 | 低 | 收尾流程已补充 planning doc 清理（步骤 5），但 report 文件（如 `step-timer-report.md`）保留策略未定：保留多少份、何时归档或删除、是否需要索引。需制定方案避免 `_tmp` 目录无限膨胀 | 2026-06-22 |
| `autoTitleControllerProvider` 内存常驻 | 低 | 用 `ref.keepAlive()`（ADR-018）后 Notifier 实例永不被自动 dispose。每个 chat nodeId 一次任务完成后保留一个 AutoTitleController 实例（实测 ~100B/instance）。当前估算单次会话 1-2 个实例完全可接受。后续可考虑 WeakReference + 定时清理（暂不实施，待 keepAlive 任务累计超 1000 个再 review） | 2026-06-29 |
| MiniMax 联网搜索未实现 | 中 | MiniMax 联网搜索需走 Assistants API（创建 Assistant → Thread → Run），与当前 `LlmClient` 接口（基于 Chat Completions API）架构差异较大。当前 MiniMax 在 `webSearchSupportMap` 中标为"支持"，但实际未实现 tool_calls 流程——用户开启联网开关后 MiniMax 请求不会携带搜索工具定义，返回结果无网页引用。需评估三个方案：方案 A 为 MiniMax 单独实现 Assistants API 客户端（工程量大，需新建 `MiniMaxAssistantClient`，引入 Assistant/Thread/Run 三阶段生命周期管理）；方案 B 调研 MiniMax Chat Completions API 是否也支持 `web_search` 类似能力（若有则可复用 `LlmClient` 现有架构，代价最小）；方案 C 暂时将 MiniMax 从 `webSearchSupportMap` 中移除，避免 UI 显示"支持"但实际无效的误导。建议优先尝试方案 B | 2026-07-04 |

---

## 维护约定

- **新建条目**：在表格新增一行，描述清楚问题、原因、严重程度。
- **关闭条目**：把整行移到 `## 已解决` 段（见下），不要直接删除。
- **AI 维护时机**：当 AI 修改代码时识别到「临时方案」「TODO」「FIXME」「HACK」标记时，**应主动询问用户是否登记为技术债**。

## 已解决

| 项目 | 解决方案 | 关闭日期 |
|------|----------|----------|
| Markdown 渲染库选型 | 已决策 `flutter_markdown → gpt_markdown`（见 [DECISIONS.md ADR-007](DECISIONS.md#adr-007-markdown-渲染库-gpt_markdown-替代-flutter_markdown)） | 2026-06-07 |
| 笔记刷新机制不稳定 | 改为全局版本号 + tab 切换触发（见 docs/modules/notes/CHANGELOG.md § 3） | 2026-05-27 |
| 暖色调主题与节点色风格冲突 | 改用清新调色板（见 docs/CHANGELOG/2026-06-06-warm-minimal-redesign.md） | 2026-06-06 |
| 递归 _TreeRowView 改拍平 | 低 | 当前用递归 Column 渲染子节点，深嵌套时 widget 树膨胀。降级方案：加 4 层深度上限。彻底方案：拍平成 List<FlatNode> + ListView.builder | 2026-06-11 |
| _withLastMessagePreviews 串行读文件 | 低 | ThemeDetailController._load() 中逐个节点读 session.md，O(n) 次文件 IO。改为 Future.wait 并行读取或 compute isolate | 2026-06-11 |
| 折叠状态不持久化 | 低 | _collapsedIds 仅存 State，每次进入详情页重置为全部展开。后续可用 SharedPreferences 持久化 | 2026-06-11 |
| 缺少 expand all / collapse all | 低 | 复杂树结构无批量折叠/展开操作。可在 NavBar trailing 加按钮或长按弹 action sheet | 2026-06-11 |
| RepaintBoundary 隔离 | 低 | 每个 _TreeRowView 都是 DragTarget，hover 时 setState 触发整棵树重绘。4 层深度上限后 widget 数量可控，暂不处理 | 2026-06-11 |
| `getSessionPathForNode` 全量 reindex 导致嵌套事务崩溃 | 统一 disk-first 写入顺序 + 启动轻量 syncFromDisk（见 [DECISIONS.md ADR-014](DECISIONS.md#adr-014-db-一致性保障统一-disk-first-写入顺序--启动轻量同步)） | 2026-06-22 |


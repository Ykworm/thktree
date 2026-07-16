# Search 模块

> ⚠️ **AI 改模块前必读**
> 1. **FTS5 同步更新**——SQLite 的 `notes_fts` 虚拟表必须随 `NoteStore` 的写盘/删盘同步增删；别单走一条路。
> 2. **跨模块跳转靠 `routeName + args`**——命中后跳到 `notes/detail` / `chat` / `themes` 等页面；**不要**在 search 模块里 `import 'lib/ui/features/notes/...'` 直接调 widget。
> 3. **BM25 排序不手写**——交给 `notes_fts MATCH ? ORDER BY bm25(...)`；UI 别加 score 字段。
> 4. **防抖 300ms（仅 live 搜索上下文）**——`SearchResults.debounceDelay` 默认 300ms，与设计系统动效绑定，**笔记 tab 的 live 搜索别改这个值**；搜索 tab 走「显式提交」，`SearchContent` 传 `Duration.zero` 关掉防抖（改这个 0 不影响笔记 tab）。
> 5. **FTS5 虚拟表禁用 `ConflictAlgorithm.replace`**——FTS5 不支持主键/UNIQUE，`ConflictAlgorithm.replace` 会**静默失效**（不抛错不替换只多一行）。upsert 必须用 `db.transaction` 包裹 `DELETE + INSERT`。⚠️ FTS5 helper function（`snippet`/`bm25`）不能在 GROUP BY 子查询里调用（iOS SQLite 报 `unable to use function X`），查询侧也不能用 GROUP BY 兜底——改成扁平查询 + 正确 `col=5`（content 列）。详见 EC-043、[war-story packages/2026-06-29-fts5-conflict-replace-silent.md](../packages/2026-06-29-fts5-conflict-replace-silent.md)。
> 6. **氛围光（2026-07-17）**：`SearchScreen` 包 `ThkPageAtmosphere`（页级静光，蓝自 title bar 释放）；**不要**给结果行加 blur。见 [design-system](../../_shared/design-system.md)。

## 职责

全局搜索模块。基于 SQLite FTS5 + BM25 的本地全文搜索，覆盖笔记标题、正文、对话消息；支持跨模块跳转（命中后直跳到 notes/search/chat 对应详情页）。

## 功能列表

- 全局搜索：单一搜索框，跨笔记/对话/节点统一命中
- BM25 排序：相关度倒序
- 防抖（debounce，仅笔记 tab）：输入停顿 300ms 后触发 live 搜索，避免频繁建查询
- 显式搜索（搜索 tab）：输入框旁「搜索」按钮 / 键盘回车才提交搜索；边打字不触发
- 高亮显示：命中关键词在结果列表加粗
- 跨模块跳转：点击结果按类型分别跳到笔记详情 / 对话详情 / 节点上下文
- 搜索历史：最近 10 条，**仅**在显式提交（按钮 / 回车 / 点历史标签）时写入；live 打字不写，避免记录输入中间过程（如 `b`/`be`/`bea`…）
- 空状态/无结果：差异化提示

## 代码文件

| 文件 | 角色 | 行数 |
|------|------|------|
| `lib/ui/features/search/search_screen.dart` | 搜索 tab（`ThkPageAtmosphere` + `SearchContent`） | - |
| `lib/ui/features/search/search_content.dart` | `SearchContent` 组件：顶部 `SearchBox` + 下方 `SearchResults`（被搜索 tab 与笔记 tab 复用） | - |
| `lib/data/search/search_service.dart` | 搜索服务（封装 FTS5 查询） | - |

> **嵌入说明**：`SearchContent` 是独立 widget，输入框 + 结果区一体，外部可自由嵌套。已用于：
> - 搜索 tab（`SearchScreen` 顶层包一层）
> - 笔记 tab 顶部（`NoteBrowseScreen._buildGroupedBody` 顶部嵌入）

## 子文档

- [specs/2026-06-05-搜索功能-design.md](specs/2026-06-05-搜索功能-design.md) — 搜索功能完整设计书（架构/索引策略/性能/扩展）

## 关键设计原则

- **FTS5 + BM25 本地索引**：避免在线调用，全离线可用；查询速度 < 50ms（10 万条语料）
- **双写索引**：写入 notes/chat 持久化时同步更新 FTS5 虚表（事务保证一致性）
- **search_index 去重（2026-06-29 修复 EC-043）**：`upsertNote` / `upsertMessage` 全部用 `db.transaction` 包裹 `DELETE + INSERT` 替代 `db.insert(..., conflictAlgorithm: ConflictAlgorithm.replace)`（FTS5 不支持主键，replace 静默失效）。`search()` 用**扁平查询**（`SELECT ... FROM search_index MATCH ?`）+ `snippet(search_index, 5, ...)`（col=5 = `content` 列）+ `ORDER BY bm25(...) ASC, updatedAt DESC`。⚠️ 不可用 GROUP BY 兜底——FTS5 helper function 在 GROUP BY 子查询里报 context 错误；历史脏数据依靠方案 A 的事务 DELETE+INSERT 在每次新 upsert 时自动清理。
- **CJK 逐字分词（2026-07-09 修复 EC-015）**：`unicode61` 将连续 CJK 字符视为一个 token，导致子串搜索失败。索引写入时用 `_tokenizeCjk()` 在 CJK 字符间插入空格，让 FTS5 按单字 AND 匹配。查询侧同步分词。snippet 返回后用 `_cleanSnippet()` 去除 CJK 间空格。v6 迁移 DROP+CREATE 触发索引重建。详见 [war-story packages/2026-07-09-fts5-cjk-tokenization.md](../../war-stories/packages/2026-07-09-fts5-cjk-tokenization.md)。
- **统一 schema**：所有内容统一序列化为 `fts_row`（type + nodeId + title + body），跨类型一次查询
- **跨模块跳转解耦**：通过 nodeId 在 result 上挂 `routeName + args`，路由层用 go_router 跳转
- **防抖 + 取消旧查询**：用 Riverpod 的 `autoDispose` + 计时器避免乱序
- **Tag cloud 初始值处理（2026-07-09 修复）**：`SearchResults` 是在 query 非空时动态创建的 widget，`ValueNotifier` 只在值变化时触发 listener，不触发初始值。tag cloud 点击设值后 `SearchResults` 新建，listener 不触发，搜索不执行。修复：`initState` 中检查并处理初始值。详见 [war-story ui-ux/2026-07-09-search-tag-cloud-no-trigger.md](../../war-stories/ui-ux/2026-07-09-search-tag-cloud-no-trigger.md)。
- **显式搜索（2026-07-09）**：搜索 tab 的 `SearchContent` 把「输入框文本 `_queryNotifier`」与「已提交词 `_committedNotifier`」拆开。只有 `SearchBox.onSearch`（接键盘回车 `onSubmitted`）与「搜索」`CupertinoButton`（空输入 `onPressed: null` 灰显禁用）才把当前文本提交到 `_committedNotifier` 并触发 `SearchResults`。结果区三态：`_committedNotifier` 空→最近搜索标签云；有文本且已提交（文本==已提交词）→结果；有文本未提交→`_SearchIdleHint` 提示「输入后点击搜索」，**不显示旧结果**。清空 / 编辑输入框即把 `committed` 清空，旧结果立即消失。`SearchResults.debounceDelay` 传 `Duration.zero`（显式提交已靠 `ValueNotifier` 同值不 notify 去重）。**笔记 tab（`NoteBrowseScreen`）仍用默认 300ms live 搜索，零改动**。历史写入（`addRecentSearch`）只在提交成功时发生，因此慢打字不会把 `b`/`be`/`bea`… 写进历史。

## 维护要点

- 新增可搜索内容类型（如标签、收藏）时：扩 `fts_row` schema + 在各模块写入处补同步索引
- 改 FTS5 索引策略前必读 [specs/2026-06-05-搜索功能-design.md](specs/2026-06-05-搜索功能-design.md)
- **禁止在 FTS5 虚表上用 `ConflictAlgorithm.replace`**——会静默累加（同 `(entityType, entityId)` 多行），必须用事务 `DELETE + INSERT`，详见 关键设计原则 2026-06-29 修复
- 搜索结果跳转依赖各模块 screen 的路由名，改 route 时同步更新
- 性能监控：超过 1000 条结果时强制收窄到 top 200，避免长列表渲染卡顿

## 相关历史

- 2026-05：搜索功能首次上线（FTS5 + BM25）
- 2026-06：补 spec 设计书、性能压测、跨模块跳转
- 2026-06：加入搜索历史 + 高亮
- 2026-06-24：`SearchContent` 组件抽离，被笔记 tab 顶部复用——笔记 tab 顶部搜索统一为全文搜索；明确放弃主题名搜索能力（接受 FTS5 schema `themeTitle UNINDEXED` 事实）。详见 [CHANGELOG](../../modules/notes/CHANGELOG.md#10-笔记-tab-顶部搜索统一为全文搜索2026-06-24)
- 2026-06-29：`upsertNote` / `upsertMessage` 全部修复 EC-043（FTS5 upsert 静默失效 → 搜索结果重复）— 方案 A+B：`db.transaction` 删+插（源头去重）+ `search()` 扁平查询 + `col=5`（查询侧不再 GROUP BY——FTS5 helper function 在子查询里报 `unable to use function X`）。上游 commit `9205baa`，下游 commit `cb9891f`（补强：message 端同步修复 + 方案 B 子查询重写为扁平）。详见 [CHANGELOG 2026-06-29-fts5-upsert-repeat.md](../../CHANGELOG/2026-06-29-fts5-upsert-repeat.md)、[CHANGELOG 2026-06-29-fts5-search-rework.md](../../CHANGELOG/2026-06-29-fts5-search-rework.md)、[war-story](../../war-stories/packages/2026-06-29-fts5-conflict-replace-silent.md)
- 2026-07-09：修复 EC-015（FTS5 CJK 分词）— `unicode61` 将连续 CJK 视为一个 token，子串搜索失败。新增 `_tokenizeCjk()` 逐字分词 + `_cleanSnippet()` 清理 + v6 迁移触发索引重建。详见 [war-story packages/2026-07-09-fts5-cjk-tokenization.md](../../war-stories/packages/2026-07-09-fts5-cjk-tokenization.md)
- 2026-07-09：修复 tag cloud 点击不触发搜索 — `ValueNotifier` 只在值变化时触发 listener，动态创建的 `SearchResults` widget 在 `initState` 中未处理初始值。详见 [war-story ui-ux/2026-07-09-search-tag-cloud-no-trigger.md](../../war-stories/ui-ux/2026-07-09-search-tag-cloud-no-trigger.md)
- 2026-07-09：搜索 tab 改为「显式搜索按钮」替代 live 搜索 + 编辑即清旧结果三态。详见本文件关键设计原则「显式搜索」。动机：live 搜索下慢打字每 >300ms 停顿都触发搜索并写历史，导致 `beautiful` 被拆成 `b`/`be`/`bea`… 记录；提交后编辑/删除框内文本时旧结果仍挂着。
- 2026-07-17：Warm Paper 页级静光（`ThkPageAtmosphere`）挂在 `SearchScreen`。见 [CHANGELOG/2026-07-17-warm-paper-glass.md](../../CHANGELOG/2026-07-17-warm-paper-glass.md)。

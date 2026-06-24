# Search 模块

> ⚠️ **AI 改模块前必读**
> 1. **FTS5 同步更新**——SQLite 的 `notes_fts` 虚拟表必须随 `NoteStore` 的写盘/删盘同步增删；别单走一条路。
> 2. **跨模块跳转靠 `routeName + args`**——命中后跳到 `notes/detail` / `chat` / `themes` 等页面；**不要**在 search 模块里 `import 'lib/ui/features/notes/...'` 直接调 widget。
> 3. **BM25 排序不手写**——交给 `notes_fts MATCH ? ORDER BY bm25(...)`；UI 别加 score 字段。
> 4. **防抖 300ms**——别改这个值，与设计系统绑定。

## 职责

全局搜索模块。基于 SQLite FTS5 + BM25 的本地全文搜索，覆盖笔记标题、正文、对话消息；支持跨模块跳转（命中后直跳到 notes/search/chat 对应详情页）。

## 功能列表

- 全局搜索：单一搜索框，跨笔记/对话/节点统一命中
- BM25 排序：相关度倒序
- 防抖（debounce）：输入停顿 300ms 后触发，避免频繁建查询
- 高亮显示：命中关键词在结果列表加粗
- 跨模块跳转：点击结果按类型分别跳到笔记详情 / 对话详情 / 节点上下文
- 搜索历史：最近 10 次搜索关键词本地保存
- 空状态/无结果：差异化提示

## 代码文件

| 文件 | 角色 | 行数 |
|------|------|------|
| `lib/ui/features/search/search_screen.dart` | 搜索 tab（包裹 `SearchContent`） | - |
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
- **统一 schema**：所有内容统一序列化为 `fts_row`（type + nodeId + title + body），跨类型一次查询
- **跨模块跳转解耦**：通过 nodeId 在 result 上挂 `routeName + args`，路由层用 go_router 跳转
- **防抖 + 取消旧查询**：用 Riverpod 的 `autoDispose` + 计时器避免乱序

## 维护要点

- 新增可搜索内容类型（如标签、收藏）时：扩 `fts_row` schema + 在各模块写入处补同步索引
- 改 FTS5 索引策略前必读 [specs/2026-06-05-搜索功能-design.md](specs/2026-06-05-搜索功能-design.md)
- 搜索结果跳转依赖各模块 screen 的路由名，改 route 时同步更新
- 性能监控：超过 1000 条结果时强制收窄到 top 200，避免长列表渲染卡顿

## 相关历史

- 2026-05：搜索功能首次上线（FTS5 + BM25）
- 2026-06：补 spec 设计书、性能压测、跨模块跳转
- 2026-06：加入搜索历史 + 高亮
- 2026-06-24：`SearchContent` 组件抽离，被笔记 tab 顶部复用——笔记 tab 顶部搜索统一为全文搜索；明确放弃主题名搜索能力（接受 FTS5 schema `themeTitle UNINDEXED` 事实）。详见 [CHANGELOG](../../modules/notes/CHANGELOG.md#10-笔记-tab-顶部搜索统一为全文搜索2026-06-24)

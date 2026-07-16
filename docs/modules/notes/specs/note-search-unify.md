# 笔记搜索入口统一为搜索 Tab 的全文搜索

> brainstorming 草稿 · 待用户确认后进入 writing-plans

---

## 1. 现状（背景）

| 位置 | 当前实现 | 调用 |
|------|---------|------|
| **笔记 tab 顶部搜索框** | 内存过滤 `_themes`，按主题名 `t.title.toLowerCase().contains(query)` | ❌ 不调用 `SearchService` |
| **搜索 tab（`SearchScreen`）** | `SearchService.search()` 走 SQLite FTS5 + BM25，300ms 防抖，命中跨笔记/对话 | ✅ `ref.read(searchServiceProvider.future)` |

两个入口都叫"搜索"、placeholder 都用同一个 `l10n.searchHint`，但行为完全不同——容易让用户产生预期错位。

## 2. 决策

**统一为搜索 Tab 的全文搜索实现**，笔记 tab 顶部搜索框不再做本地过滤。

### 2.1 用户已确认的方向

- **结果 UI**：与 `SearchScreen` 完全一致（标题 + 主题 + 片段，三行卡片）
- **搜索范围**：固定为 `note` + `message` 两种 entity_type（**不含主题名**，用户明确放弃主题名搜索能力，见第 2.4 节）
- **placeholder**：与 `SearchScreen` 一致（共用 `l10n.searchHint`）
- **行为**：与 `SearchScreen` 一致（300ms 防抖、SQLite 异常弹修复索引 dialog）

### 2.2 实现路径选择

倾向 **方案 A（组件最大化复用）**，备选 **方案 B（直接跳转）**。

#### 方案 A：抽 `SearchContent` widget · 双向嵌入（推荐）

- 把 `SearchScreen` 拆成两层：
 - `_SearchScreenState`（保留 navigationBar + 容器布局）
 - **新抽 `SearchContent` widget**（搜索框 + 结果列表 + 防抖 + 跳转逻辑）
- `SearchScreen.build` 直接 `body: SearchContent(...)`
- 笔记 tab 顶部用 `SliverToBoxAdapter` 包 `SearchContent`（替换原 `CupertinoSearchTextField`）
- **核心收益**：搜索行为/UI/范围 100% 一致，后续改一处两边生效

#### 方案 B：笔记 tab 顶部 onTap → push SearchScreen（极简）

- 笔记 tab 顶部 `CupertinoSearchTextField` 改为"伪搜索框"（视觉占位）
- 点击/聚焦 → `Navigator.push(SearchScreen)`
- 笔记 tab 本地彻底不做搜索
- **代价**：多一次页面跳转、视觉上仍是"伪搜索框"

### 2.3 主题分组的处理

方案 A 下笔记 tab 仍保留"主题分组"列表。**搜索态切换**逻辑：
- 空查询（query 为空）→ 显示主题分组（原行为）
- 非空查询 → 切换为 `SearchContent` 结果列表（替换主体）

> 这与方案 A 配合：搜索态就是嵌入一个 `SearchContent`，非搜索态是主题分组。两态视觉切换但同一屏内。

### 2.4 已知能力损失（用户已知情接受）

| 损失能力 | 原行为 | 替代方案 |
|---------|-------|---------|
| 主题名模糊搜索 | 笔记 tab 顶部按 `t.title.toLowerCase().contains(query)` 内存过滤 | **无替代** — 用户明确放弃主题名搜索能力 |

**事实依据**：`SearchService.search_index` 的 FTS5 schema 把 `themeTitle` 标记为 `UNINDEXED`，仅作结果展示元数据；现有 `rebuildAll` 不扫描 theme 自身目录，无 `upsertTheme` 方法。本次重构不扩展索引范围，主题名搜索能力**永久丢失**。

## 3. 影响范围

### 3.1 代码改动

| 文件 | 改动 |
|------|------|
| `lib/ui/features/search/search_screen.dart` | 抽出 `SearchContent` widget，本文件用其替换原内部逻辑 |
| `lib/ui/features/notes/note_browse_screen.dart` | 替换顶部 `CupertinoSearchTextField` 为 `SearchContent`；删除 `_searchController` / 内存过滤逻辑；空查询态走主题分组 |
| （新增）`lib/ui/features/search/search_content.dart` | `SearchContent` widget，供两处复用 |

### 3.2 测试改动

- `integration_test/` 新增 `note_search_test.dart`：
 - case 1：笔记 tab 顶部输入关键词 → 命中笔记列表 → 点击跳转 NoteDetailScreen
 - case 2：空查询态 → 主题分组正常显示
 - case 3：搜索无结果 → "换个角度试试"空态
 - case 4：SQLite 索引异常 → 修复 dialog（如果集成测试可触发）

### 3.3 文档改动（ctsync 阶段）

- `docs/modules/notes/CHANGELOG.md`：删除 🟡「笔记搜索/过滤」待办；新增 第 10 节「笔记搜索统一为全文搜索」
- `docs/modules/notes/visual/notes-list-design.md`：第 1.1 节 ASCII 图加搜索框；第 5 节 Assumptions 重写（不再做本地过滤）；第 6 节 待办「主题内笔记搜索」保留（这是 `ThemeNoteListScreen` 内搜索，是另一个未做项）
- `docs/modules/notes/README.md` 第 2 节：新增「笔记搜索」行
- `docs/FEATURES.md` 第 2 节：更新「笔记功能」说明（"含笔记 tab 全文搜索"）
- `docs/modules/search/README.md`：补一句"搜索能力同时嵌入笔记 tab 顶部"
- `docs/modules/notes/README.md` + `docs/FEATURES.md` 笔记模块：**明确写"搜索范围：笔记标题/正文 + 对话标题/正文，不含主题名"**（用户放弃主题名搜索能力的对外说明）

### 3.4 l10n

- 复用现有 `searchHint` / `searchNoResults` / `searchError` / `searchEmpty` 等 key，**不新增**

## 4. 验收方式

按 AGENTS.md「测试与验收策略」选择：

1. **关键路径集成测试**（优先）
 - `integration_test/note_search_test.dart` 4 个 case 全绿
 - 覆盖：搜索命中跳转、空查询主题分组、无结果空态、行为与 SearchScreen 一致
2. **静态检查**
 - `flutter analyze` 无新增 error/warning
3. **手工验证**
 - 实跑笔记 tab，输入"xxx" → 看到命中列表 → 点开 → 切回 → 搜索态消失 → 主题分组恢复
 - 与搜索 tab 输入相同关键词 → 结果顺序、UI 完全一致

## 5. 风险与权衡

| 风险 | 应对 |
|------|------|
| `SearchContent` 嵌入主题分组页 → 滚动/焦点冲突 | 限定 `SearchContent` 仅占用搜索态，主体不滚动；非搜索态走 `SliverList` |
| FTS5 索引未建/损坏时 → 用户在笔记 tab 也可能触发 | `SearchContent` 内置 SQLite 异常 → 弹修复 dialog（已有） |
| 主题分组和搜索结果切换的视觉跳变 | 用 `SliverCrossAxisTransition` 或 `AnimatedSwitcher` 平滑过渡（次要，可放后续） |
| 集成测试需要 LLM 索引数据 → 测试夹具复杂 | 仅做"在文件系统手工写笔记 → 触发 rebuild → 搜索"的轻量夹具，参考已有 `_support/` 目录 |

## 6. 任务类型

按 AGENTS.md 工作流判定：**普通功能改版**（不是 Bug 修复、不是集成测试新增）。

> **待用户确认进入下一步 → writing-plans**
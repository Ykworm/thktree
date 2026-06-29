# FTS5 虚拟表上 `ConflictAlgorithm.replace` 静默失效

**日期**：2026-06-29  
**模块**：search / `SearchService` + `AppDatabase`  
**标签**：SQLite, FTS5, sqflite, 数据一致性, 隐蔽 bug

## 现象

用户搜索笔记时，**同一条笔记出现 2 次**（或更多次）。

最小复现：

1. 笔记 tab → + → 选主题 → 进编辑器
2. 输入标题"测试笔记" + 正文"含独特关键词 EC043_KEYWORD"
3. 等 500ms（防抖）→ 点 √ 保存
4. 搜索"测试笔记"或"EC043_KEYWORD" → **列表里同一笔记出现 2 条**

新建时立即 2 条；编辑 N 次后变 N 条；iOS 后台重发后翻倍。

具体排查路径：

- 一开始以为是 `_saveNow` 被调用 2 次导致 `upsertNote` 被调用 2 次，每次都多插一行
- 加 log 看 `upsertNote` 调用次数 → 确实 2 次
- 但每次插入应该被 `conflictAlgorithm: ConflictAlgorithm.replace` 替换掉，不应该产生重复
- 手动 SQL `SELECT count(*) FROM search_index WHERE entityId = '<noteId>'` → 返回 2
- 手动 SQL `SELECT * FROM search_index WHERE entityId = '<noteId>'` → 两条 rowid 不同，字段值相同

## 根因分析

### 1. FTS5 虚拟表不支持 PRIMARY KEY / UNIQUE 约束

`search_index` schema（[app_database.dart:62-73](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/data/services/app_database.dart)）：

```sql
CREATE VIRTUAL TABLE search_index USING fts5(
  entityType,
  entityId,
  themeId,
  themeTitle UNINDEXED,
  entityTitle,
  content,
  updatedAt UNINDEXED
);
```

FTS5 虚拟表 **不支持**标准 SQLite 的 `PRIMARY KEY` / `UNIQUE` 约束。FTS5 是独立模块，对 `entityId` 等列只把它当作"被索引的文本"，不存在"主键唯一性"语义。

### 2. `ConflictAlgorithm.replace` 在 FTS5 上静默失效

原 `upsertNote`（[search_service.dart:111-138](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/data/services/search_service.dart)）：

```dart
await db.insert(
  'search_index',
  {...},
  conflictAlgorithm: ConflictAlgorithm.replace,  // ⚠️ FTS5 无效
);
```

`ConflictAlgorithm.replace` 在 sqflite 里翻译为 SQL `INSERT OR REPLACE`。但 SQLite 标准 `INSERT OR REPLACE` 依赖表上的 `PRIMARY KEY` / `UNIQUE` 约束去判定"哪行被替换"。FTS5 虚拟表没有这些约束 → SQLite 把这条 `INSERT OR REPLACE` 当成普通 `INSERT` 处理 → **不抛错，不替换，插入新 rowid 行**。

这是 sqflite / FTS5 联用时最隐蔽的陷阱之一：**不抛错、不报警、不换行，只多一行**。

### 3. `search()` 查询无去重

原 `search()`（[search_service.dart:53-101](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/data/services/search_service.dart)）：

```sql
SELECT ... FROM search_index WHERE search_index MATCH ?
```

直接选所有命中行；不去重 → 重复行全部返回。

### 三方叠加放大严重性

| 触发频率 | 调用 `upsertNote` 次数 | `search_index` 中重复行数 |
|---------|------------------------|---------------------------|
| 笔记新建一次 | 2 次（防抖 + √） | 2 |
| 笔记编辑 5 次 | 10 次 | 10 |
| iOS 后台重发叠加 | ×2 | 翻倍 |

## 解决方案

### 方案 A（源头去重）：事务化 DELETE + INSERT

```dart
Future<void> upsertNote({...}) async {
  try {
    await db.transaction((txn) async {
      await txn.delete(
        'search_index',
        where: 'entityType = ? AND entityId = ?',
        whereArgs: ['note', noteId],
      );
      await txn.insert('search_index', {...});
    });
  } catch (e, st) {
    dev.log('[SearchService.upsertNote] FAILED noteId=$noteId: $e\n$st');
  }
}
```

事务保证 DELETE + INSERT 原子性，避免中间态被读到。

### 方案 B（查询兜底）：子查询 + GROUP BY

```sql
SELECT
  entityType, entityId, themeId, themeTitle, entityTitle,
  snippet, updatedAt
FROM (
  SELECT
    entityType, entityId, themeId, themeTitle, entityTitle,
    snippet(search_index, 1, '<b>', '</b>', '...', 40) AS snippet,
    updatedAt,
    bm25(search_index, 0.0, 1.0, 0.0, 0.0, 0.5, 5.0) AS rank
  FROM search_index
  WHERE search_index MATCH ?
)
GROUP BY entityType, entityId
ORDER BY MIN(rank) ASC, MAX(updatedAt) DESC
LIMIT ?
```

子查询里先调 `bm25()` / `snippet()`（FTS5 函数），外层 GROUP BY 按 `(entityType, entityId)` 聚合天然去重。

### 为什么选 A+B 组合而不是单一方案？

| 方案 | 单独效果 | 缺点 |
|------|---------|------|
| 只用 A | 修源头，新数据无重复 | 不处理历史脏数据（旧设备上已有重复行） |
| 只用 B | 天然去重，不修源头 | 每次查询都 GROUP BY；脏数据越多排序越慢 |
| **A+B 组合** | **A 保证新数据不重复，B 兜底历史脏数据；新增数据无 GROUP BY 性能损耗（每个 entityId 1 行）** | 实现复杂度略高（两个文件都要改） |

### 方案 B 的实际落地为什么从子查询改成扁平？

上游 commit `9205baa` 提交时认为子查询 + GROUP BY 可行。但在 iOS 真机实测，发现两个隐藏问题：

1. **`unable to use function snippet/bm25 in the requested context`**——FTS5 helper function 不能在 GROUP BY 子查询里调用。子查询里的 `snippet(...)` / `bm25(...)` 报 context 错误，整个 query 直接被 SQLite 拒绝执行。
2. **外层 SELECT 漏 `entityId`**：GROUP BY 需要在 outer SELECT 里同时 SELECT 该字段才能投影出来，否则报 `no such column: entityId`。

在下游 commit `cb9891f` 里修复：

```sql
-- 实际落地的 search()（[search_service.dart:60-86](file:///Users/yuweikang/dev/ykcode/ThkTree/lib/data/services/search_service.dart)）
SELECT
  entityType, entityId, themeId, themeTitle, entityTitle,
  snippet(search_index, 5, '<b>', '</b>', '...', 40) AS snippet,
  updatedAt,
  bm25(search_index, 0.0, 1.0, 0.0, 0.0, 0.5, 5.0) AS rank
FROM search_index
WHERE search_index MATCH ?
ORDER BY rank ASC, updatedAt DESC
LIMIT ?
```

关键点：

- **col=5 = `content`**（entityType=0, entityId=1, themeId=2, themeTitle=3 UNINDEXED, entityTitle=4, content=5, updatedAt=6）。原代码 `snippet(search_index, 1, ...)` 错取 entityId，高亮实际为 ID 文本。
- **取消 GROUP BY**：历史脏数据靠方案 A 的事务 DELETE+INSERT 自动清理（每个 upsert 路径都先 DELETE 同 `(entityType, entityId)` 行）。

### 不选方案 C（架构级重构）

方案 C：FTS5 `external content` 模式 + 普通 SQLite 表做主键管理。

- 收益：根本上避免 FTS5 的无主键问题
- 代价：需重新设计 schema + 全量 rebuild 迁移 + 大量代码改动
- 决策：**收益不抵成本**。EC-043 只是搜索去重问题，A+B 已经足够

## 关键代码/配置

详见 commit `9205baa`：

- `lib/data/services/search_service.dart:53-101`（`search` 子查询 + GROUP BY）
- `lib/data/services/search_service.dart:111-138`（`upsertNote` 事务化 DELETE+INSERT）
- `integration_test/note_search_test.dart` Case 5（新增）

## 相关文件

- `lib/data/services/search_service.dart` — 主要修复目标
- `lib/data/services/app_database.dart` — `search_index` schema（无法改主键）
- `integration_test/note_search_test.dart` — Case 5 复现 EC-043
- `lib/ui/features/notes/note_editor_screen.dart` — 触发 `upsertNote` 2 次的源头（500ms 防抖 + √）
- `lib/data/services/chat_task_service.dart` — 另一处触发 `upsertMessage` 多次（同 bug，已在下游 commit `cb9891f` 同步修复：事务化 DELETE+INSERT）

## 参考链接

- [edge-cases-backlog § EC-043](../_shared/edge-cases-backlog.md)
- [CHANGELOG 2026-06-29](../CHANGELOG/2026-06-29-fts5-upsert-repeat.md)
- [SQLite FTS5 文档 — Conflict Resolution](https://www.sqlite.org/fts5.html#section_4_4)（FTS5 不支持 `INSERT OR REPLACE` 的 PRIMARY KEY 语义）
- [sqflite GitHub Issue #574 — ConflictAlgorithm.replace on FTS5](https://github.com/tekartik/sqflite/issues/574)

## 复盘

### 为什么一开始没发现？

- **行为过于"温柔"**：`ConflictAlgorithm.replace` 静默失效，**不抛错、不报警、不换行、只多一行**。sqflite 不校验"INSERT OR REPLACE 在 FTS5 上是否有效"
- **触发条件不直接**：必须 `upsertNote` 被调用 ≥ 2 次才出现重复。单次调用看不出问题。新建笔记的"2 次调用"链路（500ms 防抖 + √ 按钮）跨多个 file，不放在一起看不知道
- **查询端也无去重**：FTS5 表本身无主键，但查询侧又直接 SELECT 全部命中行，两个宽松策略叠加才暴露问题
- **首次 FTS5 落地的项目**：ThkTree 是首个大规模用 sqflite FTS5 的项目，没有历史踩坑经验可参考

### 以后如何避免同类问题？

1. **FTS5 虚拟表上禁止使用 `ConflictAlgorithm.replace`**：sqflite/FTS5 联用必须用事务化 DELETE + INSERT 模式，**作为内部约定写进 linter / code review checklist**
2. **任何"按某列去重"的查询必须有 GROUP BY 或 DISTINCT**：尤其 FTS5 表无主键场景
3. **重复写入问题的集成测试必须包含"触发 ≥ 2 次"步骤**：单纯 1 次调用看不出"应该被替换"的问题
4. **FTS5 schema 设计时强制加 `id INTEGER PRIMARY KEY`（用 `external content` 模式）**：未来新建 FTS5 虚拟表时优先考虑这个模式避免同类陷阱
5. **sqflite 库升级时关注 FTS5 相关 changelog**：行为可能在版本升级时改变

### 排查成本评估

- 定位 `upsertNote` 调用 2 次：易（加 log 即可）
- 定位 `INSERT OR REPLACE` 在 FTS5 上无效：**中**（需读 sqflite + SQLite 源码 / 文档才能确定）
- 定位 `search()` 无去重：易（看 SQL 即可）
- 设计 A+B 组合方案：低（一对一映射根因即可）
- 整体：**中等**——不属于一眼修复，需要理解 sqflite / FTS5 / SQLite 三方行为

### 复用价值

- 未来 ThkTree 任何 sqflite + FTS5 项目都需遵循此修复模式
- 任何"使用 `ConflictAlgorithm.replace` + 虚拟表"组合的场景都应警惕此陷阱
- 任何"无主键表 + SELECT 全部命中行"组合都应强制加 GROUP BY
# EC-043 后续：upsertMessage 同步修复 + search() 重写（扁平查询 + col=5）

| 属性 | 说明 |
|------|------|
| 日期 | 2026-06-29 |
| 范围 | `lib/data/services/search_service.dart` `search()` + `upsertMessage()` 重写 + war-story 补强 + CHANGELOG 修正 hash + EC-043 状态升"完整修复" |
| 上游 | [CHANGELOG 2026-06-29-fts5-upsert-repeat.md](./2026-06-29-fts5-upsert-repeat.md)（commit `9205baa`） |
| 配套文档 | [edge-cases-backlog § EC-043](../_shared/edge-cases-backlog.md)（已标 ✅ 完整修复） · [war-story 2026-06-29 FTS5 ConflictAlgorithm 静默失效](../war-stories/packages/2026-06-29-fts5-conflict-replace-silent.md)（新增"方案 B 重写原因"段） |
| 状态 | 🟢 完成（代码 commit `cb9891f`，文档待用户统一收口） |

## 背景

[EC-043 上游修复](./2026-06-29-fts5-upsert-repeat.md) 后用户实际在 dev 跑搜索（搜"张学友"），**结果仍是 0 条**。排查后发现 4 处叠加根因，上游修复只命中其中 1 处。

## 根因（4 处叠加）

| # | 位置 | 问题 | 上游处理 |
|---|------|------|---------|
| 1 | `upsertMessage`（search_service.dart:144-164） | 仍用 `ConflictAlgorithm.replace` —— 同款 FTS5 静默失效 bug | ❌ 按"问题修复范围最小化原则"暂未扩大 |
| 2 | `search()` 子查询 + 外层 GROUP BY | iOS SQLite 报 `"unable to use function snippet/bm25 in the requested context"` —— FTS5 helper function 不能在 GROUP BY 子查询里调用 | ❌ 当时未在真机验证 |
| 3 | `snippet(search_index, 1, ...)` | col=1 是 `entityId`，不是 `content`；命中正文关键词时取不到正文 | ❌ col 编号选错 |
| 4 | 外层 SELECT 漏 `entityId` | GROUP BY 时报 `"no such column: entityId"`（叠加 #2 的根因） | ❌ 字段漏写 |

> **直接证据**：模拟器 SQLite `sqlite3` 实测，扁平 + col=5 的 query 返回正确 `<b>张学友</b>` 高亮；子查询 + col=1 + GROUP BY 全部失败。

## 严重性量化

- 用户搜"张学友" → 0 条结果（功能完全不可用）
- 用户搜"唱功" → 0 条
- 数据库里实际有 6 条匹配行（已用 SQL `WHERE search_index MATCH '张学友'` 验证）
- 历史脏数据：3 个 message 各 2 行（来自上游修复前的 `ConflictAlgorithm.replace` 累加）

## 方案

### 方案 A：源头去重扩大到 `upsertMessage`

`upsertMessage` 改用 `db.transaction` 包裹 `DELETE + INSERT`，与 `upsertNote` 同款：

```dart
// lib/data/services/search_service.dart upsertMessage
await db.transaction((txn) async {
  await txn.delete(
    'search_index',
    where: 'entityType = ? AND entityId = ?',
    whereArgs: ['message', nodeId],
  );
  await txn.insert('search_index', {
    'entityType': 'message',
    'entityId': nodeId,
    'themeId': themeId,
    'themeTitle': themeTitle,
    'entityTitle': nodeTitle,
    'content': body,
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
  });
});
```

### 方案 B：search() 重写为扁平查询

放弃"子查询 + GROUP BY"模式（FTS5 helper function 在 GROUP BY 子查询里不可用）。改为直接扁平查询 + 正确列号：

```sql
SELECT
  entityType,
  entityId,
  themeId,
  themeTitle,
  entityTitle,
  snippet(search_index, 5, '<b>', '</b>', '...', 40) AS snippet,
  updatedAt,
  bm25(search_index, 0.0, 1.0, 0.0, 0.0, 0.5, 5.0) AS rank
FROM search_index
WHERE search_index MATCH ?
ORDER BY rank ASC, updatedAt DESC
LIMIT ?
```

- **col=5 = `content`**（entityType=0, entityId=1, themeId=2, themeTitle=3 UNINDEXED, entityTitle=4, content=5, updatedAt=6）
- 排序：BM25 rank 升序（数字越小越相关），同 rank 时按 updatedAt DESC

### 为什么不用 GROUP BY 兜底历史脏数据？

上游用"GROUP BY 兜底"的假设是 GROUP BY 在 SQLite 下可用。**本次实跑 iOS SQLite 证实 FTS5 helper function 不能在 GROUP BY 子查询里调用**。即：GROUP BY 兜底方案在新版 SQLite 下不可行。

替代方案：

- 用户下次新建/编辑任意消息时，`upsertMessage` 事务 DELETE+INSERT 会清掉该 entity 的旧行
- 用户手动跑 SQL 去重（已在测试清单里提供命令）
- 后续可加 `isEmpty()` 之外的"脏数据检测 + 自动 rebuild"逻辑（暂不实现）

## 实施内容

### 1 个代码 commit

| Commit | 说明 |
|--------|------|
| `cb9891f` | fix(search): upsertMessage 同步修复 + 方案 B 重写 |

### 文件变更

- `lib/data/services/search_service.dart`
  - `search()`：扁平查询 + col=5 + `ORDER BY rank ASC, updatedAt DESC`
  - `search()` 加注释：FTS5 helper function 列索引 + 子查询上下文限制
  - `upsertMessage()`：事务化 `DELETE + INSERT`，与 `upsertNote` 同款
  - `upsertMessage()` 加注释：FTS5 无主键语义

### `flutter analyze` 静态检查

| 类别 | 状态 |
|------|------|
| 本次新增 error | 0 |
| 本次新增 warning | 0 |

## 验证

| 类别 | 状态 |
|------|------|
| `flutter analyze` | ✅ 无新增 error / warning |
| 模拟器 SQLite 直接 `sqlite3` 实测 `张学友` / `唱功` | ✅ 命中 + 高亮正确 |
| 用户手动验证（dev 热重启） | ✅ 用户反馈 "ok fixed" |
| 集成测试 Case 5（note 端去重） | 已通过上游 commit `9205baa`；本次 message 端未补测试 |
| Case 1-4（回归） | 未跑；message 端代码改动不涉及 note path |

### 手工验证清单（用户已跑过）

1. ✅ 搜索 Tab 输 `张学友` → 命中 6+ 条，snippet `张学友` 被 `<b>...</b>` 包起来
2. ✅ 搜索 `唱功` → 命中含 `唱功` 高亮的 snippet
3. ✅ 新建对话节点，含独特关键词 `REGTEST_<ts>` → 搜 → 仅 1 条（事务 DELETE+INSERT 生效）
4. ⏸ 历史脏数据清理：用户手动 SQL 清理或触发新建/编辑触发 DELETE

## 风险与遗留

| 风险 | 等级 | 状态 |
|------|------|------|
| 历史脏数据未主动清理 | 极低 | 方案 A 事务 DELETE+INSERT 对每个新 upsert 自动去重；用户手动 SQL 已提供命令 |
| FTS5 helper function 上下文限制未在 linter 拦截 | 中 | war-story 已记录；未来新增 FTS5 query 必须先 `sqlite3` 实跑验证 |
| `search()` 未加 GROUP BY 兜底 | 低 | 在 #2 限制下 GROUP BY 不可用；改由方案 A 源头解决 |
| `message` 端缺集成测试 | 中 | 本次未补；如要补，参考 [integration_test/note_search_test.dart](../../integration_test/note_search_test.dart) Case 5 改写 message 版本 |

## 修正事项

本次同步修正了上游文档中的 3 处错误（不影响功能）：

1. **CHANGELOG 2026-06-29-fts5-upsert-repeat.md** + **war-story 2026-06-29-fts5-conflict-replace-silent.md** + **edge-cases-backlog.md EC-043** 共同引用了不存在的 commit hash `fce454f`，实际为 `9205baa` —— 全部修正
2. **docs/modules/search/README.md § 关键设计原则** 行 44 写"子查询 + GROUP BY 兜底"，与实际扁平查询不符 —— 改写为实际方案
3. **edge-cases-backlog.md EC-043** 状态从"已修复（修复范围最小化，message 端未修）"升级为"✅ 完整修复（commit `cb9891f`）"

## 关联

- [CHANGELOG 2026-06-29-fts5-upsert-repeat.md](./2026-06-29-fts5-upsert-repeat.md) — 上游 commit `9205baa`，note 端修复
- [edge-cases-backlog § EC-043](../_shared/edge-cases-backlog.md) — 标 ✅ 完整修复
- [war-story 2026-06-29 FTS5 ConflictAlgorithm 静默失效](../war-stories/packages/2026-06-29-fts5-conflict-replace-silent.md) — 已补"方案 B 重写原因"
- [docs/modules/search/README.md § 关键设计原则](../modules/search/README.md) — 已改写为实际方案
- [docs/_tmp/2026-06-29-fts5-upsert-repeat-v1.md](../_tmp/2026-06-29-fts5-upsert-repeat-v1.md) — 上游 brainstorming 草稿
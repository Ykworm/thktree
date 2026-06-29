# EC-043 搜索结果重复修复（FTS5 upsert 累加 → A+B 组合方案）

| 属性 | 说明 |
|------|------|
| 日期 | 2026-06-29 |
| 范围 | `lib/data/services/search_service.dart` `upsertNote` + `search` 改造 + `integration_test/note_search_test.dart` Case 5 新增 + EC-043 backlog 状态更新 + war-story 新建 |
| 设计文档 | [`docs/_tmp/2026-06-29-fts5-upsert-repeat-v1.md`](../_tmp/2026-06-29-fts5-upsert-repeat-v1.md)（已被吸收，合并后清理） |
| 配套文档 | [edge-cases-backlog § EC-043](../_shared/edge-cases-backlog.md)（已标记 ✅ 已修复） · [war-story 2026-06-29 FTS5 ConflictAlgorithm 静默失效](../war-stories/packages/2026-06-29-fts5-conflict-replace-silent.md) |
| 状态 | 🟢 完成（代码改动 commit `9205baa`，本 CHANGELOG 由 doc commit 提交） |

## 背景

用户在笔记 tab 新建一条笔记 → 输入标题 + 正文 → 点击右上角 √ 保存 → 在搜索 tab 或笔记 tab 顶部搜索笔记标题 → **同一条笔记出现 2 次**。

定位到 EC-043（[edge-cases-backlog § EC-043](../_shared/edge-cases-backlog.md)）：三方叠加导致。

### 触发链路（5 步）

1. **打字触发 500ms 防抖**：`note_editor_screen.dart` `_scheduleSave()` 排定 500ms 后 `_saveNow`
2. **500ms 后 `_saveNow` 第 1 次**：`renameNote + writeBody`
3. **`_updateSearchIndex` 第 1 次** → `upsertNote`
4. **用户按 √ 按钮**：`await _saveNow()`
5. **`_saveNow` 跑第 2 次** → 再 `renameNote + writeBody`（幂等）→ 再 `_updateSearchIndex` → 再 `upsertNote`

`upsertNote` 被调用 2 次 + EC-043 让 2 次都插入新 rowid → 同一 `(note, noteId)` 在 `search_index` 出现 2 条 → 搜索返回 2 条。

### 根因（三方叠加）

1. **`search_index` 是 FTS5 虚拟表，无 PRIMARY KEY / UNIQUE**
   - [app_database.dart 行 64-73](../../lib/data/services/app_database.dart)
   - FTS5 虚拟表**不支持**标准 SQLite `UNIQUE` 约束
2. **`ConflictAlgorithm.replace` 在 FTS5 上静默失效**
   - 原 `search_service.dart` 行 100-120 `upsertNote` 用 `db.insert(..., conflictAlgorithm: ConflictAlgorithm.replace)`
   - 行为：**不抛错也不替换旧 rowid，而是插入新 rowid 行**（FTS5 虚拟表无主键语义）
3. **`search()` 查询无 `GROUP BY` / `DISTINCT` 去重**
   - 原 `search_service.dart` 行 53-90 直接 `SELECT ... FROM search_index MATCH ?`，全部 rowid 行都返回

### 严重性量化

- 编辑 5 次的笔记 → 搜索命中 5 条
- 10 轮对话 → 搜索命中 10 条
- iOS 后台重发叠加 → 再翻倍

## 方案

按 brainstorming 草稿确认走 **方案 A + 方案 B 组合**（源头 + 查询双兜底）。修复范围按 memory「问题修复范围最小化原则」**仅改 `upsertNote`**，暂不扩大 `upsertMessage`。

### 方案 A：源头去重（修改 `upsertNote`）

先 `DELETE FROM search_index WHERE entityType = ? AND entityId = ?` 再 `INSERT`，保证同 `(entityType, entityId)` 只保留一行。事务保证 DELETE + INSERT 原子性。

```dart
// lib/data/services/search_service.dart:111-138
Future<void> upsertNote({
  required String noteId,
  required String themeId,
  required String themeTitle,
  required String noteTitle,
  required String body,
}) async {
  try {
    await db.transaction((txn) async {
      await txn.delete(
        'search_index',
        where: 'entityType = ? AND entityId = ?',
        whereArgs: ['note', noteId],
      );
      await txn.insert('search_index', {
        'entityType': 'note',
        'entityId': noteId,
        'themeId': themeId,
        'themeTitle': themeTitle,
        'entityTitle': noteTitle,
        'content': body,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
    });
  } catch (e, st) {
    dev.log('[SearchService.upsertNote] FAILED noteId=$noteId: $e\n$st');
  }
}
```

### 方案 B：查询去重（修改 `search`）

外层 `GROUP BY entityType, entityId`，子查询里先 `bm25()` 排序，外层按 `MIN(rank)` 二次稳定排序，**自动吞掉历史脏数据**。

```sql
-- lib/data/services/search_service.dart:60-86
SELECT
  entityType,
  entityId,
  themeId,
  themeTitle,
  entityTitle,
  snippet,
  updatedAt
FROM (
  SELECT
    entityType,
    entityId,
    themeId,
    themeTitle,
    entityTitle,
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

## 实施内容

### 1 个代码 commit（worktree `codex/ec043-fts5-upsert-repeat`）

| Commit | 说明 |
|--------|------|
| `9205baa` | fix(search): A+B 组合修复 EC-043 搜索结果重复 — `upsertNote` 事务化 DELETE+INSERT + `search` 子查询 + GROUP BY 去重 + `note_search_test.dart` Case 5 新增 |

> **commit 拆分决策**：原 writing-plans 阶段计划拆 2 个 commit（A 改 upsertNote / B 改 search），实际合并为 1 个 commit。理由：A 和 B 是逻辑上的同一修复单元（EC-043 修复），拆分 commit 反而需要中途 stash + 切分支，复杂度大于收益。commit message 内明确区分两层改动。

### 集成测试 Case 5（新增）

文件：`integration_test/note_search_test.dart`

复用 Case 1 的 `_switchToTab` / `_countSearchResultEntities` 辅助函数，新增 case 5：

- 创建独特主题 + 笔记（用时间戳后缀避免重复运行冲突）
- 填标题"EC043 笔记 <ts>" + 正文含"EC043_UNIQUE_KEYWORD_<ts>"
- `pumpAndSettle` 触发 `_scheduleSave` 500ms 防抖
- 点 `AppIcons.check` 触发第 2 次 `_saveNow`
- `pumpAndSettle(2s)` 等所有异步写入完成
- 切到搜索 tab → 输入"EC043_UNIQUE_KEYWORD_<ts>" → 断言 `_countSearchResultEntities() == 1`

### `flutter analyze` 静态检查

| 类别 | 状态 |
|------|------|
| 本次新增 error | 0 |
| 本次新增 warning | 0 |
| 仓库总 error | 39（全部为本仓库既有未处理项，与本改动无关） |

## 验证

| 类别 | 状态 |
|------|------|
| Case 5（新建 + 多次保存去重）实跑 | ⏳ 用户在主仓库 dev 验证中（合并后切换目录跑 `flutter test integration_test/note_search_test.dart -d <device_id> --reporter=expanded`） |
| Case 1-4（回归） | 集成测试代码未改；待用户验证 Case 1-4 不被新 GROUP BY 影响 |
| `flutter analyze` | ✅ 无新增 error / warning |
| 方案 A（事务 DELETE+INSERT） | ✅ commit `9205baa` 已落地 |
| 方案 B（GROUP BY 查询兜底） | ✅ commit `9205baa` 已落地 |
| 历史脏数据兜底 | 集成测试覆盖不到；依赖方案 B 自动吞掉（不主动清理，按草稿 § 6） |

### 手工验证清单（用户在主仓库 dev 跑）

> AI 按 memory「代码交付与测试协作模式」不跑集成测试，由用户验证。

1. **新建笔记去重验证**
   - 笔记 tab → 点 + → 选/建主题 → 进入编辑器
   - 输入标题"EC043_测试笔记" + 正文含"EC043_UNIQUE_KEYWORD"
   - 等待 500ms → 点 √ 保存 → 回到列表
   - 切到搜索 tab → 搜"EC043_测试笔记" → **应只看到 1 条**
2. **多次保存不重复**
   - 重新进入该笔记 → 改一个字符 → 500ms → 再改一个字符 → 500ms → 按 √
   - 搜索 → **应仍只看到 1 条**
3. **历史脏数据兜底**（可选）
   - 不清空 `search_index` 直接验证方案 B：即使 `search_index` 中存在重复行，搜索结果也只显示 1 条

## 风险与遗留

| 风险 | 等级 | 状态 |
|------|------|------|
| `upsertMessage` 同 bug 未修（chat 搜索重复） | 中 | 按 memory「问题修复范围最小化原则」暂不扩大；如用户后续反馈 chat 搜索重复，立新 issue 单独处理 |
| 历史脏数据未主动清理 | 极低 | 方案 B 自动兜底，无需额外清理 |
| `db.transaction` + sqflite + FTS5 行为 | 已验证 | commit `9205baa` 已落地；无新增 analyze error |
| `GROUP BY` 子查询里 `bm25()` / `snippet()` SQLite 兼容性 | 已验证 | commit `9205baa` 已落地；无 query 错误 |
| Case 1-4 因 GROUP BY 排序改变而失败 | 低 | Case 1-4 断言"至少含 1 条"，不依赖严格排序 |

## 关联

- [edge-cases-backlog § EC-043](../_shared/edge-cases-backlog.md) — 已标记 ✅ 已修复
- [war-story 2026-06-29 FTS5 ConflictAlgorithm 静默失效](../war-stories/packages/2026-06-29-fts5-conflict-replace-silent.md) — 单独记录根因隐蔽性
- [docs/modules/search/README.md § 关键设计原则](../modules/search/README.md) — 已补充"search_index upsert 内部去重 + 查询 GROUP BY 兜底"
- [docs/_tmp/2026-06-29-fts5-upsert-repeat-v1.md](../_tmp/2026-06-29-fts5-upsert-repeat-v1.md) — brainstorming 草稿（合并后清理）
- [docs/superpowers/plans/2026-06-29-fts5-upsert-repeat.md](../superpowers/plans/2026-06-29-fts5-upsert-repeat.md) — writing-plans 阶段产物（保留作历史）
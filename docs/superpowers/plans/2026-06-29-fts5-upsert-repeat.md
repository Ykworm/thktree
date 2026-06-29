# 修复 EC-043：FTS5 upsert 累加导致搜索结果重复

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 修复 `search_index` 同一 `(entityType, entityId)` 出现多行导致搜索结果重复（EC-043）。源头修 + 查询兜底双保险。

**架构：**
- **方案 A（源头）**：`SearchService.upsertNote` 改用 `db.transaction` 包 `DELETE WHERE entityType=? AND entityId=?` + `INSERT`，避免 `ConflictAlgorithm.replace` 在 FTS5 静默失效。
- **方案 B（查询兜底）**：`SearchService.search` 用子查询 + `GROUP BY entityType, entityId` + `MIN(rank)` 聚合，吞掉历史脏数据并防止后续回归。
- 范围只改 `upsertNote`，不动 `upsertMessage`（按 memory「问题修复范围最小化原则」）。

**技术栈：** Flutter 3.x / Dart 3.x / sqflite FTS5 / Riverpod / 集成测试

**任务类型：** Bug 修复（按 AGENTS.md 工作流判定）

**关联：**
- brainstorming 草稿：[docs/_tmp/2026-06-29-fts5-upsert-repeat-v1.md](../../_tmp/2026-06-29-fts5-upsert-repeat-v1.md)
- backlog：[docs/_shared/edge-cases-backlog.md § EC-043](../../_shared/edge-cases-backlog.md)
- 关键源码：[lib/data/services/search_service.dart](../../lib/data/services/search_service.dart)
- 关键源码：[lib/data/services/app_database.dart](../../lib/data/services/app_database.dart)
- 关键源码：[lib/ui/features/notes/note_editor_screen.dart](../../lib/ui/features/notes/note_editor_screen.dart)
- 关键测试：[integration_test/note_search_test.dart](../../integration_test/note_search_test.dart)

---

## 文件结构

| 文件 | 角色 | 操作 |
|------|------|------|
| `lib/data/services/search_service.dart` | `upsertNote` 改事务；`search` 改 GROUP BY | 修改 |
| `integration_test/note_search_test.dart` | 新增 Case 5（重复验证） | 修改 |
| `docs/_shared/edge-cases-backlog.md` | EC-043 状态置为「已修复 v2」 | 修改 |
| `docs/CHANGELOG/2026-06-29-fts5-upsert-repeat.md` | 新增 CHANGELOG | 新建 |
| `docs/war-stories/flutter/2026-06-29-fts5-conflict-replace-silent.md` | 沉淀现象/根因/方案 | 新建 |
| `docs/war-stories/README.md` | 索引补一条 | 修改 |

**未触动文件**（与本任务相关但无需改）：
- `lib/data/services/app_database.dart`：FTS5 schema 不支持主键
- `lib/ui/features/notes/note_editor_screen.dart`：保存逻辑本身正确（多次 _saveNow 是预期行为），不收敛

---

## 任务 1：起 worktree + 复用 dart_define

**文件：**
- 无（git worktree 命令 + 符号链接）

- [ ] **步骤 1.1：创建 worktree**

```bash
cd /Users/yuweikang/dev/ykcode
git -C ThkTree fetch origin
git -C ThkTree worktree add ../ThkTree-worktrees/fts5-upsert-repeat -b codex/ec043-fts5-upsert-repeat origin/dev
```

预期：`worktree` 创建成功，路径为 `/Users/yuweikang/dev/ykcode/ThkTree-worktrees/fts5-upsert-repeat`，分支为 `codex/ec043-fts5-upsert-repeat`。

- [ ] **步骤 1.2：复用 `build/dart_define.json`（如存在）**

```bash
if [ -f /Users/yuweikang/dev/ykcode/ThkTree/build/dart_define.json ]; then
  ln -s /Users/yuweikang/dev/ykcode/ThkTree/build/dart_define.json \
        /Users/yuweikang/dev/ykcode/ThkTree-worktrees/fts5-upsert-repeat/build/dart_define.json
fi
ls -la /Users/yuweikang/dev/ykcode/ThkTree-worktrees/fts5-upsert-repeat/build/dart_define.json
```

预期：若主仓库 `build/dart_define.json` 存在，worktree 内是符号链接（指向主仓库同一文件）；否则下一步生成。

- [ ] **步骤 1.3（如主仓库无 `build/dart_define.json`）：生成**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree-worktrees/fts5-upsert-repeat
dart run tools/gen_dart_define.dart ~/.thktree/test_llm_config.json build/dart_define.json
```

预期：`build/dart_define.json` 生成成功。

> **注**：本任务用不到 LLM 注入（搜索是纯客户端），但集成测试 driver 启动时仍会读 `dart_define.json`，所以保留文件存在性。

- [ ] **步骤 1.4：确认 worktree 内 dev 同步**

```bash
git -C /Users/yuweikang/dev/ykcode/ThkTree-worktrees/fts5-upsert-repeat log -1 --oneline
```

预期：head 是 `origin/dev` 的最新 commit（用于后续 rebase）。

---

## 任务 2：写失败测试 Case 5（TDD 红灯）

**文件：**
- 修改：`integration_test/note_search_test.dart`（在文件末尾追加 Case 5 + helper）

- [ ] **步骤 2.1：在 `note_search_test.dart` 末尾的 `}` 闭合前插入 Case 5**

定位：当前 `testWidgets('Case 4: ...')` 块结束后紧跟文件结束的 `}`（在第 203 行附近）。在 `testWidgets('Case 4: ...')` 之后、`void main() {}` 的 `}` 之前插入新 case。

插入内容：

```dart
  testWidgets(
    'Case 5: 新建笔记后多次保存 → 搜索结果去重（EC-043 回归）',
    (tester) async {
      final app = await createTestApp(locale: const Locale('zh'));
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      final ts = DateTime.now().millisecondsSinceEpoch;
      final themeTitle = 'Dedupe主题_$ts';
      final noteTitle = 'Dedupe笔记_$ts';
      // 唯一关键词 — 只能命中本笔记
      final uniqueKeyword = 'DEDUPE_UNIQUE_KW_$ts';

      // ── 准备：在主题内建一条笔记 ──────────────────────────────────────
      await _switchToTab(tester, '笔记');
      await tester.pumpAndSettle();

      // 点 + 进入主题选择
      await tester.tap(find.byKey(const ValueKey('add_note_button')));
      await tester.pumpAndSettle();

      // ThemePicker → 点 + 创建新主题
      await tester.tap(find.byIcon(AppIcons.add).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoTextField).last, themeTitle);
      await tester.pump();
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      // 等待编辑器进入稳态
      await tester.pump(const Duration(milliseconds: 500));

      // 填标题 + 正文（含唯一关键词）
      await tester.enterText(
        find.byKey(const ValueKey('note_title_input')),
        noteTitle,
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('note_body_input')),
        '正文包含唯一关键词 $uniqueKeyword 用于复现 EC-043',
      );

      // 触发 500ms 防抖（第 1 次 _saveNow）
      await tester.pump(const Duration(milliseconds: 600));

      // 显式再点 √（触发第 2 次 _saveNow）—— 这是 EC-043 的关键触发条件
      await tester.tap(find.byIcon(AppIcons.check));
      await tester.pumpAndSettle();

      // 等所有 fire-and-forget 的 _updateSearchIndex 全部跑完
      await tester.pump(const Duration(seconds: 2));

      // ── 验证：搜索唯一关键词，结果应只 1 条 ──────────────────────────
      final searchField = find.byType(CupertinoSearchTextField).first;
      await tester.enterText(searchField, uniqueKeyword);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // 该关键词只能命中本笔记；Case 5 强断言"恰好 1 条"
      expect(_countSearchResultEntities(), 1,
          reason:
              '用唯一关键词 "$uniqueKeyword" 搜应恰好返回 1 条结果（EC-043: 多次 upsertNote 在 search_index 累加多行）');
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
```

- [ ] **步骤 2.2：跑测试确认失败（红灯）**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree-worktrees/fts5-upsert-repeat
flutter test integration_test/note_search_test.dart \
  -n "Case 5" \
  --reporter=expanded
```

预期输出关键行（红灯）：

```
Expected: 1
  Actual: 2
'reason: 用唯一关键词 "DEDUPE_UNIQUE_KW_..." 搜应恰好返回 1 条结果（EC-043: 多次 upsertNote 在 search_index 累加多行）'
```

或类似 EXPECT 失败堆栈。如果有 `Bad state: ...` 或 widget 找不到的报错，对照源码修复辅助函数。

> **不要 commit**，本任务目的是确认红灯。

---

## 任务 3：实施方案 A（upsertNote 改事务）

**文件：**
- 修改：`lib/data/services/search_service.dart`（替换 `upsertNote` 方法体）

- [ ] **步骤 3.1：替换 `upsertNote` 方法体**

定位：[lib/data/services/search_service.dart:100-120](../../lib/data/services/search_service.dart#L100-L120)

将原方法体：

```dart
  Future<void> upsertNote({
    required String noteId,
    required String themeId,
    required String themeTitle,
    required String noteTitle,
    required String body,
  }) async {
    try {
      await db.insert('search_index', {
        'entityType': 'note',
        'entityId': noteId,
        'themeId': themeId,
        'themeTitle': themeTitle,
        'entityTitle': noteTitle,
        'content': body,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e, st) {
      dev.log('[SearchService.upsertNote] FAILED noteId=$noteId: $e\n$st');
    }
  }
```

替换为：

```dart
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

> **关键点**：
> - 不再用 `ConflictAlgorithm.replace`（FTS5 静默失效）
> - 在事务内先 DELETE 旧行再 INSERT，原子性保证
> - WHERE 条件与原 `delete` 单行删除方法一致（`search_service.dart:151-161`），保持同表同字段语义

- [ ] **步骤 3.2：跑测试 Case 5 验证是否过**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree-worktrees/fts5-upsert-repeat
flutter test integration_test/note_search_test.dart \
  -n "Case 5" \
  --reporter=expanded
```

**预期**：

- **如果 PASS**（`Actual: 1`）→ 继续步骤 3.3
- **如果 FAIL** → 可能有以下原因，按序排查：
  1. 事务内 FTS5 DML 行为异常（极少见）→ 改用非事务 DELETE+INSERT，回滚本步骤
  2. 辅助函数 `_countSearchResultEntities` 计数不对 → 读 [lib/ui/features/search/search_content.dart](../../lib/ui/features/search/search_content.dart) 确认 ListView 渲染方式
  3. fire-and-forget 时序问题 → 在 `await tester.pump(const Duration(seconds: 2));` 之前再 `tester.pump(const Duration(seconds: 3));`

- [ ] **步骤 3.3：跑回归 Case 1-4**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree-worktrees/fts5-upsert-repeat
flutter test integration_test/note_search_test.dart \
  --reporter=expanded
```

预期：Case 1-4 全部 PASS（无回归）。如果失败，原方案 A 改了 `upsertNote` 行为但 search 还没改，理论上不应影响；按失败原因排查。

- [ ] **步骤 3.4：Commit 方案 A**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree-worktrees/fts5-upsert-repeat
git add lib/data/services/search_service.dart
git add integration_test/note_search_test.dart
git commit -m "fix(search): upsertNote 改事务 DELETE+INSERT，修复 EC-043 累加

- search_index 是 FTS5 虚拟表，ConflictAlgorithm.replace 静默失效
- 改用 db.transaction 包 DELETE WHERE (entityType, entityId) + INSERT
- 新增 Case 5 验证：多次保存后搜索唯一关键词应只 1 条结果
- 现有 Case 1-4 回归通过

Ref: EC-043
Ref: docs/_shared/edge-cases-backlog.md"
```

---

## 任务 4：实施方案 B（search 改 GROUP BY 兜底）

**文件：**
- 修改：`lib/data/services/search_service.dart`（替换 `search` 方法的 SQL）

- [ ] **步骤 4.1：替换 `search` 方法的 rawQuery**

定位：[lib/data/services/search_service.dart:53-90](../../lib/data/services/search_service.dart#L53-L90)

将原 rawQuery：

```dart
      final rows = await db.rawQuery('''
        SELECT
          entityType,
          entityId,
          themeId,
          themeTitle,
          entityTitle,
          snippet(search_index, 1, '<b>', '</b>', '...', 40) AS snippet,
          updatedAt
        FROM search_index
        WHERE search_index MATCH ?
        ORDER BY bm25(search_index, 0.0, 1.0, 0.0, 0.0, 0.5, 5.0) ASC,
                 updatedAt DESC
        LIMIT ?
      ''', [sanitized, limit]);
```

替换为：

```dart
      final rows = await db.rawQuery('''
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
      ''', [sanitized, limit]);
```

> **关键点**：
> - 子查询里把 `snippet()` 和 `bm25()` 都算好、起别名（`snippet` / `rank`）
> - 外层 `GROUP BY (entityType, entityId)` 实现去重
> - `MIN(rank)` 排序（小 = 更相关），`MAX(updatedAt)` 稳定排序（最新优先）
> - 同一 `(entityType, entityId)` 多行只保留 1 行（SQLite 聚合选任一行；本场景所有行的 snippet 内容相同，差异只在 bm25/updatedAt，但都通过聚合函数收敛到单一值）

- [ ] **步骤 4.2：跑测试 Case 1-5 全绿**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree-worktrees/fts5-upsert-repeat
flutter test integration_test/note_search_test.dart \
  --reporter=expanded
```

预期：Case 1-5 全部 PASS。如果 Case 4 失败（两 tab 结果数不一致），可能 GROUP BY 对 message 类也有副作用；读 [lib/ui/features/search/search_content.dart](../../lib/ui/features/search/search_content.dart) 排查。

- [ ] **步骤 4.3：Commit 方案 B**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree-worktrees/fts5-upsert-repeat
git add lib/data/services/search_service.dart
git commit -m "fix(search): search() 用 GROUP BY 兜底去重，吞掉历史脏数据

- 子查询算 snippet() + bm25()，外层 GROUP BY (entityType, entityId) 去重
- ORDER BY MIN(rank), MAX(updatedAt) 保留最相关 + 最新结果
- 即使 A 方案回归或历史 search_index 已有重复行，B 也能保证不返回重复结果
- 现有 Case 1-5 全部通过

Ref: EC-043
Ref: docs/_shared/edge-cases-backlog.md"
```

---

## 任务 5：flutter analyze 静态检查

- [ ] **步骤 5.1：跑 flutter analyze**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree-worktrees/fts5-upsert-repeat
flutter analyze lib/data/services/search_service.dart \
               integration_test/note_search_test.dart
```

预期：`No issues found!` 或仅展示原有 issue（与本任务无关）。

- [ ] **步骤 5.2：跑全项目 analyze（如有需要）**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree-worktrees/fts5-upsert-repeat
flutter analyze
```

预期：本次改动**不新增** error / warning。如果有 `info` 级别且与本次改动相关，修掉；否则忽略（AGENTS.md 关注 error/warning）。

---

## 任务 6：手工验证（按用户偏好「代码交付与测试协作模式」）

AI **不跑**集成测试 driver 启动（`flutter drive`），仅输出步骤给用户。

- [ ] **步骤 6.1：准备手工验证清单**

输出到终端供用户执行：

```markdown
## 手工验证 EC-043 修复（请在你的 dev 环境跑）

### 准备
- 主仓库 + 当前 worktree 都 `git pull` 到最新
- 启动模拟器/真机 + 装 worktree 编译产物
  cd /Users/yuweikang/dev/ykcode/ThkTree-worktrees/fts5-upsert-repeat
  flutter run

### Case A：新建笔记去重（方案 A 验证）
1. 笔记 tab → 点 + → 创建新主题「EC043手工测试」→ 进入编辑器
2. 标题「手工测试笔记」+ 正文「包含 EC043_UNIQUE_KEYWORD」
3. 等待 500ms（让防抖触发第 1 次 _saveNow）
4. 点 √（触发第 2 次 _saveNow）
5. 切到搜索 tab → 搜「EC043_UNIQUE_KEYWORD」
6. **预期**：只看到 1 条结果（修复前是 2 条）

### Case B：多次保存去重（方案 A 验证）
1. 重新进入该笔记 → 改标题/正文一个字符 → 500ms → 再改一个字符 → 500ms → √
2. 搜索「EC043_UNIQUE_KEYWORD」
3. **预期**：仍只看到 1 条

### Case C：历史脏数据兜底（方案 B 验证）
1. 不清空 search_index
2. 直接打开 App，搜索已存在的笔记
3. **预期**：结果数量与之前一致（即使之前有重复历史行也被 GROUP BY 收敛）
```

---

## 任务 7：context-sync（仅改 doc）

**文件：**
- 修改：`docs/_shared/edge-cases-backlog.md`（EC-043 章节）
- 新建：`docs/CHANGELOG/2026-06-29-fts5-upsert-repeat.md`
- 新建：`docs/war-stories/flutter/2026-06-29-fts5-conflict-replace-silent.md`
- 修改：`docs/war-stories/README.md`（索引）

- [ ] **步骤 7.1：更新 EC-043 状态**

定位：[docs/_shared/edge-cases-backlog.md § EC-043](../../_shared/edge-cases-backlog.md)（行 235-270 附近）

在 EC-043 块内追加：

```markdown
### 修复记录

- **修复日期**：2026-06-29
- **修复 commit**：`codex/ec043-fts5-upsert-repeat`（两次 commit：A 源头事务 + B 查询 GROUP BY）
- **修复方案**：A + B 组合
  - A：`SearchService.upsertNote` 改用 `db.transaction` 包 DELETE+INSERT，避免 `ConflictAlgorithm.replace` 在 FTS5 静默失效
  - B：`SearchService.search` 用子查询 + `GROUP BY (entityType, entityId)` + `MIN(rank)` 兜底
- **范围**：`upsertNote` 单点修复（`upsertMessage` 同源 bug 未在本轮处理）
- **关联测试**：`integration_test/note_search_test.dart` Case 5
```

- [ ] **步骤 7.2：新增 CHANGELOG**

新建 `docs/CHANGELOG/2026-06-29-fts5-upsert-repeat.md`：

```markdown
# 2026-06-29 · 修复搜索结果重复（EC-043）

## 修复

- **搜索结果去重** — 同一笔记在搜索结果中只出现 1 次
  - 源头：FTS5 `search_index` 虚拟表不支持 `ConflictAlgorithm.replace`，多次 `upsertNote` 累加多行
  - 修复 1：`SearchService.upsertNote` 改用 `db.transaction` 包 `DELETE WHERE (entityType, entityId)` + `INSERT`
  - 修复 2：`SearchService.search` 用子查询 + `GROUP BY (entityType, entityId)` + `MIN(rank)` 兜底去重
  - 范围：仅修改 `upsertNote`（`upsertMessage` 同源 bug 暂未处理，按「问题修复范围最小化」原则）
  - 测试：新增 `integration_test/note_search_test.dart` Case 5
  - 关联：EC-043、war-story `2026-06-29-fts5-conflict-replace-silent`
```

- [ ] **步骤 7.3：新增 war-story**

新建 `docs/war-stories/flutter/2026-06-29-fts5-conflict-replace-silent.md`：

```markdown
# FTS5 ConflictAlgorithm.replace 静默失效导致搜索重复

## 现象

新建笔记 → 标题 + 正文 → 搜索关键词 → 同一笔记在搜索结果中出现 2 次。

- 测试环境：模拟器/真机均可复现
- 触发条件：编辑笔记过程中触发 ≥ 2 次 `_saveNow`（500ms 防抖 + √ 按钮）
- 期望结果：搜索结果 1 条
- 实际结果：搜索结果 2 条

## 根因

三层叠加：

1. **`search_index` 是 FTS5 虚拟表，无 PRIMARY KEY / UNIQUE**
   - FTS5 虚拟表不支持标准 SQLite `UNIQUE` 约束
   - schema：[lib/data/services/app_database.dart:62-73](../../lib/data/services/app_database.dart#L62-L73)

2. **`ConflictAlgorithm.replace` 在 FTS5 上静默失效**
   - sqflite 的 `db.insert(..., conflictAlgorithm: replace)` 在 FTS5 表上**不抛错也不替换旧 rowid**
   - 行为是**插入新 rowid 行**，旧行依然存在
   - 因此多次 `upsertNote` 同一 `(note, noteId)` 会在表里堆出多行

3. **`search()` 查询无 `GROUP BY` / `DISTINCT` 去重**
   - 直接 `SELECT ... FROM search_index MATCH ?`，所有 rowid 行都返回

### 触发链路

| 步骤 | 行为 |
|------|------|
| 1 | 用户打字 → 500ms 防抖 |
| 2 | 500ms 后 `_saveNow` 跑第 1 次（`upsertNote` 插第 1 行） |
| 3 | 用户点 √ → `_saveNow` 跑第 2 次（`upsertNote` 想 replace 第 1 行但静默失效，插第 2 行） |
| 4 | `search_index` 同一 `(note, noteId)` 有 2 行 |
| 5 | 搜索返回 2 条结果 |

## 解决方案

A + B 组合（双保险）：

- **方案 A** — 源头修：`SearchService.upsertNote` 改用 `db.transaction` 包 `DELETE WHERE (entityType, entityId)` + `INSERT`，原子性保证
- **方案 B** — 查询兜底：`SearchService.search` 用子查询 + `GROUP BY (entityType, entityId)` + `MIN(rank)` 聚合，吞掉历史脏数据 + 防止后续回归

## 排查关键

- 用 `_updateSearchIndex` 的 `dev.log` 输出 → 看到"FAILED"才看 stack trace；但本 bug 路径**不抛错**，日志里完全静默
- 直接查 SQLite `search_index` 表 → `SELECT entityType, entityId, COUNT(*) FROM search_index GROUP BY entityType, entityId HAVING COUNT(*) > 1;` → 能看到重复行
- 复现条件必须是**多次 `_saveNow` 触发**（防抖 + √），单次保存看不到

## 后续避免

- 给所有 FTS5 写操作加事务或显式 DELETE+INSERT，**不要依赖 `ConflictAlgorithm.replace`**
- `search_index` 这类聚合表，查询侧都要 `GROUP BY (entityType, entityId)` 兜底
- 集成测试要覆盖"多次写入后查询"的去重场景
```

- [ ] **步骤 7.4：更新 war-stories 索引**

定位：[docs/war-stories/README.md](../../war-stories/README.md)

在倒序索引中追加：

```markdown
- [2026-06-29 FTS5 ConflictAlgorithm.replace 静默失效导致搜索重复](flutter/2026-06-29-fts5-conflict-replace-silent.md)
```

- [ ] **步骤 7.5：跑全项目 analyze 再次确认**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree-worktrees/fts5-upsert-repeat
flutter analyze
```

预期：本次 doc 改动**不引入**新 issue。

---

## 任务 8：Worktree 收尾（按 AGENTS.md「Worktree 收尾流程」）

- [ ] **步骤 8.1：rebase dev**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree-worktrees/fts5-upsert-repeat
git fetch origin
git rebase origin/dev
```

预期：rebase 成功；如果有冲突，按提示解决（主要可能是 EC-043 backlog 或 search_service.dart 同期修改）。

- [ ] **步骤 8.2：合并回 dev（ff-only）**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree
git checkout dev
git merge --ff-only codex/ec043-fts5-upsert-repeat
```

预期：fast-forward 合并，dev 分支历史线性。

- [ ] **步骤 8.3：清理 worktree**

```bash
git worktree remove ../ThkTree-worktrees/fts5-upsert-repeat
git branch -d codex/ec043-fts5-upsert-repeat
```

预期：worktree 列表不再有 `fts5-upsert-repeat`，分支已删除。

- [ ] **步骤 8.4：清理 `docs/_tmp/`**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree
git rm docs/_tmp/2026-06-29-fts5-upsert-repeat-v1.md
git commit -m "docs: 清理 EC-043 brainstorming 草稿（已合入 dev）"
```

预期：`docs/_tmp/` 目录不再有本次任务的 brainstorming 草稿（CHANGELOG / war-story 已转正到正式位置）。

---

## 自检

**1. 规格覆盖度**（对照 brainstorming 草稿 § 2 决策 / § 3 影响范围）：

- ✅ 方案 A：`SearchService.upsertNote` 改事务 → 任务 3
- ✅ 方案 B：`SearchService.search` 改 GROUP BY → 任务 4
- ✅ Case 5 集成测试 → 任务 2
- ✅ 静态检查 → 任务 5
- ✅ 手工验证 → 任务 6
- ✅ context-sync（EC-043 状态 + CHANGELOG + war-story）→ 任务 7
- ✅ 收尾（rebase + merge）→ 任务 8

**2. 占位符扫描**：

- 无 "TODO" / "待定" / "类似任务 N" 出现
- 每步都有具体命令、具体代码、具体预期输出
- 文件路径、commit message 完整

**3. 类型一致性**：

- `upsertNote` 签名未变 → 任务 3 步骤 3.1 替换方法体不动签名
- `search` 签名未变 → 任务 4 步骤 4.1 替换 rawQuery 不动签名
- `SearchResult` 类未动 → 任务 4 步骤 4.1 列别名与 SearchResult 字段对应（`entityType`/`entityId`/`themeId`/`themeTitle`/`entityTitle`/`snippet`/`updatedAt`）

**无遗漏**，进入执行阶段。

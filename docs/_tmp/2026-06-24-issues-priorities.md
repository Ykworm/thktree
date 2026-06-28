# ThkTree 最优先处理 Issues（2026-06-24）

> **本文件定位**：集中列出 2026-06-24 用户明确指定的"最优先处理"清单，避免散落在各 backlog 文档里。
> **来源**：用户原话 —— "我们这里只是修改文档，修需求，但不碰后面的环节。刚才两个问题请记录到最优先处理的"
> **日期**：2026-06-24
> **硬约束**（用户同时明确）：**本轮只修改文档、修需求，不碰后续环节**——不建 worktree、不写代码、不集成测试、不 git commit（`docs/_tmp/` 规则 + 用户指令双重约束）。

---

## 🔴 最优先清单（2 项）

### 1. P.9 创建 sub chat "自由发挥" 选项 + 选择 sheet 间距优化

| 字段 | 内容 |
|------|------|
| **类型** | 产品需求（功能增强 + UI 微调） |
| **一句话** | 主题/对话页创建 sub chat 时，新增"自由发挥"入口（用户自填 title 进入空对话）；同时修复 `showBranchModeSheet` 第一行文字与 sheet 顶部的视觉间距过大问题 |
| **优先级** | 🔴 **最优先**（2026-06-24 用户明确指定） |
| **状态** | pending · 已完成点穴式 brainstorm |
| **卡片位置** | [`docs/_tmp/2026-06-24-product-feedback-backlog.md`](2026-06-24-product-feedback-backlog.md) § P.9 |
| **工作量估计** | **A. 自由发挥**：小（1-2 天）<br>**B. sheet 间距**：极小（<0.5 天）<br>**合计**：1.5 - 2.5 天 |
| **关键未决问题** | **A. 自由发挥维度**：<br>　a) 入口位置（sheet 第三项 / 独立按钮）<br>　b) 节点位置（停留在源节点 / 新建根节点）<br>　c) source content（携带 / 完全空白）<br>　d) title 占位文案<br>　e) LLM 后置参与<br>**B. sheet 间距维度**：<br>　a) 目标间距值<br>　b) 同步圆角<br>　c) 修复范围（本 sheet / 全局）<br>　d) 对齐 [design-tokens](../_shared/design-tokens.yaml) |
| **触发深入指令** | "深入 P.9" / "做自由发挥" / "修 sheet 间距" / "做 P.9" |

**用户原文**："创建 sub chat，我觉得应该增加一个选择，就是用户自己自由发挥，自己填写 title，然后进入空对话自己发挥；另外就是这个弹出的选择 sheet，貌似第一行文字与顶部的距离太大了，比例不好看"

---

### 2. EC-043 搜索结果重复（FTS5 无主键 + upsert 累加）

| 字段 | 内容 |
|------|------|
| **类型** | Bug 修复（缺陷） |
| **一句话** | 搜索结果出现重复条目；根因是 `search_index` FTS5 虚拟表无主键 + `ConflictAlgorithm.replace` 在 FTS5 上静默失效 + `search()` 查询未去重，三方叠加导致 `upsertNote` / `upsertMessage` 每次都新增 rowid 行 |
| **优先级** | 🔴 **P0 / 最优先**（2026-06-24 用户明确指定） |
| **状态** | pending · 已定位根因 · 待选修复方案 |
| **卡片位置** | [`docs/_shared/edge-cases-backlog.md`](../_shared/edge-cases-backlog.md) § EC-043（§ 3.5 + § 4 P0 表） |
| **工作量估计** | **方案 A**（upsert 内 DELETE 同 `(entityType, entityId)` 旧行再 INSERT）：小（0.5-1 天）<br>**方案 B**（查询尾部 GROUP BY 去重）：极小（<0.5 天）<br>**方案 C**（FTS5 external content + 普通 SQLite 主键表）：大（架构级重构，不推荐）<br>**推荐组合**：A + B（1 - 1.5 天） |
| **根因** | 1. `app_database.dart` 行 64-73：`search_index` schema **无 PRIMARY KEY / UNIQUE**（FTS5 虚拟表不支持标准 UNIQUE 约束）<br>2. `search_service.dart` 行 100-120 / 126-146：`db.insert(..., conflictAlgorithm: ConflictAlgorithm.replace)` 在 FTS5 虚拟表上**静默失效**，仍插入新 rowid 行<br>3. `search_service.dart` 行 53-90：`search()` 直接 `SELECT ... FROM search_index MATCH ?`，**未做去重**（无 `GROUP BY` / `DISTINCT`） |
| **触发累加点** | - **笔记保存**：`note_editor_screen.dart` 行 143 + `note_detail_screen.dart` 行 127 → `upsertNote`<br>- **LLM 流式 onDone**：`chat_task_service.dart` 行 138-148 → 行 167-202 `_updateSearchIndex` → `upsertMessage`<br>- **iOS 后台重发叠加**：每次后台重发都再调一次 `upsertMessage`（按 [ADR-015](../DECISIONS.md) disk-first 策略） |
| **建议验证方式** | 1. 同一笔记连续 `upsertNote` 3 次后搜索，断言结果数 = 1（当前预期失败：实际返回 3）<br>2. mock LLM 触发 3 轮 `finishAssistant` 后搜索，断言 message 类型结果数 = 1<br>3. 验证 `rebuildAll`（先 DELETE 再 INSERT）路径作为对照基准 |
| **触发深入指令** | "深入 EC-043" / "修搜索重复" / "做 EC-043" |

**用户原文**："然后，搜索功能有bug，会出现重复的搜索结果" —— 后续："这个优先 fix"

---

## 📋 集中索引

| 类型 | 编号 | 文档路径 | 紧迫度 |
|------|------|---------|------|
| 产品需求 | P.9 | [product-feedback-backlog.md](2026-06-24-product-feedback-backlog.md) § P.9 | 🔴 最优先 |
| Bug 修复 | EC-043 | [edge-cases-backlog.md § 3.5](../_shared/edge-cases-backlog.md#35-sqlite-fts5-索引边界) | 🔴 最优先 |

---

## 🚦 处理流程（待用户触发）

按 AGENTS.md 工作流，任一项最优先 issue 触发"深入"指令后，进入完整流程：

1. **brainstorming** —— 澄清关键未决问题
2. **草稿归档** —— 写入 `docs/_tmp/<topic>.md`
3. **用户确认** —— 用户明确说"可以"
4. **writing-plans** —— 输出书面实现计划
5. **验证优先** —— 定义验收方式（推荐 `integration_test/search_test.dart` 或新建分支测试文件）
6. **context-sync** —— 同步文档
7. **收尾** —— worktree + commit + rebase + 合并

**本轮不启动上述流程**——按用户"只改文档、不碰后续环节"指令，等待用户主动触发深入指令后再启动。

---

## 📝 维护约定

- **本文件**随两个最优先 issue 状态变化更新（pending → designing → planned → done → 删除）
- 两个 issue 任一完成时：把对应行状态改为"done"并标注完成日期
- 两个 issue 都完成时：本文件归档到 `docs/_done/2026-06-24-issues-priorities.md`
- 新增最优先 issue：在末尾追加，优先级高于 backlog 内其他所有项

> 待用户对任一项触发"深入"指令后再启动完整流程。
# context-sync — 文档上下文同步

将本次会话中已完成的代码改动，同步回写到 `docs/` 下受影响的文档。

## 触发命令

- "同步文档"
- "docs sync"
- "context-sync"
- "ctsync"

## 硬约束（不可违反）

1. **改 doc 是唯一允许的副作用** — 不改代码、不改 assets、不改配置
2. **不执行 git add / git commit / git push** — 改完即停
3. **doc 改动的 commit 决定权 100% 留给用户**
4. **不做表格** — 影响清单用"列表 + 卡片"，卡片支持按章节细分、支持自由草稿
5. **不写 diff 块** — 改完后用户用 git diff 看真实 diff，AI 不手写 diff
6. **每个 doc 都要给出影响/不影响/待确认的判断** — 即使"不影响"也要写一行理由
7. **不问用户"准备好了没有"** — 用户触发即执行，不设前置条件

## 流程

### Step 1：收集改动范围

```bash
git diff --name-only HEAD
```

拿到本次会话中改动过的文件列表（未 commit 的也算）。

如果 git diff 为空（全部已 commit），则基于会话中的对话上下文推断本次改动范围。

### Step 2：遍历 docs 全量

```bash
find docs -type f \( -name "*.md" -o -name "*.yaml" \)
```

拿到 docs/ 下所有 Markdown + YAML 文件清单（递归）。

- `*.md` — 文档主体
- `*.yaml` — 模块级 design-tokens 规范（页面定义、交互、存储格式等结构化描述）

### Step 3：逐 doc 三重判断

对每个 doc 文件，依次跑三层判断：

1. **路径相关** — 文件路径是否含本次改动的模块名（例：改动涉及 `lib/ui/notes/` → `docs/modules/notes/**` 路径相关）
2. **内容相关** — doc 内容是否引用本次改动涉及的类名/函数名/组件名/常量名（用 rg 快扫，rg 不可用则 fallback grep）
3. **类型相关** — 改动类型 × doc 类型的对应关系：
   - 功能新增/删除 → `FEATURES.md` + 对应模块 README
   - 依赖变更 → `TECH-DEBT.md` + `DECISIONS.md`
   - 设计决策 → `DECISIONS.md`（新增 ADR）
   - 视觉/交互 → 模块 README（含 `visual/` 子目录）+ `_shared/design-system.md` + `_shared/design.md`
   - 架构层变更 → `ARCHITECTURE.md`
   - 数据模型 → `_shared/storage-format.md` + 对应模块 README
   - 主题/样式 → `modules/themes/` 相关

**白名单兜底**：`FEATURES.md`、`TECH-DEBT.md`、`DECISIONS.md` 任何代码改动都要扫一遍。

### Step 4：输出影响清单

**格式：列表 + 卡片，禁用表格。**

```markdown
## 📊 影响清单（共遍历 N 个 doc，影响 M 个）

- 📄 `docs/FEATURES.md` — 大改版 · § 笔记模块
- 📄 `docs/modules/notes/README.md` — 小补 · § API 列表
- 📄 `docs/DECISIONS.md` — 新增 · ADR-013
- 📄 `docs/ARCHITECTURE.md` — 不影响 · 未涉及架构层变更
- 📄 `docs/_shared/design-system.md` — 待确认 · 本次改了 button 样式，是否需要更新 spacing token？
```

**变更强度枚举**：大改版 / 小补 / 新增 / 删除 / 不影响 / 待确认

### Step 5：逐 doc 卡片

每个受影响的 doc 输出一张独立卡片：

```markdown
---

## 📄 docs/FEATURES.md

**变更类型**：大改版
**影响范围**：§ 笔记模块（§ 1.1、§ 1.3）+ § 主题模块（§ 2.3）
**触发原因**：本次重构 NoteService，增加 password 保护 + AI 摘要两步

### § 笔记模块

#### § 1.1 创建流程 — 修改

**变更描述**：在"创建笔记"步骤后增加"AI 摘要自动写入"一步，触发条件 note.title.length > 5

#### § 1.3 字段说明 — 新增

**变更描述**：新增 `note.summary` 字段说明（AI 自动摘要，30 字以内，由 NoteService.create() 同步生成）

### § 主题模块

#### § 2.3 密码保护 — 小补

**变更描述**：补充密码 fallback 路径——忘记密码可重新创建主题（数据无法恢复）
```

**卡片字段说明**：
- **变更类型**：大改版 / 小补 / 新增 / 删除
- **影响范围**：§ 章节定位，可多个
- **触发原因**：AI 自动生成（基于 git diff + 会话上下文推断），不是用户输入
- **变更描述**：自然语言，讲清楚改什么、为什么改

**大改版横跨多章节时**：卡片内按"原章节 § X.X"再切分小节。

### Step 6：用户确认

把影响清单 + 所有卡片一次性输出，等用户确认。

用户可以说：
- "OK" / "全部" / "都改" → 全部执行
- "跳过 XX" / "只改 XX" → 按指示执行
- "调整" → 修改后再确认

### Step 7：改 doc 文件

对每个确认的 doc，按卡片描述逐章节修改。改完即停，不 commit。

### Step 8：汇报

```markdown
## ✅ context-sync 完成

- 遍历 doc：N 个
- 影响 doc：M 个
- 已改 doc：K 个
- 未提交（留给用户统一 commit）

已改文件：
- docs/FEATURES.md（§ 1.1、§ 1.3、§ 2.3）
- docs/modules/notes/README.md（§ API 列表）
- docs/DECISIONS.md（新增 ADR-013）
```

## 工具优先级

| 步骤 | 优先工具 | fallback |
|------|---------|----------|
| 收集改动范围 | `git diff --name-only HEAD` | 会话上下文推断 |
| 遍历 docs | `find docs -type f \( -name "*.md" -o -name "*.yaml" \)` | — |
| 内容相关判断 | `rg -l "类名" docs/` | `grep -rl "类名" docs/` |
| 符号引用判断 | CodeGraph MCP（如运行中） | rg / grep（精度有限，告知用户） |
| 改 doc 文件 | 直接写文件 | — |

**工具降级时必须告知用户**：

如果 CodeGraph 不可用，在影响清单之前输出：
```
⚠️ CodeGraph 未运行，符号引用判断降级为 rg/grep 文本匹配，结果可能有误判。
```

如果 rg 不可用，自动 fallback 到 grep，无需告知。

## 不在本 Skill 管辖范围

- 代码改动（不在本 Skill 内）
- 代码 commit（由代码改动的 Agent/会话决定）
- doc 的 git add / commit / push（用户统一收口时处理）
- 预判哪些文档会受影响（用户随时可触发，不限时机）

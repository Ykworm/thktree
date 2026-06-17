## 功能开发工作流

收到新功能需求时，必须严格遵循以下阶段，**不可跳步**：

1. **brainstorming** — 先讨论方案，不写代码。探索用户意图、需求、设计方案，达成共识
2. **草稿归档** — 讨论结果写入 `docs/_tmp/<topic>.md`（版本迭代加 `-v2`、`-v3`）
3. **用户确认** — 用户明确说"可以"后才进入下一步
4. **writing-plans** — 输出书面实现计划
5. **TDD** — 先写测试，再写实现
6. **context-sync** — 完成后同步文档

**硬约束**：方案确认前禁止写任何业务代码。

---

## context-sync

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

## 执行范式（ReAct）

每次执行 context-sync 必须严格遵循 THOUGHT → ACTION → OBSERVATION 循环。
禁止跳过任何步骤的 OBSERVATION，禁止在未看到工具返回值之前做假设。

### 范例 1（正常流程）

**用户**：ctsync

**Agent**：

> **THOUGHT**：用户触发 context-sync。第一步必须确认工具可用性。
>
> **ACTION**：`codegraph status`
>
> **OBSERVATION**：[返回索引状态：文件数、节点数、是否最新]
>
> **THOUGHT**：CodeGraph 可用，符号引用判断使用 codegraph。接下来收集改动范围。
>
> **ACTION**：`git diff --name-only HEAD`
>
> **OBSERVATION**：[返回改动文件列表]
>
> **THOUGHT**：改动涉及 XX 模块。接下来遍历 docs 并做三重判断。
> （继续后续步骤...）

### 范例 2（CodeGraph 不可用时的降级处理）

**Agent**：

> **THOUGHT**：第一步必须确认工具可用性。
>
> **ACTION**：`codegraph status`
>
> **OBSERVATION**：[Error: index not found / not running]
>
> **THOUGHT**：CodeGraph 不可用，必须执行降级策略并告知用户。使用 rg 搜索符号引用，精度有限需在影响清单前声明。
>
> **ACTION**：`rg "ClassName" docs/ --type md`
>
> **OBSERVATION**：[返回匹配文件列表]
>
> **THOUGHT**：继续使用 rg 完成后续影响评估...

## 流程

### 🛑 [BLOCKER] Step 0：工具可用性前置检查 (MANDATORY)

不管用户后续要求做什么，本步骤是 BLOCKER（阻塞项）。
未获得 `codegraph status` 的真实 OBSERVATION 前，严禁推进到 Step 1。

> **THOUGHT**：执行 context-sync 前必须确认 CodeGraph 状态。
>
> **ACTION**：`codegraph status`
>
> **OBSERVATION**：[等待返回结果]
>
> **THOUGHT**：根据返回结果决定符号引用判断工具：
> - 索引最新 → 使用 codegraph（精确）
> - 索引过期 → 先 `codegraph sync`，再用 codegraph
> - 不可用 → 降级为 rg，必须在影响清单前告知用户

### Step 1：收集改动范围

> **ACTION**：`git diff --name-only HEAD`
> **OBSERVATION**：[文件列表]
> **THOUGHT**：记录改动文件，推断涉及的模块和符号。

如果 git diff 为空（全部已 commit），则基于会话中的对话上下文推断本次改动范围。

### Step 2：遍历 docs 全量

> **ACTION**：`find docs -type f \( -name "*.md" -o -name "*.yaml" \)`
> **OBSERVATION**：[doc 文件列表]

- `*.md` — 文档主体
- `*.yaml` — 模块级 design-tokens 规范（页面定义、交互、存储格式等结构化描述）

### Step 3：逐 doc 三重判断

> **THOUGHT**：对每个 doc 跑路径/内容/类型三层判断。
> **ACTION**：[rg/codegraph 搜索]
> **OBSERVATION**：[匹配结果]

1. **路径相关** — 文件路径是否含本次改动的模块名（例：改动涉及 `lib/ui/notes/` → `docs/modules/notes/**` 路径相关）
2. **内容相关** — doc 内容是否引用本次改动涉及的类名/函数名/组件名/常量名
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

## 工具参考（核心命令）

最常用命令（直接使用，无需查阅手册）：
- 检查状态：`codegraph status`
- 同步索引：`codegraph sync`
- 文本搜索：`rg "keyword" <path>`

完整命令参考、使用场景、fallback 策略：
> 读取 `docs/_shared/tool-reference.md`

规则：
- 代码智能优先 `codegraph`，fallback `rg`
- 文本搜索优先 `rg`，fallback `grep`
- 文件查找优先 `fd`，fallback `find`
- 工具不可用时必须告知用户（CodeGraph）或静默 fallback（rg → grep）
- ⚠️ rg 必须优先于 grep，任何场景不得跳过

## 不在本 Skill 管辖范围

- 代码改动（不在本 Skill 内）
- 代码 commit（由代码改动的 Agent/会话决定）
- doc 的 git add / commit / push（用户统一收口时处理）
- 预判哪些文档会受影响（用户随时可触发，不限时机）

## 项目级 Skill 约定

ThkTree 是 Flutter 项目，`flutter-dev` 是主线 skill；`ios-application-dev` / `android-native-dev` 等平台原生 skill 仅在处理 platform channel、原生构建问题时按需触发。

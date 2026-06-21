## 功能开发工作流

收到新功能需求时，必须严格遵循以下阶段，**不可跳步**：

1. **brainstorming** — 先讨论方案，不写代码。探索用户意图、需求、设计方案，达成共识。**同时确定任务类型**（普通功能 / 集成测试 / 其他），后续 setup 和收尾依赖此判断
2. **草稿归档** — 讨论结果写入 `docs/_tmp/<topic>.md`（版本迭代加 `-v2`、`-v3`）
3. **用户确认** — 用户明确说"可以"后才进入下一步
4. **writing-plans** — 输出书面实现计划
5. **验证优先** — 先定义验收方式，再实现；默认优先关键路径集成测试，只有高风险纯逻辑规则才补 focused tests
6. **context-sync** — 完成后同步文档
7. **收尾** — 按"Worktree 收尾流程"提交、rebase、合并

**硬约束**：方案确认前禁止写任何业务代码。

### Worktree 创建（按任务类型）

确认进入实现阶段后，创建 worktree 并根据 brainstorming 确定的任务类型做对应 setup：

```bash
git worktree add ../ThkTree-worktrees/<topic> -b codex/<topic>
```

- **集成测试** → 额外确保 `build/dart_define.json` 可用（`build/` 在 gitignore 中，不影响合并）：
  - 主仓库已有生成产物 → symlink 复用
  - 首次或 Key 变更 → 重新生成：`dart run tools/gen_dart_define.dart ~/.thktree/test_llm_config.json build/dart_define.json`
  - 详见 [fixtures.md](docs/_shared/integration-testing/fixtures.md)
- **普通功能 / 其他** → 无额外步骤

---

## Worktree 收尾流程

编码完成后，按以下步骤收尾并合并回 `dev`。

### 步骤

1. **commit 代码** — 代码改动单独 commit，不和文档混在一起
2. **rebase dev** — 早发现冲突，避免最后合并时才发现
   ```bash
   git fetch origin
   git rebase origin/dev
   ```
3. **处理文档** — 按 brainstorming 确定的任务类型：
   - **集成测试** → 按 planning doc（`docs/_tmp/<topic>.md`）写/更新测试文档，commit 文档
   - **普通功能** → 执行 context-sync，commit 文档
   - **其他** → 提示用户自行处理
4. **合并回 dev** — rebase + fast-forward merge
   ```bash
   git checkout dev
   git merge --ff-only codex/<topic>
   git worktree remove ../ThkTree-worktrees/<topic>
   ```
5. **清理 `docs/_tmp/`** — 删除本次任务的 planning doc（`docs/_tmp/<topic>.md`），report 按需保留

### 硬约束

- 代码 commit 和文档 commit **必须分开**
- 合并前 **必须 rebase dev**（个人分支允许 rebase，见"Rebase 安全策略"）
- 合并用 `--ff-only`，dev 保持线性历史

---

## 并行开发与分支管理（Worktree + Rebase 规范）

当多个讨论/议题并行、且需要同时改代码时，遵循以下默认策略。

### 默认规则

- **讨论默认在主分支**（`dev`）进行：头脑风暴、方案评审、文档沉淀不切分支
- **实现默认起独立分支**：按议题创建 `codex/<topic>`，如 `codex/model-config-redesign`
- **高并行场景默认用 `git worktree`**：每个议题一个独立工作目录，互不干扰
  - 目录建议：`../ThkTree-worktrees/<topic>`
  - 主仓库继续留在 `dev` 讨论，worktree 里做实现

### Rebase 安全策略

| 场景 | 策略 | 说明 |
|------|------|------|
| 共享分支（dev / 已公开分支） | 优先 `merge` | 保持历史稳定，避免他人同步问题 |
| 个人/未公开分支 | 可 `rebase` | 整理提交历史，便于 PR review |
| 推送已 rebase 的个人分支 | 仅允许 `--force-with-lease` | 比 `--force` 安全，检查远端是否有别人新提交 |
| 共享分支 | **禁止** `rebase` / `reset --hard` / `push --force` | 不可破坏性重写公开历史 |

### 常见命令

```bash
# 创建 worktree + 新分支
git worktree add ../ThkTree-worktrees/<topic> -b codex/<topic>

# 查看所有 worktree
git worktree list

# 删除 worktree（合并完成后）
git worktree remove ../ThkTree-worktrees/<topic>

# 个人分支同步主干（rebase）
git fetch origin
git rebase origin/dev
git push --force-with-lease
```

### 风险提示

- **rebase 会改写提交历史**：生成新的 commit id，原有提交可通过 `git reflog` 找回
- **冲突处理流程**：rebase 暂停后，手动解决冲突 → `git add <file>` → `git rebase --continue`；若不想继续：`git rebase --abort`
- **同一分支不能在多个 worktree 同时 checkout**：这是 git 的硬限制


---

## 测试与验收策略

在实现前，必须先明确本次改动的验收方式。

### 核心原则

- 必须给出验收方式
- 优先选择最便宜但足够可信的验证层
- Flutter 项目默认优先关键路径集成测试
- 只有在高风险纯逻辑规则存在时，才补 focused tests
- 禁止为了凑流程、覆盖率或形式正确而生成低价值测试

### 验收方式选择

按风险和收益选择，不要求固定模板：

1. 编译通过 + diagnostics 无新增错误
2. 关键路径集成测试
3. 手工验证步骤
4. focused tests（仅用于高风险纯逻辑，如金额计算、权限判断、数据转换、边界条件）

### 补充说明

- `test case` 与 `unit test` 不要求一一对应
- 不得机械要求"先写单测再实现"
- 当集成测试、静态检查和手工验证已足够可信时，可以不补低价值单测
- focused tests 的目标是固定长期约束，而不是追求覆盖率

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
   - 技术性问题修复 / 排障 / 兼容性坑 / 构建坑 → 若满足 war-story 候选条件，则纳入 `docs/war-stories/**`；并继续评估是否需要同步 `docs/CHANGELOG/**`、模块 README 或 `ARCHITECTURE.md`

**白名单兜底**：`FEATURES.md`、`TECH-DEBT.md`、`DECISIONS.md` 任何代码改动都要扫一遍。

### Step 3.5：war-story 候选判断

`ctsync` 默认不自动写 `war-story`。只有在完成常规文档影响评估后，额外判断本次会话是否应将 `docs/war-stories/**` 纳入影响清单。

只有同时满足以下前提时，才允许进入 war-story 候选：

- 问题已经被解决，不是未完成事项
- 本次会话中已形成"现象 + 根因 + 解决方案"的完整信息

候选判定标准：以下 4 条命中 2 条及以上，即可列入候选。

1. **排查成本较高** — 不是一眼修复，经历了定位、验证、排除或多轮尝试
2. **根因具有隐蔽性** — 涉及时序、平台差异、依赖行为、构建链路、状态同步或边界条件
3. **对未来排障有复用价值** — 同类问题大概率会再次出现
4. **知识不易留存** — 若不沉淀文档，团队难以仅凭记忆复原关键上下文

明确排除：

- 拼写、文案、import、简单判空等一眼可修的问题
- 无技术陷阱的普通样式微调
- 尚未解决的问题，或仅有临时绕过方案的问题

命中候选时：

- 仅将对应 `docs/war-stories/**` 作为"新增 / 小补 / 待确认"列入影响清单
- 默认不自动写入，等待用户确认后再创建或更新文档
- 若新增或更新 war-story，必须同步维护 `docs/war-stories/README.md` 索引

### Step 4：输出影响清单

**格式：列表 + 卡片，禁用表格。**

```markdown
## 📊 影响清单（共遍历 N 个 doc，影响 M 个）

- 📄 `docs/FEATURES.md` — 大改版 · § 笔记模块
- 📄 `docs/modules/notes/README.md` — 小补 · § API 列表
- 📄 `docs/DECISIONS.md` — 新增 · ADR-013
- 📄 `docs/ARCHITECTURE.md` — 不影响 · 未涉及架构层变更
- 📄 `docs/_shared/design-system.md` — 待确认 · 本次改了 button 样式，是否需要更新 spacing token？
- 📄 `docs/war-stories/ui-ux/2026-06-20-xxx.md` — 待确认 · 本次会话解决了一个需要排查才能定位、且有复盘价值的技术问题
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

---

## 📄 docs/war-stories/ui-ux/2026-06-20-xxx.md

**变更类型**：新增
**影响范围**：新增 war-story + 更新索引
**触发原因**：本次会话已形成"现象 + 根因 + 解决方案"，且问题需要排查才能定位、并有复盘价值

### § 现象 — 新增

**变更描述**：补充用户可感知的异常表现、触发条件和复现环境。

### § 根因分析 — 新增

**变更描述**：说明问题为何发生，涉及哪些依赖、时序、平台差异或实现细节。

### § 解决方案 — 新增

**变更描述**：记录最终采用的修复方案、放弃的错误方向，以及后续避免方式。
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
- "只改 war-story" → 仅创建或更新 `docs/war-stories/**`
- "跳过 war-story" → 保留其他 doc，同步跳过 war-story
- "跳过 XX" / "只改 XX" → 按指示执行
- "调整" → 修改后再确认

### Step 7：改 doc 文件

对每个确认的 doc，按卡片描述逐章节修改。改完即停，不 commit。

如果用户确认新增或更新 war-story：

- 按 `docs/war-stories/README.md` 的单篇模板创建或更新对应文档
- 同步维护 `docs/war-stories/README.md` 的倒序索引
- 若该问题同时影响模块说明、架构说明或发布记录，不省略其他受影响文档

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
- docs/war-stories/ui-ux/2026-06-20-xxx.md（新增 war-story）
- docs/war-stories/README.md（更新索引）
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

### 集成测试文档索引

当任务涉及以下场景时，必须先读取 `docs/_shared/integration-testing/` 目录下的相关文档：

- 编写/修改集成测试
- 调试测试失败
- 添加新的测试用例
- 理解测试基础设施（fixtures、helpers、LLM 注入）

目录内容：
- `README.md` — 总论与文档体系索引
- `fixtures.md` — 测试夹具/固件规范
- `helpers.md` — 测试辅助函数规范
- `llm-injection.md` — LLM 配置注入机制（导航版）
- `backup-restore.md` — 备份恢复测试规范
- `branch-creation.md` — 分支创建测试规范
- `chat-streaming.md` — 流式聊天测试规范
- `node-reorder.md` — 节点重排序测试规范
- `theme-chat-e2e.md` — 主题聊天端到端测试规范
- `note-crud.md` — 笔记 CRUD 集成测试规范

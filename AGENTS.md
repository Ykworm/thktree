# AGENTS.md — ThkTree AI 协作红线与路由

> 本文件是 AI 协作的常驻入口（所有工具自动加载），只立红线、指路、选型。  
> 模式正文：`litemode`(fullmode) / `freemode` skills。


## 路径推导（不写死项目名）

```bash
REPO=$(basename "$(git rev-parse --show-toplevel)")
# worktree 根目录（与主仓同级）
#   ../${REPO}-worktrees/<topic>
# feature 分支
#   ${REPO}/<topic>
```

示例：仓在 `.../thktree-tauri` → worktree `../thktree-tauri-worktrees/fix-color`，分支 `thktree-tauri/fix-color`。  
仓在 `.../ThkTree` → `../ThkTree-worktrees/<topic>`，分支 `ThkTree/<topic>`。  
**禁止**写死 `codex/` 或某一固定产品名。

## 自建 skill 前缀

协作 skill 用 `yk-frontend-`：`yk-frontend-litemode` / `yk-frontend-fullmode` / `yk-frontend-freemode` / `yk-frontend-newmode` / `yk-frontend-merge` / `yk-frontend-context-sync` / `yk-frontend-ctsync` / **`yk-frontend-cleanup-docs-tmp`**（只清 `docs/_tmp` 讨论稿）。**无** `yk-frontend-workflow`。
**无** `merge-modules` skill（模块重名在 ctsync + 登记表内处理）。

## 红线（不可违反）

- **litemode / fullmode**：方案未齐前不写业务代码（litemode 微改可跳过长 brainstorm，但验收要说清）  
- **litemode / fullmode 一个 Chat Session 一个 worktree**：首次创建、后续复用；禁止同 session 主动新建 worktree  
- **freemode**：实验自由，但仍禁止把密钥提交进 git、禁止对共享分支 force push  
- 代码 commit 与文档 commit **必须分开**（litemode/fullmode）  
- 合并回 dev：`rebase origin/dev` + `--ff-only`；共享分支禁止 rewrite  
- 验证优先；禁止为凑覆盖率写低价值测试  
- 搜索：`rg` 优先于 `grep`  
- context-sync 只改 doc，不改代码、不 commit  
- 设计 token code-first：`lib/ui/core/theme/app_colors.dart` → `dart run scripts/sync-design-tokens.dart`  
- **禁止章节符号（Unicode U+00A7 / section sign）**：聊天回复、`docs/**`、`docs/_tmp/**`、commit/PR 说明、skill 正文 **一律不得出现该字符**。章节交叉引用写 **「第 N 节」** 或直接写标题（如 `见第 11.4 节` / `见「红线」`）。细则见 `chinese-documentation` skill；**本条常驻生效，不依赖用户是否触发该 skill**

## Doc Map

- 架构 → `docs/ARCHITECTURE.md` · 功能 → `docs/FEATURES.md` · 品牌 → `docs/BRAND.md`  
- 设计令牌真源 → `app_colors.dart`；镜像 `docs/_shared/design-tokens.yaml`  
- 存储 → `docs/_shared/storage-format.md` · ADR → `docs/decisions/`  
- 集成测试 → `thktree-e2e-test` skill + `docs/_shared/integration-testing/`  
- **模块登记表** → **`docs/modules/README.md`**（合法 id；ctsync 必读）  
- **跨 chat 讨论** → `docs/_tmp/<topic>.md`（见三轨 + topic 对齐）

---

## 三轨跟踪（chat / 实现 / test）

| 轨 | 文件 | 管什么 |
|----|------|--------|
| **Chat / 讨论** | **`docs/_tmp/<topic>.md`** | 未定稿讨论、spec、plan、开放问题（**不是** PROGRESS） |
| **实现进度** | 产品切片进度（本仓可用 FEATURES/切片约定；有则 `docs/PROGRESS` 类文件） | Next action、`[x]`、commit；**链到** `_tmp/<topic>.md` |
| **Test** | 测试进度 + case 文档 | E2E/集成完成条；**与 `_tmp` 无关** |

**没有 chat-PROGRESS。** 新 chat 续讨论 = 读/写 `_tmp`，不靠聊天记录。

### Topic 对齐（worktree 名 = `_tmp` 名）

同一 **`<topic>`** slug（如 `fix-color`）：

| 用途 | 仓库内路径（相对 repo root） | 讨论已开 worktree 时的磁盘绝对路径 |
|------|------------------------------|--------------------------------------|
| 讨论稿 | **`docs/_tmp/<topic>.md`**（只有这一套，**没有** `_tmp/worktree/…`） | `{WorktreeRoot}/docs/_tmp/<topic>.md` |
| worktree 根 | — | `../{REPO}-worktrees/<topic>`（即 WorktreeRoot） |
| 分支 | `{REPO}/<topic>` | 同左 |

**要点：** git worktree 是整仓检出，不是另建一套 docs 树。  
讨论中已经有 worktree 时，文件仍写 **`docs/_tmp/<topic>.md`**；只是你 `cd` 到 worktree 后完整路径变成：

```text
Worktree: /Users/…/{REPO}-worktrees/fix-color
Discuss:  /Users/…/{REPO}-worktrees/fix-color/docs/_tmp/fix-color.md
```

**不要**再建 `docs/_tmp/worktree/<topic>.md`（第三套命名，易漂）。

**litemode / fullmode 开工时：**  
若 `docs/_tmp/<topic>.md` 存在 → **必须先 read**，再改代码。  
用户续聊可说：`继续 topic fix-color` 或 `继续 docs/_tmp/fix-color.md`。

### Chat Session 与 Worktree 的默认关系

- **一个 Chat Session 默认只对应一个 topic、一个 worktree。**
- litemode / fullmode 首次进入时创建 worktree；同 session 后续请求**默认复用**该 worktree。
- **agent 不得在同 session 内主动新建 worktree**，除非用户明确说「新开 worktree / 新 topic」。
- 若用户想处理不同 topic，应**新开 Chat Session**。

### 讨论 → 开干

1. 讨论写入 `_tmp/<topic>.md`  
2. 用户「可以 / 开干」  
3. **fullmode**：完善 plan → 实现进度里写 Next action **并链接** `_tmp/<topic>.md`  
4. **litemode**：可直接实现，但仍 read 已有 `_tmp`（若有）  
5. 定稿 / 收尾文档：触发 **`context-sync` / `ctsync`**（见下），把结论迁到模块 docs / FEATURES / ADR 等；`_tmp` 可删或标 decided  

规范细节：`docs/_tmp/README.md`。

### 模块身份（防双人起两名、ctsync 改错文件夹）

**规范名（slug）只能来自已登记模块**，禁止 LLM 自由发明文件夹名。

| 真源 | 内容 |
|------|------|
| `docs/modules/*/` 目录名 | **合法模块 id 列表**（chat, notes, themes, lab, llm, search, settings, …） |
| `docs/FEATURES.md`「模块」列 | 功能归属；与 `lib/ui/features/<id>/` 对齐（见 FEATURES 表头） |
| `docs/ARCHITECTURE.md` 文档地图 | 改某类代码必读哪些 README |

**ctsync / 收尾：**

1. **主依据 = `git diff` 路径** → 映射到已有 `docs/modules/<id>`（例：`lib/ui/features/chat/` → `chat`）。  
2. **不要求**在 `_tmp` 手填「影响模块」（可选加速，非前提）。  
3. **新功能**若装不进现有模块：  
   - **禁止**直接 `mkdir docs/modules/我随便起的名`  
   - 必须先 **登记**：在 FEATURES 加行 + 选定 **唯一 slug** + 建 `docs/modules/<slug>/`（可最小 README）  
   - 双人并行新模块：以 **先 merge 进 dev 的 slug 为准**；后到的 rebase 后 **迁到已有 slug**，禁止并存两个同义文件夹  
4. 发现 `docs/modules/` 下疑似重复（同义不同名）→ **停**，列冲突，人定保留哪个，再改 ctsync 目标  

### 收尾写模块 docs：靠什么？准不准？

**主机制：`context-sync` / `ctsync`**（不是手填列表，也不是纯聊天才华）：

1. `git diff --name-only`  
2. 对照 **已登记模块 id** + 路径映射 + docs 内容引用  
3. 影响清单（含「不影响 / 待确认」）→ **人确认** → 再改 doc  
4. 不 commit  

准确度：**中高（有 diff + 登记表 + 确认）**；纯猜模块名 = **低，禁止**。  
模块 README 复杂 = 产品约束必要；ctsync **小补章节**，不整篇重写。

---

## 协作 Flow 全景（健壮性）

```text
[0 定 topic]
    ▼
[1 worktree] ../${REPO}-worktrees/<topic> + 报绝对路径
    ▼
[2 discuss] 在 worktree 内写 docs/_tmp/<topic>.md（避免主仓未提交进不了 worktree）
    ▼
[3 go-gate] 用户「可以」
    ▼
[4 plan + read-tmp]
    ▼
[5 实现] 代码 + unit / integration
    │  改模块前读 docs/modules/<id>/README「AI 必读」
    │  新模块 → 先走「模块登记」再 mkdir
    ▼
[5 文档闸门] fullmode：ctsync（diff→清单→确认→改 doc）
    │  litemode：至少真源（token/色）；ctsync 按需
    │  ctsync 缺 diff/缺确认 → 不写 doc
    ▼
[6 合入] commit 代码 / commit 文档 分开 → rebase → ff-only merge dev
    │  报告：已 merge？ Worktree path？
    ▼
[7 可选] 删或归档 _tmp；worktree 目录可留
```

### 哪一步容易断？怎么防？

| 断点 | 症状 | 闸门 / 补救 |
|------|------|-------------|
| 新 chat 无上文 | 重聊已定结论 | 必读 `_tmp/<topic>.md`；用户点名 topic |
| 没读模块 README | 踩 SSE/存储等坑 | ARCHITECTURE 地图 + README 顶部必读；改前 cross-check |
| 双人新模块两名 | `docs/modules` 分叉 | **登记表**；后到 rebase 合并到先合入的 slug |
| ctsync 乱改 | 写错模块 / 漏改 | 只认登记 id + diff；**确认后才写** |
| 当 E2E 完成其实只是 integration | 假闭环 | 桌面仓：`test:e2e` 只真壳；iOS 测轨看 test PROGRESS |
| litemode 未 merge | 你在 dev 测不到 | litemode **强制** merge 进 dev |
| freemode 实验进主线 | 脏历史 | freemode 不默认；要进 dev 先升 litemode/fullmode 收尾 |
| 信息缺失仍开工 | 半成品 | 开干闸门：完成条/验收不清 → 回 [1] |

### 原则（比再加文件夹更重要）

1. **身份先于文件夹**：模块 id 是登记名，不是 LLM 起名游戏。  
2. **diff 先于聊天**：范围以 git 为准。  
3. **确认先于写 doc**：ctsync 已如此。  
4. **闸门显式**：读不够 / 名冲突 / 验收不清 → **停并提问**，不假装做完。

---

## 三种开发模式（≠ 测试层 unit/integration/e2e）

| 模式 | 默认？ | worktree | 必读 `_tmp` | 规划/长 doc | 测试 | merge 进 dev |
|------|--------|----------|-------------|-------------|------|----------------|
| **litemode** | **是** | **是** + 报绝对路径 | **必须有**（无则先建最短稿） | 同 full 骨架，跳过长 brainstorm | 至少 unit；**无** dev-*-test | **要** + **ctsync-ask**（是→ctsync→cleanup-docs-tmp→commit docs） |
| **fullmode** | 否 | **是** + 报路径 | **必须有**（discuss 写入） | brainstorm→`_tmp`→确认→plan | unit + **dev-integration/e2e** | **要** + **ctsync → cleanup-docs-tmp → commit docs** |
| **freemode** | 否 | 不强制 | **可不建** | 不强制 | 不强制 | 不强制 |
| **newmode** | 否 | 看 nodes | 仅含 `discuss`/`read-tmp` 时要 | 自定义 | 看 nodes | 看是否含 `merge` |

- 触发：`litemode` / 微改 / 默认日常 → **`yk-frontend-litemode`**（= fullmode − 两大测试；ctsync 先问）  
- 触发：`fullmode` / 完整流程 / 架构 → **`yk-frontend-fullmode`**  
- 触发：`freemode` / 全自由 → **`yk-frontend-freemode`**  
- 触发：`newmode: a + b + c` 或 `newmode file: path.yaml` / `preset: litemode` → **`yk-frontend-newmode`**  
- git 合入主分支 → **`yk-frontend-merge`**（rebase + ff-only）  
- 清 **`docs/_tmp` 讨论稿** → **`yk-frontend-cleanup-docs-tmp`**（**ctsync 与 docs commit 之间**；只删 `docs/_tmp/<topic>*`，不碰系统/构建 tmp）  
- 删 worktree → 仅节点 **`remove-worktree`**（无独立 skill；默认不删）

### 两种模式要不要「先思考再写 doc」？

| 模式 | 讨论 doc（`_tmp`） | 产品 doc |
|------|-------------------|----------|
| **litemode** | **不强制**新建；****必须有**（无则先建）**。改色/token **必须**写真源 | 轻 |
| **fullmode** | **要**（brainstorm→`_tmp`→确认→plan） | 齐全 + 收尾迁移定稿 |
| **freemode** | 不强制 | 不强制 |

### Worktree 输出（litemode / fullmode）

```text
Worktree: /Users/…/{REPO}-worktrees/<topic>
```

方便用户 `cd` 手测。merge 后目录可留；**分支要进 dev**（litemode/fullmode）。

---

## `_tmp` vs 测试 vs 模块 docs（别混）

| 内容 | 放哪 | 收尾 |
|------|------|------|
| 未定稿讨论 / 临时 plan | `docs/_tmp/<topic>.md` | **ctsync 后** **`yk-frontend-cleanup-docs-tmp`**，再与 docs 同 commit |
| 模块长期说明 | `docs/modules/<module>/` 等 | 持续真源 |
| 可执行测试 | `integration_test/`（可按 common/platform/模块分） | 留在测试树 |
| 测试 case 说明 | `integration_test/docs/`、`docs/_shared/integration-testing/` | 正式文档 |
| 测试进度 | 测试 PROGRESS / catalog | 不与 `_tmp` 混写 |

**`_tmp` 与 test 无关。** 进入写测试阶段：改 **worktree 内** 的 `integration_test/` 与正式测试 docs，不是继续堆在 `_tmp`。

**为何仍建议保留 `_tmp`，而不是一开始就写进 `docs/modules/`：**  
未定稿直接进模块 docs 会污染真源、难回滚、agent 易把草稿当定论。模式是：**草稿 `_tmp` → 确认后迁入正式 docs**（可看成 promote，不是永久第二套世界）。

litemode/fullmode：**即使微改也要有** `_tmp/<topic>.md`（可极短）；仅 **freemode** 或 **newmode 未列 discuss/read-tmp** 才可没有。

---

## 路由

- 讨论 → `brainstorming`（若启用）· 计划 → `writing-plans`  
- 文档同步 → `context-sync`  
- **默认日常** → `litemode`  
- **完整闭环** → `fullmode`  
- **真全自由** → `freemode`  
- **自定义流程** → `newmode`（worknode 组合；可 `file:` / `preset:`）  
- **git 合入** → `yk-frontend-merge` skill  
- **删 worktree** → 节点 `remove-worktree`（无独立 skill；默认不删）  
- 文档同步 → `context-sync` / `ctsync`  
- 模块登记校验 → `bash tools/check_module_registry.sh`（agent 跑）  
- Flutter → `flutter-dev`；E2E → `thktree-e2e-test`

## 协作习惯

结束报告：改动文件绝对路径 + `Worktree: …`（litemode/fullmode）+ 是否 merge 进 dev + 相关 `_tmp/<topic>.md`。

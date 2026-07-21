# AGENTS.md — ThkTree AI 协作入口

> 只放：模式速查、红线、核心约定、项目特化、路由。执行细节在各 skill 与 docs/。

## 模式速查

红线与路由引用本表定义。

| 模式 | 一句话 | skill |
|------|--------|-------|
| **litemode** | 默认日常微改；不开发 integration/e2e 测试脚本；ctsync 先问用户 | `yk-frontend-litemode` |
| **fullmode** | 完整闭环；开发 integration/e2e 测试脚本；ctsync 必做 | `yk-frontend-fullmode` |
| **freemode** | 全自由实验；不强制 worktree / `_tmp` / merge | `yk-frontend-freemode` |
| **newmode** | 用户自定义节点组合，行为由组合的节点列表决定 | `yk-frontend-newmode` |

## 红线（不可违反）

- **go-gate 未确认（用户未说「可以 / 开干 / go」）前不写业务代码**（litemode / fullmode；微改可压缩确认形式，不可省略）  
- **litemode / fullmode 一个 Chat Session 一个 worktree**：首次创建、后续复用；禁止同 session 主动新建 worktree  
- **freemode**：实验自由，但仍禁止把密钥提交进 git、禁止对共享分支 force push  
- 代码 commit 与文档 commit **必须分开**（litemode/fullmode）  
- 合并回 dev：`rebase origin/dev` + `--ff-only`；共享分支禁止 rewrite  
- 验证优先；禁止为凑覆盖率写低价值测试  
- 搜索：`rg` 优先于 `grep`  
- context-sync 只改 doc，不改代码、不 commit  
- **禁止章节符号（Unicode U+00A7 / section sign）**：聊天回复、`docs/**`、`docs/_tmp/**`、commit/PR 说明、skill 正文 **一律不得出现该字符**。章节交叉引用写 **「第 N 节」** 或直接写标题。细则见 `chinese-documentation` skill；**本条常驻生效，不依赖用户是否触发该 skill**

## 核心约定

### 路径约定

```bash
REPO=$(basename "$(git rev-parse --show-toplevel)")
# worktree  ../${REPO}-worktrees/<topic>
# 分支      ${REPO}/<topic>
# 讨论稿    docs/_tmp/<topic>.md   ← worktree 名 = 分支后缀 = _tmp 名，同一 <topic>
```

不写死项目名。worktree 是整仓检出，docs 路径相对 repo 不变——**没有** `docs/_tmp/worktree/…` 这种第二套命名。

### 一个 Chat Session 一个 worktree（litemode / fullmode）

- 进入时先 `git worktree list`：`../${REPO}-worktrees/<topic>` **不存在则创建，已存在则复用**；复用前 `git status --porcelain`，有未提交改动先报告。
- 同 session 后续请求**默认复用**；**跨 session 继续同一 topic 也复用**——明天新开 chat 说「继续 topic fix-color」→ 直接用已存在的 `../ThkTree-worktrees/fix-color`，不新建、不报错。
- agent 不得主动新建 worktree；仅用户明确说「新开 worktree / 新 topic」时，视为用户主动打破默认。
- 想换 topic → 用户**新开 Chat Session**。
- 开工必须报告：当前 topic、worktree 绝对路径、本次是**新建**还是**复用**。

### go-gate 触发词

用户确认词：**「可以 / 开干 / go」**。litemode / fullmode 有双 gate（discuss 后 + plan 后）；微改可压缩为一句话确认，**不可省略**。未确认 → agent 停，不写业务代码（见红线）。

### 讨论轨 `_tmp`（跨 chat 的讨论暂存区）

未定稿讨论写 `docs/_tmp/<topic>.md`；新 chat 说「继续 topic X」→ agent **先读该文件**恢复上下文，不靠聊天记录。litemode / fullmode **必须有**（无则先建最短稿）；定稿后结论迁入正式 docs（`docs/modules/` / FEATURES / ADR），再清理 `_tmp`。与测试无关：测试代码在 `integration_test/`，模块长期说明在 `docs/modules/<id>/`。细则 → `docs/_tmp/README.md`。

### 模块身份（防双人起两名）

- 模块 id 可由 LLM 提议，但**必须先查登记表** `docs/modules/README.md`；登记后 id 是唯一真源，禁止另起同义文件夹。
- 新模块先登记（FEATURES 加行 + 定 slug + 建 `docs/modules/<slug>/`）再写码。
- 发现疑似重复（同义不同名）→ **停**，列冲突，人定保留哪个；迁移用 `bash tools/migrate_module_slug.sh <old> <new>`。
- ctsync 只认登记 id + `git diff`，确认后才改 doc。

### 原则

1. **登记先于文件夹**：id 以登记表为准，LLM 起名也必须落进登记表。  
2. **diff 先于聊天**：范围以 git 为准。  
3. **确认先于写 doc**：ctsync 已如此。  
4. **闸门显式**：读不够 / 名冲突 / 验收不清 → **停并提问**，不假装做完。

### 断点表（哪一步容易断、怎么防）

| 断点 | 症状 | 闸门 / 补救 |
|------|------|-------------|
| 新 chat 无上文 | 重聊已定结论 | 必读 `_tmp/<topic>.md`；用户点名 topic |
| 没读模块 README | 踩 SSE/存储等坑 | ARCHITECTURE 地图 + README 顶部必读；改前 cross-check |
| 双人新模块两名 | `docs/modules` 分叉 | 登记表 + `migrate_module_slug.sh` |
| ctsync 乱改 | 写错模块 / 漏改 | 只认登记 id + diff；**确认后才写** |
| 当 E2E 完成其实只是 integration | 假闭环 | 桌面仓：`test:e2e` 只真壳；iOS 测轨看 test PROGRESS |
| litemode 未 merge | 你在 dev 测不到 | litemode **强制** merge 进 dev |
| freemode 实验进主线 | 脏历史 | freemode 不默认；要进 dev 先升 litemode/fullmode 收尾 |
| 信息缺失仍开工 | 半成品 | go-gate：验收不清 → 停下提问 |

## 项目特化（换新项目时改这里）

- 设计 token code-first：`lib/ui/core/theme/app_colors.dart` → `dart run scripts/sync-design-tokens.dart`  
- 模块登记表 → `docs/modules/README.md`；校验 `bash tools/check_module_registry.sh`  
- 集成测试 → `thktree-e2e-test` skill + `docs/_shared/integration-testing/`  
- 模块代码结构 → `lib/ui/features/<id>/`  
- Doc Map：架构 `docs/ARCHITECTURE.md` · 功能 `docs/FEATURES.md` · 品牌 `docs/BRAND.md` · 存储 `docs/_shared/storage-format.md` · ADR `docs/decisions/`

## 路由

协作 skill 前缀：`yk-frontend-`。

- 默认日常 → `litemode` · 完整闭环 → `fullmode` · 真全自由 → `freemode` · 自定义流程 → `newmode`（可 `file:` / `preset:`）  
- git 合入主分支 → `yk-frontend-merge`（rebase + ff-only）  
- 文档同步 → `yk-frontend-context-sync` / `ctsync`  
- 清 `docs/_tmp` 讨论稿 → `yk-frontend-cleanup-docs-tmp`（**ctsync 与 docs commit 之间**）  
- 删 worktree → 仅节点 `remove-worktree`（无独立 skill；默认不删）  
- 讨论 → `brainstorming`（若启用）· 计划 → `writing-plans`  
- Flutter → `flutter-dev`；E2E → `thktree-e2e-test`

## 协作习惯

结束报告：改动文件绝对路径 + `Worktree: …`（litemode/fullmode）+ 是否 merge 进 dev + 相关 `_tmp/<topic>.md`。

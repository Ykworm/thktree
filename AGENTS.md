# AGENTS.md — ThkTree AI 协作入口

> 只放：模式速查、红线、核心约定、项目特化、路由。执行细节在各 skill 与 docs/。

## 模式速查

红线与路由引用本表定义。

| 模式           | 一句话                                         | skill                  |
| ------------ | ------------------------------------------- | ---------------------- |
| **litemode** | 默认日常微改；不开发 integration/e2e 测试脚本；ctsync 先问用户； merge 后必问是否 cleanup-docs-tmp | `yk-frontend-litemode` |
| **fullmode** | 完整闭环；开发 integration/e2e 测试脚本；ctsync 必做      | `yk-frontend-fullmode` |
| **freemode** | 全自由实验；不强制 worktree / `_tmp` / merge         | `yk-frontend-freemode` |
| **newmode**  | 用户自定义节点组合，行为由组合的节点列表决定                      | `yk-frontend-newmode`  |

## 红线（不可违反）

- **go-gate 未确认（用户未说「可以 / 开干 / go」）前不写业务代码**（litemode / fullmode；微改可压缩确认形式，不可省略）
- **litemode / fullmode 一个 Chat Session 一个 worktree**：首次创建、后续复用；禁止同 session 主动新建 worktree
- **litemode / fullmode 禁止直接在 dev 修改代码**：所有代码改动必须在 worktree 内完成；若工具限制无法直接编辑 worktree 文件，告知用户并停止，不得在 dev 上修改
- **freemode**：实验自由，但仍禁止把密钥提交进 git、禁止对共享分支 force push
- 代码 commit 与文档 commit **必须分开**（litemode/fullmode）
- 合并回 dev：`rebase origin/dev` + `--ff-only`；共享分支禁止 rewrite
- 验证优先；禁止为凑覆盖率写低价值测试
- 搜索：`rg` 优先于 `grep`
- context-sync 只改 doc，不改代码、不 commit
- **禁止章节符号（**`§` **/ U+00A7）：** 聊天回复、`docs/**`、`docs/_tmp/**`、commit/PR 说明、skill 正文中**一律不得出现** `§` **字符**。章节交叉引用一律使用英文 **「Section N」**（如 `Section 3.2`）或直接写标题。细则见 `chinese-documentation` skill；本条常驻生效。

## 核心约定

### 路径约定

```bash
REPO=$(basename "$(git rev-parse --show-toplevel)")
# worktree  ../${REPO}-worktrees/<topic>
# 分支      ${REPO}/<topic>
# 讨论稿    docs/_tmp/<topic>.md   ← 讨论稿文件名中的 <topic>、worktree 目录名、分支后缀，三者必须一致
```

不写死项目名。docs 路径相对 repo 不变，不存在 `docs/_tmp/worktree/…` 这种第二套命名。

### worktree（litemode / fullmode）

1. 进入时 `git worktree list`：不存在则创建，已存在则复用；复用前检查未提交改动
2. 同 session / 跨 session 同一 topic **默认复用**；agent 不得主动新建
3. 开工必须报告：topic、worktree 绝对路径、新建还是复用

### go-gate

用户确认词：**「可以 / 开干 / go」**。litemode / fullmode 双 gate；微改可压缩，不可省略。

### 讨论轨 `_tmp`

跨 chat 的讨论暂存区：`docs/_tmp/<topic>.md`。litemode / fullmode 必须有（无则先建）；新 chat 说「继续 topic X」→ 先读该文件恢复上下文。定稿后迁入正式 docs，再清理。细则 → `docs/_tmp/README.md`。

### 模块身份

模块 id **必须先查登记表** `docs/modules/README.md`；登记后 id 是唯一真源。新模块先登记再写码；疑似同义不同名 → 停，人定。

### 原则

1. **登记先于文件夹**
2. **diff 先于聊天**
3. **闸门显式**：信息不足 → 停并提问

### 断点表

常见断裂点及防护 → [`docs/_shared/breakpoint-table.md`](docs/_shared/breakpoint-table.md)

## 项目特化（换新项目时改这里）

- 设计 token code-first：`lib/ui/core/theme/app_colors.dart` → `dart run scripts/sync-design-tokens.dart`
- 模块登记表 → `docs/modules/README.md`；校验 `bash tools/check_module_registry.sh`
- 集成测试 → `thktree-e2e-test` skill + `docs/_shared/integration-testing/` + `integration_test/`
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

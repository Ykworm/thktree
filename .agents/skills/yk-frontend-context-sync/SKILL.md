---
name: yk-frontend-context-sync
description: >
  将「已经 commit 的代码/测试改动」同步回写到 docs/。
  代码侧未 commit 则拒绝。触发：ctsync / 同步文档 / context-sync / yk-frontend-ctsync。
---

# yk-frontend-context-sync — 文档同步

## 0. 作用（先读这三句）

| 问题 | 答案 |
|------|------|
| **做什么** | 根据 **已提交** 的代码/测试 diff，找出应更新的 `docs/**`，改文档让文档与代码一致 |
| **不做什么** | 不改业务代码；不代替测试；不 `git commit` / `push`；不勾选 E2E 完成 |
| **何时用** | fullmode 节点 `ctsync`；或用户说「同步文档 / ctsync」且代码侧已 commit |

**输入：** 最近一次（或指定范围）提交里的文件路径 + 登记表。  
**输出：** 影响清单 → 你确认 → 改好的 docs 文件（仍 **未** commit，由下一 `commit` 节点或人提交）。

---

## 1. 硬约束

1. **只改 `docs/`**（及本仓明确的文档路径）；禁止改 `src/`、`lib/`、`test-script/`、`integration_test/` 等业务/测试代码。  
2. **禁止**本 skill 内执行 `git add` / `git commit` / `git push`。  
3. **模块 id 只认** `docs/modules/README.md` 登记表；禁止 `mkdir docs/modules/<自创名>`。  
4. **代码侧未 commit → 整 skill 中止**（见第 2 节）。  
5. **未得到用户对影响清单的确认 → 不改任何 doc 文件。**  
6. **禁止章节符号（Unicode U+00A7 / section sign）**：聊天、`docs/**`、`docs/_tmp/**`、commit/PR、skill 正文一律不得出现该字符；交叉引用写「第 N 节」。**常驻生效**。  

---

## 2. 闸门：不 commit（代码/测试）不能 ctsync

**第一步就执行：**

```bash
git status --porcelain
```

### 2.1 判定规则

对 porcelain 每一行路径：

- 若路径以 `docs/` 开头（纯文档）→ 允许存在未提交（可能是上轮 ctsync 留下的）  
- 若路径属于代码/测试/配置（如 `src/`、`src-tauri/`、`lib/`、`test-script/`、`integration_test/`、`package.json` 等，**非** `docs/`）→ **BLOCKER**

| 结果 | Agent 行为 |
|------|------------|
| 存在 BLOCKER | **立即停止**。输出：`ctsync ABORT：请先 commit 代码/测试，再运行 ctsync。` 并列出未提交的非 docs 路径。 |
| 无 BLOCKER | 继续第 3 节 |

本 skill **绝不**自动 `git commit` 去「帮你清闸门」。

### 2.2 改动范围从哪取（有提交才有范围）

按优先级：

```bash
# A. 最近一次提交（推荐：流程里刚 commit 完）
git show --name-only --pretty=format: HEAD

# B. 或最近一笔相对上一笔
git diff --name-only HEAD~1..HEAD

# C. 用户指定：git show --name-only <sha>
```

得到文件列表 `CHANGED[]`。若为空 → 停止并说明「HEAD 无文件变更，无法 ctsync」。

---

## 3. 步骤（必须按序）

### Step 1 — 闸门

执行第 2 节；未通过则 **ABORT**。

### Step 2 — 登记表与一致性

```bash
# 必读
# docs/modules/README.md

bash tools/check_module_registry.sh   # 若仓库提供；exit≠0 → BLOCKER，只报冲突，不写模块业务 doc
```

- 合法模块 id = 登记表中的 `id` 列。  
- 目录有、表无 → **停**，提示补表或 ``（人只选保留 id）。

### Step 3 — 路径 → 模块 id

用登记表把 `CHANGED[]` 映射到模块：

| 路径含（示例，按本仓登记表为准） | 模块 id |
|----------------------------------|---------|
| `src/views/ChatView` / `chat.css` / `chatNav` | `chat` |
| `ThemesView` / `ForestOutline` / `themes.css` | `themes` |
| `src-tauri/src/llm.rs` | `llm` |
| `src-tauri/src/storage/` | `storage` |
| `App.tsx` / `ipc.ts` / `store.ts` | `shell` |
| … | 见 `docs/modules/README.md` |

映射不到任何 id → 记入清单「待确认」，**不**发明新模块目录。

### Step 4 — 还要扫哪些全局 doc

除 `docs/modules/<id>/` 外，按改动类型勾选（有改才标影响）：

| 改动类型 | 至少检查 |
|----------|----------|
| 功能增删/行为变化 | `IMPLEMENTATION-PROGRESS.md`、功能/parity 类文档（若有） |
| 测试分层/E2E 定义 | `docs/testing-*.md`、`e2e-ui-handoff-*.md` |
| 架构/存储/IPC | 对应决策文、storage 模块 doc |
| 任意代码 | 登记表是否需新行（新模块时） |

对每个候选 doc 给出三选一：**影响 / 不影响（一句理由）/ 待确认**。

### Step 5 — 输出影响清单（给人确认）

**禁止**在确认前改文件。格式用列表（可分段），例如：

```markdown
## ctsync 影响清单

范围：HEAD = <short-sha>，文件 N 个
模块命中：chat, llm
registry check：OK | BLOCKER: …

- 影响 `docs/modules/chat/README.md` — 小补 · 流式完成态说明
- 影响 `docs/IMPLEMENTATION-PROGRESS.md` — 小补 · Next action
- 不影响 `docs/modules/notes/…` — 本次 diff 未触及 notes
- 待确认 `docs/modules/README.md` — 是否需登记新 id `foo`
```

然后 **等待用户**：`OK` / `全部` / `只改 …` / `跳过 …` / `调整 …`。

### Step 6 — 按确认改文件

- 只改用户确认的路径  
- **小补章节**，不整篇重写模块「AI 必读」除非用户要求  
- 不写假 diff 块；用户用 `git diff` 自查  

### Step 7 — 汇报

```markdown
## ctsync 完成
- 范围提交：<sha>
- 已改文件：…
- 未 commit（请下一 commit 节点或用户提交 docs）
- 未改 / 跳过：…
```

---

## 4. 与流程节点的关系

```text
… → commit（代码+测试）→ ctsync（本 skill）→ commit（文档）→ merge
```

若跳过前置 commit 直接调本 skill → 第 2 节 **ABORT**。

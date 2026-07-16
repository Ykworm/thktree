---
name: yk-frontend-newmode
description: >
  用户组合 worknode/step；agent 生成 YAML 并按序执行。
  触发：newmode / 自定义流程 / worknode / 帮我组个流程。
---

# yk-frontend-newmode — 组合 step，生成 YAML，按序执行

## 0. 这是干什么的

| | |
|--|--|
| **给人** | 用自然语言或 `a + b + c` **组合步骤**；不必手写 YAML |
| **给 agent** | 解析意图 → **生成 YAML 落盘** → 打印节点序列 → **只执行声明的节点** |
| **不是** | 再维护一套 `.agents/modes/` 预设目录（已废弃；预设写在本 skill + 各 mode skill 里） |

预设 **litemode / fullmode / freemode** 本身就是 worknode 组合；日常直接触发对应 skill 即可。  
**newmode** 用于：少几步、多几步、换顺序、或任务专属流程。

---

## 1. 用户怎么说（任选）

```text
newmode: worktree + implement + unit + merge
newmode nodes=discuss,worktree,implement,unit,commit,merge
帮我组一个：先 worktree，写代码，只跑 unit，commit，合入，不要 ctsync
newmode file: docs/_tmp/fix-color.newmode.yaml   # 已有文件则直接读
```

---

## 2. Agent 职责：帮忙生成 YAML

当用户用对话组合 step、且 **尚未** 给出可用 yaml 路径时，agent **应主动生成**：

1. 从用户话里抽出有序 `nodes`（非法名 → 停，列出合法 node）  
2. 写文件（默认路径）：

```text
docs/_tmp/<topic>.newmode.yaml
```

3. 展示内容请用户一眼确认（微改可直接执行；复杂组合先确认再跑）  
4. 再按文件执行；结束时可提示：文件可复用（`newmode file: …`）或随 cleanup-docs-tmp 清掉  

### 生成模板

```yaml
# 由 yk-frontend-newmode 根据用户组合生成；可手改后再 newmode file: 本路径
name: <topic>-custom
topic: <topic>
nodes:
  - worktree
  - implement
  - unit
  - commit
  - merge
```

**字段：**

| 字段 | 必填 | 说明 |
|------|------|------|
| `nodes` / `worknodes` | 是 | 有序 step 名 |
| `name` | 否 | 展示用 |
| `topic` | 否 | 覆盖 slug（`_tmp` / worktree / 分支） |

**无 `options`**。行为只由 nodes 决定：

| 行为 | 约定 |
|------|------|
| 是否删 worktree | 默认 **保留**；仅当 nodes 含 **`remove-worktree`** 才删 |
| 合入主分支 | 节点 **`merge`** → **`yk-frontend-merge`** |
| `_tmp` | 仅当 nodes 含 `discuss` / `read-tmp` 时要求有稿 |

也可生成到用户指定路径（例如长期复用的 `docs/_tmp/recipes/<name>.yaml`）；**不要**再写回已删除的 `.agents/modes/`。

---

## 3. 参数优先级

1. **内联 nodes**（对话里已写清列表）→ 可先落盘再执行，或内存执行后补写 yaml  
2. **`newmode file: path.yaml`** → 只读该文件，不覆盖（除非用户说「改流程并重写」）  
3. **`newmode preset: litemode|fullmode|freemode`** → 用下方内置表（等同去跑对应 skill）  

---

## 4. 合法 worknode（step 目录）

| node | 做什么 |
|------|--------|
| `discuss` | 写/改 `docs/_tmp/<topic>.md` |
| `read-tmp` | 读 `_tmp` |
| `plan` | 更新 `_tmp` 里的实现步骤 |
| `go-gate` | 验收对齐；未「可以」则停 |
| `worktree` | 建 worktree；**必报** `Worktree: <绝对路径>` |
| `register-module` | 新模块：登记表 → FEATURES → mkdir |
| `implement` | 业务代码 |
| `unit` / `integration` / `e2e` | 跑对应测试 |
| `dev-integration-test` / `dev-e2e-test` | **写/改** 测试脚本与 case（fullmode 大节点） |
| `ctsync` | `yk-frontend-context-sync`（须先 commit 代码） |
| `ctsync-ask` | 问是否 ctsync；是→ctsync→cleanup-docs-tmp→commit docs |
| `cleanup-docs-tmp` | `yk-frontend-cleanup-docs-tmp`（宜在 **ctsync 与 docs commit 之间**） |
| `commit` | 分 commit |
| `merge` | `yk-frontend-merge` |
| `remove-worktree` | 仅 worknode；默认不执行 |

---

## 5. 内置预设（无独立 modes 目录）

| 预设 | 等价 nodes（摘要） |
|------|-------------------|
| **litemode** | worktree → discuss → go-gate → plan → go-gate → read-tmp → implement → unit → commit → **ctsync-ask** → merge |
| **fullmode** | 同上 + **dev-integration-test → dev-e2e-test**；且 **commit → ctsync → cleanup-docs-tmp → commit → merge**（ctsync 必做） |
| **freemode** | 实质自由；最小可视为 `implement`（细节见 `yk-frontend-freemode`） |

完整语义以 **`yk-frontend-litemode` / `yk-frontend-fullmode` / `yk-frontend-freemode`** 为准；preset 只是入口别名。

**文档收尾推荐片段（可嵌进自定义组合）：**

```text
… → commit → ctsync → cleanup-docs-tmp → commit → merge
```

---

## 6. Agent 纪律

1. 解析组合 → **生成或读取 YAML** → 打印节点序列  
2. **未列出的节点不做**  
3. 每节点一行：`[node] OK | SKIP | FAIL`  
4. 结束：topic、Worktree path、yaml 路径、已执行节点、是否 merge  
5. 非法 node → **停**，列出合法表，不执行  

---

## 7. 与「模块登记」

- 不强迫人手跑登记脚本  
- `register-module` / `ctsync` 时按 `docs/modules/README.md`；冲突 **停并说明**

## 文案硬规则

- **禁止章节符号（Unicode U+00A7 / section sign）**：聊天、`docs/**`、`docs/_tmp/**`、commit/PR、skill 正文一律不得出现该字符；交叉引用写「第 N 节」。**常驻生效**。  

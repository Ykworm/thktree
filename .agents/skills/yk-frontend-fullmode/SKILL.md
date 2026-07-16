---
name: yk-frontend-fullmode
description: >
  完整协作闭环：含 dev-integration-test / dev-e2e-test；ctsync 必做；
  ctsync → cleanup-docs-tmp → commit docs → merge。
  触发：fullmode / 完整流程 / 架构 / 高风险。
---

# yk-frontend-fullmode — 完整闭环

## 0. 作用

| | |
|--|--|
| **做什么** | 讨论→计划→实现→**开发集成/E2E 测试脚本**→commit→**必做 ctsync**→**清 `_tmp`**→commit docs→合入 |
| **不做什么** | 不跳过 `_tmp`；不在未 commit 时 ctsync；不默认删 worktree 目录 |
| **关联** | 轻量 → `yk-frontend-litemode`；合入 → `yk-frontend-merge`；文档 → `yk-frontend-context-sync`；清草稿 → `yk-frontend-cleanup-docs-tmp` |

## 1. 路径

```bash
REPO=$(basename "$(git rev-parse --show-toplevel)")
# worktree ../${REPO}-worktrees/<topic>
# branch   ${REPO}/<topic>
# _tmp     docs/_tmp/<topic>.md
```

## 2. 节点顺序

```text
worktree → discuss → go-gate → plan → go-gate → read-tmp
  → implement → unit
  → dev-integration-test → dev-e2e-test
  → commit → ctsync → cleanup-docs-tmp → commit → merge
```

| 节点 | 具体做什么 |
|------|------------|
| `worktree` | 先建隔离检出；报绝对路径 |
| `discuss` / `plan` / 双 `go-gate` | 方向确认 + plan 后再确认 |
| `read-tmp` | 开写前再读 |
| `implement` / `unit` | 业务 + 必跑 unit |
| `dev-integration-test` | **写/改** integration 测试脚本与 case |
| `dev-e2e-test` | **写/改** e2e 测试脚本与 case；写完尽量跑通 |
| `commit` #1 | 提交代码+测试 |
| `ctsync` | **`yk-frontend-context-sync`（必做）**；未 commit 非 docs → 拒绝 |
| `cleanup-docs-tmp` | **`yk-frontend-cleanup-docs-tmp`**：结论已进正式 docs 后清 `_tmp` |
| `commit` #2 | 提交 **docs**（含正式文档改动 + `_tmp` 删除） |
| `merge` | **`yk-frontend-merge`** |

## 3. 与 litemode 对照

| 项 | litemode | fullmode |
|----|----------|----------|
| 骨架（worktree…unit） | ✅ 同 | ✅ |
| dev-integration-test / dev-e2e-test | ❌ | ✅ |
| ctsync | **询问**（否→跳过） | **必做** |
| cleanup-docs-tmp | 仅用户同意 ctsync 时：ctsync 后、docs commit 前 | 同段：**ctsync → cleanup-docs-tmp → commit** |

## 4. 硬约束

- 禁止主仓未提交 discuss 直接 worktree  
- 禁止未 commit 代码就 ctsync  
- cleanup-docs-tmp 只删 `docs/_tmp/<topic>*`，不删 worktree；位置在 **ctsync 与 docs commit 之间**
- **禁止章节符号（Unicode U+00A7 / section sign）**：聊天、`docs/**`、`docs/_tmp/**`、commit/PR、skill 正文一律不得出现该字符；交叉引用写「第 N 节」。**常驻生效**。  

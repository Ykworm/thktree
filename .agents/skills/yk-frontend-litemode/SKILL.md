---
name: yk-frontend-litemode
description: >
  默认日常：与 fullmode 同骨架，但无 dev-integration-test / dev-e2e-test；
  commit 后询问是否 ctsync；是则 ctsync → cleanup-docs-tmp → commit docs → merge。
  触发：litemode / 微改 / 默认日常。
---

# yk-frontend-litemode — 默认日常

## 0. 作用

| | |
|--|--|
| **做什么** | 与 fullmode 相同的讨论→实现→合入骨架，但 **不开发** integration/e2e 测试脚本 |
| **不做什么** | 不做 `dev-integration-test` / `dev-e2e-test`；ctsync **默认询问**，用户说否可跳过 |
| **关联** | 完整含大测试 → `yk-frontend-fullmode`；合入 → `yk-frontend-merge`；文档 → `yk-frontend-context-sync`；清草稿 → `yk-frontend-cleanup-docs-tmp` |

## 1. 路径

```bash
REPO=$(basename "$(git rev-parse --show-toplevel)")
# worktree ../${REPO}-worktrees/<topic>
# branch   ${REPO}/<topic>
# _tmp     docs/_tmp/<topic>.md   ← 必须有
```

## 2. 节点顺序

```text
worktree → discuss → go-gate → plan → go-gate → read-tmp
  → implement → unit
  → commit
  → ctsync-ask          # 问用户是否 ctsync
  → merge
```

| 节点 | 具体做什么 |
|------|------------|
| `worktree` … `unit` | 与 fullmode **相同**（含双 go-gate、plan、`_tmp` 必须） |
| `commit` | 提交 **代码**（无大测试脚本开发） |
| **`ctsync-ask`** | **询问用户**：「是否执行 ctsync 同步文档？」 |
| → 用户 **是** | **`yk-frontend-context-sync`** → **`yk-frontend-cleanup-docs-tmp`** → **commit docs** → 然后 `merge` |
| → 用户 **否** | **跳过 ctsync 与 cleanup-docs-tmp**，直接 `merge`（`_tmp` 保留） |
| `merge` | **`yk-frontend-merge`** |

### ctsync-ask 话术示例

```text
代码已 commit。是否执行 ctsync（把变更同步到 docs/）？
- 是 → ctsync → cleanup-docs-tmp → commit docs → merge
- 否 → 直接 merge（_tmp 保留；需要时再 cleanup-docs-tmp）
```

## 3. 与 fullmode 对照

| 项 | litemode | fullmode |
|----|----------|----------|
| worktree / discuss / 双 go-gate / plan | ✅ | ✅ |
| implement + unit | ✅ | ✅ |
| **dev-integration-test** | ❌ | ✅ |
| **dev-e2e-test** | ❌ | ✅ |
| ctsync | **问用户**（`ctsync-ask`） | **必做** |
| cleanup-docs-tmp | 同意 ctsync 时：在 ctsync 与 docs commit 之间 | 同 |
| merge | ✅ | ✅ |

## 4. 硬约束

- `_tmp` 必须有；worktree 先于 discuss  
- 不默认写/跑大测试脚本  
- merge 后默认保留 worktree 目录；清的是 **`_tmp` 文件**，不是 worktree  
- cleanup 默认夹在 **ctsync → commit(docs)** 之间，不在 merge 后
- **禁止章节符号（Unicode U+00A7 / section sign）**：聊天、`docs/**`、`docs/_tmp/**`、commit/PR、skill 正文一律不得出现该字符；交叉引用写「第 N 节」。**常驻生效**。  

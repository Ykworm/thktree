---
name: yk-frontend-merge
description: >
  将 feature 分支 rebase 并 ff-only 合入主分支（dev/master）。
  比「一句 git merge」复杂：冲突、主分支名、worktree 内操作。触发：merge 节点 / 合入主分支。
---

# merge — 合入主分支（独立 skill）

litemode / fullmode / newmode 的 **`merge` 节点** 委托本 skill。

## 人类

一般无需操作；冲突时按 agent 提示解决或中止。

## Agent 步骤

1. **确认当前分支**与 topic：`{REPO}/<topic>` 或 `feat/<topic>`  
2. 确认主分支名：优先 `dev`，否则 `master` / `main`（`git rev-parse --verify`）  
3. 在 **feature 分支**上：  
   ```bash
   git fetch origin
   git rebase origin/<main>
   ```  
   冲突 → 解决 → `git add` → `git rebase --continue`；或 `git rebase --abort` 并停  
4. 切换主分支并合入：  
   ```bash
   git checkout <main>
   git merge --ff-only <feature-branch>
   ```  
   **禁止**在共享主分支上 `merge --no-ff` 乱序或 force push  
5. 汇报：  
   - 主分支名  
   - feature 分支名  
   - 是否 ff-only 成功  
   - **Worktree 路径仍保留**（除非流程含 `remove-worktree`）  
6. **不要**默认 `git worktree remove`  
7. **不要**默认 `git push`（除非用户明确要求）  

## 不做

- 不在 freemode 里自动跑（除非 newmode 显式含 `merge`）

## 文案硬规则

- **禁止章节符号（Unicode U+00A7 / section sign）**：聊天、`docs/**`、`docs/_tmp/**`、commit/PR、skill 正文一律不得出现该字符；交叉引用写「第 N 节」。**常驻生效**。  

# docs/_tmp/ — Chat / 讨论轨

> 规范总述：仓库根 **`AGENTS.md`（三轨跟踪 + topic 对齐 + 三模式）**。  
> **与 test 无关。** 测试代码/case 文档不在这里长期存放。

## 命名 = worktree = 分支

同一 `<topic>` slug：

```text
# 仓库内（唯一约定）
docs/_tmp/<topic>.md

# 已开 worktree 时的磁盘位置（同一文件，不是另一套）
../{REPO}-worktrees/<topic>/docs/_tmp/<topic>.md
{REPO}/<topic>   # branch
```

**没有** `docs/_tmp/worktree/<topic>.md`。worktree 只是检出根目录，docs 路径相对 repo 不变。

**litemode / fullmode** 开工：若 `docs/_tmp/<topic>.md` 存在 → agent **自动先 read**。

## 状态头

```markdown
# <topic>
> 状态：discussing | draft-spec | plan-ready | decided | superseded
> 更新：YYYY-MM-DD
```

## 生命周期

1. 讨论 → 写本目录  
2. 开干 → 实现进度链到本文件；worktree 名 = topic  
3. 定稿 → 迁到 `docs/modules/…` / FEATURES / decisions / 测试正式 docs  
4. 可删或标 `superseded`  

**不要**用本目录代替 `integration_test/` 或模块 README 真源。  
**不要**与桌面仓 `thktree-tauri/tmp/` 混淆。

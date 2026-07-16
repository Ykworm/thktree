---
name: yk-frontend-cleanup-docs-tmp
description: >
  清理本次 topic 的 docs/_tmp 讨论草稿（不是系统 tmp、不是 build 缓存）。
  触发：cleanup-docs-tmp 节点 / 清理 docs/_tmp / 清理讨论稿。
  兼容旧称：cleanup-tmp / yk-frontend-cleanup-tmp。
---

# yk-frontend-cleanup-docs-tmp — 清理 `docs/_tmp/<topic>` 讨论稿

## 0. 作用

| | |
|--|--|
| **做什么** | 在 **ctsync 之后、docs commit 之前**，处理 **`docs/_tmp/<topic>.md`** 及同 topic 的 `-v2`、`.newmode.yaml` 等 |
| **不做什么** | **不**动系统 `/tmp`、`tmp/` 构建产物、`node_modules`、worktree 目录、`docs/modules/**`；不代替 ctsync；**本 skill 不 commit** |
| **何时用** | fullmode 节点 `cleanup-docs-tmp`；litemode 同意 ctsync 时的同段路径；用户说「清理讨论稿 / 清理 docs/_tmp」 |

名字刻意带 **`docs-tmp`**：范围只限仓库约定的 **`docs/_tmp/`** 讨论轨，不是泛指「所有临时文件」。

## 1. 在流程中的位置

```text
… → commit(代码) → ctsync → cleanup-docs-tmp → commit(docs，含删 docs/_tmp) → merge
```

- **先 ctsync**：硬结论已进正式 docs  
- **再 cleanup-docs-tmp**：删除/归档讨论稿  
- **再 commit**：正式文档改动 + `docs/_tmp` 清理一次提交  
- **不要**放到 merge 之后再清  

litemode 跳过 ctsync 时：**默认不清**（避免未迁结论丢失）。

## 2. 前置

- 已知 `<topic>`（与 worktree / 分支一致）  
- **建议刚跑完 `yk-frontend-context-sync`**（或用户确认讨论稿内已无未迁硬结论）  
- 尚未做本轮 docs commit  

## 3. 步骤

1. 列出候选（存在才列）：  
   - `docs/_tmp/<topic>.md`  
   - `docs/_tmp/<topic>-v2.md` …  
   - `docs/_tmp/<topic>.newmode.yaml`  
2. 若仍有 **未迁入正式 docs 的硬结论** → **停**，先 ctsync/手迁  
3. 说明将删除/归档的路径（默认删除；用户说「归档」→ `docs/_tmp/_archive/<topic>-YYYYMMDD.md` 若约定存在）  
4. 执行删除或移动  
5. **不在此 commit**；交还流程下一节点 `commit`  
6. 汇报已处理路径  

## 4. 硬约束

- **只动** `docs/_tmp/` 下与 `<topic>` 相关的文件  
- 禁止 `rm -rf docs/_tmp` 整目录  
- 禁止在 go-gate 前 / implement 中途自动清讨论稿  
- 流程默认位置：**ctsync 与 docs commit 之间**
- **禁止章节符号（Unicode U+00A7 / section sign）**：聊天、`docs/**`、`docs/_tmp/**`、commit/PR、skill 正文一律不得出现该字符；交叉引用写「第 N 节」。**常驻生效**。  

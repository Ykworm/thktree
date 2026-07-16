---
name: yk-frontend-freemode
description: >
  真·全自由（不是 litemode）。无强制 worktree / _tmp / 规划 / 测试 / merge。
  触发：freemode / 全自由 / 实验不收尾。
---

# freemode — 真全自由

**不是** litemode。

- 可不建 worktree  
- **可不建 `_tmp`**（与 newmode 自定义节点相同：未列入 `discuss`/`read-tmp` 则不强制）  
- 不强制 unit / integration / e2e  
- 不强制 commit / merge / ctsync  
- 有用结果要留下 → 升 **litemode/fullmode** 再收尾  

默认日常请用 **litemode**。

## 硬约束

- **禁止章节符号（Unicode U+00A7 / section sign）**：聊天、`docs/**`、`docs/_tmp/**`、commit/PR、skill 正文一律不得出现该字符；交叉引用写「第 N 节」。**常驻生效**。  
- 仍禁止把密钥提交进 git、禁止对共享分支 force push  

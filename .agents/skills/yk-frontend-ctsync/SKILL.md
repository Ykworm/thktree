---
name: yk-frontend-ctsync
description: ctsync 薄壳 → yk-frontend-context-sync（含「代码须先 commit」闸门）。
---

# yk-frontend-ctsync

执行 **`yk-frontend-context-sync` skill** 全文。

若工作区有未提交的 **非 docs** 改动 → 先 **commit**，再调用。

## 文案硬规则

- **禁止章节符号（Unicode U+00A7 / section sign）**：聊天、`docs/**`、`docs/_tmp/**`、commit/PR、skill 正文一律不得出现该字符；交叉引用写「第 N 节」。**常驻生效**。  

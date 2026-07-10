---
name: ctsync
description: 同步文档（context-sync 的薄壳入口）。将本次会话已完成的代码改动同步回写 docs/ 下受影响的文档。触发词：ctsync / 同步文档 / sync docs。委托给 context-sync skill，不复制 SOP。
---
请执行 `context-sync` skill：把本次会话里已经完成的代码改动，同步回写到 `docs/` 下受影响的文档——架构决策记 `docs/decisions/`、模块规格记 `docs/modules/<m>/specs/`、踩坑记 `docs/war-stories/`、设计令牌记 `docs/_shared/design-tokens.yaml`。完整 SOP 见 `.agents/skills/context-sync/SKILL.md`。

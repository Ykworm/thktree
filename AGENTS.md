# AGENTS.md — ThkTree AI 协作红线与路由

> 本文件是 AI 协作的常驻入口（所有工具自动加载），只立红线、指路、选型。
> 流程正文在 `workflow` skill，详细协议在对应 skill / convention。改本文件请保持精简。

## 红线（不可违反）

- 方案确认前禁止写任何业务代码
- 代码 commit 与文档 commit **必须分开**
- 合并回 dev 前必须 `rebase origin/dev`；合并用 `--ff-only` 保持线性历史
- 共享分支（dev / 已公开）禁止 `rebase` / `reset --hard` / `push --force`；个人分支 rebase 仅用 `--force-with-lease`
- 验证优先：实现前先定义验收方式；禁止为凑覆盖率生成低价值测试
- 搜索：`rg` 优先于 `grep`，任何场景不得跳过
- context-sync 只改 doc，不改代码、不 commit（详见 `context-sync` skill）

## Doc Map（何时读哪个 doc）

- 架构 / 模块边界 → `docs/ARCHITECTURE.md`
- 功能清单 → `docs/FEATURES.md`
- 品牌 / 语气 → `docs/BRAND.md`
- 设计令牌（全端单一来源）→ `docs/_shared/design-tokens.yaml` + 各模块 `design-tokens.yaml`
- 存储格式 → `docs/_shared/storage-format.md`
- 架构决策 → `docs/decisions/`（先看 `INDEX.md`）
- 集成测试 → `docs/_shared/integration-testing/`（写 / 改测试前必读）
- 实战踩坑 → `docs/war-stories/`
- 规划草稿 → `docs/_tmp/<topic>.md`

## 档位选择器

按任务自动判定（也可用 `/` 手动覆盖）：

| 档位 | worktree 隔离 | 集成测试 | 文档 | 适用 |
|------|--------------|---------|------|------|
| `scratch` | 否 | 否 | 无 | 探索 / 实验 |
| `freemode` | 否（主分支直接改）| 按需 | 按需 | 轻量改动 |
| `standard` | 否 | 按需 | context-sync | 普通功能 / Bug |
| `rigorous` | 是（`git worktree`）| 是（关键路径）| 齐全 + 新 ADR | 架构级 / 高风险 |
| `release` | 同 rigorous | 是 | + changelog / 版本号 | 发版 |

未显式指定且非轻量改动时，默认 `standard`。完整流程正文见 `workflow` skill。

## 路由

- 讨论方案 → `brainstorming` skill
- 输出计划 → `writing-plans` skill
- 同步文档 → `context-sync` skill
- 工具优先级 → `conventions/tool-priority.md`
- 功能开发主线 → `flutter-dev` skill；平台原生问题按需 `ios-application-dev` / `android-native-dev`
- 完整开发闭环 → `workflow` skill

## 协作习惯

- 任务结束报告：列出本次新增 / 修改文件的**绝对路径**，方便在 IDE 打开（注意 ThkTree 与 TalkWithClaude 是不同仓库，看当前激活工作区）。

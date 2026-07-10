---
name: workflow
description: ThkTree 功能开发与 Bug 修复的完整 AI 协作闭环（brainstorm→草稿→确认→计划→验证优先→实现→context-sync→worktree 收尾），含档位应用、worktree/分支治理、测试验收策略。触发：开始一个功能/Bug 任务、需要走标准流程、或 agent 需判断当前档位时。
---

# workflow — ThkTree 开发闭环

本 skill 承载完整开发流程正文。档位选择见 AGENTS.md「档位选择器」，红线见 AGENTS.md。

## 0. 档位应用

| 档位 | worktree 隔离 | 集成测试 | 文档要求 | 适用 |
|------|--------------|---------|---------|------|
| scratch | 否 | 否 | 无 | 探索 / 实验 |
| freemode | 否（主分支直接改）| 按需 | 按需 | 轻量改动 |
| standard | 否 | 按需 | context-sync | 普通功能 / Bug |
| rigorous | 是（`git worktree`）| 是（关键路径）| 齐全 + 新 ADR | 架构级 / 高风险 |
| release | 同 rigorous | 是 | + changelog / 版本号 | 发版 |

- freemode 只决定 worktree 流程是否启用，不替代任务类型判断。
- 未显式指定且非轻量改动时，按 standard。
- `scratch` 与 `release` 为实验性档位，随多端开发迭代调整。

## 1. 主流程（standard / rigorous 必走，freemode 按需保留）

1. **brainstorming** — 先讨论方案不写代码。探索意图 / 需求 / 设计，达成共识；同时确定任务类型（普通功能 / Bug 修复 / 集成测试 / 其他）。
2. **草稿归档** — 讨论结果写入 `docs/_tmp/<topic>.md`（迭代加 `-v2` / `-v3`）。
3. **用户确认** — 用户明确说"可以"后才进入下一步。
4. **writing-plans** — 输出书面实现计划。
5. **验证优先** — 先定义验收方式再实现；默认优先关键路径集成测试，仅高风险纯逻辑补 focused tests。
6. **实现** — 按计划在 worktree（rigorous）或主分支（standard / freemode）编码。
7. **context-sync** — 完成后触发 `context-sync` skill 同步文档。
8. **收尾** — 按 Worktree 收尾流程提交 / rebase / 合并。

**硬约束**：方案确认前禁止写任何业务代码。

### Worktree 创建（rigorous）

```bash
git worktree add ../ThkTree-worktrees/<topic> -b codex/<topic>
```

- 集成测试 → 额外确保 `build/dart_define.json` 可用（`build/` 在 gitignore，不影响合并）：
  - 主仓库已有产物 → symlink 复用
  - 首次或 Key 变更 → `dart run tools/gen_dart_define.dart ~/.thktree/test_llm_config.json build/dart_define.json`
  - 详见 `docs/_shared/integration-testing/fixtures.md`

## 2. Worktree 收尾流程

1. **commit 代码** — 代码改动单独 commit，不和文档混在一起。
2. **rebase dev** — `git fetch origin && git rebase origin/dev`（早发现冲突）。
3. **处理文档** — 按任务类型：
   - 集成测试 → 按 planning doc（`docs/_tmp/<topic>.md`）写 / 更新测试文档，commit 文档
   - 普通功能 / Bug → 执行 context-sync，commit 文档
   - 其他 → 提示用户自行处理
4. **合并回 dev** — `git checkout dev && git merge --ff-only codex/<topic> && git worktree remove ../ThkTree-worktrees/<topic>`。
5. **清理 `docs/_tmp/`** — 删除本次 planning doc（report 按需保留）。

**硬约束**：代码与文档 commit 分开；合并前必须 rebase dev；合并用 `--ff-only` 保持线性历史。

## 3. 并行开发与分支管理

- 讨论默认在 `dev`；实现默认起 `codex/<topic>`；高并行用 `git worktree`（每个议题一目录 `../ThkTree-worktrees/<topic>`）。
- **Rebase 安全策略**：

  | 场景 | 策略 | 说明 |
  |------|------|------|
  | 共享分支（dev / 已公开）| 优先 `merge` | 保持历史稳定，避免他人同步问题 |
  | 个人 / 未公开分支 | 可 `rebase` | 整理提交历史，便于 review |
  | 推送已 rebase 的个人分支 | 仅 `--force-with-lease` | 比 `--force` 安全 |
  | 共享分支 | **禁止** `rebase` / `reset --hard` / `push --force` | 不可破坏性重写公开历史 |

- 常见命令：

  ```bash
  git worktree add ../ThkTree-worktrees/<topic> -b codex/<topic>
  git worktree list
  git worktree remove ../ThkTree-worktrees/<topic>
  git fetch origin && git rebase origin/dev && git push --force-with-lease
  ```

- 风险：rebase 改写历史（reflog 可找回）；冲突 → 解决 → `git add` → `git rebase --continue`，或 `git rebase --abort`；同一分支不能多个 worktree 同时 checkout。

## 4. 测试与验收策略

- 实现前先明确验收方式；优先最便宜但足够可信的验证层；默认优先关键路径集成测试；仅高风险纯逻辑补 focused tests；禁止为凑覆盖率生成低价值测试。
- 验收方式（按风险收益选，不固定模板）：
  1. 编译通过 + diagnostics 无新增错误
  2. 关键路径集成测试
  3. 手工验证步骤
  4. focused tests（仅用于高风险纯逻辑，如金额计算、权限判断、数据转换、边界条件）
- 写 / 改集成测试前必读 `docs/_shared/integration-testing/`（README → fixtures → helpers → 各规范）。
- 不得机械要求"先写单测再实现"；集成测试 + 静态检查 + 手工验证足够可信时不补低价值单测。

## 5. 项目级 Skill 约定

- `flutter-dev` 是主线 skill；`ios-application-dev` / `android-native-dev` 等平台原生 skill 仅在处理 platform channel / 原生构建问题时按需触发。
- 文档同步统一走 `context-sync` skill；工具优先级见 `conventions/tool-priority.md`。

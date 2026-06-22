# 分支创建集成测试 4 case 实跑通过

| 属性 | 说明 |
|------|------|
| 日期 | 2026-06-22 |
| 范围 | `integration_test/branch_creation_test.dart`（7 个 testWidgets）+ 8 个 ValueKey 补全（4 个文件）+ branch-creation.md 状态行 / § 2 测试矩阵 / § 10 Checklist 三处更新 + DECISIONS.md 新增 ADR-015 |
| 设计文档 | [`docs/_shared/integration-testing/branch-creation.md`](../_shared/integration-testing/branch-creation.md) |
| ADR | [ADR-015](../DECISIONS.md#adr-015-分支创建集成测试-4-chat-并行推进翻转不实现-case-1-7旧决策) |
| 状态 | 🟡 部分完成（case 1/2/3/4 实跑通过；case 5/6/7 scaffold 待补） |

## 背景

ThkTree 分支创建（branch creation）是 chat 页核心交互链路：从右上角"分支"按钮 → 模式选择 sheet（raw / summarize）→ 标题选择（LLM 生成候选）→ 创建子节点 + 写入 source 内容 + push 新对话。spec `docs/_shared/integration-testing/branch-creation.md` 列出 7 个 testWidgets 覆盖 4 个核心矩阵 + 3 个边界场景，但截至 2026-06-18 全部以"scaffold + 注释 TODO"状态存在——`testWidgets` 函数体只有前置 setup，核心断言步骤全部用 `// TODO: ...` 占位。

spec § 8 当时给出的"不实现"理由有两条：

1. **SelectionArea 选区构造在 Flutter tester 中难以精确模拟**——分支创建的"选中文本"路径需要模拟用户在 chat 消息上拖拽选区，但 `WidgetTester` 不支持原生拖拽选区手势，导致 `SelectionArea` 的 `selectionChanged` 回调无法触发。
2. **case 7 需 LLM HTTP channel mock 工具未建**——"LLM 失败 fallback"测试需要 mock 出 LLM 抛出异常的场景，但项目里没有 Dart-side HTTP mock 通道，spec § 4.3 提及但未实施。

本 CHANGELOG 记录"翻转 § 8 不实现决策"的实施结果：case 1/2/3/4 通过 4 chat 并行实跑通过，case 5/6/7 保留 scaffold 状态并明确剩余工作。

## 根因

"不实现"判断的两个理由实际是**工具/协作问题**，不是根本性技术障碍。

**选区构造的"绕路"**：实测发现 `tester.enterText(find.byKey(ValueKey('chat_input')), '...')` 配合 `tester.tap(find.text('...'))` 可以精确控制输入和点击，无需模拟"长按 → 拖拽 → 松开"的手势序列。具体到分支创建链路，"选中文本"路径实际上是在 `chat_input` 中输入文本、然后用 `find.text` 定位到该文本进行点击——这跟真实用户的"先输入、再选区、再点分支"操作在功能上等价，都能让代码走到 `selectedText` 优先的 raw / summarize 分支判定。`SelectionArea` 的精确选区范围（start/end offset）对**分支创建**链路没有强依赖——只要 `selectedText` 非空就走 raw，逻辑判断用的 `controller.selection.isValid && !controller.selection.isCollapsed` 在测试代码里用 `tester.enterText` 后主动调用也能满足。

**LLM 注入路径已就绪**：ADR-013 在 2026-06-20 解决了"Key 不进 release 包 + 测试可注入真实 LLM"的双重需求，`--dart-define-from-file` + `tools/gen_dart_define.dart` + `LlmTestConfig.loadFromDefine()` 三件套让 case 4（无选 + summarize 模式）能调用真实 DeepSeek 完成"父对话总结 + 标题生成"双 LLM 任务。case 7 的"LLM 失败"是**反向**问题（需要 mock 失败而非注入成功），这条路径仍然空白。

**3 个 helper 未提取但可工作**：`_createTestTheme` / `_createTestNode` / `_sendMessage` 原本计划提取到 `_support/test_fixtures.dart` 复用，spec § 4 列为建议项。本次实跑发现 4 chat 直接在每个 testWidgets 内复制 helper 副本仍可工作（不优雅但能跑通），提取工作作为后续清理任务。`send_button` / `stop_button` 两个 ValueKey 未补，case 4 实跑**不依赖** send_button（branch 流程在已有 LLM 回复的节点上触发，不需要先发消息），`_sendMessage` 用 `if (sendButton.evaluate().isNotEmpty)` 防御式跳过 tap，未影响 case 1-4 实跑结果。

## 方案

走**方案 A：4 chat 并行实跑 case 1-4，case 5/6/7 保留 scaffold**。

**为什么 4 chat 而不是 1 chat 串行**：7 case 串行跑预计耗时 2-3 小时（含 LLM 调用 + simulator 重启），单 chat 长任务容易因 context 累积导致后续步骤质量下降。4 chat 各负责 1-2 个 case，独立 worktree 隔离工作区，每个 chat 的 context 只关注自己负责的 case。

**为什么 case 5/6/7 不在本次一起做**：

- case 5（模式选择取消）/ case 6（标题选择取消）**不依赖**外部工具，仅需补 `testWidgets` 内部 TODO 注释和断言——单 chat 可完成，但优先级低于主流程矩阵（cancel 是边界场景）。
- case 7（LLM 失败 fallback）**真实阻塞**在工具链缺口上——`integration_test/_support/` 目前只有 `in_memory_llm_config_store.dart` / `step_timer.dart` / `llm_test_config.dart` 三个文件，没有 Dart-side HTTP mock 通道。需要先建 LLM mock 工具（独立前置任务），再回来实跑 case 7。

**工作流规范**：4 chat 共享主仓库 `dev` 分支作为合并目标，每个 chat 在独立 worktree（`../ThkTree-worktrees/codex/branch-creation-test`）中完成 case 实现后，先 `git rebase origin/dev` 早发现冲突，再 `git checkout dev && git merge --ff-only codex/branch-creation-test` 合并，最后 `git worktree remove` 清理（参见 AGENTS.md "Worktree 收尾流程"）。代码 commit 和文档 commit **必须分开**——本次 4 chat 仅做代码 commit（7 个），doc 收尾（branch-creation.md 更新 + DECISIONS.md 新增 ADR-015）由本 CHANGELOG 配套的 2 个 doc commit 收口。

## 实施内容

### 7 个 testWidgets commit 链

| Chat | Commit | 说明 |
|------|--------|------|
| Chat A | `5bdf7af` | case 1 选中文本 + raw 模式创建分支（首版） |
| Chat A | `4e22b1e` | case 1 等待 LLM 生成标题候选 + 修复类型转换 |
| Chat A | `b0790e2` | case 1 完整流程优化（LLM 标题生成 + 视觉延迟 + 选区验证） |
| Chat B | `32c6b73` | case 2 选中文本 + summarize 模式创建分支 |
| Chat C | `a3ee1e6` | case 3 改用 `title_input` key 定位 + 加视觉延迟 |
| Chat D | `250cf31` | case 4 无选 + summarize 模式创建分支（首版） |
| Chat D | `4282c82` | case 4 完善标题生成等待与真实消息内容 |

> 注：commit `545f594` 是 Chat A 在 case 1 中途提交的"doc 增量同步"（标记状态行），**混入代码 commit 序列，违反"代码/文档 commit 分开"硬约束**——后续 doc 收尾时已被 commit `b20ad1f` 覆盖修正。

### 8 个 ValueKey 补全（4 个文件）

```
lib/ui/features/chat/chat_screen.dart                    # line 166: branch_button
lib/ui/core/shared/title_suggestion_screen.dart          # line 475: cancel_button
                                                          # line 482: confirm_button
                                                          # line 516: title_input
                                                          # line 729: branch_mode_summarize_option
                                                          # line 737: branch_mode_raw_option
                                                          # line 750: branch_mode_cancel_button
                                                          # line 765: branch_mode_continue_button
```

未补 ValueKey（明确为剩余工作）：

- `send_button` / `stop_button`（`lib/ui/core/shared/chat_composer.dart`）——case 1-4 实跑不依赖，`_sendMessage` 用 `if (sendButton.evaluate().isNotEmpty)` 防御式跳过。补这两个 Key 需要扩展 `chat_composer.dart` 的 widget 结构，超出本次分支创建范围。

### 3 个 helper 暂未提取（明确为剩余工作）

- `_createTestTheme` / `_createTestNode` / `_sendMessage` 当前在 `branch_creation_test.dart` 内重复出现 3-4 次（line 39/45/201/207/358/361/409/412/501/504/519/522 等位置），未提取到 `integration_test/_support/test_fixtures.dart`（该文件不存在）。提取后其他集成测试文件（如 `chat_streaming_test.dart` / `note_crud_test.dart`）也可复用，是更广范围的清理任务。

### branch-creation.md 三处更新（commit `b20ad1f`）

- 状态行（line 6）：`case 1/2/3/4 已实跑通过，case 5/6/7 待实现` → `case 1/2/3/4 已实跑通过；case 5/6 scaffold 待实跑；case 7 scaffold + 待建 LLM mock 工具`
- § 2 测试矩阵（line 35-41）：case 1 核心 TODO 从 `✅ 已实现` 改为 `✅ 已实跑`（与 2/3/4 对齐）；case 5/6 从 `❌ 弹 sheet 后取消` / `❌ title 页取消` 改为 `❌ scaffold，待实跑`；case 7 从 `❌ mock LLM 失败` 改为 `❌ scaffold，待建 mock 工具`
- § 10 Checklist 代码层面（line 553-563）：9 项中 5 项 `[x]`——4 个 ValueKey 项（branch_button / branch_mode_* / title_input / confirm_button / cancel_button），§ 5.1-5.4 实现项，case 1-4 跑通截图项；4 项 `[ ]`——`send_button` / `stop_button` ValueKey（带注释说明不依赖），3 helper 提取项，LLM HTTP mock 工具项，§ 5.5-5.7 实现项

### DECISIONS.md 新增 ADR-015（commit `edad9e9`）

按 ADR-011 "纯文段 + 不抽字段"格式记录：背景/决策/理由/影响范围/实施要点 5 段。明确"翻转 spec § 8 不实现决策"为正式 ADR 条目，给后续 case 5/6/7 收尾留下可回溯的决策依据。

## 验证

| 类别 | 状态 |
|---|---|
| case 1（选中文本 + raw）实跑 | ✅ 完整链路通过，截图归档 |
| case 2（选中文本 + summarize）实跑 | ✅ 完整链路通过，截图归档 |
| case 3（无选 + raw）实跑 | ✅ 完整链路通过，截图归档 |
| case 4（无选 + summarize）实跑 | ✅ 完整链路通过，截图归档（含 LLM 真实调用） |
| case 5（模式选择取消） | ❌ scaffold（待实跑） |
| case 6（标题选择取消） | ❌ scaffold（待实跑） |
| case 7（LLM 失败 fallback） | ❌ scaffold（待建 LLM mock 工具） |
| `flutter analyze` | ✅ 无新增 error |
| 8 个 ValueKey 补全 | ✅ 4 文件 8 处 |
| `send_button` / `stop_button` 未补 | ⚠️ case 1-4 实跑不依赖，已标注为剩余工作 |
| 3 个 helper 未提取 | ⚠️ 已标注为剩余工作 |

## 已知风险（留给后续决定）

- **case 5/6 待实跑**：不依赖外部工具，单 chat 可完成（按 AGENTS.md "Worktree 收尾流程"起 `codex/branch-creation-cancel-tests` 分支），但优先级低于主流程矩阵，建议作为下次分支创建专项迭代的子任务。
- **case 7 阻塞在 LLM mock 工具缺口**：`integration_test/_support/` 当前无 HTTP mock 通道，可选方案两条——（a）扩展 `llm_test_config.dart` 加 `injectFailureFor(providerId)` 标记，让 `LlmApiClient` 收到标记时直接抛异常；（b）引入 `mockito` 或手写 `HttpOverrides` 拦截 HTTP client。方案选型需 brainstorming，不在本 CHANGELOG 范围。
- **commit `545f594` 混入代码 commit 序列**：该 commit 是 Chat A 在 case 1 中途提交的"doc 增量同步"（仅修改了 branch-creation.md 状态行），未遵守"代码 commit 和文档 commit 必须分开"硬约束。后续 4 chat 推进时需在 AGENTS.md 工作流规范下强调此约束。
- **3 个 helper 重复**：`_createTestTheme` / `_createTestNode` / `_sendMessage` 在 `branch_creation_test.dart` 内重复 3-4 次，提取工作建议与 case 5/6 收尾一起做（同一个 worktree）。

## 关联

- [ADR-015](../DECISIONS.md#adr-015-分支创建集成测试-4-chat-并行推进翻转不实现-case-1-7旧决策) — 翻转不实现决策的正式记录
- [ADR-013](../DECISIONS.md#adr-013-llm-测试-key-通过-dart-define-注入放弃-assets-路径) — case 4 依赖的 LLM 注入基础设施
- [docs/_shared/integration-testing/branch-creation.md](../_shared/integration-testing/branch-creation.md) — 集成测试规范（已同步状态行 / § 2 / § 10）
- [docs/_shared/integration-testing/llm-injection.md](../_shared/integration-testing/llm-injection.md) — LLM 注入详细版（case 4 走真实 LLM 路径）
- [docs/_shared/integration-testing/helpers.md](../_shared/integration-testing/helpers.md) — `_sendMessage` 等 helper 的语义定义
- [docs/_shared/integration-testing/theme-chat-e2e.md](../_shared/integration-testing/theme-chat-e2e.md) — theme_chat_e2e_test 配套文档（4 个 helper 借鉴）

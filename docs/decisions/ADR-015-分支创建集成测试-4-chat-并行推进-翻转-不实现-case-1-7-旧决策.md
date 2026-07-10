## ADR-015: 分支创建集成测试 4 chat 并行推进——翻转「不实现 case 1-7」旧决策

2026-06-22 决定。原 spec `docs/_shared/integration-testing/branch-creation.md` § 8 隐含一项决策：7 个 testWidgets 全部以「scaffold + 注释 TODO」状态存在，不实际跑通，理由是 SelectionArea 选区构造在 Flutter tester 中难以精确模拟、case 7 需 LLM mock 工具未建。本 ADR 翻转该决策——通过 4 chat 并行推进，case 1/2/3/4 已实跑通过，case 5/6/7 保留 scaffold 状态并明确剩余工作。

背景：4 case 实跑前的「阻塞点」实际是工具/协作问题，不是根本性技术障碍。case 1/3 用 `tester.enterText` + `find.text` 即可构造「选中文本」路径，绕过 SelectionArea 模拟；case 2 同理（selectedText 优先，不走 summarize 路径）；case 4 通过 `--dart-define-from-file` 注入真实 LLM Key（参见 ADR-013）调用 DeepSeek 完成「父对话总结 + 标题生成」双 LLM 任务；3 个 helper（`_createTestTheme` / `_createTestNode` / `_sendMessage`）虽未提取到 `_support/test_fixtures.dart`，但复制到每个 testWidgets 内部仍可工作（不优雅但能跑通）。LLM mock 工具仍是真实阻塞——case 7 没有 Dart-side HTTP mock 通道，无法模拟「LLM 失败」分支，spec § 4.3 提及但未实施。

决策：实施 4 chat 并行推进方案，不在新一轮 worktree 中启动 case 5/6/7 收尾。case 1-4 视为已实跑通过，case 5/6 视为「scaffold 待实跑」（不依赖外部工具，仅需补测试断言），case 7 保留为「scaffold + 待建 LLM mock 工具」（独立前置任务）。4 chat 的具体分工：Chat A = case 1（选中文本 + raw），Chat B = case 2（选中文本 + summarize），Chat C = case 3（无选 + raw），Chat D = case 4（无选 + summarize）。每个 chat 独立 worktree、独立 commit，共享同一 dev 分支作为合并目标。

理由：4 case 实跑证明 spec § 8 的「不实现」判断是过度悲观——SSE 注入路径 + ValueKey 补全 + tester API 组合足以覆盖核心矩阵。剩余 3 case 不阻塞主流程（cancel/fallback 是边界场景），且 case 7 仍卡在工具链缺口上，单 chat 推进 ROI 低。「翻转决策 + 保留 scaffold」的做法既承认技术进展（4 case 实跑），又诚实标注剩余工作（5/6/7 仍待补），避免「全做完」的认知偏差。

影响范围：`docs/_shared/integration-testing/branch-creation.md`（状态行、§ 2 测试矩阵、§ 10 Checklist 三处更新，commit b20ad1f），`integration_test/branch_creation_test.dart`（4 chat 7 个 commit：5bdf7af / a3ee1e6 / 4e22b1e / 4282c82 / b0790e2 / 545f594 / 32c6b73），8 个 ValueKey 补全（`branch_button` / `branch_mode_summarize_option` / `branch_mode_raw_option` / `branch_mode_continue_button` / `branch_mode_cancel_button` / `title_input` / `confirm_button` / `cancel_button`），3 个 helper 暂未提取（`_support/test_fixtures.dart` 不存在，`send_button` / `stop_button` ValueKey 仍缺，`_sendMessage` 用 if 防御跳过）。

实施要点：4 chat 共享主仓库 dev 分支作为合并目标，每个 chat 在独立 worktree 中完成 case 实现后 rebase origin/dev 再 `--ff-only` 合并；commit message 遵循 `test(branch_creation): case N <场景>` 格式（5bdf7af / a3ee1e6 等），便于按 case 维度回溯。case 5/6/7 启动新一轮 worktree 的前置条件：5/6 只需补 testWidgets 内部 TODO 注释（无外部依赖，可单人 1 个 chat 完成）；7 需要先建 LLM HTTP channel mock 工具（独立任务，可单独起 worktree）。

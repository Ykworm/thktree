# thktree-e2e-tests

ThkTree 端到端集成测试（跨端：iOS / Android / macOS）+ 人话版测试用例目录。

## 为什么叫 `integration_test`？

**这是 Flutter 框架的历史遗留问题，不是我们的选择。**

Flutter 团队在早期（约 2021 年）引入 `integration_test` 包时，错误地将"端到端测试"命名为"集成测试"。这个命名一直沿用至今，框架硬编码要求测试文件必须放在 `integration_test/` 目录下，无法自定义。

社区对此早有批评：

> "I think the term 'integration test', the way it's used around Flutter, is rather unfortunate. While they do indeed test the integration of all the classes and widgets, a much more expressive name would be 'UI flow test' because that's exactly what's being tested."
> — [ResoCoder](https://resocoder.com/2021/01/02/flutter-integration-test-tutorial-firebase-test-lab-codemagic/)

**正确的理解**：本目录包含的是 **E2E（端到端）测试**，测试完整的用户业务流程（主题→节点→聊天→分支）。目录名 `integration_test` 只是服从框架约束，不代表测试性质。

- `common/`：三端共用测试脚本
- `platform/android/`：Android 独占
- `platform/desktop/`：macOS 桌面独占
- `platform/recovery/`：iOS 独占（后台恢复）
- `_support/`：共享 fixture / helper
- `docs/test-cases-catalog.md`：测试用例目录（**规范真源**，人话，贡献者可直接改）
- `test-data/topics.md`：TREE-1 用的主题+文章 seed（人话可读镜像）

本目录是 ThkTree 主仓库内的本地目录，通过 git worktree 共享给各端使用。

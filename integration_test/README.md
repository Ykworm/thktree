# thktree-e2e-tests

ThkTree 端到端集成测试（跨端：iOS / Android / macOS）+ 人话版测试用例目录。

- `common/`：三端共用测试脚本
- `platform/android/`：Android 独占
- `platform/desktop/`：macOS 桌面独占
- `platform/recovery/`：iOS 独占（后台恢复）
- `_support/`：共享 fixture / helper
- `docs/test-cases-catalog.md`：测试用例目录（**规范真源**，人话，贡献者可直接改）
- `test-data/topics.md`：TREE-1 用的主题+文章 seed（人话可读镜像）

本目录是 ThkTree 主仓库内的本地目录，通过 git worktree 共享给各端使用。

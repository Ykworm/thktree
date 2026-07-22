---
name: thktree-e2e-test
description: ThkTree Flutter 集成测试（integration_test）工程化规范。integration_test 是本地目录。覆盖目录结构（_support/ + common/ + platform/<feature>/ + platform/desktop/ + platform/recovery/）、人话版 test case 目录（integration_test/docs/test-cases-catalog.md，规范真源）、命名规则、新测试放置判定、运行命令、三端 worktree 协作约定。写或改任何 integration_test 文件、新增 E2E 用例、或在某平台 worktree 跑测试前，必须加载本 skill。
agent_created: true
---

# ThkTree 集成测试工程化规范

## 何时加载本 skill

- 新建 / 修改 / 移动 `integration_test/` 下任何文件
- 写新的 E2E 测试用例（不再用裸 ADB 脚本拼凑）
- 在 thktree-android / thktree-macos worktree 跑或补平台测试
- 不确定某个测试该放 `common/` 还是 `platform/<feature>/`

> 本 skill 是规范单一真源。AGENTS.md 只留指针，不内联此内容。

## integration_test 是本地目录（2026-07-22 起）

`integration_test/` 现在是 ThkTree 主仓库内的本地目录，不再是独立 git 子模块：

- 所有测试代码直接在主仓库中管理
- 三端（ThkTree 主仓 / thktree-android / thktree-macos）通过 git worktree 共享同一份代码
- 本地目录结构与之前保持一致

**为什么改回本地目录**：简化工作流程，避免子模块的复杂性，所有测试代码与主应用代码一起版本控制。

**贡献测试 case 的正确流程**：

```
1. 进入项目根目录：cd ThkTree
2. 确保 dev 分支最新：git checkout dev && git pull
3. 改/加测试 Dart + 改 docs/test-cases-catalog.md（人话 case 内容）
4. 在主仓库内提交：git add integration_test/ && git commit
5. 推送到远端：git push origin dev
```

> 改测试 **直接在主仓库内编辑**，无需进入子模块目录。
> 别人也改了测试时：`git pull` 即可同步最新。

## 目标目录结构（规范态）

```
integration_test/
│
├── _support/                        ← 全局 helpers & fixtures（三端共享，不含 Platform 分支）
│   ├── test_helpers.dart               通用工具（waitForText, pumpAndSettle…）
│   ├── topic_library.dart              3×3×3×4 树 fixture 定义（含交叉引用注释，改需同步 test-data/topics.md）
│   ├── topic_llm_client.dart           mock LLM client（⚠️ 有 invalid_override 历史债，见红线）
│   ├── search_fixtures.dart            搜索测试磁盘直写 fixture
│   ├── llm_test_config.dart            --dart-define-from-file 加载 LLM key
│   ├── in_memory_llm_config_store.dart 内存 LLM config（免 Keychain）
│   ├── failing_search_service.dart     搜索失败 fake service
│   ├── step_timer.dart                 步骤计时
│   └── test-data/topics.md             主题+文章 seed（人话可读镜像，TREE-1 消费）
│
├── common/                          ← 跨平台测例（三端 CI 都跑，禁止 Platform.is* / defaultTargetPlatform）
│   ├── theme_chat_e2e_test.dart
│   ├── branch_creation_test.dart
│   ├── node_reorder_test.dart
│   ├── merge_chat_button_test.dart
│   ├── chat_streaming_test.dart / chat_breadcrumb_test.dart / chat_latex_overflow_test.dart
│   ├── note_*.dart / search_*.dart / offline_test.dart / backup_restore_test.dart
│   ├── topic_library_tree_note_test.dart   3×3×3×4 树生成+校验（消费 test-data/topics.md）
│   └── llm_error_retry_test.dart
│
├── docs/
│   └── test-cases-catalog.md            ← 人话版 test case 目录（**规范真源**），每条含完整 case 内容 + 平台覆盖/差异/Run
│
└── platform/                        ← 平台有关，按 feature 拆（现行态，2026-07-12）
    ├── branch/
    │   ├── branch_shared.dart          公共步骤（建节点、发消息、断言分支存在）
    │   └── android_test.dart           Android: 点 branch 按钮（无 SelectionArea）
    ├── image/
    │   ├── image_shared.dart
    │   └── android_test.dart           Android: 拍照 + 相册
    ├── share/
    │   ├── share_shared.dart
    │   └── android_test.dart           Android: share→系统分享→保存
    ├── recovery/
    │   └── ios_test.dart               iOS: 后台任务中断→恢复
    └── desktop/                      ← macOS 独有（右键代替长按、菜单代替 sheet、多栏布局）
        ├── shell_smoke_test.dart / sidebar_nav_test.dart / theme_chat_test.dart / comprehensive_test.dart
        └── desktop_*_helpers.dart（nav/node/chat/branch/interaction/primitive/theme/fixtures）
```

> **iOS 的 branch（长按选词）目前落在 `common/branch_creation_test.dart` 内**（不是 platform/branch/ios_test），macOS 的 branch 落在 `platform/desktop/*`。`platform/branch/` 目前仅 Android。这与早前计划（每 feature 三端各一文件）不同——实际重排时按「能跑就归位」原则落地，不强制对称。
> **人话 test case 目录 = `integration_test/docs/test-cases-catalog.md`**：开发者即需求方，md 写满 case 内容（前置/步骤/预期/边界），Dart 是实现。贡献者改 md 设计 case 不需写 Dart。

## 命名规则

| 类型 | 格式 | 示例 |
|---|---|---|
| 跨平台测试 | `common/<feature>_test.dart` | `common/branch_creation_test.dart` |
| 平台测试 | `platform/<feature>/<platform>_test.dart` | `platform/branch/android_test.dart` |
| 公共步骤 | `platform/<feature>/<feature>_shared.dart` | `platform/branch/branch_shared.dart` |
| 全局 helper | `_support/<name>.dart`（无后缀约定） | `_support/test_helpers.dart` |
| 平台 helper | `<scope>_helpers.dart` | `platform/desktop/nav_helpers.dart` |

## 判定：新测试放哪

```
新测试需要 Platform.is* / defaultTargetPlatform 分支吗？
├── 否 → common/<feature>_test.dart
└── 是
    ├── 已有 platform/<feature>/ 目录？
    │   ├── 是 → platform/<feature>/<platform>_test.dart
    │   └── 否 → 新建 platform/<feature>/，提取公共步骤到 <feature>_shared.dart
    └── 公共步骤提到 <feature>_shared.dart，各平台 _test.dart import 它
```

## 运行命令

```bash
# 跨平台测例（三端皆可，需 device 参数）
flutter test integration_test/common/ \
  --dart-define-from-file=build/dart_define.json -d <device>

# 单平台单 feature
flutter test integration_test/platform/branch/android_test.dart -d emulator-5554

# 全量
flutter test integration_test/ -d <device>
```

## Worktree 协作约定

`integration_test/` 现在是本地目录，三端通过 git worktree 共享同一份代码。因此**没有「某 worktree 只改某平台目录」的物理隔离**——隔离靠的是协作纪律：

| 平台 | 你去改主仓库里的 | 提交到 |
|---|---|---|
| iOS | `common/` `platform/*/ios_test.dart` `platform/recovery/ios_test.dart` | 主仓库 dev 分支 |
| Android | `platform/*/android_test.dart` | 主仓库 dev 分支 |
| macOS | `platform/desktop/*` | 主仓库 dev 分支 |
| 跨平台 | `common/` `_support/` | 主仓库 dev 分支 |

- 在**任一** app worktree 里直接编辑 `integration_test/` 即可；改完在主仓库内 commit + push dev
- 重排文件一律用 `git mv`（不是 `mv`），保留 rename 历史
- import 路径修正后必须 `flutter analyze integration_test/` 0 error（允许预存的 `topic_llm_client` 等 LlmClient mock `invalid_override` 历史债，见红线）
- 提交同样遵循**代码 commit 与文档 commit 分离**（Dart 一个 commit、catalog/test-data 一个 commit）

## 现行态（2026-07-22 改回本地目录）

- 三端（ThkTree 主仓 / thktree-android / thktree-macos）`integration_test/` 已统一为本地目录，通过 git worktree 共享同一份代码
- 旧结构（`_shared/ + android/ + ios/ + macos/` 平铺）已完全迁移到 `_support/ + common/ + platform/<feature>/ + platform/desktop/ + platform/recovery/`
- macOS 桌面测试已归位 `platform/desktop/`（12 文件，保留 desktop_ 前缀，import 改 `../../_support/`）
- Android `platform/{branch,image,share}/android_test.dart` 已建
- 人话 case 目录 `docs/test-cases-catalog.md` + `test-data/topics.md` 已随本地目录落盘
- 详细进度见主仓 `docs/test-engineering-plan.md`（Phase 0–4 全完成）

## 测试结果存放（results/，在本地目录内）

- 模型：每个 case 每端一份结果文件，**跑完覆盖旧结果，不堆历史**
- 路径：`results/<CASE-ID>/<platform>.md`（ios/android/macos 各一份，互不被覆盖）
- 失败截图：`results/artifacts/<CASE-ID>-<platform>.png`（gitignore，不进仓库）
- 运行：`bash integration_test/tools/run_e2e.sh <CASE-ID> <platform>`（自动从 catalog 解析脚本 + `--plain-name`，注入真实 LLM key）
- **LLM 硬约束：绝对禁止 mock**，缺真实 key 时 runner 拒绝运行
- 格式与提交约定见 `integration_test/results/README.md`

## 红线

- `common/` 禁止出现任何 `Platform.is*` / `defaultTargetPlatform` 分支
- **禁止在各 app worktree 内直接编辑 `integration_test/` 下的文件**——改测试必须在主仓库内进行（见上「integration_test 是本地目录」）
- 禁止为凑覆盖率生成低价值测试（见 AGENTS.md 红线）
- B4 手势冲突修复已落地 `lib/ui/core/shared/message_bubble.dart`：Android 跳过 `SelectionArea`，iOS/macOS 不变；新增 Android 交互测试时不要依赖文本选区
- 人话 case 目录 `docs/test-cases-catalog.md` 是规范真源：新增/修改测试 case 时**同步更新 catalog**（Dart 实现必须忠实于 md 描述的 case 内容）

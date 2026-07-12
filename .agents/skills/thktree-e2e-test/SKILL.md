---
name: thktree-e2e-test
description: ThkTree Flutter 集成测试（integration_test）工程化规范。覆盖目录结构（_support/ + common/ + platform/<feature>/）、命名规则、新测试放置判定流程、运行命令、三端 worktree 约定（ThkTree 主仓改 common/_support/ios、thktree-android 改 android、thktree-macos 改 macos/desktop）。写或改任何 integration_test 文件、新增 E2E 用例、或在某平台 worktree 跑测试前，必须加载本 skill。
agent_created: true
---

# ThkTree 集成测试工程化规范

## 何时加载本 skill

- 新建 / 修改 / 移动 `integration_test/` 下任何文件
- 写新的 E2E 测试用例（不再用裸 ADB 脚本拼凑）
- 在 thktree-android / thktree-macos worktree 跑或补平台测试
- 不确定某个测试该放 `common/` 还是 `platform/<feature>/`

> 本 skill 是规范单一真源。AGENTS.md 只留指针，不内联此内容。

## 目标目录结构（规范态）

```
integration_test/
│
├── _support/                        ← 全局 helpers & fixtures（三端共享，不含 Platform 分支）
│   ├── test_helpers.dart               通用工具（waitForText, pumpAndSettle…）
│   ├── topic_library.dart              3×3×3×4 树 fixture 定义
│   ├── topic_llm_client.dart           mock LLM client
│   ├── search_fixtures.dart            搜索测试磁盘直写 fixture
│   ├── llm_test_config.dart            --dart-define-from-file 加载 LLM key
│   ├── in_memory_llm_config_store.dart 内存 LLM config（免 Keychain）
│   ├── failing_search_service.dart     搜索失败 fake service
│   └── step_timer.dart                 步骤计时
│
├── common/                          ← 跨平台测例（三端 CI 都跑，禁止 Platform.is* / defaultTargetPlatform）
│   ├── theme_chat_e2e_test.dart
│   ├── branch_creation_test.dart
│   ├── node_reorder_test.dart
│   ├── merge_chat_button_test.dart
│   ├── chat_streaming_test.dart
│   ├── chat_breadcrumb_test.dart
│   ├── chat_latex_overflow_test.dart
│   ├── note_*.dart / search_*.dart / offline_test.dart / backup_restore_test.dart
│   ├── topic_library_tree_note_test.dart   3×3×3×4 树生成+校验
│   └── llm_error_retry_test.dart
│
└── platform/                        ← 平台有关，按 feature 拆
    ├── branch/
    │   ├── branch_shared.dart          公共步骤（建节点、发消息、断言分支存在）
    │   ├── ios_test.dart               iOS: 长按选文本→branch
    │   ├── android_test.dart           Android: 点 branch 按钮（无 SelectionArea）
    │   └── macos_test.dart             macOS: 右键菜单→branch
    ├── image/
    │   ├── image_shared.dart
    │   ├── android_test.dart           Android: 拍照 + 相册
    │   └── ios_test.dart               iOS: 相机 + Photo Library
    ├── share/
    │   ├── share_shared.dart
    │   ├── android_test.dart           Android: share→系统分享→保存
    │   └── ios_test.dart               iOS: UIActivityViewController
    ├── recovery/
    │   ├── recovery_shared.dart
    │   └── ios_test.dart               iOS: 后台任务中断→恢复
    └── desktop/                      ← macOS 独有
        ├── desktop_shared.dart + theme_chat_test.dart + comprehensive_test.dart
        └── *_helpers.dart（nav/node/chat/branch/interaction/primitive/theme）
```

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

## Worktree 约定（避免三端合并冲突）

| 仓库 | 只改 | 禁止碰 |
|---|---|---|
| ThkTree（主仓，dev） | `common/` ` _support/` `platform/*/ios_test.dart` | 其他平台目录 |
| thktree-android | `platform/*/android_test.dart` | `common/` `ios_test.dart` `macos_test.dart` |
| thktree-macos | `platform/*/macos_test.dart` `platform/desktop/` | 其他平台目录 |

- 重排一律用 `git mv`（不是 `mv`），保留 rename 历史
- import 路径修正后必须 `flutter analyze integration_test/` 0 error
- 提交：代码 commit 与文档 commit 分离

## 迁移状态（重要，2026-07-12）

当前 `integration_test/` 正从旧结构（`_shared/ + android/ + ios/ + macos/`）向本规范迁移。
Phase 0–4 进度见 `docs/test-engineering-plan.md`。迁移完成前：

- 若实际目录与本规范不符，**以 `test-engineering-plan.md` 的 Phase 状态为准**，不要盲目新建 `common/` 或 `platform/`
- macOS worktree 的 `desktop_*.dart` 尚未归位（Phase 2 待执行）
- Android 的 `platform/image|share|branch/android_test.dart` 尚待新建（Phase 3 待执行）

## 红线

- `common/` 禁止出现任何 `Platform.is*` / `defaultTargetPlatform` 分支
- 各 worktree 只改自己平台目录，禁止跨平台改他人文件
- 禁止为凑覆盖率生成低价值测试（见 AGENTS.md 红线）
- B4 手势冲突修复已落地 `lib/ui/core/shared/message_bubble.dart`：Android 跳过 `SelectionArea`，iOS/macOS 不变；新增 Android 交互测试时不要依赖文本选区

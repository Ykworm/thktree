# 测试工程化方案（详细版）

> 状态：Phase 0-4 待执行（Phase 5 skill 已完成）；三端当前为未提交半成品平铺结构
> 日期：2026-07-12
> 适用：ThkTree 主仓库 + thktree-android / thktree-macos worktree

---

## 1. 目标

- 测试代码跟平台无关的放 `common/`，平台有关的按 feature 拆到 `platform/<feature>/<platform>_test.dart`
- 每个 worktree 只改自己平台的文件，合并冲突最小化
- 新 agent 进来能从文档看懂结构，不用猜

---

## 2. 目标目录结构

```
integration_test/
│
├── _support/                              ← 全局 helpers & fixtures（三端共享）
│   ├── test_helpers.dart                     通用工具（waitForText, pumpAndSettle 等）
│   ├── topic_library.dart                    3×3×3 树 fixture 定义
│   ├── topic_llm_client.dart                 mock LLM client
│   ├── search_fixtures.dart                  搜索测试磁盘直写 fixture
│   ├── llm_test_config.dart                  --dart-define-from-file 加载 LLM key
│   ├── in_memory_llm_config_store.dart       内存 LLM config（免 Keychain）
│   ├── failing_search_service.dart           搜索失败 fake service
│   └── step_timer.dart                       步骤计时
│
├── common/                                ← 跨平台测例（三端 CI 都跑，不含 Platform.is*）
│   ├── theme_chat_e2e_test.dart              主题→节点→聊天 2 round
│   ├── branch_creation_test.dart             三种分支模式
│   ├── node_reorder_test.dart                拖拽排序
│   ├── merge_chat_button_test.dart           合并按钮→确认页
│   ├── chat_streaming_test.dart              流式回复
│   ├── chat_breadcrumb_test.dart             面包屑导航
│   ├── chat_latex_overflow_test.dart         LaTeX 渲染回归
│   ├── note_crud_test.dart                   笔记 CRUD
│   ├── note_search_test.dart                 笔记全文搜索
│   ├── note_title_required_test.dart         标题必填
│   ├── note_to_chat_test.dart                笔记→对话
│   ├── offline_test.dart                     离线模式
│   ├── search_test.dart                      搜索端到端
│   ├── search_settings_button_test.dart      搜索→设置入口
│   ├── keyword_ranking_test.dart             关键词排行
│   ├── lab_tab_test.dart                     Lab tab
│   ├── backup_restore_test.dart              备份恢复
│   ├── topic_library_tree_note_test.dart     3×3×3 树生成+校验
│   └── llm_error_retry_test.dart             LLM 错误重试
│
└── platform/                              ← 平台有关，按 feature 拆
    ├── branch/                            ← Feature: 分支创建
    │   ├── branch_shared.dart                公共步骤：建节点、发消息、断言分支存在
    │   ├── ios_test.dart                     iOS: 长按选文本→branch
    │   ├── android_test.dart                 Android: 点 branch 按钮→branch（无 SelectionArea）
    │   └── macos_test.dart                   macOS: 右键菜单→branch
    │
    ├── image/                             ← Feature: 图片插入
    │   ├── image_shared.dart                 公共步骤：断言图片出现在消息中、助手回复
    │   ├── android_test.dart                 Android: 拍照 + 相册
    │   └── ios_test.dart                     iOS: 相机 + Photo Library
    │
    ├── share/                             ← Feature: 分享导出
    │   ├── share_shared.dart                 公共步骤：断言分享 sheet 出现、图片生成
    │   ├── android_test.dart                 Android: share 按钮→系统分享→保存
    │   └── ios_test.dart                     iOS: share 按钮→UIActivityViewController
    │
    ├── recovery/                          ← Feature: 后台恢复
    │   ├── recovery_shared.dart              公共步骤：断言中断状态、恢复后消息完整
    │   └── ios_test.dart                     iOS: 后台任务中断→恢复
    │
    └── desktop/                           ← Feature: 桌面端交互（macOS 独有）
        ├── desktop_shared.dart               公共桌面步骤：侧栏、pane、键盘快捷键
        ├── theme_chat_test.dart              macOS: 三栏 theme→chat
        ├── comprehensive_test.dart           macOS: 综合 E2E
        ├── nav_helpers.dart                  导航辅助
        ├── branch_helpers.dart               分支辅助
        ├── chat_helpers.dart                 聊天辅助
        ├── interaction_helpers.dart          鼠标/键盘辅助
        ├── node_helpers.dart                 节点树辅助
        ├── primitive_helpers.dart            平台原语替换（sheet→menu 等）
        ├── test_fixtures.dart                桌面测试夹具
        └── theme_helpers.dart                主题辅助
```

### 命名规则

| 类型 | 格式 | 示例 |
|---|---|---|
| 测试文件 | `<feature>_<platform>_test.dart` | `branch_android_test.dart` |
| 公共步骤 | `<feature>_shared.dart` | `branch_shared.dart` |
| 全局 helper | 任意名，无后缀 | `test_helpers.dart` |
| 平台 helper | `<scope>_helpers.dart` | `nav_helpers.dart` |

### 判定规则：新测试放哪？

```
新测试需要 Platform.is* / defaultTargetPlatform 分支吗？
├── 否 → common/<feature>_test.dart
└── 是
    ├── 已有 platform/<feature>/ 目录？
    │   ├── 是 → platform/<feature>/<platform>_test.dart
    │   └── 否 → 新建 platform/<feature>/，提取公共步骤到 <feature>_shared.dart
    └── 公共步骤提取到 <feature>_shared.dart，各平台 _test.dart import 它
```

---

## 3. 执行 Plan

### Phase 0：用 stash 保存半成品、回到干净平铺（替代 git clean）

> 决策（2026-07-12）：废弃 `git clean -fd`（无回收站、误删不可逆）。改用 `git stash -u` 收走未提交半成品，working tree 自动回到 HEAD 干净平铺，无需 clean。重排验证后 `git stash drop` 丢弃；若搞砸 `git stash pop` 恢复。
> 三端 HEAD 均为干净平铺（ThkTree=f600f57 / android=ee2ab6e / macos=08b98a1），所有半成品都是未提交改动（rsync 把平铺 `git rm` 删了 + 复制副本到 `_shared/` untracked）。

| 步骤 | 操作 | 仓库 | 说明 |
|---|---|---|---|
| 0.1 | `git stash push -u -m "pre-refactor snapshot" -- integration_test/` | ThkTree | 收走 22 文件 staged 删除状态 + untracked `_shared/`（20 文件副本含 merge_chat_button）`ios/`；stash 后 working tree = f600f57 干净平铺 |
| 0.2 | `git stash push -u -m "pre-refactor snapshot" -- integration_test/` | thktree-android | 收走 untracked `_shared/` `ios/` `merge_chat_button_test.dart`；working tree = ee2ab6e 干净平铺 |
| 0.3 | `git stash push -u -m "pre-refactor snapshot" -- integration_test/_shared integration_test/ios` | thktree-macos | **只收走半成品 `_shared/` `ios/`**，保留 `desktop_*.dart`（tracked 真实成果）与 `_support/desktop_*.dart`（untracked helper，Phase 2.3 归位用）；working tree = 干净平铺 + desktop 成果 |
| 0.4 | 三端 `git status --short integration_test/` 应只剩 macOS desktop_*.dart 修改 | 三端 | 确认干净起点 |

> macOS 0.3 用路径限定 stash，避免收走 `_support/desktop_*.dart`（否则 Phase 2.3 无文件可 mv）。

### Phase 1：主仓库用 `git mv` 重排（ThkTree，分支 codex/ui-flatten-polish）

| 步骤 | 操作 |
|---|---|
| 1.1 | `mkdir -p integration_test/{common,platform/{branch,image,share,recovery,desktop}}` |
| 1.2 | `git mv integration_test/<file>.dart integration_test/common/` × 20 个跨平台文件（不含 desktop_*.dart，主仓无） |
| 1.2b | `merge_chat_button_test.dart` 归位：以 android 端或主仓 stash 副本中**较新版本**为准 → `git mv` 到 `integration_test/common/merge_chat_button_test.dart`，删另一处副本 |
| 1.3 | `git mv integration_test/chat_async_recovery_test.dart integration_test/platform/recovery/ios_test.dart` |
| 1.4 | `git mv integration_test/test_helpers.dart integration_test/_support/test_helpers.dart`（平铺层恢复后应有） |
| 1.5 | sed 修正 import：`common/` 内 `import '_support/` → `import '../_support/`；`platform/` 内 → `import '../../_support/` |
| 1.6 | `flutter analyze integration_test/` 确认 0 error |

### Phase 2：macOS worktree 归位（thktree-macos，分支 feat/macos-desktop）

| 步骤 | 操作 |
|---|---|
| 2.1 | `git mv integration_test/desktop_theme_chat_e2e_test.dart integration_test/platform/desktop/theme_chat_test.dart` |
| 2.2 | `git mv integration_test/desktop_comprehensive_e2e_test.dart integration_test/platform/desktop/comprehensive_test.dart` |
| 2.3 | `git mv integration_test/_support/desktop_*.dart integration_test/platform/desktop/` × 9 文件（helpers / nav / node / chat / branch / interaction / primitive / theme / test_fixtures） |
| 2.4 | `git mv integration_test/_support/desktop_nav.dart integration_test/platform/desktop/nav_helpers.dart`（统一命名，可选） |
| 2.5 | sed 修正 import 路径（desktop_*.dart 内部互引、对 _support 引用） |
| 2.6 | `flutter analyze integration_test/` 确认 |

### Phase 3：Android worktree 创建空缺文件（thktree-android，分支 feat/android-app）

| 步骤 | 操作 |
|---|---|
| 3.1 | 创建 `platform/image/android_test.dart`（TC-04 图片发送） |
| 3.2 | 创建 `platform/share/android_test.dart`（TC-07 分享导出） |
| 3.3 | 创建 `platform/branch/android_test.dart`（Android 分支创建，无 SelectionArea） |
| 3.4 | 每个 feature 目录建 `*_shared.dart` 提取公共步骤（image_shared / share_shared / branch_shared） |
| 3.5 | `flutter analyze integration_test/` 确认 |

### Phase 4：提交（代码/文档分离，落各自分支）

| commit | 内容 | 仓库 / 分支 |
|---|---|---|
| `refactor(test): integration_test 按平台/feature 重排` | `git mv` + import 修正 | ThkTree / `codex/ui-flatten-polish` |
| `docs(test): 测试工程化方案 + skill` | 本文档 + AGENTS.md | ThkTree / `codex/ui-flatten-polish` |
| `feat(android-test): image/share/branch 测试` | 新建测试文件 | thktree-android / `feat/android-app` |
| `refactor(macos-test): desktop 测试归位` | desktop_*.dart 移动 | thktree-macos / `feat/macos-desktop` |

> 主仓当前在 `codex/ui-flatten-polish`（非 dev）。重排完成、用户实测通过后，再 `rebase origin/dev` + `--ff-only` 合并回 dev（遵循 AGENTS.md 红线）。

### Phase 5：落地测试规范 skill（替代原 AGENTS.md §4 方案）

> 决策（2026-07-12）：不把测试规范内联进 AGENTS.md，改为 project-level skill，做测试任务时按需调用。

| 步骤 | 操作 |
|---|---|
| 5.1 | 新建 `.workbuddy/skills/thktree-e2e-test/SKILL.md`（承载 §2-§4 规范）✅ 已完成 |
| 5.2 | `AGENTS.md` 第 25 行：集成测试 → 指向 `thktree-e2e-test` skill ✅ 已完成 |
| 5.3 | 本 Plan §4 标记"已落地为 skill"，不再写入 AGENTS.md ✅ 已完成 |

详见 `.workbuddy/skills/thktree-e2e-test/SKILL.md`。

---

## 4. 测试规范（已落地为 `.workbuddy/skills/thktree-e2e-test` skill）

> 2026-07-12 决策：原规划写入 AGENTS.md §4，改为 project-level skill 承载（避免 AGENTS.md 膨胀、违反其"保持精简"原则）。AGENTS.md 仅保留一行指针。本 § 保留作单一真源参考。

```markdown
## 测试规范

### 目录结构

integration_test/ 按以下规则组织：

- `_support/`：全局 helpers & fixtures，三端共享
- `common/`：跨平台测例，不含任何 Platform.is* / defaultTargetPlatform 分支
- `platform/<feature>/`：平台有关测例，按 feature 拆分
  - `<feature>_shared.dart`：该 feature 的公共步骤（setup、断言）
  - `<platform>_test.dart`：各平台特有逻辑

### 新增测试时

1. 跨平台功能 → 放 `common/<feature>_test.dart`
2. 平台特有功能 → 放 `platform/<feature>/<platform>_test.dart`
3. 公共步骤提取到 `platform/<feature>/<feature>_shared.dart`
4. 全局工具放 `_support/`

### 运行测试

```bash
# 跨平台测例
flutter test integration_test/common/ --dart-define-from-file=build/dart_define.json -d <device>

# 平台特有
flutter test integration_test/platform/branch/android_test.dart -d emulator-5554

# 全部
flutter test integration_test/ -d <device>
```

### Worktree 约定

- thktree-android：只改 `platform/*/android_test.dart`，不碰别的平台目录
- thktree-macos：只改 `platform/*/macos_test.dart` 和 `platform/desktop/`
- ThkTree（主仓库）：改 `common/` 和 `_support/`，以及 `platform/*/ios_test.dart`
```

---

## 5. 风险与缓解

| 风险 | 影响 | 缓解 |
|---|---|---|
| `flutter test` 子目录发现 | 测试可能跑不到 | Phase 1.6 实测 `flutter test integration_test/` 递归扫描 |
| import 路径遗漏 | 编译失败 | sed 批量修 + `flutter analyze` 全量检查 |
| 0.3 stash 误收 macOS `_support/desktop_*.dart` | Phase 2.3 无 helper 可 mv | 0.3 用路径限定 `integration_test/_shared integration_test/ios`，保留 desktop 成果与 helper（见 Phase 0） |
| `git mv` rename detection | 历史断裂 | 用 `git mv`（不是 `mv`），commit 时 `--find-renames` |
| 三个 worktree 同步时序 | 中间状态不可跑 | Phase 1 先在主仓库完成，验证后再同步 worktree |

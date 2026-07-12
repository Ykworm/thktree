# Android e2e 测试总览

> 适用分支：`feat/android-app`（基于 dev f600f57，**未合并回 dev**）
> 最后更新：2026-07-12

---

## 目录结构

```
ThkTree（主仓库，所有测试代码在此）
└── integration_test/
    ├── _support/                          ← helpers & fixtures（跨平台共享）
    │   ├── topic_library.dart
    │   ├── topic_llm_client.dart
    │   ├── search_fixtures.dart
    │   ├── llm_test_config.dart
    │   ├── in_memory_llm_config_store.dart
    │   ├── failing_search_service.dart
    │   └── step_timer.dart
    ├── _shared/                           ← 跨平台测例（各端 CI 都跑）
    │   ├── test_helpers.dart
    │   ├── theme_chat_e2e_test.dart
    │   ├── branch_creation_test.dart
    │   ├── node_reorder_test.dart
    │   ├── merge_chat_button_test.dart
    │   ├── chat_streaming_test.dart
    │   ├── chat_breadcrumb_test.dart
    │   ├── note_crud_test.dart
    │   ├── note_search_test.dart
    │   ├── search_test.dart
    │   ├── topic_library_tree_note_test.dart
    │   └── …（共 20 文件）
    ├── android/                           ← Android 特有
    │   ├── image_send_test.dart    （缺）
    │   └── share_export_test.dart  （缺）
    ├── ios/                               ← iOS 特有
    │   └── chat_async_recovery_test.dart
    └── macos/                             ← macOS 特有
        └── …（待填充）
```

**原则**：所有测试代码在 ThkTree 主仓库持有真源。worktree（`thktree-android` / `thktree-macos`）通过 git 同步，不各自私藏文件。

---

## Test Case ↔ 测试文件映射

| TC | 场景 | 对应文件 | 覆盖程度 | 说明 |
|---|---|---|---|---|
| TC-01 | 测试数据准备 | — | — | 数据由 `_shared/topic_library_tree_note_test.dart` 在 setup 中通过 UI 生成 |
| TC-02 | 模型配置验证 | — | — | 手动检查，无自动化测试 |
| TC-03a | 分支创建 - Blank | `_shared/branch_creation_test.dart` | ✅ 已覆盖 | 选中文本 + raw 模式 |
| TC-03b | 分支创建 - Raw | `_shared/branch_creation_test.dart` | ✅ 已覆盖 | 同上文件，raw 模式已验证 |
| TC-03c | 分支创建 - Summarize | `_shared/branch_creation_test.dart` | ✅ 已覆盖 | 在同一个 group 内 |
| TC-04 | 图片插入与发送 | `android/image_send_test.dart` | ❌ 缺 | 需新建 |
| TC-05 | 同层节点排序 | `_shared/node_reorder_test.dart` | ✅ 已覆盖 | 同层拖拽重排序（B4 修复后可用） |
| TC-06 | 节点合并 | `_shared/merge_chat_button_test.dart` | ✅ 已覆盖 | 合并按钮→导航到确认页 |
| TC-07 | 分享导出 | `android/share_export_test.dart` | ❌ 缺 | 需新建 |
| TC-08 | 深度 4 层限制 | `_shared/branch_creation_test.dart` | ✅ 已覆盖 | 内嵌 depth 校验逻辑 |

---

## 关键 bug 记录

### B1. FTS5 在 Android 默认不可用（已修复）

**发现时间**：2026-07-11（smoke test）

**来源**：`docs/_tmp/android-smoke-test-handoff.md`

**根因**：Android 系统 SQLite 默认未启用 FTS5 模块，`CREATE VIRTUAL TABLE ... USING fts5` 抛异常导致 DB 打不开。

**修复**：
- `lib/data/services/search_service.dart`：catch `DatabaseException` → fallback 到 LIKE 搜索，缓存 `_fts5Supported=false`
- 提交 `376c2fe`（底部导航栏图标修复同 commit）

**现状**：已验证（smoke test），搜索降级路径正常。

---

### B2. compileSdk 冲突（已修复）

**发现时间**：2026-07-11（smoke test）

**根因**：`file_picker`/`share_plus`/`flutter_secure_storage`/`jni`/`jni_flutter` 等插件把 compileSdk 硬编码为 34/30，而 `flutter_plugin_android_lifecycle` 的 AAR 要求 minCompileSdk=36。

**修复**（`android/build.gradle.kts`）：
- 移除 `evaluationDependsOn(":app")`
- `subprojects { afterEvaluate { ... as? CommonExtension ... compileSdk = 36 } }`

**现状**：已验证（`./gradlew assembleDebug` 通过），**未提交**（待复测后 commit）。

---

### B3. Merge Chat 底部按钮无响应（已修复）

**发现时间**：2026-07-12（e2e 测试）

**来源**：`handoff-android-e2e-2026-07-12.md`

**根因**：`FullTreeScreen` 底部 `CupertinoButton` 设置了 `minimumSize: Size.zero`，触控目标被压缩到文本高度（~20dp），低于 44dp 的触控安全线。

**修复**：删除 `minimumSize: Size.zero`，恢复默认 `minSize: 44.0`。

**验证方式**：`merge_chat_button_test.dart`（已添加，覆盖按钮可点击→导航到确认页）。

**note**：iOS 端（ThkTree 主仓库）同位置也有 `minimumSize: Size.zero`，需同步修复。

---

### B4. SelectionArea + LongPressDraggable 手势冲突（已修复 ✅）

**发现时间**：2026-07-12（e2e 测试）

**异常信息**：
```
'scrollable.dart': Failed assertion: line 1266: '!_selectionStartsInScrollable': is not true.
```

**触发场景**：
1. 聊天页长按消息气泡（share sheet 入口）
2. 树页长按 drag handle（reorder）
3. 树页长按节点（rename）

**影响范围**：
- ❌ share 入口无法弹出
- ❌ reorder 无法开始
- ❌ 长时间操作后应用 ANR

**根因**：`MessageBubble` 内嵌 `SelectionArea`（包裹 `GptMarkdown`），与同一 `Scrollable`/`ListView` 内的 `LongPressDraggable`/`LongPressGestureRecognizer` 竞争 gesture arena。

**修复**（`lib/ui/core/shared/message_bubble.dart`）：
- Android 平台：条件跳过 `SelectionArea`，直接渲染 `GptMarkdown`
- iOS/macOS：行为不变
- 方式：`defaultTargetPlatform == TargetPlatform.android ? child : SelectionArea(child: child)`
- 覆盖 3 处：主消息体、reasoning 区、表格视图

**验证方式**：`_shared/node_reorder_test.dart`（排序）和新 `android/share_export_test.dart`（分享）。

---

## 测试开发路线

### 需新增

| 文件 | 说明 | 优先级 |
|---|---|---|
| `integration_test/android/image_send_test.dart` | TC-04：拍照 + 相册图片发送 | P1 |
| `integration_test/android/share_export_test.dart` | TC-07：分享当前对话 / 分享整个聊天 | P1 |
| `integration_test/_support/tree_fixture.dart` | 磁盘直写 fixture：把 `topic_library.dart` 的树结构直接写出 session.md + 节点目录，免 LLM/UI 循环 | P2（优化已有测试速度） |

### 需修复

| 问题 | 文件 | 状态 |
|---|---|---|
| SelectionArea 手势冲突 | `lib/ui/core/shared/message_bubble.dart` | ✅ 已修复（Android 跳过，iOS/macOS 保留） |
| Merge 按钮 minimumSize | 两端 `full_tree_screen.dart` | ✅ 已修复 |

### 需清理

| 文件 | 原因 | 操作 |
|---|---|---|
| `docs/android-e2e-test-cases.md` | Python 脚本引用，已过时 | ✅ 已删除 |
| `docs/android-e2e-test-tools.md` | 同上 | ✅ 已删除 |
| `handoff-android-e2e-2026-07-12.md` | 内容已并入本文 | ✅ 已删除 |
| `docs/_tmp/android-smoke-test-handoff.md` | 同上 | ✅ 已删除 |
| `tools/gen_test_data.py` | Dart 版 tree_fixture 实装后淘汰 | 待定 |
| `tools/push_test_data.py` | 同上 | 待定 |
| `integration_test/` 平铺结构 | 无平台目录，worktree 冲突风险 | ✅ 已重排为 _shared/ + android/ + ios/ + macos/ |

---

## 运行方式

```bash
# 单个测试（Android）
flutter test integration_test/_shared/merge_chat_button_test.dart \
  --dart-define-from-file=build/dart_define.json \
  -d emulator-5554

# 全部跨平台测试
flutter test integration_test/_shared/ \
  --dart-define-from-file=build/dart_define.json \
  -d emulator-5554

# Android 特有测试
flutter test integration_test/android/ \
  --dart-define-from-file=build/dart_define.json \
  -d emulator-5554

# 取截图
~/Library/Android/sdk/platform-tools/adb exec-out screencap -p > /tmp/shot.png
```

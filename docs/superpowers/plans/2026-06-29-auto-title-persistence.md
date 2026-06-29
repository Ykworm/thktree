# 自动标题持久化 Bug 修复 — 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。
>
> **上游文档：** `docs/_tmp/auto-title-persistence.md`（v1 设计与根因分析，4 节用户已确认）
> **关联 issue：** 修复 2026-06-28 branch-blank-mode 引入的"自动 title 不持久化"bug
> **任务类型：** Bug 修复（+ 集成测试新增）
> **workflow：** freemode（跳过 worktree 流程；commit 由用户决定）

---

## 🎯 目标

修复 P.9-A 引入的 bug：**新建空白对话后，LLM 自动生成的 title 没有持久化**——从 tree 视角或第二次打开 chat 时，标题仍是占位"临时会话"。

核心约束（**用户明确诉求**）：**title 生成任务必须异步、与 widget 生命周期解耦**——用户在 LLM 流式结束后、title 生成完成前退出/切换页面，**后台任务仍要跑完**，直到成功或报错。

修复后应当满足：
- **Tree 视角**：title 是 LLM 生成值（不是"临时会话"）
- **第二次进入 chat_screen**：nav bar 标题是 LLM 生成值
- **提前 pop 场景**：用户离开 chat 后，后台任务照常跑完，tree 最终仍是新 title
- **用户手动改 title 场景**：流式结束后 LLM 不会覆盖用户改过的 title

---

## 🧱 技术栈与硬约束

- Flutter 3.x + Cupertino UI
- Riverpod（`ConsumerStatefulWidget` + `ref.read` / `ref.watch` / `ref.listen`）
- 集成测试驱动（项目禁用单测）
- **任务与 widget 解耦**：使用 `NotifierProvider.autoDispose.family<AutoTitleController, AutoTitleState, String>`，以 nodeId 为 family key。widget dispose 后 Notifier 仍可继续持有 ref，完成 LLM 调用 + DB 写 + tree 刷新
- **A 模式独立原则**：不修改 raw/summarize 现有代码路径；不修改 `chatTaskStateProvider`、不破坏现有 chat 流程
- **防御式编程**：widget dispose 后调 `setState` 是 noop（mounted 检查），但 `nodeStore.updateNodeTitle` + `themeDetailController.refresh()` 不依赖 widget
- **磁盘优先**（ADR-014）：复用 `nodeStore.updateNodeTitle` 的 disk-first 写

---

## 📊 任务总表

| # | 任务 | 文件 | 类型 | 依赖 |
|---|------|------|------|------|
| 1 | 新增 `AutoTitleController` Notifier + state 骨架 | `lib/ui/features/chat/auto_title_controller.dart`（新建） | 新增 | — |
| 2 | 迁移现有 `_generateTitleWithRetry` / `_callTitleLlm` / `_collectTranscriptForTitle` 业务逻辑到 `AutoTitleController.runIfNeeded` | `auto_title_controller.dart` + `chat_screen.dart` | 修改 | 1 |
| 3 | `runIfNeeded` 完成后调 `themeDetailControllerProvider(themeId).notifier).refresh()` | `auto_title_controller.dart` | 修改 | 2 |
| 4 | `runIfNeeded` 加守卫：写 DB 前查 DB title 兜底用户手动改名 | `auto_title_controller.dart` | 修改 | 2 |
| 5 | `chat_screen.dart` 删除 4 个 `_` 私有方法 | `chat_screen.dart` | 修改 | 1 |
| 6 | `chat_screen.dart` 替换 build 边沿检测触发逻辑 + 加 `ref.listen` 同步 `_displayedTitle` | `chat_screen.dart` | 修改 | 5 |
| 7 | 编译验证 + `flutter analyze` | 全部 | 验证 | 1-6 |
| 8 | 集成测试新增 case 9.5（基础流程：tree 刷新 + 第二次进入） | `integration_test/branch_creation_test.dart` | 新增 | 1-7 |
| 9 | 集成测试新增 case 9.6（提前 pop：后台任务仍跑完） | `integration_test/branch_creation_test.dart` | 新增 | 8 |
| 10 | 集成测试激活 case 9.4（用户手动改 title 守卫） | `integration_test/branch_creation_test.dart` | 修改 | 1-7 |
| 11 | 跑所有集成测试（回归保护） | 全部 | 验证 | 8-10 |
| 12 | 写 changelog | `docs/CHANGELOG/` | 新增 | 7 |
| 13 | commit（由用户执行） | — | 用户执行 | 11-12 |

---

## 📁 文件结构

| 状态 | 路径 | 职责 |
|------|------|------|
| 新增 | `lib/ui/features/chat/auto_title_controller.dart` | Notifier：任务生命周期管理 + LLM 调用 + DB 写 + tree 刷新 |
| 修改 | `lib/ui/features/chat/chat_screen.dart` | 删除 4 个私有方法；改边沿检测触发逻辑；加 `ref.listen` |
| 修改 | `integration_test/branch_creation_test.dart` | 新增 case 9.5/9.6；激活 case 9.4 |
| 新增 | `docs/CHANGELOG/2026-06-29-auto-title-persistence.md` | 修复 changelog |

> **位置说明：** `AutoTitleController` 放 `lib/ui/features/chat/`（与 `chat_controller.dart` 同级），因为它是 Riverpod Notifier 且与 chat_screen 紧耦合。`chat_task_service.dart` 在 `lib/data/services/` 放的是无 widget 依赖的服务；本任务不同——它需要 `ref.listen` widget UI（弹 `showLlmSetupAlert`），放在 chat 目录更合理。

---

## 📋 任务详细说明

---

### 任务 1：新增 `AutoTitleController` Notifier + state 骨架

**文件：** `lib/ui/features/chat/auto_title_controller.dart`（**新建**）

**完整文件内容：**

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/data/services/title_suggestion_service.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/shared/llm_setup_check.dart';
import 'package:thk_tree/ui/features/chat/chat_controller.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';

/// 自动 title 生成任务的状态。
///
/// 状态机：
///   idle → running → done   （成功）
///   idle → running → failed （模型未配置 / LLM 失败）
class AutoTitleState {
  const AutoTitleState({
    required this.status,
    this.newTitle,
    this.error,
  });

  final AutoTitleStatus status;
  final String? newTitle;
  final Object? error;

  static const initial = AutoTitleState(status: AutoTitleStatus.idle);

  AutoTitleState copyWith({
    AutoTitleStatus? status,
    String? newTitle,
    Object? error,
  }) {
    return AutoTitleState(
      status: status ?? this.status,
      newTitle: newTitle ?? this.newTitle,
      error: error ?? this.error,
    );
  }
}

enum AutoTitleStatus { idle, running, done, failed }

/// 空白分支（A 模式）后置自动 title 生成的 Notifier。
///
/// 设计要点：
/// 1. **以 nodeId 为 family key** —— 同一 node 多次进入 chat_screen 共享同一 Notifier 实例（autoDispose 范围内）
/// 2. **任务与 widget 解耦** —— `runIfNeeded` 内部所有 `ref.read` 都用 Notifier 自己的 ref，
///    widget dispose 后（autoDispose 触发前）任务仍能继续执行
/// 3. **完成后调 `themeDetailControllerProvider(themeId).notifier).refresh()`** —
///    不论 widget 是否 mounted 都会触发 tree 刷新
/// 4. **写 DB 前查 DB title 兜底** —— 用户手动改 title 不会被 LLM 覆盖
class AutoTitleController extends AutoDisposeFamilyAsyncNotifier<AutoTitleState, String> {
  AutoTitleController(this.nodeId);

  final String nodeId;

  @override
  Future<AutoTitleState> build() async {
    // 不需要预加载数据，初始即为 idle
    return AutoTitleState.initial;
  }

  /// 占位 title 判读 + 启动 LLM 调用（幂等）。
  ///
  /// 调用方（chat_screen build 边沿检测）保证只触发一次，
  /// 但本方法内部仍做双重去重：
  ///   - state.status != idle → return
  ///   - currentTitle != placeholder → return
  ///   - 写 DB 前查 DB title → 用户手动改过则跳过
  Future<void> runIfNeeded({
    required String themeId,
    required String currentTitle,
    required String transcript,
    required String placeholder,
  }) async {
    // 守卫 1：去重
    if (state.value?.status != AutoTitleStatus.idle) return;

    // 守卫 2：title 已被改过
    if (currentTitle != placeholder) {
      state = AsyncData(state.value!.copyWith(status: AutoTitleStatus.done, newTitle: currentTitle));
      return;
    }

    // 守卫 3：查 DB title 兜底（用户可能在 LLM 启动前手动改了 DB）
    try {
      final nodeStore = await ref.read(nodeStoreProvider.future);
      final row = await nodeStore.getNodeRow(nodeId: nodeId);
      final dbTitle = row['title'] as String?;
      if (dbTitle != null && dbTitle != placeholder) {
        debugPrint('[AutoTitle] nodeId=$nodeId DB title 已被改 ($dbTitle), 跳过');
        state = AsyncData(AutoTitleState(status: AutoTitleStatus.done, newTitle: dbTitle));
        return;
      }
    } catch (e, st) {
      debugPrint('[AutoTitle] 查 DB title 失败（继续走 LLM 流程）: $e\n$st');
    }

    state = const AsyncData(AutoTitleState(status: AutoTitleStatus.running));

    try {
      final settings = ref.read(settingsControllerProvider).value;
      final providers = ref.read(llmProvidersProvider).value ?? const <LlmProviderConfig>[];

      // 解析 model
      final resolved = await resolveModelForTitle(
        ref,
        providers,
        currentProviderId: settings?.chatDefaultProviderId,
        currentModelId: settings?.chatDefaultModelId,
      );
      if (resolved == null) {
        state = const AsyncData(AutoTitleState(status: AutoTitleStatus.failed, error: 'noModel'));
        return;
      }
      final (provider, modelId, apiKey) = resolved;

      final contextWindow = _resolveContextWindow(
        settings?.chatDefaultProviderId,
        settings?.chatDefaultModelId,
      );
      final newTitle = await _generateTitleWithRetry(
        provider: provider,
        modelId: modelId,
        apiKey: apiKey,
        contextWindow: contextWindow,
        transcript: transcript,
      );

      if (newTitle == null || newTitle.trim().isEmpty) {
        state = const AsyncData(AutoTitleState(status: AutoTitleStatus.failed, error: 'empty'));
        return;
      }

      final trimmed = newTitle.trim();

      // 写 DB（disk-first）
      try {
        final nodeStore = await ref.read(nodeStoreProvider.future);
        await nodeStore.updateNodeTitle(nodeId: nodeId, newTitle: trimmed);
      } catch (e, st) {
        debugPrint('[AutoTitle] updateNodeTitle 失败: $e\n$st');
        state = AsyncData(AutoTitleState(status: AutoTitleStatus.failed, error: e));
        return;
      }

      // 刷新 tree controller（widget dispose 后仍能跑）
      try {
        await ref.read(themeDetailControllerProvider(themeId).notifier).refresh();
      } catch (e, st) {
        debugPrint('[AutoTitle] themeDetailController.refresh 失败（下次进入 tree 会重新加载）: $e\n$st');
      }

      state = AsyncData(AutoTitleState(status: AutoTitleStatus.done, newTitle: trimmed));
    } catch (e, st) {
      debugPrint('[AutoTitle] FAILED nodeId=$nodeId: $e\n$st');
      state = AsyncData(AutoTitleState(status: AutoTitleStatus.failed, error: e));
    }
  }

  /// 调 LLM 生成 title，带 3 次重试 + 指数退避 1s/2s/4s。
  Future<String?> _generateTitleWithRetry({
    required LlmProviderConfig provider,
    required String modelId,
    required String apiKey,
    required int contextWindow,
    required String transcript,
  }) async {
    const maxAttempts = 3;
    String? lastError;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final title = await _callTitleLlm(
          provider: provider,
          modelId: modelId,
          apiKey: apiKey,
          contextWindow: contextWindow,
          transcript: transcript,
        );
        if (title != null && title.trim().isNotEmpty) return title.trim();
      } catch (e) {
        lastError = e.toString();
        debugPrint('[AutoTitle] attempt ${attempt + 1} failed: $e');
      }
      if (attempt < maxAttempts - 1) {
        await Future<void>.delayed(Duration(seconds: 1 << attempt)); // 1s / 2s / 4s
      }
    }

    if (lastError != null) {
      debugPrint('[AutoTitle] all $maxAttempts attempts failed, last error: $lastError');
    }
    return null;
  }

  /// 调一次 LLM 生成 title（不带重试）。
  Future<String?> _callTitleLlm({
    required LlmProviderConfig provider,
    required String modelId,
    required String apiKey,
    required int contextWindow,
    required String transcript,
  }) async {
    if (transcript.trim().isEmpty) return null;
    final candidates = await TitleSuggestionService.generateTitles(
      content: transcript,
      direction: null,
      provider: provider,
      modelId: modelId,
      apiKey: apiKey,
      contextWindow: contextWindow,
    );
    return candidates.isEmpty ? null : candidates.first;
  }

  int _resolveContextWindow(String? providerId, String? modelId) {
    if (providerId != null && modelId != null) {
      final providers = ref.read(llmProvidersProvider).value;
      if (providers != null) {
        final provider = providers.where((p) => p.id == providerId).firstOrNull;
        if (provider != null) {
          final model = provider.models.where((m) => m.id == modelId).firstOrNull;
          if (model != null) return model.contextWindow;
        }
      }
    }
    final settings = ref.read(settingsControllerProvider).value;
    return settings?.llmProvider.contextWindowTokens ?? 64000;
  }
}

final autoTitleControllerProvider =
    AsyncNotifierProvider.autoDispose.family<AutoTitleController, AutoTitleState, String>(
  AutoTitleController.new,
);
```

**关键实现细节：**

1. **`AutoDisposeFamilyAsyncNotifier`** —— 与 `themeDetailControllerProvider` 一致的范式。`autoDispose` 触发条件是"无 listener"，所以 chat_screen push 后仍保留 listener，pop 回来时 Notifier 仍在内存中
2. **Provider 引用 Notifier 自己** —— 任务跑完后调 `ref.read(themeDetailControllerProvider(themeId).notifier).refresh()`，**不依赖 widget 的 ref**
3. **state 在 done 之前是 `AsyncData<AutoTitleState>`** —— 简化读法（state.value 直接拿 AutoTitleState）
4. **失败静默** —— LLM 失败 / 写失败 / refresh 失败都只 debugPrint，不抛异常

**验收：**
- [ ] 文件创建在 `lib/ui/features/chat/auto_title_controller.dart`
- [ ] 4 个公开类型：`AutoTitleState` / `AutoTitleStatus` / `AutoTitleController` / `autoTitleControllerProvider`
- [ ] 1 个公开方法：`runIfNeeded`
- [ ] 3 个 private helper：`_generateTitleWithRetry` / `_callTitleLlm` / `_resolveContextWindow`
- [ ] `flutter analyze` 无新增 error

---

### 任务 2：迁移 chat_screen 业务逻辑到 AutoTitleController

**文件：** `lib/ui/features/chat/chat_screen.dart`

**改动点：** 任务 1 已完成 `runIfNeeded` 全部业务逻辑，本任务主要是**验证**以下原 chat_screen 中的代码已**完整迁移**到 AutoTitleController：

| 原 chat_screen 方法 | 行号 | 迁移到 |
|---------------------|------|--------|
| `_triggerBlankAutoTitle` | 473-535 | `AutoTitleController.runIfNeeded`（任务 1 步骤 2-4 内已含） |
| `_generateTitleWithRetry` | 558-593 | `AutoTitleController._generateTitleWithRetry` |
| `_callTitleLlm` | 595-616 | `AutoTitleController._callTitleLlm` |
| `_collectTranscriptForTitle` | 537-556 | **保留**在 chat_screen（任务 6 仍要读 chatControllerProvider state） |
| `_resolveContextWindow` | 88-105 | `AutoTitleController._resolveContextWindow`（与 chat_screen 内部的同名 private 方法功能重复，可保留 chat_screen 的，因其 UI 业务可能也用） |

**注意：**
- `resolveModelForTitle` 调用从 `container` 改为 `ref`（Notifier 自己的 ref）
- `nodeStore.updateNodeTitle` 调用从 `container.read(nodeStoreProvider.future)` 改为 `ref.read(nodeStoreProvider.future)`
- `showLlmSetupAlert` **不**在 `runIfNeeded` 内调用（Notifer 不应依赖 widget BuildContext）；改由 widget 通过 `ref.listen` 监听 `failed + error=='noModel'` 状态后弹 alert（详见任务 6）

**验收：**
- [ ] 业务逻辑 100% 迁移到 `AutoTitleController`
- [ ] `chat_screen.dart` 的 `_triggerBlankAutoTitle` / `_generateTitleWithRetry` / `_callTitleLlm` 仍在文件里（任务 5 才会删）

---

### 任务 3：runIfNeeded 完成后调 `themeDetailController.refresh()`

**文件：** `lib/ui/features/chat/auto_title_controller.dart`

**说明：** 任务 1 的 `runIfNeeded` 实现已包含 `ref.read(themeDetailControllerProvider(themeId).notifier).refresh()` 调用，本任务为**验证**步骤。

**验证要点：**

```dart
// 任务 1 runIfNeeded 内部（已实现），关键行：
try {
  await ref.read(themeDetailControllerProvider(themeId).notifier).refresh();
} catch (e, st) {
  debugPrint('[AutoTitle] themeDetailController.refresh 失败（下次进入 tree 会重新加载）: $e\n$st');
}
```

**关键设计决策**：
- **为什么 refresh 而不是 invalidate**：`refresh()` 立即触发 `_load()` 并 `state = AsyncData(...)`，让在 tree 页面停留的用户能实时看到 title 变化
- **为什么 catch 错误不抛**：refresh 失败时 DB 已写成功，下次进入 tree（autoDispose 重新 build）一定能读到新 title
- **为什么不用 watch `themeDetailControllerProvider`**：避免 Notifier 依赖关系成环

**验收：**
- [ ] `runIfNeeded` 写 DB 后无条件调 `themeDetailController.refresh()`（try/catch 包住）
- [ ] 即使 widget dispose（chat_screen 提前 pop），refresh 仍能跑（Notifier 自己的 ref）

---

### 任务 4：runIfNeeded 加守卫（写 DB 前查 DB title 兜底）

**文件：** `lib/ui/features/chat/auto_title_controller.dart`

**说明：** 任务 1 的 `runIfNeeded` 实现已包含"守卫 3：查 DB title"，本任务为**验证**步骤。

**验证要点：**

```dart
// 任务 1 runIfNeeded 内部（已实现），关键行：
try {
  final nodeStore = await ref.read(nodeStoreProvider.future);
  final row = await nodeStore.getNodeRow(nodeId: nodeId);
  final dbTitle = row['title'] as String?;
  if (dbTitle != null && dbTitle != placeholder) {
    debugPrint('[AutoTitle] nodeId=$nodeId DB title 已被改 ($dbTitle), 跳过');
    state = AsyncData(AutoTitleState(status: AutoTitleStatus.done, newTitle: dbTitle));
    return;
  }
} catch (e, st) {
  debugPrint('[AutoTitle] 查 DB title 失败（继续走 LLM 流程）: $e\n$st');
}
```

**为什么需要这个守卫：**
- 现有 chat_screen 实现（行 478-479）只查 `_displayedTitle` / `widget.title` 局部变量，**不查 DB**
- 用户可能在 LLM 启动前手动改了 DB title（如通过 node rename 功能），但 UI 上 widget.title 没变（widget 构造时拿的是旧值）
- 现在的实现会**覆盖**用户手动改的 title —— bug
- 任务 4 的守卫修这个 bug

**验收：**
- [ ] `runIfNeeded` 写 DB 前查 `nodeStore.getNodeRow(nodeId).title`
- [ ] DB title 已被改成非占位值 → 跳过 LLM 流程，state = done(dbTitle)
- [ ] 这一步失败（DB 异常）→ debugPrint 后继续走 LLM（不阻断流程）
- [ ] **同时激活 case 9.4 skip 状态**（任务 10）

---

### 任务 5：chat_screen 删除 4 个 `_` 私有方法

**文件：** `lib/ui/features/chat/chat_screen.dart`

**改动点：**

| 方法 | 行号 | 处理 |
|------|------|------|
| `_triggerBlankAutoTitle` | 473-535 | **删除**（逻辑已迁） |
| `_generateTitleWithRetry` | 558-593 | **删除**（逻辑已迁） |
| `_callTitleLlm` | 595-616 | **删除**（逻辑已迁） |
| `_collectTranscriptForTitle` | 537-556 | **保留**（widget 内读 chatControllerProvider state 方便） |

**`_resolveContextWindow` 处理：**
- chat_screen 行 88-105 的 `_resolveContextWindow` 用于显示 context usage bar（`_ContextUsageBar`）
- UI 展示仍需，故**保留**
- AutoTitleController 内的同名方法（任务 1）是 Notifier 自己用的副本，**与 widget 内部实现重复但无依赖关系**

**验收：**
- [ ] chat_screen.dart 删除上述 3 个方法（行 473-535 / 558-593 / 595-616）
- [ ] `_collectTranscriptForTitle` 保留
- [ ] `_resolveContextWindow` 保留
- [ ] `flutter analyze` 无 unused import 警告

---

### 任务 6：chat_screen 替换 build 边沿检测触发逻辑 + 加 `ref.listen`

**文件：** `lib/ui/features/chat/chat_screen.dart`

**改动点 1：** 删除 line 52-58 的 3 个 `_autoTitleTriggered` / `_wasStreaming` / `_displayedTitle` 字段的注释，保留字段声明

**改动点 2：** 替换 build 中的边沿检测触发逻辑（原 line 126-137）

**原代码：**
```dart
// 空白分支（A 模式）后置自动 title 生成：检测 isStreaming true → false 边沿。
// 仅当当前 nav bar 显示的还是占位 title 时才触发；已调过一次后永久防抖。
if (_wasStreaming && !isStreaming && !_autoTitleTriggered) {
  final placeholder = l10n.branchBlankInitialTitle;
  if (_displayedTitle == placeholder || widget.title == placeholder) {
    _autoTitleTriggered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerBlankAutoTitle();
    });
  }
}
_wasStreaming = isStreaming;
```

**替换为：**
```dart
// 空白分支（A 模式）后置自动 title 生成：检测 isStreaming true → false 边沿。
// 仅当当前 nav bar 显示的还是占位 title 时才触发；已调过一次后永久防抖。
// 任务从 widget 抽到 AutoTitleController，widget dispose 后任务仍能继续。
if (_wasStreaming && !isStreaming && !_autoTitleTriggered) {
  final placeholder = l10n.branchBlankInitialTitle;
  if (_displayedTitle == placeholder || widget.title == placeholder) {
    _autoTitleTriggered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final container = ProviderScope.containerOf(context, listen: false);
      container.read(autoTitleControllerProvider(widget.nodeId).notifier).runIfNeeded(
        themeId: widget.themeId,
        currentTitle: _displayedTitle ?? widget.title,
        transcript: _collectTranscriptForTitle(),
        placeholder: placeholder,
      );
    });
  }
}
_wasStreaming = isStreaming;
```

**改动点 3：** 在 build 顶部加 `ref.listen` 同步 `_displayedTitle`（原行 117-118 附近）：

```dart
@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;

  // 监听 auto title 任务结果，更新本地 _displayedTitle 缓存
  ref.listen<AsyncValue<AutoTitleState>>(
    autoTitleControllerProvider(widget.nodeId),
    (prev, next) {
      final s = next.value;
      if (s == null) return;
      if (s.status == AutoTitleStatus.done && s.newTitle != null) {
        if (_displayedTitle != s.newTitle) {
          setState(() {
            _displayedTitle = s.newTitle;
          });
        }
      } else if (s.status == AutoTitleStatus.failed && s.error == 'noModel') {
        // 模型未配置 → 弹引导 alert（仅 widget mounted 时）
        showLlmSetupAlert(
          context: context,
          status: LlmSetupStatus.noTitleModelConfigured,
          container: ProviderScope.containerOf(context, listen: false),
        );
      }
    },
  );

  // ↓ 原有 build 逻辑不变
  final messagesAsync = ref.watch(chatControllerProvider(_args));
  // ...
}
```

**改动点 4：** import 加 `auto_title_controller.dart`：

```dart
import 'package:thk_tree/ui/features/chat/auto_title_controller.dart';
```

**验收：**
- [ ] 触发逻辑改为调 `autoTitleControllerProvider(widget.nodeId).notifier.runIfNeeded(...)`
- [ ] 加 `ref.listen<AsyncValue<AutoTitleState>>` 同步 `_displayedTitle`
- [ ] `failed + error=='noModel'` 时弹 `showLlmSetupAlert`
- [ ] import 新增 `auto_title_controller.dart`
- [ ] `_autoTitleTriggered` / `_wasStreaming` / `_displayedTitle` 字段保留
- [ ] 边沿检测条件不变（仍是 `_wasStreaming && !isStreaming && !_autoTitleTriggered`）
- [ ] 现有 widget 流程（chatTaskStateProvider / composer / branch button / model panel）行为不变

---

### 任务 7：编译验证 + flutter analyze

**命令：**
```bash
cd /Users/yuweikang/dev/ykcode/ThkTree
flutter analyze
```

**预期结果：**
- 无新增 error
- 现有 warning 数量不变（baseline: `flutter analyze` baseline）

**编译验证（如有需要）：**
```bash
flutter build ios --simulator --no-codesign
```

**验收：**
- [ ] `flutter analyze` 无新增 error
- [ ] 无 unused import / unused field 警告

---

### 任务 8：集成测试新增 case 9.5（基础流程：tree 刷新 + 第二次进入）

**文件：** `integration_test/branch_creation_test.dart`

**插入位置：** 在 `case 9.3`（行 906-1039）之后、`case 9.4`（行 1041-1054）之前

**新 case 内容：**

```dart
testWidgets('A 模式：自动 title 持久化（tree 刷新 + 第二次进入显示新 title）', (tester) async {
  // ── 1. 注入 LLM fixture ──
  final llmConfig = LlmTestConfig.loadFromDefine();
  final baseSettings = llmConfig.toAppSettings();
  final titleSettings = baseSettings.copyWith(
    titleModelProviderId: _presetIdFor(llmConfig.activeProvider),
    titleModelModelId: baseSettings.deepSeekModel,
  );
  final app = await createTestApp(
    locale: const Locale('zh'),
    llmSettings: titleSettings,
    llmConfigStore: llmConfig.toLlmConfigStore(),
  );
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();

  // ── 2. 准备 parent + blank branch ──
  await _switchToTab(tester, '主题');
  await tester.pumpAndSettle();
  final ts = DateTime.now().millisecondsSinceEpoch;
  final themeName = 'BlankPersist_$ts';
  final parentName = 'ParentPersist_$ts';
  await _createTestTheme(tester, themeName);
  await waitForText(tester, themeName, timeout: const Duration(seconds: 10));
  await tester.tap(find.text(themeName));
  await tester.pumpAndSettle();
  await _createTestNode(tester, parentName);
  await waitForText(tester, parentName, timeout: const Duration(seconds: 10));
  await tester.tap(find.text(parentName));
  await tester.pumpAndSettle();
  await waitForWidget(
    tester,
    find.byKey(const ValueKey('chat_input')),
    timeout: const Duration(seconds: 10),
  );
  await _sendAndWaitForReply(
    tester,
    message: '你好',
    timeout: const Duration(seconds: 90),
  );
  await tester.pump(const Duration(seconds: 2));
  final branchBtn = find.byKey(const ValueKey('branch_button'));
  expect(branchBtn, findsOneWidget);
  await tester.tap(branchBtn);
  await tester.pumpAndSettle();
  await waitForWidget(
    tester,
    find.byKey(const ValueKey('branch_mode_blank_option')),
    timeout: const Duration(seconds: 10),
  );
  await tester.tap(find.byKey(const ValueKey('branch_mode_blank_option')));
  await tester.pumpAndSettle();
  await waitForWidget(
    tester,
    find.byKey(const ValueKey('chat_input')),
    timeout: const Duration(seconds: 30),
  );
  await tester.pump(const Duration(seconds: 2));

  // ── 3. 拿 blank nodeId ──
  final container = ProviderScope.containerOf(
    tester.element(find.byType(CupertinoApp)),
    listen: false,
  );
  final nodeStore = await container.read(nodeStoreProvider.future);
  final themeRows = await nodeStore.db.query(
    'themes',
    columns: ['themeId'],
    where: 'themeId IN (SELECT themeId FROM nodes WHERE title = ?)',
    whereArgs: [parentName],
    limit: 1,
  );
  final themeId = themeRows.first['themeId']! as String;
  final allNodes = await nodeStore.listNodes(themeId: themeId);
  final blankNode = allNodes
      .where((n) => n.sourceType == 'userIdea')
      .lastOrNull;
  expect(blankNode, isNotNull, reason: '应能找到 blank node');
  final blankNodeId = blankNode!.nodeId;
  final initialTitle = blankNode.title;
  debugPrint('[Test 9.5] blank nodeId=$blankNodeId, 初始 title=$initialTitle');
  expect(initialTitle, equals('临时会话'), reason: '初始 title 应该是占位 "临时会话"');

  // ── 4. 在新 chat_screen 发消息 → 流式完成 ──
  await _sendAndWaitForReply(
    tester,
    message: '数字化品牌的视觉逻辑',
    timeout: const Duration(seconds: 90),
  );
  debugPrint('[Test 9.5] 流式回复完成, 等待自动 title 触发...');

  // ── 5. 轮询 DB 等 auto title 被更新（最长 60s） ──
  String? updatedTitle;
  for (var i = 0; i < 60; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
    await tester.pump();
    final row = await nodeStore.db.query(
      'nodes',
      columns: ['title'],
      where: 'nodeId = ?',
      whereArgs: [blankNodeId],
      limit: 1,
    );
    if (row.isNotEmpty) {
      final t = row.first['title']! as String;
      if (t != '临时会话' && t.trim().isNotEmpty) {
        updatedTitle = t;
        debugPrint('[Test 9.5] DB 自动 title 已更新: $updatedTitle (${i}s)');
        break;
      }
    }
    if (i % 10 == 0 && i > 0) {
      debugPrint('[Test 9.5] 等待自动 title... ${i}s');
    }
  }
  expect(updatedTitle, isNotNull, reason: '流式结束后 60s 内 LLM 应自动生成新 title');

  // ── 6. 关键断言 1：DB title 是新值 ──
  expect(updatedTitle, isNot(equals('临时会话')), reason: 'DB title 应被自动更新');

  // ── 7. 关键断言 2：tree controller state 已刷新 ──
  // 等 2s 让 refresh() 跑完
  await tester.pump(const Duration(seconds: 2));
  final themeCtrl = container.read(themeDetailControllerProvider(themeId));
  final treeState = themeCtrl.value;
  expect(treeState, isNotNull, reason: 'tree controller state 应已加载');
  final treeNode = treeState!.nodes.where((n) => n.nodeId == blankNodeId).firstOrNull;
  expect(treeNode, isNotNull, reason: 'tree 应包含 blank node');
  expect(treeNode!.title, equals(updatedTitle),
      reason: 'tree 中该 node 的 title 应被刷新为 LLM 生成的新 title');
  debugPrint('[Test 9.5] ✅ tree 已刷新: ${treeNode.title}');

  // ── 8. 关键断言 3：第二次进入 chat_screen 时 nav bar 仍是新 title ──
  // 找到 tree 中的 blank node 位置
  final blankNodeTextInTree = find.text(updatedTitle);
  expect(blankNodeTextInTree, findsWidgets,
      reason: 'tree 中应能找到新 title 的 node');
  await tester.tap(blankNodeTextInTree.first);
  await tester.pumpAndSettle();
  await waitForWidget(
    tester,
    find.byKey(const ValueKey('chat_input')),
    timeout: const Duration(seconds: 30),
  );
  // nav bar 标题（在 app bar 中）应该是新 title
  final navBarTitleFinder = find.text(updatedTitle);
  expect(navBarTitleFinder, findsWidgets,
      reason: 'nav bar 应显示 LLM 生成的新 title，不是"临时会话"');
  debugPrint('[Test 9.5] ✅ 第二次进入 chat_screen nav bar title 正确: $updatedTitle');

  debugPrint('[Test 9.5] ✅ case 9.5 完成: 自动 title 已持久化');
}, timeout: const Timeout(Duration(minutes: 6)));
```

**关键设计：**
- **断言 1（DB）**：DB title 已被 LLM 更新
- **断言 2（tree state）**：themeDetailControllerProvider 的 state.nodes 中该 node 的 title 已是新值（**核心 bug 修复点**）
- **断言 3（UI）**：第二次进入 chat_screen，nav bar 是新 title（**用户体验修复点**）

**验收：**
- [ ] 测试在 `case 9.4` 之前插入
- [ ] 3 个核心断言：DB / tree state / nav bar
- [ ] 测试通过

---

### 任务 9：集成测试新增 case 9.6（提前 pop：后台任务仍跑完）

**文件：** `integration_test/branch_creation_test.dart`

**插入位置：** 在 `case 9.5` 之后、`case 9.4` 之前

**新 case 内容：**

```dart
testWidgets('A 模式：提前 pop chat 后后台 title 任务仍能跑完', (tester) async {
  // ── 1. 注入 LLM fixture ──
  final llmConfig = LlmTestConfig.loadFromDefine();
  final baseSettings = llmConfig.toAppSettings();
  final titleSettings = baseSettings.copyWith(
    titleModelProviderId: _presetIdFor(llmConfig.activeProvider),
    titleModelModelId: baseSettings.deepSeekModel,
  );
  final app = await createTestApp(
    locale: const Locale('zh'),
    llmSettings: titleSettings,
    llmConfigStore: llmConfig.toLlmConfigStore(),
  );
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();

  // ── 2. 准备 parent + blank branch（同 9.5 步骤） ──
  await _switchToTab(tester, '主题');
  await tester.pumpAndSettle();
  final ts = DateTime.now().millisecondsSinceEpoch;
  final themeName = 'BlankEarlyPop_$ts';
  final parentName = 'ParentEarlyPop_$ts';
  await _createTestTheme(tester, themeName);
  await waitForText(tester, themeName, timeout: const Duration(seconds: 10));
  await tester.tap(find.text(themeName));
  await tester.pumpAndSettle();
  await _createTestNode(tester, parentName);
  await waitForText(tester, parentName, timeout: const Duration(seconds: 10));
  await tester.tap(find.text(parentName));
  await tester.pumpAndSettle();
  await waitForWidget(
    tester,
    find.byKey(const ValueKey('chat_input')),
    timeout: const Duration(seconds: 10),
  );
  await _sendAndWaitForReply(
    tester,
    message: '你好',
    timeout: const Duration(seconds: 90),
  );
  await tester.pump(const Duration(seconds: 2));
  final branchBtn = find.byKey(const ValueKey('branch_button'));
  expect(branchBtn, findsOneWidget);
  await tester.tap(branchBtn);
  await tester.pumpAndSettle();
  await waitForWidget(
    tester,
    find.byKey(const ValueKey('branch_mode_blank_option')),
    timeout: const Duration(seconds: 10),
  );
  await tester.tap(find.byKey(const ValueKey('branch_mode_blank_option')));
  await tester.pumpAndSettle();
  await waitForWidget(
    tester,
    find.byKey(const ValueKey('chat_input')),
    timeout: const Duration(seconds: 30),
  );
  await tester.pump(const Duration(seconds: 2));

  // ── 3. 拿 blank nodeId ──
  final container = ProviderScope.containerOf(
    tester.element(find.byType(CupertinoApp)),
    listen: false,
  );
  final nodeStore = await container.read(nodeStoreProvider.future);
  final themeRows = await nodeStore.db.query(
    'themes',
    columns: ['themeId'],
    where: 'themeId IN (SELECT themeId FROM nodes WHERE title = ?)',
    whereArgs: [parentName],
    limit: 1,
  );
  final themeId = themeRows.first['themeId']! as String;
  final allNodes = await nodeStore.listNodes(themeId: themeId);
  final blankNode = allNodes
      .where((n) => n.sourceType == 'userIdea')
      .lastOrNull;
  expect(blankNode, isNotNull, reason: '应能找到 blank node');
  final blankNodeId = blankNode!.nodeId;
  debugPrint('[Test 9.6] blank nodeId=$blankNodeId, 初始 title=${blankNode.title}');

  // ── 4. 在新 chat_screen 发消息 → 流式刚启动就 pop 回 tree ──
  final chatInput = find.byKey(const ValueKey('chat_input'));
  expect(chatInput, findsOneWidget);
  await tester.enterText(chatInput, '请帮我分析品牌视觉');
  await tester.pump();
  final sendBtn = find.byKey(const ValueKey('send_button'));
  expect(sendBtn, findsOneWidget);
  await tester.tap(sendBtn);
  await tester.pump();

  // 等待 stop_button 出现（流式已启动）
  final stopFinder = find.byKey(const ValueKey('stop_button'));
  final sw = Stopwatch()..start();
  while (stopFinder.evaluate().isEmpty) {
    if (sw.elapsed > const Duration(seconds: 10)) {
      fail('发送消息后 10s 内未进入流式状态');
    }
    await tester.pump(const Duration(milliseconds: 500));
  }
  debugPrint('[Test 9.6] 流式已启动，立即 pop 回 tree');

  // ★ 关键：不等流式结束，立刻 pop 回 tree
  // 找 back 按钮（NavBar 第一个按钮）
  // 这里用 Navigator.maybePop 更稳
  Navigator.of(tester.element(find.byType(CupertinoApp))).pop();
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 2));

  // 验证：当前在 tree 页面（看到 parent node + 占位 "临时会话"）
  expect(find.text('临时会话'), findsWidgets,
      reason: 'pop 回 tree 后，DB title 仍是占位（LLM 还在跑）');

  // ── 5. 轮询 DB 等 auto title 被更新（最长 90s，给足时间） ──
  String? updatedTitle;
  for (var i = 0; i < 90; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
    await tester.pump();
    final row = await nodeStore.db.query(
      'nodes',
      columns: ['title'],
      where: 'nodeId = ?',
      whereArgs: [blankNodeId],
      limit: 1,
    );
    if (row.isNotEmpty) {
      final t = row.first['title']! as String;
      if (t != '临时会话' && t.trim().isNotEmpty) {
        updatedTitle = t;
        debugPrint('[Test 9.6] 提前 pop 后 DB 仍被后台任务更新: $updatedTitle (${i}s)');
        break;
      }
    }
    if (i % 10 == 0 && i > 0) {
      debugPrint('[Test 9.6] 等待后台 title 任务... ${i}s');
    }
  }

  // ── 6. 关键断言：DB 仍被更新（widget dispose 后任务没被取消） ──
  expect(updatedTitle, isNotNull,
      reason: '提前 pop 后，后台 LLM 任务应仍能跑完并写 DB');
  expect(updatedTitle, isNot(equals('临时会话')),
      reason: 'DB title 仍应被自动更新');
  debugPrint('[Test 9.6] ✅ case 9.6 完成: 后台任务已持久化 title=$updatedTitle');
}, timeout: const Timeout(Duration(minutes: 7)));
```

**关键设计：**
- **流式刚启动就 pop** —— 不等 LLM 流式结束
- **DB 仍被更新** —— 验证 Notifier 的 `runIfNeeded` 与 widget 解耦
- **超时 90s** —— 给 LLM 重试 + 写 DB 留足时间

**验收：**
- [ ] 测试在 `case 9.5` 之后插入
- [ ] 提前 pop 后 DB 仍被更新
- [ ] 测试通过

---

### 任务 10：集成测试激活 case 9.4（用户手动改 title 守卫）

**文件：** `integration_test/branch_creation_test.dart`

**改动点：** 行 1041-1054 现有 skip 状态解除

**原代码：**
```dart
testWidgets(
    'A 模式：用户预改 title 后跳过自动生成（plan § 9.4 - 当前实现有差距）',
    (tester) async {
  // ⚠️ plan § 9.4 与当前实现有差距：
  //   - plan 期望：用户手动改 title 后, 流式结束时不触发自动 title 生成
  //   - 实际实现：_triggerBlankAutoTitle 守卫只查 _displayedTitle / widget.title
  //     (chat_screen.dart:448), 不查 DB title
  //   - 后果: 预改 DB title 但 UI 没改, LLM 仍会覆盖
  //   - 本测试标 skip 直到后续 PR 补齐守卫的 DB check
  debugPrint(
      '[Test 9.4] SKIP: 当前实现仅 _displayedTitle / widget.title 守卫, '
      '不查 DB title, plan § 9.4 需后续 PR 补齐');
},
    skip: true);
```

**替换为（移除 skip，加真实测试）：**

```dart
testWidgets('A 模式：用户预改 title 后跳过自动生成', (tester) async {
  // ── 1. 注入 LLM fixture ──
  final llmConfig = LlmTestConfig.loadFromDefine();
  final baseSettings = llmConfig.toAppSettings();
  final titleSettings = baseSettings.copyWith(
    titleModelProviderId: _presetIdFor(llmConfig.activeProvider),
    titleModelModelId: baseSettings.deepSeekModel,
  );
  final app = await createTestApp(
    locale: const Locale('zh'),
    llmSettings: titleSettings,
    llmConfigStore: llmConfig.toLlmConfigStore(),
  );
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();

  // ── 2. 准备 parent + blank branch ──
  await _switchToTab(tester, '主题');
  await tester.pumpAndSettle();
  final ts = DateTime.now().millisecondsSinceEpoch;
  final themeName = 'BlankManualTitle_$ts';
  final parentName = 'ParentManualTitle_$ts';
  await _createTestTheme(tester, themeName);
  await waitForText(tester, themeName, timeout: const Duration(seconds: 10));
  await tester.tap(find.text(themeName));
  await tester.pumpAndSettle();
  await _createTestNode(tester, parentName);
  await waitForText(tester, parentName, timeout: const Duration(seconds: 10));
  await tester.tap(find.text(parentName));
  await tester.pumpAndSettle();
  await waitForWidget(
    tester,
    find.byKey(const ValueKey('chat_input')),
    timeout: const Duration(seconds: 10),
  );
  await _sendAndWaitForReply(
    tester,
    message: '你好',
    timeout: const Duration(seconds: 90),
  );
  await tester.pump(const Duration(seconds: 2));
  final branchBtn = find.byKey(const ValueKey('branch_button'));
  expect(branchBtn, findsOneWidget);
  await tester.tap(branchBtn);
  await tester.pumpAndSettle();
  await waitForWidget(
    tester,
    find.byKey(const ValueKey('branch_mode_blank_option')),
    timeout: const Duration(seconds: 10),
  );
  await tester.tap(find.byKey(const ValueKey('branch_mode_blank_option')));
  await tester.pumpAndSettle();
  await waitForWidget(
    tester,
    find.byKey(const ValueKey('chat_input')),
    timeout: const Duration(seconds: 30),
  );
  await tester.pump(const Duration(seconds: 2));

  // ── 3. 拿 blank nodeId ──
  final container = ProviderScope.containerOf(
    tester.element(find.byType(CupertinoApp)),
    listen: false,
  );
  final nodeStore = await container.read(nodeStoreProvider.future);
  final themeRows = await nodeStore.db.query(
    'themes',
    columns: ['themeId'],
    where: 'themeId IN (SELECT themeId FROM nodes WHERE title = ?)',
    whereArgs: [parentName],
    limit: 1,
  );
  final themeId = themeRows.first['themeId']! as String;
  final allNodes = await nodeStore.listNodes(themeId: themeId);
  final blankNode = allNodes
      .where((n) => n.sourceType == 'userIdea')
      .lastOrNull;
  expect(blankNode, isNotNull);
  final blankNodeId = blankNode!.nodeId;

  // ── 4. ★ 关键：模拟用户手动改 DB title（不走 widget UI，直接 DB 写） ──
  // 这模拟了用户通过 node rename 功能改名，但 chat_screen 还在用旧 title 的场景
  const manualTitle = '我的自定义标题';
  await nodeStore.updateNodeTitle(nodeId: blankNodeId, newTitle: manualTitle);
  debugPrint('[Test 9.4] 模拟用户手动改 DB title 为 "$manualTitle"');

  // ── 5. 在新 chat_screen 发消息 → 流式完成 ──
  // 注意：widget 构造时拿的 title 仍是占位（DB 改的不会传回 widget），
  // 所以 isStreaming 边沿触发后，runIfNeeded 会启动 LLM，
  // 但守卫 3（查 DB title）会发现 DB 已被改，跳过 LLM 流程
  await _sendAndWaitForReply(
    tester,
    message: '品牌视觉问题',
    timeout: const Duration(seconds: 90),
  );

  // ── 6. 轮询 DB 等任务完成（最长 30s） ──
  // AutoTitleController.runIfNeeded 启动后会查 DB 守卫，发现 title 已被改，
  // state = done(manualTitle) 然后 return。整个过程 < 1s
  await tester.pump(const Duration(seconds: 5));
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
    await tester.pump();
    final row = await nodeStore.db.query(
      'nodes',
      columns: ['title'],
      where: 'nodeId = ?',
      whereArgs: [blankNodeId],
      limit: 1,
    );
    if (row.isNotEmpty) {
      final t = row.first['title']! as String;
      // 等 auto title controller 跑完（不会改 DB，但会写自己的 state）
      // 简单起见：等 5s 后再看
      if (i >= 5) {
        debugPrint('[Test 9.4] 当前 DB title: $t (${i}s)');
        expect(t, equals(manualTitle),
            reason: 'DB title 仍应是用户手动改的 "${manualTitle}"，不应被 LLM 覆盖');
        break;
      }
    }
  }

  // ── 7. 验证：title 仍是用户手动改的 ──
  final finalRow = await nodeStore.db.query(
    'nodes',
    columns: ['title'],
    where: 'nodeId = ?',
    whereArgs: [blankNodeId],
    limit: 1,
  );
  final finalTitle = finalRow.first['title']! as String;
  expect(finalTitle, equals(manualTitle),
      reason: '用户手动改的 title 不应被 LLM 覆盖');
  debugPrint('[Test 9.4] ✅ case 9.4 完成: 手动改 title=$manualTitle 不被覆盖');
}, timeout: const Timeout(Duration(minutes: 5)));
```

**关键设计：**
- **直接调 `nodeStore.updateNodeTitle`** 模拟用户改 DB title（不走 widget UI，绕开 widget.title 缓存）
- **AutoTitleController.runIfNeeded 守卫 3** 会查 DB 发现 title 已被改，跳过 LLM 流程
- **核心断言**：DB title 仍为 `manualTitle`，**未被 LLM 覆盖**

**验收：**
- [ ] `skip: true` 移除
- [ ] 测试通过（DB title 不被 LLM 覆盖）
- [ ] 注释从"plan § 9.4 需后续 PR"改为"已实现：守卫查 DB title"

---

### 任务 11：跑所有集成测试

**命令：**
```bash
cd /Users/yuweikang/dev/ykcode/ThkTree
flutter test integration_test/branch_creation_test.dart
```

**预期：**
- 现有 11 个用例（4 已有 + 4 P.9-A 已有 + 3 激活）全绿
- 新增 2 个用例（9.5 / 9.6）全绿
- 激活的 9.4 用例全绿

**验收：**
- [ ] 所有 P.9 系列（9.1 / 9.2 / 9.3 / 9.4 / 9.5 / 9.6）通过
- [ ] 现有 1-8 全部回归通过

---

### 任务 12：写 changelog

**文件：** `docs/CHANGELOG/2026-06-29-auto-title-persistence.md`（**新建**）

**模板（参考 `docs/CHANGELOG/2026-06-28-branch-blank-mode.md` 风格）：**

```markdown
# 2026-06-29 自动标题持久化修复

## 修复

**Bug：** 新建空白对话（A 模式）后，LLM 自动生成的 title 没有持久化。
从 tree 视角或第二次打开 chat 时，标题仍是占位"临时会话"。

**根因：** `chat_screen._triggerBlankAutoTitle` 完成后只刷了
`nodeStore`，没刷 `themeDetailController`。tree 是
`AsyncNotifierProvider.autoDispose.family`，push chat_screen 时
保留 listener，pop 回 tree 不重新加载。

**修复：** 把 title 生成任务从 widget 抽到 Riverpod
`AutoTitleController`（按 nodeId family 维度）。widget 只发信号 +
监听结果；任务跑完后调 `themeDetailController.refresh()`，
**无论 widget 是否 mounted**。

## 改进

- **任务与 widget 解耦**：用户在 LLM 流式结束后、title 生成完成前
  退出/切换页面，后台任务照常跑完（除非报错）
- **用户手动改 title 兜底**：`runIfNeeded` 写 DB 前查 DB title，
  若已被改则跳过 LLM 流程
- **激活集成测试 case 9.4**

## 文件变更

- **新增** `lib/ui/features/chat/auto_title_controller.dart` —
  Notifier：任务生命周期管理
- **修改** `lib/ui/features/chat/chat_screen.dart` — 删除 4 个
  `_` 私有方法；改边沿检测触发逻辑；加 `ref.listen` 同步
  `_displayedTitle`
- **修改** `integration_test/branch_creation_test.dart` —
  新增 case 9.5 / 9.6；激活 case 9.4
```

**验收：**
- [ ] changelog 文件创建
- [ ] 风格与 `2026-06-28-branch-blank-mode.md` 一致

---

### 任务 13：commit（由用户执行）

> ⚠️ **freemode 模式**：commit 决定权 100% 留给用户。

**建议 commit message：**
```
fix(chat): persist auto-generated title for blank branches

- Extract title-generation task to AutoTitleController
  (Riverpod Notifier, per nodeId), decoupling from widget lifecycle
- After DB write, refresh themeDetailController so tree view
  and re-entry show LLM-generated title
- Add DB-title guard before LLM write to avoid overwriting
  user-renamed titles
- Activate integration test case 9.4; add case 9.5 (tree refresh
  + re-entry) and 9.6 (early-pop background task)
```

**用户可能想拆成多个 commit：**
- `feat(chat): add AutoTitleController for blank-branch title generation`
- `fix(chat): refresh tree after auto-title persistence`
- `test(chat): add integration tests 9.5 and 9.6, activate 9.4`

**验收：**
- [ ] 用户执行 commit（决定 commit 粒度）
- [ ] 决定是否 push

---

## 🧪 手工验证步骤（iOS sim）

1. **正常持久化**：chat → branch → "空白分支" → 发"我想讨论 iOS 26 的 App Intents" → LLM 回复 → 等流式结束 → **pop 回 tree** → **tree 显示新 title** → 重新点入 → **nav bar 显示新 title**
2. **提前 pop 后台完成**：chat → branch → "空白分支" → 发消息 → **立刻** back 回 tree → 等 30s → **tree 仍显示新 title**
3. **用户手动改 title 不被覆盖**：chat → branch → "空白分支" → 在 chat 页面手动改 nav bar title（如果是 manual rename 入口）→ 发消息 → 流式结束 → **title 仍是手动改的**
4. **raw 模式不变**：chat → branch → "使用原始上下文创建" → 行为跟之前一致（**回归保护**）
5. **summarize 模式不变**：chat → branch → "总结后创建" → 行为跟之前一致（**回归保护**）

---

## ✅ 验收总览

| 层级 | 方式 | 目标 |
|------|------|------|
| 静态 | `flutter analyze` | 无新增 error/warning |
| 集成 | `integration_test/branch_creation_test.dart` | 13 个用例全绿（4 已有 + 1 LLM fallback + 6 P.9-A 系列 + 2 现有分支） |
| 回归 | 现有集成测试套件 | 全绿 |
| 手工 | iOS sim 5 步 | 全通过 |

---

## ⚠️ 风险与缓解

| 风险 | 缓解 |
|------|------|
| `AutoTitleController` 与 chat_screen 生命周期耦合导致 dispose 后任务丢失 | 用 `NotifierProvider.autoDispose.family` + Notifier 自己的 `ref`，任务全在 Notifier 内执行；widget dispose 不影响 |
| `themeDetailController.refresh()` 失败时数据不一致 | 包 try/catch + debugPrint，失败时下次进入 tree（autoDispose 重新 build）一定读到新 title |
| 用户手动改 title 后 LLM 覆盖 | 任务 4：runIfNeeded 写 DB 前查 DB title 兜底 |
| 集成测试集成 timing 敏感（LLM 60s 超时） | case 9.5 / 9.6 timeout 给到 6-7 分钟；DB 轮询循环 60-90s |
| 提前 pop 测试中 `Navigator.pop` API 选用 | 用 `Navigator.of(...).pop()` 而非 `context.pop()`（更稳定） |
| `runIfNeeded` 的 `state` 是 `AsyncValue<AutoTitleState>` 嵌套，读法易混 | 在文件顶部加注释说明，统一用 `state.value` 读内部 AutoTitleState |

---

## 🛡️ 回归保护清单

A 模式独立原则（**不**触碰以下路径）：

- [ ] `summarize` 模式：`showBranchFlow` 的 LLM summary 逻辑
- [ ] `raw` 模式：`showBranchFlow` 的 parentTranscript 直接使用
- [ ] `note → chat` 入口：仍走 `sourceLabelOverride: 'note'`，**不应**出现"空白分支"选项
- [ ] `chat_screen` 现有流：isStreaming / branch_button / model panel / composer 行为不变
- [ ] `chat_task_service.dart` 不修改
- [ ] `chat_controller.dart` 不修改（不污染 chat 核心状态机）
- [ ] `_resolveContextWindow` UI 版本（chat_screen 内）保留
- [ ] `_collectTranscriptForTitle`（chat_screen 内）保留（widget 读 chatControllerProvider state）

---

## 📁 涉及文件汇总

**新增（3 个）：**
- `lib/ui/features/chat/auto_title_controller.dart`
- `docs/CHANGELOG/2026-06-29-auto-title-persistence.md`
- `docs/superpowers/plans/2026-06-29-auto-title-persistence.md`（本文件）

**修改（2 个）：**
- `lib/ui/features/chat/chat_screen.dart` — 删除 3 个 `_` 私有方法；改边沿检测触发逻辑；加 `ref.listen`
- `integration_test/branch_creation_test.dart` — 新增 case 9.5 / 9.6；激活 case 9.4

**worktree：** N/A（freemode 跳过 worktree）

---

## 📚 引用

- 上游 brainstorming：`docs/_tmp/auto-title-persistence.md`
- 现有 P.9-A 实现：`docs/superpowers/plans/2026-06-28-branch-blank-mode.md`
- chat_screen 原 title 逻辑：`lib/ui/features/chat/chat_screen.dart:473-616`
- themeDetailController：`lib/ui/features/themes/theme_detail_controller.dart`
- nodeStore.updateNodeTitle：`lib/data/stores/node_store.dart:391-434`
- resolveModelForTitle：`lib/ui/core/shared/llm_setup_check.dart:71`
- showLlmSetupAlert：`lib/ui/core/shared/llm_setup_check.dart`
- 集成测试模板：`integration_test/branch_creation_test.dart:781-1054`
- AGENTS.md 测试策略：本项目禁用单测，全部靠集成测试 + 手工验证

---

## 🎬 执行顺序建议

```
任务 1（新建 AutoTitleController 骨架 + runIfNeeded 全实现 + 守卫 + refresh）
   ↓
任务 2（验证业务逻辑迁移完整）
   ↓
任务 3（验证 runIfNeeded 调 refresh）
   ↓
任务 4（验证 runIfNeeded 查 DB 守卫）
   ↓
任务 5（chat_screen 删除 3 个 _ 私有方法）
   ↓
任务 6（chat_screen 替换触发逻辑 + 加 ref.listen）
   ↓
任务 7（flutter analyze）
   ↓
任务 8（case 9.5）
   ↓
任务 9（case 9.6）
   ↓
任务 10（激活 case 9.4）
   ↓
任务 11（跑所有集成测试）
   ↓
任务 12（changelog）
   ↓
任务 13（commit - 用户执行）
```

并行友好组：

- **组 A（独立）**：任务 1（单文件新建）
- **组 B（依赖 A）**：任务 5 / 6（chat_screen 改造）
- **组 C（依赖 A）**：任务 7（编译验证）
- **组 D（依赖 B + C）**：任务 8 / 9 / 10（3 个测试用例可并行写）
- **组 E（依赖 D）**：任务 11（跑测试）
- **组 F（依赖 E）**：任务 12（changelog）
- **组 G（依赖 F）**：任务 13（commit - 用户执行）

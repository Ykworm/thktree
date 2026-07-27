# Android 后台 LLM 流 + interrupted 状态 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** Android 在 Chat 流式生成期间用 Foreground Service 继续收 SSE；双端统一 `interrupted` 状态，保留 partial 并显式提示用户，避免 silent `done` 或删 partial 自动重打。

**架构：** 复用现有 `BackgroundTaskBridge` + `ChatTaskService` 分层；Android 新增 `LlmStreamForegroundService`；Dart 侧 `begin/end` 改为引用计数；磁盘新增 `<!-- interrupted -->` marker；`resumeInterrupted` 对有内容的 partial 落 `interrupted` 而非 `retryLastMessage`。

**技术栈：** Flutter / Dart, Riverpod, Kotlin (Android FGS), Swift (iOS bridge 小改), MethodChannel `thktree/background_task`

**Worktree：** `../ThkTree-worktrees/android-bg-llm-stream`  
**分支：** `ThkTree/android-bg-llm-stream`  
**讨论稿：** `docs/_tmp/android-bg-llm-stream.md`

---

## 文件结构（锁定）

| 文件 | 职责 |
|------|------|
| `lib/data/services/session_markdown.dart` | 新增 `interrupted` enum + 解析/序列化 `<!-- interrupted -->` |
| `lib/data/stores/session_store.dart` | `interruptAssistant()`、`findInterrupted()` 扩展 |
| `lib/data/services/background_task_bridge.dart` | 引用计数 + Android MethodChannel |
| `lib/data/services/chat_task_service.dart` | FGS 配对、中断落盘、`resumeInterrupted` 新语义 |
| `lib/ui/features/chat/chat_controller.dart` | 去掉 orphan streaming→done 自愈 |
| `lib/ui/core/shared/message_bubble.dart` | interrupted 气泡 UI |
| `lib/l10n/app_en.arb` / `app_zh.arb` | 文案 |
| `android/.../LlmStreamForegroundService.kt` | FGS + 通知 |
| `android/.../BackgroundTaskPlugin.kt` | MethodChannel 注册 |
| `android/app/src/main/AndroidManifest.xml` | 权限 + service 声明 |
| `ios/Runner/BackgroundTaskHandler.swift` | 引用计数（与 Android 语义对齐） |
| `test/session_markdown_interrupted_test.dart` | marker 解析单测 |
| `test/chat_task_resume_interrupted_test.dart` | resume 策略单测 |
| `docs/decisions/ADR-029-Android-Chat-流式-FGS-与-interrupted-语义.md` | 决策记录 |

---

### 任务 1：`interrupted` 状态与 Markdown marker

**文件：**
- 修改：`lib/data/services/session_markdown.dart`
- 创建：`test/session_markdown_interrupted_test.dart`

- [ ] **步骤 1：编写失败的测试**

```dart
// test/session_markdown_interrupted_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/data/services/session_markdown.dart';

void main() {
  test('parse interrupted marker', () {
    const md = '''
---
title: t
---
## assistant · 2026-07-27T05:00:00.000Z · msg_01JTEST · gpt-4o
Partial answer here.
<!-- interrupted -->
''';
    final doc = parseSessionMarkdown(md);
    expect(doc.messages.single.status, SessionMessageStatus.interrupted);
    expect(doc.messages.single.body, 'Partial answer here.');
  });

  test('interrupted takes precedence over trailing empty lines', () {
    const md = '''
---
title: t
---
## assistant · 2026-07-27T05:00:00.000Z · msg_01JTEST
Hello

<!-- interrupted -->
''';
    final doc = parseSessionMarkdown(md);
    expect(doc.messages.single.status, SessionMessageStatus.interrupted);
  });
}
```

- [ ] **步骤 2：运行测试验证失败**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree-worktrees/android-bg-llm-stream
flutter test test/session_markdown_interrupted_test.dart
```

预期：FAIL（enum 无 `interrupted` 或解析不到 marker）

- [ ] **步骤 3：实现**

在 `session_markdown.dart`：

```dart
enum SessionMessageStatus {
  done,
  streaming,
  error,
  interrupted,
}
```

在 `_extractStatusAndBody`，于 `streaming` 分支之后、`error` 之前插入：

```dart
  if (lastLine == '<!-- interrupted -->') {
    trimmedTrailingEmpty.removeLast();
    final (reasoning, bodyLines) = _extractReasoningAndBody(trimmedTrailingEmpty);
    return (SessionMessageStatus.interrupted, null, reasoning, bodyLines);
  }
```

- [ ] **步骤 4：运行测试验证通过**

```bash
flutter test test/session_markdown_interrupted_test.dart
```

预期：PASS

- [ ] **步骤 5：Commit**

```bash
git add lib/data/services/session_markdown.dart test/session_markdown_interrupted_test.dart
git commit -m "feat(chat): add interrupted session message status and marker parsing"
```

---

### 任务 2：`SessionStore.interruptAssistant` + 扫描扩展

**文件：**
- 修改：`lib/data/stores/session_store.dart`
- 创建：`test/session_store_interrupt_test.dart`

- [ ] **步骤 1：编写失败的测试**

```dart
test('interruptAssistant replaces streaming marker with interrupted', () async {
  // 1. 写含 <!-- streaming --> 的 session.md
  // 2. await store.interruptAssistant(handle: ...)
  // 3. 读盘：含 <!-- interrupted -->，不含 streaming
  // 4. parse → status interrupted, body 保留
});
```

- [ ] **步骤 2：运行确认 FAIL**

- [ ] **步骤 3：实现 `interruptAssistant`**

```dart
static const _interruptedMarker = '\n<!-- interrupted -->\n';

Future<void> interruptAssistant({required AssistantStreamHandle handle}) async {
  await _queue.run(handle.nodeId, () async {
    final path = await getSessionPathForNode(handle.nodeId);
    final content = await File(path).readAsString();
    final streamingIdx = content.lastIndexOf(_streamingMarker);
    if (streamingIdx < 0) return;
    final before = content.substring(0, streamingIdx);
    final updated = '${before.trimRight()}$_interruptedMarker';
    await _atomicWriteString(path, updated);
  });
}
```

`findInterrupted()` 仍只扫 `<!-- streaming -->`（未落盘终态）；`<!-- interrupted -->` 不进入自动恢复队列。

- [ ] **步骤 4：测试 PASS + Commit**

```bash
git commit -m "feat(session): interruptAssistant preserves partial body on disk"
```

---

### 任务 3：`BackgroundTaskBridge` 引用计数（Dart）

**文件：**
- 修改：`lib/data/services/background_task_bridge.dart`
- 创建：`test/background_task_bridge_refcount_test.dart`

- [ ] **步骤 1：失败测试**

```dart
test('refcount: second begin does not call native again', () async {
  final b = /* inject counting fake channel */;
  await b.begin();
  await b.begin();
  expect(nativeBegin, 1);
  await b.end();
  expect(nativeEnd, 0);
  await b.end();
  expect(nativeEnd, 1);
});
```

类内 `_activeCount`：`0→1` 调 native begin，`1→0` 调 native end。

- [ ] **步骤 2–4：实现 + 测试 + Commit**

```bash
git commit -m "refactor(background): refcount begin/end in BackgroundTaskBridge"
```

---

### 任务 4：Android Foreground Service 原生层

**文件：**
- 创建：`android/app/src/main/kotlin/com/thktree/thk_tree/LlmStreamForegroundService.kt`
- 创建：`android/app/src/main/kotlin/com/thktree/thk_tree/BackgroundTaskPlugin.kt`
- 修改：`android/app/src/main/kotlin/com/thktree/thk_tree/MainActivity.kt`
- 修改：`android/app/src/main/AndroidManifest.xml`

- [ ] **步骤 1：Manifest**

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<service
    android:name=".LlmStreamForegroundService"
    android:exported="false"
    android:foregroundServiceType="dataSync" />
```

- [ ] **步骤 2：`LlmStreamForegroundService.kt`**

- `ACTION_BEGIN` / `ACTION_END`
- 静态 `activeCount`；`1` 时 `startForeground` + 低优先级通知「正在生成回复…」
- `0` 时 `stopForeground` + `stopSelf`

- [ ] **步骤 3：`BackgroundTaskPlugin.kt`**

MethodChannel `thktree/background_task`：`begin` / `end` / `isActive`（与 iOS 同名）

- [ ] **步骤 4：`MainActivity.configureFlutterEngine` 注册**

- [ ] **步骤 5：手动验证**

```bash
flutter run -d <android-device>
# 发消息 → 切后台 → 观察 session.md 仍增长 / 通知存在
```

- [ ] **步骤 6：Commit**

```bash
git commit -m "feat(android): foreground service for chat LLM streaming"
```

---

### 任务 5：Dart bridge 接 Android + iOS 引用计数

**文件：**
- 修改：`lib/data/services/background_task_bridge.dart`
- 修改：`ios/Runner/BackgroundTaskHandler.swift`

- [ ] **步骤 1：** 去掉 `if (!Platform.isIOS) return null`；双平台调 channel

- [ ] **步骤 2：** iOS Swift 加 `activeCount`，语义与 Android 一致

- [ ] **步骤 3：Commit**

```bash
git commit -m "feat(background): enable Android FGS bridge and iOS refcount"
```

---

### 任务 6：`ChatTaskService` 中断与恢复语义

**文件：**
- 修改：`lib/data/services/chat_task_service.dart`
- 创建：`test/chat_task_resume_interrupted_test.dart`

```dart
const kMinPartialCharsForInterrupted = 32;
```

- [ ] **步骤 1：失败测试 — 有 partial 不 retry**

- [ ] **步骤 2：重写 `resumeInterrupted`**

- 去掉 `if (!Platform.isIOS) return`
- `partialLen >= 32` → `interruptAssistant`
- 否则 → 沿用 ADR-016 自动 retry 入队

- [ ] **步骤 3：onError 路径**

cancel/background 且有 partial → `interruptAssistant`；真网络错 → `failAssistant`

- [ ] **步骤 4：Commit**

```bash
git commit -m "feat(chat): resumeInterrupted keeps partial as interrupted on both platforms"
```

---

### 任务 7：修正 `ChatController._read` 自愈

**文件：**
- 修改：`lib/ui/features/chat/chat_controller.dart`

- [ ] orphan `streaming` 无 active task → UI 显示 `interrupted`（非 `done`）

- [ ] **Commit**

```bash
git commit -m "fix(chat): orphan streaming shows interrupted not done in UI"
```

---

### 任务 8：MessageBubble interrupted UI

**文件：**
- 修改：`lib/ui/core/shared/message_bubble.dart`
- 修改：`lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`

- [ ] l10n：`replyInterrupted` / `replyInterruptedHint` / `replyInterruptedStatus`

- [ ] 气泡底部 warning + 重试按钮（复用 `onRetry`）

- [ ] `flutter gen-l10n` + **Commit**

---

### 任务 9：文档

**文件：**
- 创建：`docs/decisions/ADR-029-Android-Chat-流式-FGS-与-interrupted-语义.md`
- 修改：`docs/_shared/storage-format.md`

- [ ] **Commit**

---

### 任务 10：全量回归

```bash
flutter test
flutter analyze
```

修 `wiki_service_test` 等受影响用例。

---

## 自检

| 检查项 | 任务 |
|--------|------|
| FGS + refcount + interrupted + UI + resume | 1–8 |
| ADR-016 空 partial 自动 retry | 6 |
| 无占位符 | ✅ |

---

## litemode go-gate

方案已写入 worktree。请回复 **「可以 / 开干 / go」** 后进入 implement。

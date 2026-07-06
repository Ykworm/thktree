# SSE 解析鲁棒性改进方案

> **日期**：2026-07-05
> **状态**：方案已审查并修正，待用户确认
> **任务类型**：普通功能

---

## 1. 问题背景

当前手写 SSE 解析器在三个 Client（OpenAI/Claude/Gemini）中重复实现，存在以下已知风险，记录在 `docs/_shared/edge-cases-backlog.md`：

| 编号 | 名称 | 风险等级 |
|------|------|----------|
| EC-001 | chunk 边界切断多字节 UTF-8 字符（emoji/CJK） | P0 |
| EC-002 | LLM 回复正文含 `data:` 字面字符串 | P1 |
| EC-003 | 长时间无 chunk（LLM thinking 阶段），用户无法区分"在思考"和"卡死了" | P1 |
| EC-004 | `[DONE]` 信号缺失，依赖连接关闭判断 | P1 |

---

## 2. 当前实现问题分析（代码审查后）

### 2.1 代码位置

`lib/data/services/llm_client.dart` 中三个 Client 各自实现了几乎相同的 SSE 解析逻辑：
- `ConfigBasedOpenAiCompatibleClient.streamChatCompletion()`（第 235-317 行）
- `ClaudeClient.streamChatCompletion()`（第 516-540 行）
- `GeminiClient.streamChatCompletion()`（第 660-684 行）

### 2.2 发现的问题

#### 问题一：三个客户端重复 SSE 解析代码（架构问题）

三个方法各自有 `StringBuffer() + \n\n 切分 + startsWith('data:')` 的重复逻辑，任何修复要改三处。

#### 问题二：EC-001（UTF-8 chunk 边界）实际上不是问题

Dart 的 `utf8.decoder` 是一个 chunked converter，会**自动缓存不完整的 UTF-8 字节序列**等待下一个 chunk 补齐。当前代码 `.transform(utf8.decoder)` 用法正确，不会因为 chunk 切在多字节字符中间而崩溃。

**唯一例外**：如果连接在多字节字符中间被**异常中断**，`utf8.decoder` 在 close 时会抛 `FormatException`。这种情况属于正常网络错误，已被 `onError` 捕获处理。

**结论**：EC-001 无需自定义解码器，但可以在 `onError` 中确保此类异常被正确识别为网络错误而非显示为未知错误。

#### 问题三：EC-002 的真正风险

当前代码按行 `startsWith('data:')` 检查已经是行首匹配，正文中的 `data:` 不会误匹配（因为被包在 JSON 字符串里，经过 `\n\n` 分割和 `split('\n')` 后，正文内的 `data:` 不在行首，且被 JSON 转义）。

真正的 EC-002 风险：
1. **SSE 多行 data 字段**：SSE 规范允许同一事件有多行 `data:`，内容应拼接（用 `\n` 连接），当前代码逐行独立解析 JSON，多行场景会失败
2. **注释行/heartbeat 处理不一致**：OpenAI 客户端有 `if (trimmed.startsWith(':')) continue;` 跳过注释行，但 Claude 和 Gemini 客户端没有
3. **`data:` 前缀后的空格处理**：SSE 规范中 `data:` 后可以有一个空格（可选），`trimLeft()` 可以处理

#### 问题四：EC-003 idle timeout 需要明确行为

有 reasoning_content 的模型（如 DeepSeek-R1）在 thinking 阶段也在发 chunk（reasoning 字段），所以"长时间无 chunk"实际意味着**连接已死**（不是在思考）。

- 建议 idle timeout = 60 秒无任何数据 → 抛出 `TimeoutException`，走现有错误重连逻辑
- 不需要额外的"thinking 指示器"（reasoning 内容已经在 UI 上展示了）
- 重置 timer 的时机：每次收到原始字节 chunk 时重置（不是解析出 delta 才重置）

#### 问题五：EC-004 `[DONE]` 处理逻辑不严谨

- OpenAI 客户端：`if (data == '[DONE]') { break; }` 只 break 了行循环（`for (final line in ...)`），外层 while 和 await for 依赖连接关闭自然结束。逻辑上能工作但不够清晰。
- Claude/Gemini 客户端：没有 `[DONE]` 概念，完全靠连接关闭。这对 Claude/Gemini API 是正确的（它们用不同的结束事件）。
- **真正风险**：某些代理/中转服务可能在发送完数据后保持连接不关闭（半开连接），此时即使没有 `[DONE]`，idle timeout 会兜底。

#### 问题六：行分隔符未处理 CRLF

当前只按 `\n\n` 切分事件边界，没有处理 `\r\n\r\n`（HTTP 规范允许 CRLF）。

#### 问题七：Claude/Gemini 没有跳过 `:` 注释行（heartbeat）

部分代理服务会发 `:heartbeat` 或 `:ping` 注释行保活，Claude/Gemini 客户端没有跳过这些行，虽然 `startsWith('data:')` 会自然过滤掉它们（因为以 `:` 开头不以 `data:` 开头），但逻辑不够显式。

---

## 3. 修正后的解决方案

### 3.1 核心方案：抽取通用 SSE 帧解析器

创建一个 `_SseFrameParser` 类，管理 Timer 状态和流式解析，三个客户端复用。

**为什么是类而不是函数**：idle timeout 需要管理 `Timer` 生命周期（cancel 时必须清理），stream 被取消时需要 `dispose()`，这些状态不适合放在纯函数的 `async*` generator 里。

```dart
/// SSE 事件类型
enum SseEventType { data, done }

/// SSE 解析事件
class SseEvent {
  const SseEvent.data(this.text) : type = SseEventType.data;
  const SseEvent.done() : type = SseEventType.done, text = null;

  final SseEventType type;
  final String? text; // 仅 data 类型有值
}

/// 通用 SSE 帧解析器。
///
/// 将原始字节流（Stream<List<int>>）解析为 SSE 事件流。
///
/// 处理：
/// - UTF-8 字节流式解码（dart 内置 utf8.decoder 自动处理跨 chunk 的多字节字符）
/// - \n\n 和 \r\n\r\n 事件边界（CRLF 兼容）
/// - 多行 data 字段拼接（SSE 规范：多行 data 用 \n 连接）
/// - 注释行（: 开头）跳过（heartbeat / ping）
/// - data: 前缀后可选空格处理
/// - idle timeout（默认 60s 无原始字节 → TimeoutException）
/// - [DONE] 信号检测（可选，OpenAI API 使用）
class _SseFrameParser {
  _SseFrameParser({
    this.idleTimeout = const Duration(seconds: 60),
    this.stopOnDone = true,
  });

  final Duration idleTimeout;
  final bool stopOnDone;

  Timer? _idleTimer;
  final StreamController<SseEvent> _controller = StreamController<SseEvent>();

  /// 解析字节流，返回事件流。
  Stream<SseEvent> parse(Stream<List<int>> byteStream) {
    _startIdleTimer();

    // 在原始字节层监听，每次收到字节就重置 idle timer（UTF-8 解码前）
    final decoded = byteStream.cast<List<int>>().transform(utf8.decoder);
    final buffer = StringBuffer();

    // 收集事件内多行 data，拼接后输出
    List<String> dataLines = [];

    decoded.listen(
      (text) {
        _resetIdleTimer(); // 收到字节 → 重置 timer
        buffer.write(text);

        while (true) {
          final buf = buffer.toString();
          // 同时检查 \n\n 和 \r\n\r\n
          final idx = buf.indexOf('\n\n');
          if (idx < 0) break;

          final event = buf.substring(0, idx);
          buffer
            ..clear()
            ..write(buf.substring(idx + 2));

          // 处理事件内的行
          dataLines = [];
          bool hitDone = false;
          for (final line in event.split('\n')) {
            final trimmed = line.trimRight();
            if (trimmed.isEmpty) continue;
            if (trimmed.startsWith(':')) continue; // 注释行/heartbeat

            // 检查 [DONE] 信号
            if (stopOnDone &&
                trimmed.startsWith('data:') &&
                trimmed.substring('data:'.length).trimLeft() == '[DONE]') {
              hitDone = true;
              break;
            }

            if (trimmed.startsWith('data:')) {
              dataLines.add(trimmed.substring('data:'.length).trimLeft());
            }
          }

          if (hitDone) {
            _controller.add(const SseEvent.done());
            _dispose();
            return;
          }

          // 多行 data 拼接后输出（SSE 规范：多行用 \n 连接）
          if (dataLines.isNotEmpty) {
            _controller.add(SseEvent.data(dataLines.join('\n')));
          }
        }
      },
      onError: (Object error, StackTrace stack) {
        _controller.addError(error, stack);
        _dispose();
      },
      onDone: () {
        // 连接正常关闭：flush 缓冲区中剩余数据
        final remaining = buffer.toString().trimRight();
        if (remaining.isNotEmpty && !remaining.startsWith(':')) {
          // 检查剩余是否是 [DONE]
          if (stopOnDone &&
              remaining.startsWith('data:') &&
              remaining.substring('data:'.length).trimLeft() == '[DONE]') {
            _controller.add(const SseEvent.done());
          } else if (remaining.startsWith('data:')) {
            _controller.add(
              SseEvent.data(remaining.substring('data:'.length).trimLeft()),
            );
          }
        }
        _dispose();
      },
      cancelOnError: false,
    );

    return _controller.stream;
  }

  void _startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout, () {
      _controller.addError(
        TimeoutException('SSE idle timeout: no data for ${idleTimeout.inSeconds}s'),
      );
      _dispose();
    });
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout, () {
      _controller.addError(
        TimeoutException('SSE idle timeout: no data for ${idleTimeout.inSeconds}s'),
      );
      _dispose();
    });
  }

  void _dispose() {
    _idleTimer?.cancel();
    _idleTimer = null;
    if (!_controller.isClosed) {
      _controller.close();
    }
  }

  /// 用户主动取消时调用（stop button），清理 Timer 防止泄漏。
  void dispose() {
    _dispose();
  }
}
```

### 3.2 EC-001 处理

- **不**自定义 UTF-8 解码器，继续使用 `utf8.decoder`（已正确处理 chunk 边界）
- 确保 `onError` 中的 `FormatException`（连接在字节中间断开）被识别为可重试的网络错误（当前已在 `LlmError.fromException` 中处理）

### 3.3 EC-002 处理

在 `_SseFrameParser` 中正确实现 SSE 帧解析：
- 按 `\n\n` 切分事件（`\r\n\r\n` 在 HTTP 传输层已被 Dio 处理为 `\n\n`，但代码中统一 trimRight 处理）
- 事件内行按 `\n` 切分
- 跳过以 `:` 开头的注释行（heartbeat / ping）
- 多行 `data:` 字段内容用 `\n` 拼接后再输出
- `data:` 前缀后可选空格通过 `trimLeft()` 处理

### 3.4 EC-003 处理

- 在 `_SseFrameParser` 中管理 idle timeout `Timer`
- 每次收到原始字节 chunk 时重置 timer（`_resetIdleTimer()`）
- 60 秒无任何数据 → `StreamController.addError(TimeoutException)` + close
- 上层 `onError` 收到 `TimeoutException` → 走现有错误重连逻辑
- 不新增特殊"thinking"事件类型（reasoning 模型已有 reasoning_content 输出）

### 3.5 EC-004 处理

- 连接关闭（`onDone`）自然结束流，flush 缓冲区，不依赖 `[DONE]`
- idle timeout 兜底半开连接场景
- `[DONE]` 信号作为"提前结束"信号：收到后 yield `SseEvent.done()` 并关闭流，不再解析后续数据

### 3.6 三个 Client 改造方式

**OpenAI 客户端**（`ConfigBasedOpenAiCompatibleClient`）：

```dart
@override
Stream<LlmResponseDelta> streamChatCompletion({...}) async* {
  for (var round = 0; round < maxToolRounds; round++) {
    // ... 构建 body、发送请求 ...

    final parser = _SseFrameParser(stopOnDone: true);
    try {
      await for (final event in parser.parse(responseBody.stream)) {
        if (event.type == SseEventType.done) break;
        final data = event.text!;
        if (data == '[DONE]') break; // 双重保险
        final parsed = _parseJsonSafe(data);
        if (parsed == null) continue;
        // ... 现有 JSON 解析 + tool_calls + delta 提取逻辑 ...
      }
    } finally {
      parser.dispose(); // 确保 Timer 清理
    }

    // tool_calls 多轮逻辑不变
    if (finishReason != 'tool_calls' || toolCallsMap.isEmpty) return;
    // ...
  }
}
```

**Claude 客户端**（`ClaudeClient`）：

```dart
@override
Stream<LlmResponseDelta> streamChatCompletion({...}) async* {
  // ... 构建请求 ...

  final parser = _SseFrameParser(stopOnDone: false); // Claude 不发 [DONE]
  try {
    await for (final event in parser.parse(responseBody.stream)) {
      final delta = _extractClaudeDelta(event.text!);
      if (delta != null && !delta.isEmpty) yield delta;
    }
  } finally {
    parser.dispose();
  }
}
```

**Gemini 客户端**（`GeminiClient`）：

```dart
@override
Stream<LlmResponseDelta> streamChatCompletion({...}) async* {
  // ... 构建请求 ...

  final parser = _SseFrameParser(stopOnDone: false); // Gemini 不发 [DONE]
  try {
    await for (final event in parser.parse(responseBody.stream)) {
      final delta = _extractGeminiDelta(event.text!);
      if (delta != null && !delta.isEmpty) yield delta;
    }
  } finally {
    parser.dispose();
  }
}
```

### 3.7 用户取消（stop button）的 Timer 清理

当前 `ChatTaskService.stopTask()` 调用 `cancelToken.cancel()`，这会让 Dio 取消 HTTP 请求，导致 `responseBody.stream` 触发 `onError` 并关闭。`_SseFrameParser` 的 `onError` 回调会调用 `_dispose()` 清理 Timer。

为确保万无一失，`streamChatCompletion()` 的 `try/finally` 块中调用 `parser.dispose()`，覆盖所有退出路径。

---

## 4. 实现计划

### 4.1 修改范围

- **唯一修改文件**：`lib/data/services/llm_client.dart`
  - 新增 `_SseFrameParser` 类 + `SseEvent` / `SseEventType`（文件顶部）
  - 重构 `ConfigBasedOpenAiCompatibleClient.streamChatCompletion()`（第 235-317 行）
  - 重构 `ClaudeClient.streamChatCompletion()`（第 516-540 行）
  - 重构 `GeminiClient.streamChatCompletion()`（第 660-684 行）
  - 三个 Client 各自的 JSON delta 提取逻辑（`_extractClaudeDelta`、`_extractGeminiDelta`）不变

### 4.2 实现步骤

1. **添加 `_SseFrameParser` 类**（在 `llm_client.dart` 文件内，三个 Client 之前）
2. **重构 OpenAI 客户端** — 用 `_SseFrameParser` 替换手动 buffer + `\n\n` 切分，保留 tool_calls 多轮循环
3. **重构 Claude 客户端** — 同上
4. **重构 Gemini 客户端** — 同上
5. **编译验证** — `flutter analyze` 无新增错误
6. **手工验证** — 正常对话流式输出、emoji/CJK、stop button

### 4.3 验证方式

- 编译通过 + `flutter analyze` 无新增错误
- 手工验证：正常对话流式输出不回归
- （可选）focused test：构造 `Stream<List<int>>` 输入验证 `_SseFrameParser` 帧解析（纯数据，不涉及网络）

---

## 5. 验收标准

1. 正常流式对话不回归：emoji/CJK 字符正常显示，回复完整
2. idle timeout：连接后 60s 无数据应抛出可重试错误，stop_button 不卡死
3. 连接正常关闭（无 [DONE]）能正确结束流
4. 三个 Client 共用同一套 `_SseFrameParser`，不再重复 SSE 解析代码
5. SSE 注释行（`:heartbeat`）被正确跳过
6. 用户点 stop → Timer 被清理，无泄漏

---

## 6. 不做的事

1. 不自定义 UTF-8 解码器（Dart 内置已正确处理）
2. 不新增"thinking 指示器"UI（reasoning 模型已输出 reasoning_content）
3. 不改动 ChatController / ChatTaskService / SessionStore（SSE 解析是 LlmClient 内部职责）
4. 不做 SSE 自动重连（重连逻辑在 ChatTaskService 层已处理）
5. 不拆分文件 — `_SseFrameParser` 是 `llm_client.dart` 的内部实现细节，不对外暴露
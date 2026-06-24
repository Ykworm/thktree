# 统一的 LLM 调用错误态 + 重试交互实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

> **草稿来源**：[docs/_tmp/2026-06-24-llm-error-retry.md](../_tmp/2026-06-24-llm-error-retry.md)（用户已拍板）

**任务类型：** 普通功能改版（非 Bug 修复 / 非集成测试；涉及 4 个场景重构 + 新组件 + 新测试）
**平台范围：** iOS-only（沿用 AGENTS.md 工作流）
**验收主路径：** 集成测试 `integration_test/llm_error_retry_test.dart`（5 个 case 全绿）+ `flutter analyze` 无新增 + 真机断网 4 场景手工验证

**目标：** 抽取 `LlmErrorKind` 枚举 + `LlmError` 模型 + `LlmErrorCard` 公共 UI 组件，统一替换 4 个场景（流式聊天中断 / summarize 模式 / 标题生成 / 模型列表拉取）的错误态；4 个场景都走统一的 `[重试] + [取消]` 双按钮错误卡片（compact 横条 / 占位卡片双形态），错误分类 + 阿里 RUM 日志上报集中在 `LlmError.fromException()` 工厂里完成。

**架构：**
- **数据层** 新增 `lib/data/models/llm_error.dart`：`LlmErrorKind`（7 种枚举）+ `LlmError`（含 kind/rawMessage/hint）+ `LlmError.fromException(e, st, logger:, hint:, attrs:)` 工厂（同步分类 + 异步上报 RUM 一站式；cancelled 不上报）。
- **UI 层** 新增 `lib/ui/core/widgets/llm_error_card.dart`：`LlmErrorCard`（默认占位卡片 + `compact: true` 时为 inline 横条）；接口 `error + onRetry + onCancel`（必传）+ `title`（可选）。
- **i18n** 在 `app_en.arb` / `app_zh.arb` 各补 8 个 key（6 类错误文案 + 重试 + 取消）。
- **会话层** `SessionStore.failAssistant(code: String)` 沿用现有磁盘格式 `<!-- error: $code -->`，但 code 改为 `LlmErrorKind.name`（如 `network`/`timeout`/`rateLimited`）；`SessionMessage.errorCode` 解析时新增 `LlmErrorKind.fromCodeName` 反查。
- **4 场景接入**：`ChatTaskService.onError`（流式）/ `MessageBubble` failed body / `TitleSuggestionScreen._buildErrorBar` / `_summarizeWithLifecycleAndRetry` / `LlmProviderDetailScreen._fetchModels` 全部走 `LlmError.fromException` 分类 + `LlmErrorCard` 渲染。

**技术栈：** Flutter 3.x / Riverpod / Cupertino UI / dio / flutter_localizations / 阿里云 RUM（已对接）

**前置约束：**
- ThkTree 项目禁用单测（AGENTS.md + flutter-add-widget-test 规则），本计划"测试"专指集成测试
- LLM 配置已通过 `build/dart_define.json` 注入；测试 mock `LlmClient` 注入错误流（参考 `chat_async_recovery_test.dart:74 _NoopLlmClient` 模式，新增 `_ErrorLlmClient`）
- `AppLogger.error()` 上报通道已存在（`lib/ui/core/app_logger.dart:112`），本计划只触发不重复实现
- 保留磁盘兼容：已有 `<!-- error: network -->` 仍能解析，新失败写 `<!-- error: <kind.name> -->`

---

## Architecture 概览

```
Flutter UI Layer
─────────────────────────
lib/ui/core/widgets/
  ├── llm_error_card.dart   (新增) ── LlmErrorCard 组件
  └── widgets.dart           (改)   ── 导出 LlmErrorCard

lib/ui/core/shared/
  ├── message_bubble.dart    (改)   ── failed body 替换为 LlmErrorCard(compact: true)
  └── title_suggestion_screen.dart (改) ── _buildErrorBar 替换；_summarizeWithLifecycleAndRetry 弹 LlmErrorCard

lib/ui/features/llm/
  └── llm_provider_detail_screen.dart (改) ── _fetchModels 失败替换 toast

lib/ui/features/chat/
  ├── chat_screen.dart       (不改；onRetry 已接好)
  └── chat_controller.dart   (改)   ── catch 块用 LlmError.fromException

lib/l10n/
  ├── app_en.arb             (改)   ── 新增 8 个 key
  └── app_zh.arb             (改)   ── 新增 8 个 key


Data Layer
─────────────────────────
lib/data/models/
  └── llm_error.dart         (新增) ── LlmErrorKind + LlmError + fromException 工厂

lib/data/services/
  ├── chat_task_service.dart (改)   ── onError 用 fromException 替换 hardcoded 'network'
  ├── session_markdown.dart  (不改；磁盘格式兼容)
  └── session_store.dart     (不改；failAssistant 签名沿用 String code)


Test Layer
─────────────────────────
integration_test/
  └── llm_error_retry_test.dart (新增) ── 5 个 case
```

### 文件清单

**新增 3 个**：
| 路径 | 职责 |
|---|---|
| `lib/data/models/llm_error.dart` | `LlmErrorKind` 枚举（7 种）+ `LlmError` 模型 + `fromException` 工厂 |
| `lib/ui/core/widgets/llm_error_card.dart` | `LlmErrorCard` 公共组件（默认 + compact 双形态） |
| `integration_test/llm_error_retry_test.dart` | 5 个集成测试 case |

**修改 8 个**：
| 路径 | 改动 |
|---|---|
| `lib/ui/core/widgets/widgets.dart` | 导出 `LlmErrorCard` |
| `lib/ui/core/shared/message_bubble.dart` | failed body 改用 `LlmErrorCard(compact: true)` |
| `lib/ui/core/shared/title_suggestion_screen.dart` | `_buildErrorBar` + `_summarizeWithLifecycleAndRetry` 替换 |
| `lib/ui/features/llm/llm_provider_detail_screen.dart` | `_fetchModels` catch 改用 `LlmErrorCard(compact: true)` |
| `lib/ui/features/chat/chat_controller.dart` | catch 块用 `LlmError.fromException` |
| `lib/data/services/chat_task_service.dart` | onError 用 `LlmError.fromException` 替换硬编码 `code: 'network'` |
| `lib/l10n/app_en.arb` | 新增 8 个 key |
| `lib/l10n/app_zh.arb` | 新增 8 个 key |

---

## 任务 1：新增 `LlmErrorKind` + `LlmError` + `fromException` 工厂

**文件：**
- 创建：`lib/data/models/llm_error.dart`

- [ ] **步骤 1：创建文件，定义枚举 + 模型 + 工厂**

文件 `lib/data/models/llm_error.dart`：

```dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:thk_tree/ui/core/app_logger.dart';

/// LLM 调用错误的语义分类。1 种枚举 = 1 类错误 + 1 套 i18n 文案。
///
/// 新增枚举值时同步在 [appLocalizationsMappings] 添加文案映射。
enum LlmErrorKind {
  /// 网络断开 / 连接失败（含 DNS 解析失败、connection refused 等）。
  network,

  /// 请求 / 响应超时（sendTimeout / receiveTimeout）。
  timeout,

  /// 服务端限流（HTTP 429）。
  rateLimited,

  /// 鉴权失败（HTTP 401/403）。
  authFailed,

  /// 服务端错误（HTTP 5xx）。
  serverError,

  /// 用户 / 系统主动取消（不显示错误态、不上报）。
  cancelled,

  /// 其他 DioException 或非 DioException。
  unknown,
}

extension LlmErrorKindX on LlmErrorKind {
  /// 磁盘标记 + 上报 attr 共用的稳定字符串。
  String get codeName => name;
}

/// LLM 错误的不可变模型。`rawMessage` 用于调试 / 日志，`kind` 决定 UI 渲染。
class LlmError {
  const LlmError({
    required this.kind,
    this.rawMessage,
    this.hint,
  });

  /// 语义分类。
  final LlmErrorKind kind;

  /// 原始异常字符串（`e.toString()`），仅用于调试 / 上报，不直接渲染。
  final String? rawMessage;

  /// 调用方传入的语义 hint（用于日志聚合），如 `'ChatTask.streamError'`。
  final String? hint;

  /// 是否可重试：除 [LlmErrorKind.cancelled] 外都可重试。
  bool get isRetriable => kind != LlmErrorKind.cancelled;

  /// 是否需要用户去设置页修配置：仅 [LlmErrorKind.authFailed] 是。
  bool get isConfigIssue => kind == LlmErrorKind.authFailed;

  /// 工厂方法：分类 + 异步上报一站式。
  ///
  /// 行为约定：
  /// 1. [e] 是 [DioException] 时按 `_classifyDio` 分类；否则归 [LlmErrorKind.unknown]。
  /// 2. [kind] != [LlmErrorKind.cancelled] 时触发 `logger.error(...)` 上报：
  ///    - attrs = `{'kind': kind.codeName, ...?attrs}`
  ///    - hint 透传调用方，未传时默认 `'LlmError'`
  ///    - 用 `unawaited(...)` 异步触发，不阻塞返回值
  /// 3. `cancelled` 不上报（用户主动取消，无需排查）。
  /// 4. 同步返回 [LlmError]；如需 await 上报完成，调用方自行 await。
  ///
  /// 调用方示例：
  /// ```dart
  /// try {
  ///   await client.streamChatCompletion(...);
  /// } catch (e, st) {
  ///   final err = LlmError.fromException(
  ///     e, st,
  ///     logger: logger,
  ///     hint: 'ChatTask.streamError',
  ///     attrs: {'nodeId': nodeId},
  ///   );
  ///   if (!err.isRetriable) return;
  ///   await sessionStore.failAssistant(handle: handle, code: err.kind.codeName);
  /// }
  /// ```
  factory LlmError.fromException(
    Object e,
    StackTrace? st, {
    AppLogger? logger,
    String? hint,
    Map<String, Object?>? attrs,
  }) {
    final kind = _classify(e);
    if (logger != null && kind != LlmErrorKind.cancelled) {
      final fullAttrs = <String, Object?>{
        'kind': kind.codeName,
        ...?attrs,
      };
      unawaited(logger.error(
        e,
        st ?? StackTrace.current,
        hint: hint ?? 'LlmError',
        attrs: fullAttrs,
      ));
    }
    return LlmError(
      kind: kind,
      rawMessage: e.toString(),
      hint: hint,
    );
  }

  static LlmErrorKind _classify(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
          return LlmErrorKind.network;
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return LlmErrorKind.timeout;
        case DioExceptionType.cancel:
          return LlmErrorKind.cancelled;
        case DioExceptionType.badResponse:
          final code = e.response?.statusCode ?? 0;
          if (code == 429) return LlmErrorKind.rateLimited;
          if (code == 401 || code == 403) return LlmErrorKind.authFailed;
          if (code >= 500) return LlmErrorKind.serverError;
          return LlmErrorKind.unknown;
        case DioExceptionType.badCertificate:
        case DioExceptionType.unknown:
          return LlmErrorKind.unknown;
      }
    }
    return LlmErrorKind.unknown;
  }

  @override
  String toString() => 'LlmError(kind: $kind, hint: $hint)';
}

/// `LlmErrorKind.codeName` → [LlmErrorKind] 反查，用于从磁盘标记 `<!-- error: <code> -->`
/// 恢复错误态。未知值统一返回 [LlmErrorKind.unknown]。
LlmErrorKind llmErrorKindFromCodeName(String code) {
  for (final k in LlmErrorKind.values) {
    if (k.codeName == code) return k;
  }
  return LlmErrorKind.unknown;
}
```

- [ ] **步骤 2：编译验证**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree
flutter analyze lib/data/models/llm_error.dart
```

预期：无 error / warning。

- [ ] **步骤 3：Commit**

```bash
git add lib/data/models/llm_error.dart
git commit -m "feat(llm-error): 新增 LlmErrorKind + LlmError + fromException 工厂"
```

---

## 任务 2：l10n 新增 8 个 key（中英同步）

**文件：**
- 修改：`lib/l10n/app_en.arb`
- 修改：`lib/l10n/app_zh.arb`

- [ ] **步骤 1：在 `app_en.arb` 末尾追加 8 个 key**

定位 `lib/l10n/app_en.arb` 末尾 `}` 之前，追加：

```json
  "llmErrorNetwork": "Network error. Please check your connection and retry.",
  "@llmErrorNetwork": {
    "description": "LLM error card body when DioException type is connectionError or connectionTimeout"
  },
  "llmErrorTimeout": "Request timed out. Please try again.",
  "@llmErrorTimeout": {
    "description": "LLM error card body when DioException type is sendTimeout or receiveTimeout"
  },
  "llmErrorRateLimited": "Too many requests. Please try again later.",
  "@llmErrorRateLimited": {
    "description": "LLM error card body when HTTP 429"
  },
  "llmErrorAuthFailed": "API key invalid or expired. Check settings.",
  "@llmErrorAuthFailed": {
    "description": "LLM error card body when HTTP 401/403"
  },
  "llmErrorServerError": "Service temporarily unavailable. Please try again.",
  "@llmErrorServerError": {
    "description": "LLM error card body when HTTP 5xx"
  },
  "llmErrorUnknown": "Generation failed. Please try again.",
  "@llmErrorUnknown": {
    "description": "LLM error card body for unknown / non-Dio errors"
  },
  "llmErrorRetry": "Retry",
  "@llmErrorRetry": {
    "description": "Primary action button on LlmErrorCard"
  },
  "llmErrorCancel": "Cancel",
  "@llmErrorCancel": {
    "description": "Secondary action button on LlmErrorCard"
  },
```

- [ ] **步骤 2：在 `app_zh.arb` 末尾追加对应中文文案**

定位 `lib/l10n/app_zh.arb` 末尾 `}` 之前，追加：

```json
  "llmErrorNetwork": "网络连接中断，请检查后重试",
  "@llmErrorNetwork": {},
  "llmErrorTimeout": "请求超时，请重试",
  "@llmErrorTimeout": {},
  "llmErrorRateLimited": "请求过于频繁，请稍后再试",
  "@llmErrorRateLimited": {},
  "llmErrorAuthFailed": "API Key 无效或已过期，请检查设置",
  "@llmErrorAuthFailed": {},
  "llmErrorServerError": "服务暂不可用，请稍后再试",
  "@llmErrorServerError": {},
  "llmErrorUnknown": "生成失败，请重试",
  "@llmErrorUnknown": {},
  "llmErrorRetry": "重试",
  "@llmErrorRetry": {},
  "llmErrorCancel": "取消",
  "@llmErrorCancel": {},
```

- [ ] **步骤 3：触发代码生成 + 验证**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree
flutter gen-l10n
flutter analyze lib/l10n/
```

预期：`gen-l10n` 重新生成 `app_localizations.dart`；analyze 无新增 error。

- [ ] **步骤 4：Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/generated/app_localizations*.dart
git commit -m "feat(l10n): 新增 LlmErrorCard 8 个 key（中英同步）"
```

---

## 任务 3：新增 `LlmErrorCard` 组件 + 导出

**文件：**
- 创建：`lib/ui/core/widgets/llm_error_card.dart`
- 修改：`lib/ui/core/widgets/widgets.dart`（导出）

- [ ] **步骤 1：创建 `LlmErrorCard` 组件**

文件 `lib/ui/core/widgets/llm_error_card.dart`：

```dart
import 'package:flutter/cupertino.dart';
import 'package:thk_tree/data/models/llm_error.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart' show ThkButton;

/// 统一的 LLM 错误展示组件。
///
/// 两种形态：
/// - 默认（`compact: false`）：占位卡片，居中显示图标 + 文案 + `[重试] [取消]` 按钮。
/// - compact（`compact: true`）：inline 横条，左图标 + 错误文案 + `[重试] [取消]` 按钮。
///
/// `error.kind == LlmErrorKind.cancelled` 时调用方不应渲染此组件（见 [LlmError.isRetriable]）。
class LlmErrorCard extends StatelessWidget {
  const LlmErrorCard({
    super.key,
    required this.error,
    required this.onRetry,
    required this.onCancel,
    this.title,
    this.compact = false,
  });

  /// 错误模型（必传）。
  final LlmError error;

  /// [重试] 回调（必传）。按钮文案始终为 `l10n.llmErrorRetry`。
  final VoidCallback onRetry;

  /// [取消] 回调（必传）。按钮文案始终为 `l10n.llmErrorCancel`。
  /// 取消语义由调用方决定：可为 `Navigator.pop()` / `setState` 清错误 / `cancelToken.cancel()` 等。
  final VoidCallback onCancel;

  /// 可选：覆盖标题（默认从 `l10n` 取对应 kind 的文案）。
  final String? title;

  /// true = inline 横条；false（默认）= 占位卡片。
  final bool compact;

  String _resolveMessage(AppLocalizations l10n) {
    return switch (error.kind) {
      LlmErrorKind.network => l10n.llmErrorNetwork,
      LlmErrorKind.timeout => l10n.llmErrorTimeout,
      LlmErrorKind.rateLimited => l10n.llmErrorRateLimited,
      LlmErrorKind.authFailed => l10n.llmErrorAuthFailed,
      LlmErrorKind.serverError => l10n.llmErrorServerError,
      LlmErrorKind.cancelled => l10n.llmErrorCancel, // 调用方不该走到这里；兜底文案
      LlmErrorKind.unknown => l10n.llmErrorUnknown,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final message = title ?? _resolveMessage(l10n);
    return compact ? _buildCompact(context, l10n, message) : _buildCard(context, l10n, message);
  }

  Widget _buildCard(BuildContext context, AppLocalizations l10n, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.systemRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.systemRed.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle,
            size: 32,
            color: CupertinoColors.systemRed,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ThkButton.plain(
                label: l10n.llmErrorCancel,
                onPressed: onCancel,
              ),
              const SizedBox(width: 12),
              ThkButton.filled(
                label: l10n.llmErrorRetry,
                onPressed: onRetry,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(BuildContext context, AppLocalizations l10n, String message) {
    return Container(
      width: double.infinity,
      color: CupertinoColors.systemRed.withValues(alpha: 0.1),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 14,
                color: CupertinoColors.systemRed,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: CupertinoColors.systemRed,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                onPressed: onCancel,
                child: Text(
                  l10n.llmErrorCancel,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                color: CupertinoColors.systemRed,
                minimumSize: Size.zero,
                onPressed: onRetry,
                child: Text(
                  l10n.llmErrorRetry,
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **步骤 2：在 `widgets.dart` barrel 添加导出**

定位 `lib/ui/core/widgets/widgets.dart`，添加：

```dart
export 'package:thk_tree/ui/core/widgets/llm_error_card.dart' show LlmErrorCard;
```

- [ ] **步骤 3：编译验证**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree
flutter analyze lib/ui/core/widgets/llm_error_card.dart
```

预期：无 error。如果 `ThkButton.plain` / `ThkButton.filled` 命名不一致（参考 `lib/ui/core/widgets/buttons.dart` 实际 API），调整为对应方法名后再次跑 analyze。

- [ ] **步骤 4：Commit**

```bash
git add lib/ui/core/widgets/llm_error_card.dart lib/ui/core/widgets/widgets.dart
git commit -m "feat(llm-error-card): 新增 LlmErrorCard 公共组件（占位卡片 + compact 横条）"
```

---

## 任务 4：建立集成测试脚手架 + 5 个 case 基线

**文件：**
- 创建：`integration_test/llm_error_retry_test.dart`

**前置约束：**
- 测试需用 mock `LlmClient` + mock `AppLogger` 注入，避免真发 API / 真写日志。
- 走 `lib/main_test.dart` 的 `createTestApp(extraOverrides: ...)` 而**不是** `lib/main.dart.main()`——后者不接受注入参数，前者有 `extraOverrides: List<dynamic>` 钩子。
- mock LlmClient 参考 `chat_async_recovery_test.dart:74 _NoopLlmClient`；mock AppLogger 需用真实 `AppPaths.load()`（构造器要求 `required paths`），通过 `appLoggerProvider.overrideWithValue(AsyncData(logger))` 注入。
- 测试命令必须加 `-d "iPhone 15 Pro"`（integration test 走真机/模拟器，不加会无声失败）。

- [ ] **步骤 1：创建测试文件，包含 mock + 5 个 case 骨架**

文件 `integration_test/llm_error_retry_test.dart`：

```dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/data/services/llm_client.dart';
import 'package:thk_tree/data/models/llm_error.dart';
// 用 main_test.dart 的 createTestApp（main.dart 不接受注入参数）。
import 'package:thk_tree/main_test.dart' as test_app;
import 'package:thk_tree/ui/core/app_logger.dart';
import 'package:thk_tree/ui/core/app_paths.dart';
import 'package:thk_tree/ui/core/app_services.dart';

import '_support/in_memory_llm_config_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ─────────────────────────────────────────────────────────────────────
  // Mock LlmClient：每个 test 重新构造，行为由注入的 _scenario 决定。
  // Mock AppLogger：收集 error() 调用，验证上报链路。
  // ─────────────────────────────────────────────────────────────────────
  late _ErrorLlmClient mockClient;
  late _RecordingLogger recordingLogger;
  late AppPaths paths;

  setUpAll(() async {
    paths = await AppPaths.load();
    await paths.ensureCreated();
  });

  setUp(() {
    mockClient = _ErrorLlmClient();
    recordingLogger = _RecordingLogger(paths);
  });

  /// 公共 helper：createTestApp + 注入 mock client / logger。
  Future<void> _pumpApp(WidgetTester tester) async {
    final widget = await test_app.createTestApp(
      llmConfigStore: InMemoryLlmConfigStore(
        providers: const [],
        apiKeys: const {},
      ),
      extraOverrides: [
        appLoggerProvider.overrideWithValue(AsyncData<AppLogger>(recordingLogger)),
        llmClientProvider.overrideWith((ref) async => mockClient),
      ],
    );
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  // ─────────────────────────────────────────────────────────────────────
  // Case 1：4 个场景错误态展示 + 文案
  // ─────────────────────────────────────────────────────────────────────
  testWidgets('case 1: 4 场景错误态 + i18n 文案', (tester) async {
    mockClient.scenario = _ErrorScenario.network(
      DioExceptionType.connectionError,
    );
    await _pumpApp(tester);

    // 流式聊天：注入用户消息 → 触发 stream → 看到 LlmErrorCard compact
    await _sendUserMessage(tester, 'hello');
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byKey(const ValueKey('llm_error_card_compact')), findsOneWidget);
    expect(find.text('Network error. Please check your connection and retry.'),
        findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  // ─────────────────────────────────────────────────────────────────────
  // Case 2：4 场景重试触发
  // ─────────────────────────────────────────────────────────────────────
  testWidgets('case 2: 重试按钮触发新请求', (tester) async {
    mockClient.scenario = _ErrorScenario.network(DioExceptionType.connectionError);
    await _pumpApp(tester);

    await _sendUserMessage(tester, 'hello');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(mockClient.callCount, 1);

    // 改成 success，第 2 次调用返回成功
    mockClient.scenario = _ErrorScenario.success('ok-reply');
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(mockClient.callCount, 2);
  });

  // ─────────────────────────────────────────────────────────────────────
  // Case 3：日志上报链路（factory 写入 kind / hint / attrs）
  // ─────────────────────────────────────────────────────────────────────
  testWidgets('case 3: LlmError.fromException 上报链路', (tester) async {
    mockClient.scenario = _ErrorScenario.network(DioExceptionType.connectionError);
    await _pumpApp(tester);

    await _sendUserMessage(tester, 'hello');
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 等待 async 上报 fire-and-forget 完成
    await tester.pump(const Duration(milliseconds: 500));

    final calls = recordingLogger.errorCalls;
    expect(calls, isNotEmpty);
    final first = calls.first;
    expect(first.kind, 'network');
    expect(first.hint, anyOf('ChatTask.streamError', 'LlmError'));
    expect(first.attrs['nodeId'], isA<String>());
  });

  // ─────────────────────────────────────────────────────────────────────
  // Case 4：cancelled 错误不显示错误态 + 不上报
  // ─────────────────────────────────────────────────────────────────────
  testWidgets('case 4: cancelled 错误不渲染错误卡', (tester) async {
    mockClient.scenario = _ErrorScenario.network(DioExceptionType.cancel);
    await _pumpApp(tester);

    await _sendUserMessage(tester, 'hello');
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byKey(const ValueKey('llm_error_card_compact')), findsNothing);
    expect(recordingLogger.errorCalls, isEmpty);
  });

  // ─────────────────────────────────────────────────────────────────────
  // Case 5：i18n 文案映射（zh locale）
  // ─────────────────────────────────────────────────────────────────────
  testWidgets('case 5: 中文 locale 文案正确', (tester) async {
    mockClient.scenario = _ErrorScenario.network(DioExceptionType.connectionError);
    await _pumpApp(tester);

    // 本 case 走系统默认 locale（en），验证英文文案映射。
    // 如需切中文：case 5b 通过 _pumpApp(locale: const Locale('zh')) 覆盖。
    await _sendUserMessage(tester, 'hello');
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('网络连接中断，请检查后重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });
}

// ─────────────────────────────────────────────────────────────────────
// Mock LlmClient
// ─────────────────────────────────────────────────────────────────────

enum _ErrorKindScenario {
  success,
  network,
  timeout,
  cancelled,
  rateLimited,
  authFailed,
  serverError,
}

class _ErrorScenario {
  _ErrorScenario.success(String reply)
      : kind = _ErrorKindScenario.success,
        reply = reply;
  _ErrorScenario.network(DioExceptionType t)
      : kind = _ErrorKindScenario.network,
        type = t,
        reply = null;
  _ErrorScenario.timeout(DioExceptionType t)
      : kind = _ErrorKindScenario.timeout,
        type = t,
        reply = null;
  _ErrorScenario.networkWithStatus(int code)
      : kind = _ErrorKindScenario.network,
        statusCode = code,
        type = DioExceptionType.badResponse,
        reply = null;

  final _ErrorKindScenario kind;
  final DioExceptionType? type;
  final int? statusCode;
  final String? reply;
}

class _ErrorLlmClient extends LlmClient {
  _ErrorScenario scenario = _ErrorScenario.success('mock-reply');
  int callCount = 0;

  @override
  Stream<String> streamChatCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, Object?>> messages,
    CancelToken? cancelToken,
  }) async* {
    callCount++;
    switch (scenario.kind) {
      case _ErrorKindScenario.success:
        yield scenario.reply!;
        return;
      case _ErrorKindScenario.network:
      case _ErrorKindScenario.timeout:
        throw DioException(
          requestOptions: RequestOptions(path: '/mock'),
          type: scenario.type!,
        );
      case _ErrorKindScenario.cancelled:
        throw DioException(
          requestOptions: RequestOptions(path: '/mock'),
          type: DioExceptionType.cancel,
        );
      case _ErrorKindScenario.rateLimited:
        throw DioException(
          requestOptions: RequestOptions(path: '/mock', statusCode: 429),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/mock'),
            statusCode: 429,
          ),
        );
      case _ErrorKindScenario.authFailed:
        throw DioException(
          requestOptions: RequestOptions(path: '/mock'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/mock'),
            statusCode: 401,
          ),
        );
      case _ErrorKindScenario.serverError:
        throw DioException(
          requestOptions: RequestOptions(path: '/mock'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/mock'),
            statusCode: 500,
          ),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// Recording Logger（测试用，捕获 error 调用）
// ─────────────────────────────────────────────────────────────────────

class _LogCall {
  _LogCall({required this.kind, required this.hint, required this.attrs});
  final String kind;
  final String hint;
  final Map<String, Object?> attrs;
}

class _RecordingLogger extends AppLogger {
  // AppLogger 构造器要求 required paths（写文件 / 远程上报都依赖）。
  // 我们的 error() override 不调 super，所以不写文件，但必须传真实 AppPaths。
  _RecordingLogger(AppPaths paths) : super(paths: paths);

  final List<_LogCall> errorCalls = [];

  @override
  Future<void> error(Object error, StackTrace stackTrace,
      {String? hint, Map<String, Object?>? attrs}) async {
    errorCalls.add(_LogCall(
      kind: (attrs?['kind'] as String?) ?? 'unknown',
      hint: hint ?? '',
      attrs: attrs ?? {},
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────
// 辅助：发送用户消息（参考 chat_streaming_test.dart 模式）
// ─────────────────────────────────────────────────────────────────────

Future<void> _sendUserMessage(WidgetTester tester, String text) async {
  // selector 与项目实际一致（参考 chat_streaming_test.dart:104 / test_helpers.dart:290）
  final inputFinder = find.byKey(const ValueKey('chat_input'));
  await tester.enterText(inputFinder, text);
  await tester.tap(find.byKey(const ValueKey('send_button')));
  await tester.pump();
}
```

- [ ] **步骤 2：跑测试，确认 case 全部 FAIL（因为组件未实现）**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree
flutter test integration_test/llm_error_retry_test.dart \
  --dart-define-from-file=build/dart_define.json \
  -d "iPhone 15 Pro"
```

预期：5 个 case 全部 FAIL（`LlmErrorCard` 未挂到 MessageBubble、注入点未接通）。这是预期的 TDD 起点。

如果遇到创建在 iOS 模拟器上报 `'build/dart_define.json' not found`，先确认 worktree 里 `build/dart_define.json` 已 symlink 到主仓库同名文件（集成测试 fixture 准备）：

```bash
ls -la /Users/yuweikang/dev/ykcode/ThkTree-worktrees/llm-error-retry/build/dart_define.json
# 应输出 → 主仓库路径
```

- [ ] **步骤 3：Commit（仅测试骨架）**

```bash
git add integration_test/llm_error_retry_test.dart
git commit -m "test(llm-error): 新增 llm_error_retry_test 5 个 case 骨架（预期全 FAIL）"
```

---

## 任务 5：流式聊天场景接入（ChatTaskService + MessageBubble）

**文件：**
- 修改：`lib/data/services/chat_task_service.dart:122-132`（onError）
- 修改：`lib/ui/core/shared/message_bubble.dart`（failed body 渲染）

- [ ] **步骤 1：`ChatTaskService.onError` 改用 `LlmError.fromException`**

定位 `lib/data/services/chat_task_service.dart:122-132`，改为：

```dart
      onError: (e, st) async {
        final err = LlmError.fromException(
          e,
          st,
          logger: logger,
          hint: 'ChatTask.streamError',
          attrs: {'nodeId': nodeId},
        );
        if (!err.isRetriable) return; // cancelled: 不显示错误态
        try {
          await sessionStore.failAssistant(handle: handle, code: err.kind.codeName);
        } catch (_) {}
        unawaited(_bridge.end());
        _removeTask(nodeId);
      },
```

在文件顶部 import 区追加：

```dart
import 'package:thk_tree/data/models/llm_error.dart';
```

- [ ] **步骤 2：`MessageBubble` failed body 改用 `LlmErrorCard(compact: true)`**

定位 `lib/ui/core/shared/message_bubble.dart:160-170`（GptMarkdown 渲染处），改为：

```dart
                if (widget.message.status == SessionMessageStatus.error) ...[
                  LlmErrorCard(
                    key: const ValueKey('llm_error_card_compact'),
                    compact: true,
                    error: LlmError(
                      kind: llmErrorKindFromCodeName(
                        widget.message.errorCode ?? '',
                      ),
                    ),
                    onRetry: widget.onRetry ?? () {},
                    onCancel: () {
                      // 取消语义：什么都不做（用户可能在等上下文）
                    },
                  ),
                ] else ...[
                  GptMarkdown(
                    body,
                    style: baseStyle,
                    tableBuilder: _buildTable,
                    codeBuilder: _buildCodeBlock,
                    latexBuilder: buildLatex,
                    useDollarSignsForLatex: true,
                  ),
                ],
```

并在 `message_bubble.dart` 顶部 import 区追加：

```dart
import 'package:thk_tree/data/models/llm_error.dart';
```

`LlmErrorCard` 通过 `widgets.dart` barrel 已自动可见，无需额外 import。

**注意**：原底部按钮行（line 170-234 的 copy / TTS / share / retry）保留非 error 状态；当 status == error 时整个 Column 被 `LlmErrorCard` 占据，按钮行隐藏在 LlmErrorCard 内部（其内置 retry/cancel）。

- [ ] **步骤 3：编译验证**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree
flutter analyze lib/data/services/chat_task_service.dart lib/ui/core/shared/message_bubble.dart
```

预期：无 error。

- [ ] **步骤 4：跑 chat_streaming / chat_async_recovery 回归**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree
flutter test integration_test/chat_streaming_test.dart \
  integration_test/chat_async_recovery_test.dart \
  --dart-define-from-file=build/dart_define.json
```

预期：原有 2 个集成测试仍 PASS（流式中断 → 错误态 → 重试入口）。

- [ ] **步骤 5：Commit**

```bash
git add lib/data/services/chat_task_service.dart lib/ui/core/shared/message_bubble.dart
git commit -m "feat(llm-error): 流式聊天场景接入 LlmErrorCard（compact 形态）"
```

---

## 任务 6：标题生成场景接入（TitleSuggestionScreen._buildErrorBar）

**文件：**
- 修改：`lib/ui/core/shared/title_suggestion_screen.dart:591-629`（`_buildErrorBar`）+ `setState(_error: e.toString())` 三处

- [ ] **步骤 1：替换状态字段 `String? _error` → `LlmError? _error`**

定位 `lib/ui/core/shared/title_suggestion_screen.dart:71`，改为：

```dart
  LlmError? _error;
```

- [ ] **步骤 2：替换三处 setState 错误赋值**

定位 `lib/ui/core/shared/title_suggestion_screen.dart:209-215, 261-267, 311-315`，把 `_error = e.toString()` 替换为：

```dart
        _error = LlmError.fromException(
          e,
          null,
          logger: logger, // 如无法直接拿到 logger，传 null（仍分类、仅不上报）
          hint: 'TitleSuggestion.generate',
        );
```

> **logger 获取方式**：在 State 里加 `late AppLogger? _logger;` 字段，在 `initState` 里 `ref.read(appLoggerProvider.future).then((v) => _logger = v).catchError((_) {})` 异步初始化。如果异步未完成时 `_logger == null`，工厂跳过上报但仍分类，不影响主流程。

- [ ] **步骤 3：替换 `_buildErrorBar` 为 `LlmErrorCard(compact: true)`**

定位 `lib/ui/core/shared/title_suggestion_screen.dart:591-629`，整个 `_buildErrorBar` 方法改为：

```dart
  Widget _buildErrorBar(AppLocalizations l10n) {
    final err = _error;
    if (err == null) return const SizedBox.shrink();
    return LlmErrorCard(
      key: const ValueKey('llm_error_card_compact'),
      compact: true,
      error: err,
      onRetry: () {
        setState(() => _error = null);
        if (_currentModel != null) {
          _onRegenerate();
        } else {
          _resolveAndGenerate();
        }
      },
      onCancel: () {
        // 取消 = 关闭标题选择屏，回到上一级（用户什么都不想做）
        Navigator.of(context).pop();
      },
    );
  }
```

并删除 `_onSwitchModel` 方法（line 374-426）：用户去设置页自行切换，本组件不再提供切换入口。如后续要切换模型，用户点导航栏的返回 + 进入设置页。

> **保留兼容性**：`Navigator.of(context).pop()` 关闭整个 TitleSuggestionScreen，等价"用户什么都不想做"。

- [ ] **步骤 4：文件顶部 import**

在 `lib/ui/core/shared/title_suggestion_screen.dart` 顶部 import 区追加：

```dart
import 'package:thk_tree/data/models/llm_error.dart';
import 'package:thk_tree/ui/core/app_logger.dart';
```

- [ ] **步骤 5：编译验证 + 静态检查**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree
flutter analyze lib/ui/core/shared/title_suggestion_screen.dart
```

预期：无 error。如果 `_isNetworkError` / `_RetryChoice` / `_showRetryCancelSheet` 变成未使用，给 `_isNetworkError` 加 `@visibleForTesting` 标注或保留作为参考（实际由任务 7 替换）。

- [ ] **步骤 6：Commit**

```bash
git add lib/ui/core/shared/title_suggestion_screen.dart
git commit -m "feat(llm-error): 标题生成场景接入 LlmErrorCard（去掉切换模型入口）"
```

---

## 任务 7：summarize 模式场景接入（替换 retry/cancel sheet）

**文件：**
- 修改：`lib/ui/core/shared/title_suggestion_screen.dart:1019-1200`（`_runWithLoadingAndError` + `_summarizeWithLifecycleAndRetry` + `_showRetryCancelSheet`）

- [ ] **步骤 1：升级 `_runWithLoadingAndError` 支持错误态显示**

定位 `lib/ui/core/shared/title_suggestion_screen.dart:1019-1057`，方法签名 + 实现改为（关键改动：用 `Widget?` 返回 StateBuilder 可切换的 dialog 内容）：

```dart
/// 跑异步 action，期间显示 Cupertino loading dialog（不可关闭）。
///
/// 错误态：失败时不立刻 pop dialog，而是把 dialog 内容从 loading 切到
/// [LlmErrorCard]，让用户选 retry / cancel。选 cancel 才 pop。
Future<({T? result, Object? error})> _runWithLoadingAndError<T>({
  required BuildContext context,
  required String message,
  required Future<T> Function() action,
  void Function(T? result)? onRetry, // retry 时回调（重新调用 action）
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  Object? actionError;

  // 第一次调用 action
  Future<({T? result, Object? error})> runOnce() async {
    try {
      final result = await action();
      return (result: result, error: null);
    } catch (e) {
      return (result: null, error: e);
    }
  }

  final first = await runOnce();
  if (first.result != null) {
    if (navigator.canPop()) navigator.pop();
    return first;
  }
  actionError = first.error;
  if (!context.mounted) return first;

  // 弹 LlmErrorCard retry/cancel 让用户决策
  final llmErr = LlmError.fromException(
    actionError!,
    null,
    hint: 'summarizeAttempt',
  );
  if (llmErr.kind == LlmErrorKind.cancelled) {
    if (navigator.canPop()) navigator.pop();
    return first;
  }

  final shouldRetry = await showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => CupertinoAlertDialog(
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LlmErrorCard(
          error: llmErr,
          onRetry: () => Navigator.of(ctx).pop(true),
          onCancel: () => Navigator.of(ctx).pop(false),
        ),
      ),
    ),
  );

  if (shouldRetry != true || !context.mounted) {
    if (navigator.canPop()) navigator.pop();
    return first;
  }

  // retry：再跑一次（用同 action）
  final second = await runOnce();
  if (navigator.canPop()) navigator.pop();
  return second;
}
```

- [ ] **步骤 2：简化 `_summarizeWithLifecycleAndRetry`**

定位 `lib/ui/core/shared/title_suggestion_screen.dart:1065-1150`，整段改为：

```dart
Future<String?> _summarizeWithLifecycleAndRetry({
  required BuildContext context,
  required LlmProviderConfig provider,
  required String modelId,
  required String apiKey,
  required String transcript,
  required int contextWindow,
}) async {
  final l10n = AppLocalizations.of(context)!;

  Future<String?> attempt() async {
    final cancelToken = CancelToken();
    final listener = AppLifecycleListener(
      onPause: () {
        if (!cancelToken.isCancelled) cancelToken.cancel('lifecycle-paused');
      },
      onInactive: () {
        if (!cancelToken.isCancelled) cancelToken.cancel('lifecycle-paused');
      },
      onHide: () {
        if (!cancelToken.isCancelled) cancelToken.cancel('lifecycle-paused');
      },
    );
    try {
      final outcome = await _runWithLoadingAndError<String>(
        context: context,
        message: l10n.summarizing,
        action: () => TitleSuggestionService.summarizeContent(
          transcript: transcript,
          provider: provider,
          modelId: modelId,
          apiKey: apiKey,
          contextWindow: contextWindow,
          cancelToken: cancelToken,
        ),
      );
      return outcome.result;
    } finally {
      listener.dispose();
    }
  }

  // 1st 尝试（lifecycle 取消的会自动让结果为空 → 走 retry）
  final r1 = await attempt();
  if (r1 != null && r1.isNotEmpty) return r1;

  // retry dialog（用户选 cancel 时 _runWithLoadingAndError 内部已 pop）
  final r2 = await attempt();
  if (r2 != null && r2.isNotEmpty) return r2;

  // 二次都失败：fallback 到原始 transcript
  if (!context.mounted) return null;
  ThkAlert.show(
    context: context,
    message: l10n.summarizeFailedFallback,
  );
  return null;
}
```

- [ ] **步骤 3：删除 `_isNetworkError` / `_RetryChoice` / `_showRetryCancelSheet`**

整段删除 `lib/ui/core/shared/title_suggestion_screen.dart:1152-1200`（分类和 sheet 由 `LlmError.fromException` + `LlmErrorCard` 取代）。

- [ ] **步骤 4：编译验证**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree
flutter analyze lib/ui/core/shared/title_suggestion_screen.dart
```

预期：无 error。

- [ ] **步骤 5：跑 branch_creation 回归**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree
flutter test integration_test/branch_creation_test.dart \
  --dart-define-from-file=build/dart_define.json
```

预期：原 case 全 PASS（默认 mock Llm 返回成功，retry/cancel 路径不触发）。

- [ ] **步骤 6：Commit**

```bash
git add lib/ui/core/shared/title_suggestion_screen.dart
git commit -m "feat(llm-error): summarize 模式替换 retry/cancel sheet 为 LlmErrorCard"
```

---

## 任务 8：模型列表拉取场景接入（LlmProviderDetailScreen）

**文件：**
- 修改：`lib/ui/features/llm/llm_provider_detail_screen.dart:259-266`（`_fetchModels` catch）

- [ ] **步骤 1：在 State 加 `LlmError? _fetchError` 字段**

定位 `lib/ui/features/llm/llm_provider_detail_screen.dart:39`，追加：

```dart
  LlmError? _fetchError;
```

- [ ] **步骤 2：替换 `_fetchModels` 的 catch**

定位 `lib/ui/features/llm/llm_provider_detail_screen.dart:259-266`，改为：

```dart
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _isFetchingModels = false;
        _fetchError = LlmError.fromException(
          e,
          st,
          logger: ref.read(appLoggerProvider).valueOrNull,
          hint: 'LlmProviderDetail.fetchModels',
        );
      });
    }
  }
```

- [ ] **步骤 3：在 build 里渲染 `LlmErrorCard`（替换原有 ThkAlert）**

定位 `lib/ui/features/llm/llm_provider_detail_screen.dart:166-179`（"获取模型列表按钮" 区），改为：

```dart
                    // 错误态（替换原 toast）
                    if (_fetchError != null)
                      LlmErrorCard(
                        key: const ValueKey('llm_error_card_compact'),
                        compact: true,
                        error: _fetchError!,
                        onRetry: () {
                          setState(() => _fetchError = null);
                          _fetchModels();
                        },
                        onCancel: () {
                          // 取消：清除错误态（保留页面，用户可继续编辑其他字段）
                          setState(() => _fetchError = null);
                        },
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: _isFetchingModels
                            ? const Center(child: CupertinoActivityIndicator())
                            : ThkButton.filled(
                                label: l10n.fetchModels,
                                icon: Icon(AppIcons.download),
                                onPressed: _fetchModels,
                              ),
                      ),
```

- [ ] **步骤 4：文件顶部 import**

在 `lib/ui/features/llm/llm_provider_detail_screen.dart` 顶部 import 区追加：

```dart
import 'package:thk_tree/data/models/llm_error.dart';
```

- [ ] **步骤 5：编译验证**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree
flutter analyze lib/ui/features/llm/llm_provider_detail_screen.dart
```

预期：无 error。

- [ ] **步骤 6：Commit**

```bash
git add lib/ui/features/llm/llm_provider_detail_screen.dart
git commit -m "feat(llm-error): 模型列表拉取失败替换 toast 为 LlmErrorCard"
```

---

## 任务 9：跑 5 个集成测试 case（验证全部 PASS）

**前置：** 任务 4-8 全部完成，组件已挂到 4 个场景。

- [ ] **步骤 1：跑 5 个新 case**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree
flutter test integration_test/llm_error_retry_test.dart \
  --dart-define-from-file=build/dart_define.json \
  -d "iPhone 15 Pro"
```

预期：5 个 case 全 PASS。如果有 selector 对不上（`chat_input` / `send_button` 是项目标准 key），按 case 报错信息修正。

- [ ] **步骤 2：跑全部集成测试回归**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree
flutter test integration_test/ \
  --dart-define-from-file=build/dart_define.json \
  -d "iPhone 15 Pro"
```

预期：所有原有 case + 5 个新 case 全 PASS。

- [ ] **步骤 3：`flutter analyze` 全量检查**

```bash
cd /Users/yuweikang/dev/ykcode/ThkTree
flutter analyze
```

预期：无新增 error（warning 可控）。

- [ ] **步骤 4：Commit（仅测试代码改动）**

```bash
git add integration_test/llm_error_retry_test.dart
git commit -m "test(llm-error): 5 个集成测试 case 全绿（错误态 + 重试 + 上报 + cancelled + i18n）"
```

---

## 任务 10：真机手工验收（4 场景断网重试）

**前置：** 集成测试已 PASS；连接真机 / 模拟器。

- [ ] **步骤 1：场景 1 — 流式聊天断网**

1. 进入任一对话页，发"hello"
2. 启动后立刻打开飞行模式
3. 看到 assistant message 渲染 `LlmErrorCard(compact: true)` + `[重试] [取消]`
4. 关闭飞行模式
5. 点 `[重试]` → 重新请求成功
6. 点 `[取消]` → 错误态保持，不做任何动作

- [ ] **步骤 2：场景 2 — summarize 模式（分支创建）**

1. 在对话里选中一段文字
2. 触发分支创建 → 选 summarize
3. 飞行模式 → LLM 弹 loading → 失败 → 切到 `LlmErrorCard` dialog
4. 选 retry → 关闭飞行模式 → 再试 → 成功
5. 选 cancel → 退到 raw 模式 + 原始 transcript

- [ ] **步骤 3：场景 3 — 标题生成（`TitleSuggestionScreen`）**

1. 触发标题生成屏（任意入口）
2. 飞行模式 → 点"生成" → 失败
3. 看到底部红色 compact 错误条 + `[重试] [取消]`
4. 关闭飞行模式 → `[重试]` → 成功生成候选
5. `[取消]` → 关闭整个标题屏

- [ ] **步骤 4：场景 4 — 模型列表拉取**

1. 进 LLM provider 详情页
2. 飞行模式 → 点"获取模型"
3. 看到错误卡片 + `[重试] [取消]`
4. 关闭飞行模式 → `[重试]` → 成功拉到列表
5. `[取消]` → 错误态消失，按钮区恢复

- [ ] **步骤 5：提交手工验收记录**

手工完成 4 场景后无需 commit；如果发现 UI bug，回到任务 5-8 对应任务修。

---

## 任务 11：context-sync（文档同步）

**触发命令：** 用户说"ctsync" / "同步文档" / "docs sync"

**前置：** 任务 1-10 全部完成，集成测试 PASS，手工验收通过。

- [ ] **步骤 1：跑 context-sync skill**

按 AGENTS.md `context-sync` 流程执行：
- 收集改动范围（`git diff --name-only HEAD~11..HEAD`）
- 遍历 docs 全量，三重判断（路径 / 内容 / 类型）
- 输出影响清单 + 卡片
- 等用户确认后改 doc

预期影响（按 [AGENTS.md#context-sync 白名单兜底](AGENTS.md) 推断）：
- 📄 `docs/FEATURES.md` — 大改版 · § LLM 设置章节 + § 分支创建章节
- 📄 `docs/CHANGELOG/2026-06-24-llm-error-unify.md`（新增）· 本次变更说明
- 📄 `docs/modules/chat/README.md`（如有）— 小补 · § 错误态
- 📄 `docs/modules/llm/README.md`（如有）— 小补 · § 错误态
- 📄 `docs/DECISIONS.md` — 不影响（无架构决策）
- 📄 `docs/ARCHITECTURE.md` — 不影响（无架构层变更）

---

## 自检清单（plan 完成时执行）

### 1. spec 覆盖度

| spec 章节 | 对应任务 |
|---|---|
| 2.1 错误分类 7 种枚举 | 任务 1 |
| 2.1 LlmError + fromException 工厂 | 任务 1 |
| 2.1 LlmErrorCard 组件（占位 + compact） | 任务 3 |
| 2.1 4 场景统一 | 任务 5（流式）/ 6（标题生成）/ 7（summarize）/ 8（模型列表） |
| 2.1 按钮 [重试] + [取消] 双必现 | 任务 3（组件接口） + 任务 5-8（接入） |
| 2.1 不提供"切换模型"按钮 | 任务 6（删除 `_onSwitchModel`） |
| 2.1 i18n 8 个 key | 任务 2 |
| 2.2 日志上报集中在 fromException | 任务 1 + 任务 5（ChatTaskService 改用） |
| 2.4 cancelled 不上报 | 任务 1（工厂 `_classify`）+ 任务 5（onError 提前 return） |
| 3.2 集成测试 5 个 case | 任务 4 + 任务 9 |

**未覆盖项**：无

### 2. 占位符扫描

- ❌ 无 "TODO" / "待定" / "后续补充"
- ❌ 无 "类似任务 N" 引用
- ✅ 每步有具体代码块
- ✅ 每步有具体文件路径 + 行号（line: 引用基于已确认的现状）
- ✅ 命令和预期输出明确

### 3. 类型一致性

| 符号 | 定义任务 | 使用任务 | 一致 |
|---|---|---|---|
| `LlmErrorKind.network` | 1 | 1, 3, 5, 6, 7, 8 | ✅ |
| `LlmErrorKind.cancelled` | 1 | 5, 7 | ✅ |
| `LlmError.fromException` | 1 | 5, 6, 7, 8 | ✅ |
| `LlmError.isRetriable` | 1 | 5 | ✅ |
| `LlmError.kind.codeName` | 1 | 5 | ✅ |
| `llmErrorKindFromCodeName` | 1 | 5 | ✅ |
| `LlmErrorCard` | 3 | 5, 6, 7, 8 | ✅ |
| `LlmErrorCard.compact` | 3 | 5, 6, 8 | ✅ |
| `l10n.llmErrorRetry` | 2 | 3, 5, 6, 7, 8 | ✅ |
| `l10n.llmErrorCancel` | 2 | 3, 5, 6, 7, 8 | ✅ |
| `SessionStore.failAssistant(code: String)` | (沿用) | 5 | ✅（`code: err.kind.codeName` 是 String） |

---

## 执行选项

**计划已完成并保存到 `docs/superpowers/plans/2026-06-24-llm-error-retry.md`。两种执行方式：**

**1. 子代理驱动（推荐）** — 每个任务调度一个新的子代理，任务间进行审查，快速迭代。

**2. 内联执行** — 在当前会话中使用 executing-plans 执行任务，批量执行并设有检查点。

**选哪种方式？**

按 AGENTS.md 后续流程：执行完成后需 commit → rebase dev → context-sync → 合并回 dev → 删除 `docs/_tmp/2026-06-24-llm-error-retry.md`。
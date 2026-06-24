# 统一 LLM 错误处理与重试机制

| 属性 | 说明 |
|------|------|
| 日期 | 2026-06-24 |
| 范围 | 跨模块（llm / chat / _shared） |
| 设计文档 | `docs/superpowers/plans/2026-06-24-llm-error-retry.md` |
| 状态 | ✅ 完成（集成测试全绿，真机手工验收跳过） |

## 背景

ThkTree 有 4 个 LLM 调用场景（流式聊天 / summarize / 标题生成 / 模型列表），每个场景各自实现错误处理逻辑：有的用 `ThkAlert`，有的用自定义 retry/cancel sheet，有的用 `toast`。错误分类不统一，日志上报分散，用户看到的错误 UI 也各不相同。

## 方案

新增统一的 `LlmError` 模型 + `LlmErrorCard` 组件，4 个场景统一接入：

- **`LlmErrorKind` 枚举**（7 种）：network / timeout / rateLimited / authFailed / serverError / cancelled / unknown
- **`LlmError.fromException` 工厂**：DioException 自动分类 + 异步上报 AppLogger
- **`LlmErrorCard` 组件**：compact 横条 + 占位卡片两种形态，内置 retry / cancel 回调
- **4 个场景接入**：ChatTaskService / TitleSuggestionScreen / summarize 模式 / LlmProviderDetailScreen

## 实施内容

### 新增文件(2 个)

```
lib/data/models/llm_error.dart              # LlmErrorKind + LlmError + fromException 工厂
lib/ui/core/widgets/llm_error_card.dart     # LlmErrorCard（compact + 占位卡片）
```

### 修改文件(7 个)

```
lib/l10n/app_en.arb                         # 8 个 i18n key（英文）
lib/l10n/app_zh.arb                         # 8 个 i18n key（中文）
lib/ui/core/widgets/widgets.dart            # barrel 导出 LlmErrorCard
lib/data/services/chat_task_service.dart    # onError 用 LlmError.fromException
lib/ui/core/shared/message_bubble.dart      # error status 渲染 LlmErrorCard
lib/ui/core/shared/title_suggestion_screen.dart  # 4 处 catch 改用 LlmError + _buildErrorBar 用 LlmErrorCard
lib/ui/features/llm/llm_provider_detail_screen.dart  # _fetchModels catch 改用 LlmError + UI 渲染 LlmErrorCard
```

### 测试文件(1 个)

```
integration_test/llm_error_retry_test.dart  # 5 个 case（错误态 + 重试 + 上报 + cancelled + i18n）
```

### 关键设计

**`LlmError.fromException` 工厂方法：**
```dart
factory LlmError.fromException(
  Object e, StackTrace? st, {
  AppLogger? logger, String? hint, Map<String, Object?>? attrs,
}) {
  final kind = _classify(e);  // DioException → LlmErrorKind
  if (logger != null && kind != LlmErrorKind.cancelled) {
    unawaited(logger.error(e, st, hint: hint, attrs: {'kind': kind.codeName, ...?attrs}));
  }
  return LlmError(kind: kind, rawMessage: e.toString(), hint: hint);
}
```

**MessageBubble 错误渲染：**
```dart
if (widget.message.status == SessionMessageStatus.error)
  LlmErrorCard(
    key: const ValueKey('llm_error_card_compact'),
    compact: true,
    error: LlmError(kind: llmErrorKindFromCodeName(widget.message.errorCode ?? '')),
    onRetry: widget.onRetry ?? () {},
    onCancel: () {},
  )
```

## 验证

| 类别 | 状态 |
|---|---|
| `flutter analyze` | ✅ 25 issues（全 baseline，无新增） |
| 集成测试 | ✅ 5/5 case 全绿（llm_error_retry_test.dart） |
| 真机手工 | ⏭️ 跳过（用户要求） |

## 关联

- 统一 `session.md` 的 `<!-- error: code -->` 标记（已存在于 chat-async-recovery 分支）
- 与 `LlmErrorKind.codeName` 和 `llmErrorKindFromCodeName()` 配对使用

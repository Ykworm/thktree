import 'dart:async';

import 'package:dio/dio.dart';
import 'package:thk_tree/ui/core/app_logger.dart';

/// LLM 调用错误的语义分类。1 种枚举 = 1 类错误 + 1 套 i18n 文案。
///
/// 新增枚举值时同步在 `app_localizations.dart` 添加文案映射。
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

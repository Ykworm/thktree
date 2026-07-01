import 'dart:convert';
import 'package:yaml/yaml.dart';

enum SessionRole {
  user,
  assistant,
  system,
}

enum SessionMessageStatus {
  done,
  streaming,
  error,
}

class SessionMessage {
  SessionMessage({
    required this.role,
    required this.timestampUtcIso8601,
    required this.msgId,
    required this.body,
    required this.status,
    this.errorCode,
    this.reasoning,
  });

  final SessionRole role;
  final String timestampUtcIso8601;
  final String msgId;
  final String body;
  final SessionMessageStatus status;
  final String? errorCode;
  final String? reasoning;
}

class SessionDocument {
  SessionDocument({
    required this.frontmatter,
    required this.messages,
  });

  final Map<String, Object?> frontmatter;
  final List<SessionMessage> messages;

  /// 对话关联的提供商 ID（可为 null，兼容旧文件）
  String? get providerId => frontmatter['providerId'] as String?;

  /// 对话关联的模型 ID（可为 null，兼容旧文件）
  String? get modelId => frontmatter['modelId'] as String?;

  /// 对话的自定义 system prompt（可为 null，兼容旧文件，fallback 到默认值）
  String get systemPrompt =>
      (frontmatter['systemPrompt'] as String?) ??
          'You are a helpful assistant. Reply in Markdown.';
}

final _messageHeader = RegExp(
  r'^## (user|assistant|system) · ([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z) · (msg_[0-9A-Z]{26})$',
  caseSensitive: false,
);
const _reasoningStartMarker = '<!-- reasoning:start -->';
const _reasoningEndMarker = '<!-- reasoning:end -->';

SessionDocument parseSessionMarkdown(String content) {
  final normalized = content.replaceAll('\r\n', '\n');
  final (frontmatter, bodyStartIndex) = _parseFrontmatter(normalized);
  final body = normalized.substring(bodyStartIndex);
  final messages = _parseMessages(body);
  return SessionDocument(frontmatter: frontmatter, messages: messages);
}

(Map<String, Object?>, int) _parseFrontmatter(String content) {
  if (!content.startsWith('---\n')) {
    throw FormatException('Missing frontmatter start delimiter');
  }

  final endIndex = content.indexOf('\n---\n', 4);
  if (endIndex < 0) {
    throw FormatException('Missing frontmatter end delimiter');
  }

  final yamlText = content.substring(4, endIndex + 1);
  final loaded = loadYaml(yamlText);
  if (loaded is! YamlMap) {
    throw FormatException('Frontmatter is not a map');
  }

  final frontmatter = <String, Object?>{};
  for (final entry in loaded.entries) {
    final key = entry.key;
    if (key is! String) continue;
    frontmatter[key] = _yamlToDart(entry.value);
  }

  final bodyStartIndex = endIndex + '\n---\n'.length;
  return (frontmatter, bodyStartIndex);
}

Object? _yamlToDart(Object? value) {
  if (value is YamlMap) {
    final map = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) continue;
      map[key] = _yamlToDart(entry.value);
    }
    return map;
  }
  if (value is YamlList) {
    return value.map(_yamlToDart).toList(growable: false);
  }
  return value;
}

List<SessionMessage> _parseMessages(String body) {
  final lines = body.split('\n');

  final messages = <SessionMessage>[];
  int? currentHeaderLineIndex;
  SessionRole? currentRole;
  String? currentTimestamp;
  String? currentMsgId;

  void flushMessage(int endLineExclusive) {
    if (currentHeaderLineIndex == null) return;
    final headerLineIndex = currentHeaderLineIndex;
    final role = currentRole!;
    final timestamp = currentTimestamp!;
    final msgId = currentMsgId!;

    final rawBodyLines = lines.sublist(headerLineIndex + 1, endLineExclusive);
    final (status, errorCode, reasoning, bodyLines) =
        _extractStatusAndBody(rawBodyLines);
    final body = bodyLines.join('\n').trimRight();

    messages.add(
      SessionMessage(
        role: role,
        timestampUtcIso8601: timestamp,
        msgId: msgId,
        body: body,
        status: status,
        errorCode: errorCode,
        reasoning: reasoning,
      ),
    );
  }

  for (var i = 0; i < lines.length; i++) {
    final match = _messageHeader.firstMatch(lines[i]);
    if (match == null) continue;

    flushMessage(i);

    currentHeaderLineIndex = i;
    currentRole = switch (match.group(1)) {
      'user' => SessionRole.user,
      'assistant' => SessionRole.assistant,
      'system' => SessionRole.system,
      _ => throw StateError('Unreachable'),
    };
    currentTimestamp = match.group(2);
    currentMsgId = match.group(3);
  }

  flushMessage(lines.length);
  return messages;
}

(SessionMessageStatus, String?, String?, List<String>) _extractStatusAndBody(
  List<String> rawBodyLines,
) {
  final trimmedTrailingEmpty = rawBodyLines.toList(growable: true);
  while (trimmedTrailingEmpty.isNotEmpty && trimmedTrailingEmpty.last.isEmpty) {
    trimmedTrailingEmpty.removeLast();
  }

  if (trimmedTrailingEmpty.isEmpty) {
    return (SessionMessageStatus.done, null, null, const <String>[]);
  }

  final lastLine = trimmedTrailingEmpty.last;
  if (lastLine == '<!-- streaming -->') {
    trimmedTrailingEmpty.removeLast();
    final (reasoning, bodyLines) = _extractReasoningAndBody(trimmedTrailingEmpty);
    return (SessionMessageStatus.streaming, null, reasoning, bodyLines);
  }

  final errorMatch = RegExp(r'^<!-- error: ([a-z]+) -->$').firstMatch(lastLine);
  if (errorMatch != null) {
    trimmedTrailingEmpty.removeLast();
    final (reasoning, bodyLines) = _extractReasoningAndBody(trimmedTrailingEmpty);
    return (SessionMessageStatus.error, errorMatch.group(1), reasoning, bodyLines);
  }

  final (reasoning, bodyLines) = _extractReasoningAndBody(trimmedTrailingEmpty);
  return (SessionMessageStatus.done, null, reasoning, bodyLines);
}

(String?, List<String>) _extractReasoningAndBody(List<String> lines) {
  if (lines.isEmpty || lines.first.trim() != _reasoningStartMarker) {
    return (null, lines);
  }

  final endIndex = lines.indexWhere((line) => line.trim() == _reasoningEndMarker);
  if (endIndex <= 0) {
    return (null, lines);
  }

  final reasoningLines = lines.sublist(1, endIndex);
  final bodyLines = lines.sublist(endIndex + 1).toList(growable: true);
  while (bodyLines.isNotEmpty && bodyLines.first.trim().isEmpty) {
    bodyLines.removeAt(0);
  }

  final reasoning = reasoningLines.join('\n').trimRight();
  return (reasoning.isEmpty ? null : reasoning, bodyLines);
}

String formatMessageHeader({
  required SessionRole role,
  required String timestampUtcIso8601,
  required String msgId,
}) {
  final roleStr = switch (role) {
    SessionRole.user => 'user',
    SessionRole.assistant => 'assistant',
    SessionRole.system => 'system',
  };

  return '## $roleStr · $timestampUtcIso8601 · $msgId';
}

/// 将 frontmatter Map 序列化为 YAML 文本（不含 --- 分隔符）
String _serializeFrontmatter(Map<String, Object?> fm) {
  final buffer = StringBuffer();
  for (final entry in fm.entries) {
    final key = entry.key;
    final value = entry.value;
    if (value == null) {
      buffer.writeln('$key: null');
    } else if (value is String) {
      // 多行字符串使用 YAML 块标量 | 语法，单行字符串用引号包裹
      if (value.contains('\n')) {
        buffer.writeln('$key: |');
        for (final line in value.split('\n')) {
          buffer.writeln('  $line');
        }
      } else {
        // 字符串值用引号包裹，避免 YAML 解析歧义
        buffer.writeln('$key: "$value"');
      }
    } else if (value is bool) {
      buffer.writeln('$key: $value');
    } else if (value is num) {
      buffer.writeln('$key: $value');
    } else if (value is List) {
      buffer.writeln('$key: ${jsonEncode(value)}');
    } else if (value is Map) {
      buffer.writeln('$key: ${jsonEncode(value)}');
    } else {
      buffer.writeln('$key: "$value"');
    }
  }
  return buffer.toString();
}

/// 更新 session.md 文件中 frontmatter 的指定字段，保留消息内容不变。
///
/// 读取文件 → 解析 → 合并 frontmatter → 重新序列化写回。
String updateSessionFrontmatter(
  String fileContent,
  Map<String, Object?> updates,
) {
  final normalized = fileContent.replaceAll('\r\n', '\n');
  final (frontmatter, bodyStartIndex) = _parseFrontmatter(normalized);
  final body = normalized.substring(bodyStartIndex);

  // 合并更新
  frontmatter.addAll(updates);

  // 重新组装
  final fmText = _serializeFrontmatter(frontmatter);
  final result = '---\n$fmText---\n$body';
  return result;
}

String buildConversationTranscript(SessionDocument document) {
  final buffer = StringBuffer();

  for (final message in document.messages) {
    final body = message.body.trim();
    if (body.isEmpty) continue;

    final roleLabel = switch (message.role) {
      SessionRole.user => 'user',
      SessionRole.assistant => 'assistant',
      SessionRole.system => 'system',
    };

    if (buffer.isNotEmpty) {
      buffer.writeln();
      buffer.writeln();
    }
    buffer.writeln('[$roleLabel]');
    buffer.write(body);
  }

  return buffer.toString();
}

String serializeSessionMessageBody(SessionMessage message) {
  final segments = <String>[];
  final reasoning = message.reasoning?.trimRight();
  final body = message.body.trimRight();

  if (reasoning != null && reasoning.isNotEmpty) {
    segments.add(_reasoningStartMarker);
    segments.add(reasoning);
    segments.add(_reasoningEndMarker);
  }

  if (body.isNotEmpty) {
    if (segments.isNotEmpty) {
      segments.add('');
    }
    segments.add(body);
  }

  return segments.join('\n');
}

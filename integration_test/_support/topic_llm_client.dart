import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:thk_tree/data/services/llm_client.dart';

class TopicLibraryLlmClient extends LlmClient {
  TopicLibraryLlmClient({
    required Map<String, String> repliesByUserPrompt,
    this.chunkDelay = const Duration(milliseconds: 120),
  }) : _repliesByUserPrompt = Map.unmodifiable(repliesByUserPrompt);

  final Map<String, String> _repliesByUserPrompt;
  final Duration chunkDelay;

  @override
  Stream<LlmResponseDelta> streamChatCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, Object?>> messages,
    CancelToken? cancelToken,
  }) async* {
    if (cancelToken?.isCancelled == true) return;

    final lastUserContent = _lastUserMessage(messages) ?? '';
    final reply = _repliesByUserPrompt[lastUserContent] ?? _fallbackReply(lastUserContent);

    // 记录 Prompt 匹配情况，方便调试
    if (!_repliesByUserPrompt.containsKey(lastUserContent)) {
      print('[MockLLM] Warning: No exact match for prompt: "${lastUserContent.replaceAll('\n', ' ')}"');
      print('[MockLLM] Available prompts: ${_repliesByUserPrompt.keys.map((k) => '"$k"').join(', ')}');
    } else {
      print('[MockLLM] Info: Matched prompt! Replying: "${reply.substring(0, min(20, reply.length))}..."');
    }

    if (reply.isEmpty) return;

    final firstLen = min(reply.length, max(16, reply.length ~/ 2));
    yield LlmResponseDelta(content: reply.substring(0, firstLen));

    await Future<void>.delayed(chunkDelay);
    if (cancelToken?.isCancelled == true) return;

    if (firstLen < reply.length) {
      yield LlmResponseDelta(content: reply.substring(firstLen));
    }
  }

  String? _lastUserMessage(List<Map<String, Object?>> messages) {
    for (var i = messages.length - 1; i >= 0; i--) {
      final role = messages[i]['role'];
      if (role is String && role == 'user') {
        final content = messages[i]['content'];
        if (content is String) return content;
      }
    }
    return null;
  }

  String _fallbackReply(String prompt) {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return '好的。';
    final preview = trimmed.length <= 60 ? trimmed : '${trimmed.substring(0, 60)}...';
    return '收到。我将基于你的输入给出结构化结果：$preview';
  }
}


import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/domain/ids.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import 'package:thk_tree/data/services/file_write_queue.dart';
import 'package:thk_tree/data/services/session_markdown.dart';

class SummaryChatParams {
  final String tempNodeId;
  final String parentNodeId;
  final String themeId;
  final String branchTitle;
  final String parentSessionText;

  SummaryChatParams({
    required this.tempNodeId,
    required this.parentNodeId,
    required this.themeId,
    required this.branchTitle,
    required this.parentSessionText,
  });
}

const _streamingMarker = '\n<!-- streaming -->\n';
const _legacyStreamingMarker = '<!-- streaming -->\n';

class SummaryChatController extends AsyncNotifier<List<SessionMessage>> {
  SummaryChatController(this.params);

  final SummaryChatParams params;
  String get tempNodeId => params.tempNodeId;
  String get parentNodeId => params.parentNodeId;
  String get themeId => params.themeId;
  String get branchTitle => params.branchTitle;

  late Directory _tempDir;
  late File _tempSessionFile;
  final FileWriteQueue _queue = FileWriteQueue();

  StreamSubscription<String>? _streamSub;
  AssistantStreamHandle? _handle;
  bool _stopRequested = false;
  CancelToken? _cancelToken;
  int _streamGeneration = 0;

  void _trace(String message, {Map<String, Object?>? attrs}) {
    dev.log(message);
    () async {
      try {
        final logger = await ref.read(appLoggerProvider.future);
        final fullAttrs = <String, Object?>{
          'tempNodeId': tempNodeId,
          'parentNodeId': parentNodeId,
          'themeId': themeId,
          'branchTitle': branchTitle,
          ...?attrs,
        };
        await logger.info(message, attrs: fullAttrs);
      } catch (_) {}
    }();
  }

  @override
  Future<List<SessionMessage>> build() async {
    _trace('summary_chat_controller.build');

    final tempBase = await ref.read(tempDirProvider.future);
    _tempDir = Directory(p.join(tempBase.path, 'summary_$tempNodeId'));
    await _tempDir.create(recursive: true);
    _tempSessionFile = File(p.join(_tempDir.path, 'session.md'));

    ref.onDispose(() async {
      _trace('summary_chat_controller.dispose');
      _streamSub?.cancel();
      _cancelToken?.cancel('dispose');
      try {
        await _tempDir.delete(recursive: true);
      } catch (_) {}
    });

    final initialSession = _buildInitialSession();
    await _atomicWriteString(_tempSessionFile.path, initialSession);
    _trace('summary_chat_controller.initial_session_written');

    final result = await _read();
    _trace('summary_chat_controller.build_done', attrs: {'messages': result.length});
    return result;
  }

  String _buildInitialSession() {
    final now = DateTime.now().toUtc().toIso8601String();
    final initialPrompt = '''请帮我总结以下对话的核心内容，要求：
1. 保持关键信息完整
2. 语言简洁清晰
3. 适合作为新对话的上下文

---
${params.parentSessionText}''';

    return '''---
schema: session/v1
themeId: "$themeId"
nodeId: "$tempNodeId"
kind: "chat"
parentId: "$parentNodeId"
title: "总结: $branchTitle"
createdAt: "$now"
updatedAt: "$now"
---

## user · $now · ${newMsgId()}
$initialPrompt
''';
  }

  Future<void> stopStreaming() async {
    _trace('summary_chat_controller.stop_streaming', attrs: {'hasHandle': _handle != null});
    final handle = _handle;
    _stopRequested = true;
    _streamGeneration++;
    _handle = null;

    _cancelToken?.cancel('user_stop');
    _cancelToken = null;

    final sub = _streamSub;
    _streamSub = null;
    await sub?.cancel();

    try {
      if (handle != null) {
        await _finishAssistant(handle);
      } else {
        await _finishStreamingMessage();
      }
      _trace('summary_chat_controller.stop_streaming_done');
      state = AsyncData(await _read());
    } catch (e, st) {
      _trace('summary_chat_controller.stop_streaming_error');
      try {
        final logger = await ref.read(appLoggerProvider.future);
        await logger.error(e, st, hint: 'stopStreaming', attrs: {'tempNodeId': tempNodeId});
      } catch (_) {}
    } finally {
      _stopRequested = false;
    }
  }

  Future<List<SessionMessage>> _read() async {
    try {
      _trace('summary_chat_controller.read_start');
      final text = await _tempSessionFile.readAsString();
      final doc = parseSessionMarkdown(text);
      _trace('summary_chat_controller.read_done', attrs: {'messages': doc.messages.length});
      return doc.messages;
    } catch (e, st) {
      _trace('summary_chat_controller.read_error');
      try {
        final logger = await ref.read(appLoggerProvider.future);
        await logger.error(e, st, hint: '_read', attrs: {'tempNodeId': tempNodeId});
      } catch (_) {}
      return state.value ?? [];
    }
  }

  Future<void> sendUserMessage(String text) async {
    try {
      final trimmed = text.trim();
      if (trimmed.isEmpty) return;

      await stopStreaming();

      final timestamp = DateTime.now().toUtc().toIso8601String();
      final msgId = newMsgId();
      await _appendMessage(
        role: SessionRole.user,
        timestamp: timestamp,
        msgId: msgId,
        body: trimmed,
      );

      state = AsyncData(await _read());

      final settings = await _loadSettings();
      if (settings.apiKey.isEmpty) {
        final ts = DateTime.now().toUtc().toIso8601String();
        final mid = newMsgId();
        await _appendMessage(
          role: SessionRole.assistant,
          timestamp: ts,
          msgId: mid,
          body: '[未配置 API Key] 请到 Settings 设置 ${settings.llmProvider.displayName} API Key。',
        );
        state = AsyncData(await _read());
        return;
      }

      await _startStreaming(settings);
    } catch (e, st) {
      final logger = await ref.read(appLoggerProvider.future);
      await logger.error(e, st, hint: 'sendUserMessage', attrs: {'tempNodeId': tempNodeId});
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<AppSettings> _loadSettings() async {
    final store = ref.read(settingsStoreProvider);
    return store.load();
  }

  Future<void> _startStreaming(AppSettings settings) async {
    final client = await ref.read(llmClientProvider.future);

    _stopRequested = false;
    _streamGeneration++;
    final generation = _streamGeneration;
    _cancelToken?.cancel('superseded');
    _cancelToken = CancelToken();

    final timestamp = DateTime.now().toUtc().toIso8601String();
    final msgId = newMsgId();
    _handle = AssistantStreamHandle(nodeId: tempNodeId, msgId: msgId);

    await _appendMessage(
      role: SessionRole.assistant,
      timestamp: timestamp,
      msgId: msgId,
      body: '',
      streaming: true,
    );

    state = AsyncData(await _read());

    final history = await _read();
    final messages = _buildMessages(history);

    final stream = client.streamChatCompletion(
      apiKey: settings.apiKey,
      model: settings.model,
      messages: messages,
      cancelToken: _cancelToken,
    );

    _streamSub?.cancel();
    _streamSub = stream.listen(
      (delta) async {
        if (_stopRequested || generation != _streamGeneration) return;
        final handle = _handle;
        if (handle == null) return;
        try {
          if (_stopRequested || generation != _streamGeneration) return;
          await _appendDelta(delta);
          if (_stopRequested || generation != _streamGeneration) return;
          state = AsyncData(await _read());
        } catch (e, st) {
          final logger = await ref.read(appLoggerProvider.future);
          await logger.error(e, st, hint: 'appendDelta', attrs: {'tempNodeId': tempNodeId});
        }
      },
      onError: (e, st) async {
        final handle = _handle;
        if (handle == null) return;
        if (_stopRequested) return;
        if (e is DioException && e.type == DioExceptionType.cancel) {
          return;
        }
        final logger = await ref.read(appLoggerProvider.future);
        await logger.error(e, st, hint: 'LLM stream error', attrs: {'tempNodeId': tempNodeId});
        await _failAssistant('network');
        _handle = null;
        _cancelToken = null;
        state = AsyncData(await _read());
      },
      onDone: () async {
        final handle = _handle;
        if (handle == null) return;
        try {
          await _finishAssistant(handle);
          _handle = null;
          _cancelToken = null;
          state = AsyncData(await _read());
        } catch (e, st) {
          final logger = await ref.read(appLoggerProvider.future);
          await logger.error(e, st, hint: 'finishAssistant', attrs: {'tempNodeId': tempNodeId});
        }
      },
      cancelOnError: true,
    );
  }

  Future<void> _appendMessage({
    required SessionRole role,
    required String timestamp,
    required String msgId,
    required String body,
    bool streaming = false,
  }) async {
    await _queue.run(tempNodeId, () async {
      final content = await _tempSessionFile.readAsString();
      final header = formatMessageHeader(
        role: role,
        timestampUtcIso8601: timestamp,
        msgId: msgId,
      );
      String updated = '${_ensureEndsWithNewline(content)}$header\n${body.trimRight()}';
      if (streaming) {
        updated += _streamingMarker;
      } else {
        updated += '\n';
      }
      await _atomicWriteString(_tempSessionFile.path, updated);
    });
  }

  Future<void> _appendDelta(String delta) async {
    await _queue.run(tempNodeId, () async {
      final content = await _tempSessionFile.readAsString();
      final (withoutMarker, found) = _stripStreamingMarker(content);
      if (!found) return;
      final updated = withoutMarker + delta + _streamingMarker;
      await _atomicWriteString(_tempSessionFile.path, updated);
    });
  }

  Future<void> _finishAssistant(AssistantStreamHandle handle) async {
    await _queue.run(tempNodeId, () async {
      final content = await _tempSessionFile.readAsString();
      final (withoutMarker, found) = _stripStreamingMarker(content);
      if (!found) return;
      final updated = '${withoutMarker.trimRight()}\n';
      await _atomicWriteString(_tempSessionFile.path, updated);
    });
  }

  Future<void> _finishStreamingMessage() async {
    await _queue.run(tempNodeId, () async {
      final content = await _tempSessionFile.readAsString();
      final (withoutMarker, found) = _stripStreamingMarker(content);
      if (!found) return;
      final updated = '${withoutMarker.trimRight()}\n';
      await _atomicWriteString(_tempSessionFile.path, updated);
    });
  }

  Future<void> _failAssistant(String code) async {
    await _queue.run(tempNodeId, () async {
      final content = await _tempSessionFile.readAsString();
      final (withoutMarker, found) = _stripStreamingMarker(content);
      if (!found) return;
      final updated = '$withoutMarker\n<!-- error: $code -->\n';
      await _atomicWriteString(_tempSessionFile.path, updated);
    });
  }

  String? getSummaryText() {
    final messages = state.value;
    if (messages == null || messages.isEmpty) return null;
    final lastAssistant = messages.lastWhere(
      (m) => m.role == SessionRole.assistant && m.status == SessionMessageStatus.done,
      orElse: () => messages.last,
    );
    if (lastAssistant.body.trim().isEmpty) return null;
    return lastAssistant.body.trim();
  }
}

final summaryChatControllerProvider = AsyncNotifierProvider.autoDispose
    .family<SummaryChatController, List<SessionMessage>, SummaryChatParams>(
  SummaryChatController.new,
);

List<Map<String, Object?>> _buildMessages(List<SessionMessage> history) {
  final messages = <Map<String, Object?>>[
    {
      'role': 'system',
      'content': 'You are a helpful assistant. Reply in Markdown.',
    },
  ];

  for (final msg in history) {
    final role = switch (msg.role) {
      SessionRole.user => 'user',
      SessionRole.assistant => 'assistant',
      SessionRole.system => 'system',
    };
    if (msg.body.trim().isEmpty) continue;
    messages.add({'role': role, 'content': msg.body});
  }

  return messages;
}

String _ensureEndsWithNewline(String content) {
  if (content.isEmpty) return '';
  return content.endsWith('\n') ? content : '$content\n';
}

(String, bool) _stripStreamingMarker(String content) {
  if (content.endsWith(_streamingMarker)) {
    return (content.substring(0, content.length - _streamingMarker.length), true);
  }
  if (content.endsWith(_legacyStreamingMarker)) {
    return (content.substring(0, content.length - _legacyStreamingMarker.length), true);
  }
  return (content, false);
}

Future<void> _atomicWriteString(String filePath, String content) async {
  final tmpPath = '$filePath.tmp';
  final tmpFile = File(tmpPath);
  await tmpFile.writeAsString(content);
  await tmpFile.rename(filePath);
}

class AssistantStreamHandle {
  AssistantStreamHandle({required this.nodeId, required this.msgId});

  final String nodeId;
  final String msgId;
}

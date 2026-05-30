import 'dart:async';
import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/data/services/llm_client.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/data/stores/session_store.dart';

class ChatControllerParams {
  final String nodeId;
  final String title;

  ChatControllerParams(this.nodeId, this.title);
}

class ChatController extends AsyncNotifier<List<SessionMessage>> {
  ChatController(this.params);

  final ChatControllerParams params;
  String get nodeId => params.nodeId;
  String get title => params.title;

  StreamSubscription<String>? _streamSub;
  AssistantStreamHandle? _handle;
  bool _stopRequested = false;
  CancelToken? _cancelToken;
  int _streamGeneration = 0;

  // 缓存当前对话的模型信息
  String? _providerId;
  String? _modelId;

  /// 缓存当前对话的 system prompt
  String _systemPrompt = 'You are a helpful assistant. Reply in Markdown.';

  /// 当前对话关联的 providerId（可为 null 表示使用全局设置）
  String? get providerId => _providerId;

  /// 当前对话关联的 modelId（可为 null 表示使用全局设置）
  String? get modelId => _modelId;

  void _trace(String message, {Map<String, Object?>? attrs}) {
    dev.log(message);
    () async {
      try {
        final logger = await ref.read(appLoggerProvider.future);
        final fullAttrs = <String, Object?>{'nodeId': nodeId, 'title': title, ...?attrs};
        await logger.info(message, attrs: fullAttrs);
      } catch (_) {}
    }();
  }

  @override
  Future<List<SessionMessage>> build() async {
    _trace('chat_controller.build');
    ref.onDispose(() {
      _trace('chat_controller.dispose');
      _streamSub?.cancel();
      _cancelToken?.cancel('dispose');
    });
    final result = await _read();
    _trace('chat_controller.build_done', attrs: {'messages': result.length});

    // 读取并缓存对话级模型信息
    await _loadSessionModel();

    return result;
  }

  /// 从 session.md 的 frontmatter 加载对话级 providerId/modelId/systemPrompt
  Future<void> _loadSessionModel() async {
    try {
      final store = await ref.read(sessionStoreProvider.future);
      final doc = await store.readSession(nodeId);
      _providerId = doc.providerId;
      _modelId = doc.modelId;
      _systemPrompt = doc.systemPrompt;
      _trace('chat_controller.load_session_model', attrs: {'providerId': _providerId, 'modelId': _modelId});
    } catch (_) {
      _providerId = null;
      _modelId = null;
      _systemPrompt = 'You are a helpful assistant. Reply in Markdown.';
    }
  }

  /// 切换当前对话使用的模型
  Future<void> switchModel(String providerId, String modelId) async {
    _trace('chat_controller.switch_model', attrs: {'providerId': providerId, 'modelId': modelId});
    final sessionStore = await ref.read(sessionStoreProvider.future);
    await sessionStore.updateSessionModel(
      nodeId: nodeId,
      providerId: providerId,
      modelId: modelId,
    );
    _providerId = providerId;
    _modelId = modelId;
    // 通知 UI 刷新
    state = AsyncData(await _read());
  }

  Future<void> stopStreaming() async {
    _trace('chat_controller.stop_streaming', attrs: {'hasHandle': _handle != null});
    final handle = _handle;
    _stopRequested = true;
    _streamGeneration++;
    _handle = null;

    _cancelToken?.cancel('user_stop');
    _cancelToken = null;

    // 乐观更新：立即将 streaming 消息标记为 done，让 UI 立刻切换按钮
    final currentMessages = state.value ?? [];
    state = AsyncData(currentMessages.map((m) {
      if (m.status == SessionMessageStatus.streaming) {
        return SessionMessage(
          role: m.role,
          timestampUtcIso8601: m.timestampUtcIso8601,
          msgId: m.msgId,
          body: m.body,
          status: SessionMessageStatus.done,
        );
      }
      return m;
    }).toList());

    final sub = _streamSub;
    _streamSub = null;
    // 取消订阅可能抛出 pending 的 DioException，静默处理
    try {
      await sub?.cancel();
    } catch (_) {}

    try {
      final sessionStore = await ref.read(sessionStoreProvider.future);
      _trace('chat_controller.stop_streaming_got_sessionStore');
      if (handle != null) {
        _trace('chat_controller.finish_assistant');
        await sessionStore.finishAssistant(handle: handle);
      } else {
        _trace('chat_controller.finish_streaming_message');
        await sessionStore.finishStreamingMessage(nodeId: nodeId);
      }
      _trace('chat_controller.stop_streaming_done');
      state = AsyncData(await _read());
    } catch (e, st) {
      _trace('chat_controller.stop_streaming_error');
      try {
        final logger = await ref.read(appLoggerProvider.future);
        await logger.error(e, st, hint: 'stopStreaming', attrs: {'nodeId': nodeId, 'title': title});
      } catch (_) {}
    } finally {
      _stopRequested = false;
    }
  }

  Future<List<SessionMessage>> _read() async {
    try {
      _trace('chat_controller.read_start');
      final store = await ref.read(sessionStoreProvider.future);
      _trace('chat_controller.read_got_sessionStore');
      final doc = await store.readSession(nodeId);
      final streamingCount = doc.messages.where((m) => m.status == SessionMessageStatus.streaming).length;
      _trace('chat_controller.read_done', attrs: {'messages': doc.messages.length, 'streaming': streamingCount});
      return doc.messages;
    } catch (e, st) {
      _trace('chat_controller.read_error');
      try {
        final logger = await ref.read(appLoggerProvider.future);
        await logger.error(e, st, hint: '_read', attrs: {'nodeId': nodeId, 'title': title});
      } catch (_) {}
      return state.value ?? [];
    }
  }

  Future<void> sendUserMessage(String text) async {
    try {
      final trimmed = text.trim();
      if (trimmed.isEmpty) return;

      await stopStreaming();

      final sessionStore = await ref.read(sessionStoreProvider.future);
      await sessionStore.appendUserMessage(nodeId: nodeId, content: trimmed);

      state = AsyncData(await _read());

      // 判断使用对话级模型还是全局设置
      final sessionProviderId = _providerId;
      final sessionModelId = _modelId;

      if (sessionProviderId != null && sessionModelId != null) {
        // 使用对话级模型
        final configStore = ref.read(llmConfigStoreProvider);
        final provider = await configStore.getProvider(sessionProviderId);
        if (provider == null) {
          _trace('chat_controller.provider_not_found', attrs: {'providerId': sessionProviderId});
          await sessionStore.appendAssistantMessage(
            nodeId: nodeId,
            content: '[提供商未找到] providerId=$sessionProviderId 对应的提供商配置不存在，请切换模型。',
          );
          state = AsyncData(await _read());
          return;
        }
        final apiKey = await configStore.readApiKey(sessionProviderId);
        if (apiKey.isEmpty) {
          await sessionStore.appendAssistantMessage(
            nodeId: nodeId,
            content: '[未配置 API Key] 请为 ${provider.name} 配置 API Key。',
          );
          state = AsyncData(await _read());
          return;
        }
        await _startStreamingWithConfig(
          client: LlmClient.forConfig(provider),
          apiKey: apiKey,
          model: sessionModelId,
        );
      } else {
        // 回退到全局设置
        final settings = await _loadSettings();
        if (settings.apiKey.isEmpty) {
          await sessionStore.appendAssistantMessage(
            nodeId: nodeId,
            content: '[未配置 API Key] 请到 Settings 设置 ${settings.llmProvider.displayName} API Key。',
          );
          state = AsyncData(await _read());
          return;
        }
        await _startStreamingWithSettings(settings);
      }
    } catch (e, st) {
      final logger = await ref.read(appLoggerProvider.future);
      await logger.error(e, st, hint: 'sendUserMessage', attrs: {'nodeId': nodeId, 'title': title});
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<AppSettings> _loadSettings() async {
    final store = ref.read(settingsStoreProvider);
    return store.load();
  }

  Future<void> _startStreamingWithSettings(AppSettings settings) async {
    final client = await ref.read(llmClientProvider.future);
    await _startStreamingWithConfig(
      client: client,
      apiKey: settings.apiKey,
      model: settings.model,
    );
  }

  Future<void> _startStreamingWithConfig({
    required LlmClient client,
    required String apiKey,
    required String model,
  }) async {
    final sessionStore = await ref.read(sessionStoreProvider.future);

    _stopRequested = false;
    _streamGeneration++;
    final generation = _streamGeneration;
    _cancelToken?.cancel('superseded');
    _cancelToken = CancelToken();
    _handle = await sessionStore.beginAssistantMessage(nodeId: nodeId);

    state = AsyncData(await _read());

    final history = await _read();
    final messages = _buildMessages(history, _systemPrompt);

    final stream = client.streamChatCompletion(
      apiKey: apiKey,
      model: model,
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
          await sessionStore.appendAssistantDelta(handle: handle, delta: delta);
          if (_stopRequested || generation != _streamGeneration) return;
          state = AsyncData(await _read());
        } catch (e, st) {
          final logger = await ref.read(appLoggerProvider.future);
          await logger.error(e, st, hint: 'appendAssistantDelta', attrs: {'nodeId': nodeId, 'title': title});
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
        await logger.error(e, st, hint: 'LLM stream error', attrs: {'nodeId': nodeId, 'title': title});
        await sessionStore.failAssistant(handle: handle, code: 'network');
        _handle = null;
        _cancelToken = null;
        state = AsyncData(await _read());
      },
      onDone: () async {
        final handle = _handle;
        if (handle == null) return;
        try {
          await sessionStore.finishAssistant(handle: handle);
          _handle = null;
          _cancelToken = null;
          state = AsyncData(await _read());
        } catch (e, st) {
          final logger = await ref.read(appLoggerProvider.future);
          await logger.error(e, st, hint: 'finishAssistant', attrs: {'nodeId': nodeId, 'title': title});
        }
      },
      cancelOnError: true,
    );
  }
}

final chatControllerProvider =
    AsyncNotifierProvider.autoDispose.family<ChatController, List<SessionMessage>, ChatControllerParams>(
  ChatController.new,
);

List<Map<String, Object?>> _buildMessages(List<SessionMessage> history, String systemPrompt) {
  final messages = <Map<String, Object?>>[
    {'role': 'system', 'content': systemPrompt},
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

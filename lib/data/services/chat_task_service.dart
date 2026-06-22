import 'dart:async';
import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/data/services/llm_client.dart';
import 'package:thk_tree/data/stores/session_store.dart';
import 'package:thk_tree/ui/core/app_logger.dart';
import 'package:thk_tree/data/stores/node_store.dart';
import 'package:thk_tree/data/services/search_service.dart';

class ChatTask {
  ChatTask({
    required this.nodeId,
    required this.handle,
    required this.streamSub,
    required this.cancelToken,
    required this.generation,
    required this.sessionStore,
    this.searchService,
    this.nodeStore,
    this.logger,
  });

  final String nodeId;
  final AssistantStreamHandle handle;
  final StreamSubscription<String> streamSub;
  final CancelToken cancelToken;
  final int generation;
  final SessionStore sessionStore;
  final SearchService? searchService;
  final NodeStore? nodeStore;
  final AppLogger? logger;
  bool stopped = false;
}

class ChatTaskService extends Notifier<Map<String, ChatTask>> {
  ChatTaskService();

  SearchService? _searchService;
  NodeStore? _nodeStore;

  @override
  Map<String, ChatTask> build() {
    return {};
  }

  Future<void> initializeServices({
    SearchService? searchService,
    NodeStore? nodeStore,
  }) async {
    _searchService = searchService;
    _nodeStore = nodeStore;
  }

  Future<void> startTask({
    required String nodeId,
    required LlmClient client,
    required String apiKey,
    required String model,
    required List<SessionMessage> history,
    required String systemPrompt,
    required SessionStore sessionStore,
    AppLogger? logger,
  }) async {
    if (state.containsKey(nodeId)) {
      await stopTask(nodeId);
    }

    final cancelToken = CancelToken();
    final handle = await sessionStore.beginAssistantMessage(nodeId: nodeId);
    final generation = DateTime.now().millisecondsSinceEpoch;

    final messages = _buildMessages(history, systemPrompt);
    final stream = client.streamChatCompletion(
      apiKey: apiKey,
      model: model,
      messages: messages,
      cancelToken: cancelToken,
    );

    final streamSub = stream.listen(
      (delta) async {
        try {
          await sessionStore.appendAssistantDelta(handle: handle, delta: delta);
        } catch (e, st) {
          logger?.error(e, st, hint: 'ChatTask.appendDelta', attrs: {'nodeId': nodeId});
        }
      },
      onError: (e, st) async {
        if (e is DioException && e.type == DioExceptionType.cancel) {
          return;
        }
        logger?.error(e, st, hint: 'ChatTask.streamError', attrs: {'nodeId': nodeId});
        try {
          await sessionStore.failAssistant(handle: handle, code: 'network');
        } catch (_) {}
        _removeTask(nodeId);
      },
      onDone: () async {
        try {
          await sessionStore.finishAssistant(handle: handle);
          // 更新搜索索引
          await _updateSearchIndex(nodeId, sessionStore, logger);
        } catch (e, st) {
          logger?.error(e, st, hint: 'ChatTask.finish', attrs: {'nodeId': nodeId});
        }
        _removeTask(nodeId);
      },
      cancelOnError: true,
    );

    final task = ChatTask(
      nodeId: nodeId,
      handle: handle,
      streamSub: streamSub,
      cancelToken: cancelToken,
      generation: generation,
      sessionStore: sessionStore,
      searchService: _searchService,
      nodeStore: _nodeStore,
      logger: logger,
    );

    state = {...state, nodeId: task};
  }

  Future<void> _updateSearchIndex(
    String nodeId,
    SessionStore sessionStore,
    AppLogger? logger,
  ) async {
    try {
      final searchService = _searchService;
      final nodeStore = _nodeStore;
      if (searchService == null || nodeStore == null) return;

      final nodeRow = await nodeStore.getNodeRow(nodeId: nodeId);
      final themeId = nodeRow['themeId'] as String;
      final nodeTitle = nodeRow['title'] as String? ?? '';

      // 获取主题标题
      final themeRow = await nodeStore.getThemeRow(themeId: themeId);
      final themeTitle = themeRow['title'] as String? ?? '';

      // 读取完整对话内容用于索引
      final doc = await sessionStore.readSession(nodeId);
      final body = doc.messages
          .where((m) => m.role == SessionRole.assistant)
          .map((m) => m.body)
          .join('\n');

      await searchService.upsertMessage(
        nodeId: nodeId,
        themeId: themeId,
        themeTitle: themeTitle,
        nodeTitle: nodeTitle,
        body: body,
      );
    } catch (e) {
      log('[ChatTaskService._updateSearchIndex] FAILED nodeId=$nodeId: $e');
    }
  }

  Future<void> stopTask(String nodeId) async {
    final task = state[nodeId];
    if (task == null) return;

    task.stopped = true;
    task.streamSub.cancel();
    task.cancelToken.cancel('user_stop');
    _removeTask(nodeId);
  }

  void _removeTask(String nodeId) {
    final newState = Map<String, ChatTask>.from(state);
    newState.remove(nodeId);
    state = newState;
  }

  bool hasTask(String nodeId) => state.containsKey(nodeId);
}

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

final chatTaskServiceProvider = NotifierProvider<ChatTaskService, Map<String, ChatTask>>(
  ChatTaskService.new,
);

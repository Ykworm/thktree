import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:thk_tree/data/models/llm_error.dart';
import 'package:thk_tree/data/services/background_task_bridge.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/data/services/llm_client.dart';
import 'package:thk_tree/data/stores/session_store.dart';
import 'package:thk_tree/ui/core/app_logger.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/features/chat/chat_controller.dart';
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
  final StreamSubscription<LlmResponseDelta> streamSub;
  final CancelToken cancelToken;
  final int generation;
  final SessionStore sessionStore;
  final SearchService? searchService;
  final NodeStore? nodeStore;
  final AppLogger? logger;
  bool stopped = false;
}

class ChatTaskService extends Notifier<Map<String, ChatTask>> {
  ChatTaskService({BackgroundTaskBridge? bridge})
      : _bridge = bridge ?? BackgroundTaskBridge();

  SearchService? _searchService;
  NodeStore? _nodeStore;

  /// iOS 后台 task 桥接（短回复 < 30s 时保活；详见 [BackgroundTaskBridge]）。
  ///
  /// 测试可通过构造参数注入 mock bridge 以计数 begin/end 调用。
  final BackgroundTaskBridge _bridge;

  /// 待重发的 nodeId 队列（先进先出）。重复入队会被过滤。
  final List<String> _resumeQueue = <String>[];

  /// 当前排队的 node 数（仅供测试观察内部状态用）。
  @visibleForTesting
  int get resumeQueueLength => _resumeQueue.length;

  /// 当前是否正在执行 [_resumeLoop]。
  @visibleForTesting
  bool get isResuming => _isResuming;

  /// 是否正在串行执行 [_resumeLoop]
  bool _isResuming = false;

  /// 每次 [cancelResumeQueue] 递增；旧 loop 检测到 generation 变化立即退出
  int _resumeGeneration = 0;

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
    bool webSearch = false,
    bool deepThinking = false,
    Uint8List? imageData,
    String? imageMimeType,
  }) async {
    if (state.containsKey(nodeId)) {
      await stopTask(nodeId);
    }

    // 申请 iOS 后台 task（短回复 < 30s 时保活；非 iOS 平台 / 失败返回 null，不阻塞主流程）
    unawaited(_bridge.begin());

    final cancelToken = CancelToken();
    print('[DEBUG-CHAT-TASK] before beginAssistantMessage, model=$model, nodeId=$nodeId');
    final handle = await sessionStore.beginAssistantMessage(nodeId: nodeId, modelId: model);
    print('[DEBUG-CHAT-TASK] beginAssistantMessage done, handle.msgId=${handle.msgId}');
    final generation = DateTime.now().millisecondsSinceEpoch;

    final messages = _buildMessages(history, systemPrompt, imageData: imageData, imageMimeType: imageMimeType);
    final stream = client.streamChatCompletion(
      apiKey: apiKey,
      model: model,
      messages: messages,
      cancelToken: cancelToken,
      webSearch: webSearch,
      deepThinking: deepThinking,
    );

    final streamSub = stream.listen(
      (delta) async {
        try {
          await sessionStore.appendAssistantDelta(
            handle: handle,
            contentDelta: delta.content,
            reasoningDelta: delta.reasoning,
          );
        } catch (e, st) {
          logger?.error(e, st, hint: 'ChatTask.appendDelta', attrs: {'nodeId': nodeId});
        }
      },
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
      onDone: () async {
        try {
          await sessionStore.finishAssistant(handle: handle);
          // 更新搜索索引
          await _updateSearchIndex(nodeId, sessionStore, logger);
        } catch (e, st) {
          logger?.error(e, st, hint: 'ChatTask.finish', attrs: {'nodeId': nodeId});
        }
        unawaited(_bridge.end());
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
    unawaited(_bridge.end());
    _removeTask(nodeId);
  }

  void _removeTask(String nodeId) {
    final newState = Map<String, ChatTask>.from(state);
    newState.remove(nodeId);
    state = newState;
  }

  bool hasTask(String nodeId) => state.containsKey(nodeId);

  // ─────────────────────────────────────────────────────────────────────
  //  iOS 后台中断恢复（Task 6 + 7）
  // ─────────────────────────────────────────────────────────────────────

  /// 扫描磁盘中断消息，串行排队重发。
  ///
  /// 流程：
  /// 1. 调 [SessionStore.findInterrupted] 拿 [(nodeId, sessionPath), ...]
  /// 2. 过滤：当前 [hasTask]（流还活着）和已在 [_resumeQueue]（避免重复入队）
  /// 3. 调 [SessionStore.finishStreamingMessage] 清掉磁盘上的 `<!-- streaming -->` 标记
  /// 4. 入队；串行从队首取一个调 [ChatController.retryLastMessage]
  ///
  /// 串行执行在 [_resumeLoop] 私有方法里；新调用 [resumeInterrupted] 不重启 loop。
  ///
  /// 仅 iOS 平台：Android 走自然恢复。
  Future<void> resumeInterrupted() async {
    if (!Platform.isIOS) return;

    final SessionStore sessionStore;
    try {
      sessionStore = await ref.read(sessionStoreProvider.future);
    } catch (e, st) {
      await _logError(e, st, hint: 'resumeInterrupted.sessionStore');
      return;
    }

    final interrupted = await SessionStore.findInterrupted();
    if (interrupted.isEmpty) return;

    // 去重 + 过滤活跃任务
    final newItems = interrupted
        .where((item) => !hasTask(item.nodeId))
        .where((item) => !_resumeQueue.contains(item.nodeId))
        .toList();

    if (newItems.isEmpty) return;

    // 清掉磁盘上的 `<!-- streaming -->` 标记（避免下次 _read 误判为 streaming 状态）
    for (final item in newItems) {
      try {
        await sessionStore.finishStreamingMessage(nodeId: item.nodeId);
      } catch (e, st) {
        await _logError(e, st,
            hint: 'resumeInterrupted.finishStreamingMessage',
            attrs: {'nodeId': item.nodeId});
      }
      _resumeQueue.add(item.nodeId);
    }

    await _logInfo('resumeInterrupted: enqueued ${newItems.length} node(s)');

    if (!_isResuming) {
      _isResuming = true;
      unawaited(_resumeLoop());
    }
  }

  /// 用户主动取消：清空队列 + 递增 generation 让正在跑的 loop 退出。
  void cancelResumeQueue() {
    _resumeQueue.clear();
    _resumeGeneration++;
    unawaited(_logInfo('cancelResumeQueue: cleared'));
  }

  /// 串行执行队列：每次取一个 nodeId，调 [ChatController.retryLastMessage]。
  ///
  /// 通过 [_resumeGeneration] 实现可取消：循环检测到 generation 变化就退出。
  Future<void> _resumeLoop() async {
    final myGen = ++_resumeGeneration;
    try {
      while (_resumeQueue.isNotEmpty && myGen == _resumeGeneration) {
        final nodeId = _resumeQueue.removeAt(0);
        try {
          await _retry(nodeId);
        } catch (e, st) {
          await _logError(e, st,
              hint: 'resumeInterrupted.retry', attrs: {'nodeId': nodeId});
        }
      }
    } finally {
      if (myGen == _resumeGeneration) {
        _isResuming = false;
      }
    }
  }

  /// 委托给 [ChatController.retryLastMessage]（按 nodeId 路由）。
  ///
  /// 关键：先 `ref.read(chatControllerProvider(params).future)` 触发 build 并 await
  /// 完成，拿到 messages 后调 notifier 的 retryLastMessage。
  Future<void> _retry(String nodeId) async {
    final NodeStore? nodeStore = _nodeStore;
    if (nodeStore == null) {
      await _logInfo('_retry: nodeStore not ready, skip', attrs: {'nodeId': nodeId});
      return;
    }

    final row = await nodeStore.getNodeRow(nodeId: nodeId);
    final title = row['title'] as String? ?? '';
    final params = ChatControllerParams(
      nodeId: nodeId,
      title: title,
      autoTriggerReply: false,
    );

    // 触发 ChatController.build() 完成（拿到 messages），再调 retryLastMessage
    await ref.read(chatControllerProvider(params).future);
    final controller = ref.read(chatControllerProvider(params).notifier);
    await controller.retryLastMessage();
  }

  Future<void> _logInfo(String message, {Map<String, Object?>? attrs}) async {
    try {
      final logger = await ref.read(appLoggerProvider.future);
      await logger.info(message, attrs: attrs);
    } catch (_) {}
  }

  Future<void> _logError(Object e, StackTrace st,
      {required String hint, Map<String, Object?>? attrs}) async {
    try {
      final logger = await ref.read(appLoggerProvider.future);
      await logger.error(e, st, hint: hint, attrs: attrs);
    } catch (_) {}
  }
}

List<Map<String, Object?>> _buildMessages(
  List<SessionMessage> history,
  String systemPrompt, {
  Uint8List? imageData,
  String? imageMimeType,
}) {
  final messages = <Map<String, Object?>>[
    {'role': 'system', 'content': systemPrompt},
  ];

  for (final msg in history) {
    final role = switch (msg.role) {
      SessionRole.user => 'user',
      SessionRole.assistant => 'assistant',
      SessionRole.system => 'system',
    };

    // 处理用户消息中的图片
    if (msg.role == SessionRole.user && msg.imageData != null) {
      // 构建多模态消息
      final content = <Map<String, Object?>>[
        if (msg.body.trim().isNotEmpty) {'type': 'text', 'text': msg.body},
        {
          'type': 'image_url',
          'image_url': {
            'url': 'data:${msg.imageMimeType ?? 'image/jpeg'};base64,${base64Encode(msg.imageData!)}',
          },
        },
      ];
      messages.add({'role': role, 'content': content});
    } else {
      // 纯文本消息
      if (msg.body.trim().isEmpty) continue;
      messages.add({'role': role, 'content': msg.body});
    }
  }

  return messages;
}

final chatTaskServiceProvider = NotifierProvider<ChatTaskService, Map<String, ChatTask>>(
  ChatTaskService.new,
);

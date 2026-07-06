import 'dart:async';
import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/data/services/llm_client.dart';
import 'package:thk_tree/data/models/llm_model_config.dart';
import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/data/models/model_capabilities.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/data/services/chat_task_service.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';

class ChatControllerParams {
  const ChatControllerParams({
    required this.nodeId,
    required this.title,
    this.autoTriggerReply = false,
  });

  final String nodeId;
  final String title;

  /// 为 true 且最后一条消息是 user 消息（status == done）时，
  /// build() 完成后会自动调一次 LLM 回复（不追加 user 消息）。
  ///
  /// 用于"笔记→对话自动续聊"和"summary 创建分支"等场景。
  final bool autoTriggerReply;
}

class ChatController extends AsyncNotifier<List<SessionMessage>> {
  ChatController(this.params);

  final ChatControllerParams params;
  String get nodeId => params.nodeId;
  String get title => params.title;

  Timer? _pollTimer;
  bool _isListeningToTaskService = false;

  // 缓存当前对话的模型信息
  String? _providerId;
  String? _modelId;
  LlmProviderType? _providerType;

  // 当前对话的深度思考开关（per-session in-memory，默认关）
  bool _deepThinkingEnabled = false;

  /// 缓存当前对话的 system prompt
  String _systemPrompt = 'You are a helpful assistant. Always respond using correct and well-structured Markdown format — use proper headings, lists, code fences, tables, and inline formatting as appropriate. Do not return raw text when Markdown syntax is applicable.';

  /// 当前对话关联的 providerId（可为 null 表示使用全局设置）
  String? get providerId => _providerId;

  /// 当前对话关联的 modelId（可为 null 表示使用全局设置）
  String? get modelId => _modelId;

  /// 当前对话关联的提供商类型（用于联网搜索等判断）
  LlmProviderType? get providerType => _providerType;

  /// 当前深度思考开关状态（per-session in-memory，UI 调用 [setDeepThinking] 切换）
  bool get deepThinkingEnabled => _deepThinkingEnabled;

  /// 设置深度思考开关。注意：调用方（chat_screen）在切换按钮被按下时应同步 setState
  /// 来触发 rebuild；本方法不直接触发 Riverpod state 重建，因为 UI 状态本身已在屏幕层持有。
  void setDeepThinking(bool value) {
    if (_deepThinkingEnabled == value) return;
    _deepThinkingEnabled = value;
    _trace(
      'chat_controller.set_deep_thinking',
      attrs: {'value': value, 'modelId': _modelId ?? '', 'providerType': _providerType?.name ?? ''},
    );
  }

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
      _pollTimer?.cancel();
    });

    // 监听任务服务状态变化
    if (!_isListeningToTaskService) {
      _isListeningToTaskService = true;
      ref.listen<Map<String, ChatTask>>(
        chatTaskServiceProvider,
        (previous, next) async {
          if (next.containsKey(nodeId) || (previous?.containsKey(nodeId) ?? false)) {
            state = AsyncData(await _read());
          }
        },
      );
    }

    // 启动轮询以更新 UI（在后台任务运行时）
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      final taskService = ref.read(chatTaskServiceProvider);
      if (taskService.containsKey(nodeId)) {
        state = AsyncData(await _read());
      }
    });

    final result = await _read();
    _trace('chat_controller.build_done', attrs: {'messages': result.length});

    // 读取并缓存对话级模型信息
    await _loadSessionModel();

    // 自动续聊：若需要且最后一条是 user 消息 + status done，
    // 且没有正在运行的任务，则调度一次 LLM 回复。
    if (params.autoTriggerReply) {
      final lastMsg = result.isEmpty ? null : result.last;
      final hasActiveTask = ref.read(chatTaskServiceProvider).containsKey(nodeId);
      if (lastMsg != null &&
          lastMsg.role == SessionRole.user &&
          lastMsg.status == SessionMessageStatus.done &&
          !hasActiveTask) {
        Future.microtask(() async {
          try {
            await _triggerAssistantReply();
          } catch (e, st) {
            _trace('chat_controller.auto_trigger_reply_error');
            try {
              final logger = await ref.read(appLoggerProvider.future);
              await logger.error(e, st,
                  hint: 'autoTriggerReply',
                  attrs: {'nodeId': nodeId, 'title': title});
            } catch (_) {}
          }
        });
      }
    }

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
      // 加载提供商类型
      if (_providerId != null) {
        final configStore = ref.read(llmConfigStoreProvider);
        final config = await configStore.getProvider(_providerId!);
        _providerType = config?.type;
      } else {
        _providerType = null;
      }
      _trace('chat_controller.load_session_model', attrs: {'providerId': _providerId, 'modelId': _modelId});
    } catch (_) {
      _providerId = null;
      _modelId = null;
      _providerType = null;
      _systemPrompt = 'You are a helpful assistant. Always respond using correct and well-structured Markdown format — use proper headings, lists, code fences, tables, and inline formatting as appropriate. Do not return raw text when Markdown syntax is applicable.';
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
    // 同步更新提供商类型
    final configStore = ref.read(llmConfigStoreProvider);
    final config = await configStore.getProvider(providerId);
    _providerType = config?.type;
    // 通知 UI 刷新
    state = AsyncData(await _read());
  }

  /// 取消当前流：委托给 ChatTaskService
  Future<void> _cancelCurrentStream() async {
    _trace('chat_controller.cancel_current_stream');
    await ref.read(chatTaskServiceProvider.notifier).stopTask(nodeId);
    // 乐观更新：让 UI 快速响应
    final currentMessages = state.value ?? [];
    state = AsyncData(currentMessages.map((m) {
      if (m.status == SessionMessageStatus.streaming) {
        return SessionMessage(
          role: m.role,
          timestampUtcIso8601: m.timestampUtcIso8601,
          msgId: m.msgId,
          body: m.body,
          status: SessionMessageStatus.done,
          reasoning: m.reasoning,
          modelId: m.modelId,
        );
      }
      return m;
    }).toList());
  }

  /// 停止流式生成（供 UI 调用，如 Stop 按钮）
  Future<void> stopStreaming() => _cancelCurrentStream();

  Future<List<SessionMessage>> _read() async {
    try {
      final store = await ref.read(sessionStoreProvider.future);
      final doc = await store.readSession(nodeId);

      // 自愈：如果没有活跃流，残留的 streaming 标记一定是过时的
      // 只修正返回值，不写磁盘，避免与其他读操作竞争
      final hasStreaming = doc.messages.any((m) => m.status == SessionMessageStatus.streaming);
      final hasActiveTask = ref.read(chatTaskServiceProvider).containsKey(nodeId);
      List<SessionMessage> diskMessages;
      if (hasStreaming && !hasActiveTask) {
        diskMessages = doc.messages.map((m) {
          if (m.status == SessionMessageStatus.streaming) {
            return SessionMessage(
              role: m.role,
              timestampUtcIso8601: m.timestampUtcIso8601,
              msgId: m.msgId,
              body: m.body,
              status: SessionMessageStatus.done,
              reasoning: m.reasoning,
              modelId: m.modelId,
            );
          }
          return m;
        }).toList();
      } else {
        diskMessages = doc.messages;
      }

      // 合并 in-memory state 中的图片数据（磁盘不存储二进制图片）
      return _mergeImageData(diskMessages, state.value);
    } catch (e, st) {
      try {
        final logger = await ref.read(appLoggerProvider.future);
        await logger.error(e, st, hint: '_read', attrs: {'nodeId': nodeId, 'title': title});
      } catch (_) {}
      return state.value ?? [];
    }
  }

  /// 将 in-memory 消息中的 imageData/imageMimeType 合并到磁盘消息中。
  /// 按 msgId + role 匹配，只补全磁盘缺失的图片字段。
  List<SessionMessage> _mergeImageData(
    List<SessionMessage> diskMessages,
    List<SessionMessage>? memoryMessages,
  ) {
    if (memoryMessages == null || memoryMessages.isEmpty) return diskMessages;
    final memoryMap = {
      for (final m in memoryMessages)
        if (m.imageData != null) '${m.msgId}_${m.role.index}': m,
    };
    if (memoryMap.isEmpty) return diskMessages;
    return diskMessages.map((m) {
      final key = '${m.msgId}_${m.role.index}';
      final mem = memoryMap[key];
      if (mem != null && m.imageData == null) {
        return SessionMessage(
          role: m.role,
          timestampUtcIso8601: m.timestampUtcIso8601,
          msgId: m.msgId,
          body: m.body,
          status: m.status,
          reasoning: m.reasoning,
          imageData: mem.imageData,
          imageMimeType: mem.imageMimeType,
          modelId: m.modelId,
        );
      }
      return m;
    }).toList();
  }

  /// 在 build() 完成后由 [ChatControllerParams.autoTriggerReply] 调度执行。
  ///
  /// 复用 [sendUserMessage] 里的 provider/model 解析链（对话级 → 第一个有 key 的
  /// provider → 全局设置），但**不** append user 消息，直接开始流式回复。
  Future<void> _triggerAssistantReply() async {
    _trace('chat_controller.trigger_assistant_reply');
    final sessionProviderId = _providerId;
    final sessionModelId = _modelId;

    if (sessionProviderId != null && sessionModelId != null) {
      final configStore = ref.read(llmConfigStoreProvider);
      final provider = await configStore.getProvider(sessionProviderId);
      if (provider == null) {
        _trace('chat_controller.provider_not_found',
            attrs: {'providerId': sessionProviderId});
        return;
      }
      final apiKey = await configStore.readApiKey(sessionProviderId);
      if (apiKey.isEmpty) return;
      await _startStreamingWithConfig(
        providerConfig: provider,
        apiKey: apiKey,
        model: sessionModelId,
      );
      return;
    }

    // Fallback: 第一个有 key 且有 model 的 provider
    final configStore = ref.read(llmConfigStoreProvider);
    final providers = await configStore.loadAll();
    for (final p in providers) {
      final key = await configStore.readApiKey(p.id);
      if (key.isNotEmpty && p.models.isNotEmpty) {
        await _startStreamingWithConfig(
          providerConfig: p,
          apiKey: key,
          model: p.models.first.id,
        );
        return;
      }
    }

    // 没有可用的 provider/model，静默返回
  }

  /// Retry / Regenerate the last assistant message.
  /// Removes the last assistant message (done or error) and re-triggers the LLM stream
  /// against the existing preceding user message — does NOT re-append the user message.
  Future<void> retryLastMessage() async {
    final messages = state.value ?? [];
    if (messages.isEmpty) return;

    // Find the last non-streaming assistant message
    int lastAssistantIdx = -1;
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == SessionRole.assistant &&
          messages[i].status != SessionMessageStatus.streaming) {
        lastAssistantIdx = i;
        break;
      }
    }

    if (lastAssistantIdx == -1) return;

    // Sanity check: there should be a user message just before the assistant.
    // (avoid sending to LLM without user input)
    if (lastAssistantIdx == 0) return;
    if (messages[lastAssistantIdx - 1].role != SessionRole.user) return;

    // 1. 取消当前流（同步，不阻塞）—— 防止并发
    _cancelCurrentStream();

    // 2. 从 session.md 删除最后一条 assistant
    final sessionStore = await ref.read(sessionStoreProvider.future);
    await sessionStore.removeLastAssistantMessage(nodeId: nodeId);

    // 3. 重新从磁盘读取 state（state 现在反映删除后的对话，去掉了 assistant 条目）
    final reloaded = await _read();
    state = AsyncData(reloaded);

    // 4. 不再追加 user 消息 —— 它已经在磁盘上。直接触发 LLM 流。
    await _triggerLlmStream(messagesForLlm: reloaded);
  }

  Future<void> sendUserMessage(
    String text, {
    Uint8List? imageData,
    String? imageMimeType,
  }) async {
    try {
      final trimmed = text.trim();
      // 允许只发图片不发文本
      if (trimmed.isEmpty && imageData == null) return;

      // 1. 取消当前流（同步，不阻塞）
      _cancelCurrentStream();

      // 2. 乐观追加用户消息到 state（不读磁盘）
      final timestamp = DateTime.now().toUtc().toIso8601String();
      final userMsg = SessionMessage(
        role: SessionRole.user,
        timestampUtcIso8601: timestamp,
        msgId: 'pending',
        body: trimmed,
        status: SessionMessageStatus.done,
        imageData: imageData,
        imageMimeType: imageMimeType,
      );
      final current = state.value ?? [];
      state = AsyncData([...current, userMsg]);
      final messagesForLlm = state.value!;

      // 3. 磁盘写入（异步，不阻塞 UI）
      final sessionStore = await ref.read(sessionStoreProvider.future);
      await sessionStore.appendUserMessage(nodeId: nodeId, content: trimmed);

      // 4. 触发关键词榜 stale 检测（fire-and-forget，不阻塞主流程）
      // - 方案：通过 NodeStore.getThemeIdByNodeId 反查 themeId
      //   （避免改 ChatControllerParams 签名）
      // - try-catch 包裹：异常静默吞掉，仅记录 trace，不阻塞 LLM 流式回复
      unawaited(_markStaleIfAnalyzed());

      // 5. 触发 LLM 流
      await _triggerLlmStream(
        messagesForLlm: messagesForLlm,
        imageData: imageData,
        imageMimeType: imageMimeType,
      );
    } catch (e, st) {
      final logger = await ref.read(appLoggerProvider.future);
      await logger.error(e, st, hint: 'sendUserMessage', attrs: {'nodeId': nodeId, 'title': title});
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// 触发 LLM 流式回复。
  ///
  /// 入口要求：
  /// - [messagesForLlm] 已经包含所有要发给 LLM 的历史消息（包括最后一条 user）。
  ///   - 新消息场景：[sendUserMessage] 已把 user 消息 append 到 state 与磁盘。
  ///   - 重试场景：[retryLastMessage] 已从磁盘删 assistant 并 reload state，
  ///     user 消息仍然存在。
  ///
  /// 本方法不修改 state.value，不写磁盘，只启动 ChatTaskService。
  Future<void> _triggerLlmStream({
    required List<SessionMessage> messagesForLlm,
    Uint8List? imageData,
    String? imageMimeType,
  }) async {
    final sessionStore = await ref.read(sessionStoreProvider.future);
    final sessionProviderId = _providerId;
    final sessionModelId = _modelId;

    if (sessionProviderId != null && sessionModelId != null) {
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
        providerConfig: provider,
        apiKey: apiKey,
        model: sessionModelId,
        imageData: imageData,
        imageMimeType: imageMimeType,
        currentMessages: messagesForLlm,
      );
    } else {
      final configStore = ref.read(llmConfigStoreProvider);
      final providers = await configStore.loadAll();
      String? fallbackApiKey;
      String? fallbackModel;
      LlmProviderConfig? fallbackProvider;
      for (final p in providers) {
        final key = await configStore.readApiKey(p.id);
        if (key.isNotEmpty && p.models.isNotEmpty) {
          fallbackApiKey = key;
          fallbackModel = p.models.first.id;
          fallbackProvider = p;
          break;
        }
      }
      if (fallbackApiKey != null && fallbackApiKey.isNotEmpty) {
        await _startStreamingWithConfig(
          providerConfig: fallbackProvider!,
          apiKey: fallbackApiKey,
          model: fallbackModel!,
          imageData: imageData,
          imageMimeType: imageMimeType,
          currentMessages: messagesForLlm,
        );
      } else {
        await sessionStore.appendAssistantMessage(
          nodeId: nodeId,
          content: '[未配置 API Key] 请到设置 > 模型提供商中配置 API Key。',
        );
        state = AsyncData(await _read());
        return;
      }
    }
  }

  /// 关键词榜 stale 触发（fire-and-forget 内部方法）。
  ///
  /// 由 [sendUserMessage] 在磁盘写入成功后调用。
  /// 流程：
  ///   1. 通过 NodeStore.getThemeIdByNodeId 反查 leaf 所属 themeId
  ///   2. 拿对应 theme 的 KeywordAnalysisService
  ///   3. 调 markStaleIfAnalyzed 标记当前 leaf 为 stale（如已分析过）
  ///
  /// 反查失败或服务不可用时静默吞掉异常，不阻塞主流程。
  /// 仅在 trace 日志中留痕（便于排查为什么某些 leaf 没标 stale）。
  Future<void> _markStaleIfAnalyzed() async {
    try {
      final nodeStore = await ref.read(nodeStoreProvider.future);
      final themeId = await nodeStore.getThemeIdByNodeId(nodeId);
      if (themeId == null) {
        // 节点可能已被删除（极少见），跳过
        _trace('chat_controller.mark_stale_skipped', attrs: {
          'nodeId': nodeId,
          'reason': 'theme_not_found',
        });
        return;
      }
      final service = await ref.read(keywordAnalysisServiceProvider(themeId).future);
      await service.markStaleIfAnalyzed(leafId: nodeId);
    } catch (e, st) {
      // 静默失败：异常被吞掉，仅记录 trace + logger，不阻塞主流程
      _trace('chat_controller.mark_stale_failed', attrs: {
        'nodeId': nodeId,
        'error': e.toString(),
      });
      try {
        final logger = await ref.read(appLoggerProvider.future);
        await logger.error(
          e,
          st,
          hint: 'chat_controller._markStaleIfAnalyzed',
          attrs: {'nodeId': nodeId},
        );
      } catch (_) {
        // logger 不可用也吞掉
      }
    }
  }

  Future<void> _startStreamingWithConfig({
    required LlmProviderConfig providerConfig,
    required String apiKey,
    required String model,
    Uint8List? imageData,
    String? imageMimeType,
    List<SessionMessage>? currentMessages,
  }) async {
    final sessionStore = await ref.read(sessionStoreProvider.future);
    final logger = await ref.read(appLoggerProvider.future);
    // 优先用调用方传入的 in-memory 消息（含图片等内存态数据），
    // 避免 _read() 从磁盘重读丢失未持久化的字段。
    final history = currentMessages ?? await _read();

    // 解析联网搜索状态
    final webSearch = _resolveWebSearch(providerConfig.type);
    final client = LlmClient.forConfig(providerConfig, webSearch: webSearch);

    // 更新 UI 状态（显示开始）
    state = AsyncData(history);

    // 委托给 ChatTaskService 在后台运行
    await ref.read(chatTaskServiceProvider.notifier).startTask(
      nodeId: nodeId,
      client: client,
      apiKey: apiKey,
      model: model,
      history: history,
      systemPrompt: _systemPrompt,
      sessionStore: sessionStore,
      logger: logger,
      webSearch: webSearch,
      deepThinking: _resolveDeepThinking(model),
      imageData: imageData,
      imageMimeType: imageMimeType,
    );

    // Update search index (fire-and-forget after task completes)
    // 注意：这里搜索索引更新将由 ChatTaskService 的 onDone 处理
    // 我们保持这个方法的签名不变，但实际执行在 ChatTaskService 中
  }

  /// 解析当前提供商的联网搜索是否应该开启
  bool _resolveWebSearch(LlmProviderType? providerType) {
    if (providerType == null) {
      dev.log('_resolveWebSearch: providerType=null → false', name: 'chat_controller');
      return false;
    }
    final support = webSearchSupportMap[providerType];
    if (support != WebSearchSupport.supported) {
      dev.log('_resolveWebSearch: $providerType not supported → false', name: 'chat_controller');
      return false;
    }
    final settings = ref.read(settingsControllerProvider).value;
    if (settings == null) {
      dev.log('_resolveWebSearch: settings=null → default true', name: 'chat_controller');
      return true;
    }
    final enabled = settings.isWebSearchEnabled(providerType.name);
    dev.log('_resolveWebSearch: $providerType enabled=$enabled', name: 'chat_controller');
    return enabled;
  }

  /// 解析当前模型是否应该开启深度思考：
  /// 1. 用户在 chat_screen toggle 了开关 → 才进入这里
  /// 2. 当前模型必须在 `ModelCapability.deepThinking` 白名单内
  ///    否则不发 `thinking` 参数（避免给不支持的模型传未识别字段导致 400）
  ///
  /// 注意：capability 判断基于 model id 的关键字匹配（与 [inferCapabilities] 一致），
  /// 不依赖 provider 元信息——所以即使 session 用全局默认模型也能正常判断。
  bool _resolveDeepThinking(String modelId) {
    if (!_deepThinkingEnabled) return false;
    final caps = inferCapabilities(modelId);
    final supported = caps.contains(ModelCapability.deepThinking);
    dev.log('_resolveDeepThinking: model=$modelId enabled=$supported',
        name: 'chat_controller');
    return supported;
  }
}

final chatControllerProvider =
    AsyncNotifierProvider.autoDispose.family<ChatController, List<SessionMessage>, ChatControllerParams>(
  ChatController.new,
);

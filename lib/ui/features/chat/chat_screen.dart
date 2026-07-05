import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectionArea;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/data/services/doc_split_service.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/chat/auto_title_controller.dart';
import 'package:thk_tree/ui/features/chat/chat_controller.dart';
import 'package:thk_tree/ui/features/chat/widgets/model_selector_panel.dart';
import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/data/services/llm_provider.dart' show estimateTokens;
import 'package:thk_tree/ui/core/shared/chat_composer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:thk_tree/ui/core/shared/chat_list_view.dart';
import 'package:thk_tree/ui/core/shared/llm_setup_check.dart';
import 'package:thk_tree/ui/core/shared/message_bubble.dart';
import 'package:thk_tree/ui/core/shared/title_suggestion_screen.dart';
import 'package:thk_tree/ui/features/chat/widgets/chat_outline_sheet.dart';
import 'package:thk_tree/ui/features/chat/widgets/chat_search_sheet.dart';
import 'package:thk_tree/ui/features/chat/widgets/chat_markdown_sheet.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';
import 'package:thk_tree/data/stores/note_store.dart';
import 'package:thk_tree/ui/features/notes/note_editor_screen.dart';
import 'package:thk_tree/ui/features/themes/full_tree_screen.dart';
import 'package:thk_tree/ui/features/themes/theme_detail_controller.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.themeId,
    required this.nodeId,
    required this.title,
    this.autoTriggerReply = false,
    this.isDocSplit = false,
  });

  final String themeId;
  final String nodeId;
  final String title;

  /// 若为 true，chat 加载完后若最后一条是 user 消息（status == done），
  /// 会自动调一次 LLM 回复（用于"笔记→对话自动续聊"和"summary 创建分支"场景）。
  final bool autoTriggerReply;

  final bool isDocSplit;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late final ChatControllerParams _args;
  final _chatListKey = GlobalKey<ChatListViewState>();
  bool _showModelPanel = false;
  String? _currentSelectedText;

  // ---- 图片选择状态 ----
  Uint8List? _selectedImageData;
  String? _selectedImageMimeType;

  // ---- 空白分支（A 模式）后置自动 title 生成 ----
  /// 上次 build 的 isStreaming，用于检测 true → false 边沿。
  bool _wasStreaming = false;
  /// 防抖：触发过一次就永远 true（避免 retry / 重新加载时重复触发）。
  bool _autoTitleTriggered = false;
  /// DB 写新 title 后，缓存为本地展示值，覆盖 widget.title 显示在 nav bar。
  String? _displayedTitle;
  /// 防抖：自动保存默认模型后置 true，避免重复调用 switchModel。
  bool _autoModelSaved = false;
  String? _panelProviderId;
  String? _panelModelId;

  @override
  void initState() {
    super.initState();
    _args = ChatControllerParams(
      nodeId: widget.nodeId,
      title: widget.title,
      autoTriggerReply: widget.autoTriggerReply,
    );
  }

  /// 从当前对话的 providerId/modelId 查找 contextWindow，找不到则 fallback
  int _resolveContextWindow(String? providerId, String? modelId) {
    if (providerId != null && modelId != null) {
      final providers = ref.read(llmProvidersProvider).value;
      if (providers != null) {
        final provider = providers.where((p) => p.id == providerId).firstOrNull;
        if (provider != null) {
          final model = provider.models.where((m) => m.id == modelId).firstOrNull;
          if (model != null) {
            return model.contextWindow;
          }
        }
      }
    }
    // fallback 到第一个有 models 的 provider 的默认 context window
    final providers = ref.read(llmProvidersProvider).value;
    if (providers != null) {
      for (final p in providers) {
        if (p.models.isNotEmpty) {
          return p.models.first.contextWindow;
        }
      }
    }
    return 64000;
  }

  /// 获取当前对话的模型显示信息
  String? _resolveModelSubtitle(String? providerId, String? modelId) {
    if (providerId == null || modelId == null) return null;
    final providers = ref.read(llmProvidersProvider).value;
    if (providers == null) return null;
    final provider = providers.where((p) => p.id == providerId).firstOrNull;
    if (provider == null) return null;
    return '$modelId · ${provider.name}';
  }

  /// 将助手消息保存为笔记（临时标题 = 正文前 N 字）。
  ///
  /// 使用当前对话所在主题作为笔记分类。若主题不存在则自动创建同名主题。
  Future<void> _saveMessageAsNote(SessionMessage message) async {
    if (message.body.trim().isEmpty || !mounted) return;

    // 生成临时标题：去掉 Markdown 标记，取前 20 字
    final plainText = message.body
        .replaceAll(RegExp(r'[#*_`~\[\]()>|]'), '')
        .replaceAll(RegExp(r'\n+'), ' ')
        .trim();
    final tempTitle = plainText.length <= 20
        ? plainText
        : '${plainText.substring(0, 20)}…';

    try {
      final paths = await ref.read(appPathsProvider.future);

      // 确保主题存在，不存在则自动创建同名主题
      final themeStore = await ref.read(themeStoreProvider.future);
      final themes = await themeStore.listThemes();
      final themeTitle = _displayedTitle ?? widget.title;
      var themeId = widget.themeId;

      final themeExists = themes.any((t) => t.themeId == themeId);
      if (!themeExists) {
        final newTheme = await themeStore.createTheme(title: themeTitle);
        themeId = newTheme.themeId;
      }

      final notesDir = Directory('${paths.themesDir.path}/$themeId/notes');
      final store = NoteStore(notesDir: notesDir);

      final meta = await store.createNote(
        themeId: themeId,
        title: tempTitle,
      );
      await store.writeBody(meta.noteId, message.body);

      ref.read(noteListVersionProvider.notifier).bump();

      if (!mounted) return;

      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => NoteEditorScreen(
            themeId: themeId,
            themeTitle: themeTitle,
            themePath: '${paths.themesDir.path}/$themeId',
            notesDir: notesDir.path,
            noteId: meta.noteId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ThkAlert.show(
        context: context,
        message: 'Failed to save note: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // 监听 auto title 任务结果，更新本地 _displayedTitle 缓存。
    ref.listen<AsyncValue<AutoTitleState>>(
      autoTitleControllerProvider(widget.nodeId),
      (prev, next) {
        final s = next.value;
        if (s == null) return;
        if (s.status == AutoTitleStatus.done && s.newTitle != null) {
          if (_displayedTitle != s.newTitle) {
            setState(() {
              _displayedTitle = s.newTitle;
            });
          }
        } else if (s.status == AutoTitleStatus.failed && s.error == 'noModel') {
          // 模型未配置 → 弹引导 alert（仅 widget mounted 时）。
          showLlmSetupAlert(
            context: context,
            status: LlmSetupStatus.noTitleModelConfigured,
            container: ProviderScope.containerOf(context, listen: false),
          );
        }
      },
    );

    final messagesAsync = ref.watch(chatControllerProvider(_args));
    final isStreaming = messagesAsync.maybeWhen(
      data: (messages) => messages.any((m) => m.status == SessionMessageStatus.streaming),
      orElse: () => false,
    );

    // 空白分支（A 模式）后置自动 title 生成：检测 isStreaming true → false 边沿。
    // 仅当当前 nav bar 显示的还是占位 title 时才触发；已调过一次后永久防抖。
    if (_wasStreaming && !isStreaming && !_autoTitleTriggered) {
      final placeholder = l10n.branchBlankInitialTitle;
      if (_displayedTitle == placeholder || widget.title == placeholder) {
        _autoTitleTriggered = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // 委托给 AutoTitleController（任务与 widget 解耦：
          // 即使 widget 后续 dispose，Notifier 自己的 ref 仍能跑完任务并写 DB / 刷 tree）。
          final container = ProviderScope.containerOf(context, listen: false);
          container.read(autoTitleControllerProvider(widget.nodeId).notifier).runIfNeeded(
            themeId: widget.themeId,
            currentTitle: _displayedTitle ?? widget.title,
            transcript: _collectTranscriptForTitle(),
            placeholder: placeholder,
          );
        });
      }
    }
    _wasStreaming = isStreaming;

    // 读取当前对话的 providerId/modelId
    final chatCtrl = ref.read(chatControllerProvider(_args).notifier);
    var currentProviderId = chatCtrl.providerId;
    var currentModelId = chatCtrl.modelId;

    // 如果对话未指定模型，fallback 到全局默认设置
    final settings = ref.watch(settingsControllerProvider).value;
    final providers = ref.watch(llmProvidersProvider).value;
    final resolved = resolveChatModel(
      sessionProviderId: currentProviderId,
      sessionModelId: currentModelId,
      chatDefaultProviderId: settings?.chatDefaultProviderId,
      chatDefaultModelId: settings?.chatDefaultModelId,
      providers: providers,
    );
    currentProviderId = resolved.$1.isNotEmpty ? resolved.$1 : null;
    currentModelId = resolved.$2.isNotEmpty ? resolved.$2 : null;

    // 自动保存到 session.md 以便模型选择器显示选中状态
    if (currentProviderId != null && currentModelId != null && !_autoModelSaved) {
      _autoModelSaved = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await ref.read(chatControllerProvider(_args).notifier).switchModel(currentProviderId!, currentModelId!);
      });
    }

    final effectiveProviderId = _showModelPanel ? (_panelProviderId ?? currentProviderId) : currentProviderId;
    final effectiveModelId = _showModelPanel ? (_panelModelId ?? currentModelId) : currentModelId;

    // 联网搜索状态
    final currentProviderType = chatCtrl.providerType;
    final webSearchSupported = currentProviderType != null &&
        webSearchSupportMap[currentProviderType] == WebSearchSupport.supported;
    final webSearchEnabled = webSearchSupported &&
        (settings?.isWebSearchEnabled(currentProviderType.name) ?? true);

    final modelSubtitle = _resolveModelSubtitle(effectiveProviderId, effectiveModelId);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.pageBg,
      navigationBar: ThkNavBar.inline(
        title: '',
        middle: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _displayedTitle ?? widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (modelSubtitle != null)
              Text(
                modelSubtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.go('/themes/${widget.themeId}/tree');
            }
          },
          child: const Icon(AppIcons.back),
        ),
        trailing: CupertinoButton(
          key: const ValueKey('more_button'),
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: isStreaming ? null : () => _showMoreActions(context),
          child: Icon(
            AppIcons.more,
            size: 24,
            color: isStreaming
                ? AppColors.textTertiary
                : AppColors.accent,
          ),
        ),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // 消息列表 - 面板出现时它会被压缩变小
              Expanded(
                child: Listener(
                  onPointerDown: (_) {
                    _dismissModelPanel();
                    FocusScope.of(context).unfocus();
                  },
                  child: messagesAsync.when(
                    data: (messages) => SelectionArea(
                      onSelectionChanged: (value) {
                        final text = value?.plainText;
                        if (text != null && text.trim().isNotEmpty) {
                          _currentSelectedText = text;
                        } else {
                          _currentSelectedText = null;
                        }
                      },
                      child: ChatListView(
                        key: _chatListKey,
                        messages: messages,
                        messageBuilder: (context, message) {
                          final isLastAssistant = message.role == SessionRole.assistant &&
                              message.status != SessionMessageStatus.streaming &&
                              message == messages.lastWhere(
                                (m) => m.role == SessionRole.assistant,
                                orElse: () => message,
                              );

                          String? userQuestion;
                          if (message.role == SessionRole.assistant) {
                            final idx = messages.indexOf(message);
                            if (idx > 0) {
                              for (var i = idx - 1; i >= 0; i--) {
                                if (messages[i].role == SessionRole.user) {
                                  userQuestion = messages[i].body;
                                  break;
                                }
                              }
                            }
                          }

                          // 时间戳显示逻辑：第一条、角色切换、或间隔 > 2 分钟
                          final showTimestamp = _shouldShowTimestamp(messages, message);

                          return MessageBubble(
                            message: message,
                            showTimestamp: showTimestamp,
                            onRetry: isLastAssistant
                                ? () => ref.read(chatControllerProvider(_args).notifier).retryLastMessage()
                                : null,
                            userQuestion: userQuestion,
                            onSaveToNote: message.role == SessionRole.assistant &&
                                    message.status == SessionMessageStatus.done
                                ? () => _saveMessageAsNote(message)
                                : null,
                          );
                        },
                      ),
                    ),
                    error: (e, st) => Center(child: Text(e.toString())),
                    loading: () => const Center(child: CupertinoActivityIndicator()),
                  ),
                ),
              ),
              // Context 使用条
              messagesAsync.maybeWhen(
                data: (messages) {
                  final contextWindow = _resolveContextWindow(effectiveProviderId, effectiveModelId);
                  return Listener(
                    onPointerDown: (_) => _dismissModelPanel(),
                    child: _ContextUsageBar(
                      messages: messages,
                      contextWindow: contextWindow,
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              // 输入框
              // Listener 用于在 panel 显示时拦截 ChatComposer 区域的 pointer down
              // 事件关闭 panel。不拦截事件本身（不影响 TextField 聚焦、按钮点击）
              // —— 仅为“先关 panel”这一动作提供了一个在 pointer down 阶段就能触发
              // 的轻量级路径，避免 TextField 的 TapGestureRecognizer 在 arena 中赢
              // 而导致外层 GestureDetector 无法关闭 panel 的问题。
              Listener(
                onPointerDown: (_) {
                  _dismissModelPanel();
                },
                child: ChatComposer(
                  hintText: l10n.messageHint,
                  isStreaming: isStreaming,
                  onSend: (text, {imageData, imageMimeType}) async {
                    await ref.read(chatControllerProvider(_args).notifier).sendUserMessage(
                      text,
                      imageData: imageData,
                      imageMimeType: imageMimeType,
                    );
                    // 发送后清除图片选择状态
                    if (mounted) {
                      setState(() {
                        _selectedImageData = null;
                        _selectedImageMimeType = null;
                      });
                    }
                  },
                  onStopStreaming: () async {
                    await ref.read(chatControllerProvider(_args).notifier).stopStreaming();
                  },
                  onModelSelectorTap: () {
                    if (isStreaming) return;
                    FocusScope.of(context).unfocus();
                    var nextProviderId = currentProviderId;
                    var nextModelId = currentModelId;
                    if (nextProviderId == null || nextModelId == null) {
                      final providers = ref.read(llmProvidersProvider).value;
                      if (providers != null) {
                        for (final p in providers) {
                          if (p.models.isNotEmpty) {
                            nextProviderId = p.id;
                            nextModelId = p.models.first.id;
                            break;
                          }
                        }
                      }
                    }
                    if (!_showModelPanel && nextProviderId != null && nextModelId != null) {
                      _panelProviderId = nextProviderId;
                      _panelModelId = nextModelId;
                      if (chatCtrl.providerId == null || chatCtrl.modelId == null) {
                        ref.read(chatControllerProvider(_args).notifier).switchModel(nextProviderId!, nextModelId!);
                      }
                    }
                    setState(() => _showModelPanel = !_showModelPanel);
                  },
                  webSearchEnabled: webSearchEnabled,
                  webSearchSupported: webSearchSupported,
                  onWebSearchToggle: webSearchSupported
                      ? () {
                          ref.read(settingsControllerProvider.notifier).saveWebSearchEnabled(
                            currentProviderType.name,
                            !webSearchEnabled,
                          );
                        }
                      : null,
                  onImagePick: () => _showImagePicker(context),
                  imageSupported: _isImageSupported(currentProviderId, currentModelId),
                  selectedImageData: _selectedImageData,
                  selectedImageMimeType: _selectedImageMimeType,
                  onImageRemove: () {
                    if (mounted) {
                      setState(() {
                        _selectedImageData = null;
                        _selectedImageMimeType = null;
                      });
                    }
                  },
                ),
              ),
              // 模型面板（出现在输入框下方，取代软键盘位置）
              if (_showModelPanel && !isStreaming)
                Flexible(
                  child: ModelSelectorPanel(
                    currentProviderId: effectiveProviderId,
                    currentModelId: effectiveModelId,
                    onModelSelected: (providerId, modelId) async {
                      await ref.read(chatControllerProvider(_args).notifier).switchModel(providerId, modelId);
                      _panelProviderId = providerId;
                      _panelModelId = modelId;
                      if (mounted) setState(() => _showModelPanel = false);
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _dismissModelPanel() {
    if (!_showModelPanel || !mounted) return;
    setState(() => _showModelPanel = false);
  }

  /// 检查当前模型是否支持图片
  bool _isImageSupported(String? providerId, String? modelId) {
    if (providerId == null || modelId == null) return false;
    final providers = ref.read(llmProvidersProvider).value;
    if (providers == null) return false;
    final provider = providers.where((p) => p.id == providerId).firstOrNull;
    if (provider == null) return false;
    final model = provider.models.where((m) => m.id == modelId).firstOrNull;
    if (model == null) return false;
    return model.supportsVision;
  }

  /// 显示图片选择器
  Future<void> _showImagePicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;

    // 检查是否支持图片
    final chatCtrl = ref.read(chatControllerProvider(_args).notifier);
    final settings = ref.read(settingsControllerProvider).value;
    final providers = ref.read(llmProvidersProvider).value;
    final resolved = resolveChatModel(
      sessionProviderId: chatCtrl.providerId,
      sessionModelId: chatCtrl.modelId,
      chatDefaultProviderId: settings?.chatDefaultProviderId,
      chatDefaultModelId: settings?.chatDefaultModelId,
      providers: providers,
    );
    final currentProviderId = resolved.$1.isNotEmpty ? resolved.$1 : null;
    final currentModelId = resolved.$2.isNotEmpty ? resolved.$2 : null;

    if (!_isImageSupported(currentProviderId, currentModelId)) {
      ThkAlert.show(
        context: context,
        message: '当前模型不支持图片功能',
        defaultAction: l10n.ok,
      );
      return;
    }

    // 显示 ActionSheet
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('选择图片来源'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'camera'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(AppIcons.camera, size: 20),
                const SizedBox(width: 8),
                Text('拍照'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'gallery'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(AppIcons.image, size: 20),
                const SizedBox(width: 8),
                Text('从相册选择'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ),
    );

    if (action == null || !mounted) return;

    try {
      final picker = ImagePicker();
      final source = action == 'camera' ? ImageSource.camera : ImageSource.gallery;
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile == null || !mounted) return;

      final bytes = await pickedFile.readAsBytes();
      final mimeType = pickedFile.mimeType ?? 'image/jpeg';

      setState(() {
        _selectedImageData = bytes;
        _selectedImageMimeType = mimeType;
      });
    } catch (e) {
      if (!mounted) return;
      ThkAlert.show(
        context: context,
        message: '选择图片失败：$e',
        defaultAction: l10n.ok,
      );
    }
  }

  /// 判断是否应该在该消息上方显示时间戳。
  ///
  /// 规则：第一条消息、角色切换、或与前一条同角色但间隔 > 2 分钟。
  static bool _shouldShowTimestamp(List<SessionMessage> messages, SessionMessage message) {
    final idx = messages.indexOf(message);
    if (idx <= 0) return true;

    final prev = messages[idx - 1];
    if (prev.role != message.role) return true;

    final prevTime = DateTime.tryParse(prev.timestampUtcIso8601);
    final curTime = DateTime.tryParse(message.timestampUtcIso8601);
    if (prevTime == null || curTime == null) return true;

    return curTime.difference(prevTime).inMinutes > 2;
  }

  void _showMoreActions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final messagesAsync = ref.read(chatControllerProvider(_args));
    final messages = messagesAsync.maybeWhen(
      data: (m) => m,
      orElse: () => <SessionMessage>[],
    );

    // 用 Overlay 直接画"更多"菜单，不走 Navigator 路由栈 —— 这样不会触发
    // primary focus 转移，底层 SelectionArea 的选区高亮得以保持。
    unawaited(_showOverlayMoreActions(
      context: context,
      actions: [
        if (widget.isDocSplit)
          GridAction(
            label: l10n.submitTreeStructure,
            icon: AppIcons.checkCircle,
            color: CupertinoColors.systemGreen,
            onPressed: () => unawaited(_onSubmitDocSplit()),
          ),
        GridAction(
          label: l10n.chatOutline,
          icon: AppIcons.document,
          color: AppColors.accent,
          onPressed: () => _onOpenOutline(context, messages),
        ),
        GridAction(
          label: l10n.chatSearch,
          icon: AppIcons.search,
          color: CupertinoColors.systemOrange,
          onPressed: () => _onOpenSearch(context, messages),
        ),
        GridAction(
          label: l10n.swipeBranch,
          icon: AppIcons.branch,
          color: AppColors.accent,
          onPressed: () => unawaited(_onCreateBranchFromMenu(context)),
        ),
        GridAction(
          label: l10n.chatMarkdown,
          icon: AppIcons.document,
          color: CupertinoColors.systemTeal,
          onPressed: () {
            showChatMarkdownSheet(context, widget.nodeId);
          },
        ),
        GridAction(
          label: l10n.viewTree,
          icon: AppIcons.accountTree,
          color: CupertinoColors.systemIndigo,
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => FullTreeScreen(
                  themeId: widget.themeId,
                  currentNodeId: widget.nodeId,
                ),
              ),
            );
          },
        ),
      ],
    ));
  }

  /// 用 [OverlayEntry] 直接在 Overlay 上画"更多"菜单，避免 [showModalBottomSheet]
  /// 抢焦点导致 [SelectionArea] 的选区被清掉。
  ///
  /// 行为对齐 [ThkGridBottomSheet.show]：
  /// - 点 action → 先移除 overlay，再异步执行 [GridAction.onPressed]
  /// - 点背景/外部 → 移除 overlay 并 complete（无 action）
  Future<void> _showOverlayMoreActions({
    required BuildContext context,
    required List<GridAction> actions,
  }) async {
    final completer = Completer<void>();
    OverlayEntry? entry;
    var dismissed = false;

    void dismiss([VoidCallback? followUp]) {
      if (dismissed) return;
      dismissed = true;
      entry?.remove();
      // 在 overlay 移除后再执行后续动作（典型场景：pop 当前页面并 push 新页面）。
      // 用 microtask 让 overlay 的移除先排到事件队列，避免 widget tree 中
      // entry 与被 pop 的页面同时存在造成状态混乱。
      if (followUp != null) {
        Future.microtask(followUp);
      }
      if (!completer.isCompleted) completer.complete();
    }

    entry = OverlayEntry(builder: (ctx) {
      return _MoreActionsOverlayPanel(
        actions: actions,
        onPicked: (action) => dismiss(action.onPressed),
        onDismiss: () => dismiss(),
      );
    });

    Overlay.of(context, rootOverlay: true).insert(entry);
    return completer.future;
  }

  Future<void> _onOpenOutline(BuildContext context, List<SessionMessage> messages) async {
    // 注意：ThkGridBottomSheet 已经 pop 了自身，不要再 pop
    final selected = await showChatOutlineSheet(context, messages);
    if (selected != null && mounted) {
      _chatListKey.currentState?.scrollToMessage(selected.msgId);
    }
  }

  Future<void> _onOpenSearch(BuildContext context, List<SessionMessage> messages) async {
    // 注意：ThkGridBottomSheet 已经 pop 了自身，不要再 pop
    final selected = await showChatSearchSheet(context, messages);
    if (selected != null && mounted) {
      _chatListKey.currentState?.scrollToMessage(selected.msgId);
    }
  }

  Future<void> _onSubmitDocSplit() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final nodeStore = await ref.read(nodeStoreProvider.future);
      final sessionStore = await ref.read(sessionStoreProvider.future);
      final doc = await sessionStore.readSession(widget.nodeId);

      String? lastAssistantBody;
      for (final msg in doc.messages.reversed) {
        if (msg.role == SessionRole.assistant &&
            msg.status == SessionMessageStatus.done &&
            msg.body.trim().isNotEmpty) {
          lastAssistantBody = msg.body;
          break;
        }
      }
      if (lastAssistantBody == null) {
        if (!mounted) return;
        ThkAlert.show(context: context, message: l10n.docSplitNoAssistantMessage);
        return;
      }

      var sourceMdText = '';
      for (final msg in doc.messages) {
        if (msg.role == SessionRole.user && msg.body.trim().isNotEmpty) {
          sourceMdText = msg.body;
          break;
        }
      }

      final themeRow = await nodeStore.getThemeRow(themeId: widget.themeId);
      final themePath = themeRow['themePath']! as String;

      final service = DocSplitService(
        nodeStore: nodeStore,
        sessionStore: sessionStore,
      );
      final createdCount = await service.materializeTree(
        docSplitNodeId: widget.nodeId,
        themeId: widget.themeId,
        themePath: themePath,
        sourceMdText: sourceMdText,
      );

      if (!mounted) return;

      if (createdCount == 0) {
        ThkAlert.show(context: context, message: l10n.docSplitParsingFailed);
        return;
      }

      ref.read(themeDetailControllerProvider(widget.themeId).notifier).refresh();
      ThkAlert.show(context: context, message: l10n.docSplitSuccess(createdCount));
      context.go('/themes/${widget.themeId}/tree');
    } catch (e) {
      if (!mounted) return;
      ThkAlert.show(context: context, message: e.toString());
    }
  }

  /// 从顶部 branch 按钮进入：先弹 sheet 让用户选 mode，再 [_showBranchFlow]。
  Future<void> _onCreateBranchFromMenu(BuildContext context) async {
    // 在弹 sheet 之前读取选中文本，避免选区被清除
    final selected = _currentSelectedText;
    debugPrint('[ChatScreen] _onCreateBranchFromMenu: selectedText=${selected?.length ?? 'null'} chars');

    final mode = await showBranchModeSheet(
      context,
      selectedText: selected,
    );
    if (mode == null) return;
    if (!context.mounted) return;

    await _showBranchFlow(
      context,
      mode: mode,
      selectedText: selected?.trim().isNotEmpty == true ? selected : null,
    );
  }

  /// 触发"创建分支"全流程。
  ///
  /// [mode] 决定是否需要先 LLM 总结：
  /// - [BranchMode.summarize] 且 [selectedText] 为空：先 LLM 总结当前对话。
  /// - [BranchMode.raw]：[selectedText] 非空时用选中文本；为空时用 parentTranscript 原文。
  ///
  /// [selectedText] 非空时会被直接使用，忽略 mode 中的总结步骤（用户从选区菜单进入）。
  ///
  /// 实际逻辑委托给 [showBranchFlow] 顶层函数，这里只负责：
  /// 1. 构造 [parentTranscript]（从 session.md 读）
  /// 2. 解析 providerId/modelId（chat 级 → 全局设置）
  Future<void> _showBranchFlow(
    BuildContext context, {
    required BranchMode mode,
    String? selectedText,
  }) async {
    debugPrint('[ChatScreen._showBranchFlow] mode=$mode, '
        'selectedText=${selectedText?.length ?? 'null'} chars, '
        'preview=${selectedText?.substring(0, (selectedText.length).clamp(0, 80)) ?? 'null'}');
    final l10n = AppLocalizations.of(context)!;
    try {
      // 1. 构造 parentTranscript
      final nodeStore = await ref.read(nodeStoreProvider.future);
      final row = await nodeStore.getNodeRow(nodeId: widget.nodeId);
      final sessionPath = row['sessionPath'] as String;
      final sessionFile = File(sessionPath);
      String parentTranscript = '';
      if (await sessionFile.exists()) {
        final rawText = await sessionFile.readAsString();
        final doc = parseSessionMarkdown(rawText);
        parentTranscript = buildConversationTranscript(doc);
      }

      if (!context.mounted) return;

      // 2. 解析 providerId / modelId
      final chatCtrl = ref.read(chatControllerProvider(_args).notifier);
      final settings = ref.read(settingsControllerProvider).value;
      final branchProviders = ref.read(llmProvidersProvider).value;
      final resolved = resolveChatModel(
        sessionProviderId: chatCtrl.providerId,
        sessionModelId: chatCtrl.modelId,
        chatDefaultProviderId: settings?.chatDefaultProviderId,
        chatDefaultModelId: settings?.chatDefaultModelId,
        providers: branchProviders,
      );
      String? providerId = resolved.$1.isNotEmpty ? resolved.$1 : null;
      String? modelId = resolved.$2.isNotEmpty ? resolved.$2 : null;

      if (!context.mounted) return;

      // 3. 调顶层 showBranchFlow
      await showBranchFlow(
        context: context,
        mode: mode,
        selectedText: selectedText,
        parentTranscript: parentTranscript,
        providerId: providerId,
        modelId: modelId,
        themeId: widget.themeId,
        parentNodeId: widget.nodeId,
      );
    } catch (e) {
      if (!context.mounted) return;
      ThkAlert.show(
        context: context,
        message: l10n.branchFailed(e.toString()),
      );
    }
  }

  /// 收集 chat transcript 用于生成 title（取最后一对 user + assistant message）。
  String _collectTranscriptForTitle() {
    final messagesAsync = ref.read(chatControllerProvider(_args));
    return messagesAsync.maybeWhen(
      data: (messages) {
        final lastUser = messages
            .where((m) => m.role == SessionRole.user)
            .lastOrNull
            ?.body ??
            '';
        final lastAssistant = messages
            .where((m) => m.role == SessionRole.assistant)
            .lastOrNull
            ?.body ??
            '';
        return 'User: $lastUser\nAssistant: $lastAssistant';
      },
      orElse: () => '',
    );
  }

}

/// "更多"菜单的 Overlay 浮层 —— 用 [OverlayEntry] 直接画，不走 Navigator 路由栈，
/// 避免 [showModalBottomSheet] 抢焦点导致 [SelectionArea] 的选区被清掉。
///
/// 视觉与 [ThkGridBottomSheet] 保持一致（圆角顶部 + 网格布局 + 半透明背景）。
class _MoreActionsOverlayPanel extends StatelessWidget {
  const _MoreActionsOverlayPanel({
    required this.actions,
    required this.onPicked,
    required this.onDismiss,
  });

  final List<GridAction> actions;
  final void Function(GridAction action) onPicked;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomSafeGap = bottomInset > 0 ? 8.0 : 4.0;

    return Stack(
      children: [
        // 半透明背景：点击关闭（与 modal sheet 的 barrier 行为一致）
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: const ColoredBox(color: Color(0x80000000)),
          ),
        ),
        // 底部菜单本体
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: _MoreActionsOverlayGrid(
                    actions: actions,
                    onPicked: onPicked,
                  ),
                ),
                // 替代默认 SafeArea 的全量 bottomInset，避免与 home indicator 重叠
                SizedBox(height: bottomSafeGap),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "更多"菜单的网格布局 —— 复用 [ThkGridBottomSheet] 的 4 列 Wrap 算法。
class _MoreActionsOverlayGrid extends StatelessWidget {
  const _MoreActionsOverlayGrid({
    required this.actions,
    required this.onPicked,
  });

  final List<GridAction> actions;
  final void Function(GridAction action) onPicked;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 与 _ActionGrid 保持一致：4 列，spacing=12，每项宽度 clamp 到 [80, 84]
        final maxFourColumnWidth =
            (constraints.maxWidth - 12 * (4 - 1)) / 4;
        final itemWidth = maxFourColumnWidth.clamp(80.0, 84.0);
        return Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final action in actions)
                SizedBox(
                  width: itemWidth,
                  child: _MoreActionsOverlayItem(
                    action: action,
                    onPicked: onPicked,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// "更多"菜单的单个 item —— 圆形 tint 图标 + 文字标签，点击触发 [onPicked]。
class _MoreActionsOverlayItem extends StatelessWidget {
  const _MoreActionsOverlayItem({
    required this.action,
    required this.onPicked,
  });

  final GridAction action;
  final void Function(GridAction action) onPicked;

  @override
  Widget build(BuildContext context) {
    // 10% opacity tint for icon background（与 ThkGridBottomSheet 保持一致）
    final tintColor = action.color.withAlpha(25);

    return GestureDetector(
      onTap: () => onPicked(action),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tintColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              action.icon,
              size: 22,
              color: action.color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            action.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.15,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ContextUsageBar extends StatelessWidget {
  const _ContextUsageBar({required this.messages, required this.contextWindow});

  final List<SessionMessage> messages;
  final int contextWindow;

  @override
  Widget build(BuildContext context) {
    final used = _estimateTotalTokens(messages);
    final total = contextWindow;
    final ratio = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    final color = ratio > 0.85
        ? CupertinoColors.systemRed
        : ratio > 0.6
            ? AppColors.accent
            : AppColors.accent;

    return Container(
      height: 1,
      color: AppColors.border.withValues(alpha: 0.15),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: ratio,
          child: Container(color: color),
        ),
      ),
    );
  }

  int _estimateTotalTokens(List<SessionMessage> messages) {
    var total = 0;
    for (final m in messages) {
      total += estimateTokens(m.body);
    }
    return total;
  }
}

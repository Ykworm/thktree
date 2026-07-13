import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectionArea;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/data/services/doc_split_service.dart';
import 'package:thk_tree/data/models/llm_model_config.dart';
import 'package:thk_tree/data/models/model_capabilities.dart';
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
import 'package:thk_tree/ui/core/shared/selection_state.dart';
import 'package:thk_tree/ui/core/shared/clips_context_menu.dart';
import 'package:thk_tree/data/services/share_service.dart';
import 'package:thk_tree/ui/features/chat/widgets/chat_outline_sheet.dart';
import 'package:thk_tree/ui/features/chat/widgets/chat_search_sheet.dart';
import 'package:thk_tree/ui/features/chat/widgets/chat_markdown_sheet.dart';
import 'package:thk_tree/ui/features/chat/user_questions.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';
import 'package:thk_tree/data/stores/note_store.dart';
import 'package:thk_tree/ui/features/notes/note_editor_screen.dart';
import 'package:thk_tree/ui/features/themes/theme_detail_controller.dart';
import 'package:thk_tree/domain/node.dart';
import 'package:thk_tree/ui/features/notes/note_browse_screen.dart'
    show localizedThemeTitle;

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

  /// 从磁盘（主题详情 controller）派生的当前节点真实 title。
  /// 面包屑 go() 跳转不传 extra、router 回退到内部 ID 时，作为 navBar / 面包屑的
  /// 兜底标题来源，确保跳转后显示可读标题而非 thm_/nd_ ID。
  String? _currentTitle;

  /// 防抖：自动保存默认模型后置 true，避免重复调用 switchModel。
  bool _autoModelSaved = false;

  /// 模型选择弹层是否打开。打开期间禁用 chat scaffold 的
  /// resizeToAvoidBottomInset，避免键盘弹起时底下对话区被挤压、
  /// 透过弹层半透明遮罩露出留白。弹层面板自己用 viewInsets 上移避键盘。
  bool _modelSheetOpen = false;

  /// 滚动位置：是否接近底部（控制浮动按钮显隐）。
  bool _isNearBottom = true;

  /// 当前对话的深度思考开关（per-session in-memory，
  /// 切换模型时重置为 false，避免新模型不支持时还保留开启状态）。
  bool _deepThinkingEnabled = false;

  /// 缓存「分支回调」provider 的 notifier 引用。
  ///
  /// 在 initState 里读一次并存起来，避免 dispose 时再用 `ref`——
  /// widget 卸载后 `ref` 依赖的 BuildContext 已失效。
  BranchFromSelectionNotifier? _branchNotifier;

  /// 我们写入 [branchFromSelectionProvider] 的具体回调闭包。
  ///
  /// dispose 时用于精准判断「该 provider 仍是我们设的值」才清空，
  /// 避免误清掉后挂载的聊天页写入的新值（闭包引用可比较）。
  void Function(String)? _branchCallback;

  @override
  void initState() {
    super.initState();
    _args = ChatControllerParams(
      nodeId: widget.nodeId,
      title: widget.title,
      autoTriggerReply: widget.autoTriggerReply,
    );
    // 读 notifier 引用是安全的（不修改 provider，不违反构建期断言），
    // 缓存起来供 dispose 使用。
    _branchNotifier = ref.read(branchFromSelectionProvider.notifier);
    // 把"从活跃选区直接分支"的回调注册到全局 provider，
    // 供选区工具栏「分支」按钮读取（见 buildClipsContextMenu）。
    // 这样分支从活跃选区即时触发，不依赖 currentSelectionProvider 的残留值。
    //
    // 注意：必须延迟到首帧构建完成后再写 provider。
    // 在 initState（widget 树构建期）内直接改 provider 会触发 Riverpod 的
    // `_debugCanModifyProviders` 断言（Tried to modify a provider while the
    // widget tree was building）。用 addPostFrameCallback 移出构建期。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cb = (text) => unawaited(_branchFromSelection(context, text));
      _branchCallback = cb;
      _branchNotifier?.state = cb;
    });
  }

  @override
  void dispose() {
    // 卸载时清空分支回调，避免被已销毁的 chat 上下文误触发。
    // 注意：不能在 dispose 同步改 provider —— 此时 widget 树仍在 finalize，
    // Riverpod 的 _debugCanModifyProviders 断言会拦截（缓存引用也没用，
    // 因为断言看的是"是否在构建/finalize 期"，不是"是否用 ref"）。
    // 延迟到微任务，此时已脱离构建期；并用闭包引用做守卫，只清我们自己设的值。
    final notifier = _branchNotifier;
    final cb = _branchCallback;
    Future.microtask(() {
      try {
        if (notifier?.state == cb) notifier?.state = null;
      } catch (_) {
        // Provider 已随 ProviderScope 销毁，无需清理。
      }
    });
    super.dispose();
  }

  /// 从当前对话的 providerId/modelId 查找 contextWindow，找不到则 fallback
  int _resolveContextWindow(String? providerId, String? modelId) {
    if (providerId != null && modelId != null) {
      final providers = ref.read(llmProvidersProvider).value;
      if (providers != null) {
        final provider = providers.where((p) => p.id == providerId).firstOrNull;
        if (provider != null) {
          final model = provider.models
              .where((m) => m.id == modelId)
              .firstOrNull;
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

      final meta = await store.createNote(themeId: themeId, title: tempTitle);
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
      ThkAlert.show(context: context, message: 'Failed to save note: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // 面包屑：用主题详情 controller 拿全量节点，沿 parentId 回溯祖先链。
    // 加载中/出错时给空列表（ThkBreadcrumbRow 自动渲染为 SizedBox.shrink）。
    final themeDetailAsync = ref.watch(
      themeDetailControllerProvider(widget.themeId),
    );
    // 从磁盘真实数据派生当前节点标题：面包屑 go() 跳转不传 extra，
    // router 会回退到 '$themeId/$nodeId'（thm_/nd_ ID），必须优先用磁盘 title。
    // 作为 navBar 主标题与面包屑当前段的兜底来源，避免暴露内部 ID。
    _currentTitle = themeDetailAsync.whenOrNull(
      data: (data) =>
          data.nodes.where((n) => n.nodeId == widget.nodeId).firstOrNull?.title,
    );
    final crumbs = themeDetailAsync.when(
      data: (data) => _buildCrumbs(
        l10n,
        data.nodes,
        localizedThemeTitle(l10n, data.themeTitle),
      ),
      loading: () => const <BreadcrumbSegment>[],
      error: (_, __) => const <BreadcrumbSegment>[],
    );

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
      data: (messages) =>
          messages.any((m) => m.status == SessionMessageStatus.streaming),
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
          container
              .read(autoTitleControllerProvider(widget.nodeId).notifier)
              .runIfNeeded(
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
      lastUsedChatProviderId: settings?.lastUsedChatProviderId,
      lastUsedChatModelId: settings?.lastUsedChatModelId,
      chatDefaultProviderId: settings?.chatDefaultProviderId,
      chatDefaultModelId: settings?.chatDefaultModelId,
      providers: providers,
    );
    currentProviderId = resolved.$1.isNotEmpty ? resolved.$1 : null;
    currentModelId = resolved.$2.isNotEmpty ? resolved.$2 : null;

    // 自动保存到 session.md 以便模型选择器显示选中状态
    if (currentProviderId != null &&
        currentModelId != null &&
        !_autoModelSaved) {
      _autoModelSaved = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await ref
            .read(chatControllerProvider(_args).notifier)
            .switchModel(currentProviderId!, currentModelId!);
      });
    }

    // 联网搜索状态
    final currentProviderType = chatCtrl.providerType;
    final webSearchSupported =
        currentProviderType != null &&
        webSearchSupportMap[currentProviderType] ==
            WebSearchSupport.supported &&
        !isModelWebSearchUnsupported(currentModelId ?? '');
    final webSearchEnabled =
        webSearchSupported &&
        (settings?.isWebSearchEnabled(currentProviderType.name) ?? true);

    // 深度思考状态：当前模型命中白名单才显示可点击的 chip，
    // 否则显示灰色的 "不支持深度思考"。
    //
    // 注意：「始终开启」（豆包）优先级最高——它跟「用户可控 toggle」互斥，
    // UI 上只显示一个 chip，要么是只读的 "深度思考（默认）"，要么是可点击的 toggle，
    // 不会同时出现。
    final deepThinkingSupported = _isDeepThinkingSupported(
      currentProviderId,
      currentModelId,
    );
    final alwaysThinking = _isAlwaysThinking(currentProviderId, currentModelId);

    final modelSubtitle = _resolveModelSubtitle(
      currentProviderId,
      currentModelId,
    );

    // 模型选择：点击导航栏标题区域弹出底部选择面板（不再上推挤占对话空间）。
    final openModelSelector = () async {
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
      // 弹层打开期间禁用 chat scaffold resize，避免键盘弹起时
      // 底下对话区被挤压、透过半透明遮罩露出留白。
      setState(() => _modelSheetOpen = true);
      await showModelSelectorSheet(
        context: context,
        currentProviderId: nextProviderId,
        currentModelId: nextModelId,
        onModelSelected: (providerId, modelId) async {
          await ref
              .read(chatControllerProvider(_args).notifier)
              .switchModel(providerId, modelId);
          if (mounted) {
            setState(() {
              // 模型变了，深度思考状态重置（保守默认：新模型可能不支持）
              _deepThinkingEnabled = false;
            });
          }
        },
      );
      if (mounted) {
        setState(() => _modelSheetOpen = false);
      }
    };

    // _MainShell（iOS）会把 MediaQuery.viewInsets.bottom 减去 tabBar 高度，
    // 以让底部 tab 栏在键盘弹起时保持可见。但 ChatScreen 是全屏 push 页面，
    // 键盘弹起时 tabBar 被键盘遮住不存在，被减的部分会导致 Scaffold resize
    // 少留空间，在输入栏下方出现空白。这里通过 View 获取未被篡改的原始
    // 键盘高度（物理像素→逻辑像素），恢复正确的 viewInsets 给内部 Scaffold。
    final mq = MediaQuery.of(context);
    final view = View.of(context);
    final realBottomInset = view.viewInsets.bottom / view.devicePixelRatio;

    return MediaQuery(
      data: mq.copyWith(
        viewInsets: mq.viewInsets.copyWith(bottom: realBottomInset),
      ),
      child: CupertinoPageScaffold(
      // 模型选择弹层打开期间禁用 resize：键盘弹起时由弹层面板自己上移避让，
      // 避免 scaffold 把对话区顶起、透过弹层半透明遮罩露出留白。
      resizeToAvoidBottomInset: !_modelSheetOpen,
      backgroundColor: AppColors.pageBg,
      navigationBar: ThkNavBar.inline(
        title: '',
        middle: GestureDetector(
          onTap: openModelSelector,
          onDoubleTapDown: (_) => _chatListKey.currentState?.scrollToTop(),
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _displayedTitle ?? _currentTitle ?? widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (modelSubtitle != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      modelSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      AppIcons.chevronDown,
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
            ],
          ),
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
          onPressed: isStreaming
              ? null
              : () {
                  // 收起输入法再弹出菜单（overlay 走 rootOverlay 不抢焦点，需手动收）
                  FocusScope.of(context).unfocus();
                  _showMoreActions(context);
                },
          child: Icon(
            AppIcons.more,
            size: 24,
            color: isStreaming ? AppColors.textTertiary : AppColors.accent,
          ),
        ),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              if (crumbs.isNotEmpty)
                // 关键：Column 默认 crossAxisAlignment=center，会让这个非 Expanded
                // 的 Container 收缩到 Wrap 内容宽度并整体横向居中（视觉上像面包屑
                // 居中、浪费空间）。用 width:double.infinity + centerLeft 强制占满
                // 并左对齐，最大化可用显示空间。
                Container(
                  width: double.infinity,
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: 0.5),
                    ),
                  ),
                  child: ThkBreadcrumbRow(crumbs: crumbs),
                ),
              // 消息列表
              Expanded(
                child: Listener(
                  onPointerDown: (_) {
                    FocusScope.of(context).unfocus();
                  },
                  child: messagesAsync.when(
                    data: (messages) => SelectionArea(
                      // 注意：消息列表是「嵌套 SelectionArea」——每条 MessageBubble
                      // 内部各自包了一个 SelectionArea（GptMarkdown 自身不可选）。
                      // 嵌套下外层 SelectionArea 的 onSelectionChanged 收不到子选区，
                      // 所以这里几乎不会回调；选区实际由 MessageBubble 内的
                      // SelectionArea 捕获并写入 currentSelectionProvider。
                      // 保留写入仅作兜底（万一外层能拿到选区时同步）。
                      contextMenuBuilder: (context, editableTextState) =>
                          buildClipsContextMenu(context, editableTextState),
                      onSelectionChanged: (value) {
                        final text = value?.plainText;
                        if (text != null && text.trim().isNotEmpty) {
                          ref.read(currentSelectionProvider.notifier).state =
                              text;
                        }
                      },
                      child: ChatListView(
                        key: _chatListKey,
                        messages: messages,
                        onScrollPositionChanged: (nearBottom) {
                          if (_isNearBottom != nearBottom) {
                            setState(() => _isNearBottom = nearBottom);
                          }
                        },
                        messageBuilder: (context, message) {
                          final isLastAssistant =
                              message.role == SessionRole.assistant &&
                              message.status !=
                                  SessionMessageStatus.streaming &&
                              message ==
                                  messages.lastWhere(
                                    (m) => m.role == SessionRole.assistant,
                                    orElse: () => message,
                                  );

                          String? userQuestion;
                          Uint8List? userQuestionImage;
                          if (message.role == SessionRole.assistant) {
                            final idx = messages.indexOf(message);
                            if (idx > 0) {
                              for (var i = idx - 1; i >= 0; i--) {
                                if (messages[i].role == SessionRole.user) {
                                  userQuestion = messages[i].body;
                                  userQuestionImage = messages[i].imageData;
                                  break;
                                }
                              }
                            }
                          }

                          // 时间戳显示逻辑：第一条、角色切换、或间隔 > 2 分钟
                          final showTimestamp = _shouldShowTimestamp(
                            messages,
                            message,
                          );

                          return MessageBubble(
                            message: message,
                            showTimestamp: showTimestamp,
                            onRetry: isLastAssistant
                                ? () => ref
                                      .read(
                                        chatControllerProvider(_args).notifier,
                                      )
                                      .retryLastMessage()
                                : null,
                            userQuestion: userQuestion,
                            userQuestionImage: userQuestionImage,
                            onSaveToNote:
                                message.role == SessionRole.assistant &&
                                    message.status == SessionMessageStatus.done
                                ? () => _saveMessageAsNote(message)
                                : null,
                            onShareEntireChat: () => _shareEntireChat(messages),
                          );
                        },
                      ),
                    ),
                    error: (e, st) => Center(child: Text(e.toString())),
                    loading: () =>
                        const Center(child: CupertinoActivityIndicator()),
                  ),
                ),
              ),
              // Context 使用条
              messagesAsync.maybeWhen(
                data: (messages) {
                  final contextWindow = _resolveContextWindow(
                    currentProviderId,
                    currentModelId,
                  );
                  return _ContextUsageBar(
                    messages: messages,
                    contextWindow: contextWindow,
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              // 输入框
              ChatComposer(
                hintText: l10n.messageHint,
                isStreaming: isStreaming,
                onSend: (text, {imageData, imageMimeType}) async {
                  await ref
                      .read(chatControllerProvider(_args).notifier)
                      .sendUserMessage(
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
                  await ref
                      .read(chatControllerProvider(_args).notifier)
                      .stopStreaming();
                },
                webSearchEnabled: webSearchEnabled,
                webSearchSupported: webSearchSupported,
                onWebSearchToggle: webSearchSupported
                    ? () {
                        ref
                            .read(settingsControllerProvider.notifier)
                            .saveWebSearchEnabled(
                              currentProviderType.name,
                              !webSearchEnabled,
                            );
                      }
                    : null,
                deepThinkingEnabled: _deepThinkingEnabled,
                deepThinkingSupported: deepThinkingSupported,
                onDeepThinkingToggle: (deepThinkingSupported && !alwaysThinking)
                    ? () {
                        final next = !_deepThinkingEnabled;
                        setState(() => _deepThinkingEnabled = next);
                        // 同步到底层 controller（用于 build 下一帧决定是否传 thinking 参数）
                        ref
                            .read(chatControllerProvider(_args).notifier)
                            .setDeepThinking(next);
                      }
                    : null,
                alwaysThinking: alwaysThinking,
                onImagePick: () => _showImagePicker(context),
                imageSupported: _isImageSupported(
                  currentProviderId,
                  currentModelId,
                ),
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
            ],
          ),
          // 浮动滚动按钮：离开底部时显示，点击回到底部
          if (!_isNearBottom)
            Positioned(
              right: 16,
              bottom: 110,
              child: GestureDetector(
                onTap: () => _chatListKey.currentState?.scrollToBottom(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.elevationShadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    AppIcons.chevronDown,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }

  /// 根据当前节点沿 parentId 回溯祖先链，构造面包屑。
  ///
  /// 顺序：主题(tab) → 主题树 → 各级祖先节点 → 当前节点（最后一段不可点）。
  /// 聊天页位于 go_router 的 StatefulShellBranch（themes 分支）内，go_router
  /// 自己管理该分支的 navigator 栈，因此每段用 [BreadcrumbSegment.goPath]
  /// 走声明式 `GoRouter.go(path)` 回跳，不能用 popUntil（会把 go_router 的
  /// route match list 摘空而崩溃）。
  /// 防御：跳过 title 明显是 ULID/原始 ID 的祖先段；当前节点的回退标题
  /// 若像 ID 则替换为通用文案，避免在 UI 上暴露 thm_/nd_/msg_ 等内部标识。
  ///
  /// 注意：当节点数据可用时（current != null），当前节点标签优先用磁盘上的
  /// [NodeEntity.title]（真实 title），而非 [widget.title]——后者来自 router extra
  /// 参数，面包屑 GoRouter.go() 回跳时不传 extra，router 会回退到
  /// '$themeId/$nodeId' 默认值，若用它做标签会误触发 ID 过滤或暴露内部 ID。
  static const _ulidPrefixes = ['thm_', 'nd_', 'nt_', 'msg_'];

  bool _looksLikeRawId(String s) => _ulidPrefixes.any((p) => s.startsWith(p));

  List<BreadcrumbSegment> _buildCrumbs(
    AppLocalizations l10n,
    List<NodeEntity> nodes,
    String themeTitle,
  ) {
    final themeId = widget.themeId;
    final segments = <BreadcrumbSegment>[
      BreadcrumbSegment(label: l10n.themesTabLabel, goPath: '/'),
      BreadcrumbSegment(label: themeTitle, goPath: '/themes/$themeId/tree'),
    ];

    final current = nodes.where((n) => n.nodeId == widget.nodeId).firstOrNull;
    if (current == null) {
      // 节点数据暂未就绪：优先用磁盘派生的 _currentTitle，避免回退到 router 的
      // '$themeId/$nodeId' 内部 ID。仍为 ID 形态时降级为通用文案。
      final fallbackTitle = _currentTitle ?? widget.title;
      segments.add(
        BreadcrumbSegment(
          label: _looksLikeRawId(fallbackTitle) ? l10n.noTitle : fallbackTitle,
        ),
      );
      return segments;
    }

    // 回溯祖先链：current → … → root
    final chain = <NodeEntity>[];
    final byId = {for (final n in nodes) n.nodeId: n};
    var cursor = current!; // current 已在上方面 null 检查后 return
    while (true) {
      chain.add(cursor);
      final parentId = cursor.parentId;
      if (parentId == null) break;
      final parent = byId[parentId];
      if (parent == null) break;
      cursor = parent;
    }
    chain.removeAt(0); // 去掉 current 本身
    // 此时 chain 为 [parent … root]，反转后为 [root … parent]
    for (final n in chain.reversed) {
      // 跳过 title 是原始 ULID 的节点（创建时未命名、title 回退到了 ID）。
      if (_looksLikeRawId(n.title)) continue;
      segments.add(
        BreadcrumbSegment(
          label: n.title,
          goPath: '/themes/$themeId/nodes/${n.nodeId}',
        ),
      );
    }
    // 当前节点（最后一段，不可点）。
    // 直接用磁盘真实 title（current.title），不依赖 widget.title——
    // widget.title 来自 router extra，面包屑 go() 回跳时不传 extra，
    // router 会回退到 '$themeId/$nodeId' 默认值（内部 ID），若用它做标签会暴露。
    final currentLabel = _looksLikeRawId(current!.title)
        ? l10n.noTitle
        : current.title;
    segments.add(BreadcrumbSegment(label: currentLabel));
    return segments;
  }

  /// 检查当前模型是否支持图片
  bool _isImageSupported(String? providerId, String? modelId) {
    if (providerId == null || modelId == null) return false;
    final providers = ref.read(llmProvidersProvider).value;
    if (providers == null) return false;
    final provider = providers.where((p) => p.id == providerId).firstOrNull;
    if (provider == null) return false;
    final model = provider.models.where((m) => m.id == modelId).firstOrNull;
    // 优先用持久化的权威 capabilities；命中且为 true 直接返回，
    // 否则回退到关键词实时推断（与 [_isDeepThinkingSupported] 逻辑保持一致），
    // 避免改了能力映射表后必须重新拉取模型列表才生效。
    if (model?.supportsVision ?? false) return true;
    return inferCapabilities(modelId).contains(ModelCapability.vision);
  }

  /// 当前模型是否支持深度思考（基于 model id 关键词匹配白名单）
  bool _isDeepThinkingSupported(String? providerId, String? modelId) {
    if (modelId == null) return false;
    return inferCapabilities(modelId).contains(ModelCapability.deepThinking);
  }

  /// 当前模型是否默认开启深度思考且用户无法关闭（豆包 Seed 系列）。
  /// 与 [ModelCapability.deepThinking]（用户可控 toggle）互斥——豆包不会有 toggle chip。
  bool _isAlwaysThinking(String? providerId, String? modelId) {
    if (modelId == null) return false;
    return inferCapabilities(modelId).contains(ModelCapability.alwaysThinking);
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
      lastUsedChatProviderId: settings?.lastUsedChatProviderId,
      lastUsedChatModelId: settings?.lastUsedChatModelId,
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
      final source = action == 'camera'
          ? ImageSource.camera
          : ImageSource.gallery;
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
  static bool _shouldShowTimestamp(
    List<SessionMessage> messages,
    SessionMessage message,
  ) {
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
    unawaited(
      _showOverlayMoreActions(
        context: context,
        actions: [
          if (widget.isDocSplit)
            GridAction(
              label: l10n.submitTreeStructure,
              icon: AppIcons.checkCircle,
              color: AppColors.success,
              onPressed: () => unawaited(_onSubmitDocSplit()),
            ),
          GridAction(
            key: const ValueKey('branch_button'),
            label: l10n.swipeBranch,
            icon: AppIcons.branch,
            color: AppColors.accent,
            onPressed: () => unawaited(_onCreateBranchFromMenu(context)),
          ),
          GridAction(
            label: l10n.chatMarkdown,
            icon: AppIcons.document,
            color: AppColors.waveTeal,
            onPressed: () {
              showChatMarkdownSheet(context, widget.nodeId);
            },
          ),
          GridAction(
            label: l10n.viewTree,
            icon: AppIcons.accountTree,
            color: AppColors.accent,
            onPressed: () => context.go(
              '/themes/${widget.themeId}/full-tree?currentNodeId=${widget.nodeId}',
            ),
          ),
          GridAction(
            label: l10n.myQuestions,
            icon: AppIcons.chat,
            color: AppColors.waveOrange,
            onPressed: () {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => UserQuestionsListPage(args: _args),
                ),
              );
            },
          ),
        ],
      ),
    );
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

    entry = OverlayEntry(
      builder: (ctx) {
        return _MoreActionsOverlayPanel(
          actions: actions,
          onPicked: (action) => dismiss(action.onPressed),
          onDismiss: () => dismiss(),
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(entry);
    return completer.future;
  }

  Future<void> _onOpenOutline(
    BuildContext context,
    List<SessionMessage> messages,
  ) async {
    // 注意：ThkGridBottomSheet 已经 pop 了自身，不要再 pop
    final selected = await showChatOutlineSheet(context, messages);
    if (selected != null && mounted) {
      _chatListKey.currentState?.scrollToMessage(selected.msgId);
    }
  }

  Future<void> _onOpenSearch(
    BuildContext context,
    List<SessionMessage> messages,
  ) async {
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
        ThkAlert.show(
          context: context,
          message: l10n.docSplitNoAssistantMessage,
        );
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

      ref
          .read(themeDetailControllerProvider(widget.themeId).notifier)
          .refresh();
      ThkAlert.show(
        context: context,
        message: l10n.docSplitSuccess(createdCount),
      );
      context.go('/themes/${widget.themeId}/tree');
    } catch (e) {
      if (!mounted) return;
      ThkAlert.show(context: context, message: e.toString());
    }
  }

  /// 从「活跃选区」直接分支：选区工具栏「分支」按钮触发。
  /// 此时选区一定还在，直接把选中文本作为 source 传入，不经过全局残留选区。
  Future<void> _branchFromSelection(
    BuildContext context,
    String selectedText,
  ) async {
    final mode = await showBranchModeSheet(context, selectedText: selectedText);
    if (mode == null) return;
    if (!context.mounted) return;

    await _showBranchFlow(context, mode: mode, selectedText: selectedText);
  }

  /// 从顶部「更多 → 分支」按钮进入：先弹 sheet 让用户选 mode，再 [_showBranchFlow]。
  /// 注意：此时活跃选区已随浮层打开而收起，不应再用全局残留选区
  /// （见 [currentSelectionProvider] 的"保留上次有效选区"约定），故 selectedText 传 null。
  Future<void> _onCreateBranchFromMenu(BuildContext context) async {
    final mode = await showBranchModeSheet(context);
    if (mode == null) return;
    if (!context.mounted) return;

    await _showBranchFlow(context, mode: mode, selectedText: null);
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
    debugPrint(
      '[ChatScreen._showBranchFlow] mode=$mode, '
      'selectedText=${selectedText?.length ?? 'null'} chars, '
      'preview=${selectedText?.substring(0, (selectedText.length).clamp(0, 80)) ?? 'null'}',
    );
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
        lastUsedChatProviderId: settings?.lastUsedChatProviderId,
        lastUsedChatModelId: settings?.lastUsedChatModelId,
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
      ThkAlert.show(context: context, message: l10n.branchFailed(e.toString()));
    }
  }

  /// 收集 chat transcript 用于生成 title（取最后一对 user + assistant message）。
  String _collectTranscriptForTitle() {
    final messagesAsync = ref.read(chatControllerProvider(_args));
    return messagesAsync.maybeWhen(
      data: (messages) {
        final lastUser =
            messages
                .where((m) => m.role == SessionRole.user)
                .lastOrNull
                ?.body ??
            '';
        final lastAssistant =
            messages
                .where((m) => m.role == SessionRole.assistant)
                .lastOrNull
                ?.body ??
            '';
        return 'User: $lastUser\nAssistant: $lastAssistant';
      },
      orElse: () => '',
    );
  }

  Future<void> _shareEntireChat(List<SessionMessage> messages) async {
    if (messages.isEmpty) return;

    // 补全本地图片字节（磁盘有 imagePath 但内存无 imageData 的情况）
    final loaded = await _loadShareImages(messages);

    // 构造分享消息列表（保留每条消息的图片）
    final shareMessages = loaded.map((m) {
      return ShareMessage(role: m.role, text: m.body, image: m.imageData);
    }).toList();

    if (shareMessages.isEmpty) return;

    print('分享整个聊天: 消息数量=${messages.length}');

    // 获取屏幕中心作为分享锚点
    final size = MediaQuery.of(context).size;
    final origin = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 1,
      height: 1,
    );

    try {
      await ShareService.shareAsImage(
        context: context,
        messages: shareMessages,
        sharePositionOrigin: origin,
      );
    } catch (e, stackTrace) {
      print('分享整个聊天失败: $e');
      print('堆栈: $stackTrace');
      if (!mounted) return;
      ThkAlert.show(context: context, message: '内容过多，无法保存为图片');
    }
  }

  /// 对仅有 [SessionMessage.imagePath]（本地路径）但无 [SessionMessage.imageData]
  /// 的消息，从磁盘读取图片字节补回，供分享卡片渲染。
  Future<List<SessionMessage>> _loadShareImages(
    List<SessionMessage> messages,
  ) async {
    final needLoad = messages
        .where((m) => m.imagePath != null && m.imageData == null)
        .toList();
    if (needLoad.isEmpty) return messages;

    try {
      final nodeStore = await ref.read(nodeStoreProvider.future);
      final themeId = await nodeStore.getThemeIdByNodeId(widget.nodeId);
      if (themeId == null) return messages;
      final paths = await ref.read(appPathsProvider.future);
      final imagesDir =
          '${paths.themesDir.path}/$themeId/${widget.nodeId}/images';

      return messages.map((m) {
        if (m.imagePath == null || m.imageData != null) return m;
        final fileName = m.imagePath!.split('/').last;
        var file = File('$imagesDir/$fileName');
        // fallback：pending_ 文件已被 rename 为 msgId.jpg（旧 bug）
        if (!file.existsSync() && fileName.startsWith('pending_')) {
          file = File('$imagesDir/${m.msgId}.jpg');
        }
        if (!file.existsSync()) return m;
        return SessionMessage(
          role: m.role,
          timestampUtcIso8601: m.timestampUtcIso8601,
          msgId: m.msgId,
          body: m.body,
          status: m.status,
          reasoning: m.reasoning,
          imageData: file.readAsBytesSync(),
          imageMimeType: m.imageMimeType,
          imagePath: m.imagePath,
          modelId: m.modelId,
        );
      }).toList();
    } catch (_) {
      return messages;
    }
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
            child: const ColoredBox(color: AppColors.scrim),
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
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
        final maxFourColumnWidth = (constraints.maxWidth - 12 * (4 - 1)) / 4;
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
  const _MoreActionsOverlayItem({required this.action, required this.onPicked});

  final GridAction action;
  final void Function(GridAction action) onPicked;

  @override
  Widget build(BuildContext context) {
    // 10% opacity tint for icon background（与 ThkGridBottomSheet 保持一致）
    final tintColor = action.color.withAlpha(25);

    return GestureDetector(
      key: action.key,
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
            decoration: BoxDecoration(color: tintColor, shape: BoxShape.circle),
            child: Icon(action.icon, size: 22, color: action.color),
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
        ? AppColors.destructive
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

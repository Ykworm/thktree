import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectionArea;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/chat/chat_controller.dart';
import 'package:thk_tree/ui/features/chat/widgets/model_selector_panel.dart';
import 'package:thk_tree/ui/features/notes/note_select_screen.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/data/services/llm_provider.dart' show estimateTokens, LlmProvider;
import 'package:thk_tree/ui/core/shared/chat_composer.dart';
import 'package:thk_tree/ui/core/shared/chat_list_view.dart';
import 'package:thk_tree/ui/core/shared/message_bubble.dart';
import 'package:thk_tree/ui/core/shared/title_suggestion_screen.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.themeId,
    required this.nodeId,
    required this.title,
    this.autoTriggerReply = false,
  });

  final String themeId;
  final String nodeId;
  final String title;

  /// 若为 true，chat 加载完后若最后一条是 user 消息（status == done），
  /// 会自动调一次 LLM 回复（用于"笔记→对话自动续聊"和"summary 创建分支"场景）。
  final bool autoTriggerReply;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late final ChatControllerParams _args;
  bool _showModelPanel = false;
  String? _currentSelectedText;

  @override
  void initState() {
    super.initState();
    _args = ChatControllerParams(
      nodeId: widget.nodeId,
      title: widget.title,
      autoTriggerReply: widget.autoTriggerReply,
    );
  }

  /// 将旧版 LlmProvider 枚举映射到新系统的 preset provider id。
  String _mapLegacyProviderToPresetId(LlmProvider provider) {
    switch (provider) {
      case LlmProvider.claude:
        return 'preset_anthropic';
      case LlmProvider.deepseek:
        return 'preset_deepseek';
      case LlmProvider.openai:
        return 'preset_openai';
      case LlmProvider.gemini:
        return 'preset_gemini';
      case LlmProvider.minimax:
        return 'preset_minimax';
      case LlmProvider.kimi:
        return 'preset_kimi';
    }
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
    // fallback 到旧的全局 provider 设置
    final settings = ref.read(settingsControllerProvider).value;
    return settings?.llmProvider.contextWindowTokens ?? 64000;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final messagesAsync = ref.watch(chatControllerProvider(_args));
    final isStreaming = messagesAsync.maybeWhen(
      data: (messages) => messages.any((m) => m.status == SessionMessageStatus.streaming),
      orElse: () => false,
    );

    // 读取当前对话的 providerId/modelId
    final chatCtrl = ref.read(chatControllerProvider(_args).notifier);
    var currentProviderId = chatCtrl.providerId;
    var currentModelId = chatCtrl.modelId;

    // 如果对话未指定模型，fallback 到全局设置
    final settings = ref.watch(settingsControllerProvider).value;
    if (settings != null) {
      currentProviderId ??= _mapLegacyProviderToPresetId(settings.llmProvider);
      currentModelId ??= settings.model;
    }

    final modelSubtitle = _resolveModelSubtitle(currentProviderId, currentModelId);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: ThkNavBar.inline(
        title: '',
        middle: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (modelSubtitle != null)
              Text(
                modelSubtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
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
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: isStreaming ? null : () => _onCreateBranchFromMenu(context),
          child: Icon(
            AppIcons.branch,
            size: 24,
            color: isStreaming
                ? CupertinoColors.systemGrey.resolveFrom(context)
                : CupertinoColors.systemBlue.resolveFrom(context),
          ),
        ),
      ),
      child: Column(
        children: [
          // 消息列表 - 面板出现时它会被压缩变小
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: messagesAsync.when(
                data: (messages) => SelectionArea(
                  onSelectionChanged: (value) {
                    final text = value?.plainText;
                    if (text != null && text.trim().isNotEmpty) {
                      _currentSelectedText = text;
                    }
                  },
                  child: ChatListView(
                    messages: messages,
                    messageBuilder: (context, message) => MessageBubble(
                      message: message,
                    ),
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
              final contextWindow = _resolveContextWindow(currentProviderId, currentModelId);
              return _ContextUsageBar(messages: messages, contextWindow: contextWindow);
            },
            orElse: () => const SizedBox.shrink(),
          ),
          // 输入框
          ChatComposer(
            hintText: l10n.messageHint,
            isStreaming: isStreaming,
            onSend: (text) {
              return ref.read(chatControllerProvider(_args).notifier).sendUserMessage(text);
            },
            onStopStreaming: () async {
              ref.read(chatControllerProvider(_args).notifier).stopStreaming();
            },
            onModelSelectorTap: () {
              if (isStreaming) return;
              FocusScope.of(context).unfocus();
              setState(() => _showModelPanel = !_showModelPanel);
            },
          ),
          // 模型面板（出现在输入框下方，取代软键盘位置）
          if (_showModelPanel && !isStreaming)
            Flexible(
              child: ModelSelectorPanel(
                currentProviderId: currentProviderId,
                currentModelId: currentModelId,
                onModelSelected: (providerId, modelId) async {
                  await ref.read(chatControllerProvider(_args).notifier).switchModel(providerId, modelId);
                  if (mounted) setState(() => _showModelPanel = false);
                },
                onClose: () {
                  if (mounted) setState(() => _showModelPanel = false);
                },
              ),
            ),
        ],
      ),
    );
  }

  void _onAddToNote(BuildContext context, String text) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => NoteSelectScreen(
          currentThemeId: widget.themeId,
          selectedText: text,
          onNoteSelected: (ctx, noteId) {
            if (noteId != null) {
              ThkAlert.show(
                context: ctx,
                message: AppLocalizations.of(ctx)!.addToNote,
              );
            }
          },
        ),
      ),
    );
  }

  /// 从顶部 branch 按钮进入：先弹 sheet 让用户选 mode，再 [_showBranchFlow]。
  Future<void> _onCreateBranchFromMenu(BuildContext context) async {
    // 在弹 sheet 之前读取选中文本，避免选区被清除
    final selected = _currentSelectedText;
    debugPrint('[ChatScreen] _onCreateBranchFromMenu: selectedText=${selected?.length ?? 'null'} chars');

    final mode = await showBranchModeSheet(context);
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
      String? providerId = chatCtrl.providerId;
      String? modelId = chatCtrl.modelId;
      final settings = ref.read(settingsControllerProvider).value;
      if (settings != null) {
        providerId ??= _mapLegacyProviderToPresetId(settings.llmProvider);
        modelId ??= settings.model;
      }

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
            ? CupertinoColors.systemOrange
            : CupertinoColors.systemTeal;

    return Container(
      height: 1,
      color: CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.15),
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

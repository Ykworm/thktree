import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/features/summary/summary_route_params.dart';
import 'package:thk_tree/ui/features/chat/chat_controller.dart';
import 'package:thk_tree/ui/features/chat/widgets/model_selector_panel.dart';
import 'package:thk_tree/ui/features/notes/note_select_screen.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/data/services/llm_provider.dart' show estimateTokens, LlmProvider;
import 'package:thk_tree/ui/core/shared/chat_composer.dart';
import 'package:thk_tree/ui/core/shared/chat_list_view.dart';
import 'package:thk_tree/ui/core/shared/message_bubble.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.themeId, required this.nodeId, required this.title});

  final String themeId;
  final String nodeId;
  final String title;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late final ChatControllerParams _args;
  bool _showModelPanel = false;

  @override
  void initState() {
    super.initState();
    _args = ChatControllerParams(widget.nodeId, widget.title);
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.go('/themes/${widget.themeId}/tree');
            }
          },
          tooltip: l10n.back,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title),
            if (modelSubtitle != null)
              Text(
                modelSubtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.go('/themes/${widget.themeId}/tree'),
            icon: const Icon(Icons.account_tree),
            tooltip: l10n.tree,
          ),
          IconButton(
            onPressed: () async {
              try {
                final title = await _promptTitle(context);
                if (title == null) return;
                
                final nodeStore = await ref.read(nodeStoreProvider.future);
                final row = await nodeStore.getNodeRow(nodeId: widget.nodeId);
                final sessionPath = row['sessionPath'] as String;
                final sessionFile = File(sessionPath);
                String? parentSessionText;
                if (await sessionFile.exists()) {
                  final rawText = await sessionFile.readAsString();
                  final doc = parseSessionMarkdown(rawText);
                  parentSessionText = buildConversationTranscript(doc);
                } else {
                  parentSessionText = '';
                }
                
                if (!context.mounted) return;
                
                final params = SummaryRouteParams(
                  themeId: widget.themeId,
                  parentNodeId: widget.nodeId,
                  branchTitle: title,
                  parentSessionText: parentSessionText,
                );
                
                context.push(
                  '/themes/${widget.themeId}/nodes/${widget.nodeId}/summary',
                  extra: params,
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(l10n.branchFailed(e.toString()))));
              }
            },
            icon: const Icon(Icons.call_split),
            tooltip: l10n.branch,
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表 - 面板出现时它会被压缩变小
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: messagesAsync.when(
                data: (messages) => ChatListView(
                  messages: messages,
                  messageBuilder: (context, message) => MessageBubble(
                    message: message,
                    onAddToNote: (selectedText) => _onAddToNote(context, selectedText),
                  ),
                ),
                error: (e, st) => Center(child: Text(e.toString())),
                loading: () => const Center(child: CircularProgressIndicator()),
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
            onStopStreaming: () {
              return ref.read(chatControllerProvider(_args).notifier).stopStreaming();
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
      MaterialPageRoute(
        builder: (_) => NoteSelectScreen(
          currentThemeId: widget.themeId,
          selectedText: text,
          onNoteSelected: (ctx, noteId) {
            if (noteId != null) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(ctx)!.addToNote),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          },
        ),
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
    final l10n = AppLocalizations.of(context)!;
    final used = _estimateTotalTokens(messages);
    final total = contextWindow;
    final ratio = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    final percent = (ratio * 100).round();
    final color = ratio > 0.85
        ? Colors.red
        : ratio > 0.6
            ? Colors.orange
            : Colors.teal;

    return Tooltip(
      message: l10n.contextUsagePercent(percent),
      child: Container(
        height: 2.5,
        color: Theme.of(context).dividerColor.withAlpha(60),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: ratio,
            child: Container(color: color),
          ),
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

Future<String?> _promptTitle(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(l10n.newBranch),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.titleHint),
          onSubmitted: (value) {
            final composing = controller.value.composing;
            if (composing.isValid && !composing.isCollapsed) return;
            Navigator.of(context).pop(value.trim().isEmpty ? null : value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              Navigator.of(context).pop(value.isEmpty ? null : value);
            },
            child: Text(l10n.create),
          ),
        ],
      );
    },
  );
}

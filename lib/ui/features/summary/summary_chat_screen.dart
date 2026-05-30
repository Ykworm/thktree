import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/features/themes/theme_detail_controller.dart';
import 'package:thk_tree/ui/features/summary/summary_chat_controller.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/ui/core/shared/chat_composer.dart';
import 'package:thk_tree/ui/core/shared/chat_list_view.dart';
import 'package:thk_tree/ui/core/shared/message_bubble.dart';
import 'package:thk_tree/data/services/llm_provider.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';

class SummaryChatScreen extends ConsumerStatefulWidget {
  const SummaryChatScreen({
    super.key,
    required this.themeId,
    required this.parentNodeId,
    required this.branchTitle,
    required this.parentSessionText,
  });

  final String themeId;
  final String parentNodeId;
  final String branchTitle;
  final String parentSessionText;

  @override
  ConsumerState<SummaryChatScreen> createState() => _SummaryChatScreenState();
}

class _SummaryChatScreenState extends ConsumerState<SummaryChatScreen> {
  late final SummaryChatParams _args;
  bool _isCreatingBranch = false;

  @override
  void initState() {
    super.initState();
    _args = SummaryChatParams(
      tempNodeId: 'temp_summary_${DateTime.now().millisecondsSinceEpoch}',
      parentNodeId: widget.parentNodeId,
      themeId: widget.themeId,
      branchTitle: widget.branchTitle,
      parentSessionText: widget.parentSessionText,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final messagesAsync = ref.watch(summaryChatControllerProvider(_args));
    final isStreaming = messagesAsync.maybeWhen(
      data: (messages) => messages.any((m) => m.status == SessionMessageStatus.streaming),
      orElse: () => false,
    );
    final summaryController = ref.read(summaryChatControllerProvider(_args).notifier);
    final settingsAsync = ref.watch(settingsControllerProvider);
    final summaryText = summaryController.getSummaryText();
    final canConfirm = summaryText != null && summaryText.isNotEmpty && !isStreaming && !_isCreatingBranch;

    return PopScope(
      canPop: !_isCreatingBranch,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.polishSummary),
          leading: _isCreatingBranch
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      context.pop();
                    } else {
                      context.go('/themes/${widget.themeId}/tree');
                    }
                  },
                ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Text(
                l10n.summaryBanner(widget.branchTitle),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            Expanded(
              child: messagesAsync.when(
                data: (messages) => ChatListView(
                  messages: messages,
                  messageBuilder: (context, message) => MessageBubble(message: message),
                ),
                error: (e, st) => Center(child: Text(e.toString())),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
            messagesAsync.maybeWhen(
              data: (messages) {
                final provider = settingsAsync.maybeWhen(
                  data: (s) => s.llmProvider,
                  orElse: () => LlmProvider.deepseek,
                );
                return _SummaryContextBar(messages: messages, provider: provider);
              },
              orElse: () => const SizedBox.shrink(),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ChatComposer(
                      hintText: l10n.summaryHint,
                      isStreaming: isStreaming,
                      enabled: !_isCreatingBranch,
                      onSend: (text) {
                        return ref.read(summaryChatControllerProvider(_args).notifier).sendUserMessage(text);
                      },
                      onStopStreaming: () {
                        return ref.read(summaryChatControllerProvider(_args).notifier).stopStreaming();
                      },
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isCreatingBranch
                                ? null
                                : () => context.pop(),
                            child: Text(l10n.cancel),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isCreatingBranch
                                ? null
                                : () => _createBranch(null),
                            child: Text(l10n.blankBranch),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isCreatingBranch
                                ? null
                                : () => _createBranch(widget.parentSessionText),
                            child: Text(l10n.skipSummary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: canConfirm ? _confirmAndCreateBranch : null,
                            child: _isCreatingBranch
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(l10n.confirmSummary),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndCreateBranch() async {
    final summaryController = ref.read(summaryChatControllerProvider(_args).notifier);
    final summaryText = summaryController.getSummaryText();
    if (summaryText == null || summaryText.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseGenerateSummary)),
      );
      return;
    }
    await _createBranch(summaryText);
  }

  Future<void> _createBranch(String? initialContent) async {
    setState(() => _isCreatingBranch = true);

    try {
      await ref.read(summaryChatControllerProvider(_args).notifier).stopStreaming();

      final childNode = await ref
          .read(themeDetailControllerProvider(widget.themeId).notifier)
          .createChildChatNode(
            parentId: widget.parentNodeId,
            title: widget.branchTitle,
          );

      if (initialContent != null && initialContent.isNotEmpty) {
        final sessionStore = await ref.read(sessionStoreProvider.future);
        await sessionStore.appendUserMessage(
          nodeId: childNode.nodeId,
          content: initialContent,
        );
      }

      if (!mounted) return;

      context.go('/themes/${widget.themeId}/nodes/${childNode.nodeId}', extra: childNode.title);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreatingBranch = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.branchCreationFailed(e.toString()))),
      );
    }
  }
}

class _SummaryContextBar extends StatelessWidget {
  const _SummaryContextBar({required this.messages, required this.provider});

  final List<SessionMessage> messages;
  final LlmProvider provider;

  @override
  Widget build(BuildContext context) {
    final used = _estimateTotalTokens(messages);
    final total = provider.contextWindowTokens;
    final ratio = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    final color = ratio > 0.85
        ? Colors.red
        : ratio > 0.6
            ? Colors.orange
            : Colors.teal;
    final usedStr = provider.formatTokens(used);
    final totalStr = provider.formatTokens(total);

    return Tooltip(
      message: 'Context: $usedStr / $totalStr tokens',
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

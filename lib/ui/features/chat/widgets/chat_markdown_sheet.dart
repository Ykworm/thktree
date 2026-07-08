import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText, SelectionArea;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_durations.dart';
import 'package:thk_tree/ui/core/theme/app_spacing.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';

/// 查看当前对话的原始 Markdown（session.md 文件内容），支持复制。
void showChatMarkdownSheet(BuildContext context, String nodeId) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => _ChatMarkdownPage(nodeId: nodeId),
  );
}

class _ChatMarkdownPage extends ConsumerStatefulWidget {
  const _ChatMarkdownPage({required this.nodeId});

  final String nodeId;

  @override
  ConsumerState<_ChatMarkdownPage> createState() =>
      _ChatMarkdownPageState();
}

class _ChatMarkdownPageState extends ConsumerState<_ChatMarkdownPage> {
  String? _content;
  bool _copied = false;

  final _scrollController = ScrollController();
  bool _isNearTop = true;
  bool _isNearBottom = true;

  static const _scrollTolerance = 48.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final nearTop = position.extentBefore <= _scrollTolerance;
    final nearBottom = position.extentAfter <= _scrollTolerance;
    if (nearTop != _isNearTop) setState(() => _isNearTop = nearTop);
    if (nearBottom != _isNearBottom) {
      setState(() => _isNearBottom = nearBottom);
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: AppDur.listScroll,
      curve: AppDur.listScrollCurve,
    );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: AppDur.listScroll,
      curve: AppDur.listScrollCurve,
    );
  }

  Future<void> _load() async {
    final store = await ref.read(sessionStoreProvider.future);
    final text = await store.readSessionRaw(widget.nodeId);
    if (!mounted) return;
    setState(() => _content = text);
  }

  Future<void> _onCopy() async {
    final content = _content;
    if (content == null || content.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _copied = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: CupertinoTheme.of(context).scaffoldBackgroundColor,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppSp.sheetTopRadius)),
      ),
      child: Column(
        children: [
          // 拖拽指示条
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.close),
                ),
                Expanded(
                  child: Text(
                    l10n.chatMarkdown,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: _content == null ? null : _onCopy,
                  child: Text(
                    _copied ? l10n.copied : l10n.copy,
                    style: TextStyle(
                      color: _copied
                          ? AppColors.success
                          : AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildBody(l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    final content = _content;
    if (content == null) {
      return const Center(
        child: CupertinoActivityIndicator(),
      );
    }
    if (content.isEmpty) {
      return Center(
        child: Text(
          l10n.chatMarkdownEmpty,
          style: TextStyle(color: AppColors.textTertiary),
        ),
      );
    }
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: AppColors.surface,
          child: SelectionArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 48),
              child: SelectableText(
                content,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
        // 浮动到顶部按钮
        if (!_isNearTop)
          Positioned(
            right: 12,
            bottom: _isNearBottom ? 32 : 76,
            child: _ScrollFloatingButton(
              icon: AppIcons.chevronUp,
              onTap: _scrollToTop,
            ),
          ),
        // 浮动到底部按钮
        if (!_isNearBottom)
          Positioned(
            right: 12,
            bottom: 32,
            child: _ScrollFloatingButton(
              icon: AppIcons.chevronDown,
              onTap: _scrollToBottom,
            ),
          ),
      ],
    );
  }
}

/// Markdown 预览浮层中的浮动圆形滚动按钮。
class _ScrollFloatingButton extends StatelessWidget {
  const _ScrollFloatingButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.elevationShadow,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 16,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

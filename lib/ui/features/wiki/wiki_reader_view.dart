import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:thk_tree/data/models/wiki_node.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/data/services/wiki_export_service.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/shared/link_launcher.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/theme/app_spacing.dart';
import 'package:thk_tree/ui/core/theme/app_surfaces.dart';
import 'package:thk_tree/ui/core/theme/app_theme.dart';
import 'package:thk_tree/ui/features/wiki/wiki_reader_controller.dart';
import 'package:thk_tree/ui/features/wiki/wiki_toc_view.dart';

/// Wiki 阅读视图（嵌入 ThemeDetailScreen 的 Wiki tab，不带独立 NavBar）。
class WikiReaderView extends ConsumerStatefulWidget {
  const WikiReaderView({
    super.key,
    required this.themeId,
    required this.themeTitle,
  });

  final String themeId;
  final String themeTitle;

  @override
  ConsumerState<WikiReaderView> createState() => _WikiReaderViewState();
}

class _WikiReaderViewState extends ConsumerState<WikiReaderView> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};
  double _readingProgress = 0.0;
  String? _currentNodeId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    setState(() {
      _readingProgress = max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;
    });
    _updateCurrentSection();
  }

  void _updateCurrentSection() {
    // 简化实现：根据滚动位置估算当前 section。
    // 更精确的做法需要测量每个 section 的高度，首版先用近似。
    if (_sectionKeys.isEmpty) return;
    final viewportTop = _scrollController.offset;
    String? current;
    for (final entry in _sectionKeys.entries) {
      final context = entry.value.currentContext;
      if (context == null) continue;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final position = box.localToGlobal(Offset.zero);
      // 大致判断：如果 section 顶部在视口上半部分，认为它是当前 section
      if (position.dy < viewportTop + 200) {
        current = entry.key;
      } else {
        break;
      }
    }
    if (current != _currentNodeId) {
      setState(() => _currentNodeId = current);
    }
  }

  GlobalKey _keyFor(String nodeId) {
    return _sectionKeys.putIfAbsent(nodeId, GlobalKey.new);
  }

  Future<void> _generateWiki() async {
    await ref.read(wikiReaderControllerProvider(widget.themeId).notifier).generateWiki();
  }

  Future<void> _deleteWiki() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(l10n.wikiDeleteTitle),
        content: Text(l10n.wikiDeleteConfirm),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(wikiReaderControllerProvider(widget.themeId).notifier).deleteWiki();
  }

  Future<void> _exportWiki() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final paths = await ref.read(appPathsProvider.future);
      final wikiDir = Directory(p.join(paths.themesDir.path, widget.themeId, 'wiki'));
      final zipFile = await const WikiExportService().exportWiki(
        wikiDir: wikiDir,
        themeTitle: widget.themeTitle,
      );
      await Share.shareXFiles(
        [XFile(zipFile.path)],
        sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
      );
    } catch (e) {
      if (!mounted) return;
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          content: Text(l10n.wikiExportFailed(e.toString())),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
    }
  }

  void _showToc(List<WikiNode> nodes) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => WikiTocView(
        nodes: nodes,
        currentNodeId: _currentNodeId,
        onNodeTap: (nodeId) {
          Navigator.of(context).pop();
          _scrollToNode(nodeId);
        },
      ),
    );
  }

  void _scrollToNode(String nodeId) {
    final key = _sectionKeys[nodeId];
    if (key == null) return;
    final context = key.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final wikiAsync = ref.watch(wikiReaderControllerProvider(widget.themeId));

    return wikiAsync.when(
      data: (state) {
        if (!state.hasWiki || state.document == null) {
          return _EmptyWikiView(
            themeTitle: widget.themeTitle,
            onGenerate: _generateWiki,
          );
        }

        final doc = state.document!;
        final flatNodes = doc.flatten();
        if (flatNodes.isEmpty) {
          return _EmptyWikiView(
            themeTitle: widget.themeTitle,
            onGenerate: _generateWiki,
          );
        }

        return Stack(
          children: [
            // 进度条
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                color: AppColors.textTertiary.withValues(alpha: 0.1),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _readingProgress,
                  child: Container(color: AppColors.accent),
                ),
              ),
            ),
            // 内容
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppSp.screenPadding,
                    20,
                    AppSp.screenPadding,
                    32 + MediaQuery.of(context).padding.bottom,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == 0) {
                          return _buildCover(doc, state.meta?.generatedAt);
                        }
                        final node = flatNodes[index - 1];
                        return _WikiSection(
                          key: _keyFor(node.nodeId),
                          node: node,
                        );
                      },
                      childCount: flatNodes.length + 1,
                    ),
                  ),
                ),
              ],
            ),
            // TOC 按钮
            Positioned(
              right: 16,
              bottom: 24 + MediaQuery.of(context).padding.bottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _exportWiki,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        AppIcons.share,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _deleteWiki,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        AppIcons.delete,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _showToc(flatNodes),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        AppIcons.listBullet,
                        color: AppColors.surface,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (e, _) => Center(
        child: Text(
          '${l10n.wikiLoadFailed}: $e',
          style: TextStyle(color: AppColors.destructive),
        ),
      ),
    );
  }

  Widget _buildCover(WikiDocument doc, String? generatedAt) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            doc.themeTitle,
            style: AppTheme.largeTitle.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (generatedAt != null)
            Text(
              l10n.wikiGeneratedAt(generatedAt),
              style: AppTheme.caption1.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          const SizedBox(height: 8),
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyWikiView extends StatelessWidget {
  const _EmptyWikiView({
    required this.themeTitle,
    required this.onGenerate,
  });

  final String themeTitle;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.book,
                size: 64,
                color: AppColors.textTertiary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.wikiEmptyTitle,
                style: AppTheme.title1.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.wikiEmptySubtitle(themeTitle),
                style: AppTheme.body.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: onGenerate,
                  child: Text(l10n.wikiGenerateButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WikiSection extends StatelessWidget {
  const _WikiSection({
    super.key,
    required this.node,
  });

  final WikiNode node;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 28, bottom: 12),
          child: Text(
            node.title,
            style: _headingStyle(),
          ),
        ),
        for (final message in node.messages)
          _WikiMessageView(message: message),
      ],
    );
  }

  TextStyle _headingStyle() {
    final baseStyle = AppTheme.title1;
    switch (node.headingLevel) {
      case 1:
        return baseStyle.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        );
      case 2:
        return baseStyle.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        );
      case 3:
        return baseStyle.copyWith(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        );
      default:
        return baseStyle.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        );
    }
  }
}

class _WikiMessageView extends StatelessWidget {
  const _WikiMessageView({required this.message});

  final WikiMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == SessionRole.user;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: isUser
          ? AppSurfaces.contentCard(radius: 12)
          : BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: AppColors.accent,
                  width: 3,
                ),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.reasoning != null && message.reasoning!.isNotEmpty)
            _ReasoningView(reasoning: message.reasoning!),
          GptMarkdown(
            message.body,
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: AppColors.textPrimary,
            ),
            onLinkTap: (url, _) => openMarkdownLink(context, url),
          ),
        ],
      ),
    );
  }
}

class _ReasoningView extends StatelessWidget {
  const _ReasoningView({required this.reasoning});

  final String reasoning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.textTertiary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '思考过程',
              style: AppTheme.caption1.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              reasoning,
              style: AppTheme.body.copyWith(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

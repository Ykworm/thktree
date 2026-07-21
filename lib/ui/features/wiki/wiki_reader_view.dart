import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:thk_tree/data/models/wiki_node.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/data/services/wiki_export_service.dart';
import 'package:thk_tree/data/services/wiki_store.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/shared/link_launcher.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/theme/app_spacing.dart';
import 'package:thk_tree/ui/core/theme/app_surfaces.dart';
import 'package:thk_tree/ui/core/theme/app_theme.dart';
import 'package:thk_tree/ui/features/wiki/wiki_reader_controller.dart';

/// Wiki 目录页（嵌入 ThemeDetailScreen 的 Wiki tab）。
///
/// 首次进入显示 catalog：书籍封面 + 层级目录 + 操作按钮。
/// 点击目录项进入章节阅读页。
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
  String? _chapterNodeId;

  void _openChapter(String nodeId) {
    setState(() => _chapterNodeId = nodeId);
  }

  void _backToCatalog() {
    setState(() => _chapterNodeId = null);
  }

  Future<void> _generateWiki(String rootNodeId) async {
    await ref
        .read(wikiReaderControllerProvider(widget.themeId).notifier)
        .generateWiki(rootNodeId);
  }

  Future<void> _deleteWiki(String rootNodeId) async {
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
    await ref
        .read(wikiReaderControllerProvider(widget.themeId).notifier)
        .deleteWiki(rootNodeId);
    if (mounted) {
      setState(() => _chapterNodeId = null);
    }
  }

  Future<void> _exportWiki(String rootNodeId) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final paths = await ref.read(appPathsProvider.future);
      final wikiDir = Directory(
        p.join(paths.themesDir.path, widget.themeId, 'wiki', rootNodeId),
      );
      final zipFile = await const WikiExportService().exportWiki(
        wikiDir: wikiDir,
        themeTitle: widget.themeTitle,
      );
      await Share.shareXFiles([
        XFile(zipFile.path),
      ], sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1));
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final wikiAsync = ref.watch(wikiReaderControllerProvider(widget.themeId));

    return wikiAsync.when(
      data: (state) {
        if (state.trees.isEmpty) {
          return _EmptyWikiView(
            themeTitle: widget.themeTitle,
            onGenerate: null,
          );
        }

        final selected = state.selectedTree;
        if (selected == null) {
          return const Center(child: CupertinoActivityIndicator());
        }

        // 章节阅读页
        if (_chapterNodeId != null &&
            selected.hasWiki &&
            selected.document != null) {
          final doc = selected.document!;
          final flatNodes = doc.flatten();
          final currentIndex = flatNodes.indexWhere(
            (n) => n.nodeId == _chapterNodeId,
          );
          if (currentIndex >= 0) {
            return _WikiChapterView(
              node: flatNodes[currentIndex],
              hasPrevious: currentIndex > 0,
              hasNext: currentIndex < flatNodes.length - 1,
              onPrevious: currentIndex > 0
                  ? () => _openChapter(flatNodes[currentIndex - 1].nodeId)
                  : null,
              onNext: currentIndex < flatNodes.length - 1
                  ? () => _openChapter(flatNodes[currentIndex + 1].nodeId)
                  : null,
              onBack: _backToCatalog,
            );
          }
        }

        // 目录页
        return Column(
          children: [
            if (state.trees.length > 1)
              _TreeSelector(
                trees: state.trees,
                selectedRootNodeId: state.selectedRootNodeId!,
                onSelect: (rootNodeId) {
                  ref
                      .read(
                        wikiReaderControllerProvider(widget.themeId).notifier,
                      )
                      .selectTree(rootNodeId);
                  setState(() => _chapterNodeId = null);
                },
              ),
            Expanded(
              child: selected.hasWiki && selected.document != null
                  ? _WikiCatalogView(
                      document: selected.document!,
                      meta: selected.meta,
                      onOpenChapter: _openChapter,
                      onExport: () => _exportWiki(selected.rootNode.nodeId),
                      onDelete: () => _deleteWiki(selected.rootNode.nodeId),
                    )
                  : _EmptyWikiView(
                      themeTitle: selected.rootNode.title,
                      onGenerate: () => _generateWiki(selected.rootNode.nodeId),
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
}

class _TreeSelector extends StatelessWidget {
  const _TreeSelector({
    required this.trees,
    required this.selectedRootNodeId,
    required this.onSelect,
  });

  final List<TreeWikiInfo> trees;
  final String selectedRootNodeId;
  final ValueChanged<String> onSelect;

  void _showTreePicker(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  l10n.wikiSelectTree,
                  style: AppTheme.headline.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.fromLTRB(
                    AppSp.screenPadding,
                    0,
                    AppSp.screenPadding,
                    16,
                  ),
                  itemCount: trees.length,
                  itemBuilder: (context, index) {
                    final tree = trees[index];
                    final selected = tree.rootNode.nodeId == selectedRootNodeId;
                    return CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Navigator.of(context).pop();
                        onSelect(tree.rootNode.nodeId);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tree.rootNode.title,
                                    style: AppTheme.body.copyWith(
                                      color: selected
                                          ? AppColors.accent
                                          : AppColors.textPrimary,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (tree.hasWiki)
                                    Text(
                                      l10n.wikiGeneratedAt(
                                        tree.meta?.generatedAt ?? '',
                                      ),
                                      style: AppTheme.caption1.copyWith(
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (selected)
                              Icon(
                                AppIcons.check,
                                size: 18,
                                color: AppColors.accent,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedTree = trees.firstWhere(
      (t) => t.rootNode.nodeId == selectedRootNodeId,
      orElse: () => trees.first,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSp.screenPadding,
        8,
        AppSp.screenPadding,
        8,
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _showTreePicker(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.textTertiary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(AppIcons.branch, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedTree.rootNode.title,
                  style: AppTheme.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                AppIcons.chevronDown,
                size: 14,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wiki 目录页（书籍封面 + 层级目录）。
class _WikiCatalogView extends StatelessWidget {
  const _WikiCatalogView({
    required this.document,
    required this.meta,
    required this.onOpenChapter,
    required this.onExport,
    required this.onDelete,
  });

  final WikiDocument document;
  final WikiMeta? meta;
  final ValueChanged<String> onOpenChapter;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  Widget _buildCover(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          document.themeTitle,
          style: AppTheme.largeTitle.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (meta != null)
          Text(
            l10n.wikiGeneratedAt(meta!.generatedAt),
            style: AppTheme.caption1.copyWith(color: AppColors.textTertiary),
          ),
      ],
    );
  }

  Widget _buildActions(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onExport,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.share,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.wikiExportAction,
                    style: AppTheme.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onDelete,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.destructive.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.delete, size: 16, color: AppColors.destructive),
                  const SizedBox(width: 6),
                  Text(
                    l10n.delete,
                    style: AppTheme.body.copyWith(color: AppColors.destructive),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final flatNodes = document.flatten();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppSp.screenPadding,
            24,
            AppSp.screenPadding,
            32 + MediaQuery.of(context).padding.bottom,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index == 0) {
                return _buildCover(l10n);
              }
              if (index == 1) {
                return _buildActions(l10n);
              }
              if (index == 2) {
                return Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 12),
                  child: Text(
                    l10n.wikiTocTitle,
                    style: AppTheme.title1.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }
              final node = flatNodes[index - 3];
              return _CatalogItem(
                node: node,
                onTap: () => onOpenChapter(node.nodeId),
              );
            }, childCount: flatNodes.length + 3),
          ),
        ),
      ],
    );
  }
}

class _CatalogItem extends StatelessWidget {
  const _CatalogItem({required this.node, required this.onTap});

  final WikiNode node;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.textTertiary.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: (node.depth - 1) * 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.title,
                    style: AppTheme.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: node.depth <= 2
                          ? FontWeight.w600
                          : FontWeight.w400,
                      fontSize: node.depth == 1 ? 17 : 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.wikiMessageCount(node.messages.length),
                    style: AppTheme.caption1.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              AppIcons.chevronRight,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// 章节阅读页。
class _WikiChapterView extends StatelessWidget {
  const _WikiChapterView({
    required this.node,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
    required this.onBack,
  });

  final WikiNode node;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        // 顶部导航
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onBack,
                  child: Icon(
                    AppIcons.back,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    node.title,
                    style: AppTheme.headline.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        // 内容
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSp.screenPadding,
                  16,
                  AppSp.screenPadding,
                  24,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      node.title,
                      style: AppTheme.title1.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final message in node.messages)
                      _WikiMessageView(message: message),
                  ]),
                ),
              ),
            ],
          ),
        ),
        // 底部上一章/下一章
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSp.screenPadding,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(
                  color: AppColors.textTertiary.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: hasPrevious ? onPrevious : null,
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.chevronLeft,
                        size: 16,
                        color: hasPrevious
                            ? AppColors.accent
                            : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.wikiPreviousChapter,
                        style: AppTheme.body.copyWith(
                          color: hasPrevious
                              ? AppColors.accent
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: hasNext ? onNext : null,
                  child: Row(
                    children: [
                      Text(
                        l10n.wikiNextChapter,
                        style: AppTheme.body.copyWith(
                          color: hasNext
                              ? AppColors.accent
                              : AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        AppIcons.chevronRight,
                        size: 16,
                        color: hasNext
                            ? AppColors.accent
                            : AppColors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyWikiView extends StatelessWidget {
  const _EmptyWikiView({required this.themeTitle, required this.onGenerate});

  final String themeTitle;
  final VoidCallback? onGenerate;

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
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.matteGoldLight, // 非常淡的暖金色
                      AppColors.matteGoldBg, // 极淡的暖灰
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.matteGoldBorder,
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.matteGold.withValues(alpha: 0.1),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SizedBox.square(
                  dimension: 72,
                  child: Center(
                    child: Transform.translate(
                      // Cupertino book glyph has a slightly high visual center.
                      offset: const Offset(0, 2),
                      child: Icon(
                        AppIcons.book,
                        size: 64,
                        color: AppColors.matteGold, // 高级暖沙金
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.wikiEmptyTitle,
                style: AppTheme.title1.copyWith(
                  color: AppColors.textMatteGoldDark, // 带有暖灰调的深色
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.wikiEmptySubtitle(themeTitle),
                style: AppTheme.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              if (onGenerate != null) ...[
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.matteGold.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    color: AppColors.matteGold, // 暖沙金按钮
                    borderRadius: BorderRadius.circular(12),
                    onPressed: onGenerate,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.wand_stars,
                          size: 18,
                          color: AppColors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.wikiGenerateButton,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
                left: BorderSide(color: AppColors.accent, width: 3),
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
    final l10n = AppLocalizations.of(context)!;
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
              l10n.thinkingProcess,
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

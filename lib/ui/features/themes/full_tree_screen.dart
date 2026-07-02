import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/theme/app_theme.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/themes/theme_detail_controller.dart';
import 'package:thk_tree/domain/node.dart';

/// Full-screen tree view that shows all nodes fully expanded.
/// Tap any node to navigate to its chat page.
class FullTreeScreen extends ConsumerStatefulWidget {
  const FullTreeScreen({
    super.key,
    required this.themeId,
    required this.currentNodeId,
  });

  final String themeId;
  final String currentNodeId;

  @override
  ConsumerState<FullTreeScreen> createState() => _FullTreeScreenState();
}

class _FullTreeScreenState extends ConsumerState<FullTreeScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _highlightKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentNode());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentNode() {
    final key = _highlightKey.currentContext;
    if (key != null) {
      Scrollable.ensureVisible(
        key,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final detailAsync =
        ref.watch(themeDetailControllerProvider(widget.themeId));

    return detailAsync.when(
      data: (data) {
        // Find the root of the tree that the current node belongs to.
        final nodeById = <String, NodeEntity>{
          for (final n in data.nodes) n.nodeId: n,
        };
        NodeEntity? current = nodeById[widget.currentNodeId];
        NodeEntity? root = current;
        while (root != null && root.parentId != null) {
          root = nodeById[root.parentId];
        }
        if (root == null) {
          return CupertinoPageScaffold(
            backgroundColor: AppColors.surface,
            navigationBar: ThkNavBar.inline(title: data.themeTitle),
            child: Center(child: Text(l10n.emptyTree)),
          );
        }
        final treeRoot = root;
        return CupertinoPageScaffold(
          backgroundColor: AppColors.surface,
          navigationBar: ThkNavBar.inline(
            title: treeRoot.title,
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () => Navigator.of(context).pop(),
              child: const Icon(AppIcons.back),
            ),
          ),
          child: SafeArea(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: 1,
              itemBuilder: (context, _) => _FullTreeNodeRow(
                key: treeRoot.nodeId == widget.currentNodeId
                    ? _highlightKey
                    : null,
                themeId: widget.themeId,
                node: treeRoot,
                allNodes: data.nodes,
                depth: 0,
                currentNodeId: widget.currentNodeId,
              ),
            ),
          ),
        );
      },
      error: (e, st) => CupertinoPageScaffold(
        navigationBar: ThkNavBar.inline(title: ''),
        child: Center(child: Text(e.toString())),
      ),
      loading: () => CupertinoPageScaffold(
        navigationBar: ThkNavBar.inline(title: ''),
        child: const Center(child: CupertinoActivityIndicator()),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _FullTreeNodeRow — simplified tree row for full-tree view
// ---------------------------------------------------------------------------

class _FullTreeNodeRow extends StatelessWidget {
  const _FullTreeNodeRow({
    super.key,
    required this.themeId,
    required this.node,
    required this.allNodes,
    required this.depth,
    required this.currentNodeId,
  });

  final String themeId;
  final NodeEntity node;
  final List<NodeEntity> allNodes;
  final int depth;
  final String currentNodeId;

  static const _kIndent = 28.0;

  List<NodeEntity> _children() {
    final list = allNodes
        .where((n) => n.parentId == node.nodeId)
        .toList(growable: false);
    list.sort(_compareNodes);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final children = _children();
    final hasChildren = children.isNotEmpty;
    final isCurrent = node.nodeId == currentNodeId;
    final palette = AppColors.paletteForNode(node.nodeId);

    final l10n = AppLocalizations.of(context)!;
    final sourceLabel = _sourceTypeLabel(l10n, node.sourceType);

    final tile = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(
        '/themes/$themeId/nodes/${node.nodeId}',
        extra: node.title,
      ),
      child: Container(
        color: isCurrent
            ? AppColors.accent.withValues(alpha: 0.08)
            : null,
        child: Row(
          children: [
            if (isCurrent)
              Container(width: 3, height: 44, color: AppColors.accent)
            else
              const SizedBox(width: 3),
            Padding(
              padding: EdgeInsets.only(left: depth * _kIndent),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: hasChildren
                          ? palette.circle
                          : palette.circle.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: palette.circle, width: 2),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    node.title,
                    style: AppTheme.body.copyWith(
                      color: isCurrent
                          ? AppColors.accent
                          : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (sourceLabel != null)
                    Text(
                      sourceLabel,
                      style: AppTheme.caption1.copyWith(color: palette.subtitle),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );

    if (!hasChildren) return tile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        tile,
        for (final child in children)
          _FullTreeNodeRow(
            themeId: themeId,
            node: child,
            allNodes: allNodes,
            depth: depth + 1,
            currentNodeId: currentNodeId,
          ),
      ],
    );
  }
}

int _compareNodes(NodeEntity a, NodeEntity b) {
  return a.sortOrder.compareTo(b.sortOrder);
}

String? _sourceTypeLabel(AppLocalizations l10n, String? sourceType) {
  return switch (sourceType) {
    'selectedText' => l10n.sourceTypeSelectedText,
    'conversation' => l10n.sourceTypeConversation,
    'summary' => l10n.sourceTypeSummary,
    'note' => l10n.sourceTypeNote,
    'userIdea' => l10n.sourceTypeUserIdea,
    'docSplit' => l10n.sourceTypeDocSplit,
    _ => null,
  };
}

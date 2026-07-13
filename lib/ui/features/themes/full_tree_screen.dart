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
///
/// - Browse mode (default): tap any node to navigate to its chat page.
/// - Multi-select mode: tap chat nodes to select up to [_maxSelection] for merging.
class FullTreeScreen extends ConsumerStatefulWidget {
  const FullTreeScreen({
    super.key,
    required this.themeId,
    this.currentNodeId,
    this.initialMultiSelect = false,
  });

  final String themeId;
  final String? currentNodeId;
  final bool initialMultiSelect;

  @override
  ConsumerState<FullTreeScreen> createState() => _FullTreeScreenState();
}

class _FullTreeScreenState extends ConsumerState<FullTreeScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _highlightKey = GlobalKey();

  static const _maxSelection = 3;

  bool _multiSelectMode = false;
  bool _hintExpanded = true;
  final List<String> _selectedNodeIds = [];

  @override
  void initState() {
    super.initState();
    _multiSelectMode = widget.initialMultiSelect;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentNode());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentNode() {
    if (widget.currentNodeId == null) return;
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

  void _toggleMultiSelectMode() {
    setState(() {
      _multiSelectMode = !_multiSelectMode;
      if (!_multiSelectMode) _selectedNodeIds.clear();
    });
  }

  void _toggleSelect(String nodeId, List<NodeEntity> allNodes) {
    final node = allNodes.where((n) => n.nodeId == nodeId).firstOrNull;
    if (node == null || node.kind != NodeKind.chat) return;

    setState(() {
      if (_selectedNodeIds.contains(nodeId)) {
        _selectedNodeIds.remove(nodeId);
      } else {
        if (_selectedNodeIds.length >= _maxSelection) {
          _showMaxSelectionToast();
          return;
        }
        _selectedNodeIds.add(nodeId);
      }
    });
  }

  void _showMaxSelectionToast() {
    final l10n = AppLocalizations.of(context)!;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 120,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              l10n.maxSelectionReached(_maxSelection),
              style: AppTheme.body.copyWith(color: AppColors.surface),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () => entry.remove());
  }

  void _onMergeAndCreate(List<NodeEntity> allNodes) {
    final selectedNodes = _selectedNodeIds
        .map((id) => allNodes.where((n) => n.nodeId == id).firstOrNull)
        .whereType<NodeEntity>()
        .toList();

    context.push(
      '/themes/${widget.themeId}/merge-confirm'
      '?crossTree=${widget.currentNodeId == null}',
      extra: selectedNodes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final detailAsync =
        ref.watch(themeDetailControllerProvider(widget.themeId));

    return detailAsync.when(
      data: (data) {
        // Determine which root(s) to display based on entry point.
        //
        // - From chat page (currentNodeId != null): show only the tree
        //   containing the current node.
        // - From tree page (currentNodeId == null): show ALL root nodes,
        //   matching what the tree page itself displays.
        final nodeById = <String, NodeEntity>{
          for (final n in data.nodes) n.nodeId: n,
        };
        final List<NodeEntity> treeRoots;
        if (widget.currentNodeId != null) {
          NodeEntity? current = nodeById[widget.currentNodeId];
          NodeEntity? root = current;
          while (root != null && root.parentId != null) {
            root = nodeById[root.parentId];
          }
          treeRoots = root != null ? [root] : [];
        } else {
          treeRoots = data.nodes
              .where((n) => n.parentId == null)
              .toList()
            ..sort(_compareNodes);
        }

        if (treeRoots.isEmpty) {
          return CupertinoPageScaffold(
            backgroundColor: AppColors.surface,
            navigationBar: ThkNavBar.inline(title: data.themeTitle),
            child: Center(child: Text(l10n.emptyTree)),
          );
        }

        // Nav bar title: single root → its title; multiple roots → theme title.
        final navTitle =
            treeRoots.length == 1 ? treeRoots.first.title : data.themeTitle;

        // Navigation bar trailing: toggle multi-select / browse mode.
        final trailing = CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: _toggleMultiSelectMode,
          child: Text(
            _multiSelectMode ? l10n.done : l10n.multiSelect,
            style: AppTheme.body.copyWith(color: AppColors.accent),
          ),
        );

        return CupertinoPageScaffold(
          backgroundColor: AppColors.surface,
          navigationBar: ThkNavBar.inline(
            title: navTitle,
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () {
                if (widget.currentNodeId != null) {
                  // 从 chat 页进入：go() 不会走回退，必须显式 go 回聊天页
                  context.go(
                    '/themes/${widget.themeId}/nodes/${widget.currentNodeId}',
                  );
                } else {
                  context.pop();
                }
              },
              child: const Icon(AppIcons.back),
            ),
            trailing: trailing,
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Expandable teaching hint bar (multi-select mode only).
                if (_multiSelectMode)
                  _MultiSelectHintBar(
                    maxSelection: _maxSelection,
                    selectedCount: _selectedNodeIds.length,
                    isExpanded: _hintExpanded,
                    onToggleExpand: () =>
                        setState(() => _hintExpanded = !_hintExpanded),
                  ),
                // Tree list.
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: treeRoots.length,
                    itemBuilder: (context, index) {
                      final root = treeRoots[index];
                      return _FullTreeNodeRow(
                        key: root.nodeId == widget.currentNodeId
                            ? _highlightKey
                            : null,
                        themeId: widget.themeId,
                        node: root,
                        allNodes: data.nodes,
                        depth: 0,
                        currentNodeId: widget.currentNodeId,
                        isMultiSelectMode: _multiSelectMode,
                        selectedNodeIds: _selectedNodeIds,
                        onToggleSelect: (nodeId) =>
                            _toggleSelect(nodeId, data.nodes),
                      );
                    },
                  ),
                ),
                // Bottom action bar (multi-select mode only).
                if (_multiSelectMode)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border(
                        top: BorderSide(
                          color: AppColors.border,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.selectedCount(
                              _selectedNodeIds.length,
                              _maxSelection,
                            ),
                            style: AppTheme.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          onPressed: _selectedNodeIds.isEmpty
                              ? null
                              : () => _onMergeAndCreate(data.nodes),
                          child: Text(
                            l10n.mergeAndCreate,
                            style: AppTheme.body.copyWith(
                              color: _selectedNodeIds.isEmpty
                                  ? AppColors.textSecondary
                                  : AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
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
    this.isMultiSelectMode = false,
    this.selectedNodeIds = const [],
    this.onToggleSelect,
  });

  final String themeId;
  final NodeEntity node;
  final List<NodeEntity> allNodes;
  final int depth;
  final String? currentNodeId;

  final bool isMultiSelectMode;
  final List<String> selectedNodeIds;
  final ValueChanged<String>? onToggleSelect;

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

    // In multi-select mode, only chat nodes are selectable.
    final isSelectable =
        !isMultiSelectMode || node.kind == NodeKind.chat;
    final isSelected = selectedNodeIds.contains(node.nodeId);

    final tile = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isMultiSelectMode
          ? (isSelectable ? () => onToggleSelect?.call(node.nodeId) : null)
          : () => context.push(
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
                  child: isMultiSelectMode
                      ? _buildSelectionIndicator(isSelected, isSelectable)
                      : Container(
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
            isMultiSelectMode: isMultiSelectMode,
            selectedNodeIds: selectedNodeIds,
            onToggleSelect: onToggleSelect,
          ),
      ],
    );
  }

  Widget _buildSelectionIndicator(bool isSelected, bool isSelectable) {
    if (!isSelectable) {
      // Non-chat nodes: show a dim circle (not selectable).
      return Icon(
        CupertinoIcons.circle,
        size: 22,
        color: AppColors.textSecondary.withValues(alpha: 0.3),
      );
    }
    return Icon(
      isSelected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
      size: 22,
      color: isSelected ? AppColors.accent : AppColors.textSecondary,
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

// ---------------------------------------------------------------------------
// _MultiSelectHintBar — expandable teaching hint for multi-select merge
// ---------------------------------------------------------------------------

class _MultiSelectHintBar extends StatelessWidget {
  const _MultiSelectHintBar({
    required this.maxSelection,
    required this.selectedCount,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  final int maxSelection;
  final int selectedCount;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final accentSoft = AppColors.accent.withValues(alpha: 0.06);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggleExpand,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: accentSoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: hint text + count + chevron.
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${l10n.mergeChatHint(maxSelection)} · ${l10n.selectedCount(selectedCount, maxSelection)}',
                    style: AppTheme.caption1.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                ),
                Icon(
                  isExpanded
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  size: 14,
                  color: AppColors.accent,
                ),
              ],
            ),
            // Expanded body: teaching steps.
            if (isExpanded) ...[
              const SizedBox(height: 8),
              ..._buildGuideSteps(l10n),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGuideSteps(AppLocalizations l10n) {
    final steps = <String>[
      l10n.mergeSelectGuideOnlyChat,
      l10n.mergeSelectGuideMaxChats(maxSelection),
      l10n.mergeSelectGuideTapMerge,
    ];

    return steps.map((text) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 6),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: AppTheme.caption1.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

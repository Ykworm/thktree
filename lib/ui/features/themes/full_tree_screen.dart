import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/theme/app_spacing.dart';
import 'package:thk_tree/ui/core/theme/app_surfaces.dart';
import 'package:thk_tree/ui/core/theme/app_theme.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/themes/theme_detail_controller.dart';
import 'package:thk_tree/domain/node.dart';

/// Full-screen tree view that shows all nodes fully expanded.
///
/// - Browse mode (default): tap any node to navigate to its chat page.
/// - Multi-select: via trailing「多选 / 合并」，或 [initialMultiSelect]
///   （树页 overflow「合并 & 创建」）。无右上「完成」——浏览态多选用返回退出多选；
///   专态入口用返回离开本页。
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

  /// 进入时定位到当前节点：节点数据异步加载，须等 data 分支渲染出目标行
  /// 后再滚动；首帧 loading 时滚动会被静默跳过，故不在 initState 里触发。
  bool _needsInitialScroll = true;

  @override
  void initState() {
    super.initState();
    _multiSelectMode = widget.initialMultiSelect;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentNode() {
    if (widget.currentNodeId == null) return;
    final key = _highlightKey.currentContext;
    if (key == null) return; // 目标行尚未渲染，保留标记待下次 build 重试
    _needsInitialScroll = false;
    Scrollable.ensureVisible(
      key,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.3,
    );
  }

  void _enterMultiSelect() {
    setState(() {
      _multiSelectMode = true;
      _hintExpanded = true;
    });
  }

  void _exitMultiSelect() {
    setState(() {
      _multiSelectMode = false;
      _selectedNodeIds.clear();
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

  void _onBack() {
    // 浏览态进入的多选：返回先退出多选，不离开整树页
    if (_multiSelectMode && !widget.initialMultiSelect) {
      _exitMultiSelect();
      return;
    }
    if (widget.currentNodeId != null) {
      // 从 chat 页进入：go() 不会走回退，必须显式 go 回聊天页
      context.go(
        '/themes/${widget.themeId}/nodes/${widget.currentNodeId}',
      );
    } else {
      context.pop();
    }
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
            backgroundColor: AppColors.pageBg,
            navigationBar: ThkNavBar.inline(
              title: data.themeTitle,
              leading: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: _onBack,
                child: const Icon(AppIcons.back),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.branch,
                      size: 40, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text(
                    l10n.emptyTree,
                    style: AppTheme.body
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        // 数据就绪且目标行已渲染后，定位到当前节点（仅首次，见 _needsInitialScroll）
        if (widget.currentNodeId != null && _needsInitialScroll) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _scrollToCurrentNode();
          });
        }

        // Nav bar title: multi-select → theme/merge context; else single root
        // title or theme title.
        final navTitle = _multiSelectMode
            ? (treeRoots.length == 1
                ? treeRoots.first.title
                : data.themeTitle)
            : (treeRoots.length == 1
                ? treeRoots.first.title
                : data.themeTitle);

        // 浏览态：trailing 提供「多选」进入合并；多选态不显示「完成」
        // （返回退出多选 / 离开页面）。initialMultiSelect 专态无 trailing。
        final Widget? trailing = widget.initialMultiSelect
            ? null
            : (_multiSelectMode
                ? null
                : CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: _enterMultiSelect,
                    child: Text(
                      // 短文案进多选；底栏才是「合并 & 创建新 Chat」主 CTA
                      l10n.multiSelect,
                      style: AppTheme.body.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ));

        return CupertinoPageScaffold(
          backgroundColor: AppColors.pageBg,
          navigationBar: ThkNavBar.inline(
            title: navTitle,
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: _onBack,
              child: const Icon(AppIcons.back),
            ),
            trailing: trailing,
          ),
          child: SafeArea(
            child: Column(
              children: [
                if (_multiSelectMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSp.screenPadding,
                      8,
                      AppSp.screenPadding,
                      0,
                    ),
                    child: _MultiSelectHintBar(
                      maxSelection: _maxSelection,
                      selectedCount: _selectedNodeIds.length,
                      isExpanded: _hintExpanded,
                      onToggleExpand: () =>
                          setState(() => _hintExpanded = !_hintExpanded),
                    ),
                  ),
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AppSp.screenPadding,
                      12,
                      AppSp.screenPadding,
                      24,
                    ),
                    children: [
                      DecoratedBox(
                        decoration: AppSurfaces.contentCard(radius: 14),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Column(
                            children: [
                              for (final root in treeRoots)
                                _FullTreeNodeRow(
                                  themeId: widget.themeId,
                                  node: root,
                                  allNodes: data.nodes,
                                  depth: 0,
                                  currentNodeId: widget.currentNodeId,
                                  highlightKey: _highlightKey,
                                  isMultiSelectMode: _multiSelectMode,
                                  selectedNodeIds: _selectedNodeIds,
                                  onToggleSelect: (nodeId) =>
                                      _toggleSelect(nodeId, data.nodes),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_multiSelectMode) _MergeBottomBar(
                  selectedCount: _selectedNodeIds.length,
                  maxSelection: _maxSelection,
                  enabled: _selectedNodeIds.isNotEmpty,
                  onMerge: () => _onMergeAndCreate(data.nodes),
                ),
              ],
            ),
          ),
        );
      },
      error: (e, st) => CupertinoPageScaffold(
        backgroundColor: AppColors.pageBg,
        navigationBar: ThkNavBar.inline(title: ''),
        child: Center(child: Text(e.toString())),
      ),
      loading: () => CupertinoPageScaffold(
        backgroundColor: AppColors.pageBg,
        navigationBar: ThkNavBar.inline(title: ''),
        child: const Center(child: CupertinoActivityIndicator()),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom bar — multi-select merge CTA
// ---------------------------------------------------------------------------

class _MergeBottomBar extends StatelessWidget {
  const _MergeBottomBar({
    required this.selectedCount,
    required this.maxSelection,
    required this.enabled,
    required this.onMerge,
  });

  final int selectedCount;
  final int maxSelection;
  final bool enabled;
  final VoidCallback onMerge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
        boxShadow: AppSurfaces.cardShadowSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.selectedCount(selectedCount, maxSelection),
              style: AppTheme.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ThkButton.filled(
            label: l10n.mergeAndCreate,
            onPressed: enabled ? onMerge : null,
            disabled: !enabled,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _FullTreeNodeRow — simplified tree row for full-tree view
// ---------------------------------------------------------------------------

class _FullTreeNodeRow extends StatelessWidget {
  const _FullTreeNodeRow({
    required this.themeId,
    required this.node,
    required this.allNodes,
    required this.depth,
    required this.currentNodeId,
    required this.highlightKey,
    this.isMultiSelectMode = false,
    this.selectedNodeIds = const [],
    this.onToggleSelect,
  });

  final String themeId;
  final NodeEntity node;
  final List<NodeEntity> allNodes;
  final int depth;
  final String? currentNodeId;
  final GlobalKey highlightKey;

  final bool isMultiSelectMode;
  final List<String> selectedNodeIds;
  final ValueChanged<String>? onToggleSelect;

  static const _kIndent = AppSp.treeIndent;

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
    final isRoot = depth == 0;

    final l10n = AppLocalizations.of(context)!;
    final sourceLabel = _sourceTypeLabel(l10n, node.sourceType);

    // In multi-select mode, only chat nodes are selectable.
    final isSelectable =
        !isMultiSelectMode || node.kind == NodeKind.chat;
    final isSelected = selectedNodeIds.contains(node.nodeId);

    final tile = GestureDetector(
      key: isCurrent ? highlightKey : null,
      behavior: HitTestBehavior.opaque,
      onTap: isMultiSelectMode
          ? (isSelectable ? () => onToggleSelect?.call(node.nodeId) : null)
          : () => context.push(
                '/themes/$themeId/nodes/${node.nodeId}',
                extra: node.title,
              ),
      child: Container(
        height: AppSp.treeRowHeight,
        color: isCurrent
            ? AppColors.accent.withValues(alpha: 0.08)
            : (isSelected
                ? AppColors.accent.withValues(alpha: 0.06)
                : null),
        child: Row(
          children: [
            if (isCurrent)
              Container(width: 3, height: AppSp.treeRowHeight, color: AppColors.accent)
            else
              const SizedBox(width: 3),
            Padding(
              padding: EdgeInsets.only(left: depth * _kIndent),
              child: SizedBox(
                width: AppSp.touchTarget,
                height: AppSp.touchTarget,
                child: Center(
                  child: isMultiSelectMode
                      ? _buildSelectionIndicator(isSelected, isSelectable)
                      : Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: hasChildren
                                ? palette.circle
                                : palette.circle.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: palette.circle, width: 2),
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
                      fontWeight: isRoot || isCurrent
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (sourceLabel != null)
                    Text(
                      sourceLabel,
                      style: AppTheme.caption1.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
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
            highlightKey: highlightKey,
            isMultiSelectMode: isMultiSelectMode,
            selectedNodeIds: selectedNodeIds,
            onToggleSelect: onToggleSelect,
          ),
      ],
    );
  }

  Widget _buildSelectionIndicator(bool isSelected, bool isSelectable) {
    if (!isSelectable) {
      return Icon(
        CupertinoIcons.circle,
        size: 22,
        color: AppColors.textTertiary.withValues(alpha: 0.45),
      );
    }
    return Icon(
      isSelected
          ? CupertinoIcons.checkmark_circle_fill
          : CupertinoIcons.circle,
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
// _MultiSelectHintBar — inset card teaching hint for multi-select merge
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggleExpand,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: AppSurfaces.cardShadowSm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: isExpanded ? 72 : 18,
              margin: const EdgeInsets.only(right: 12, top: 2),
              decoration: BoxDecoration(
                color: AppColors.plum,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${l10n.mergeChatHint(maxSelection)} · ${l10n.selectedCount(selectedCount, maxSelection)}',
                          style: AppTheme.caption1.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? CupertinoIcons.chevron_up
                            : CupertinoIcons.chevron_down,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                  if (isExpanded) ...[
                    const SizedBox(height: 8),
                    ..._buildGuideSteps(l10n),
                  ],
                ],
              ),
            ),
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
                  color: AppColors.plum.withValues(alpha: 0.7),
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

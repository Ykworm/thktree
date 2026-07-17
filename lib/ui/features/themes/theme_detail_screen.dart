import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/theme/app_spacing.dart';
import 'package:thk_tree/ui/core/theme/app_surfaces.dart';
import 'package:thk_tree/ui/core/theme/app_theme.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/features/notes/note_browse_screen.dart'
    show localizedThemeTitle;
import 'package:thk_tree/ui/features/themes/theme_detail_controller.dart';
import 'package:thk_tree/ui/core/shared/llm_setup_check.dart' show resolveChatModel;
import 'package:thk_tree/ui/features/settings/settings_controller.dart';
import 'package:thk_tree/ui/core/shared/title_suggestion_screen.dart';
import 'package:thk_tree/ui/features/chat/chat_screen_launch_params.dart';
import 'package:thk_tree/ui/features/doc_split/doc_split_input_screen.dart';
import 'package:thk_tree/domain/node.dart';
import 'package:thk_tree/data/services/session_markdown.dart';

// ---------------------------------------------------------------------------
// ThemeDetailScreen
// ---------------------------------------------------------------------------

class ThemeDetailScreen extends ConsumerStatefulWidget {
  const ThemeDetailScreen({
    super.key,
    required this.themeId,
    this.scrollToNodeId,
    this.searchPrefill,
  });

  final String themeId;
  final String? scrollToNodeId;
  final String? searchPrefill;

  @override
  ConsumerState<ThemeDetailScreen> createState() => _ThemeDetailScreenState();
}

class _ThemeDetailScreenState extends ConsumerState<ThemeDetailScreen> {
  final Set<String> _collapsedIds = {};

  void _showOverflowMenu() {
    final l10n = AppLocalizations.of(context)!;
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              ref
                  .read(themeDetailControllerProvider(widget.themeId).notifier)
                  .refresh();
            },
            child: Text(l10n.refresh),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _collapsedIds.isEmpty ? _collapseAll() : _expandAll();
            },
            child: Text(
              _collapsedIds.isEmpty ? l10n.collapseAll : l10n.expandAll,
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              context.push(
                '/themes/${widget.themeId}/full-tree?multiSelect=true',
              );
            },
            child: Text(l10n.mergeAndCreate),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ),
    );
  }

  void _collapseAll() {
    final detail =
        ref.read(themeDetailControllerProvider(widget.themeId)).value;
    if (detail == null) return;
    final nodes = detail.nodes;
    // Build parent→children index to find non-leaf nodes.
    final parentIds = <String>{};
    for (final n in nodes) {
      if (n.parentId != null) parentIds.add(n.parentId!);
    }
    setState(() {
      _collapsedIds.addAll(parentIds);
    });
  }

  void _expandAll() {
    setState(() {
      _collapsedIds.clear();
    });
  }

  Future<void> _onImportDocSplit() async {
    final l10n = AppLocalizations.of(context)!;

    final mdText = await Navigator.of(context).push<String>(
      CupertinoPageRoute(
        builder: (_) => const DocSplitInputScreen(),
      ),
    );
    if (mdText == null || mdText.trim().isEmpty) return;
    if (!mounted) return;

    try {
      final nodeStore = await ref.read(nodeStoreProvider.future);
      final sessionStore = await ref.read(sessionStoreProvider.future);
      final detail = ref.read(themeDetailControllerProvider(widget.themeId)).value;
      if (detail == null) return;

      const systemPrompt = '''
你是一个文档结构分析助手。用户会提供一段文档文本，你需要：
1. 分析文档内容，提出 2-3 种不同的拆分维度（如按主题、按逻辑结构、按时间线等）
2. 每种维度展示完整的树结构
3. 树结构使用以下 Markdown 格式输出：

## 维度A：[维度名称]
[维度说明]

- **[节点标题]**
  [节点内容：该节点的详细说明，2-4句话概括核心信息]
  - **[子节点标题]**
    [子节点内容]
  - **[子节点标题]**
    [子节点内容]
- **[节点标题]**
  [节点内容]

4. 每个维度之间用分隔线（---）隔开
5. 节点标题用加粗（**标题**），内容紧跟标题后（不加粗，缩进对齐）
6. 缩进表示层级关系（2空格 = 一级子节点）
''';

      final previewNode = await nodeStore.createChatNode(
        themeId: widget.themeId,
        themePath: detail.themePath,
        parentId: null,
        title: l10n.docSplitInputTitle,
        systemPrompt: systemPrompt,
      );

      await sessionStore.appendUserMessage(
        nodeId: previewNode.nodeId,
        content: mdText,
      );

      final trimmed = mdText.trim();
      final sourceExcerpt = trimmed.length <= 80 ? trimmed : '${trimmed.substring(0, 80)}...';
      await nodeStore.updateNodeSourceInfo(
        nodeId: previewNode.nodeId,
        sourceExcerpt: sourceExcerpt,
        sourceType: 'docSplit',
      );

      if (!mounted) return;

      context.push(
        '/themes/${widget.themeId}/nodes/${previewNode.nodeId}',
        extra: ChatScreenLaunchParams(
          title: l10n.docSplitInputTitle,
          autoTriggerReply: true,
          isDocSplit: true,
        ),
      );

      ref.read(themeDetailControllerProvider(widget.themeId).notifier).refresh();
    } catch (e) {
      if (!mounted) return;
      ThkAlert.show(context: context, message: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final detailAsync =
        ref.watch(themeDetailControllerProvider(widget.themeId));
    return detailAsync.when(
      data: (data) {
        final roots = data.nodes
            .where((n) => n.parentId == null)
            .toList(growable: false);
        roots.sort(_compareNodes);
        return CupertinoPageScaffold(
          backgroundColor: AppColors.pageBg,
          navigationBar: ThkNavBar.inline(
            title:
                l10n.treeTitle(localizedThemeTitle(l10n, data.themeTitle)),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () {
                if (Navigator.canPop(context)) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
              child: const Icon(AppIcons.back),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  key: const ValueKey('doc_split_button'),
                  padding: EdgeInsets.zero,
                  onPressed: _onImportDocSplit,
                  child: const Icon(AppIcons.docSplit),
                ),
                CupertinoButton(
                  key: const ValueKey('overflow_menu_button'),
                  padding: EdgeInsets.zero,
                  onPressed: _showOverflowMenu,
                  child: const Icon(AppIcons.more),
                ),
                CupertinoButton(
                  key: const ValueKey('add_node_button'),
                  padding: EdgeInsets.zero,
                  onPressed: () async {
                    final title = await _promptRootTitle(context);
                    if (title == null) return;
                    await ref
                        .read(themeDetailControllerProvider(widget.themeId)
                            .notifier)
                        .createRootChatNode(title: title);
                  },
                  child: Icon(AppIcons.add),
                ),
              ],
            ),
          ),
          child: roots.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.branch,
                        size: 40,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.emptyTree,
                        style: AppTheme.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: ListView(
                        key: const ValueKey('node_list'),
                        padding: const EdgeInsets.fromLTRB(
                          AppSp.screenPadding,
                          12,
                          AppSp.screenPadding,
                          80,
                        ),
                        children: [
                          DecoratedBox(
                            decoration:
                                AppSurfaces.contentCard(radius: 14),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Column(
                                children: [
                                  for (final root in roots)
                                    _TreeRowView(
                                      themeId: widget.themeId,
                                      node: root,
                                      allNodes: data.nodes,
                                      depth: 0,
                                      collapsedIds: _collapsedIds,
                                      onToggleCollapse: (id) =>
                                          setState(() {
                                        if (!_collapsedIds.remove(id)) {
                                          _collapsedIds.add(id);
                                        }
                                      }),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
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

/// Compare nodes by sortOrder.
int _compareNodes(NodeEntity a, NodeEntity b) {
  return a.sortOrder.compareTo(b.sortOrder);
}

// ---------------------------------------------------------------------------
// _TreeRowView
// ---------------------------------------------------------------------------


void _showRenameDialog(BuildContext context, WidgetRef ref, NodeEntity node, String themeId, List<NodeEntity> allNodes) {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController(text: node.title);
  
  showCupertinoDialog(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(l10n.renameNode),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          controller: controller,
          autofocus: true,
          placeholder: l10n.enterNewTitle,
          enableInteractiveSelection: true,
        ),
      ),
      actions: [
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.cancel),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () async {
            final newTitle = controller.text.trim();
            if (newTitle.isNotEmpty) {
              final store = await ref.read(nodeStoreProvider.future);
              await store.updateNodeTitle(nodeId: node.nodeId, newTitle: newTitle);
              ref.read(themeDetailControllerProvider(themeId).notifier).refresh();
            }
            if (context.mounted) Navigator.of(ctx).pop();
          },
          child: Text(l10n.save),
        ),
      ],
    ),
  );
}

class _TreeRowView extends ConsumerWidget {
  const _TreeRowView({
    required this.themeId,
    required this.node,
    required this.allNodes,
    required this.depth,
    required this.collapsedIds,
    required this.onToggleCollapse,
  });

  final String themeId;
  final NodeEntity node;
  final List<NodeEntity> allNodes;
  final int depth;
  final Set<String> collapsedIds;
  final ValueChanged<String> onToggleCollapse;

  static const _kIndent = AppSp.treeIndent;

  List<NodeEntity> _children() {
    final list = allNodes
        .where((n) => n.parentId == node.nodeId)
        .toList(growable: false);
    list.sort(_compareNodes);
    return list;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final children = _children();
    final isCollapsed = collapsedIds.contains(node.nodeId);
    final hasChildren = children.isNotEmpty;
    // 已达最大嵌套深度（节点层级 4 层）时禁用「分支」入口：
    // SwipeableRow 在 onSwipeRight == null 时自动隐藏该 action。
    // 分支本质是在当前节点下创建子节点，再深一层就会超过 kMaxNodeDepth。
    final atMaxDepth = computeNodeDepth(
          {for (final n in allNodes) n.nodeId: n},
          node.nodeId,
        ) >=
        kMaxNodeDepth;
    final palette = AppColors.paletteForNode(node.nodeId);
    // ── Source type label ──
    final sourceLabel = _sourceTypeLabel(l10n, node.sourceType);
    final isRoot = depth == 0;

    // ── Node tile ──
    final tileContent = SizedBox(
      height: AppSp.treeRowHeight,
      child: Padding(
        padding: EdgeInsets.only(left: depth * _kIndent),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Circle indicator (tappable only when hasChildren)
            GestureDetector(
              onTap: hasChildren ? () => onToggleCollapse(node.nodeId) : null,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: AppSp.touchTarget,
                height: AppSp.touchTarget,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: hasChildren
                          ? (isCollapsed
                              ? palette.circle
                              : palette.circle.withValues(alpha: 0.18))
                          : palette.circle.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: palette.circle,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Title + source label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    node.title,
                    style: AppTheme.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight:
                          isRoot ? FontWeight.w600 : FontWeight.w400,
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
            const SizedBox(width: 4),
          ],
        ),
      ),
    );

    final tile = DragTarget<NodeEntity>(
      onWillAcceptWithDetails: (details) =>
          details.data.parentId == node.parentId &&
          details.data.nodeId != node.nodeId,
      onAcceptWithDetails: (details) async {
        debugPrint('[REORDER] onAccept fired: ${details.data.title} -> target=${node.title}');
        try {
          await _handleReorder(
            ref,
            draggedNode: details.data,
            targetNode: node,
            allNodes: allNodes,
          );
          debugPrint('[REORDER] calling refreshNodesOnly...');
          await ref
              .read(themeDetailControllerProvider(themeId).notifier)
              .refreshNodesOnly();
          debugPrint('[REORDER] refreshNodesOnly done');
        } catch (e, st) {
          debugPrint('[REORDER] onAccept ERROR: $e');
          debugPrint('[REORDER] onAccept STACK: $st');
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        // Is this node the last sibling? If so, show bottom blue line.
        final siblings = allNodes
            .where((n) => n.parentId == node.parentId)
            .toList()
          ..sort(_compareNodes);
        final isLastChild = siblings.isNotEmpty &&
            siblings.last.nodeId == node.nodeId;
        final indicatorSide = isLastChild
            ? const Border(
                bottom: BorderSide(
                  color: AppColors.accent,
                  width: 2.5,
                ),
              )
            : const Border(
                top: BorderSide(
                  color: AppColors.accent,
                  width: 2.5,
                ),
              );
        return Container(
          decoration: isHovering
              ? BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.10),
                  border: indicatorSide,
                )
              : null,
          child: Row(
            children: [
              Expanded(
                child: SwipeableRow(
                  onSwipeLeft: () => _handleDelete(context, ref, l10n, node: node, themeId: themeId, allNodes: allNodes),
                  onSwipeRight: atMaxDepth
                      ? null
                      : () => _onCreateBranchFromMenu(context, ref, node: node),
                  leftActionLabel: l10n.swipeDelete,
                  leftActionIcon: AppIcons.delete,
                  leftActionColor: AppColors.destructive,
                  rightActionLabel: l10n.swipeBranch,
                  rightActionIcon: AppIcons.callSplit,
                  rightActionColor: AppColors.accent,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.push(
                      '/themes/$themeId/nodes/${node.nodeId}',
                      extra: node.title,
                    ),
                    onLongPress: () => _showRenameDialog(context, ref, node, themeId, allNodes),
                    child: tileContent,
                  ),
                ),
              ),
              // Drag handle — outside swipe zone; visible for same-level reorder
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _DragHandle(node: node),
              ),
            ],
          ),
        );
      },
    );

    // ── Children (only when expanded) ──
    if (!hasChildren || isCollapsed) {
      return tile;
    }

    final childWidgets = <Widget>[tile];
    for (int i = 0; i < children.length; i++) {
      childWidgets.add(
        _TreeRowView(
          themeId: themeId,
          node: children[i],
          allNodes: allNodes,
          depth: depth + 1,
          collapsedIds: collapsedIds,
          onToggleCollapse: onToggleCollapse,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: childWidgets,
    );
  }
}

// ---------------------------------------------------------------------------
// Drag handle with long-press to start drag
// ---------------------------------------------------------------------------

class _DragHandle extends StatefulWidget {
  const _DragHandle({required this.node});

  final NodeEntity node;

  @override
  State<_DragHandle> createState() => _DragHandleState();
}

class _DragHandleState extends State<_DragHandle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleCtrl.forward(),
      onTapUp: (_) => _scaleCtrl.reverse(),
      onTapCancel: () => _scaleCtrl.reverse(),
      child: LongPressDraggable<NodeEntity>(
        key: ValueKey('drag_handle_${widget.node.nodeId}'),
        data: widget.node,
        // Shorter delay so same-level reorder feels responsive.
        delay: const Duration(milliseconds: 180),
        onDragStarted: () => HapticFeedback.mediumImpact(),
        onDragEnd: (_) => _scaleCtrl.reverse(),
        onDraggableCanceled: (_, _) => _scaleCtrl.reverse(),
        feedback: DefaultTextStyle(
          style: CupertinoTheme.of(context).textTheme.textStyle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: AppSurfaces.contentCard(radius: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.line_horizontal_3,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.node.title,
                      style: AppTheme.body.copyWith(
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
        ),
        childWhenDragging: Opacity(
          opacity: 0.25,
          child: Icon(
            CupertinoIcons.line_horizontal_3,
            size: 22,
            color: AppColors.textSecondary,
          ),
        ),
        child: AnimatedBuilder(
          animation: _scaleAnim,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnim.value,
            child: child,
          ),
          child: SizedBox(
            width: AppSp.dragHandle,
            height: AppSp.dragHandle,
            child: Center(
              child: Icon(
                CupertinoIcons.line_horizontal_3,
                size: 22,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Delete handler (used by swipe action)
// ---------------------------------------------------------------------------

Future<void> _handleDelete(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n, {
  required NodeEntity node,
  required String themeId,
  required List<NodeEntity> allNodes,
}) async {
  final subtreeNodes = _collectSubtreeNodes(node, allNodes);
  final subtreeIds = subtreeNodes.map((item) => item.nodeId).toSet();
  final sameTitleNodesOutside = allNodes
      .where((item) =>
          item.title == node.title && !subtreeIds.contains(item.nodeId))
      .toList(growable: false);
  final confirmed = await _confirmDeleteNode(
    context,
    node: node,
    subtreeNodes: subtreeNodes,
    sameTitleNodesOutside: sameTitleNodesOutside,
  );
  if (confirmed != true) return;
  try {
    final deletedCount = await ref
        .read(themeDetailControllerProvider(themeId).notifier)
        .deleteNodeSubtree(nodeId: node.nodeId);
    if (!context.mounted) return;
    _showAlert(context, l10n.deletedCount(deletedCount));
  } catch (e) {
    if (!context.mounted) return;
    _showAlert(context, l10n.deleteFailed(e.toString()));
  }
}

/// Handle drag-to-reorder: recalculate sortOrder for all siblings.
Future<void> _handleReorder(
  WidgetRef ref, {
  required NodeEntity draggedNode,
  required NodeEntity targetNode,
  required List<NodeEntity> allNodes,
}) async {
  try {
    debugPrint('[REORDER] START dragged=${draggedNode.title} target=${targetNode.title}');
    final nodeStore = await ref.read(nodeStoreProvider.future);
    final parentId = targetNode.parentId;

    final siblings = allNodes
        .where((n) => n.parentId == parentId)
        .toList()
      ..sort(_compareNodes);

    debugPrint('[REORDER] siblings before: ${siblings.map((s) => '${s.title}(${s.sortOrder})').toList()}');

    // Determine direction: dragging down means insert AFTER target
    final draggedIdx = siblings.indexWhere((n) => n.nodeId == draggedNode.nodeId);
    final targetOriginalIdx = siblings.indexWhere((n) => n.nodeId == targetNode.nodeId);
    final draggingDown = draggedIdx < targetOriginalIdx;

    siblings.removeWhere((n) => n.nodeId == draggedNode.nodeId);
    debugPrint('[REORDER] after remove, count=${siblings.length}');

    final targetIdx =
        siblings.indexWhere((n) => n.nodeId == targetNode.nodeId);
    debugPrint('[REORDER] targetIdx=$targetIdx draggingDown=$draggingDown');

    siblings.insert(draggingDown ? targetIdx + 1 : targetIdx, draggedNode);
    debugPrint('[REORDER] siblings after: ${siblings.map((s) => s.title).toList()}');

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (int i = 0; i < siblings.length; i++) {
      await nodeStore.reorderNode(
        nodeId: siblings[i].nodeId,
        newSortOrder: now + i,
      );
    }
    debugPrint('[REORDER] DONE wrote ${siblings.length} nodes, sortOrder starts at $now');
  } catch (e, st) {
    debugPrint('[REORDER] ERROR: $e');
    debugPrint('[REORDER] STACK: $st');
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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

void _showAlert(BuildContext context, String message) {
  showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('OK'),
        ),
      ],
    ),
  );
}

List<NodeEntity> _collectSubtreeNodes(
    NodeEntity root, List<NodeEntity> allNodes) {
  final childrenByParent = <String?, List<NodeEntity>>{};
  for (final item in allNodes) {
    childrenByParent.putIfAbsent(item.parentId, () => []).add(item);
  }

  final result = <NodeEntity>[];
  final queue = <NodeEntity>[root];
  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);
    result.add(current);
    queue.addAll(childrenByParent[current.nodeId] ?? const []);
  }
  return result;
}

// ---------------------------------------------------------------------------
// Branch creation
// ---------------------------------------------------------------------------

Future<void> _onCreateBranchFromMenu(
  BuildContext context,
  WidgetRef ref, {
  required NodeEntity node,
}) async {
  final mode = await showBranchModeSheet(context);
  if (mode == null) return;
  if (!context.mounted) return;
  await _showBranchFlow(context, ref, node: node, mode: mode);
}

Future<void> _showBranchFlow(
  BuildContext context,
  WidgetRef ref, {
  required NodeEntity node,
  required BranchMode mode,
}) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final nodeStore = await ref.read(nodeStoreProvider.future);
    final row = await nodeStore.getNodeRow(nodeId: node.nodeId);
    final sessionPath = row['sessionPath'] as String;
    final sessionFile = File(sessionPath);
    String parentTranscript = '';
    String? providerId;
    String? modelId;
    if (await sessionFile.exists()) {
      final rawText = await sessionFile.readAsString();
      final doc = parseSessionMarkdown(rawText);
      parentTranscript = buildConversationTranscript(doc);
      providerId = doc.providerId;
      modelId = doc.modelId;
    }

    if (!context.mounted) return;

    final settings = ref.read(settingsControllerProvider).value;
    final providers = ref.read(llmProvidersProvider).value;
    final resolved = resolveChatModel(
      sessionProviderId: providerId,
      sessionModelId: modelId,
      lastUsedChatProviderId: settings?.lastUsedChatProviderId,
      lastUsedChatModelId: settings?.lastUsedChatModelId,
      chatDefaultProviderId: settings?.chatDefaultProviderId,
      chatDefaultModelId: settings?.chatDefaultModelId,
      providers: providers,
    );
    providerId = resolved.$1;
    modelId = resolved.$2;

    if (!context.mounted) return;

    await showBranchFlow(
      context: context,
      mode: mode,
      selectedText: null,
      parentTranscript: parentTranscript,
      providerId: providerId,
      modelId: modelId,
      themeId: node.themeId,
      parentNodeId: node.nodeId,
    );
  } catch (e) {
    if (!context.mounted) return;
    _showAlert(context, l10n.branchFailed(e.toString()));
  }
}

// ---------------------------------------------------------------------------
// Delete dialog
// ---------------------------------------------------------------------------

Future<bool?> _confirmDeleteNode(
  BuildContext context, {
  required NodeEntity node,
  required List<NodeEntity> subtreeNodes,
  required List<NodeEntity> sameTitleNodesOutside,
}) {
  return showCupertinoDialog<bool>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      final descendantCount = subtreeNodes.length - 1;
      final keptNodeIds =
          sameTitleNodesOutside.map((item) => item.nodeId).join('\n');
      final needsAck = sameTitleNodesOutside.isNotEmpty;
      bool acknowledged = false;
      return StatefulBuilder(
        builder: (context, setState) {
          return CupertinoAlertDialog(
            title: Text(l10n.deleteItem),
            content: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.deleteConfirm(node.title)),
                  if (kDebugMode) ...[
                    const SizedBox(height: 8),
                    Text(l10n.targetNodeId(node.nodeId)),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    descendantCount > 0
                        ? l10n.deleteDescWithChildren(descendantCount)
                        : l10n.deleteDescOnly,
                  ),
                  if (needsAck) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.keptSameTitleNodes(sameTitleNodesOutside.length),
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(keptNodeIds),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () =>
                          setState(() => acknowledged = !acknowledged),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 6, top: 2),
                            child: Icon(
                              acknowledged
                                  ? CupertinoIcons.checkmark_square_fill
                                  : CupertinoIcons.square,
                              size: 20,
                              color: acknowledged
                                  ? AppColors.destructive
                                  : AppColors.textSecondary,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              l10n.deleteUnderstand,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: acknowledged
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: needsAck && !acknowledged
                    ? null
                    : () => Navigator.of(context).pop(true),
                child: Text(l10n.delete),
              ),
            ],
          );
        },
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Prompt root title (already Cupertino — kept as-is)
// ---------------------------------------------------------------------------

Future<String?> _promptRootTitle(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController();
  return showCupertinoDialog<String>(
    context: context,
    builder: (context) {
      return CupertinoAlertDialog(
        title: Text(l10n.newSession),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ThkTextField(
            key: const ValueKey('node_title_input'),
            controller: controller,
            placeholder: l10n.titleHint,
            autofocus: true,
            maxLength: 30,
            onSubmitted: (value) {
              final composing = controller.value.composing;
              if (composing.isValid && !composing.isCollapsed) return;
              Navigator.of(context)
                  .pop(value.trim().isEmpty ? null : value.trim());
            },
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            key: const ValueKey('node_create_button'),
            isDefaultAction: true,
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

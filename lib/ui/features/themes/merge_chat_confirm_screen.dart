import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/theme/app_theme.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/themes/theme_detail_controller.dart';
import 'package:thk_tree/ui/features/chat/chat_screen_launch_params.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/domain/node.dart';
import 'package:thk_tree/domain/theme.dart';
import 'package:thk_tree/ui/features/themes/merge_chat_tree_scope.dart';

/// Step 2 of the multi-chat merge flow.
///
/// User enters a title for the new chat and selects a mount location (parent node).
/// On submit, the selected chats' conversation histories are merged into a single
/// user message and written to the new chat's session.md.
///
/// [crossTree] controls whether the mount-location picker may span across
/// multiple trees (themes):
/// - `false` (entry from a chat page): only the current tree is shown.
/// - `true`  (entry from a tree page): a tree selector is shown on top so the
///   merged chat can be mounted into any tree.
class MergeChatConfirmScreen extends ConsumerStatefulWidget {
  const MergeChatConfirmScreen({
    super.key,
    required this.themeId,
    required this.selectedNodes,
    this.crossTree = false,
  });

  final String themeId;
  final List<NodeEntity> selectedNodes;
  final bool crossTree;

  @override
  ConsumerState<MergeChatConfirmScreen> createState() =>
      _MergeChatConfirmScreenState();
}

class _MergeChatConfirmScreenState extends ConsumerState<MergeChatConfirmScreen> {
  final TextEditingController _titleController = TextEditingController();
  String? _selectedParentId; // null = root (top level)
  bool _isSubmitting = false;
  bool _titleValid = false;

  // Cross-tree selection state (only used when [widget.crossTree] is true).
  String? _selectedThemeId; // currently selected target tree
  List<ThemeEntity>? _themes;

  @override
  void initState() {
    super.initState();
    _selectedThemeId = widget.themeId;
    if (widget.crossTree) _loadThemes();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadThemes() async {
    try {
      final themeStore = await ref.read(themeStoreProvider.future);
      final themes = await themeStore.listThemes();
      if (!mounted) return;
      setState(() => _themes = themes);
    } catch (e) {
      // Themes failed to load: the tree selector simply won't render
      // (themes.length <= 1 guard), and the current tree remains usable.
    }
  }

  void _onTitleChanged(String value) {
    final isValid = value.trim().isNotEmpty;
    if (isValid != _titleValid) {
      setState(() => _titleValid = isValid);
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final sessionStore = await ref.read(sessionStoreProvider.future);
      final nodeStore = await ref.read(nodeStoreProvider.future);
      final targetThemeId = widget.crossTree ? _selectedThemeId! : widget.themeId;
      final detail =
          ref.read(themeDetailControllerProvider(targetThemeId)).value;
      if (detail == null) throw StateError('Theme data not available');

      // 1. Read each selected node's session and collect messages.
      final allMessages = <SessionMessage>[];
      for (final node in widget.selectedNodes) {
        final doc = await sessionStore.readSession(node.nodeId);
        allMessages.addAll(doc.messages);
      }

      // 2. Create new chat node.
      //
      // For the chat-page entry the merged chat must stay inside the current
      // tree. The mount-location picker only renders nodes of the current tree,
      // and this guard re-checks at submit time: if the chosen parent is not in
      // the current tree (shouldn't happen via the UI, but defense in depth),
      // it falls back to the current tree's root.
      final String? effectiveParentId;
      if (widget.crossTree) {
        effectiveParentId = _selectedParentId;
      } else {
        final root = currentTreeRootIdOf(detail.nodes, widget.selectedNodes);
        final subIds = <String>{
          for (final n in subTreeNodes(detail.nodes, root ?? '')) n.nodeId
        };
        effectiveParentId = (_selectedParentId != null &&
                subIds.contains(_selectedParentId!))
            ? _selectedParentId
            : root;
      }
      final newNode = await nodeStore.createChatNode(
        themeId: targetThemeId,
        themePath: detail.themePath,
        parentId: effectiveParentId,
        title: title,
      );

      // 3. Import all messages preserving original roles.
      await sessionStore.importMessages(
        nodeId: newNode.nodeId,
        messages: allMessages,
      );

      // 4. Refresh tree data (fire-and-forget).
      ref
          .read(themeDetailControllerProvider(targetThemeId).notifier)
          .refresh();

      // 5. Navigate to the new chat (autoTriggerReply = false).
      //
      // 用 go 而非 pushReplacement：合并入口来自 full-tree（它本身是从某个
      // chat 页 push 进来的），若用 pushReplacement，导航栈会变成
      // [tree, chatA, fullTree, newChat]，新 chat 页点返回会落回 fullTree，
      // 而不是用户预期的 tree page。
      //
      // 改成 go 会把 themes 分支栈重置为只剩 [newChat]，此时
      // ChatScreen 的返回走 canPop=false 分支，fallback 到
      // '/themes/:themeId/tree'，即 tree page。仍保持"停留在 chat page"的现状。
      //
      // 注意：跨 tree 时新 chat 可能落在与入口不同的 tree，这里用
      // [targetThemeId] 而非 [widget.themeId]，保证跳转到正确的 tree。
      if (!mounted) return;
      context.go(
        '/themes/$targetThemeId/nodes/${newNode.nodeId}',
        extra: ChatScreenLaunchParams(
          title: title,
          autoTriggerReply: false,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final l10n = AppLocalizations.of(context)!;
      ThkAlert.show(
        context: context,
        message: l10n.branchFailed(e.toString()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final detailAsync = widget.crossTree
        ? ref.watch(themeDetailControllerProvider(_selectedThemeId!))
        : ref.watch(themeDetailControllerProvider(widget.themeId));

    return CupertinoPageScaffold(
      backgroundColor: AppColors.surface,
      navigationBar: ThkNavBar.inline(
        title: l10n.mergeChatConfirmTitle,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => context.pop(),
          child: const Icon(AppIcons.back),
        ),
      ),
      child: SafeArea(
        child: detailAsync.when(
          data: (data) => _buildBody(data.nodes, l10n),
          error: (e, st) => Center(child: Text(e.toString())),
          loading: () => const Center(child: CupertinoActivityIndicator()),
        ),
      ),
    );
  }

  Widget _buildBody(List<NodeEntity> allNodes, AppLocalizations l10n) {
    // For the chat-page entry (crossTree == false) the mount-location picker
    // must stay inside the *current tree* — the sub-tree rooted at the merged
    // chats' common root — NOT the whole theme. A theme can hold multiple root
    // nodes (multiple trees), so `widget.themeId` alone would leak other trees.
    // The tree-page entry (crossTree == true) may span trees, so it shows the
    // entire selected theme.
    final String? currentTreeRootId =
        widget.crossTree ? null : currentTreeRootIdOf(allNodes, widget.selectedNodes);

    final List<NodeEntity> treeRowRoots;
    final List<NodeEntity> treeRowNodes;
    if (widget.crossTree) {
      treeRowRoots = allNodes.where((n) => n.parentId == null).toList()
        ..sort(_compareNodes);
      treeRowNodes = allNodes;
    } else if (currentTreeRootId != null) {
      final subTree = subTreeNodes(allNodes, currentTreeRootId);
      // Show descendants only; the current tree's root is represented by the
      // dedicated "root option" below, avoiding a duplicated row.
      treeRowNodes = subTree
          .where((n) => n.nodeId != currentTreeRootId)
          .toList();
      treeRowRoots = directChildren(subTree, currentTreeRootId)
        ..sort(_compareNodes);
    } else {
      // Fallback (shouldn't happen): no resolvable tree root — show whole theme.
      treeRowRoots = allNodes.where((n) => n.parentId == null).toList()
        ..sort(_compareNodes);
      treeRowNodes = allNodes;
    }

    final bool rootIsSelected = widget.crossTree
        ? _selectedParentId == null
        : (_selectedParentId == null || _selectedParentId == currentTreeRootId);

    return Column(
      children: [
        // Title input.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CupertinoTextField(
                controller: _titleController,
                placeholder: l10n.newSession,
                onChanged: _onTitleChanged,
                style: AppTheme.body,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        ),
        // Mount location section.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.selectMountLocation,
              style: AppTheme.caption1.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        // Tree selector.
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              // Cross-tree selector (only when entry allows spanning trees).
              if (widget.crossTree) _buildThemeSelector(l10n),
              // Root option. For the chat-page entry this mounts at the top of
              // the current tree (under its root), keeping the merged chat
              // inside that tree; for the tree-page entry it creates a new
              // top-level chat in the selected theme.
              _LocationOption(
                title: l10n.rootNode,
                depth: 0,
                isSelected: rootIsSelected,
                onTap: () => setState(() => _selectedParentId =
                    widget.crossTree ? null : currentTreeRootId),
                isRoot: true,
              ),
              // Tree nodes.
              ..._buildTreeRows(treeRowRoots, treeRowNodes, l10n),
            ],
          ),
        ),
        // Submit button.
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: (_titleValid && !_isSubmitting) ? _submit : null,
              child: _isSubmitting
                  ? const CupertinoActivityIndicator(color: AppColors.white)
                  : Text(l10n.done),
            ),
          ),
        ),
      ],
    );
  }

  /// Horizontal tree selector shown above the node list when [widget.crossTree]
  /// is true. Only rendered when more than one tree exists, so single-tree
  /// scenarios stay noise-free. Tapping a tree switches the node list and
  /// resets the chosen mount location.
  Widget _buildThemeSelector(AppLocalizations l10n) {
    final themes = _themes ?? [];
    if (themes.length <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.selectTree,
            style: AppTheme.caption1.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: themes.map((theme) {
                final selected = theme.themeId == _selectedThemeId;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _selectedThemeId = theme.themeId;
                      _selectedParentId = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.accent
                            : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? AppColors.accent
                              : AppColors.border,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        theme.title,
                        style: AppTheme.caption1.copyWith(
                          color: selected
                              ? AppColors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTreeRows(
    List<NodeEntity> roots,
    List<NodeEntity> allNodes,
    AppLocalizations l10n,
  ) {
    final sorted = [...roots]..sort(_compareNodes);
    final result = <Widget>[];
    for (final root in sorted) {
      result.add(_LocationTreeNodeRow(
        node: root,
        allNodes: allNodes,
        depth: 0,
        selectedParentId: _selectedParentId,
        onTap: (nodeId) => setState(() => _selectedParentId = nodeId),
      ));
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// _LocationTreeNodeRow — single-select tree row for choosing mount location
// ---------------------------------------------------------------------------

class _LocationTreeNodeRow extends StatelessWidget {
  const _LocationTreeNodeRow({
    required this.node,
    required this.allNodes,
    required this.depth,
    required this.selectedParentId,
    required this.onTap,
  });

  final NodeEntity node;
  final List<NodeEntity> allNodes;
  final int depth;
  final String? selectedParentId;
  final ValueChanged<String> onTap;

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
    final isSelected = node.nodeId == selectedParentId;

    final tile = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(node.nodeId),
      child: Container(
        color: isSelected ? AppColors.accent.withValues(alpha: 0.08) : null,
        child: Row(
          children: [
            if (isSelected)
              Container(width: 3, height: 44, color: AppColors.accent)
            else
              const SizedBox(width: 3),
            Padding(
              padding: EdgeInsets.only(left: depth * _kIndent),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Icon(
                    isSelected
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.circle,
                    size: 22,
                    color: isSelected
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                node.title,
                style: AppTheme.body.copyWith(
                  color: isSelected
                      ? AppColors.accent
                      : AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );

    if (children.isEmpty) return tile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        tile,
        for (final child in children)
          _LocationTreeNodeRow(
            node: child,
            allNodes: allNodes,
            depth: depth + 1,
            selectedParentId: selectedParentId,
            onTap: onTap,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _LocationOption — top-level option (e.g. "Root (Top Level)")
// ---------------------------------------------------------------------------

class _LocationOption extends StatelessWidget {
  const _LocationOption({
    required this.title,
    required this.depth,
    required this.isSelected,
    required this.onTap,
    this.isRoot = false,
  });

  final String title;
  final int depth;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isRoot;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: isSelected ? AppColors.accent.withValues(alpha: 0.08) : null,
        child: Row(
          children: [
            if (isSelected)
              Container(width: 3, height: 44, color: AppColors.accent)
            else
              const SizedBox(width: 3),
            Padding(
              padding: EdgeInsets.only(left: depth * _LocationTreeNodeRow._kIndent),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Icon(
                    isSelected
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.circle,
                    size: 22,
                    color: isSelected
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                style: AppTheme.body.copyWith(
                  color: isSelected
                      ? AppColors.accent
                      : AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

int _compareNodes(NodeEntity a, NodeEntity b) {
  return a.sortOrder.compareTo(b.sortOrder);
}

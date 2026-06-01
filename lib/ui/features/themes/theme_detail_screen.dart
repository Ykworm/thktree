import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/theme/app_theme.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/notes/note_browse_screen.dart'
    show localizedThemeTitle;
import 'package:thk_tree/ui/features/themes/theme_detail_controller.dart';
import 'package:thk_tree/ui/features/summary/summary_route_params.dart';
import 'package:thk_tree/domain/node.dart';
import 'package:thk_tree/data/services/session_markdown.dart';

class ThemeDetailScreen extends ConsumerStatefulWidget {
  const ThemeDetailScreen({super.key, required this.themeId});

  final String themeId;

  @override
  ConsumerState<ThemeDetailScreen> createState() => _ThemeDetailScreenState();
}

class _ThemeDetailScreenState extends ConsumerState<ThemeDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final detailAsync = ref.watch(themeDetailControllerProvider(widget.themeId));
    return detailAsync.when(
      data: (data) {
        final roots = data.nodes.where((n) => n.parentId == null).toList(growable: false);
        roots.sort((a, b) => a.createdAtUtcIso8601.compareTo(b.createdAtUtcIso8601));
        return CupertinoPageScaffold(
          navigationBar: ThkNavBar.inline(
            title: l10n.treeTitle(localizedThemeTitle(l10n, data.themeTitle)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => ref
                      .read(themeDetailControllerProvider(widget.themeId)
                          .notifier)
                      .refresh(),
                  child: Icon(AppIcons.refresh),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () async {
                    final title = await _promptTitle(context);
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
              ? Center(child: Text(l10n.emptyTree))
              : SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
                        children: [
                          for (int i = 0; i < roots.length; i++)
                            _TreeRowView(
                              themeId: widget.themeId,
                              node: roots[i],
                              allNodes: data.nodes,
                              depth: 0,
                              isLast: i == roots.length - 1,
                              ancestorsLast: const [],
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

class _TreeRowView extends ConsumerWidget {
  const _TreeRowView({
    required this.themeId,
    required this.node,
    required this.allNodes,
    required this.depth,
    required this.isLast,
    required this.ancestorsLast,
  });

  final String themeId;
  final NodeEntity node;
  final List<NodeEntity> allNodes;
  final int depth;
  final bool isLast;
  final List<bool> ancestorsLast;

  static const _kIndent = 28.0;

  List<NodeEntity> _children() {
    final list = allNodes.where((n) => n.parentId == node.nodeId).toList(growable: false);
    list.sort((a, b) => a.createdAtUtcIso8601.compareTo(b.createdAtUtcIso8601));
    return list;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final children = _children();
    final lineColor = CupertinoColors.separator.resolveFrom(context);

    final indentWidgets = <Widget>[];
    for (int i = 0; i < depth; i++) {
      final showLine = i < ancestorsLast.length && !ancestorsLast[i];
      indentWidgets.add(
        SizedBox(
          width: _kIndent,
          child: showLine
              ? CustomPaint(painter: _VerticalLinePainter(lineColor))
              : const SizedBox.shrink(),
        ),
      );
    }

    final connectorLine = CustomPaint(painter: _BranchPainter(lineColor, isLast: isLast, hasChildren: children.isNotEmpty));

    final tileContent = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...indentWidgets,
          SizedBox(width: _kIndent, child: connectorLine),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(node.title, style: AppTheme.body.copyWith(fontWeight: FontWeight.w600)),
                if (kDebugMode) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${node.kind.value} · ${node.nodeId}',
                    style: AppTheme.footnote.copyWith(color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              try {
                final t = await _promptTitle(context);
                if (t == null) return;

                final nodeStore = await ref.read(nodeStoreProvider.future);
                final row = await nodeStore.getNodeRow(nodeId: node.nodeId);
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
                  themeId: themeId,
                  parentNodeId: node.nodeId,
                  branchTitle: t,
                  parentSessionText: parentSessionText,
                );

                context.push(
                  '/themes/$themeId/nodes/${node.nodeId}/summary',
                  extra: params,
                );
              } catch (e) {
                if (!context.mounted) return;
                _showSnackBar(context, l10n.branchFailed(e.toString()));
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(AppIcons.callSplit, size: 18, color: CupertinoColors.systemBlue),
            ),
          ),
          GestureDetector(
            onTap: () async {
              final subtreeNodes = _collectSubtreeNodes(node, allNodes);
              final subtreeIds = subtreeNodes.map((item) => item.nodeId).toSet();
              final sameTitleNodesOutside = allNodes
                  .where((item) => item.title == node.title && !subtreeIds.contains(item.nodeId))
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
                _showSnackBar(context, l10n.deletedCount(deletedCount));
              } catch (e) {
                if (!context.mounted) return;
                _showSnackBar(context, l10n.deleteFailed(e.toString()));
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(AppIcons.delete, size: 18, color: CupertinoColors.systemRed),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );

    final tile = GestureDetector(
      onTap: () => context.push('/themes/$themeId/nodes/${node.nodeId}', extra: node.title),
      child: tileContent,
    );

    final childWidgets = <Widget>[tile];
    for (int i = 0; i < children.length; i++) {
      childWidgets.add(
        _TreeRowView(
          themeId: themeId,
          node: children[i],
          allNodes: allNodes,
          depth: depth + 1,
          isLast: i == children.length - 1,
          ancestorsLast: [...ancestorsLast, isLast],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: childWidgets,
    );
  }
}

void _showSnackBar(BuildContext context, String message) {
  showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class _VerticalLinePainter extends CustomPainter {
  _VerticalLinePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _VerticalLinePainter oldDelegate) => color != oldDelegate.color;
}

class _BranchPainter extends CustomPainter {
  _BranchPainter(this.color, {required this.isLast, required this.hasChildren});
  final Color color;
  final bool isLast;
  final bool hasChildren;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    final midX = size.width / 2;
    canvas.drawLine(Offset(midX, 0), Offset(midX, size.height / 2), paint);
    canvas.drawLine(Offset(midX, size.height / 2), Offset(size.width, size.height / 2), paint);
  }

  @override
  bool shouldRepaint(covariant _BranchPainter oldDelegate) =>
      color != oldDelegate.color || isLast != oldDelegate.isLast;
}

List<NodeEntity> _collectSubtreeNodes(NodeEntity root, List<NodeEntity> allNodes) {
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

Future<String?> _promptTitle(BuildContext context) async {
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
            controller: controller,
            placeholder: l10n.titleHint,
            autofocus: true,
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
      final keptNodeIds = sameTitleNodesOutside.map((item) => item.nodeId).join('\n');
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
              if (sameTitleNodesOutside.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.keptSameTitleNodes(sameTitleNodesOutside.length),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(keptNodeIds),
                const SizedBox(height: 12),
                Text(
                  '⚠ ${l10n.deleteUnderstand}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
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
            onPressed: sameTitleNodesOutside.isEmpty
                ? () => Navigator.of(context).pop(true)
                : null,
            child: Text(l10n.delete),
          ),
        ],
      );
    },
  );
}

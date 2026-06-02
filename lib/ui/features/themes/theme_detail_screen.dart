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
import 'package:thk_tree/ui/features/settings/settings_controller.dart';
import 'package:thk_tree/ui/core/shared/title_suggestion_screen.dart';
import 'package:thk_tree/domain/node.dart';
import 'package:thk_tree/data/services/llm_provider.dart' show LlmProvider;
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
            onTap: () => _onCreateBranchFromMenu(context, ref, node: node),
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

/// 主题树节点上的"创建分支"入口（节点 trailing 按钮）。
///
/// 1. 弹 [showBranchModeSheet] 让用户选 [BranchMode]（raw=原文 / summarize=LLM 总结）。
/// 2. 调内部 [_showBranchFlow] 完成 session 读取 + provider/model 解析 + 调顶层
///    [showBranchFlow] 完成标题选择 + 创建 chat node + 跳转。
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

/// 主题树节点上的"创建分支"流程。
///
/// 1. 从 session.md 读 transcript（作为分支源 / 总结输入）
/// 2. 解析 session frontmatter 的 providerId/modelId（fallback 全局设置）
/// 3. 调 [showBranchFlow] 顶层函数。
Future<void> _showBranchFlow(
  BuildContext context,
  WidgetRef ref, {
  required NodeEntity node,
  required BranchMode mode,
}) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    // 1. 读 session
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

    // 2. fallback 全局设置
    final settings = ref.read(settingsControllerProvider).value;
    if (settings != null) {
      providerId ??= _mapLegacyProviderToPresetId(settings.llmProvider);
      modelId ??= settings.model;
    }

    if (!context.mounted) return;

    // 3. 调顶层 showBranchFlow
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
    _showSnackBar(context, l10n.branchFailed(e.toString()));
  }
}

String _mapLegacyProviderToPresetId(LlmProvider provider) {
  switch (provider) {
    case LlmProvider.claude:
      return 'preset_anthropic';
    case LlmProvider.deepseek:
      return 'preset_deepseek';
    case LlmProvider.openai:
      return 'preset_openai';
    case LlmProvider.gemini:
      return 'preset_gemini';
    case LlmProvider.minimax:
      return 'preset_minimax';
    case LlmProvider.kimi:
      return 'preset_kimi';
  }
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
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(keptNodeIds),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => setState(() => acknowledged = !acknowledged),
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
                                  ? CupertinoColors.systemRed
                                  : CupertinoColors.secondaryLabel,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              l10n.deleteUnderstand,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: acknowledged
                                    ? CupertinoColors.label
                                    : CupertinoColors.secondaryLabel,
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

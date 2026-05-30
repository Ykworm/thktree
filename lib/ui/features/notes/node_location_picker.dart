import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/domain/node.dart';
import 'package:thk_tree/domain/theme.dart';
import 'package:thk_tree/ui/core/app_services.dart';

class NodeLocationResult {
  final String themeId;
  final String themePath;
  final String? parentId; // null = root conversation

  const NodeLocationResult({
    required this.themeId,
    required this.themePath,
    this.parentId,
  });
}

Future<NodeLocationResult?> showNodeLocationPicker(
  BuildContext context,
  WidgetRef ref,
) {
  return showModalBottomSheet<NodeLocationResult>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.6,
    ),
    builder: (_) => const _NodeLocationPickerContent(),
  );
}

class _NodeLocationPickerContent extends ConsumerStatefulWidget {
  const _NodeLocationPickerContent();

  @override
  ConsumerState<_NodeLocationPickerContent> createState() =>
      _NodeLocationPickerContentState();
}

class _NodeLocationPickerContentState
    extends ConsumerState<_NodeLocationPickerContent> {
  // Phase: theme selection → node selection
  _PickerPhase _phase = _PickerPhase.themeSelection;

  // Theme data
  List<ThemeEntity>? _themes;
  bool _themesLoading = true;
  Object? _themesError;

  // Selected theme & its node data
  ThemeEntity? _selectedTheme;
  String? _selectedThemePath;
  List<NodeEntity>? _nodes;
  bool _nodesLoading = false;
  Object? _nodesError;

  @override
  void initState() {
    super.initState();
    _loadThemes();
  }

  Future<void> _loadThemes() async {
    setState(() {
      _themesLoading = true;
      _themesError = null;
    });
    try {
      final themeStore = await ref.read(themeStoreProvider.future);
      final themes = await themeStore.listThemes();
      if (!mounted) return;
      setState(() {
        _themes = themes;
        _themesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _themesError = e;
        _themesLoading = false;
      });
    }
  }

  Future<void> _selectTheme(ThemeEntity theme) async {
    setState(() {
      _nodesLoading = true;
      _nodesError = null;
    });
    try {
      final nodeStore = await ref.read(nodeStoreProvider.future);
      final themeRow = await nodeStore.getThemeRow(themeId: theme.themeId);
      final themePath = themeRow['themePath']! as String;
      final nodes = await nodeStore.listNodes(themeId: theme.themeId);
      if (!mounted) return;
      setState(() {
        _selectedTheme = theme;
        _selectedThemePath = themePath;
        _nodes = nodes;
        _nodesLoading = false;
        _phase = _PickerPhase.nodeSelection;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _nodesError = e;
        _nodesLoading = false;
      });
    }
  }

  void _selectLocation({String? parentId}) {
    Navigator.of(context).pop(NodeLocationResult(
      themeId: _selectedTheme!.themeId,
      themePath: _selectedThemePath!,
      parentId: parentId,
    ));
  }

  void _backToThemeSelection() {
    setState(() {
      _selectedTheme = null;
      _selectedThemePath = null;
      _nodes = null;
      _nodesError = null;
      _phase = _PickerPhase.themeSelection;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return switch (_phase) {
      _PickerPhase.themeSelection => _buildThemeList(l10n),
      _PickerPhase.nodeSelection => _buildNodeTree(l10n),
    };
  }

  Widget _buildThemeList(AppLocalizations l10n) {
    if (_themesLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_themesError != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: Text(_themesError.toString())),
      );
    }

    final themes = _themes ?? [];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(l10n.selectTheme,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        const Divider(height: 1),
        Flexible(
          child: themes.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text(l10n.noThemesYet)),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: themes.length,
                  itemBuilder: (context, index) {
                    final theme = themes[index];
                    return ListTile(
                      title: Text(theme.title),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _selectTheme(theme),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNodeTree(AppLocalizations l10n) {
    if (_nodesLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_nodesError != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: Text(_nodesError.toString())),
      );
    }

    final nodes = _nodes ?? [];
    final rootNodes = nodes.where((n) => n.parentId == null).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(l10n.selectLocation,
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: _backToThemeSelection,
                child: Text(l10n.back),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // "As root chat" option
        ListTile(
          leading: const Icon(Icons.chat_bubble_outline),
          title: Text(l10n.asRootChat),
          onTap: () => _selectLocation(parentId: null),
        ),
        const Divider(height: 1),
        // Node tree
        if (nodes.isNotEmpty)
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: _buildNodeItems(rootNodes, nodes, 0),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildNodeItems(
    List<NodeEntity> roots,
    List<NodeEntity> allNodes,
    int depth,
  ) {
    final items = <Widget>[];
    for (final node in roots) {
      items.add(
        Padding(
          padding: EdgeInsets.only(left: depth * 16.0),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.subdirectory_arrow_right, size: 20),
            title: Text(node.title),
            onTap: () => _selectLocation(parentId: node.nodeId),
          ),
        ),
      );
      final children =
          allNodes.where((n) => n.parentId == node.nodeId).toList();
      items.addAll(_buildNodeItems(children, allNodes, depth + 1));
    }
    return items;
  }
}

enum _PickerPhase { themeSelection, nodeSelection }
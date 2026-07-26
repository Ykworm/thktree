import 'package:flutter/cupertino.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/domain/node.dart';
import 'package:thk_tree/domain/theme.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/theme/app_theme.dart';
import 'package:thk_tree/ui/core/widgets/thk_alert.dart';

/// Stable on-disk title for the default catch-all theme; display via [_localizedThemeTitle].
const _kUncategorizedThemeTitle = '未分类';

String _localizedThemeTitle(AppLocalizations l10n, String title) {
  if (title == _kUncategorizedThemeTitle) return l10n.uncategorized;
  return title;
}

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

/// 主题选择结果（仅主题，不含节点位置）。
class ThemeSelectionResult {
  final String themeId;
  final String themePath;
  final String themeTitle;

  const ThemeSelectionResult({
    required this.themeId,
    required this.themePath,
    required this.themeTitle,
  });
}

/// 显示仅选择主题的 Bottom Sheet。
///
/// 用于笔记创建场景，笔记挂在主题上，无需选择对话节点。
Future<ThemeSelectionResult?> showThemePicker(
  BuildContext context,
  WidgetRef ref,
  {VoidCallback? onThemeCreated}
) {
  return showCupertinoModalPopup<ThemeSelectionResult>(
    context: context,
    builder: (_) => Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: _ThemePickerContent(onThemeCreated: onThemeCreated),
    ),
  );
}

Future<NodeLocationResult?> showNodeLocationPicker(
  BuildContext context,
  WidgetRef ref,
  {VoidCallback? onThemeCreated}
) {
  return showCupertinoModalPopup<NodeLocationResult>(
    context: context,
    builder: (_) => Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: _NodeLocationPickerContent(onThemeCreated: onThemeCreated),
    ),
  );
}

class _NodeLocationPickerContent extends ConsumerStatefulWidget {
  const _NodeLocationPickerContent({this.onThemeCreated});

  final VoidCallback? onThemeCreated;

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

  // Pre-selected theme ID (for newly created themes)
  String? _preSelectedThemeId;

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
    // reparent / 笔记转对话会改变节点的 parentId：若选中的父节点已处于
    // 最大深度，再挂一层会超过 kMaxNodeDepth，这里提前拦截并提示。
    if (parentId != null) {
      final byId = {for (final n in _nodes ?? <NodeEntity>[]) n.nodeId: n};
      final parentDepth = computeNodeDepth(byId, parentId);
      if (parentDepth + 1 > kMaxNodeDepth) {
        final l10n = AppLocalizations.of(context)!;
        ThkAlert.show(context: context, message: l10n.maxNodeDepthReached(kMaxNodeDepth));
        return;
      }
    }
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

  Future<void> _createNewTheme(AppLocalizations l10n) async {
    // 弹出标题输入对话框
    final title = await _promptThemeTitle(l10n);
    if (title == null || !mounted) return;

    try {
      // 创建新主题
      final themeStore = await ref.read(themeStoreProvider.future);
      final newTheme = await themeStore.createTheme(title: title);
      
      // 重新加载主题列表
      await _loadThemes();
      
      // 设置新创建的主题为预选中状态
      if (mounted) {
        setState(() {
          _preSelectedThemeId = newTheme.themeId;
        });
        // 通知调用者有新主题被创建
        widget.onThemeCreated?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _themesError = e;
        });
      }
    }
  }

  Future<String?> _promptThemeTitle(AppLocalizations l10n) async {
    final controller = TextEditingController();
    return showCupertinoDialog<String>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(l10n.newTheme),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: controller,
              placeholder: l10n.titleHint,
              autofocus: true,
              enableInteractiveSelection: true,
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
        child: Center(child: CupertinoActivityIndicator()),
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
          child: Row(
            children: [
              Text(l10n.selectTheme, style: AppTheme.headline),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _createNewTheme(l10n),
                child: Icon(AppIcons.add),
              ),
            ],
          ),
        ),
        Flexible(
          child: themes.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text(l10n.noThemesYet)),
                )
              : ListView.builder(
                  itemCount: themes.length,
                  itemBuilder: (context, index) {
                    final theme = themes[index];
                    return CupertinoListTile(
                      title: Text(_localizedThemeTitle(l10n, theme.title)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_preSelectedThemeId == theme.themeId)
                            Icon(
                              CupertinoIcons.checkmark,
                              color: AppColors.accent,
                            ),
                          const CupertinoListTileChevron(),
                        ],
                      ),
                      onTap: () {
                        setState(() {
                          _preSelectedThemeId = null;
                        });
                        _selectTheme(theme);
                      },
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
        child: Center(child: CupertinoActivityIndicator()),
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
              Text(l10n.selectLocation, style: AppTheme.headline),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _backToThemeSelection,
                child: Text(l10n.back),
              ),
            ],
          ),
        ),
        // "As root chat" option and node tree in one section
        Flexible(
          child: ListView(
            children: [
              CupertinoListTile(
                leading: Icon(AppIcons.chat),
                title: Text(l10n.asRootChat),
                onTap: () => _selectLocation(parentId: null),
              ),
              ..._buildNodeItems(rootNodes, nodes, 0),
            ],
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
          child: CupertinoListTile(
            leading: Icon(AppIcons.subdirectoryArrowRight, size: 20),
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

/// 仅选择主题的 Picker 内容组件。
class _ThemePickerContent extends ConsumerStatefulWidget {
  const _ThemePickerContent({this.onThemeCreated});

  final VoidCallback? onThemeCreated;

  @override
  ConsumerState<_ThemePickerContent> createState() =>
      _ThemePickerContentState();
}

class _ThemePickerContentState extends ConsumerState<_ThemePickerContent> {
  List<ThemeEntity>? _themes;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadThemes();
  }

  Future<void> _loadThemes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final themeStore = await ref.read(themeStoreProvider.future);
      final themes = await themeStore.listThemes();
      if (!mounted) return;
      setState(() {
        _themes = themes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _selectTheme(ThemeEntity theme) async {
    try {
      final nodeStore = await ref.read(nodeStoreProvider.future);
      final themeRow = await nodeStore.getThemeRow(themeId: theme.themeId);
      final themePath = themeRow['themePath']! as String;
      if (!mounted) return;
      Navigator.of(context).pop(ThemeSelectionResult(
        themeId: theme.themeId,
        themePath: themePath,
        themeTitle: theme.title,
      ));
    } catch (e) {
      if (!mounted) return;
      ThkAlert.show(
        context: context,
        message: e.toString(),
        defaultAction: 'OK',
      );
    }
  }

  Future<void> _createNewTheme(AppLocalizations l10n) async {
    final controller = TextEditingController();
    final title = await showCupertinoDialog<String>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(l10n.newTheme),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: controller,
              placeholder: l10n.titleHint,
              autofocus: true,
              enableInteractiveSelection: true,
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

    if (title == null || !mounted) return;

    try {
      final themeStore = await ref.read(themeStoreProvider.future);
      final theme = await themeStore.createTheme(title: title);
      if (!mounted) return;

      widget.onThemeCreated?.call();

      // 获取 themePath 并返回
      final nodeStore = await ref.read(nodeStoreProvider.future);
      final themeRow = await nodeStore.getThemeRow(themeId: theme.themeId);
      final themePath = themeRow['themePath']! as String;
      if (!mounted) return;
      Navigator.of(context).pop(ThemeSelectionResult(
        themeId: theme.themeId,
        themePath: themePath,
        themeTitle: theme.title,
      ));
    } catch (e) {
      if (!mounted) return;
      ThkAlert.show(
        context: context,
        message: e.toString(),
        defaultAction: 'OK',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(l10n.selectTheme, style: AppTheme.headline),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _createNewTheme(l10n),
                child: Icon(AppIcons.add),
              ),
            ],
          ),
        ),
        Container(
          height: 0.5,
          color: AppColors.border,
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CupertinoActivityIndicator()),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: Text(_error.toString())),
          )
        else if ((_themes ?? []).isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                l10n.noThemesYet,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          Flexible(
            child: ListView.builder(
              itemCount: (_themes ?? []).length,
              itemBuilder: (context, index) {
                final theme = (_themes ?? [])[index];
                return CupertinoListTile(
                  title: Text(_localizedThemeTitle(l10n, theme.title)),
                  onTap: () => _selectTheme(theme),
                );
              },
            ),
          ),
      ],
    );
  }
}

enum _PickerPhase { themeSelection, nodeSelection }

import 'package:thk_tree/ui/features/notes/note_browse_screen.dart' show formatRelativeTime;
import 'dart:async';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectionArea;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/shared/llm_setup_check.dart'
    show resolveChatModel;
import 'package:thk_tree/ui/features/settings/settings_controller.dart';
import 'package:thk_tree/data/stores/note_store.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/chat/chat_screen_launch_params.dart';
import 'package:thk_tree/ui/features/notes/node_location_picker.dart';
import 'package:thk_tree/ui/features/notes/note_editor_screen.dart';
import 'package:thk_tree/ui/features/notes/generate_title_screen.dart';
import 'package:thk_tree/ui/features/themes/theme_detail_controller.dart';
import 'package:thk_tree/ui/features/themes/theme_list_controller.dart';

class NoteDetailScreen extends ConsumerStatefulWidget {
  const NoteDetailScreen({
    super.key,
    required this.notesDir,
    required this.noteId,
  });

  final String notesDir;
  final String noteId;

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen> {
  bool _editing = false;
  late final TextEditingController _controller;
  late final NoteStore _store;
  String _body = '';
  String _title = '';
  bool _loading = true;
  Object? _error;
  int? _lastSeenVersion;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _store = NoteStore(notesDir: Directory(widget.notesDir));
    _controller = TextEditingController();
    _lastSeenVersion = ref.read(noteListVersionProvider);
    _loadTitle();
    _loadBody();
  }

  Future<void> _loadBody() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await _store.readBody(widget.noteId);
      if (!mounted) return;
      setState(() {
        _body = body;
        _controller.text = body;
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

  Future<void> _loadTitle() async {
    try {
      final metas = await _store.listNoteMetas(includePreview: true);
      final meta = metas.firstWhere(
        (m) => m.noteId == widget.noteId,
        orElse: () => NoteMeta(
          themeId: '',
          noteId: widget.noteId,
          title: '',
          createdAt: '',
          updatedAt: '',
        ),
      );
      if (mounted) {
        setState(() {
          _title = meta.title;
        });
      }
    } catch (_) {
      // Ignore errors when loading title
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleEditing() async {
    if (_editing) {
      await _store.writeBody(widget.noteId, _controller.text);
      _body = _controller.text;
      ref.read(noteListVersionProvider.notifier).bump();

      // Update search index (fire-and-forget)
      _updateSearchIndex();

      if (!mounted) return;
    }
    setState(() {
      _editing = !_editing;
    });
  }

  /// Fire-and-forget: update search index after note save.
  void _updateSearchIndex() {
    unawaited(() async {
      try {
        final searchIndex = await ref.read(searchServiceProvider.future);
        final metas = await _store.listNoteMetas();
        final meta = metas.where((m) => m.noteId == widget.noteId).firstOrNull;
        if (meta == null) return;

        // Get theme title from themeStore
        final themeStore = await ref.read(themeStoreProvider.future);
        final themes = await themeStore.listThemes();
        final theme = themes.where((t) => t.themeId == meta.themeId).firstOrNull;
        final themeTitle = theme?.title ?? '';

        await searchIndex.upsertNote(
          noteId: meta.noteId,
          themeId: meta.themeId,
          themeTitle: themeTitle,
          noteTitle: meta.title,
          body: _body,
        );
      } catch (e) {
        // Silent fail - search index update should never block note save
      }
    }());
  }

  /// 复制全部笔记内容到剪贴板。
  Future<void> _copyAll() async {
    final textToCopy = _editing ? _controller.text : _body;
    if (textToCopy.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: textToCopy));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _copied = false);
    }
  }

  Future<void> _renameNote() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: _title);
    
    final newTitle = await showCupertinoDialog<String>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(l10n.renameNote),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ThkTextField(
              controller: controller,
              placeholder: l10n.titleHint,
              autofocus: true,
              maxLength: 30,
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
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );

    if (newTitle == null || newTitle.isEmpty) return;
    if (newTitle == _title) return;

    await _store.renameNote(noteId: widget.noteId, newTitle: newTitle);
    ref.read(noteListVersionProvider.notifier).bump();
    if (mounted) {
      setState(() {
        _title = newTitle;
      });
    }
  }

  Future<void> _deleteNote() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(l10n.deleteNote),
          content: Text(l10n.deleteNoteConfirmTitle(_title)),
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
        );
      },
    );
    if (confirmed != true) return;

    try {
      await _store.deleteNote(noteId: widget.noteId);
      ref.read(noteListVersionProvider.notifier).bump();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ThkAlert.show(
        context: context,
        message: '${l10n.deleteFailed}: $e',
        defaultAction: l10n.ok,
      );
    }
  }

  /// 跳转到 GenerateTitleScreen，让用户选择/自定义标题后确认。
  Future<void> _generateTitle() async {
    if (_body.trim().isEmpty) return;
    if (!mounted) return;

    final newTitle = await Navigator.of(context).push<String>(
      CupertinoPageRoute(
        builder: (_) => GenerateTitleScreen(
          noteId: widget.noteId,
          notesDir: widget.notesDir,
          currentTitle: _title,
          body: _body,
        ),
      ),
    );

    if (newTitle != null && newTitle != _title && mounted) {
      ref.read(noteListVersionProvider.notifier).bump();
      setState(() {
        _title = newTitle;
      });
    }
  }

  /// 将笔记转移到另一个主题。
  Future<void> _moveToTheme() async {
    final l10n = AppLocalizations.of(context)!;

    final themeResult = await showThemePicker(
      context,
      ref,
      onThemeCreated: () {
        ref.invalidate(themeListControllerProvider);
      },
    );
    if (themeResult == null) return;
    if (!mounted) return;

    try {
      final paths = await ref.read(appPathsProvider.future);
      final targetNotesDir = Directory('${paths.themesDir.path}/${themeResult.themeId}/notes');

      await _store.moveNote(
        noteId: widget.noteId,
        targetThemeId: themeResult.themeId,
        targetNotesDir: targetNotesDir,
      );

      ref.read(noteListVersionProvider.notifier).bump();

      if (!mounted) return;
      ThkAlert.show(
        context: context,
        message: l10n.noteMoved,
        defaultAction: l10n.ok,
      );
      // Pop back to note list since the note moved to a different theme
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ThkAlert.show(
        context: context,
        message: 'Failed: $e',
        defaultAction: l10n.ok,
      );
    }
  }

  void _showMoreActions() {
    final l10n = AppLocalizations.of(context)!;
    final canCopy = (_editing ? _controller.text : _body).isNotEmpty;
    ThkGridBottomSheet.show(
      context: context,
      showCancel: false,
      actions: [
        if (canCopy)
          GridAction(
            label: _copied ? l10n.copied : l10n.copy,
            icon: _copied ? AppIcons.checkCircle : AppIcons.copy,
            color: _copied ? CupertinoColors.systemGreen : AppColors.accent,
            onPressed: _copyAll,
          ),
        GridAction(
          label: l10n.renameNote,
          icon: AppIcons.edit,
          color: AppColors.textSecondary,
          onPressed: _renameNote,
        ),
        GridAction(
          label: l10n.generateTitle,
          icon: AppIcons.sparkles,
          color: AppColors.accent,
          onPressed: _generateTitle,
        ),
        GridAction(
          label: l10n.moveNote,
          icon: AppIcons.folder,
          color: CupertinoColors.systemIndigo,
          onPressed: _moveToTheme,
        ),
      ],
      destructiveActions: [
        GridAction(
          label: l10n.delete,
          icon: AppIcons.delete,
          color: CupertinoColors.systemRed,
          onPressed: _deleteNote,
        ),
      ],
    );
  }

  /// 从笔记创建一个新对话（简化流程）。
  ///
  /// 流程：选位置 → 直接创建对话（title = note title）→ 写入笔记内容 → 跳转。
  Future<void> _createChatFromNote() async {
    if (_body.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      ThkAlert.show(
        context: context,
        message: l10n.noMessagesYet,
        defaultAction: 'OK',
      );
      return;
    }

    // 1. 选位置
    final location = await showNodeLocationPicker(
      context, 
      ref,
      onThemeCreated: () {
        // 刷新主题列表
        ref.invalidate(themeListControllerProvider);
      },
    );
    if (location == null) return;
    if (!mounted) return;

    // 2. 解析 provider/model（笔记默认继承全局设置）
    final settings = ref.read(settingsControllerProvider).value;
    final providers = ref.read(llmProvidersProvider).value;
    final resolved = resolveChatModel(
      lastUsedChatProviderId: settings?.lastUsedChatProviderId,
      lastUsedChatModelId: settings?.lastUsedChatModelId,
      chatDefaultProviderId: settings?.chatDefaultProviderId,
      chatDefaultModelId: settings?.chatDefaultModelId,
      providers: providers,
    );
    String? providerId = resolved.$1;
    String? modelId = resolved.$2;

    // 3. 直接创建对话，title = note title
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final nodeStore = await container.read(nodeStoreProvider.future);
      final sessionStore = await container.read(sessionStoreProvider.future);
      final themeRow = await nodeStore.getThemeRow(themeId: location.themeId);
      final themePath = themeRow['themePath']! as String;

      // 合并笔记 title 和内容作为 user input
      final userInput = '$_title\n\n$_body';

      final childNode = await nodeStore.createChatNode(
        themeId: location.themeId,
        themePath: themePath,
        parentId: location.parentId,
        title: _title,
      );

      await sessionStore.appendUserMessage(
        nodeId: childNode.nodeId,
        content: userInput,
      );

      // Store source info
      final nodeSourceExcerpt = userInput.length <= 80
          ? userInput
          : '${userInput.substring(0, 80)}...';
      await nodeStore.updateNodeSourceInfo(
        nodeId: childNode.nodeId,
        sourceExcerpt: nodeSourceExcerpt,
        sourceType: 'note',
      );

      if (providerId != null && modelId != null) {
        await sessionStore.updateSessionModel(
          nodeId: childNode.nodeId,
          providerId: providerId,
          modelId: modelId,
        );
      }

      if (!mounted) return;

      // 刷新主题树
      unawaited(
        container
            .read(themeDetailControllerProvider(location.themeId).notifier)
            .refresh()
            .catchError((_) {}),
      );

      // 跳转到对话页面
      context.push(
        '/themes/${location.themeId}/nodes/${childNode.nodeId}',
        extra: ChatScreenLaunchParams(
          title: _title,
          autoTriggerReply: true,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ThkAlert.show(
        context: context,
        message: l10n.branchFailed(e.toString()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(noteListVersionProvider);
    if (_lastSeenVersion != version) {
      _lastSeenVersion = version;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_editing) {
          _loadBody();
        }
      });
    }
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.pageBg,
      navigationBar: ThkNavBar.inline(
        title: _title,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _createChatFromNote,
              child: Icon(AppIcons.branch),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _toggleEditing,
              key: const ValueKey('note_edit_button'),
              child: Icon(_editing ? AppIcons.check : AppIcons.edit),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showMoreActions,
              key: const ValueKey('note_more_actions_button'),
              child: const Icon(CupertinoIcons.ellipsis),
            ),
          ],
        ),
      ),
      child: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_editing) {
      return SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            Expanded(
              child: CupertinoTextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                padding: const EdgeInsets.all(16),
                style: TextStyle(
                  fontSize: 17,
                  height: 1.6,
                  color: AppColors.textPrimary,
                ),
                enableInteractiveSelection: true,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                ),
              ),
            ),
            MarkdownToolbar(controller: _controller),
          ],
        ),
      );
    }
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error.toString(),
          style: TextStyle(color: CupertinoColors.systemRed),
        ),
      );
    }
    if (_body.isEmpty) {
      return Center(
        child: Text(
          l10n.noMessagesYet,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    // 修复: SingleChildScrollView 默认 shrink-wrap 到 child intrinsic height,
    // 会让父级 Container 跟着 shrink-wrap. 用 SizedBox.expand 强制填满父级约束.
    return SizedBox.expand(
      child: Container(
        color: AppColors.surface,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            12 + MediaQuery.of(context).padding.bottom,
          ),
          child: SizedBox(
            width: double.infinity,
            // SelectionArea 让 GptMarkdown 渲染的笔记正文支持长按选中/复制部分文字
            // （与 chat_screen 中消息列表用法保持一致；iOS 上工具栏为 Cupertino 风格）。
            child: SelectionArea(
              child: GptMarkdown(
                _body,
                style: TextStyle(fontSize: 17, height: 1.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ThemeNoteListScreen extends ConsumerStatefulWidget {
  const ThemeNoteListScreen({
    super.key,
    required this.themeId,
    required this.notesDir,
  });

  final String themeId;
  final String notesDir;

  @override
  ConsumerState<ThemeNoteListScreen> createState() =>
      _ThemeNoteListScreenState();
}

class _ThemeNoteListScreenState extends ConsumerState<ThemeNoteListScreen> {
  late final NoteStore _store;
  List<NoteMeta>? _metas;
  bool _loading = true;
  Object? _error;
  int? _lastSeenVersion;

  @override
  void initState() {
    super.initState();
    _store = NoteStore(notesDir: Directory(widget.notesDir));
    _lastSeenVersion = ref.read(noteListVersionProvider);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final metas = await _store.listNoteMetas();
      if (!mounted) return;
      setState(() {
        _metas = metas;
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

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(noteListVersionProvider);
    if (_lastSeenVersion != version) {
      _lastSeenVersion = version;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _load();
        }
      });
    }
    final l10n = AppLocalizations.of(context)!;

    return ThkLargeTitlePage(
      title: l10n.notes,
      backgroundColor: AppColors.surface,
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _createNote(context, ref),
        key: const ValueKey('add_note_button'),
        child: Icon(AppIcons.add),
      ),
      children: _buildChildren(l10n),
    );
  }

  Future<void> _createNote(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    // 1. 选择主题
    final themeResult = await showThemePicker(
      context,
      ref,
      onThemeCreated: () {
        ref.invalidate(themeListControllerProvider);
      },
    );
    if (themeResult == null) return;
    if (!mounted) return;

    // 2. 跳转到编辑器
    if (!mounted) return;
    navigator.push(
      CupertinoPageRoute(
        builder: (_) => NoteEditorScreen(
          themeId: themeResult.themeId,
          themeTitle: themeResult.themeTitle,
          themePath: themeResult.themePath,
          notesDir: widget.notesDir,
          createMode: true,
        ),
      ),
    );
  }

  List<Widget> _buildChildren(AppLocalizations l10n) {
    if (_loading) {
      return [
        const Padding(
          padding: EdgeInsets.only(top: 80),
          child: Center(child: CupertinoActivityIndicator()),
        ),
      ];
    }
    if (_error != null) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Center(
            child: Text(
              '${l10n.noNotesYet}: $_error',
              style: TextStyle(color: CupertinoColors.systemRed),
            ),
          ),
        ),
      ];
    }
    final metas = _metas ?? [];
    if (metas.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIcons.note,
                  size: 40,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.noNotesYet,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      Column(
        children: [
          for (int i = 0; i < metas.length; i++) ...[
            SwipeableRow(
              key: ValueKey(metas[i].noteId),
              onSwipeLeft: () async {
                final l10n = AppLocalizations.of(context)!;
                final confirmed = await showCupertinoDialog<bool>(
                  context: context,
                  builder: (ctx) {
                    return CupertinoAlertDialog(
                      title: Text(l10n.deleteNote),
                      content: Text(
                          l10n.deleteNoteConfirmTitle(metas[i].title)),
                      actions: [
                        CupertinoDialogAction(
                          onPressed: () =>
                              Navigator.of(ctx).pop(false),
                          child: Text(l10n.cancel),
                        ),
                        CupertinoDialogAction(
                          isDestructiveAction: true,
                          onPressed: () =>
                              Navigator.of(ctx).pop(true),
                          child: Text(l10n.delete),
                        ),
                      ],
                    );
                  },
                );
                if (confirmed != true) return;
                try {
                  await _store.deleteNote(noteId: metas[i].noteId);
                  ref
                      .read(noteListVersionProvider.notifier)
                      .bump();
                } catch (e) {
                  if (!mounted) return;
                  ThkAlert.show(
                    context: context,
                    message: '${l10n.deleteFailed}: $e',
                    defaultAction: l10n.ok,
                  );
                }
              },
              leftActionLabel: l10n.swipeDelete,
              leftActionIcon: AppIcons.delete,
              leftActionColor: CupertinoColors.destructiveRed,
              child: ThkListTile(
                title: metas[i].title,
                subtitle: metas[i].preview != null
                    ? metas[i].preview!
                    : formatRelativeTime(l10n, metas[i].updatedAt),
                onTap: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => NoteDetailScreen(
                        notesDir: widget.notesDir,
                        noteId: metas[i].noteId,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (i < metas.length - 1)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 56),
                child: Container(
                  height: 0.5,
                  color: AppColors.border,
                ),
              ),
          ],
        ],
      ),
    ];
  }
}

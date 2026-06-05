import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/data/services/llm_provider.dart' show LlmProvider;
import 'package:thk_tree/data/stores/note_store.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/chat/chat_screen_launch_params.dart';
import 'package:thk_tree/ui/features/notes/node_location_picker.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';
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
      final metas = await _store.listNoteMetas();
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
      if (!mounted) return;
    }
    setState(() {
      _editing = !_editing;
    });
  }

  /// 复制全部笔记内容到剪贴板。
  Future<void> _copyAll() async {
    if (_body.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _body));
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
    String? providerId;
    String? modelId;
    final settings = ref.read(settingsControllerProvider).value;
    if (settings != null) {
      providerId = _mapLegacyProviderToPresetId(settings.llmProvider);
      modelId = settings.model;
    }

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

  /// 将旧版 LlmProvider 枚举映射到新系统的 preset provider id。
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
      backgroundColor: CupertinoColors.white,
      navigationBar: ThkNavBar.inline(
        title: _title,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_editing && _body.isNotEmpty)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _copyAll,
                child: Icon(
                  _copied ? AppIcons.checkCircle : AppIcons.copy,
                  color: _copied
                      ? CupertinoColors.systemGreen
                      : CupertinoColors.activeBlue,
                ),
              ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _createChatFromNote,
              child: Icon(AppIcons.branch),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _toggleEditing,
              child: Icon(_editing ? AppIcons.check : AppIcons.edit),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _deleteNote,
              child: const Icon(
                CupertinoIcons.trash,
                color: CupertinoColors.systemRed,
              ),
            ),
          ],
        ),
        onTitleTap: _renameNote,
      ),
      child: SafeArea(
        bottom: !_editing,
        child: _buildBody(l10n),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_editing) {
      return Column(
        children: [
          Expanded(
            child: CupertinoTextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              padding: const EdgeInsets.all(16),
              style: const TextStyle(
                fontSize: 17,
                height: 1.6,
                color: CupertinoColors.black,
              ),
              decoration: const BoxDecoration(
                color: CupertinoColors.white,
              ),
            ),
          ),
          MarkdownToolbar(controller: _controller),
        ],
      );
    }
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error.toString(),
          style: const TextStyle(color: CupertinoColors.systemRed),
        ),
      );
    }
    if (_body.isEmpty) {
      return Center(
        child: Text(
          l10n.noMessagesYet,
          style: const TextStyle(color: CupertinoColors.secondaryLabel),
        ),
      );
    }
    return Container(
      color: CupertinoColors.white,
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: GptMarkdown(
          _body,
          style: const TextStyle(fontSize: 17, height: 1.6),
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

    return CupertinoPageScaffold(
      navigationBar: ThkNavBar.inline(
        title: l10n.notes,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _createNote(context, ref),
          child: Icon(AppIcons.add),
        ),
      ),
      child: SafeArea(
        top: false,
        child: _buildBody(l10n),
      ),
    );
  }

  Future<void> _createNote(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final title = await showCupertinoDialog<String>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(l10n.newNote),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ThkTextField(
              controller: controller,
              placeholder: l10n.titleHint,
              autofocus: true,
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
    if (title == null) return;

    await _store.createNote(themeId: widget.themeId, title: title);
    ref.read(noteListVersionProvider.notifier).bump();
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          '${l10n.noNotesYet}: $_error',
          style: const TextStyle(color: CupertinoColors.systemRed),
        ),
      );
    }
    final metas = _metas ?? [];
    if (metas.isEmpty) {
      return Center(
        child: Text(
          l10n.noNotesYet,
          style: const TextStyle(color: CupertinoColors.secondaryLabel),
        ),
      );
    }
    return ListView(
      children: [
        ThkListSection(
          children: metas
              .map(
                (meta) => SwipeableRow(
                  key: ValueKey(meta.noteId),
                  onSwipeLeft: () async {
                    final l10n = AppLocalizations.of(context)!;
                    final confirmed = await showCupertinoDialog<bool>(
                      context: context,
                      builder: (ctx) {
                        return CupertinoAlertDialog(
                          title: Text(l10n.deleteNote),
                          content: Text(
                              l10n.deleteNoteConfirmTitle(meta.title)),
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
                      await _store.deleteNote(noteId: meta.noteId);
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
                    title: meta.title,
                    subtitle:
                        '${meta.noteId} \u00b7 ${meta.updatedAt}',
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => NoteDetailScreen(
                            notesDir: widget.notesDir,
                            noteId: meta.noteId,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

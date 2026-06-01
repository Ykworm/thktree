import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/data/stores/note_store.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/theme/app_theme.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/notes/node_location_picker.dart';

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
  bool _loading = true;
  Object? _error;
  int? _lastSeenVersion;

  @override
  void initState() {
    super.initState();
    _store = NoteStore(notesDir: Directory(widget.notesDir));
    _controller = TextEditingController();
    _lastSeenVersion = ref.read(noteListVersionProvider);
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

  Future<void> _createChatFromNote() async {
    final l10n = AppLocalizations.of(context)!;
    if (_body.isEmpty) {
      ThkAlert.show(
        context: context,
        message: l10n.noMessagesYet,
        defaultAction: 'OK',
      );
      return;
    }

    final location = await showNodeLocationPicker(context, ref);
    if (location == null) return;
    if (!mounted) return;

    final title = await _promptChatTitle(context);
    if (title == null) return;
    if (!mounted) return;

    try {
      final nodeStore = await ref.read(nodeStoreProvider.future);
      final node = await nodeStore.createChatNode(
        themeId: location.themeId,
        themePath: location.themePath,
        parentId: location.parentId,
        title: title,
        systemPrompt: _body,
      );

      if (mounted) {
        context.push('/themes/${location.themeId}/nodes/${node.nodeId}',
            extra: title);
      }
    } catch (e) {
      if (mounted) {
        ThkAlert.show(
          context: context,
          message: e.toString(),
          defaultAction: 'OK',
        );
      }
    }
  }

  Future<String?> _promptChatTitle(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    return showCupertinoDialog<String>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(l10n.chatTitle),
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
      navigationBar: ThkNavBar.inline(
        title: l10n.notes,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _createChatFromNote,
              child: Icon(AppIcons.forum),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _toggleEditing,
              child: Icon(_editing ? AppIcons.check : AppIcons.edit),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: _buildBody(l10n),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_editing) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: CupertinoTextField(
            controller: _controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGroupedBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: CupertinoColors.separator),
            ),
          ),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(_body, style: AppTheme.body),
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
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            middle: Text(l10n.notes),
          ),
          CupertinoSliverRefreshControl(
            onRefresh: _load,
          ),
          ..._buildSlivers(l10n),
        ],
      ),
    );
  }

  List<Widget> _buildSlivers(AppLocalizations l10n) {
    if (_loading) {
      return [
        const SliverFillRemaining(
          child: Center(child: CupertinoActivityIndicator()),
        ),
      ];
    }
    if (_error != null) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Text(
              '${l10n.noNotesYet}: $_error',
              style: const TextStyle(color: CupertinoColors.systemRed),
            ),
          ),
        ),
      ];
    }
    final metas = _metas ?? [];
    if (metas.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Text(
              l10n.noNotesYet,
              style: const TextStyle(color: CupertinoColors.secondaryLabel),
            ),
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: ThkListSection(
          children: metas
              .map((meta) => ThkListTile(
                    title: meta.title,
                    subtitle: '${meta.noteId} · ${meta.updatedAt}',
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
                  ))
              .toList(),
        ),
      ),
    ];
  }
}

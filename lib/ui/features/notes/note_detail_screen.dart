import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/data/stores/note_store.dart';
import 'package:thk_tree/ui/core/app_services.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noMessagesYet)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.chatCreated)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<String?> _promptChatTitle(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.chatTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.titleHint),
            onSubmitted: (value) {
              final composing = controller.value.composing;
              if (composing.isValid && !composing.isCollapsed) return;
              Navigator.of(context)
                  .pop(value.trim().isEmpty ? null : value.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notes),
        actions: [
          IconButton(
            onPressed: _createChatFromNote,
            icon: const Icon(Icons.forum),
            tooltip: l10n.createChatFromNote,
          ),
          IconButton(
            onPressed: _toggleEditing,
            icon: Icon(_editing ? Icons.check : Icons.edit),
            tooltip: _editing ? l10n.save : null,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadBody,
        child: _buildBody(l10n),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_editing) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      );
    }
    if (_loading) {
      return const _ScrollableWrap(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return _ScrollableWrap(
        child: Center(
          child: Text(
            _error.toString(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      );
    }
    if (_body.isEmpty) {
      return _ScrollableWrap(
        child: Center(child: Text(l10n.noMessagesYet)),
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        SelectableText(_body),
      ],
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
  ConsumerState<ThemeNoteListScreen> createState() => _ThemeNoteListScreenState();
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notes)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(l10n),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return const _ScrollableWrap(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return _ScrollableWrap(
        child: Center(child: Text('${l10n.noNotesYet}: $_error')),
      );
    }
    final metas = _metas ?? [];
    if (metas.isEmpty) {
      return _ScrollableWrap(
        child: Center(
          child: Text(
            l10n.noNotesYet,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: metas.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final meta = metas[index];
        return ListTile(
          title: Text(meta.title),
          subtitle: Text('${meta.noteId} · ${meta.updatedAt}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NoteDetailScreen(
                  notesDir: widget.notesDir,
                  noteId: meta.noteId,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ScrollableWrap extends StatelessWidget {
  const _ScrollableWrap({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: child,
        ),
      ],
    );
  }
}

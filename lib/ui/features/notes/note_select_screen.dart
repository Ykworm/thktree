import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/data/stores/note_store.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/notes/note_browse_screen.dart'
    show localizedThemeTitle;

/// One row on the select list — pairs a note's metadata with the
/// concrete `notes/` directory it lives under (so append targets the
/// right file across themes).
class _NoteEntry {
  _NoteEntry({
    required this.meta,
    required this.themeTitle,
    required this.notesDir,
  });

  final NoteMeta meta;
  final String themeTitle;
  final String notesDir;
}

class NoteSelectScreen extends ConsumerStatefulWidget {
  const NoteSelectScreen({
    super.key,
    required this.currentThemeId,
    required this.selectedText,
    required this.onNoteSelected,
  });

  /// The theme of the chat triggering "Add to note". Used as the
  /// destination for newly created notes.
  final String currentThemeId;
  final String selectedText;
  final void Function(BuildContext context, String? noteId) onNoteSelected;

  @override
  ConsumerState<NoteSelectScreen> createState() => _NoteSelectScreenState();
}

class _NoteSelectScreenState extends ConsumerState<NoteSelectScreen> {
  List<_NoteEntry> _entries = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final paths = await ref.read(appPathsProvider.future);
      final themesDir = paths.themesDir;
      final entries = <_NoteEntry>[];
      if (await themesDir.exists()) {
        final themeDirs = await themesDir.list().toList();
        for (final entity in themeDirs) {
          if (entity is! Directory) continue;
          final themeId = p.basename(entity.path);
          if (themeId.startsWith('.')) continue;
          final notesSubDir = Directory(p.join(entity.path, 'notes'));
          final store = NoteStore(notesDir: notesSubDir);
          final metas = await store.listNoteMetas();
          if (metas.isEmpty) continue;
          var themeTitle = themeId;
          try {
            final metaFile = File(p.join(entity.path, 'theme.meta.json'));
            if (await metaFile.exists()) {
              final raw = await metaFile.readAsString();
              final map = jsonDecode(raw) as Map<String, dynamic>;
              themeTitle = map['title'] as String? ?? themeId;
            }
          } catch (_) {}
          for (final meta in metas) {
            entries.add(_NoteEntry(
              meta: meta,
              themeTitle: themeTitle,
              notesDir: notesSubDir.path,
            ));
          }
        }
      }
      entries.sort((a, b) => b.meta.updatedAt.compareTo(a.meta.updatedAt));
      if (!mounted) return;
      setState(() {
        _entries = entries;
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
    final l10n = AppLocalizations.of(context)!;
    return CupertinoPageScaffold(
      navigationBar: ThkNavBar.inline(
        title: l10n.notes,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _createAndAppend(l10n),
          child: Icon(AppIcons.add),
        ),
      ),
      child: SafeArea(
        child: _buildBody(l10n),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error.toString(),
          style: TextStyle(color: AppColors.destructive),
        ),
      );
    }
    if (_entries.isEmpty) {
      return Center(
        child: Text(
          l10n.noNotesYet,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return ThkListSection(
      children: _entries
          .map((entry) => ThkListTile(
                title: entry.meta.title.isEmpty
                    ? entry.meta.noteId
                    : entry.meta.title,
                subtitle:
                    '${localizedThemeTitle(l10n, entry.themeTitle)} · ${entry.meta.updatedAt}',
                onTap: () => _appendToEntry(entry),
              ))
          .toList(),
    );
  }

  Future<void> _appendToEntry(_NoteEntry entry) async {
    try {
      final store = NoteStore(notesDir: Directory(entry.notesDir));
      await store.appendBody(entry.meta.noteId, widget.selectedText);
      ref.read(noteListVersionProvider.notifier).bump();
      if (!mounted) return;
      widget.onNoteSelected(context, entry.meta.noteId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ThkAlert.show(
        context: context,
        message: e.toString(),
        defaultAction: 'OK',
      );
    }
  }

  Future<void> _createAndAppend(AppLocalizations l10n) async {
    final title = await _promptTitle(l10n);
    if (title == null) return;
    try {
      final paths = await ref.read(appPathsProvider.future);
      final notesDir = Directory(
        p.join(paths.themesDir.path, widget.currentThemeId, 'notes'),
      );
      final store = NoteStore(notesDir: notesDir);
      final meta = await store.createNote(
        themeId: widget.currentThemeId,
        title: title,
      );
      if (!mounted) return;
      await store.appendBody(meta.noteId, widget.selectedText);
      ref.read(noteListVersionProvider.notifier).bump();
      if (!mounted) return;
      widget.onNoteSelected(context, meta.noteId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ThkAlert.show(
        context: context,
        message: e.toString(),
        defaultAction: 'OK',
      );
    }
  }

  Future<String?> _promptTitle(AppLocalizations l10n) async {
    final controller = TextEditingController();
    return showCupertinoDialog<String>(
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
              child: Text(l10n.create),
            ),
          ],
        );
      },
    );
  }
}

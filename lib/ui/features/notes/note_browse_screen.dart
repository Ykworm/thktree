import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/data/stores/note_store.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/features/notes/note_detail_screen.dart';

/// Stable on-disk title used as identifier for the catch-all theme
/// (notes created from the notes tab). Display name is localized via
/// [localizedThemeTitle].
const String kUncategorizedThemeTitle = '未分类';

/// Returns the user-facing theme title, swapping the stable marker
/// [kUncategorizedThemeTitle] for the current locale's translation.
String localizedThemeTitle(AppLocalizations l10n, String title) {
  if (title == kUncategorizedThemeTitle) return l10n.uncategorized;
  return title;
}

class NoteBrowseScreen extends ConsumerStatefulWidget {
  const NoteBrowseScreen({super.key});

  @override
  ConsumerState<NoteBrowseScreen> createState() => _NoteBrowseScreenState();
}

class _NoteBrowseScreenState extends ConsumerState<NoteBrowseScreen> {
  List<_ThemeNotes>? _themes;
  bool _loading = true;
  Object? _error;
  int? _lastSeenVersion;

  @override
  void initState() {
    super.initState();
    _lastSeenVersion = ref.read(noteListVersionProvider);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final themes = await _loadThemeNotes(ref);
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNoteInUncategorized(context, ref),
        tooltip: l10n.newNote,
        child: const Icon(Icons.add),
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
    final themes = _themes ?? [];
    if (themes.isEmpty) {
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
      itemCount: themes.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final tn = themes[index];
        return ListTile(
          title: Text(localizedThemeTitle(l10n, tn.title)),
          subtitle: Text(l10n.noteCount(tn.noteCount)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ThemeNoteListScreen(
                  themeId: tn.themeId,
                  notesDir: '${tn.themePath}/notes',
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

Future<List<_ThemeNotes>> _loadThemeNotes(WidgetRef ref) async {
  final paths = await ref.read(appPathsProvider.future);
  final themesDir = paths.themesDir;
  if (!await themesDir.exists()) return [];

  final result = <_ThemeNotes>[];
  final themeDirs = await themesDir.list().toList();
  for (final entity in themeDirs) {
    if (entity is! Directory) continue;
    final themeId = entity.path.split('/').last;
    if (themeId.startsWith('.')) continue;
    final notesSubDir = Directory('${entity.path}/notes');
    final store = NoteStore(notesDir: notesSubDir);
    final metas = await store.listNoteMetas();
    var title = themeId;
    try {
      final metaFile = File('${entity.path}/theme.meta.json');
      if (await metaFile.exists()) {
        final content = await metaFile.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        title = map['title'] as String? ?? themeId;
      }
    } catch (_) {}
    result.add(_ThemeNotes(
      themeId: themeId,
      themePath: entity.path,
      title: title,
      noteCount: metas.length,
    ));
  }
  result.sort((a, b) {
    final aPinned = a.title == '未分类';
    final bPinned = b.title == '未分类';
    if (aPinned && !bPinned) return -1;
    if (!aPinned && bPinned) return 1;
    return a.title.compareTo(b.title);
  });
  return result;
}

Future<String> _ensureUncategorizedTheme(WidgetRef ref) async {
  final paths = await ref.read(appPathsProvider.future);

  final themesDir = paths.themesDir;
  if (await themesDir.exists()) {
    final dirs = await themesDir.list().toList();
    for (final entity in dirs) {
      if (entity is! Directory) continue;
      final metaFile = File('${entity.path}/theme.meta.json');
      if (!await metaFile.exists()) continue;
      try {
        final content = await metaFile.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        if (map['title'] == kUncategorizedThemeTitle) {
          return map['themeId'] as String;
        }
      } catch (_) {}
    }
  }

  final store = await ref.read(themeStoreProvider.future);
  final theme = await store.createTheme(title: kUncategorizedThemeTitle);
  return theme.themeId;
}

Future<void> _createNoteInUncategorized(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final title = await _promptNoteTitle(context, l10n);
  if (title == null) return;

  final themeId = await _ensureUncategorizedTheme(ref);
  final paths = await ref.read(appPathsProvider.future);
  if (!context.mounted) return;

  final notesDir = Directory('${paths.themesDir.path}/$themeId/notes');
  final store = NoteStore(notesDir: notesDir);
  await store.createNote(themeId: themeId, title: title);
  ref.read(noteListVersionProvider.notifier).bump();
}

Future<String?> _promptNoteTitle(BuildContext context, AppLocalizations l10n) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(l10n.newNote),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.titleHint),
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

class _ThemeNotes {
  _ThemeNotes({
    required this.themeId,
    required this.themePath,
    required this.title,
    required this.noteCount,
  });
  final String themeId;
  final String themePath;
  final String title;
  final int noteCount;
}

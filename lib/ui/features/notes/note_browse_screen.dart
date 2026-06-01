import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/data/stores/note_store.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
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
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          ThkNavBar.large(
            title: l10n.notes,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _createNoteInUncategorized(context, ref),
              child: Icon(AppIcons.add),
            ),
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
              _error.toString(),
              style: const TextStyle(color: CupertinoColors.systemRed),
            ),
          ),
        ),
      ];
    }
    final themes = _themes ?? [];
    if (themes.isEmpty) {
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
          children: themes
              .map((tn) => ThkListTile(
                    title: localizedThemeTitle(l10n, tn.title),
                    subtitle: l10n.noteCount(tn.noteCount),
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => ThemeNoteListScreen(
                            themeId: tn.themeId,
                            notesDir: '${tn.themePath}/notes',
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

Future<void> _createNoteInUncategorized(
    BuildContext context, WidgetRef ref) async {
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

Future<String?> _promptNoteTitle(
    BuildContext context, AppLocalizations l10n) async {
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

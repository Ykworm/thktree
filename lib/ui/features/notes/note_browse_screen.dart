import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/data/stores/note_store.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/notes/node_location_picker.dart';
import 'package:thk_tree/ui/features/notes/note_detail_screen.dart';
import 'package:thk_tree/ui/features/notes/note_editor_screen.dart';
import 'package:thk_tree/ui/features/themes/theme_list_controller.dart';

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
      navigationBar: ThkNavBar.inline(
        title: l10n.notes,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _createNoteInUncategorized(context, ref),
          child: Icon(AppIcons.add),
        ),
      ),
      child: SafeArea(
        top: false,
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error.toString(),
            style: const TextStyle(color: CupertinoColors.systemRed),
          ),
        ),
      );
    }
    final themes = _themes ?? [];
    if (themes.isEmpty) {
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

Future<void> _createNoteInUncategorized(
    BuildContext context, WidgetRef ref) async {
  // 1. 选择主题
  final themeResult = await showThemePicker(
    context,
    ref,
    onThemeCreated: () {
      ref.invalidate(themeListControllerProvider);
    },
  );
  if (themeResult == null) return;
  if (!context.mounted) return;

  // 2. 获取 notesDir
  final paths = await ref.read(appPathsProvider.future);
  if (!context.mounted) return;
  final notesDir = Directory('${paths.themesDir.path}/${themeResult.themeId}/notes');

  // 3. 跳转到编辑器
  if (!context.mounted) return;
  Navigator.of(context).push(
    CupertinoPageRoute(
      builder: (_) => NoteEditorScreen(
        themeId: themeResult.themeId,
        themeTitle: themeResult.themeTitle,
        themePath: themeResult.themePath,
        notesDir: notesDir.path,
        createMode: true,
      ),
    ),
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

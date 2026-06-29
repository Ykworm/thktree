import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thk_tree/data/services/search_service.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/features/chat/chat_screen_launch_params.dart';
import 'package:thk_tree/ui/features/notes/note_detail_screen.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';

/// Public version of the result-row widget (was private _SearchResultItem).
class SearchResultItem extends ConsumerWidget {
  const SearchResultItem({
    super.key,
    required this.result,
    required this.onTap,
  });

  final SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.entityType == 'note'
                      ? CupertinoIcons.doc_text
                      : CupertinoIcons.chat_bubble,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.entityTitle,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (result.themeTitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                result.themeTitle,
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (result.snippet.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                result.snippet,
                style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Navigate to the right screen for a [SearchResult].
/// Pure function: takes (context, ref, result), returns `Future<void>`.
Future<void> navigateToSearchResult(
  BuildContext context,
  WidgetRef ref,
  SearchResult result,
) async {
  if (result.entityType == 'note') {
    final paths = await ref.read(appPathsProvider.future);
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (_) => NoteDetailScreen(
          notesDir: '${paths.themesDir.path}/${result.themeId}/notes',
          noteId: result.entityId,
        ),
      ),
    );
  } else {
    if (!context.mounted) return;
    context.push(
      '/themes/${result.themeId}/nodes/${result.entityId}',
      extra: ChatScreenLaunchParams(title: result.entityTitle),
    );
  }
}

/// Show SQLite repair dialog (used by both SearchScreen and SearchContent).
void showSearchRepairDialog(BuildContext context, VoidCallback onRepair) {
  final l10n = AppLocalizations.of(context)!;
  showCupertinoDialog(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(l10n.searchIndexError),
      content: Text(l10n.searchIndexErrorContent),
      actions: [
        CupertinoDialogAction(
          child: Text(l10n.repairLater),
          onPressed: () => Navigator.pop(ctx),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          child: Text(l10n.repairNow),
          onPressed: () {
            Navigator.pop(ctx);
            onRepair();
          },
        ),
      ],
    ),
  );
}

/// A reusable search box that optionally syncs its text to a shared notifier.
/// If [queryNotifier] is non-null, every onChanged updates the notifier value,
/// allowing sibling widgets to react to the current query.
class SearchBox extends StatefulWidget {
  const SearchBox({
    super.key,
    this.queryNotifier,
    this.placeholder,
    this.controller,
    this.focusNode,
  });

  final ValueNotifier<String>? queryNotifier;
  final String? placeholder;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _ownsController = false;
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsController = widget.controller == null;
    _ownsFocusNode = widget.focusNode == null;
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return CupertinoSearchTextField(
      controller: _controller,
      focusNode: _focusNode,
      placeholder: widget.placeholder ?? l10n.searchHint,
      onChanged: (value) {
        widget.queryNotifier?.value = value;
      },
    );
  }
}

/// Live results list driven by [queryNotifier].
/// Performs a debounced (300ms) full-text search via [searchServiceProvider].
class SearchResults extends ConsumerStatefulWidget {
  const SearchResults({super.key, required this.queryNotifier});

  final ValueNotifier<String> queryNotifier;

  @override
  ConsumerState<SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends ConsumerState<SearchResults> {
  List<SearchResult> _results = [];
  bool _loading = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.queryNotifier.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    widget.queryNotifier.removeListener(_onQueryChanged);
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final query = widget.queryNotifier.value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        final svc = await ref.read(searchServiceProvider.future);
        final results = await svc.search(query);
        if (mounted) {
          setState(() {
            _results = results;
            _loading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = e.toString();
            _loading = false;
          });
          if (e is DatabaseException) {
            showSearchRepairDialog(context, () => _runRepair());
          }
        }
      }
    });
  }

  Future<void> _runRepair() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = await ref.read(searchServiceProvider.future);
      final themeStore = await ref.read(themeStoreProvider.future);
      final paths = await ref.read(appPathsProvider.future);
      final themes = await themeStore.listThemes();
      final scanItems = themes.map((t) => ThemeScanItem(
        themeId: t.themeId,
        title: t.title,
        notesDir: Directory('${paths.themesDir.path}/${t.themeId}/notes'),
        nodesDir: Directory('${paths.themesDir.path}/${t.themeId}/nodes'),
      )).toList();
      await svc.rebuildAll(scanItems);
      if (mounted) {
        setState(() {
          _loading = false;
        });
        final l10n = AppLocalizations.of(context)!;
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(l10n.repairComplete),
            content: Text(l10n.repairCompleteContent),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                child: Text(l10n.ok),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
        // Re-run search with current query after repair.
        _onQueryChanged();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '修复失败: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: CupertinoActivityIndicator(),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          l10n.searchError,
          style: const TextStyle(color: CupertinoColors.destructiveRed),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.search, size: 40, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              widget.queryNotifier.value.isEmpty ? l10n.searchEmpty : l10n.searchNoResults,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        return SearchResultItem(
          result: result,
          onTap: () => navigateToSearchResult(context, ref, result),
        );
      },
    );
  }
}

/// Full-page search content: search box + results. Used by SearchScreen body.
class SearchContent extends StatefulWidget {
  const SearchContent({super.key});

  @override
  State<SearchContent> createState() => _SearchContentState();
}

class _SearchContentState extends State<SearchContent> {
  final _queryNotifier = ValueNotifier<String>('');

  @override
  void dispose() {
    _queryNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SearchBox(queryNotifier: _queryNotifier),
        ),
        Expanded(
          child: SearchResults(queryNotifier: _queryNotifier),
        ),
      ],
    );
  }
}
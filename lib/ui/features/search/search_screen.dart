import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thk_tree/data/services/search_service.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/features/notes/note_detail_screen.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<SearchResult> _results = [];
  bool _loading = false;
  String? _error;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _onSearchChanged(String query) async {
    _debounce?.cancel();

    if (query.trim().isEmpty) {
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
        final searchService = await ref.read(searchServiceProvider.future);
        final results = await searchService.search(query.trim());
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

          // Show repair dialog for SQLite errors
          if (e is DatabaseException) {
            _showRepairDialog();
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.searchTabLabel),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CupertinoSearchTextField(
                controller: _searchController,
                focusNode: _focusNode,
                placeholder: l10n.searchHint,
                onChanged: _onSearchChanged,
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CupertinoActivityIndicator(),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  l10n.searchError,
                  style: TextStyle(color: CupertinoColors.destructiveRed),
                ),
              ),
            Expanded(
              child: _results.isEmpty && !_loading && _error == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _searchController.text.isEmpty
                                ? CupertinoIcons.search
                                : CupertinoIcons.search,
                            size: 40,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchController.text.isEmpty
                                ? l10n.searchEmpty
                                : l10n.searchNoResults,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final result = _results[index];
                        return _SearchResultItem(
                          result: result,
                          onTap: () => _onResultTap(result),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _onResultTap(SearchResult result) async {
    if (result.entityType == 'note') {
      // Navigate to note detail via Navigator.push (no GoRoute needed)
      final paths = await ref.read(appPathsProvider.future);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute(
          builder: (_) => NoteDetailScreen(
            notesDir: '${paths.themesDir.path}/${result.themeId}/notes',
            noteId: result.entityId,
          ),
        ),
      );
    } else {
      // Navigate to chat screen
      context.push('/themes/${result.themeId}/nodes/${result.entityId}');
    }
  }

  void _showRepairDialog() {
    final l10n = AppLocalizations.of(context)!;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(l10n.searchIndexError),
        content: Text(l10n.searchIndexErrorContent),
        actions: [
          CupertinoDialogAction(
            child: Text(l10n.repairLater),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(l10n.repairNow),
            onPressed: () async {
              Navigator.pop(context);
              await _repairIndex();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _repairIndex() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final searchService = await ref.read(searchServiceProvider.future);
      final themeStore = await ref.read(themeStoreProvider.future);
      final paths = await ref.read(appPathsProvider.future);
      final themes = await themeStore.listThemes();

      final scanItems = themes.map((t) => ThemeScanItem(
        themeId: t.themeId,
        title: t.title,
        notesDir: Directory('${paths.themesDir.path}/${t.themeId}/notes'),
        nodesDir: Directory('${paths.themesDir.path}/${t.themeId}/nodes'),
      )).toList();

      await searchService.rebuildAll(scanItems);

      if (mounted) {
        setState(() {
          _loading = false;
        });

        final l10n = AppLocalizations.of(context)!;

        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(l10n.repairComplete),
            content: Text(l10n.repairCompleteContent),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                child: Text(l10n.ok),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
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
}

class _SearchResultItem extends StatelessWidget {
  const _SearchResultItem({
    required this.result,
    required this.onTap,
  });

  final SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.border,
              width: 0.5,
            ),
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
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
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (result.snippet.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                result.snippet,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textTertiary,
                ),
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

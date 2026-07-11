import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:thk_tree/data/services/auto_backup_service.dart';
import 'package:thk_tree/data/services/export_service.dart';
import 'package:thk_tree/data/services/search_service.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/features/chat/chat_screen_launch_params.dart';
import 'package:thk_tree/ui/features/notes/note_detail_screen.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';
import 'package:thk_tree/ui/features/backup_restore/backup_restore_screen.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:share_plus/share_plus.dart';

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
    this.onSearch,
  });

  final ValueNotifier<String>? queryNotifier;
  final String? placeholder;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  /// Called when the user explicitly triggers a search (keyboard search/return
  /// key, or an external search button). When non-null, live typing no longer
  /// drives searching on its own — callers wire an explicit trigger.
  final VoidCallback? onSearch;

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _ownsController = false;
  bool _ownsFocusNode = false;

  /// Guards against circular updates between [queryNotifier] and [_controller].
  ///
  /// When the notifier pushes a value to the controller (notifier → controller),
  /// setting `_controller.text` triggers `onChanged`, which would normally
  /// push back to the notifier. The flag short-circuits that return path.
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsController = widget.controller == null;
    _ownsFocusNode = widget.focusNode == null;
    // Listen to external notifier changes (e.g., tag tap) and sync to controller.
    widget.queryNotifier?.addListener(_onNotifierChanged);
    // Initial sync — notifier may already have a value (state preserved by IndexedStack).
    if (widget.queryNotifier != null) {
      _controller.text = widget.queryNotifier!.value;
    }
  }

  @override
  void dispose() {
    widget.queryNotifier?.removeListener(_onNotifierChanged);
    if (_ownsController) _controller.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _onNotifierChanged() {
    if (_syncing) return;
    final value = widget.queryNotifier?.value ?? '';
    // Only update if different — avoids unnecessary cursor jumps.
    if (_controller.text != value) {
      _syncing = true;
      _controller.text = value;
      _syncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return CupertinoSearchTextField(
      controller: _controller,
      focusNode: _focusNode,
      placeholder: widget.placeholder ?? l10n.searchHint,
      onChanged: (value) {
        // Skip when syncing from notifier to avoid circular push-back.
        if (!_syncing) {
          widget.queryNotifier?.value = value;
        }
      },
      onSubmitted: (_) => widget.onSearch?.call(),
    );
  }
}

/// Live results list driven by [queryNotifier].
/// Performs a debounced full-text search via [searchServiceProvider].
class SearchResults extends ConsumerStatefulWidget {
  const SearchResults({
    super.key,
    required this.queryNotifier,
    this.scrollable = true,
    this.debounceDelay = const Duration(milliseconds: 300),
  });

  final ValueNotifier<String> queryNotifier;

  /// Whether the list should scroll itself.
  /// Set to `false` when placed inside a [SliverToBoxAdapter] or other
  /// scrollable parent that handles scrolling.
  final bool scrollable;

  /// Debounce before firing the search. Defaults to 300ms (live typing).
  /// Pass [Duration.zero] for an explicit-commit search box where the caller
  /// already controls when a search happens.
  final Duration debounceDelay;

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
    // If queryNotifier already has a non-empty value (e.g., tapped from tag
    // cloud), fire search immediately — ValueNotifier only notifies on
    // *changes*, not the current value.
    if (widget.queryNotifier.value.trim().isNotEmpty) {
      _onQueryChanged();
    }
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
    _debounce = Timer(widget.debounceDelay, () async {
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
        // Record successful search to history (fire-and-forget, don't block UI).
        unawaited(addRecentSearch(query));
      } on DatabaseException catch (e, st) {
        dev.log('[SearchResults] DatabaseException: $e\n$st');
        if (mounted) {
          setState(() {
            _results = [];
            _loading = false;
          });
          showSearchRepairDialog(context, () => _runRepair());
        }
      } catch (e, st) {
        dev.log('[SearchResults] Unexpected error: $e\n$st');
        if (mounted) {
          setState(() {
            _error = e.toString();
            _loading = false;
          });
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
          style: const TextStyle(color: AppColors.destructive),
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
      shrinkWrap: !widget.scrollable,
      physics: widget.scrollable
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
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
  final _committedNotifier = ValueNotifier<String>('');

  @override
  void initState() {
    super.initState();
    // When the text box is emptied, also clear the last committed query so the
    // results view returns to the recent-search tag cloud (no stale results).
    _queryNotifier.addListener(_onQueryTextChanged);
  }

  void _onQueryTextChanged() {
    // The live text diverged from the last committed search (user edited or
    // cleared the field) — drop the stale committed term so the results view
    // returns to the idle/tag-cloud state instead of showing old results.
    final q = _queryNotifier.value.trim();
    final c = _committedNotifier.value.trim();
    if (q != c) {
      _committedNotifier.value = '';
    }
  }

  /// Explicit search trigger — wired to the search button and keyboard return.
  /// Only fires when there is non-empty text; the committed value (not live
  /// typing) drives [SearchResults], so history is written once per commit.
  void _commitSearch() {
    final q = _queryNotifier.value.trim();
    if (q.isEmpty) return;
    _committedNotifier.value = q;
  }

  @override
  void dispose() {
    _queryNotifier.removeListener(_onQueryTextChanged);
    _queryNotifier.dispose();
    _committedNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        const _BackupReminderBanner(),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ValueListenableBuilder<String>(
            valueListenable: _queryNotifier,
            builder: (context, query, _) {
              final canSearch = query.trim().isNotEmpty;
              return Row(
                children: [
                  Expanded(
                    child: SearchBox(
                      queryNotifier: _queryNotifier,
                      onSearch: _commitSearch,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: canSearch ? _commitSearch : null,
                    child: Text(l10n.searchAction),
                  ),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<String>(
            valueListenable: _queryNotifier,
            builder: (context, query, _) {
              if (query.trim().isEmpty) {
                return RecentSearchTags(
                  onTagTap: (tag) {
                    _queryNotifier.value = tag;
                    _committedNotifier.value = tag;
                  },
                );
              }
              // Field has text. Show results only when it matches the last
              // committed term; otherwise show an idle hint (no stale results).
              return ValueListenableBuilder<String>(
                valueListenable: _committedNotifier,
                builder: (context, committed, _) {
                  if (committed.trim() != query.trim()) {
                    return _SearchIdleHint(l10n: l10n);
                  }
                  return SearchResults(
                    queryNotifier: _committedNotifier,
                    debounceDelay: Duration.zero,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Shown when the field has text but no search has been committed yet
/// (e.g., the user is still typing or has edited after a search).
class _SearchIdleHint extends StatelessWidget {
  const _SearchIdleHint({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.search, size: 40, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text(
            l10n.searchIdleHint,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// 备份提醒横幅，显示在搜索页面顶部。
class _BackupReminderBanner extends ConsumerStatefulWidget {
  const _BackupReminderBanner();

  @override
  ConsumerState<_BackupReminderBanner> createState() => _BackupReminderBannerState();
}

class _BackupReminderBannerState extends ConsumerState<_BackupReminderBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settingsAsync = ref.watch(settingsControllerProvider);

    // 如果用户已手动关闭，本次会话不再显示
    if (_dismissed) return const SizedBox.shrink();

    final settings = settingsAsync.asData?.value;
    if (settings == null) return const SizedBox.shrink();

    if (!_shouldShow(settings)) return const SizedBox.shrink();

    final paths = ref.read(appPathsProvider).value;
    final backupCount = paths != null
        ? AutoBackupService(paths: paths).listBackups().length
        : 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.archivebox, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '你已有 $backupCount 份本地备份，建议分享一份到 iCloud 或其他设备保存',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: _onDismiss,
                child: Icon(
                  CupertinoIcons.xmark,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                minimumSize: Size.zero,
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(8),
                onPressed: () => _onBackup(context, l10n),
                child: const Text(
                  '去分享',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                minimumSize: Size.zero,
                onPressed: _onDismiss,
                child: Text(
                  '忽略',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _shouldShow(AppSettings settings) {
    if (!settings.backupReminderEnabled) return false;
    if (settings.nextBackupReminderDate == null) return true;
    return DateTime.now().isAfter(settings.nextBackupReminderDate!);
  }

  void _onDismiss() {
    final nextDate = _computeNextDate();
    ref.read(settingsControllerProvider.notifier).saveNextBackupReminderDate(nextDate);
    setState(() => _dismissed = true);
  }

  DateTime _computeNextDate() {
    final settings =
        ref.read(settingsControllerProvider).whenOrNull(data: (s) => s);
    final days = settings?.backupReminderIntervalDays ?? 3;
    return DateTime.now().add(Duration(days: days));
  }

  Future<void> _onBackup(BuildContext context, AppLocalizations l10n) async {
    if (!context.mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => const BackupRestoreScreen(),
      ),
    );
  }
}

/// SharedPreferences key for recent search history.
const _kRecentSearchesKey = 'recent_searches';
const _kMaxRecentSearches = 10;

/// Read recent searches from SharedPreferences.
Future<List<String>> _readRecentSearches() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kRecentSearchesKey);
  if (raw == null || raw.isEmpty) return [];
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.cast<String>();
  } catch (_) {
    return [];
  }
}

/// Write recent searches to SharedPreferences.
Future<void> _writeRecentSearches(List<String> searches) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kRecentSearchesKey, jsonEncode(searches));
}

/// Add a query to recent searches (dedup + move to front + cap at 10).
Future<void> addRecentSearch(String query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return;
  final list = await _readRecentSearches();
  list.remove(trimmed);
  list.insert(0, trimmed);
  if (list.length > _kMaxRecentSearches) {
    list.removeLast();
  }
  await _writeRecentSearches(list);
}

/// Remove a single recent search.
Future<void> removeRecentSearch(String query) async {
  final list = await _readRecentSearches();
  list.remove(query);
  await _writeRecentSearches(list);
}

/// Clear all recent searches.
Future<void> clearRecentSearches() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kRecentSearchesKey);
}

/// Tag cloud of recent searches. Shown when search box is empty.
class RecentSearchTags extends StatelessWidget {
  const RecentSearchTags({
    super.key,
    required this.onTagTap,
  });

  final ValueChanged<String> onTagTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<List<String>>(
      future: _readRecentSearches(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CupertinoActivityIndicator());
        }

        final tags = snapshot.data ?? [];

        if (tags.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.search, size: 40, color: AppColors.textTertiary),
                const SizedBox(height: 12),
                Text(
                  l10n.searchEmpty,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }

        return _RecentSearchTagsBody(
          tags: tags,
          onTagTap: onTagTap,
        );
      },
    );
  }
}

class _RecentSearchTagsBody extends StatefulWidget {
  const _RecentSearchTagsBody({
    required this.tags,
    required this.onTagTap,
  });

  final List<String> tags;
  final ValueChanged<String> onTagTap;

  @override
  State<_RecentSearchTagsBody> createState() => _RecentSearchTagsBodyState();
}

class _RecentSearchTagsBodyState extends State<_RecentSearchTagsBody> {
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    _tags = widget.tags;
  }

  @override
  void didUpdateWidget(covariant _RecentSearchTagsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tags != oldWidget.tags) {
      setState(() {
        _tags = widget.tags;
      });
    }
  }

  Future<void> _remove(String tag) async {
    await removeRecentSearch(tag);
    final updated = await _readRecentSearches();
    if (mounted) {
      setState(() {
        _tags = updated;
      });
    }
  }

  Future<void> _clearAll() async {
    await clearRecentSearches();
    if (mounted) {
      setState(() {
        _tags = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '最近搜索',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: _clearAll,
              child: Text(
                '清除全部',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.destructive,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _tags.map((tag) {
            return _RecentSearchTag(
              label: tag,
              onTap: () => widget.onTagTap(tag),
              onRemove: () => _remove(tag),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _RecentSearchTag extends StatelessWidget {
  const _RecentSearchTag({
    required this.label,
    required this.onTap,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.border.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 0, 6),
              child: Text(
                label,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
            minimumSize: Size.zero,
            onPressed: onRemove,
            child: Icon(
              CupertinoIcons.xmark,
              size: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/data/services/search_service.dart';
import 'package:thk_tree/ui/core/app_services.dart';
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
    context.push('/themes/${result.themeId}/nodes/${result.entityId}');
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
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:go_router/go_router.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/features/search/search_content.dart';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.searchTabLabel),
        trailing: CupertinoButton(
          key: const ValueKey('settings_button'),
          padding: EdgeInsets.zero,
          minSize: 0,
          onPressed: () => context.push('/settings'),
          child: SFIcon(AppIcons.settings, fontSize: 22),
        ),
      ),
      child: SafeArea(child: SearchContent()),
    );
  }
}
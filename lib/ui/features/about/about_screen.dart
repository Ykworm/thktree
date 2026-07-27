import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_version.dart';
import 'package:thk_tree/ui/core/shared/link_launcher.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/widgets/thk_list_tile.dart';
import 'package:thk_tree/ui/features/about/legal_links.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';

/// 关于页面。
///
/// 展示 App 名称、版本号、法律文档链接与开发者联系方式。
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final savedLocale = ref.watch(localeProvider);
    final systemLocale = Localizations.localeOf(context);

    return CupertinoPageScaffold(
      backgroundColor: AppColors.surface,
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.aboutTitle),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/icons/ThkTree_AppIcon.png',
                      width: 80,
                      height: 80,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ThkTree',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Thinking Tree',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            FutureBuilder<PackageInfo>(
              future: loadPackageInfo(),
              builder: (context, snapshot) {
                final info = snapshot.data;
                if (info == null) return const SizedBox.shrink();
                return _buildSection(
                  children: [
                    ThkListTile(
                      title: l10n.aboutVersion,
                      additionalInfo: formatVersionLabel(l10n, info.version),
                      trailing: null,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _buildSection(
              children: [
                _LinkTile(
                  icon: CupertinoIcons.doc_text,
                  title: l10n.aboutPrivacyPolicy,
                  url: LegalLinks.privacyPolicy(
                    savedLocale: savedLocale,
                    systemLocale: systemLocale,
                  ),
                ),
                _LinkTile(
                  icon: CupertinoIcons.doc_plaintext,
                  title: l10n.aboutTermsOfService,
                  url: LegalLinks.termsOfService(
                    savedLocale: savedLocale,
                    systemLocale: systemLocale,
                  ),
                ),
                _LinkTile(
                  icon: CupertinoIcons.book,
                  title: l10n.aboutOpenSourceLicense,
                  subtitle: 'MIT',
                  url: LegalLinks.license,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              children: [
                _LinkTile(
                  icon: CupertinoIcons.link,
                  title: l10n.aboutContactGitHub,
                  subtitle: 'Ykworm/thktree',
                  url: LegalLinks.contact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: children),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.url,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String url;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ThkListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: title,
      subtitle: subtitle,
      onTap: () => openMarkdownLink(context, url, title),
    );
  }
}

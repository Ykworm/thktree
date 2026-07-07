import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/widgets/thk_list_tile.dart';

/// 关于页面。
///
/// 展示 App 名称、版本号、开发者联系方式。
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.surface,
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.aboutTitle),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 40),
            // App 图标 + 名称
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
            // 联系方式
            _buildSection(
              children: [
                _buildContactTile(
                  icon: CupertinoIcons.mail,
                  title: l10n.aboutContactEmail,
                  value: '897210868@qq.com',
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

  Widget _buildContactTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return _AboutTile(
      icon: icon,
      title: title,
      value: value,
    );
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (!context.mounted) return;
        showCupertinoDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (_) => const CupertinoAlertDialog(
            content: Text('已复制'),
          ),
        );
      },
      child: ThkListTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: title,
        subtitle: value,
        trailing: null,
      ),
    );
  }
}

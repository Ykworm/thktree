import 'package:flutter/cupertino.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';

/// 页面顶部信息横幅：一行摘要，点击可展开更多说明。
class ThkInfoBanner extends StatefulWidget {
  const ThkInfoBanner({
    super.key,
    required this.summary,
    this.details = const [],
    this.icon = CupertinoIcons.info_circle,
    this.iconColor,
    this.initiallyExpanded = false,
  });

  final String summary;
  final List<String> details;
  final IconData icon;
  final Color? iconColor;
  final bool initiallyExpanded;

  @override
  State<ThkInfoBanner> createState() => _ThkInfoBannerState();
}

class _ThkInfoBannerState extends State<ThkInfoBanner> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final hasDetails = widget.details.isNotEmpty;

    return GestureDetector(
      onTap: hasDetails ? () => setState(() => _expanded = !_expanded) : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: AppColors.surfaceMuted,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  widget.icon,
                  color: widget.iconColor ?? AppColors.accent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.summary,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),
                if (hasDetails)
                  Icon(
                    _expanded
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    size: 14,
                    color: AppColors.textTertiary,
                  ),
              ],
            ),
            if (_expanded && hasDetails) ...[
              const SizedBox(height: 8),
              for (final detail in widget.details)
                Padding(
                  padding: const EdgeInsets.only(left: 24, bottom: 4),
                  child: Text(
                    detail,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

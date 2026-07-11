// Android 主题列表卡片（themes 列表项），展示 token 复用。
//
// 继承 iOS/macOS 的视觉决策（handoff §2.5）：圆形彩色徽章 + branch 图标 +
// 标题/副标题。颜色完全来自 AppColors.themeTileColorFor(themeId)，不写裸色。
// 徽章底色用主题色的 12% tint（withValues，遵循 §1.3 废弃 withOpacity 的约定）。

import 'package:flutter/material.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/platform/android/android_color_scheme.dart';

/// 单个主题的可点列项。
class AndroidThemeTile extends StatelessWidget {
  const AndroidThemeTile({
    super.key,
    required this.themeId,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final String themeId;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badge = AppColors.themeTileColorFor(themeId);
    final leading = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: badge.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.folder,
        color: badge,
        size: 22,
      ),
    );

    final tile = ListTile(
      leading: leading,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
      onTap: onTap,
    );

    // 保证最小触摸命中区 ≥ 48dp（handoff §2.7）。
    return SizedBox(
      height: kAndroidMinTouchTarget + 8,
      child: tile,
    );
  }
}

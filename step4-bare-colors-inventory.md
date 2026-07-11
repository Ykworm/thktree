# Step 4 · Tier 1 裸色清单（code-first，源自 lib/ 实测）

总命中：92 处（排除 app_colors.dart 自身定义）

| # | 文件 | 行 | 行内容(截断) | 建议映射 |
|---|------|----|--------------|----------|
| 1 | `lib/ui/core/auth_gate.dart` | 123 | child: ColoredBox(color: Color(0xF0000000)), | Color(0xF0000000) → FLAG:值不匹配 |
| 2 | `lib/ui/core/auth_gate.dart` | 145 | backgroundColor: const Color(0x00000000), | Color(0x00000000) → FLAG:值不匹配 |
| 3 | `lib/ui/core/shared/message_bubble.dart` | 675 | style: TextStyle(fontSize: 14, color: CupertinoColors.white), | CupertinoColors.white → FLAG:未归类 |
| 4 | `lib/ui/core/shared/message_bubble.dart` | 1102 | ? CupertinoColors.systemBlue | CupertinoColors.systemBlue → AppColors.accent |
| 5 | `lib/ui/core/shared/message_bubble.dart` | 1145 | backgroundColor: CupertinoColors.black, | CupertinoColors.black → FLAG:未归类 |
| 6 | `lib/ui/core/shared/message_bubble.dart` | 1147 | backgroundColor: CupertinoColors.black, | CupertinoColors.black → FLAG:未归类 |
| 7 | `lib/ui/core/shared/message_bubble.dart` | 1150 | style: TextStyle(color: CupertinoColors.white), | CupertinoColors.white → FLAG:未归类 |
| 8 | `lib/ui/core/shared/message_bubble.dart` | 1157 | color: CupertinoColors.white, | CupertinoColors.white → FLAG:未归类 |
| 9 | `lib/ui/core/shared/markdown_builders.dart` | 27 | color: textStyle.color ?? CupertinoColors.label.resolveFrom(context), | CupertinoColors.label → AppColors.textPrimary |
| 10 | `lib/ui/core/widgets/thk_breadcrumb_nav.dart` | 69 | color: CupertinoColors.separator.resolveFrom(context), | CupertinoColors.separator → AppColors.border |
| 11 | `lib/ui/core/widgets/thk_breadcrumb_nav.dart` | 88 | ? CupertinoColors.secondaryLabel.resolveFrom(context) | CupertinoColors.secondaryLabel → AppColors.textSecondary |
| 12 | `lib/ui/core/widgets/thk_breadcrumb_nav.dart` | 89 | : CupertinoColors.label.resolveFrom(context), | CupertinoColors.label → AppColors.textPrimary |
| 13 | `lib/ui/core/widgets/thk_button.dart` | 115 | style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w600), | CupertinoColors.white → FLAG:未归类 |
| 14 | `lib/ui/core/widgets/llm_error_card.dart` | 65 | color: CupertinoColors.systemRed.withValues(alpha: 0.08), | CupertinoColors.systemRed → AppColors.destructive |
| 15 | `lib/ui/core/widgets/llm_error_card.dart` | 68 | color: CupertinoColors.systemRed.withValues(alpha: 0.3), | CupertinoColors.systemRed → AppColors.destructive |
| 16 | `lib/ui/core/widgets/llm_error_card.dart` | 79 | color: CupertinoColors.systemRed, | CupertinoColors.systemRed → AppColors.destructive |
| 17 | `lib/ui/core/widgets/llm_error_card.dart` | 114 | color: CupertinoColors.systemRed.withValues(alpha: 0.1), | CupertinoColors.systemRed → AppColors.destructive |
| 18 | `lib/ui/core/widgets/llm_error_card.dart` | 125 | color: CupertinoColors.systemRed, | CupertinoColors.systemRed → AppColors.destructive |
| 19 | `lib/ui/core/widgets/llm_error_card.dart` | 132 | color: CupertinoColors.systemRed, | CupertinoColors.systemRed → AppColors.destructive |
| 20 | `lib/ui/core/widgets/llm_error_card.dart` | 158 | color: CupertinoColors.systemRed, | CupertinoColors.systemRed → AppColors.destructive |
| 21 | `lib/ui/core/widgets/llm_error_card.dart` | 164 | color: CupertinoColors.white, | CupertinoColors.white → FLAG:未归类 |
| 22 | `lib/ui/core/widgets/thk_grid_bottom_sheet.dart` | 34 | backgroundColor: Colors.transparent, | Colors.transparent → transparent (保留) |
| 23 | `lib/ui/core/widgets/swipeable_row.dart` | 194 | Icon(icon, color: CupertinoColors.white, size: 20), | CupertinoColors.white → FLAG:未归类 |
| 24 | `lib/ui/core/widgets/swipeable_row.dart` | 201 | color: CupertinoColors.white, | CupertinoColors.white → FLAG:未归类 |
| 25 | `lib/ui/features/settings/tts_tokens.dart` | 138 | static const Color actionActive = CupertinoColors.systemBlue; | CupertinoColors.systemBlue → AppColors.accent |
| 26 | `lib/ui/features/settings/tts_tokens.dart` | 140 | static const Color actionIdle = Color(0xFF64748B); | Color(0xFF64748B) → AppColors.textSecondary / textTertiary |
| 27 | `lib/ui/features/settings/default_model_config_screen.dart` | 79 | color: CupertinoColors.separator.resolveFrom(context), | CupertinoColors.separator → AppColors.border |
| 28 | `lib/ui/features/settings/default_model_config_screen.dart` | 133 | style: const TextStyle(color: CupertinoColors.destructiveRed), | CupertinoColors.destructiveRed → AppColors.destructive |
| 29 | `lib/ui/features/settings/llm_settings_screen.dart` | 44 | color: CupertinoColors.separator.resolveFrom(context), | CupertinoColors.separator → AppColors.border |
| 30 | `lib/ui/features/settings/tts_player_screen.dart` | 97 | backgroundColor: const Color(0x00000000), // 让背景透出 | Color(0x00000000) → FLAG:值不匹配 |
| 31 | `lib/ui/features/settings/tts_player_screen.dart` | 226 | : const Color(0x0D000000), | Color(0x0D000000) → FLAG:值不匹配 |
| 32 | `lib/ui/features/settings/tts_player_screen.dart` | 289 | color: const Color(0x0F000000), // ~6% black | Color(0x0F000000) → FLAG:值不匹配 |
| 33 | `lib/ui/features/settings/default_model_picker_screen.dart` | 94 | color: CupertinoColors.separator.resolveFrom(context), | CupertinoColors.separator → AppColors.border |
| 34 | `lib/ui/features/settings/clean_images_screen.dart` | 349 | color: CupertinoColors.white, | CupertinoColors.white → FLAG:未归类 |
| 35 | `lib/ui/features/settings/clean_images_screen.dart` | 369 | color: CupertinoColors.white, | CupertinoColors.white → FLAG:未归类 |
| 36 | `lib/ui/features/settings/clean_images_screen.dart` | 482 | top: BorderSide(color: CupertinoColors.separator), | CupertinoColors.separator → AppColors.border |
| 37 | `lib/ui/features/settings/clean_images_screen.dart` | 496 | ? const CupertinoActivityIndicator(color: CupertinoColors.white) | CupertinoColors.white → FLAG:未归类 |
| 38 | `lib/ui/features/settings/clean_images_screen.dart` | 499 | style: const TextStyle(color: CupertinoColors.white), | CupertinoColors.white → FLAG:未归类 |
| 39 | `lib/ui/features/settings/widgets/tts_player_background.dart` | 130 | child: const ColoredBox(color: Color(0x00000000)), | Color(0x00000000) → FLAG:值不匹配 |
| 40 | `lib/ui/features/llm/llm_provider_detail_screen.dart` | 534 | color: CupertinoColors.systemGrey, | CupertinoColors.systemGrey → AppColors.textSecondary |
| 41 | `lib/ui/features/llm/llm_providers_screen.dart` | 87 | color: CupertinoColors.separator.resolveFrom(context), | CupertinoColors.separator → AppColors.border |
| 42 | `lib/ui/features/llm/llm_providers_screen.dart` | 189 | color: CupertinoColors.destructiveRed, | CupertinoColors.destructiveRed → AppColors.destructive |
| 43 | `lib/ui/features/chat/chat_screen.dart` | 965 | color: CupertinoColors.systemTeal, | CupertinoColors.systemTeal → FLAG:无token |
| 44 | `lib/ui/features/chat/chat_screen.dart` | 973 | color: CupertinoColors.systemIndigo, | CupertinoColors.systemIndigo → AppColors.accent |
| 45 | `lib/ui/features/chat/chat_screen.dart` | 984 | color: CupertinoColors.systemOrange, | CupertinoColors.systemOrange → FLAG:无token |
| 46 | `lib/ui/features/chat/user_questions.dart` | 81 | backgroundColor: CupertinoColors.black, | CupertinoColors.black → FLAG:未归类 |
| 47 | `lib/ui/features/chat/user_questions.dart` | 83 | backgroundColor: CupertinoColors.black, | CupertinoColors.black → FLAG:未归类 |
| 48 | `lib/ui/features/chat/user_questions.dart` | 86 | style: const TextStyle(color: CupertinoColors.white), | CupertinoColors.white → FLAG:未归类 |
| 49 | `lib/ui/features/chat/user_questions.dart` | 93 | color: CupertinoColors.white, | CupertinoColors.white → FLAG:未归类 |
| 50 | `lib/ui/features/chat/widgets/model_selector_panel.dart` | 252 | : CupertinoColors.transparent, | CupertinoColors.transparent → FLAG:未归类 |
| 51 | `lib/ui/features/chat/widgets/clips_management_screen.dart` | 150 | color: CupertinoColors.white, | CupertinoColors.white → FLAG:未归类 |
| 52 | `lib/ui/features/chat/widgets/clips_management_screen.dart` | 189 | color: CupertinoColors.white, | CupertinoColors.white → FLAG:未归类 |
| 53 | `lib/ui/features/chat/widgets/clips_sheet.dart` | 22 | backgroundColor: CupertinoColors.transparent, | CupertinoColors.transparent → FLAG:未归类 |
| 54 | `lib/ui/features/chat/widgets/clips_sheet.dart` | 102 | color: CupertinoColors.systemBackground, | CupertinoColors.systemBackground → AppColors.pageBg |
| 55 | `lib/ui/features/chat/widgets/clips_sheet.dart` | 270 | color: CupertinoColors.black.withValues(alpha: 0.4), | CupertinoColors.black → FLAG:未归类 |
| 56 | `lib/ui/features/chat/widgets/clips_sheet.dart` | 280 | color: CupertinoColors.systemBackground, | CupertinoColors.systemBackground → AppColors.pageBg |
| 57 | `lib/ui/features/lab/lab_placeholder_screen.dart` | 23 | statusBarColor: Color(0xFF0F1035), | Color(0xFF0F1035) → FLAG:值不匹配 |
| 58 | `lib/ui/features/lab/lab_placeholder_screen.dart` | 50 | color: const Color(0xFF3B82F6), // 蓝色系 | Color(0xFF3B82F6) → FLAG:值不匹配 |
| 59 | `lib/ui/features/lab/lab_placeholder_screen.dart` | 60 | color: const Color(0xFFF97316), // 橙色系 | Color(0xFFF97316) → FLAG:值不匹配 |
| 60 | `lib/ui/features/lab/lab_placeholder_screen.dart` | 70 | color: const Color(0xFFA855F7), // 紫色系 | Color(0xFFA855F7) → FLAG:值不匹配 |
| 61 | `lib/ui/features/lab/thinking_collision/thinking_collision_screen.dart` | 214 | color: const Color(0xFFA855F7), | Color(0xFFA855F7) → FLAG:值不匹配 |
| 62 | `lib/ui/features/lab/user_input_summary/user_input_summary_screen.dart` | 364 | ? CupertinoColors.white | CupertinoColors.white → FLAG:未归类 |
| 63 | `lib/ui/features/backup_restore/backup_restore_screen.dart` | 357 | style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey), | CupertinoColors.systemGrey → AppColors.textSecondary |
| 64 | `lib/ui/features/backup_restore/backup_restore_screen.dart` | 372 | color: CupertinoColors.systemBackground, | CupertinoColors.systemBackground → AppColors.pageBg |
| 65 | `lib/ui/features/backup_restore/backup_restore_screen.dart` | 389 | fontSize: 13, color: CupertinoColors.systemGrey), | CupertinoColors.systemGrey → AppColors.textSecondary |
| 66 | `lib/ui/features/backup_restore/backup_restore_screen.dart` | 402 | color: CupertinoColors.systemBackground, | CupertinoColors.systemBackground → AppColors.pageBg |
| 67 | `lib/ui/features/backup_restore/backup_restore_screen.dart` | 406 | const Icon(CupertinoIcons.doc, color: CupertinoColors.systemBlue), | CupertinoColors.systemBlue → AppColors.accent |
| 68 | `lib/ui/features/backup_restore/backup_restore_screen.dart` | 416 | fontSize: 13, color: CupertinoColors.systemGrey), | CupertinoColors.systemGrey → AppColors.textSecondary |
| 69 | `lib/ui/features/backup_restore/backup_restore_screen.dart` | 429 | size: 20, color: CupertinoColors.destructiveRed), | CupertinoColors.destructiveRed → AppColors.destructive |
| 70 | `lib/ui/features/backup_restore/backup_restore_screen.dart` | 440 | style: const TextStyle(color: CupertinoColors.systemGrey), | CupertinoColors.systemGrey → AppColors.textSecondary |
| 71 | `lib/ui/features/search/search_content.dart` | 401 | style: const TextStyle(color: CupertinoColors.destructiveRed), | CupertinoColors.destructiveRed → AppColors.destructive |
| 72 | `lib/ui/features/search/search_content.dart` | 654 | color: CupertinoColors.white, | CupertinoColors.white → FLAG:未归类 |
| 73 | `lib/ui/features/search/search_content.dart` | 878 | color: CupertinoColors.destructiveRed, | CupertinoColors.destructiveRed → AppColors.destructive |
| 74 | `lib/ui/features/search/search_screen.dart` | 50 | barrierColor: const Color(0x61000000), | Color(0x61000000) → FLAG:值不匹配 |
| 75 | `lib/ui/features/notes/note_select_screen.dart` | 138 | style: TextStyle(color: CupertinoColors.systemRed), | CupertinoColors.systemRed → AppColors.destructive |
| 76 | `lib/ui/features/notes/note_detail_screen.dart` | 337 | color: _copied ? CupertinoColors.systemGreen : AppColors.accent, | CupertinoColors.systemGreen → AppColors.success |
| 77 | `lib/ui/features/notes/note_detail_screen.dart` | 355 | color: CupertinoColors.systemIndigo, | CupertinoColors.systemIndigo → AppColors.accent |
| 78 | `lib/ui/features/notes/note_detail_screen.dart` | 363 | color: CupertinoColors.systemRed, | CupertinoColors.systemRed → AppColors.destructive |
| 79 | `lib/ui/features/notes/note_detail_screen.dart` | 559 | style: TextStyle(color: CupertinoColors.systemRed), | CupertinoColors.systemRed → AppColors.destructive |
| 80 | `lib/ui/features/notes/note_detail_screen.dart` | 722 | style: TextStyle(color: CupertinoColors.systemRed), | CupertinoColors.systemRed → AppColors.destructive |
| 81 | `lib/ui/features/notes/note_detail_screen.dart` | 801 | leftActionColor: CupertinoColors.destructiveRed, | CupertinoColors.destructiveRed → AppColors.destructive |
| 82 | `lib/ui/features/notes/note_browse_screen.dart` | 158 | style: TextStyle(color: CupertinoColors.systemRed), | CupertinoColors.systemRed → AppColors.destructive |
| 83 | `lib/ui/features/themes/merge_chat_confirm_screen.dart` | 319 | ? const CupertinoActivityIndicator(color: CupertinoColors.white) | CupertinoColors.white → FLAG:未归类 |
| 84 | `lib/ui/features/themes/merge_chat_confirm_screen.dart` | 382 | ? CupertinoColors.white | CupertinoColors.white → FLAG:未归类 |
| 85 | `lib/ui/features/themes/theme_detail_screen.dart` | 263 | color: CupertinoColors.separator.resolveFrom(context), | CupertinoColors.separator → AppColors.border |
| 86 | `lib/ui/features/themes/theme_detail_screen.dart` | 492 | color: CupertinoColors.systemBlue, | CupertinoColors.systemBlue → AppColors.accent |
| 87 | `lib/ui/features/themes/theme_detail_screen.dart` | 498 | color: CupertinoColors.systemBlue, | CupertinoColors.systemBlue → AppColors.accent |
| 88 | `lib/ui/features/themes/theme_detail_screen.dart` | 505 | color: CupertinoColors.systemBlue | CupertinoColors.systemBlue → AppColors.accent |
| 89 | `lib/ui/features/themes/theme_detail_screen.dart` | 521 | leftActionColor: CupertinoColors.destructiveRed, | CupertinoColors.destructiveRed → AppColors.destructive |
| 90 | `lib/ui/features/themes/theme_detail_screen.dart` | 524 | rightActionColor: CupertinoColors.systemBlue, | CupertinoColors.systemBlue → AppColors.accent |
| 91 | `lib/ui/features/themes/theme_detail_screen.dart` | 635 | color: CupertinoColors.black | CupertinoColors.black → FLAG:未归类 |
| 92 | `lib/ui/features/themes/theme_detail_screen.dart` | 952 | ? CupertinoColors.systemRed | CupertinoColors.systemRed → AppColors.destructive |

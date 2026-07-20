import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show showModalBottomSheet, showDialog, Divider, SelectableText;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/data/services/clip_storage.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_spacing.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/features/chat/widgets/clips_management_screen.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';

/// 弹出碎片库 sheet。
///
/// [controller] 是接收插入文本的 TextEditingController（通常是 ChatComposer
/// 的输入框 controller）。点击碎片 → 插入到光标位置，sheet 自动关闭。
void showClipsSheet(BuildContext context, TextEditingController controller) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.transparent,
    builder: (_) => ClipsSheet(controller: controller),
  );
}

class ClipsSheet extends ConsumerStatefulWidget {
  const ClipsSheet({super.key, required this.controller});

  final TextEditingController controller;

  @override
  ConsumerState<ClipsSheet> createState() => _ClipsSheetState();
}

class _ClipsSheetState extends ConsumerState<ClipsSheet> {
  List<Clip> _clips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClips();
  }

  Future<void> _loadClips() async {
    final storage = await ref.read(clipStorageProvider.future);
    final clips = await storage.getAll();
    if (!mounted) return;
    setState(() {
      _clips = clips;
      _loading = false;
    });
  }

  void _insertClip(Clip clip) {
    final controller = widget.controller;
    final value = controller.value;
    final selection = value.selection;
    final start = selection.isValid && !selection.isCollapsed
        ? selection.start
        : (selection.isValid ? selection.baseOffset : controller.text.length);
    final end = selection.isValid && !selection.isCollapsed
        ? selection.extentOffset
        : start;
    final newText = controller.text.replaceRange(start, end, clip.text);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + clip.text.length),
    );
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  void _showPreview(Clip clip) {
    HapticFeedback.lightImpact();
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ClipPreviewDialog(text: clip.text),
    );
  }

  Future<void> _openManagement() async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => const ClipsManagementScreen(),
      ),
    );
    // 管理页返回后刷新列表
    if (mounted) _loadClips();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.55;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSp.sheetTopRadius),
        ),
      ),
      child: Column(
        children: [
          // 拖拽指示条
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppLocalizations.of(context)!.close),
                ),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.clipsTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: _openManagement,
                  child: Text(
                    AppLocalizations.of(context)!.clipsManage,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          // 内容区
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_clips.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.clips,
              size: 40,
              color: AppColors.textTertiary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.clipsEmpty,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.clipsEmptyHint,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: _clips.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: AppColors.border.withValues(alpha: 0.5),
      ),
      itemBuilder: (context, index) {
        final clip = _clips[index];
        return _ClipListTile(
          clip: clip,
          onTap: () => _insertClip(clip),
          onLongPress: () => _showPreview(clip),
        );
      },
    );
  }
}

/// 碎片列表中的单条 item。
class _ClipListTile extends StatelessWidget {
  const _ClipListTile({
    required this.clip,
    required this.onTap,
    required this.onLongPress,
  });

  final Clip clip;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          clip.text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            height: 1.35,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// 长按弹出的纯预览 dialog（无操作按钮）。
///
/// 尺寸覆盖屏幕大部分区域，适配 iOS safe area。
/// 内部可滚动查看全文。点击背景或关闭按钮关闭。
class _ClipPreviewDialog extends StatelessWidget {
  const _ClipPreviewDialog({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // 预览 card 宽度：屏幕宽 - 左右各 24pt
    final cardWidth = mediaQuery.size.width - 48;
    // 预览 card 高度：屏幕高度的 65%，但限制在 300-600pt 之间
    final cardHeight = (mediaQuery.size.height * 0.65).clamp(300.0, 600.0);

    return GestureDetector(
      // 点击背景关闭
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        color: AppColors.black.withValues(alpha: 0.4),
        alignment: Alignment.center,
        child: GestureDetector(
          // 点击 card 内部不关闭
          onTap: () {},
          child: Container(
            width: cardWidth,
            height: cardHeight,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.pageBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                // 标题栏：标题 + 关闭按钮
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.clipsPreview,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      child: Icon(
                        AppIcons.close,
                        size: 20,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 1),
                const SizedBox(height: 8),
                // 全文内容（可滚动）
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      text,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/data/services/clip_storage.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_spacing.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';

/// 碎片管理页面。
///
/// 从 clips sheet 的"管理"按钮 push 进入。
/// 支持左滑删除单条 + 底部"清空全部"（二次确认）。
class ClipsManagementScreen extends ConsumerStatefulWidget {
  const ClipsManagementScreen({super.key});

  @override
  ConsumerState<ClipsManagementScreen> createState() =>
      _ClipsManagementScreenState();
}

class _ClipsManagementScreenState extends ConsumerState<ClipsManagementScreen> {
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

  Future<void> _deleteClip(String id) async {
    final storage = await ref.read(clipStorageProvider.future);
    await storage.remove(id);
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() {
      _clips.removeWhere((c) => c.id == id);
    });
  }

  Future<void> _clearAll() async {
    final confirmed = await _showClearConfirmation();
    if (!confirmed || !mounted) return;

    final storage = await ref.read(clipStorageProvider.future);
    await storage.clearAll();
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() {
      _clips = [];
    });
  }

  Future<bool> _showClearConfirmation() async {
    return await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(AppLocalizations.of(context)!.clipsClearAllTitle),
            content: Text(AppLocalizations.of(context)!.clipsClearAllContent),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(AppLocalizations.of(context)!.clipsClearAll),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(AppLocalizations.of(context)!.clipsManageTitle),
        previousPageTitle: AppLocalizations.of(context)!.clipsTitle,
      ),
      child: SafeArea(
        top: false,
        child: _buildBody(),
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
              size: 48,
              color: AppColors.textTertiary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.clipsEmpty,
              style: TextStyle(
                fontSize: 17,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _clips.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: AppColors.border.withValues(alpha: 0.5),
            ),
            itemBuilder: (context, index) {
              final clip = _clips[index];
              return Dismissible(
                key: ValueKey(clip.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: AppColors.destructive,
                  child: const Icon(
                    AppIcons.delete,
                    color: AppColors.white,
                    size: 24,
                  ),
                ),
                onDismissed: (_) => _deleteClip(clip.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
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
            },
          ),
        ),
        // 底部清空按钮
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: AppColors.destructive,
              borderRadius: BorderRadius.circular(AppSp.cardRadius),
              onPressed: _clearAll,
              child: Text(
                AppLocalizations.of(context)!.clipsClearAll,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
